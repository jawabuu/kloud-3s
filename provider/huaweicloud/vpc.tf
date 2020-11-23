resource "huaweicloud_vpc" "kube-hosts" {
  name = "kube-hosts"
  cidr = var.vpc_cidr
}

resource "huaweicloud_vpc_subnet" "kube-vpc" {
  name        = "kube-vpc"
  cidr        = var.vpc_cidr
  vpc_id      = huaweicloud_vpc.kube-hosts.id
  gateway_ip  = cidrhost(huaweicloud_vpc.kube-hosts.cidr, 1)
  dhcp_enable = false
}
