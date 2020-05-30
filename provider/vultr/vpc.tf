resource "vultr_network" "kube-vpc" {
    description = "kube-vpc"
    region_id   = var.region_id
    cidr_block  = "10.115.0.0/24"
}