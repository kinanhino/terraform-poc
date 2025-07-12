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
  })
}

variable "vpc_a" {
  description = "project a vpc configuration with subnetworks"
  type = object({
    network    = string
    subnet_name = string
    subnet_cidr = string
  })
}

variable "vpc_b" {
  description = "proejct b vpc configuration with subnetworks"
  type = object({
    network    = string
    subnet_name = string
    subnet_cidr = string
    pods_cidr = string
    services_cidr = string
    psc_subnet_name = string
    psc_subnet_ip = string
  })
}