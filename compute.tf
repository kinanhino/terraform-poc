resource "google_compute_instance" "psc_proxy" {
  name         = "psc-proxy"
  machine_type = "e2-small"
  zone         = "${var.project_a.region}-a"
  project      = module.project_a.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = module.project_a_network.network_self_link
    subnetwork = module.project_a_network.subnets_self_links[0]
    access_config {
      # internet access - to run startup script and install nginx
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    cat > /etc/nginx/sites-available/default <<NGINX
server {
    listen 80;
    location / {
        proxy_pass https://${google_compute_address.psc_endpoint_ip.address};
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
NGINX
    systemctl restart nginx
  EOF

  tags = ["http-server"]

  depends_on = [google_compute_forwarding_rule.psc_endpoint]
}

resource "google_compute_instance_group" "psc_proxy_group" {
  name      = "psc-proxy-group"
  zone      = "${var.project_a.region}-a"
  project   = module.project_a.project_id
  
  instances = [google_compute_instance.psc_proxy.self_link]
  
  named_port {
    name = "http"
    port = "80"
  }
}