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
  type = list
}

provider "hcloud" {
  token = var.token
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

resource "hcloud_ssh_key" "tf-kube" {
    count      = fileexists("${var.ssh_pubkey_path}") ? 1 : 0
    name       = "tf-kube"
    public_key = file("${var.ssh_pubkey_path}")
}

resource "hcloud_server" "host" {
  name        = format(var.hostname_format, count.index + 1)
  location    = var.location
  image       = var.image
  server_type = var.type
  ssh_keys    = hcloud_ssh_key.tf-kube.*.id

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
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq ufw ${join(" ", var.apt_packages)}",
    ]
  }
}

output "hostnames" {
  value = "${hcloud_server.host.*.name}"
}

output "public_ips" {
  value = "${hcloud_server.host.*.ipv4_address}"
}

output "private_ips" {
  value = "${hcloud_server_network.kube-host-network.*.ip}"
}

output "private_network_interface" {
  value = "ens10"
}

output "hcloud_servers" {
  value = "${hcloud_server.host}"
}
