variable "node_count" {}

variable "project" {}

variable "region" {}

variable "creds_file" {}

variable "managed_zone" {}

variable "domain" {}

variable "hostnames" {
  type = list(any)
}

variable "public_ips" {
  type = list(any)
}

variable "trform_domain" {
  type        = bool
  default     = false
  description = "Manage the root and wildcard domain using this module."
}

provider "google" {
  credentials = file(var.creds_file)
  project     = var.project
  region      = var.region
}

resource "google_dns_record_set" "hosts" {
  count = var.node_count

  name         = "${element(var.hostnames, count.index)}.${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = var.managed_zone
  rrdatas      = ["${element(var.public_ips, count.index)}"]
}

resource "google_dns_record_set" "domain" {
  count        = var.trform_domain && var.node_count > 0 ? 1 : 0
  name         = "${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = var.managed_zone
  rrdatas      = ["${element(var.public_ips, 0)}"]
}

resource "google_dns_record_set" "wildcard" {
  depends_on = ["google_dns_record_set.domain"]

  count        = var.trform_domain && var.node_count > 0 ? 1 : 0
  name         = "*.${var.domain}."
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.managed_zone
  rrdatas      = ["${var.domain}."]
}

output "domains" {
  value = google_dns_record_set.hosts.*.name
}

output "dns_auth" {
  sensitive = true
  value = {
    provider    = "google"
    domain      = var.domain
    credentials = file(var.creds_file)
    project     = var.project
    region      = var.region
  }
}