########################################################################
# apis.tf
# Habilita las APIs de Google Cloud necesarias para todo lo que vamos a
# crear. Si una API no está habilitada, Terraform fallará al intentar
# crear el recurso correspondiente. Se hace aquí para no depender de que
# el implementador se acuerde de habilitarlas a mano una por una.
########################################################################

locals {
  required_apis = [
    "compute.googleapis.com",             # VPC, subredes, firewall, Cloud NAT/Router
    "container.googleapis.com",           # GKE
    "artifactregistry.googleapis.com",    # Artifact Registry
    "iam.googleapis.com",                 # Service Accounts / roles
    "vpcaccess.googleapis.com",           # Serverless VPC Access Connector
    "cloudresourcemanager.googleapis.com",# metadata del proyecto
    "logging.googleapis.com",             # Cloud Logging
    "monitoring.googleapis.com",          # Cloud Monitoring
    "servicenetworking.googleapis.com",   # reservas de rangos para servicios privados (Cloud SQL/Memorystore futuros)
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
