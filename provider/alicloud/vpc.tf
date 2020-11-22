resource "alicloud_vpc" "kube-hosts" {
  name       = "kube-hosts"
  cidr_block = var.vpc_cidr
}

data "alicloud_zones" "default" {
  available_resource_creation = "VSwitch"
}

resource "alicloud_vswitch" "kube-vpc" {
  vpc_id            = alicloud_vpc.kube-hosts.id
  cidr_block        = var.vpc_cidr
  availability_zone = data.alicloud_zones.default.zones[0].id
}

resource "alicloud_nat_gateway" "gw" {
  vpc_id = alicloud_vswitch.kube-vpc.vpc_id
  name   = "kloud-3s"
}
