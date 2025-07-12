# Main Terraform configuration for PSC setup
# External LB (Project A) -> Proxy VM -> PSC -> nginx ingress (Project B) -> Flask app

# This file orchestrates the overall infrastructure
# Specific resources are organized in separate files:
# - projects.tf: Project creation and APIs
# - networking.tf: VPCs, subnets, PSC configuration  
# - kubernetes.tf: GKE cluster, applications, ingress
# - compute.tf: Proxy VMs and instance groups
# - loadbalancer.tf: External LB and Cloud Armor
# - locals.tf: Data sources and computed values


# terraform {
#   required_providers {
#     google = {
#       source = "hashicorp/google"
#       version = "6.43.0"
#     }
#     helm = {
#       source = "hashicorp/helm"
#       version = "3.0.2"
#     }
#   }
# }

# provider "google" {
#   region  = var.project_b.region
#   zone    = var.project_b.zone
# }

# data "google_client_config" "default" {}

# provider "kubernetes" {
#   host                   = "https://${module.kubernetes-engine.endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.kubernetes-engine.ca_certificate)
# }

# provider "helm" {
#   kubernetes = {
#     host                   = "https://${module.kubernetes-engine.endpoint}"
#     token                  = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(module.kubernetes-engine.ca_certificate)
#   }
# }

# # resource "google_organization_iam_member" "project_creator_user" {
# #   org_id            = "0"
# #   role              = "roles/resourcemanager.projectCreator"
# #   member            = "user:kinanpersonalwork@gmail.com"
# # }


# module "project_a" {
#   source  = "terraform-google-modules/project-factory/google"
#   version = "18.0.0"
#   # insert the 2 required variables here
#   name = var.project_a.name
#   billing_account = var.billing_account
#   activate_apis = [
#     "compute.googleapis.com",
#   ]
#   disable_services_on_destroy = false
#   deletion_policy = "DELETE"
# }

# module "project_b" {
#   source  = "terraform-google-modules/project-factory/google"
#   version = "18.0.0"
#   # insert the 2 required variables here
#   name = var.project_b.name
#   billing_account = var.billing_account
#   activate_apis = [
#     "compute.googleapis.com",
#     "container.googleapis.com"
#   ]
#   disable_services_on_destroy = false
#   deletion_policy = "DELETE"
# }

# resource "google_project_service" "compute" {
#   project = module.project_b.project_id
#   service = "compute.googleapis.com"
#   depends_on = [
#     module.project_b
#   ]
# }

# resource "google_project_service" "container" {
#   project = module.project_b.project_id
#   service = "container.googleapis.com"
#   depends_on = [
#     google_project_service.project_b_compute
#   ]
# }

# module "network" {
#   source  = "terraform-google-modules/network/google"
#   version = "11.1.1"
#   network_name = var.vpc_b.network
#   project_id = module.project_b.project_id

#   subnets = [
#     {
#       subnet_name   = var.vpc_b.subnet_name
#       subnet_ip     = var.vpc_b.subnet_cidr
#       subnet_region = var.project_b.region
#       private_ip_google_access = true
#     },
#     {
#       subnet_name   = "psc-nat-subnet"
#       subnet_ip     = "10.3.0.0/28"  # Dedicated /28 subnet for PSC NAT
#       subnet_region = var.project_b.region
#       purpose       = "PRIVATE_SERVICE_CONNECT"
#     }
#   ]
#   secondary_ranges = {
#     main-subnet = [
#       {
#         range_name    = var.kubernetes.ip_range_pods
#         ip_cidr_range = var.vpc_b.pods_cidr
#       },
#       {
#         range_name    = var.kubernetes.ip_range_services
#         ip_cidr_range = var.vpc_b.services_cidr
#       }
#     ]
#   }
#   depends_on = [
#     google_project_service.project_b_compute
#   ]
# }

# # resource "time_sleep" "wait_for_network" {
# #   depends_on = [module.network]
# #   create_duration = "30s"
# # }

