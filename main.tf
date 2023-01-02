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

########################################
# Traffic Director Backend Service
########################################

/*resource "google_compute_network_endpoint_group" "awsneg" {
  name                  = format("%s-%s", var.aws_resource_name_prefix, "neg")
  network               = var.networks
  default_port          = var.awsneg_ports
  zone                  = var.zone
  network_endpoint_type = var.aws_network_endpoint_type
}
resource "google_compute_network_endpoint_group" "gcpneg" {
  name                  = format("%s-%s", var.gcp_resource_name_prefix, "neg")
  network               = var.networks
  subnetwork            = var.subnets
  default_port          = var.gcpneg_ports
  zone                  = var.zone
  network_endpoint_type = var.gcp_network_endpoint_type
}
resource "google_compute_network_endpoint" "awsendpoint" {
  network_endpoint_group = google_compute_network_endpoint_group.awsneg.name
  port                   = google_compute_network_endpoint_group.awsneg.default_port
  ip_address             = var.aws_endpoint_ip
  zone                   = var.zone

}

resource "google_compute_backend_service" "awsservice" {
  name                  = format("%s-%s", var.aws_resource_name_prefix, "service")
  health_checks         = [google_compute_health_check.tdhealthcheck.id]
  load_balancing_scheme = var.load_balancing_schemes
  locality_lb_policy    = var.load_balancing_policy
  backend {
    group                 = google_compute_network_endpoint_group.awsneg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = var.max_rate_per_endpoint_compute
  }
}
resource "google_compute_backend_service" "gcpservice" {
  name                  = format("%s-%s", var.gcp_resource_name_prefix, "service")
  health_checks         = [google_compute_health_check.tdhealthcheck.id]
  load_balancing_scheme = var.load_balancing_schemes
  locality_lb_policy    = var.load_balancing_policy
  backend {
    group                 = google_compute_network_endpoint_group.gcpneg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = var.max_rate_per_endpoint_compute
  }
}

#########################################
# Traffic Director Health Check
#########################################
resource "google_compute_health_check" "tdhealthcheck" {
  provider = google-beta
  name     = "tdhealthcheck"
  http_health_check {
    port = var.ports
  }
}


############################################
#Traffic Director Routes
############################################
resource "google_compute_url_map" "tdroutes" {
  name            = "tdroutes"
  description     = "traffic director routes"
  default_service = google_compute_backend_service.awsservice.id

  host_rule {
    hosts        = [var.host_name]
    path_matcher = "allpaths"
  }
  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.awsservice.id

    route_rules {
      priority = var.route_priority
      match_rules {
        prefix_match = "/"
      }
      route_action {
        weighted_backend_services {
          backend_service = google_compute_backend_service.awsservice.id
          weight          = var.aws_weight
        }
        weighted_backend_services {
          backend_service = google_compute_backend_service.gcpservice.id
          weight          = var.gcp_weight
        }
      }
    }
  }
  test {
    service = google_compute_backend_service.awsservice.id
    host    = var.host_name
    path    = "/*"
  }
}

#############################################
# Target HTTP Proxy
#############################################
resource "google_compute_target_http_proxy" "fwproxy" {
  name    = "fwproxy"
  url_map = google_compute_url_map.tdroutes.id
}

##########################################
# Traffic Director Global Forwarding Rule
##########################################
resource "google_compute_global_forwarding_rule" "awsfwrule" {
  name                  = format("%s-%s", var.aws_resource_name_prefix, "fwrule")
  provider              = google
  network               = var.networks
  load_balancing_scheme = var.load_balancing_schemes
  port_range            = var.ports
  target                = google_compute_target_http_proxy.fwproxy.id
  ip_address            = var.awsfwrule_ip

}

resource "google_compute_global_forwarding_rule" "gcpfwrule" {
  name                  = format("%s-%s", var.gcp_resource_name_prefix, "fwrule")
  provider              = google
  network               = var.networks
  load_balancing_scheme = var.load_balancing_schemes
  port_range            = var.ports
  target                = google_compute_target_http_proxy.fwproxy.id
  ip_address            = var.gcpfwrule_ip

}*/


