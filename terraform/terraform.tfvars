project_a = {
  name = "terraform-poc-projec-a"
  region  = "me-west1"
  zone    = "me-west1-a"
}

project_b = {
  name = "terraform-poc-projec-b"
  region  = "me-west1"
  zone    = "me-west1-a"
}

kubernetes = {
    namespace = "app-ns"
    workload_identity = "my-workload-identity"
    ip_range_pods = "pods-range"
    ip_range_services = "services-range"
    name = "terraform-poc"
}

vpc_a = {
  network = "main-network"
  subnet_name = "main-subnet"
  subnet_cidr = "10.0.0.0/16"
}

vpc_b = { 
  network = "main-network"
  subnet_name = "main-subnet"
  subnet_cidr = "10.0.0.0/16"
  pods_cidr = "10.1.0.0/16"
  services_cidr = "10.2.0.0/16"
  psc_subnet_name   = "psc-nat-subnet"
  psc_subnet_ip     = "10.3.0.0/28" 

}

private_key_path = "../dummy_certs/private-key.pem"
certificate_path = "../dummy_certs/certificate.pem"

billing_account = "<BILLING_ACC_ID>"