# module "kubernetes-engine" {
#     source  = "terraform-google-modules/kubernetes-engine/google"
#     version = "37.0.0"
#     ip_range_pods = var.kubernetes.ip_range_pods
#     ip_range_services = var.kubernetes.ip_range_services
#     name = var.kubernetes.name
#     network = module.project_b_network.network_name
#     project_id = module.project_b.project_id
#     subnetwork = module.project_b_network.subnets_names[0]
#     region = var.project_b.region
#     zones = [var.project_b.zone]
#     remove_default_node_pool = true
#     initial_node_count = 1
#     deletion_protection = false
    
#     node_pools = [
#       {
#         name         = "default-pool"
#         machine_type = "e2-standard-4"
#         min_count    = 1
#         max_count    = 2
#         disk_size_gb = 100
#         disk_type    = "pd-standard"
#         auto_repair  = true
#         auto_upgrade = true
#         preemptible  = false
#       }
#     ]
    
#     depends_on = [
#     google_project_service.project_b_container,
#     # time_sleep.wait_for_network
#   ]
# }

# resource "kubernetes_namespace" "app_namespace" {
#   metadata {
#     name = var.kubernetes.namespace
#   }
#   depends_on = [module.kubernetes-engine]
# }

# resource "kubernetes_namespace" "ingress_nginx" {
#   metadata {
#     name = "ingress-nginx"
#   }
#   depends_on = [module.kubernetes-engine]
# }

# resource "helm_release" "nginx_ingress" {
#   name       = "ingress-nginx"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   namespace  = kubernetes_namespace.ingress_nginx.metadata.0.name

#   values = [
#     yamlencode({
#       controller = {
#         service = {
#           annotations = {
#             "networking.gke.io/load-balancer-type" = "Internal"
#           }
#         }
#       }
#     })
#   ]
#   depends_on = [module.kubernetes-engine, kubernetes_namespace.ingress_nginx]
# }

# module "gke-workload-identity" {
#   source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
#   name                = "app-wi"
#   namespace           = kubernetes_namespace.app_namespace.metadata[0].name
#   project_id          = module.project_b.project_id
#   roles               = ["roles/storage.admin", "roles/compute.admin"]
#   additional_projects = {(module.project_a.project_id) : ["roles/storage.admin", "roles/compute.admin"]}

#   depends_on = [
#     module.kubernetes-engine,
#     kubernetes_namespace.app_namespace
#   ]
# }

# resource "kubernetes_deployment" "example" {
#   metadata {
#     name = "terraform-example"
#     namespace  = kubernetes_namespace.app_namespace.metadata[0].name
#     labels = {
#       app = "MyApp"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "MyApp"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "MyApp"
#         }
#       }

#       spec {
#         container {
#           image = "tiangolo/uwsgi-nginx-flask:python3.8"
#           name  = "example"

#           liveness_probe {
#             http_get {
#               path = "/health"
#               port = 80
#             }

#             initial_delay_seconds = 10
#             period_seconds        = 10
#           }

#           volume_mount {
#             name = "config-volume"
#             mount_path = "/app"
#           }
#         }

#         volume {
#           name = "config-volume"
#           config_map {
#             name = kubernetes_config_map.example.metadata.0.name
#           }
#         }
#       }
#     }
#   }
#   depends_on = [ kubernetes_namespace.app_namespace,
#               kubernetes_config_map.example
#               ]
# }

# resource "kubernetes_service" "example" {
#   metadata {
#     name = "terraform-example"
#     namespace = kubernetes_namespace.app_namespace.metadata[0].name
#     # annotations = {
#     #   "cloud.google.com/load-balancer-type" = "Internal"
#     # }
#   }
#   spec {
#     selector = {
#       app = kubernetes_deployment.example.metadata.0.labels.app
#     }
#     port {
#       port        = 80
#       target_port = 80
#     }

#     type = "ClusterIP"
#   }
#   depends_on = [ kubernetes_namespace.app_namespace ]
# }

# resource "kubernetes_config_map" "example" {
#   metadata {
#     name = "my-config"
#     namespace = kubernetes_namespace.app_namespace.metadata[0].name
#   }
#   data = {
#     "main.py" = <<EOF
# from flask import Flask
# app = Flask(__name__)

