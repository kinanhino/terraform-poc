module "kubernetes-engine" {
    source  = "terraform-google-modules/kubernetes-engine/google"
    version = "37.0.0"
    ip_range_pods = var.kubernetes.ip_range_pods
    ip_range_services = var.kubernetes.ip_range_services
    name = var.kubernetes.name
    network = module.project_b_network.network_name
    project_id = module.project_b.project_id
    subnetwork = module.project_b_network.subnets_names[0]
    region = var.project_b.region
    zones = [var.project_b.zone]
    remove_default_node_pool = true
    initial_node_count = 1
    deletion_protection = false
    
    node_pools = [
      {
        name         = "default-pool"
        machine_type = "e2-standard-4"
        min_count    = 1
        max_count    = 2
        disk_size_gb = 100
        disk_type    = "pd-standard"
        auto_repair  = true
        auto_upgrade = true
        preemptible  = false
      }
    ]
    
    depends_on = [
    google_project_service.project_b_container,
  ]
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.kubernetes.namespace
  }
  depends_on = [module.kubernetes-engine]
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
  depends_on = [module.kubernetes-engine]
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata.0.name

  values = [
    yamlencode({
      controller = {
        service = {
          annotations = {
            "networking.gke.io/load-balancer-type" = "Internal"
          }
        }
      }
    })
  ]
  
  # Wait for the chart to be fully deployed
  wait = true
  timeout = 600
  
  depends_on = [module.kubernetes-engine, kubernetes_namespace.ingress_nginx]
}

module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                = var.kubernetes.workload_identity
  namespace           = kubernetes_namespace.app_namespace.metadata[0].name
  project_id          = module.project_b.project_id
  roles               = ["roles/storage.admin", "roles/compute.admin"]
  additional_projects = {(module.project_a.project_id) : ["roles/storage.admin", "roles/compute.admin"]}

  depends_on = [
    module.kubernetes-engine,
    kubernetes_namespace.app_namespace
  ]
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "terraform-example"
    namespace  = kubernetes_namespace.app_namespace.metadata[0].name
    labels = {
      app = "MyApp"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "MyApp"
      }
    }

    template {
      metadata {
        labels = {
          app = "MyApp"
        }
      }

      spec {
        container {
          image = "tiangolo/uwsgi-nginx-flask:python3.8"
          name  = "example"

          liveness_probe {
            http_get {
              path = "/health"
              port = 80
            }

            initial_delay_seconds = 10
            period_seconds        = 10
          }

          volume_mount {
            name = "config-volume"
            mount_path = "/app"
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.example.metadata.0.name
          }
        }
      }
    }
  }
  depends_on = [ kubernetes_namespace.app_namespace,
              kubernetes_config_map.example
              ]
}

resource "kubernetes_service" "example" {
  metadata {
    name = "terraform-example"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.example.metadata.0.labels.app
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
  depends_on = [ kubernetes_namespace.app_namespace ]
}

resource "kubernetes_config_map" "example" {
  metadata {
    name = "my-config"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  data = {
    "main.py" = <<EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from prebuilt Flask image!"

@app.route('/health')
def health():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF
    "uwsgi.ini" = <<EOF
[uwsgi]
module = main
callable = app
uid = 1000
gid = 2000
master = true
processes = 5
socket = /tmp/uwsgi.sock
chown-socket = nginx:nginx
chmod-socket = 664
vacuum = true
die-on-term = true
EOF
  }
  depends_on = [ kubernetes_namespace.app_namespace ]
}

resource "kubernetes_secret" "tls_secret" {
    metadata {
      name = "tls-secret"
      namespace = kubernetes_namespace.app_namespace.metadata[0].name
    }

    type = "kubernetes.io/tls"

    data = {
      "tls.crt" = base64encode(file("dummy_certs/certificate.pem"))
      "tls.key" = base64encode(file("dummy_certs/private-key.pem"))
    }
    depends_on = [ kubernetes_namespace.app_namespace ]
  }

resource "kubernetes_ingress_v1" "example_ingress" {
  metadata {
    name = "example-ingress"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service {
              name = "terraform-example"
              port {
                number = 80
              }
            }
          }

          path = "/"
          path_type = "Prefix"
        }
      }
    }

    tls {
      secret_name = "tls-secret"
    }
  }
  depends_on = [ kubernetes_namespace.app_namespace, kubernetes_service.example, helm_release.nginx_ingress ]
}