resource "hcloud_network" "kube-vpc" {
  name     = "kube-vpc"
  ip_range = "10.115.0.0/20"
}

resource hcloud_network_subnet kube-hosts {
  type         = "server"
  network_id   = hcloud_network.kube-vpc.id
  network_zone = "eu-central"
  ip_range     = var.vpc_cidr
}

resource "hcloud_server_network" "kube-host-network" {
  count        =  var.hosts
  server_id    =  hcloud_server.host[count.index].id
  subnet_id    =  hcloud_network.kube-vpc.id
  ip           =  cidrhost(hcloud_network_subnet.kube-hosts.ip_range, count.index + 101)
}