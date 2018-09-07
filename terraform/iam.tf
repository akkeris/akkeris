resource "google_service_account" "letsencrypt" {
  account_id   = "letsencrypt"
  display_name = "letsencrypt"
}

resource "google_service_account_key" "letsencrypt" {
  service_account_id = "${google_service_account.letsencrypt.name}"
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "kubernetes_secret" "letsecnrypt" {
  metadata {
    name = "clouddns-svc-acct-secret"
  }
  data {
    credentials.json = "${base64decode(google_service_account_key.letsencrypt.private_key)}"
  }
}

resource "google_project_iam_binding" "project" {
  project = "${var.projectID}"
  role    = "roles/owner"

  members = [
    "serviceAccount:letsencrypt@${PROJECT_ID}.iam.gserviceaccount.com",
  ]
}

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = "${google_service_account.letsencrypt.name}"
  role               = "roles/owner"

  members = [
    "user:${var.email}",
  ]
}

