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

# resource "google_organization_iam_member" "project_creator_user" {
#   org_id            = "0"
#   role              = "roles/resourcemanager.projectCreator"
#   member            = "user:kinanpersonalwork@gmail.com"
# }

resource "google_project_service" "compute" {
  project = module.project-b.project_id
  service = "compute.googleapis.com"
  depends_on = [
    module.project-b
  ]
}

resource "google_project_service" "container" {
  project = module.project-b.project_id
  service = "container.googleapis.com"
  depends_on = [
    google_project_service.compute,
  ]
}

module "project-a" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.0.0"
  # insert the 2 required variables here
  name = var.project_a.name
  billing_account = var.billing_account
}

module "project-b" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.0.0"
  # insert the 2 required variables here
  name = var.project_b.name
  billing_account = var.billing_account

  
}

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "11.1.1"
  network_name = var.vpc.network
  project_id = module.project-b.project_id

  subnets = local.subnet
  depends_on = [
    module.project-b
  ]
}

module "kubernetes-engine" {
    source  = "terraform-google-modules/kubernetes-engine/google"
    version = "37.0.0"
    ip_range_pods = var.kubernetes.ip_range_pods
    ip_range_services =var.kubernetes.ip_range_services
    name = var.kubernetes.name
    network = var.vpc.network
    project_id = module.project-b.project_id
    subnetwork = var.vpc.subnet_name
    region = var.project_b.region
    depends_on = [
    google_project_service.container,
    module.network
  ]
}


module "my-app-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                = "app-wi"
  namespace           = var.kubernetes.namespace
  project_id          = var.project_b.name
  roles               = ["roles/storage.admin", "roles/compute.admin"]
  additional_projects = {"my-gcp-project-name1" : ["roles/storage.admin", "roles/compute.admin"],
                         "my-gcp-project-name2" : ["roles/storage.admin", "roles/compute.admin"]}

  depends_on = [
    module.kubernetes-engine
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