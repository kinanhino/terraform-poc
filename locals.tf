# Get all forwarding rules and find the one for our specific service
data "google_compute_forwarding_rules" "k8s_forwarding_rules" {
  project = module.project_b.project_id
  region  = var.project_b.region
  
  depends_on = [kubernetes_service.example]
}

# Get the nginx ingress controller service created by helm
data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata.0.name
  }
  depends_on = [helm_release.nginx_ingress]
}

# Find the nginx ingress controller forwarding rule (for HTTPS support)
locals {
  nginx_ingress_ip = data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip
  # Find the forwarding rule for nginx ingress controller
  k8s_service_forwarding_rule = [
    for rule in data.google_compute_forwarding_rules.k8s_forwarding_rules.rules :
    rule if rule.ip_address == local.nginx_ingress_ip
  ][0]
}