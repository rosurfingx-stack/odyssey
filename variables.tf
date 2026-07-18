########################################################################
# variables.tf
# Aquí se declaran TODAS las variables que el implementador puede/debe
# ajustar. Los valores reales se ponen en "terraform.tfvars" (nunca en
# este archivo), copiando terraform.tfvars.example.
########################################################################

variable "project_id" {
  description = "ID del proyecto de GCP (ej: prosegur-ia-corporativa-pro). NO es el nombre visible, es el project_id."
  type        = string
}

variable "region" {
  description = "Región de despliegue. Según el documento de solución: europe-west4."
  type        = string
  default     = "europe-west4"
}

variable "environment" {
  description = "Sufijo de entorno para nombrar recursos (pro, pre, dev...)."
  type        = string
  default     = "pro"
}

variable "name_prefix" {
  description = "Prefijo corto para nombrar todos los recursos de este proyecto."
  type        = string
  default     = "pltia"
}

########################################
# Red (VPC)
########################################

variable "vpc_cidr" {
  description = "Rango principal de la subred donde viven los nodos de GKE."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Rango secundario (alias IP) para los Pods de Kubernetes."
  type        = string
  default     = "10.20.0.0/14"
}

variable "services_cidr" {
  description = "Rango secundario (alias IP) para los Services de Kubernetes (ClusterIP)."
  type        = string
  default     = "10.30.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "Rango /28 exclusivo para el plano de control (master) del clúster privado. No debe solaparse con nada."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "Listado de redes (CIDR) autorizadas a hablar con el endpoint del API server de Kubernetes (ej. red de Prosegur, VPN, bastión de CI/CD). AJUSTAR obligatoriamente antes de aplicar."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "10.0.0.0/8"
      display_name = "red-interna-prosegur-PLACEHOLDER-ajustar"
    }
  ]
}

variable "enable_private_endpoint" {
  description = "Si es true, el API server SOLO tiene IP privada (recomendado para producción, requiere VPN/Interconnect u host de administración dentro de la VPC/red on-prem)."
  type        = bool
  default     = false
}

variable "create_serverless_vpc_connector" {
  description = "Crea un Serverless VPC Access Connector para que el pool api-gateway-pool (LiteLLM) pueda hablar por red privada con el servicio de Cloud Run (vLLM), tal como indica el documento de solución."
  type        = bool
  default     = true
}

########################################
# GKE - Clúster
########################################

variable "cluster_name" {
  description = "Nombre del clúster GKE."
  type        = string
  default     = "gke-corporativo-pltia"
}

variable "kubernetes_version_prefix" {
  description = "Prefijo de versión de Kubernetes a usar dentro del canal de versiones (release channel). Dejar null para que GKE elija la más reciente validada del canal."
  type        = string
  default     = null
}

variable "release_channel" {
  description = "Canal de versiones de GKE: RAPID, REGULAR o STABLE."
  type        = string
  default     = "REGULAR"
}

variable "enable_network_policy" {
  description = "Activa Network Policy (Calico) para poder aislar tráfico entre namespaces/pools con políticas de Kubernetes."
  type        = bool
  default     = true
}

variable "maintenance_start_time" {
  description = "Hora de inicio (RFC3339, solo HH:MM:SSZ) de la ventana diaria de mantenimiento."
  type        = string
  default     = "03:00"
}

########################################
# Artifact Registry
########################################

variable "artifact_registry_repository_id" {
  description = "Nombre del repositorio de imágenes de contenedores en Artifact Registry."
  type        = string
  default     = "artifact"
}

variable "artifact_registry_format" {
  description = "Formato del repositorio: DOCKER, ya que vamos a guardar imágenes de contenedores."
  type        = string
  default     = "DOCKER"
}

########################################
# Cuentas de servicio (IAM)
########################################

variable "cicd_service_account_id" {
  description = "Account-id (sin dominio) de la Service Account que usará el pipeline de CI/CD (ej. Jenkins) para desplegar en GKE y publicar imágenes en Artifact Registry. Equivalente al 'SP_PGA_PRO_PLTIA' del documento de solución."
  type        = string
  default     = "sa-cicd-pltia"
}

variable "gke_nodes_service_account_id" {
  description = "Account-id (sin dominio) de la Service Account que usarán los nodos del clúster (principio de mínimo privilegio, en vez de usar la cuenta default de Compute Engine)."
  type        = string
  default     = "sa-gke-nodes-pltia"
}

variable "labels" {
  description = "Etiquetas comunes que se aplican a todos los recursos, para facilitar el control de costes y el inventario."
  type        = map(string)
  default = {
    proyecto   = "plataforma-corporativa-modelos-generativos"
    gestionado = "terraform"
  }
}
