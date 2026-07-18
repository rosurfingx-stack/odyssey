########################################################################
# versions.tf
# Define qué versión de Terraform y del proveedor de Google Cloud vamos
# a usar. Fijar versiones evita que un "terraform init" futuro descargue
# una versión nueva que cambie el comportamiento sin que nos demos cuenta.
########################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.40"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
