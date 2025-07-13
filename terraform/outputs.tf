# Project Outputs
output "project_a_id" {
  description = "Project A ID"
  value       =  module.project_a.project_id
}

output "project_a_number" {
  description = "Project A number"
  value       =  module.project_a.project_number
}

output "project_b_id" {
  description = "Project B ID"
  value       =  module.project_b.project_id
}

output "project_b_number" {
  description = "Project B number"
  value       =  module.project_b.project_number
}

# Network Outputs
output "network_name" {
  description = "VPC network name"
  value       = module.project_b_network.network_name
}

output "network_self_link" {
  description = "Network self link"
  value       = module.project_b_network.network_self_link
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.project_b_network.subnets_names[0]
}

output "subnet_self_link" {
  description = "Subnet self link"
  value       = module.project_b_network.subnets_self_links[0]
}

# GKE Cluster Outputs
output "cluster_name" {
  description = "GKE cluster name"
  value       = module.kubernetes-engine.name
}

output "cluster_endpoint" {
  description = "Cluster endpoint URL"
  value       = module.kubernetes-engine.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = module.kubernetes-engine.ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Cluster location"
  value       = module.kubernetes-engine.location
}

output "cluster_master_version" {
  description = "Cluster master version"
  value       = module.kubernetes-engine.master_version
}

# Service Account Outputs
output "cluster_service_account_email" {
  description = "GKE cluster service account email"
  value       = module.kubernetes-engine.service_account
}

output "workload_identity_service_account_email" {
  description = "Workload identity service account email"
  value       = module.gke-workload-identity.gcp_service_account_email
}

output "kubernetes_service_account_name" {
  description = "Kubernetes service account name"
  value       = module.gke-workload-identity.k8s_service_account_name
}

output "cluster_node_pools_versions" {
  description = "List of node pool versions"
  value       = module.kubernetes-engine.node_pools_versions
}

output "network_subnets_secondary_ranges" {
  description = "Secondary ranges for subnets"
  value       = module.project_b_network.subnets_secondary_ranges
}

# External Load Balancer Outputs
output "external_lb_ip" {
  description = "External Load Balancer IP address for public access"
  value       = module.gce-lb-http.external_ip
}

output "external_lb_url" {
  description = "External Load Balancer HTTPS URL"
  value       = "https://${module.gce-lb-http.external_ip}"
}

# Private Service Connect Outputs
output "psc_endpoint_ip" {
  description = "PSC endpoint IP in Project A"
  value       = google_compute_forwarding_rule.psc_endpoint.ip_address
}

output "psc_service_attachment_uri" {
  description = "PSC service attachment URI in Project B"
  value       = google_compute_service_attachment.psc_service_attachment.self_link
}

output "psc_connection_status" {
  description = "PSC connection status"
  value       = google_compute_forwarding_rule.psc_endpoint.psc_connection_status
}

# Cloud Armor
output "cloud_armor_policy_name" {
  description = "Cloud Armor security policy name"
  value       = module.cloud-armor.policy.name
}

output "cloud_armor_policy_link" {
  description = "Cloud Armor security policy self link"
  value       = module.cloud-armor.policy.self_link
}

# Project A Network
output "project_a_network_name" {
  description = "Project A VPC network name"
  value       = module.project_a_network.network_name
}

# Testing and Monitoring
output "test_commands" {
  description = "Useful commands for testing the setup"
  value = {
    curl_external_lb = "curl -v http://${module.gce-lb-http.external_ip}"
    curl_external_lb = "curl -vk https://${module.gce-lb-http.external_ip}"
    curl_with_blocked_country = "curl -v -H 'CF-IPCountry: CN' https://${module.gce-lb-http.external_ip}"
    check_psc_status = "gcloud compute forwarding-rules describe psc-endpoint-to-project-b --region=${var.project_a.region} --project=${module.project_a.project_id}"
    check_cloud_armor = "gcloud compute security-policies describe ${module.cloud-armor.policy.name} --project=${module.project_a.project_id}"
    kubectl_get_services = "kubectl get services -n ${var.kubernetes.namespace}"
  }
}

# Nginx Ingress Controller Internal Load Balancer IP
output "nginx_ingress_internal_ip" {
  description = "Nginx Ingress Controller Internal Load Balancer IP"
  value       = try(data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip, "pending")
}