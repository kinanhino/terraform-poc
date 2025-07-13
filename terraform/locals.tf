# Wait for GKE to create the forwarding rule for nginx ingress
resource "null_resource" "wait_for_forwarding_rule" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for GKE to create forwarding rule for nginx ingress..."
      for i in {1..30}; do
        RULE_COUNT=$(gcloud compute forwarding-rules list --project=${module.project_b.project_id} --regions=${var.project_b.region} --format="value(name)" | wc -l)
        if [ "$RULE_COUNT" -gt "0" ]; then
          echo "Found $RULE_COUNT forwarding rule(s)"
          exit 0
        fi
        echo "Attempt $i/30: No forwarding rules found yet, waiting 10 seconds..."
        sleep 10
      done
      echo "Timeout waiting for forwarding rules"
      exit 1
    EOT
  }
  
  depends_on = [helm_release.nginx_ingress]
}

# Get all forwarding rules and find the one for our specific service
data "google_compute_forwarding_rules" "k8s_forwarding_rules" {
  project = module.project_b.project_id
  region  = var.project_b.region
  
  depends_on = [null_resource.wait_for_forwarding_rule]
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
  
  k8s_service_forwarding_rule = [
    for rule in data.google_compute_forwarding_rules.k8s_forwarding_rules.rules :
    rule if rule.ip_address == local.nginx_ingress_ip
  ][0]
}