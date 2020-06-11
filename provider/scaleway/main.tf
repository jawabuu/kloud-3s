variable "organization_id" {}

variable "access_key" {}

variable "secret_key" {}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type = string
}

variable "zone" {
  type = string
}

variable "type" {
  type = string
}

variable "image" {
  type = string
}

variable "apt_packages" {
  type    = list
  default = []
}

variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

resource "scaleway_account_ssh_key" "tf-kube" {
    count      = fileexists("${var.ssh_pubkey_path}") ? 1 : 0
    name       = "tf-kube"
    public_key = file("${var.ssh_pubkey_path}")
}

provider "scaleway" {
  organization_id = var.organization_id
  access_key      = var.access_key
  secret_key      = var.secret_key
  zone            = var.zone
  version         = ">= 1.14"
}

resource "scaleway_instance_server" "host" {
  name                = format(var.hostname_format, count.index + 1)
  type                = var.type
  image               = data.scaleway_instance_image.image.id
  enable_dynamic_ip   = true

  count = var.hosts

  connection {
    user = "root"
    type = "ssh"
    timeout = "2m"
    host = self.public_ip
    agent = false
    private_key = file("${var.ssh_key_path}")
  }


  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -yq apt-transport-https jq ufw netcat-traditional ${join(" ", var.apt_packages)}",
      # fix a problem with later wireguard installation
      "DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::=--force-confnew sudo",
    ]
  }
}

data "scaleway_instance_image" "image" {
  architecture = "x86_64"
  name         = var.image
}

data "external" "network_interfaces" {
  count   = var.hosts > 0 ? 1 : 0
  program = [
  "ssh",
  "-i", "${abspath(var.ssh_key_path)}",
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no",
  "-o", "UserKnownHostsFile=/dev/null",
  "root@${scaleway_instance_server.host[0].public_ip}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}

output "hostnames" {
  value = scaleway_instance_server.host.*.name
}

output "public_ips" {
  value = scaleway_instance_server.host.*.public_ip
}

output "private_ips" {
  value = scaleway_instance_server.host.*.private_ip
}

output "network_interfaces" {
  value = var.hosts > 0 ? lookup(data.external.network_interfaces[0].result, "iface") : ""
}

output "public_network_interface" {
  value = "ens3"
}

output "private_network_interface" {
  value = "ens2"
}

output "scaleway_servers" {
  value = "${scaleway_instance_server.host}"
}

output "nodes" {

value = [for index, server in scaleway_instance_server.host: {
    hostname    = server.name
    public_ip   = server.public_ip,
    private_ip  = server.private_ip,
  }]

}
