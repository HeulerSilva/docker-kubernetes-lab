terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.51.0"
    }
  }

  required_version = ">= 0.14"
}

# No lab do Skills Boost o projeto e a região/zona padrão já vêm
# configurados no ambiente (gcloud config). Por isso o provider
# NÃO fixa "project" aqui -- ele detecta sozinho o projeto temporário
# do lab. Se quiser fixar manualmente, rode antes:
#   gcloud config get-value project
#   gcloud config get-value compute/zone
variable "zone" {
  description = "Zona onde o cluster e os recursos serão criados"
  default     = "us-central1-a"
  type        = string
}

variable "region" {
  description = "Região correspondente à zona acima"
  default     = "us-central1"
  type        = string
}

provider "google" {
  region = var.region
  zone   = var.zone
}

resource "google_compute_network" "vpc" {
  name                    = "vpc-gke"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "subnet-gke"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "default" {
  account_id   = "gke-aula-sa"
  display_name = "GKE Aula Service Account"
}

# Cluster ZONAL (não regional) de propósito: no lab do Skills Boost isso
# não afeta custo (o projeto é temporário e já vem com crédito), mas
# deixa a criação bem mais rápida -- essencial porque a sessão do lab
# dura só 45 minutos. Se um dia você rodar isso numa conta GCP pessoal
# de verdade, mantenha zonal: é a única forma de entrar no always-free
# tier do GKE (cluster regional NÃO entra no free tier).
resource "google_container_cluster" "primary" {
  name     = "gke-aula-infra"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
  network                  = google_compute_network.vpc.name
  subnetwork                = google_compute_subnetwork.subnet.name

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    service_account = google_service_account.default.email
    preemptible      = true
    # e2-medium em vez de n4-standard-2: disponibilidade garantida em
    # qualquer projeto temporário de lab, sem depender de quota extra.
    machine_type      = "e2-medium"
  }
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_zone" {
  value = google_container_cluster.primary.location
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone}"
}
