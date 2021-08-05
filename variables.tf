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

variable "trform_domain" {
  type        = bool
  default     = false
  description = "Manage this domain and it's wildcard domain using terraform."
}

variable "hostname_format" {
  default = "kube%d"
}

variable "ssh_key_path" {
  default = "./.ssh/tf-kube"
}

variable "ssh_pubkey_path" {
  default = "./.ssh/tf-kube.pub"
}

variable "ssh_keys_dir" {
  default = "./.ssh"
}

variable "k3s_version" {
  default = "latest"
}

variable "kubeconfig_path" {
  default = "./.kubeconfig"
}

variable "create_zone" {
  default = false
}

variable "cni" {
  default     = "cilium"
  description = "Choice of CNI to install e.g. flannel, weave, cilium, calico"
}

variable "overlay_cidr" {
  default     = "10.42.0.0/16"
  description = "Cluster pod cidr"
}

variable "service_cidr" {
  default     = "10.43.0.0/16"
  description = "Cluster service cidr"
}

variable "vpc_cidr" {
  default     = "10.115.0.0/24"
  description = "CIDR for nodes provider vpc if available"
}

variable "vpn_iprange" {
  default     = "10.0.1.0/24"
  description = "CIDR for nodes wireguard vpn"
}

variable "ha_cluster" {
  default     = false
  description = "Create highly available cluster. Currently experimental and requires node_count >= 3"
}

variable "create_certs" {
  type        = bool
  default     = false
  description = "Option to create letsencrypt certs. Only enable if certain that your deployment is reachable."
}

variable "ha_nodes" {
  default     = 3
  description = "Number of controller nodes for HA cluster. Must be greater than 3 and odd-numbered."
}

variable "install_app" {
  description = "Additional apps to Install"
  type        = map(any)
  default = {
    kubernetes_dashboard = true,
    longhorn             = true,
    vault                = false,
    trow                 = false,
    superset             = false,
    sentry               = false,
    kube_prometheus      = false,
    elastic_cloud        = false,
  }
}

variable "additional_rules" {
  type        = list(string)
  default     = []
  description = "add custom firewall rules during provisioning e.g. allow 1194/udp, allow ftp"
}

variable "auth_user" {
  default     = "kloud-3s"
  description = "Traefik basic auth username"
}

variable "auth_password" {
  default     = ""
  description = "Traefik basic auth password"
}

variable "loadbalancer" {
  default     = "metallb"
  description = "How LoadBalancer IPs are assigned. Options are metallb(default), traefik, ccm, kube-vip & akrobateo"
}

variable "registry_user" {
  default     = "kloud-3s"
  description = "Trow Registry username"
}

variable "registry_password" {
  default     = ""
  description = "Trow Registry password"
}

variable "apt_packages" {
  type        = list(any)
  default     = []
  description = "Additional packages to install"
}

variable "oidc_config" {
  type        = list(map(string))
  description = "OIDC Configuration for protecting private resources. Used by Pomerium IAP & Vault."
  default     = []
}

variable "mail_config" {
  type        = map(string)
  description = "SMTP Configuration for email services."
  default     = {}
}

variable "s3_config" {
  type        = map(string)
  description = "S3 config for backups and other storage needs."
  default     = {}
}

variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size in GB"
}

variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

/* upcloud */
variable "upcloud_username" {
  default = ""
}

variable "upcloud_password" {
  default = ""
}

variable "upcloud_ssh_keys" {
  default = [""]
}

variable "upcloud_zone" {
  default = "uk-lon1"
}

variable "upcloud_plan" {
  default = "1xCPU-1GB"
}

variable "upcloud_image" {
  default = "Ubuntu Server 20.04 LTS (Focal Fossa)"
}

/* linode */
variable "linode_token" {
  default = ""
}

variable "linode_ssh_keys" {
  type    = list(string)
  default = [""]
}

variable "linode_region" {
  default = "eu-central"
}

variable "linode_type" {
  default = "g6-nanode-1"
}

variable "linode_image" {
  default = "linode/ubuntu18.04"
}

/* vultr */
variable "vultr_api_key" {
  default = ""
}

variable "vultr_ssh_keys" {
  type    = list(string)
  default = [""]
}

variable "vultr_region" {
  default = "New Jersey"
}

variable "vultr_plan" {
  default = "1024 MB RAM,25 GB SSD,1.00 TB BW"
}

variable "vultr_os" {
  default = "Ubuntu 18.04 x64"
}

/* hcloud */
variable "hcloud_token" {
  default = ""
}

variable "hcloud_ssh_keys" {
  type    = list(string)
  default = [""]
}

variable "hcloud_location" {
  default = "nbg1"
}

variable "hcloud_type" {
  default = "cx11"
}

variable "hcloud_image" {
  default = "ubuntu-18.04"
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
  default = "Ubuntu Bionic"
}

/* digitalocean */
variable "digitalocean_token" {
  default = ""
}

variable "digitalocean_ssh_keys" {
  type    = list(string)
  default = [""]
}

variable "digitalocean_region" {
  default = "fra1"
}

variable "digitalocean_size" {
  default = "s-1vcpu-1gb"
}

variable "digitalocean_image" {
  default = "ubuntu-18-04-x64"
}

/* packet */

variable "packet_auth_token" {
  default = ""
}

variable "packet_project_id" {
  default = ""
}

variable "packet_plan" {
  default = "c1.small.x86"
}

variable "packet_facility" {
  default = "sjc1"
}

variable "packet_operating_system" {
  default = "ubuntu_18_04"
}

variable "packet_billing_cycle" {
  default = "hourly"
}

variable "packet_user_data" {
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

variable "cloudflare_zone" {
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

/* vsphere */

variable "vsphere_server" {
  description = "vsphere server for the environment - EXAMPLE: vcenter01.hosted.local or IP address"
  default     = ""
}

variable "vsphere_datacenter" {
  description = "vSphere Datacenter Name"
  default     = "Datacenter1"
}

variable "vsphere_cluster" {
  description = "vSphere Cluster Name"
  default     = "Cluster1"
}

variable "vsphere_network" {
  description = "vSphere Network Name"
  default     = "VM Network"
}

variable "vsphere_datastore" {
  description = "vSphere Datastore Name"
  default     = "datastore1"
}

variable "vsphere_vm_template" {
  description = "vSphere VM Template Name"
  default     = "tpl-ubuntu-1804"
}

variable "vsphere_vm_linked_clone" {
  description = "create vsphere linked clone VM"
  default     = false
}

variable "vsphere_vm_num_cpus" {
  description = "Number of CPUs for the VM"
  default     = "2"
}

variable "vsphere_vm_memory" {
  description = "Amount of memory for the VM"
  default     = "2048"
}

variable "vsphere_user" {
  description = "vSphere Admin Username"
  default     = "administrator@vsphere.local"
}

variable "vsphere_password" {
  description = "vSphere Admin Password"
  default     = "YourSecretPassword"
}