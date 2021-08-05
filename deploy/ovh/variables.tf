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
  default = "../../.ssh/kubeconfig"
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

variable "trform_domain" {
  type        = bool
  default     = false
  description = "Manage this domain and it's wildcard domain using terraform."
}

variable "test-traefik" {
  type        = bool
  default     = true
  description = "Deploy traefik test."
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
    kubernetes_dashboard = true
    kube_prometheus      = false
    k8dash               = false
    elastic_cloud        = false
    longhorn             = false
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

/* ovh */
variable "tenant_name" {
  type        = string
  description = "The Name of the Tenant (Identity v2) or Project (Identity v3) to login with"
}

variable "user_name" {
  type        = string
  description = "The Username to login with"
}

variable "password" {
  type        = string
  description = "The Password to login with"
}

variable "auth_url" {
  default     = "https://auth.cloud.ovh.net/v3"
  description = "The Identity authentication URL"
}

variable "application_key" {
  type        = string
  description = "The API Application Key"
  default     = ""
}

variable "application_secret" {
  type        = string
  description = "The API Application Secret"
  default     = ""
}

variable "consumer_key" {
  type        = string
  description = "The API Consumer key"
  default     = ""
}

variable "endpoint" {
  default     = "ovh-ca"
  description = "The API endpoint to use"
}

variable "ovh_ssh_keys" {
  type    = list(string)
  default = [""]
}

variable "region" {
  default     = "BHS5"
  description = "The region of the OpenStack cloud to use"
}

variable "ovh_type" {
  default     = "s1-2"
  description = "Server type e.g. s1-2, s1-4, s1-8"
}

variable "ovh_image" {
  default = "Ubuntu 20.04"
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
