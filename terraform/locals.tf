locals {
  subnet = [
    {
      subnet_name   = var.vpc.subnet_name
      subnet_ip     = var.vpc.subnet_cidr
      subnet_region = var.project_b.region
      secondary_ranges = [
        {
          range_name    = var.kubernetes.ip_range_pods
          ip_cidr_range = var.vpc.pods_cidr
        },
        {
          range_name    = var.kubernetes.ip_range_services
          ip_cidr_range = var.vpc.services_cidr
        }
      ]
    }
  ]
}
