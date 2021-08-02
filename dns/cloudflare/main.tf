locals {
  zone_id = var.create_zone ? cloudflare_zone.kube[0].id : lookup(data.cloudflare_zones.domain_zones.zones[0], "id")
  zone    = var.cloudflare_zone == "" ? var.domain : var.cloudflare_zone
}

variable "node_count" {}

variable "email" {}

variable "api_token" {}

variable "cloudflare_zone" {
  default = ""
}

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

variable "create_zone" {
  type = bool
}

provider "cloudflare" {
  version = "~> 2.0"
  email   = var.email
  api_key = var.api_token
}


# Create a new domain/zone
resource "cloudflare_zone" "kube" {
  count = var.create_zone ? 1 : 0
  zone  = local.zone
}


data "cloudflare_zones" "domain_zones" {
  filter {
    name   = local.zone
    status = "active"
    paused = false
  }
}

resource "cloudflare_record" "hosts" {
  count = var.node_count

  zone_id = local.zone_id
  name    = element(var.hostnames, count.index)
  value   = element(var.public_ips, count.index)
  type    = "A"
  proxied = false
}

resource "cloudflare_record" "domain" {
  count   = var.trform_domain && var.node_count > 0 ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain
  value   = element(var.public_ips, 0)
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "wildcard" {
  depends_on = [cloudflare_record.domain]

  count   = var.trform_domain && var.node_count > 0 ? 1 : 0
  zone_id = local.zone_id
  name    = "*"
  value   = var.domain
  type    = "CNAME"
  proxied = false
}

output "domains" {
  value = cloudflare_record.hosts.*.hostname
}


output "dns_auth" {
  sensitive = true
  value = {
    provider  = "cloudflare"
    domain    = var.domain
    email     = var.email
    api_token = var.api_token
    zone_id   = local.zone_id
    zone      = local.zone
  }
}

output "trform_domain" {
  value = var.trform_domain
}
