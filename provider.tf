terraform {
  required_version = ">= 1.1.0"

  required_providers {
    // use minimum version pinning in modules. see https://www.terraform.io/docs/language/expressions/version-constraints.html#terraform-core-and-provider-versions

    google = {
      source  = "hashicorp/google"
      version = ">= 4.18.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.18.0"
    }
    
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.1"
    }

  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {
  depends_on = [google_container_cluster.traffic-director-cluster]
}

# Defer reading the cluster data until the GKE cluster exists.
data "google_container_cluster" "default" {
  name       = "traffic-director-cluster"
  location   = "us-central1-a"
  depends_on = [google_container_cluster.traffic-director-cluster]
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.default.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
  )
}
