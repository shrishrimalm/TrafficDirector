########################################
# Enable API for Traffic Director
########################################

resource "google_project_service" "trafficdirector" {
  project = var.project_id
  service = "trafficdirector.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
  disable_on_destroy         = false
}

####################################################################
# Enabling the service account to access the Traffic Director API
##################################################################
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

resource "google_project_iam_binding" "compute_networkViewer" {
  project = var.project_id
  role    = "roles/compute.networkViewer"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}

resource "google_project_iam_binding" "trafficdirector_client" {
  project = var.project_id
  role    = "roles/trafficdirector.client"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}
###################################
#Creating Zonal GKE Public Cluster
#####################################

resource "google_container_cluster" "traffic-director-cluster" {
  name     = "traffic-director-cluster"
  location = "us-central1-a"
  initial_node_count = 3
  node_config {
    disk_size_gb = 10
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  } 
  ip_allocation_policy {}
  timeouts {
    create = "30m"
    update = "40m"
  }
}

#####################################################
# Pointing kubectl to the newly created cluster
####################################################

resource "null_resource" "get_credentials" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials traffic-director-cluster --zone us-central1-a"
  }
  depends_on = [
    google_container_cluster.traffic-director-cluster
  ]
}

#####################################################
# Configuring TLS for the sidecar injector
####################################################

resource "null_resource" "secret_ns_creation" {
  provisioner "local-exec" {
    command = "kubectl apply -f td-sidecar-injector-xdsv3/specs/00-namespaces.yaml"
  }
  depends_on = [
    null_resource.get_credentials
  ]
}

##############################################
# Create the secret for the sidecar injector.
#############################################

resource "kubernetes_secret" "istio-sidecar-injector" {
  metadata {
    name      = "istio-sidecar-injector"
    namespace = "istio-control"
  }
  data = {
    "key.pem"      = "${file("td-sidecar-injector-xdsv3/key.pem")}"
    "cert.pem"     = "${file("td-sidecar-injector-xdsv3/cert.pem")}"
    "ca-cert.pem"  = "${file("td-sidecar-injector-xdsv3/ca-cert.pem")}"
  }
  type = "Opaque"
  depends_on = [
    null_resource.secret_ns_creation
  ]
}

##############################################
# Deploy the sidecar injector
#############################################

resource "null_resource" "deploy_sidecar_injector" {
  provisioner "local-exec" {
    command = "kubectl apply -f td-sidecar-injector-xdsv3/specs"
  }
  depends_on = [
    kubernetes_secret.istio-sidecar-injector
  ]
}

##############################################
# Enabling sidecar injection
#############################################

resource "null_resource" "enable_sidecar_injector" {
  provisioner "local-exec" {
    command = "kubectl label namespace default istio-injection=enabled"
  }
  depends_on = [
    null_resource.deploy_sidecar_injector
  ]
}
###################################################
# Deploying a sample client and verifying injection
###################################################

resource "null_resource" "deploy_sample_client" {
  provisioner "local-exec" {
    command = "kubectl create -f td-sidecar-injector-xdsv3/demo/client_sample.yaml"
  }
  depends_on = [
    null_resource.enable_sidecar_injector
  ]
}

##############################################
# Deploying a Kubernetes service for testing
##############################################

resource "null_resource" "deploy_kubernetes_service" {
  provisioner "local-exec" {
    command = "kubectl create -f td-sidecar-injector-xdsv3/demo/trafficdirector_service_sample.yaml"
  }
  depends_on = [
    null_resource.deploy_sample_client
  ]
}

#########################################
# Traffic Director Health Check
#########################################

resource "google_compute_health_check" "td-gke-health-check" {
  name     = "td-gke-health-check"
  http_health_check {
    port = "80"
  }
}

##############################################################
# Firewall rule to allow the health checker IP address ranges
##############################################################

resource "google_compute_firewall" "fw-allow-health-checks" {
  name          = "fw-allow-health-checks"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  allow {
    protocol = "tcp"
  }
}

############################################################################################
# Create the backend service and associate the health check and NEG with the backend service
############################################################################################

data "google_compute_network_endpoint_group" "gcpneg" {
  project = var.project_id
  name    = "service-test-neg"
  zone    = "us-central1-a"
  depends_on = [
    null_resource.deploy_kubernetes_service
  ]
}

resource "google_compute_backend_service" "td-gke-service" {
  name                  = "td-gke-service"
  health_checks         = [google_compute_health_check.td-gke-health-check.id]
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  backend {
    group                 = data.google_compute_network_endpoint_group.gcpneg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 5
  }
  depends_on = [
    google_compute_health_check.td-gke-health-check
  ]
}

########################################################################
# URL map that uses td-gke-service as the default backend service
#########################################################################

resource "google_compute_url_map" "td-gke-url-map" {
  name            = "td-gke-url-map"
  default_service = google_compute_backend_service.td-gke-service.id

  host_rule {
    hosts        = ["service-test"]
    path_matcher = "td-gke-path-matcher"
  }

  path_matcher {
    name            = "td-gke-path-matcher"
    default_service = google_compute_backend_service.td-gke-service.id
  }

  depends_on = [
    google_compute_backend_service.td-gke-service
  ]
}

#############################################
# Target HTTP Proxy
#############################################

resource "google_compute_target_http_proxy" "td-gke-proxy" {
  name    = "td-gke-proxy"
  url_map = google_compute_url_map.td-gke-url-map.id
  depends_on = [
    google_compute_url_map.td-gke-url-map
  ]
}

#############################################
# Global Forwarding Rule
#############################################

resource "google_compute_global_forwarding_rule" "td-gke-forwarding-rule" {
  name                  = "td-gke-forwarding-rule"
  target                = google_compute_target_http_proxy.td-gke-proxy.id
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  port_range            = "80"
  ip_address            = "0.0.0.0"
  network               = "default"
  depends_on = [
    google_compute_target_http_proxy.td-gke-proxy
  ]
}

#############################################################