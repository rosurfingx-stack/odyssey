########################################################################
# network.tf
# Red privada (VPC) donde vivirá el clúster GKE, más las piezas que
# necesita un clúster PRIVADO para funcionar:
#   - Subred con rangos secundarios para Pods y Services (VPC-native)
#   - Cloud Router + Cloud NAT (para que los nodos, que NO tienen IP
#     pública, puedan salir a internet a bajar imágenes, hablar con
#     Azure AD, etc.)
#   - Reglas de firewall mínimas
#   - (Opcional) Conector de Serverless VPC Access, para que el pool
#     api-gateway-pool llegue por red privada al servicio de Cloud Run
#     (vLLM), tal como pide el documento de solución.
########################################################################

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "vpc-${var.name_prefix}-${var.environment}"
  auto_create_subnetworks = false
  description             = "VPC dedicada a la Plataforma Corporativa de Modelos Generativos"
}

resource "google_compute_subnetwork" "gke_subnet" {
  project                  = var.project_id
  name                     = "snet-${var.name_prefix}-gke-${var.environment}"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.vpc_cidr
  private_ip_google_access = true # permite llegar a APIs de Google (Artifact Registry, GCS, etc.) sin salir a internet

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# --- Salida a internet para nodos sin IP pública -----------------------

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "rt-${var.name_prefix}-${var.environment}"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "nat-${var.name_prefix}-${var.environment}"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Firewall ------------------------------------------------------------

# Permite la comunicación interna entre nodos, pods y el plano de control.
resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "fw-${var.name_prefix}-allow-internal-${var.environment}"
  network = google_compute_network.vpc.id
  priority = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.vpc_cidr,
    var.pods_cidr,
    var.services_cidr,
    var.master_ipv4_cidr_block,
  ]
}

# Permite los health-checks de los Load Balancers de Google (necesario para
# que el Ingress/App Gateway pueda dar servicio a las apps del clúster).
resource "google_compute_firewall" "allow_health_checks" {
  project = var.project_id
  name    = "fw-${var.name_prefix}-allow-healthchecks-${var.environment}"
  network = google_compute_network.vpc.id
  priority = 1000

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
}

# Acceso administrativo por SSH a través de IAP (Identity-Aware Proxy),
# en vez de abrir SSH a internet. Solo se usará puntualmente para depurar.
resource "google_compute_firewall" "allow_iap_ssh" {
  project = var.project_id
  name    = "fw-${var.name_prefix}-allow-iap-ssh-${var.environment}"
  network = google_compute_network.vpc.id
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # rango fijo de Google para IAP
}

# --- Conector para llegar a Cloud Run (vLLM) por red privada -----------

resource "google_vpc_access_connector" "serverless_connector" {
  count   = var.create_serverless_vpc_connector ? 1 : 0
  project = var.project_id
  name    = "vpcconn-${var.name_prefix}-${var.environment}"
  region  = var.region
  network = google_compute_network.vpc.name

  # Rango dedicado y libre, distinto del resto (no puede solaparse).
  ip_cidr_range = "10.8.0.0/28"

  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"
}
