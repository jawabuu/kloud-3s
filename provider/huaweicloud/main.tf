variable "huaweicloud_access_key" {
  type    = string
  default = ""
}

variable "huaweicloud_secret_key" {
  type    = string
  default = ""
}

variable "huaweicloud_account_name" {
  type    = string
  default = ""
}

variable "region_zone" {
  type = string
}

variable "project" {
  type    = string
  default = "kloud-3s"
}

variable "hosts" {
  default = 0
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

provider "huaweicloud" {
  region      = var.region
  access_key  = var.huaweicloud_access_key
  secret_key  = var.huaweicloud_secret_key
  domain_name = var.huaweicloud_account_name
}

resource "huaweicloud_networking_secgroup" "allow_all" {
  name = "kube-firewall"
}

resource "huaweicloud_networking_secgroup_rule" "allow_all_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.allow_all.id
}

resource "huaweicloud_compute_keypair" "ssh-key" {
  name       = "ssh-key-${time_static.id.unix}"
  public_key = file(var.ssh_pubkey_path)
  lifecycle {
    ignore_changes = [
      public_key
    ]
  }
}

data "huaweicloud_images_image" "ubuntu" {
  name        = var.image
  most_recent = true
}

resource "huaweicloud_vpc_bandwidth" "kloud-3s" {
  name = "kloud-3s"
  size = 5
}

resource "huaweicloud_vpc_eip" "eip" {
  count = var.hosts
  publicip {
    type = "5_bgp"
  }

  bandwidth {
    id         = huaweicloud_vpc_bandwidth.kloud-3s.id
    share_type = "WHOLE"
  }

  #bandwidth {
  #  name        = "basic"
  #  size        = 5
  #  share_type  = "PER"
  #  charge_mode = "traffic"
  #}
}

resource "huaweicloud_compute_eip_associate" "eip_assoc" {
  count       = var.hosts
  public_ip   = huaweicloud_vpc_eip.eip[count.index].address
  instance_id = huaweicloud_compute_instance.host[count.index].id
}

// retrieve instance type
data "huaweicloud_compute_flavors" "instance" {
  availability_zone = var.region_zone #data.huaweicloud_availability_zones.az.names[0]
  performance_type  = "normal"
  cpu_core_count    = regex("([\\d]+)c([\\d]+)g", var.size)[0]
  memory_size       = regex("([\\d]+)c([\\d]+)g", var.size)[1]
}


resource "huaweicloud_compute_instance" "host" {

  count             = var.hosts
  image_id          = data.huaweicloud_images_image.ubuntu.id
  flavor_id         = data.huaweicloud_compute_flavors.instance.ids[0]
  name              = format(var.hostname_format, count.index + 1)
  availability_zone = var.region_zone
  key_pair          = "ssh-key-${time_static.id.unix}"

  security_groups = [huaweicloud_networking_secgroup.allow_all.name]

  network {
    uuid        = huaweicloud_vpc_subnet.kube-vpc.id
    fixed_ip_v4 = cidrhost(huaweicloud_vpc.kube-hosts.cidr, count.index + 101)
  }

  connection {
    user        = "root"
    type        = "ssh"
    timeout     = "2m"
    host        = self.access_ip_v4
    agent       = false
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get install -yq jq net-tools ufw wireguard-tools wireguard open-iscsi nfs-common ${join(" ", var.apt_packages)}",
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
  "root@${huaweicloud_compute_instance.host[0].access_ip_v4}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/

output "hostnames" {
  value = huaweicloud_compute_instance.host.*.name
}

output "public_ips" {
  value = huaweicloud_compute_instance.host.*.access_ip_v4
}

output "private_ips" {
  value = huaweicloud_compute_instance.host.*.network.0.fixed_ip_v4
}

output "public_network_interface" {
  value = "eth0"
}

output "private_network_interface" {
  value = "eth0"
}

output "huaweicloud_compute_instances" {
  value = huaweicloud_compute_instance.host
}

output "region" {
  value = var.region
}

output "nodes" {

  value = [for index, server in huaweicloud_compute_instance.host : {
    hostname   = server.name
    public_ip  = server.access_ip_v4
    private_ip = server.network[0].fixed_ip_v4
  }]

}
