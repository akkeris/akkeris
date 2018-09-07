provider "google" {
  credentials = "${file("account.json")}"
  project     = "${var.projectID}"
  region      = "${var.region}"
}

resource "google_project_services" "project" {
  project    = "${var.projectID}"
  services   = ["cloudapis.googleapis.com", "cloudkms.googleapis.com", "container.googleapis.com", "containerregistry.googleapis.com", "iam.googleapis.com"]
}

resource "google_container_cluster" "akkeris" {
  name               = "marcellus-wallace"
  zone               = "us-west1-a"
  initial_node_count = "${var.nodeCount}"
  additional_zones = [
    "us-west1-b"
  ]

  master_auth {
    username = "${var.clusterUsername}"
    password = "${var.clusterPassword}"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels {
      akkeris = "v1.0"
    }

    tags = ["foo", "bar"]
  }

  private_cluster = true
}

# The following outputs allow authentication and connectivity to the GKE Cluster.
output "client_certificate" {
  value = "${google_container_cluster.primary.master_auth.0.client_certificate}"
}

output "client_key" {
  value = "${google_container_cluster.primary.master_auth.0.client_key}"
}

output "cluster_ca_certificate" {
  value = "${google_container_cluster.primary.master_auth.0.cluster_ca_certificate}"
}