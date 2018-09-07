resource "google_dns_managed_zone" "akkeris" {
  name        = "akkeris"
  dns_name    = "prod.mydomain.com."
  description = "Production DNS zone"
}