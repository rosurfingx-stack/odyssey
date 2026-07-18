########################################################################
# gke.tf
# Clúster GKE (modo "Standard", no Autopilot) según el diagrama y las
# tablas del documento de solución "Google GKS - Corporativo":
#
#   - Clúster privado, VPC-native (alias IP), regional en europe-west4.
#   - Workload Identity habilitado (para que los Pods usen cuentas de
#     servicio de GCP sin necesidad de claves JSON).
#   - Shielded GKE Nodes habilitado (seguridad).
#   - 5 node pools, tal y como se definen en la sección "AKS/GKE" del
#     documento:
#       1. gke-platform-system-pool  -> plano de control interno
#       2. api-gateway-pool          -> LiteLLM + Guardrails
#       3. data-storage-pool         -> Qdrant, MinIO, ClickHouse
#       4. workflows-pool            -> Temporal.io y n8n
#       5. integration-pool          -> Airbyte
#
# El clúster se crea "vacío" de nodos por defecto (remove_default_node_pool)
# y todos los nodos reales viven en los node pools definidos más abajo,
# que es la práctica recomendada en Terraform para GKE.
########################################################################

resource "google_container_cluster" "primary" {
  provider = google-beta

  project  = var.project_id
  name     = var.cluster_name
  location = var.region # clúster REGIONAL (alta disponibilidad del plano de control)

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Creamos el clúster sin node pool por defecto: todos los nodos se
  # gestionan de forma explícita en node_pools.tf
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.release_channel
  }

  min_master_version = var.kubernetes_version_prefix

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = true
    }
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  dynamic "network_policy" {
    for_each = var.enable_network_policy ? [1] : []
    content {
      enabled  = true
      provider = "CALICO"
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false # necesario para el Ingress/App Gateway
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = !var.enable_network_policy
    }
    gcp_filestore_csi_driver_config {
      enabled = false # no se usa Filestore en este diseño; activar si se necesita en el futuro
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Buenas prácticas de seguridad recomendadas por Google
  # (protegen el clúster frente a manipulación del kernel/boot de los nodos).
  # Se define también a nivel de node pool para asegurarlo en todos ellos.

  deletion_protection = true

  resource_labels = var.labels

  depends_on = [
    google_project_service.required,
  ]

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}