# @app.route('/')
# def hello():
#     return "Hello from prebuilt Flask image!"

# @app.route('/health')
# def health():
#     return "OK", 200

# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=80)
# EOF
#     "uwsgi.ini" = <<EOF
# [uwsgi]
# module = main
# callable = app
# uid = 1000
# gid = 2000
# master = true
# processes = 5
# socket = /tmp/uwsgi.sock
# chown-socket = nginx:nginx
# chmod-socket = 664
# vacuum = true
# die-on-term = true
# EOF
#   }
#   depends_on = [ kubernetes_namespace.app_namespace ]
# }

# resource "kubernetes_secret" "tls_secret" {
#     metadata {
#       name = "tls-secret"
#       namespace = kubernetes_namespace.app_namespace.metadata[0].name
#     }

#     type = "kubernetes.io/tls"

#     data = {
#       "tls.crt" = base64encode(file("dummy_certs/certificate.pem"))
#       "tls.key" = base64encode(file("dummy_certs/private-key.pem"))
#     }
#     depends_on = [ kubernetes_namespace.app_namespace ]
#   }

# resource "kubernetes_ingress_v1" "example_ingress" {
#   metadata {
#     name = "example-ingress"
#     namespace = kubernetes_namespace.app_namespace.metadata[0].name
#     annotations = {
#       "kubernetes.io/ingress.class" = "nginx"
#       "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
#       "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      
#     }
#   }

#   spec {
#     rule {
#       http {
#         path {
#           backend {
#             service {
#               name = "terraform-example"
#               port {
#                 number = 80
#               }
#             }
#           }

#           path = "/"
#           path_type = "Prefix"
#         }
#       }
#     }

#     tls {
#       secret_name = "tls-secret"
#     }
#   }
#   depends_on = [ kubernetes_namespace.app_namespace, kubernetes_service.example, helm_release.nginx_ingress ]
# }

# module "project_a_network" {
#   source  = "terraform-google-modules/network/google"
#   version = "11.1.1"
#   network_name = var.vpc_a.network
#   project_id = module.project_a.project_id

#   subnets = [
#     {
#       subnet_name   = var.vpc_a.subnet_name
#       subnet_ip     = var.vpc_a.subnet_cidr
#       subnet_region = var.project_a.region
#     }
#   ]

#   depends_on = [
#     google_project_service.project_a_compute
#   ]
# }

# resource "google_project_service" "compute_a" {
#   project = module.project_a.project_id
#   service = "compute.googleapis.com"

# }

# module "gce-lb-http" {
#   source            = "terraform-google-modules/lb-http/google"
#   version           = "~> 12.0"
#   name              = "ci-https-redirect"
#   project           = module.project_a.project_id
#   firewall_networks = [module.project_a_network.network_name]
#   ssl               = true
#   ssl_certificates  = [google_compute_ssl_certificate.example.self_link]
#   https_redirect    = true
  
#   # cloud armor policy
#   security_policy   = module.cloud-armor.policy.self_link

#   backends = {
#     default = {
#       protocol    = "HTTP"
#       port        = 80
#       port_name   = "http"
#       timeout_sec = 10
#       enable_cdn  = false

#       health_check = {
#         request_path = "/"
#         port         = 80
#       }

#       log_config = {
#         enable = false
#       }

#       groups = [
#         {
#           group = google_compute_instance_group.psc_proxy_group.self_link
#         }
#       ]
#       iap_config = {
#         enable = false
#       }
#     }
#   }
  
#   depends_on = [module.cloud-armor, google_compute_instance_group.psc_proxy_group]
# }

# module "cloud-armor" {
#   source  = "GoogleCloudPlatform/cloud-armor/google"
#   version = "5.1.0"
  
#   name = "cloud-armor-policy"
#   project_id = module.project_a.project_id
  
#   # Default action - allow all traffic not matching custom rules
#   default_rule_action = "allow"
  
