# Main Terraform configuration for Terraform POC
# External LB (Project A) -> Proxy VM -> PSC -> internal LB (Project B) -> GKE -> nginx ingress -> Flask app

# This file orchestrates the overall infrastructure
# Specific resources are organized in separate files:
# - projects.tf: Project creation and APIs
# - networking.tf: VPCs, subnets, PSC configuration  
# - kubernetes.tf: GKE cluster, applications, ingress
# - compute.tf: Proxy VMs and instance groups
# - loadbalancer.tf: External LB and Cloud Armor
# - locals.tf: Data sources and computed values