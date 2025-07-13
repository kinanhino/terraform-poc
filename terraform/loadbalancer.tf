resource "google_compute_ssl_certificate" "example" {
  name_prefix = "example-cert-"
  project     = module.project_a.project_id
  description = "SSL certificate for external load balancer"
  
  certificate =  file(var.certificate_path)
  private_key = file(var.private_key_path)
  lifecycle {
    create_before_destroy = true
  }
}

module "cloud-armor" {
  source  = "GoogleCloudPlatform/cloud-armor/google"
  version = "5.1.0"
  
  name = "cloud-armor-policy"
  project_id = module.project_a.project_id
  
  default_rule_action = "allow"
  
  custom_rules = {
    block_countries_1 = {
      action         = "deny(403)"
      priority       = 1000
      description    = "Block traffic from restricted countries - Group 1"
      preview        = false
      expression     = "origin.region_code == 'CN' || origin.region_code == 'PK' || origin.region_code == 'KW' || origin.region_code == 'MA' || origin.region_code == 'TN'"
    }
    block_countries_2 = {
      action         = "deny(403)"
      priority       = 1001
      description    = "Block traffic from restricted countries - Group 2"
      preview        = false
      expression     = "origin.region_code == 'DZ' || origin.region_code == 'PS' || origin.region_code == 'IQ' || origin.region_code == 'BH' || origin.region_code == 'LB'"
    }
    block_countries_3 = {
      action         = "deny(403)"
      priority       = 1002
      description    = "Block traffic from restricted countries - Group 3"
      preview        = false
      expression     = "origin.region_code == 'BD' || origin.region_code == 'ID' || origin.region_code == 'BN' || origin.region_code == 'YE' || origin.region_code == 'QA'"
    }
    block_countries_4 = {
      action         = "deny(403)"
      priority       = 1003
      description    = "Block traffic from restricted countries - Group 4"
      preview        = false
      expression     = "origin.region_code == 'SY' || origin.region_code == 'AZ' || origin.region_code == 'SA' || origin.region_code == 'AE' || origin.region_code == 'JO'"
    }
  }
}

module "gce-lb-http" {
  source            = "terraform-google-modules/lb-http/google"
  version           = "~> 12.0"
  name              = "ci-https-redirect"
  project           = module.project_a.project_id
  firewall_networks = [module.project_a_network.network_name]
  ssl               = true
  ssl_certificates  = [google_compute_ssl_certificate.example.self_link]
  https_redirect    = true
  
  security_policy   = module.cloud-armor.policy.self_link

  backends = {
    default = {
      protocol    = "HTTP"
      port        = 80
      port_name   = "http"
      timeout_sec = 10
      enable_cdn  = false

      health_check = {
        request_path = "/"
        port         = 80
      }

      log_config = {
        enable = false
      }

      groups = [
        {
          group = google_compute_instance_group.psc_proxy_group.self_link
        }
      ]
      iap_config = {
        enable = false
      }
    }
  }
  
  depends_on = [module.cloud-armor, google_compute_instance_group.psc_proxy_group]
}

# Wait for PSC flow to be ready
resource "null_resource" "wait_for_psc" {
  depends_on = [
    google_compute_instance.psc_proxy,
    google_compute_service_attachment.psc_service_attachment,
    module.gce-lb-http
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for PSC flow to be ready..."
      for i in {1..60}; do
        if curl -f -k https://${module.gce-lb-http.external_ip}; then
          echo "PSC flow is working!"
          exit 0
        fi
        echo "Attempt $i/60 failed, waiting 10 seconds..."
        sleep 10
      done
      echo "Timeout waiting for PSC flow"
      exit 1
    EOT
  }
}