#   # Custom rules for country restrictions (split into multiple rules due to expression limits)
#   custom_rules = {
#     # Block major restricted countries - Group 1
#     block_countries_1 = {
#       action         = "deny(403)"
#       priority       = 1000
#       description    = "Block traffic from restricted countries - Group 1"
#       preview        = false
#       expression     = "origin.region_code == 'CN' || origin.region_code == 'PK' || origin.region_code == 'KW' || origin.region_code == 'MA' || origin.region_code == 'TN'"
#     }
#     # Block major restricted countries - Group 2  
#     block_countries_2 = {
#       action         = "deny(403)"
#       priority       = 1001
#       description    = "Block traffic from restricted countries - Group 2"
#       preview        = false
#       expression     = "origin.region_code == 'DZ' || origin.region_code == 'PS' || origin.region_code == 'IQ' || origin.region_code == 'BH' || origin.region_code == 'LB'"
#     }
#     # Block major restricted countries - Group 3
#     block_countries_3 = {
#       action         = "deny(403)"
#       priority       = 1002
#       description    = "Block traffic from restricted countries - Group 3"
#       preview        = false
#       expression     = "origin.region_code == 'BD' || origin.region_code == 'ID' || origin.region_code == 'BN' || origin.region_code == 'YE' || origin.region_code == 'QA'"
#     }
#     # Block major restricted countries - Group 4
#     block_countries_4 = {
#       action         = "deny(403)"
#       priority       = 1003
#       description    = "Block traffic from restricted countries - Group 4"
#       preview        = false
#       expression     = "origin.region_code == 'SY' || origin.region_code == 'AZ' || origin.region_code == 'SA' || origin.region_code == 'AE' || origin.region_code == 'JO'"
#     }
#   }
# }

# # Get all forwarding rules and find the one for our specific service
# data "google_compute_forwarding_rules" "k8s_forwarding_rules" {
#   project = module.project_b.project_id
#   region  = var.project_b.region
  
#   depends_on = [kubernetes_service.example]
# }

# # Get the nginx ingress controller service created by helm
# data "kubernetes_service" "nginx_ingress_controller" {
#   metadata {
#     name      = "ingress-nginx-controller"
#     namespace = kubernetes_namespace.ingress_nginx.metadata.0.name
#   }
#   depends_on = [helm_release.nginx_ingress]
# }

# # Find the nginx ingress controller forwarding rule (for HTTPS support)
# locals {
#   nginx_ingress_ip = data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip
#   # Find the forwarding rule for nginx ingress controller
#   k8s_service_forwarding_rule = [
#     for rule in data.google_compute_forwarding_rules.k8s_forwarding_rules.rules :
#     rule if rule.ip_address == local.nginx_ingress_ip
#   ][0]
# }

# # PSC Service Attachment - Publish the service backend (not ingress)
# resource "google_compute_service_attachment" "psc_service_attachment" {
#   name        = "psc-service-attachment"
#   project     = module.project_b.project_id
#   region      = var.project_b.region
  
#   # Point to the forwarding rule for our specific service backend
#   target_service = local.k8s_service_forwarding_rule.self_link
  
#   connection_preference = "ACCEPT_MANUAL"
#   consumer_accept_lists {
#     project_id_or_num = module.project_a.project_id
#     connection_limit  = 10
#   }
#   enable_proxy_protocol = false
  
#   nat_subnets = [module.project_b_network.subnets_self_links[1]]  # Use the dedicated /28 PSC subnet
  
#   depends_on = [
#     data.google_compute_forwarding_rules.k8s_forwarding_rules,
#     module.network
#   ]
# }

# # Reserve IP address for PSC endpoint in Project A
# resource "google_compute_address" "psc_endpoint_ip" {
#   name         = "psc-endpoint-ip"
#   project      = module.project_a.project_id
#   region       = var.project_a.region
#   address_type = "INTERNAL"
#   subnetwork   = module.project_a_network.subnets_self_links[0]
#   # address      = "10.0.1.100"
  
#   depends_on = [module.project_a_network]
# }

# # PSC Endpoint in Project A - Connect to published service
# resource "google_compute_forwarding_rule" "psc_endpoint" {
#   name                  = "psc-endpoint-to-project-b"
#   project               = module.project_a.project_id
#   region                = var.project_a.region
#   load_balancing_scheme = ""
  
