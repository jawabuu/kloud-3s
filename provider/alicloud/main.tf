variable "alicloud_access_key" {
  type    = string
  default = ""
}

variable "alicloud_secret_key" {
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
  type    = list
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

provider "alicloud" {
  region     = var.region
  access_key = var.alicloud_access_key
  secret_key = var.alicloud_secret_key
}

resource "alicloud_security_group" "allow_all" {
  name   = "kube-firewall"
  vpc_id = alicloud_vpc.kube-hosts.id
}

resource "alicloud_security_group_rule" "allow_all_ingress" {
  type              = "ingress"
  ip_protocol       = "all"
  nic_type          = "intranet"
  policy            = "accept"
  priority          = 100
  security_group_id = alicloud_security_group.allow_all.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_key_pair" "ssh-key" {
  key_name   = "ssh-key-${time_static.id.unix}"
  public_key = file(var.ssh_pubkey_path)
  lifecycle {
    ignore_changes = [
      public_key
    ]
  }
}

data "alicloud_images" "ubuntu" {
  most_recent = true
  name_regex  = "^ubuntu_20.*64"
}

/*
resource "alicloud_eip" "eip" {
  count  = var.hosts
}

resource "alicloud_eip_association" "eip_assoc" {
  count              = var.hosts
  allocation_id      = alicloud_eip.eip[count.index].id
  instance_id        = alicloud_nat_gateway.gw.id #alicloud_instance.host[count.index].id
  # private_ip_address = cidrhost(alicloud_vswitch.kube-vpc.cidr_block, count.index + 101)
}
*/

// retrieve instance type
data "alicloud_instance_types" "instance" {
  availability_zone = alicloud_vswitch.kube-vpc.availability_zone
  cpu_core_count    = regex("([\\d]+)c([\\d]+)g", var.size)[0]
  memory_size       = regex("([\\d]+)c([\\d]+)g", var.size)[1]
}


resource "alicloud_instance" "host" {

  count         = var.hosts
  image_id      = data.alicloud_images.ubuntu.ids.0
  instance_type = data.alicloud_instance_types.instance.ids.0
  instance_name = format(var.hostname_format, count.index + 1)
  host_name     = format(var.hostname_format, count.index + 1)
  vswitch_id    = alicloud_vswitch.kube-vpc.id
  private_ip    = cidrhost(alicloud_vswitch.kube-vpc.cidr_block, count.index + 101)
  key_name      = "ssh-key-${time_static.id.unix}"

  security_groups            = [alicloud_security_group.allow_all.id]
  internet_max_bandwidth_out = 100

  connection {
    user        = "root"
    type        = "ssh"
    timeout     = "2m"
    host        = self.public_ip
    agent       = false
    private_key = file("${var.ssh_key_path}")
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
  "root@${alicloud_instance.host[0].public_ip}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/

output "hostnames" {
  value = "${alicloud_instance.host.*.instance_name}"
}

output "public_ips" {
  value = "${alicloud_instance.host.*.public_ip}"
}

output "private_ips" {
  value = "${alicloud_instance.host.*.private_ip}"
}

output "public_network_interface" {
  value = "eth0"
}

output "private_network_interface" {
  value = "eth0"
}

output "alicloud_instances" {
  value = "${alicloud_instance.host}"
}

output "region" {
  value = var.region
}

output "nodes" {

  value = [for index, server in alicloud_instance.host : {
    hostname   = server.instance_name
    public_ip  = server.public_ip
    private_ip = server.private_ip
  }]

}
