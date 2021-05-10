data "openstack_networking_network_v2" "public" {
  name = "Ext-Net"
}

resource "openstack_networking_port_v2" "public" {
  count          = var.hosts
  name           = format(var.hostname_format, count.index + 1)
  network_id     = data.openstack_networking_network_v2.public.id
  admin_state_up = true
}

resource "openstack_networking_network_v2" "kube-vpc" {
  name           = "kube-vpc"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "kube-hosts" {
  name       = "kube-hosts"
  network_id = openstack_networking_network_v2.kube-vpc.id
  cidr       = var.vpc_cidr
  ip_version = 4
}

resource "openstack_networking_port_v2" "kube-host-network" {
  count          = var.hosts
  name           = "kube-host-${count.index}"
  network_id     = openstack_networking_network_v2.kube-vpc.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.kube-hosts.id
    ip_address = cidrhost(openstack_networking_subnet_v2.kube-hosts.cidr, count.index + 101)
  }
}
