terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.43.0"
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

# resource "google_organization_iam_member" "project_creator_user" {
#   org_id            = "0"
#   role              = "roles/resourcemanager.projectCreator"
#   member            = "user:kinanpersonalwork@gmail.com"
# }


module "project_a" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.0.0"
  # insert the 2 required variables here
  name = var.project_a.name
  billing_account = var.billing_account
  activate_apis = [
    "compute.googleapis.com",
  ]
  disable_services_on_destroy = false
  deletion_policy = "DELETE"
}

module "project_b" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.0.0"
  # insert the 2 required variables here
  name = var.project_b.name
  billing_account = var.billing_account
  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com"
  ]
  disable_services_on_destroy = false
  deletion_policy = "DELETE"
}

resource "google_project_service" "compute" {
  project = module.project_b.project_id
  service = "compute.googleapis.com"
  depends_on = [
    module.project_b
  ]
}

resource "google_project_service" "container" {
  project = module.project_b.project_id
  service = "container.googleapis.com"
  depends_on = [
    google_project_service.compute
  ]
}

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "11.1.1"
  network_name = var.vpc.network
  project_id = module.project_b.project_id

  subnets = [
    {
      subnet_name   = var.vpc.subnet_name
      subnet_ip     = var.vpc.subnet_cidr
      subnet_region = var.project_b.region
      private_ip_google_access = true

    }
  ]
  secondary_ranges = {
    main-subnet = [
      {
        range_name    = var.kubernetes.ip_range_pods
        ip_cidr_range = var.vpc.pods_cidr
      },
      {
        range_name    = var.kubernetes.ip_range_services
        ip_cidr_range = var.vpc.services_cidr
      }
    ]
  }
  depends_on = [
    google_project_service.compute
  ]
}

resource "time_sleep" "wait_for_network" {
  depends_on = [module.network]
  create_duration = "30s"
}

module "kubernetes-engine" {
    source  = "terraform-google-modules/kubernetes-engine/google"
    version = "37.0.0"
    ip_range_pods = var.kubernetes.ip_range_pods
    ip_range_services = var.kubernetes.ip_range_services
    name = var.kubernetes.name
    network = module.network.network_name
    project_id = module.project_b.project_id
    subnetwork = module.network.subnets_names[0]
    region = var.project_b.region
    zones = [var.project_b.zone]
    remove_default_node_pool = true
    initial_node_count = 1
    depends_on = [
    google_project_service.container,
    time_sleep.wait_for_network
  ]
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.kubernetes.namespace
  }
  depends_on = [module.kubernetes-engine]
}

module "my-app-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                = "app-wi"
  namespace           = var.kubernetes.namespace
  project_id          = module.project_b.project_id
  roles               = ["roles/storage.admin", "roles/compute.admin"]
  additional_projects = {(module.project_a.project_id) : ["roles/storage.admin", "roles/compute.admin"]}

  depends_on = [
    module.kubernetes-engine,
    kubernetes_namespace.app_namespace
  ]
}









# resource "google_service_account" "default" {
#   account_id   = "terraform-sa"
#   display_name = "Service Account"
# }

# resource "google_container_cluster" "primary" {
#   name     = "my-gke-cluster"
#   location = var.project_b.region
#   network  = ""
#   subnetwork = ""
#   # We can't create a cluster with no node pool defined, but we want to only use
#   # separately managed node pools. So we create the smallest possible default
#   # node pool and immediately delete it.
#   remove_default_node_pool = true
#   initial_node_count       = 1
#   workload_identity_config {
#   workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
#   }
# }

# resource "google_container_node_pool" "primary_preemptible_nodes" {
#   name       = "my-node-pool"
#   location   = var.project_b.region
#   cluster    = google_container_cluster.primary.name
#   node_count = 1

#   node_config {
#     preemptible  = true
#     machine_type = "e2-small"

#     # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
#     service_account = google_service_account.default.email
#     oauth_scopes    = [
#       "https://www.googleapis.com/auth/cloud-platform"
#     ]
#   }
# }