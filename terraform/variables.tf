variable project_a {
    type = map(string)	
}

variable project_b {
    type = map(string)	
}

variable billing_account {
    type = string
}

variable kubernetes {
    type = object({
    namespace                = string
    workload_identity        = string
    ip_range_pods = string
    ip_range_services = string
    name = string

    # perimeter_name        = bool
    # resources             = list(string)
    # restricted_services   = list(string)
    # access_levels         = list(string)
  })
}

variable "vpc" {
  description = "VPC configuration with subnetworks"
  type = object({
    network    = string
    subnet_name = string
    subnet_cidr = string
    pods_cidr = string
    services_cidr = string
  })
}