#   # Connect to the published service attachment (cross-project)
#   target = "projects/${module.project_b.project_id}/regions/${var.project_b.region}/serviceAttachments/psc-service-attachment"
  
#   network    = module.project_a_network.network_self_link
#   subnetwork = module.project_a_network.subnets_self_links[0]
#   ip_address = google_compute_address.psc_endpoint_ip.self_link
  
#   depends_on = [
#     google_compute_service_attachment.psc_service_attachment,
#     module.project_a_network
#   ]
# }

# # Proxy VM that forwards traffic from External LB to PSC endpoint
# resource "google_compute_instance" "psc_proxy" {
#   name         = "psc-proxy"
#   machine_type = "e2-small"
#   zone         = "${var.project_a.region}-a"
#   project      = module.project_a.project_id

#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#     }
#   }

#   network_interface {
#     network    = module.project_a_network.network_self_link
#     subnetwork = module.project_a_network.subnets_self_links[0]
#     access_config {
#       # Ephemeral external IP - Access to Internet - to run startup script and install nginx
#     }
#   }

#   metadata_startup_script = <<-EOF
#     #!/bin/bash
#     apt-get update
#     apt-get install -y nginx
#     cat > /etc/nginx/sites-available/default <<NGINX
# server {
#     listen 80;
#     location / {
#         proxy_pass https://${google_compute_address.psc_endpoint_ip.address};
#         proxy_ssl_verify off;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto https;
#     }
# }
# NGINX
#     systemctl restart nginx
#   EOF

#   tags = ["http-server"]

#   depends_on = [google_compute_forwarding_rule.psc_endpoint]
# }

# # Instance group for the proxy VM
# resource "google_compute_instance_group" "psc_proxy_group" {
#   name      = "psc-proxy-group"
#   zone      = "${var.project_a.region}-a"
#   project   = module.project_a.project_id
  
#   instances = [google_compute_instance.psc_proxy.self_link]
  
#   named_port {
#     name = "http"
#     port = "80"
#   }
# }

# # # Health check for proxy VM
# # resource "google_compute_health_check" "psc_proxy_hc" {
# #   name     = "psc-proxy-health-check"
# #   project  = module.project_a.project_id

# #   http_health_check {
# #     port = "80"
# #     request_path = "/"
# #   }
# # }

# # # Backend service for External LB - points to proxy instance group
# # resource "google_compute_backend_service" "external_lb_neg" {
# #   name         = "external-lb-backend"
# #   project      = module.project_a.project_id
# #   protocol     = "HTTP"
# #   port_name    = "http"
# #   timeout_sec  = 30

# #   backend {
# #     group = google_compute_instance_group.psc_proxy_group.self_link
# #   }

# #   health_checks = [google_compute_health_check.psc_proxy_hc.self_link]
  
# #   depends_on = [google_compute_instance_group.psc_proxy_group]
# # }


# # SSL certificate for the external load balancer
# resource "google_compute_ssl_certificate" "example" {
#   name_prefix = "example-cert-"
#   project     = module.project_a.project_id
#   description = "SSL certificate for external load balancer"
  
#   certificate =  file("dummy_certs/certificate.pem")
#   private_key = file("dummy_certs/private-key.pem")
#   lifecycle {
#     create_before_destroy = true
#   }
# }


# resource "null_resource" "wait_for_psc" {
#   depends_on = [
#     google_compute_instance.psc_proxy,
#     google_compute_service_attachment.psc_service_attachment,
#     module.gce-lb-http
#   ]

#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Waiting for PSC flow to be ready..."
#       for i in {1..120}; do
#         if curl -f -k https://${module.gce-lb-http.external_ip}; then
#           echo "PSC flow is working!"
#           exit 0
#         fi
#         echo "Attempt $i/120 failed, waiting 5 seconds..."
#         sleep 5
#       done
#       echo "Timeout waiting for PSC flow"
#       exit 1
#     EOT
#   }
# }