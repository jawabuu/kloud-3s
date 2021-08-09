variable "token" {}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type = string
}

variable "location" {
  type = string
}

variable "type" {
  type = string
}

variable "image" {
  type = string
}

variable "ssh_keys" {
  type = list(any)
}

variable "vpc_cidr" {
  default = "10.115.0.0/24"
}

resource "time_static" "id" {}

provider "hcloud" {
  token = var.token
}

variable "apt_packages" {
  type    = list(any)
  default = []
}

variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

locals {
  private_network_interface = length(regexall("cpx", var.type)) > 0 ? "enp7s0" : "ens10"
}


resource "hcloud_ssh_key" "tf-kube" {
  name       = "tf-kube-${time_static.id.unix}"
  public_key = file(var.ssh_pubkey_path)

  lifecycle {
    ignore_changes = [
      public_key
    ]
  }
}

data "hcloud_locations" "ds" {}

resource "hcloud_server" "host" {
  name        = format(var.hostname_format, count.index + 1)
  location    = element(data.hcloud_locations.ds.names, count.index % 3) #var.location 
  image       = var.image
  server_type = var.type
  ssh_keys    = [hcloud_ssh_key.tf-kube.id]

  count = var.hosts

  connection {
    user        = "root"
    type        = "ssh"
    timeout     = "2m"
    host        = self.ipv4_address
    agent       = false
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq jq net-tools ufw wireguard-tools wireguard open-iscsi nfs-common ${join(" ", var.apt_packages)}",
    ]
  }
}
/*
data "external" "network_interfaces" {
  count = var.hosts > 0 ? 1 : 0
  program = [
  "ssh", 
  "-i", "${abspath(var.ssh_key_path)}", 
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no", 
  "-o", "UserKnownHostsFile=/dev/null", 
  "root@${hcloud_server.host[0].ipv4_address}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/
output "hostnames" {
  value = hcloud_server.host.*.name
}

output "public_ips" {
  value = hcloud_server.host.*.ipv4_address
}

output "private_ips" {
  value = hcloud_server_network.kube-host-network.*.ip
}
/*
output "network_interfaces" {
  value = var.hosts > 0 ? lookup(data.external.network_interfaces[0].result, "iface") : ""
}
*/
output "public_network_interface" {
  value = "eth0"
}

output "private_network_interface" {
  value = local.private_network_interface
}

output "hcloud_servers" {
  value = hcloud_server.host
}

output "region" {
  value = var.location
}

output "nodes" {

  value = [for index, server in hcloud_server.host : {
    hostname   = server.name
    public_ip  = server.ipv4_address,
    private_ip = try(hcloud_server_network.kube-host-network[index].ip, "127.0.0.1")
  }]

}