resource "vultr_network" "kube-vpc" {
  description = "kube-vpc-${time_static.id.unix}"
  region_id   = data.vultr_region.region.id
  cidr_block  = var.vpc_cidr
}