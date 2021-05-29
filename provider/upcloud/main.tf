variable "username" {}

variable "password" {}

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

provider "upcloud" {
  username = var.username
  password = var.password
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


variable "storage_sizes" {
  type = map(any)
  default = {
    "1xCPU-1GB" = 25
    "1xCPU-2GB" = 50
    "2xCPU-4GB" = 80
    "4xCPU-8GB" = 160
  }
}

terraform {
  required_version = ">= 0.13"
  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "2.0.0"
    }
  }
}

resource "upcloud_server" "host" {
  hostname = format(var.hostname_format, count.index + 1)
  zone     = var.location
  plan     = var.type

  count = var.hosts

  template {
    storage = var.image
    size    = lookup(var.storage_sizes, var.type, 30)
  }

  network_interface {
    type = "public"
  }

  # network_interface {
  #   type = "utility"
  # }

  network_interface {
    type       = "private"
    network    = upcloud_network.kube-vpc.id
    ip_address = cidrhost(var.vpc_cidr, count.index + 101)
  }

  dynamic "storage_devices" {
    for_each = var.enable_volumes ? [var.enable_volumes] : []
    content {
      storage = upcloud_storage.kube_volume[count.index].id
    }
  }


  login {
    user = "root"

    keys = [chomp(file(var.ssh_pubkey_path))]

  }

  connection {
    user        = "root"
    type        = "ssh"
    timeout     = "2m"
    host        = self.network_interface[0].ip_address
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
  "root@${upcloud_server.host[0].network_interface[0].ip_address}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/
output "hostnames" {
  value = upcloud_server.host.*.hostname
}

output "public_ips" {
  value = [for index, server in upcloud_server.host : server.network_interface[0].ip_address]
}

output "private_ips" {
  value = [for index, server in upcloud_server.host : server.network_interface[1].ip_address]
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
  value = "eth1"
}

output "upcloud_servers" {
  value = upcloud_server.host
}

output "region" {
  value = var.location
}

output "nodes" {

  value = [for index, server in upcloud_server.host : {
    hostname   = server.hostname
    public_ip  = server.network_interface[0].ip_address,
    private_ip = server.network_interface[1].ip_address,
  }]

}