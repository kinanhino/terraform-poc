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
  value       = module.network.network_name
}

output "network_self_link" {
  description = "Network self link"
  value       = module.network.network_self_link
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.network.subnets_names[0]
}

output "subnet_self_link" {
  description = "Subnet self link"
  value       = module.network.subnets_self_links[0]
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
  value       = module.my-app-workload-identity.gcp_service_account_email
}

output "kubernetes_service_account_name" {
  description = "Kubernetes service account name"
  value       = module.my-app-workload-identity.k8s_service_account_name
}

# Additional Useful Outputs
output "cluster_min_master_version" {
  description = "Minimum master version"
  value       = module.kubernetes-engine.min_master_version
}

output "cluster_node_pools_names" {
  description = "List of node pool names"
  value       = module.kubernetes-engine.node_pools_names
}

output "cluster_node_pools_versions" {
  description = "List of node pool versions"
  value       = module.kubernetes-engine.node_pools_versions
}

output "network_subnets_secondary_ranges" {
  description = "Secondary ranges for subnets"
  value       = module.network.subnets_secondary_ranges
}

# output "load_balancer_ip" {
#   value = kubernetes_ingress_v1.example.status.0.load_balancer.0.ingress.0.ip
# }