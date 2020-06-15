/* general */
variable "node_count" {
  default = 3
}

/* etcd_node_count must be <= node_count; odd numbers provide quorum */
variable "etcd_node_count" {
  default = 3
}

variable "domain" {
  default = "kloud3s.io"
}

variable "hostname_format" {
  default = "kube%d"
}

variable "ssh_key_path" {
  default = "../../.ssh/tf-kube"
}

variable "ssh_pubkey_path" {
  default = "../../.ssh/tf-kube.pub"
}

variable "ssh_keys_dir" {
  default = "../../.ssh"
}

variable "k3s_version" {
  default = "latest"
}

variable "kubeconfig_path" {
  default = "../../.kubeconfig"
}

variable "create_zone" {
  default = false
}

variable "cni" {
  default = "cilium"
  description = "Choice of CNI to install e.g. flannel, weave, cilium, calico"
}

variable "overlay_cidr" {
  default = "10.42.0.0/16"
  description = "Cluster cidr"
}

/* scaleway */
variable "scaleway_organization_id" {
  default = ""
}

variable "scaleway_access_key" {
  default = "SCWXXXXXXXXXXXXXXXXX" // enables to specify only the secret_key
}

variable "scaleway_secret_key" {
  default = ""
}

variable "scaleway_zone" {
  default = "nl-ams-1"
}

variable "scaleway_type" {
  default = "DEV1-S"
}

variable "scaleway_image" {
  default = "ubuntu_focal"
}

/* digitalocean */
variable "digitalocean_token" {
  default = ""
}

/* aws dns */
variable "aws_access_key" {
  default = ""
}

variable "aws_secret_key" {
  default = ""
}

variable "aws_region" {
  default = "eu-west-1"
}

/* cloudflare dns */
variable "cloudflare_email" {
  default = ""
}

variable "cloudflare_api_token" {
  default = ""
}

/* google dns */
variable "google_project" {
  default = ""
}

variable "google_region" {
  default = ""
}

variable "google_managed_zone" {
  default = ""
}

variable "google_credentials_file" {
  default = ""
}
