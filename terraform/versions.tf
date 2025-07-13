terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.43.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "3.0.2"
    }
  }
}

provider "google" {
  region  = var.project_b.region
  zone    = var.project_b.zone
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.kubernetes-engine.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.kubernetes-engine.ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = "https://${module.kubernetes-engine.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.kubernetes-engine.ca_certificate)
  }
}