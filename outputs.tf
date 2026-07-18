########################################################################
# outputs.tf
# Datos que necesitará el equipo de despliegue (u otro ingeniero) al
# terminar el "terraform apply". Se muestran automáticamente al final
# y también se pueden consultar en cualquier momento con:
#   terraform output
########################################################################

output "cluster_name" {
  description = "Nombre del clúster GKE creado."
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "Región del clúster."
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "IP del endpoint del API server de Kubernetes (privado)."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "get_credentials_command" {
  description = "Comando exacto para configurar kubectl contra este clúster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}

output "vpc_name" {
  description = "Nombre de la VPC creada."
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Nombre de la subred de GKE."
  value       = google_compute_subnetwork.gke_subnet.name
}

output "artifact_registry_repository_url" {
  description = "URL del repositorio de Artifact Registry, para usar en 'docker push/pull' y en los manifiestos de Kubernetes (campo image:)."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "gke_nodes_service_account_email" {
  description = "Cuenta de servicio usada por los nodos del clúster."
  value       = google_service_account.gke_nodes.email
}

output "cicd_service_account_email" {
  description = "Cuenta de servicio para el pipeline de CI/CD (build & deploy)."
  value       = google_service_account.cicd.email
}

output "node_pools" {
  description = "Resumen de los node pools creados."
  value = {
    system      = google_container_node_pool.system.name
    api_gateway = google_container_node_pool.api_gateway.name
    data_storage = google_container_node_pool.data_storage.name
    workflows   = google_container_node_pool.workflows.name
    integration = google_container_node_pool.integration.name
  }
}
