variable "auth_token" {}

variable "hosts" {
  default = 3
}

variable "project_id" {
  default = ""
}

variable "facility" {
  default = ""
}

variable "operating_system" {
  default = ""
}

variable "billing_cycle" {
  default = "hourly"
}

variable "plan" {
  type = string
}

variable "apt_packages" {
  type    = list
  default = []
}

variable "user_data" { default = "" }

variable "hostname_format" {
  default = ""
}

variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

resource "time_static" "id" {}

provider "packet" {
  auth_token = var.auth_token
}

resource "packet_project_ssh_key" "tf-kube" {
  name       = "tf-kube-${time_static.id.unix}"
  public_key = file("${var.ssh_pubkey_path}")
  project_id = local.project_id

  lifecycle {
    ignore_changes = [
      public_key
    ]
  }
}

resource "packet_device" "host" {
  count            = var.hosts
  hostname         = format(var.hostname_format, count.index + 1)
  plan             = var.plan
  facilities       = var.facility
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.project_id
  user_data        = var.user_data
  ssh_keys         = [packet_project_ssh_key.tf-kube.id]

  connection {
    user    = "root"
    type    = "ssh"
    timeout = "2m"
    host    = self.access_public_ipv4
    private_key = file("${var.ssh_key_path}")
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -yq apt-transport-https ufw wireguard-tools wireguard ${join(" ", var.apt_packages)}",
      # fix a problem with later wireguard installation
      "DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::=--force-confnew sudo",
    ]
  }
}

output "public_ips" {
  value = "${packet_device.host.*.access_public_ipv4}"
}

output "hostnames" {
  value = "${packet_device.host.*.hostname}"
}

output "private_ips" {
  value = "${packet_device.host.*.access_private_ipv4}"
}

output "public_network_interface" {
  value = "bond0"
}

output "private_network_interface" {
  value = "bond0"
}

output "region" {
  value = var.facility
}

output "nodes" {

  value = [for index, server in packet_device.host : {
    hostname   = server.name
    public_ip  = server.access_public_ipv4
    private_ip = server.access_private_ipv4
  }]

}