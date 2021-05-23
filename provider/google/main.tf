variable "project" {}

variable "creds_file" {}

variable "region_zone" {
  type    = string
  default = ""
}

variable "hosts" {
  default = 0
}
/*
variable "ssh_keys" {
  type = list
}
*/
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
  type    = list(any)
  default = []
}

variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

variable "vpc_cidr" {
  default = "10.115.0.0/24"
}

resource "time_static" "id" {}

provider "google" {
  region      = var.region
  zone        = var.region_zone
  project     = var.project
  credentials = file(var.creds_file)
}

provider "google-beta" {
  region      = var.region
  zone        = var.region_zone
  project     = var.project
  credentials = file(var.creds_file)
}

resource "google_compute_firewall" "default" {
  name    = "kube-firewall"
  network = google_compute_network.kube-hosts.self_link

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["kube-node"]
}

resource "google_compute_instance" "host" {

  count = var.hosts

  name         = format(var.hostname_format, count.index + 1)
  machine_type = var.size
  tags         = ["kube-node"]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 30
    }
  }

  network_interface {
    network    = "kube-hosts-${time_static.id.unix}"
    subnetwork = google_compute_subnetwork.kube-vpc.self_link
    network_ip = cidrhost(google_compute_subnetwork.kube-vpc.ip_cidr_range, count.index + 101)

    access_config {}
  }

  can_ip_forward            = true
  allow_stopping_for_update = true

  metadata = {
    ssh-keys = "root:${try(file(var.ssh_pubkey_path), "")}"
  }

  scheduling {
    automatic_restart = true
    preemptible       = false
  }

  connection {
    user        = "root"
    type        = "ssh"
    timeout     = "2m"
    host        = self.network_interface.0.access_config.0.nat_ip
    agent       = false
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq jq net-tools ufw wireguard-tools wireguard open-iscsi nfs-common ${join(" ", var.apt_packages)}",
    ]
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }

}

/*
data "external" "network_interfaces" {
  count   = var.hosts > 0 ? 1 : 0
  program = [
  "ssh",
  "-i", "${abspath(var.ssh_key_path)}",
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no",
  "-o", "UserKnownHostsFile=/dev/null",
  "root@${google_compute_instance.host[0].network_interface.0.access_config.0.nat_ip}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/

output "hostnames" {
  value = google_compute_instance.host.*.name
}

output "public_ips" {
  value = google_compute_instance.host.*.network_interface.0.access_config.0.nat_ip
}

output "private_ips" {
  value = google_compute_instance.host.*.network_interface.0.network_ip
}

output "public_network_interface" {
  value = "ens4"
}

output "private_network_interface" {
  value = "ens4"
}

output "google_compute_instances" {
  value = google_compute_instance.host
}

output "region" {
  value = var.region
}

output "nodes" {

  value = [for index, server in google_compute_instance.host : {
    hostname   = server.name
    public_ip  = server.network_interface.0.access_config.0.nat_ip
    private_ip = server.network_interface.0.network_ip
  }]

}
