########################################################################
# artifact_registry.tf
# Repositorio de imágenes de contenedores en GCP Artifact Registry.
# Aquí es donde el equipo de despliegue publicará las imágenes Docker
# de todos los componentes (LiteLLM, Guardrails, Langfuse, n8n, Temporal
# workers, ChatUI, etc.) que luego se desplegarán en el clúster.
########################################################################

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  description   = "Repositorio de imagenes de contenedores - Plataforma Corporativa Modelos Generativos"
  format        = var.artifact_registry_format

  labels = var.labels

  # Limpia automáticamente versiones antiguas sin tag para no acumular
  # coste de almacenamiento indefinidamente. El equipo de despliegue
  # puede ajustar esta política según su estrategia de tags/releases.
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged-after-30-days"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 dias
    }
  }

  cleanup_policies {
    id     = "keep-latest-tagged"
    action = "KEEP"
    most_recent_versions {
      keep_count = 20
    }
  }
}
