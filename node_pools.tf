########################################################################
# node_pools.tf
# Los 5 node pools descritos en la tabla "AKS/GKE" del documento de
# solución. Cada pool aísla una familia de componentes mediante un
# "taint" (mancha), de forma que el equipo de despliegue debe añadir la
# "toleration" correspondiente en sus manifiestos de Kubernetes para que
# sus Pods puedan programarse en el pool correcto. También se añade una
# "label" gemela para poder usar nodeSelector/affinity.
#
# IMPORTANTE sobre los números de nodos:
# El clúster es REGIONAL para que el plano de control tenga alta
# disponibilidad, pero cada node pool se restringe a UNA sola zona
# (var.node_zones) para que el número de nodos que veas en "gcloud" o
# "kubectl get nodes" coincida exactamente con el de la tabla del
# documento. Si en el futuro se decide repartir un pool en varias zonas
# para más resiliencia, el número de nodos (min/max) se multiplica por
# el número de zonas indicado.
########################################################################

variable "node_zones" {
  description = "Zona(s) donde se crean los nodos de cada pool. Con 1 zona, min/max de nodos = min/max de la tabla del documento."
  type        = list(string)
  default     = ["europe-west4-a"]
}

# ------------------------------------------------------------------
# 1) gke-platform-system-pool
#    Exclusivo para el plano de control interno (CoreDNS, kube-proxy,
#    agentes de métricas). NO debe correr aplicaciones.
# ------------------------------------------------------------------
resource "google_container_node_pool" "system" {
  provider = google-beta

  project        = var.project_id
  name           = "gke-platform-system-pool"
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_locations = var.node_zones

  node_count = 2 # fijo, sin autoscaling (según el documento)

  max_pods_per_node = 32

  node_config {
    machine_type    = "e2-standard-2" # 2 vCPU / 8 GB RAM
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, { workload = "platform-system" })

    taint {
      key    = "dedicated"
      value  = "platform-system"
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels]
  }
}

# ------------------------------------------------------------------
# 2) api-gateway-pool
#    Aloja LiteLLM y Guardrails. Necesita CPU rápida y baja latencia de
#    red porque habla directamente con vLLM en Cloud Run vía el
#    conector Serverless VPC Access.
# ------------------------------------------------------------------
resource "google_container_node_pool" "api_gateway" {
  provider = google-beta

  project        = var.project_id
  name           = "api-gateway-pool"
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_locations = var.node_zones

  autoscaling {
    min_node_count = 3
    max_node_count = 5
  }

  max_pods_per_node = 32

  node_config {
    machine_type    = "e2-standard-4" # 4 vCPU / 16 GB RAM
    disk_size_gb    = 100
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, { workload = "api-gateway" })

    taint {
      key    = "workload"
      value  = "api-gateway"
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels]
  }
}

# ------------------------------------------------------------------
# 3) data-storage-pool
#    Aloja Qdrant, MinIO y ClickHouse. Requiere SSD NVMe locales para
#    alto rendimiento de I/O.
#
#    NOTA: el documento indica "3" nodos con autoscale "Si" pero sin
#    especificar min/max explícitos (a diferencia de otros pools que sí
#    los detallan). Se ha asumido min=3 (línea base) / max=6 como
#    margen de crecimiento; AJUSTAR con el equipo de arquitectura si
#    corresponde un rango distinto.
# ------------------------------------------------------------------
resource "google_container_node_pool" "data_storage" {
  provider = google-beta

  project        = var.project_id
  name           = "data-storage-pool"
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_locations = var.node_zones

  autoscaling {
    min_node_count = 3
    max_node_count = 6
  }

  max_pods_per_node = 32

  node_config {
    machine_type = "n2-highmem-4" # 4 vCPU / 32 GB RAM (subir a n2-highmem-8 si se necesita el tramo alto 8 vCPU/64GB)
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    # SSD NVMe locales obligatorios según el documento (2 x 375 GB ~ 750 GB efímeros)
    ephemeral_storage_local_ssd_config {
      local_ssd_count = 2
    }

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, { workload = "data-storage" })

    taint {
      key    = "workload"
      value  = "data-storage"
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels]
  }
}

# ------------------------------------------------------------------
# 4) workflows-pool
#    Aloja Temporal.io y n8n (Server + Workers). Lógica de negocio
#    asíncrona, escala según el volumen de cola.
# ------------------------------------------------------------------
resource "google_container_node_pool" "workflows" {
  provider = google-beta

  project        = var.project_id
  name           = "workflows-pool"
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_locations = var.node_zones

  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }

  max_pods_per_node = 45

  node_config {
    machine_type    = "e2-standard-4"
    disk_size_gb    = 100
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, { workload = "workflows" })

    taint {
      key    = "workload"
      value  = "workflows"
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels]
  }
}

# ------------------------------------------------------------------
# 5) integration-pool
#    Aloja Airbyte (Server y Workers). Diseñado para escalar a 0 cuando
#    no hay tareas de sincronización activas (ahorro de costes).
# ------------------------------------------------------------------
resource "google_container_node_pool" "integration" {
  provider = google-beta

  project        = var.project_id
  name           = "integration-pool"
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_locations = var.node_zones

  autoscaling {
    min_node_count = 0
    max_node_count = 3
  }

  max_pods_per_node = 30

  node_config {
    machine_type    = "e2-standard-4"
    disk_size_gb    = 100
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, { workload = "integration" })

    taint {
      key    = "workload"
      value  = "integration"
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels]
  }
}
