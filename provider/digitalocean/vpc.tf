resource "digitalocean_vpc" "kube-vpc"{
    # The human friendly name of our VPC.
    name = "kube-vpc"

    # The region to deploy our VPC to.
    region = var.region

    # The private ip range within our VPC
    ip_range = var.vpc_cidr
}