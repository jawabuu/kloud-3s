variable "node_count" {}

variable "token" {}

variable "domain" {}

variable "hostnames" {
  type = list
}

variable "public_ips" {
  type = list
}

provider "digitalocean" {
  token = var.token
}

variable "create_zone" {
  type = bool
}

# Create a new domain/zone
resource "digitalocean_domain" "hobby-kube" {
  count  = var.create_zone ? 1 : 0
  name   = var.domain
}

locals{
  do_domain = var.create_zone ? digitalocean_domain.hobby-kube[0].name : var.domain
}

resource "digitalocean_record" "hosts" {
  count  = var.node_count

  domain = local.do_domain
  name   = element(var.hostnames, count.index)
  value  = element(var.public_ips, count.index)
  type   = "A"
  ttl    = 60
}

resource "digitalocean_record" "domain" {
  domain = local.do_domain
  name   = "@"
  value  = element(var.public_ips, 0) # Use LoadBalancer or Floating IP
  type   = "A"
  ttl    = 60
}

resource "digitalocean_record" "wildcard" {
  depends_on = [digitalocean_record.domain]

  domain = local.do_domain
  name   = "*.${local.do_domain}."
  value  = "@"
  type   = "CNAME"
  ttl    = 300
}

output "domains" {
  value = "${digitalocean_record.hosts.*.fqdn}"
}
