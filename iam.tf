########################################################################
# iam.tf
# Cuentas de servicio (Service Accounts) necesarias:
#
#  1) sa-gke-nodes: la usan los NODOS del clúster (VMs) en vez de la
#     cuenta "default" de Compute Engine, que tiene demasiados permisos.
#     Solo puede escribir logs/métricas y leer imágenes de Artifact
#     Registry.
#
#  2) sa-cicd: la usará el pipeline de CI/CD (Jenkins u otro) del equipo
#     de desarrollo para publicar imágenes en Artifact Registry y
#     desplegar manifiestos en el clúster. Equivale a la cuenta
#     "SP_PGA_PRO_PLTIA" descrita en el documento de solución.
########################################################################

resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = var.gke_nodes_service_account_id
  display_name = "SA nodos GKE - Plataforma Corporativa IA"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# --- Cuenta de servicio para el pipeline de CI/CD (equipo de despliegue) --

resource "google_service_account" "cicd" {
  project      = var.project_id
  account_id   = var.cicd_service_account_id
  display_name = "SA CI/CD - Publicacion de imagenes y despliegue en GKE"
}

resource "google_project_iam_member" "cicd_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer" # permite desplegar en el clúster, NO administrarlo
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Nota para el implementador:
# La generación de la clave/credencial concreta para que Jenkins (u otra
# herramienta externa) use esta cuenta (google_service_account_key o,
# preferiblemente, Workload Identity Federation sin claves) se define
# junto con el equipo de CI/CD y queda fuera del alcance de este
# entregable de infraestructura base.
