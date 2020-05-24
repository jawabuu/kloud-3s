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

# Create a new domain/zone
resource "digitalocean_domain" "hobby-kube" {
  name  = var.domain
}

resource "digitalocean_record" "hosts" {
  count = var.node_count

  domain = digitalocean_domain.hobby-kube.name
  name   = element(var.hostnames, count.index)
  value  = element(var.public_ips, count.index)
  type   = "A"
  ttl    = 60
}

resource "digitalocean_record" "domain" {
  domain = digitalocean_domain.hobby-kube.name
  name   = "@"
  value  = element(var.public_ips, 0) # Use LoadBalancer or Floating IP
  type   = "A"
  ttl    = 60
}

resource "digitalocean_record" "wildcard" {
  depends_on = [digitalocean_record.domain]

  domain = digitalocean_domain.hobby-kube.name
  name   = "*.${digitalocean_domain.hobby-kube.name}."
  value  = "@"
  type   = "CNAME"
  ttl    = 300
}

output "domains" {
  value = "${digitalocean_record.hosts.*.fqdn}"
}
