variable "api_key" {}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type = string
}

variable "region_id" {
  type = string
}

variable "plan_id" {
  type = string
}

variable "os_id" {
  type = string
}

variable "ssh_keys" {
  type = list
}

provider "vultr" {
  api_key     = var.api_key
  rate_limit  = 700
  retry_limit = 3
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

resource "vultr_ssh_key" "tf-kube" {
    count      = fileexists("${var.ssh_pubkey_path}") ? 1 : 0
    name       = "tf-kube"
    ssh_key    = file("${var.ssh_pubkey_path}")
}

resource "vultr_server" "host" {
  hostname    = format(var.hostname_format, count.index + 1)
  region_id   = var.region_id
  os_id       = var.os_id
  plan_id     = var.plan_id
  ssh_key_ids = vultr_ssh_key.tf-kube.*.id
  network_ids = [ vultr_network.kube-vpc.id ]
  enable_private_network = true

  count = var.hosts

  connection {
    user = "root"
    type = "ssh"
    timeout = "2m"
    host = self.main_ip
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
  value = "${vultr_server.host.*.hostname}"
}

output "public_ips" {
  value = "${vultr_server.host.*.main_ip}"
}

output "private_ips" {
  value = "${vultr_server.host.*.internal_ip}"
}

output "private_network_interface" {
  value = "ens3"
}

output "vultr_servers" {
  value = "${vultr_server.host}"
}
