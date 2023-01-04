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
# Creating Zonal GKE Cluster
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
  /*private_cluster_config {
    #enable_private_endpoint = true
    enable_private_nodes = true
    master_ipv4_cidr_block     = "10.0.0.0/28"
  }*/
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
# Opening required port on a private cluster
####################################################
/*
resource "null_resource" "update_firewall_rule" {
  provisioner "local-exec" {
    command = "gcloud compute firewall-rules update gke-traffic-director-cluster-ae978e47-master --allow tcp:10250,tcp:443,tcp:9443"
  }
  depends_on = [
    null_resource.get_credentials
  ]
}*/

############################################
#  Configuring the sidecar injector
############################################

resource "null_resource" "replace_project_number" {
  provisioner "local-exec" {
    command = "sed -i 's/your-project-here/629996305394/g' '${path.module}/td-sidecar-injector-xdsv3/specs/01-configmap.yaml'"
  }
}

resource "null_resource" "replace_network_value" {
  provisioner "local-exec" {
    command = " sed -i 's/your-network-here/default/g' '${path.module}/td-sidecar-injector-xdsv3/specs/01-configmap.yaml' "
  }
  depends_on = [
    null_resource.replace_project_number
  ]
}


#####################################################
# Configuring TLS for the sidecar injector
####################################################

resource "tls_private_key" "privatekey" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "key_pem" {
  content  = "${tls_private_key.privatekey.private_key_pem}"
  filename = "${path.module}/td-sidecar-injector-xdsv3/key.pem"
}

resource "tls_self_signed_cert" "cakey" {
  private_key_pem   = "${tls_private_key.privatekey.private_key_pem}"
  is_ca_certificate = true
  
  dns_names = ["istio-sidecar-injector.istio-control.svc"]

  subject {
    common_name         = "istio-sidecar-injector.istio-control.svc"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  depends_on = [
    tls_private_key.privatekey
  ]
}

resource "local_file" "ca_key" {
  content  = "${tls_self_signed_cert.cakey.cert_pem}"
  filename = "${path.module}/td-sidecar-injector-xdsv3/cert.pem"
}

resource "local_file" "ca_cert" {
  content  = "${tls_self_signed_cert.cakey.cert_pem}"
  filename = "${path.module}/td-sidecar-injector-xdsv3/ca-cert.pem"
  depends_on = [
    tls_self_signed_cert.cakey
  ]
}

############################################################################
# Create the namespace under which the Kubernetes secret should be created
############################################################################

resource "null_resource" "secret_ns_creation" {
  provisioner "local-exec" {
    command = "kubectl apply -f td-sidecar-injector-xdsv3/specs/00-namespaces.yaml"
  }
  depends_on = [
    local_file.ca_cert,
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
    null_resource.secret_ns_creation,
    local_file.ca_cert,
    local_file.ca_key,
    local_file.key_pem
  ]
}

##############################################
# Modify the caBundle of the sidecar injection
##############################################

# Base64-encode the contents of the cert.pem file
data "local_file" "cert" {
  filename = "${path.module}/td-sidecar-injector-xdsv3/cert.pem"
}

locals {
  ca_bundle = "${base64encode(data.local_file.cert.content)}"
}

resource "null_resource" "replace_caBundle" {
  provisioner "local-exec" {
    command = " sed -i 's/caBundle:.*/caBundle: ${local.ca_bundle}/g' '${path.module}/td-sidecar-injector-xdsv3/specs/02-injector.yaml' "
  }
}

##############################################
# Deploy the sidecar injector
#############################################

resource "null_resource" "deploy_sidecar_injector" {
  provisioner "local-exec" {
    command = "kubectl apply -f td-sidecar-injector-xdsv3/specs"
  }
  depends_on = [
    kubernetes_secret.istio-sidecar-injector,
    null_resource.get_credentials
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
    port = "443"
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
