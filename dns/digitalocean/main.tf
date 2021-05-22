variable "node_count" {}

variable "token" {}

variable "domain" {}

variable "hostnames" {
  type = list(any)
}

variable "public_ips" {
  type = list(any)
}

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.8.0"
    }
  }
}

provider "digitalocean" {
  token = var.token
}

variable "create_zone" {
  type = bool
}

variable "trform_domain" {
  type        = bool
  default     = false
  description = "Manage the root and wildcard domain using this module."
}

# Create a new domain/zone
resource "digitalocean_domain" "hobby-kube" {
  count = var.create_zone ? 1 : 0
  name  = var.domain
}

locals {
  do_domain        = var.create_zone ? digitalocean_domain.hobby-kube[0].name : var.domain
  master_public_ip = length(var.public_ips) > 0 ? var.public_ips[0] : ""
}

resource "digitalocean_record" "hosts" {
  count = var.node_count

  domain = local.do_domain
  name   = element(var.hostnames, count.index)
  value  = element(var.public_ips, count.index)
  type   = "A"
  ttl    = 60
}

resource "digitalocean_record" "domain" {
  count  = var.trform_domain && var.node_count > 0 ? 1 : 0
  domain = local.do_domain
  name   = "@"
  value  = local.master_public_ip # Use LoadBalancer or Floating IP
  type   = "A"
  ttl    = 150
}

resource "digitalocean_record" "wildcard" {
  depends_on = [digitalocean_record.domain]

  count  = var.trform_domain && var.node_count > 0 ? 1 : 0
  domain = local.do_domain
  name   = "*.${local.do_domain}."
  value  = "@"
  type   = "CNAME"
  ttl    = 300
}

output "domains" {
  value = digitalocean_record.hosts.*.fqdn
}

output "dns_auth" {
  sensitive = true
  value = {
    domain   = var.domain
    provider = "digitalocean"
    token    = var.token
  }
}

output "trform_domain" {
  value = var.trform_domain
}