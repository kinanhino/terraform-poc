project_a = {
  name = "tf-project-a"
}

project_b = {
  name = "tf-project-b"
  region  = "me-west1"
  zone    = "me-west1-a"
}

kubernetes = {
    namespace = "app_ns"
    workload_identity = "my-workload-identity"
    ip_range_pods = "pods-range"
    ip_range_services = "services-range"
    name = "terraform-poc"
}

vpc = {
  network = "main-network"
  subnet_name = "main-subnet"
  subnet_cidr = "10.0.0.0/16"
  pods_cidr = "10.1.0.0/16"
  services_cidr = "10.2.0.0/16"
}


billing_account = "015DDE-9D4D6C-9AA531"