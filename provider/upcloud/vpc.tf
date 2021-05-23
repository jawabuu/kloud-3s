resource "upcloud_router" "kube-router" {
  name = "kube-router-${time_static.id.unix}"
}

resource "upcloud_network" "kube-vpc" {
  name = "kube-vpc-${time_static.id.unix}"
  zone = var.location

  router = upcloud_router.kube-router.id

  ip_network {
    address            = var.vpc_cidr
    dhcp               = true
    dhcp_default_route = false
    family             = "IPv4"
  }
}
