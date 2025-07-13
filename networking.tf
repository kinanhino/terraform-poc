module "project_b_network" {
  source  = "terraform-google-modules/network/google"
  version = "11.1.1"
  network_name = var.vpc_b.network
  project_id = module.project_b.project_id

  subnets = [
    {
      subnet_name   = var.vpc_b.subnet_name
      subnet_ip     = var.vpc_b.subnet_cidr
      subnet_region = var.project_b.region
      private_ip_google_access = true
    },
    {
      subnet_name   = var.vpc_b.psc_subnet_name
      subnet_ip     = var.vpc_b.psc_subnet_ip
      subnet_region = var.project_b.region
      purpose       = "PRIVATE_SERVICE_CONNECT"
    }
  ]
  secondary_ranges = {
    main-subnet = [
      {
        range_name    = var.kubernetes.ip_range_pods
        ip_cidr_range = var.vpc_b.pods_cidr
      },
      {
        range_name    = var.kubernetes.ip_range_services
        ip_cidr_range = var.vpc_b.services_cidr
      }
    ]
  }
  depends_on = [
    google_project_service.project_b_compute
  ]
}

module "project_a_network" {
  source  = "terraform-google-modules/network/google"
  version = "11.1.1"
  network_name = var.vpc_a.network
  project_id = module.project_a.project_id

  subnets = [
    {
      subnet_name   = var.vpc_a.subnet_name
      subnet_ip     = var.vpc_a.subnet_cidr
      subnet_region = var.project_a.region
    }
  ]

  depends_on = [
    google_project_service.project_a_compute
  ]
}

# Reserve IP address for PSC endpoint in Project A
resource "google_compute_address" "psc_endpoint_ip" {
  name         = "psc-endpoint-ip"
  project      = module.project_a.project_id
  region       = var.project_a.region
  address_type = "INTERNAL"
  subnetwork   = module.project_a_network.subnets_self_links[0]
  
  depends_on = [module.project_a_network]
}

# PSC Endpoint in Project A - Connect to published service
resource "google_compute_forwarding_rule" "psc_endpoint" {
  
  name                  = "psc-endpoint-to-project-b"
  project               = module.project_a.project_id
  region                = var.project_a.region
  load_balancing_scheme = ""
  
  # Connect to the published service attachment (cross-project)
  target = "projects/${module.project_b.project_id}/regions/${var.project_b.region}/serviceAttachments/psc-service-attachment"
  
  network    = module.project_a_network.network_self_link
  subnetwork = module.project_a_network.subnets_self_links[0]
  ip_address = google_compute_address.psc_endpoint_ip.self_link
  
  depends_on = [
    google_compute_service_attachment.psc_service_attachment,
    module.project_a_network
  ]
}

# PSC Service Attachment - Publish the nginx ingress service
resource "google_compute_service_attachment" "psc_service_attachment" {
  
  name        = "psc-service-attachment"
  project     = module.project_b.project_id
  region      = var.project_b.region
  
  # Point to the forwarding rule for nginx ingress controller
  target_service = local.k8s_service_forwarding_rule.self_link
  
  connection_preference = "ACCEPT_MANUAL"
  consumer_accept_lists {
    project_id_or_num = module.project_a.project_id
    connection_limit  = 10
  }
  enable_proxy_protocol = false
  
  nat_subnets = [module.project_b_network.subnets_self_links[1]]  # use the dedicated /28 PSC subnet
  
  depends_on = [
    data.google_compute_forwarding_rules.k8s_forwarding_rules,
    module.project_b_network
  ]
}