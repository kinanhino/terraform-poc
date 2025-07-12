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

resource "google_project_service" "project_b_compute" {
  project = module.project_b.project_id
  service = "compute.googleapis.com"
  depends_on = [
    module.project_b
  ]
}

resource "google_project_service" "project_b_container" {
  project = module.project_b.project_id
  service = "container.googleapis.com"
  depends_on = [
    google_project_service.project_b_compute
  ]
}

resource "google_project_service" "project_a_compute" {
  project = module.project_a.project_id
  service = "compute.googleapis.com"
}