variable "token" {}

variable "hosts" {
  default = 0
}

variable "ssh_keys" {
  type = list
}

variable "hostname_format" {
  type = string
}

variable "region" {
  type = string
}

variable "image" {
  type = string
}

variable "size" {
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

provider "digitalocean" {
  token = var.token
}

resource "digitalocean_ssh_key" "tf-kube" {
    count      = fileexists("${var.ssh_pubkey_path}") ? 1 : 0
    name       = "tf-kube"
    public_key = file("${var.ssh_pubkey_path}")
}

resource "digitalocean_droplet" "host" {
  name               = format(var.hostname_format, count.index + 1)
  region             = var.region
  image              = var.image
  size               = var.size
  backups            = false
  private_networking = true
  ssh_keys           = digitalocean_ssh_key.tf-kube.*.id
  vpc_uuid           = digitalocean_vpc.kube-vpc.id

  count = var.hosts

  connection {
    user = "root"
    type = "ssh"
    timeout = "2m"
    host = self.ipv4_address
    agent = false
    private_key = file("${var.ssh_key_path}")
  }

  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq jq ufw ${join(" ", var.apt_packages)}",
    ]
  }
}

data "external" "network_interfaces" {

  program = [
  "ssh", 
  "-i", "${abspath(var.ssh_key_path)}", 
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no", 
  "-o", "UserKnownHostsFile=/dev/null", 
  "root@${digitalocean_droplet.host[0].ipv4_address}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}

output "hostnames" {
  value = "${digitalocean_droplet.host.*.name}"
}

output "public_ips" {
  value = "${digitalocean_droplet.host.*.ipv4_address}"
}

output "private_ips" {
  value = "${digitalocean_droplet.host.*.ipv4_address_private}"
}

output "network_interfaces" {
  value = jsondecode(lookup(data.external.network_interfaces.result, "iface"))
}

output "public_network_interface" {
  value = "eth0"
}

output "private_network_interface" {
  value = "eth1"
}

output "digitalocean_droplets" {
  value = "${digitalocean_droplet.host}"
}
