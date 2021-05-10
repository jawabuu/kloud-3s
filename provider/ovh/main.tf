variable "tenant_name" {
  type        = string
  description = "The Name of the Tenant (Identity v2) or Project (Identity v3) to login with"
}

variable "user_name" {
  type        = string
  description = "The Username to login with"
}

variable "password" {
  type        = string
  description = "The Password to login with"
}

variable "auth_url" {
  default     = "https://auth.cloud.ovh.net/v3"
  description = "The Identity authentication URL"
}

variable "application_key" {
  type        = string
  description = "The API Application Key"
}

variable "application_secret" {
  type        = string
  description = "The API Application Secret"
}

variable "consumer_key" {
  type        = string
  description = "The API Consumer key"
}

variable "endpoint" {
  type        = string
  description = "The API endpoint to use"
}

variable "hosts" {
  default = 0
}

variable "ssh_keys" {
  type = list
}

variable "hostname_format" {
  type        = string
  description = "The region of the OpenStack cloud to use"
}

variable "region" {
  type = string
}

variable "image" {
  type        = string
  description = "The region of the OpenStack cloud to use"
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

# Left to test ovh provider
/*
provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

data ovh_vracks vracks {}

output "vracks" {
  value = "${data.ovh_vracks.vracks}"
}
*/

provider "openstack" {
  region      = var.region
  tenant_name = var.tenant_name
  user_name   = var.user_name
  password    = var.password
  auth_url    = var.auth_url
}

resource "openstack_compute_keypair_v2" "tf-kube" {
  count      = fileexists("${var.ssh_pubkey_path}") ? 1 : 0
  name       = "tf-kube"
  public_key = file("${var.ssh_pubkey_path}")
}

resource "openstack_compute_instance_v2" "host" {
  name        = format(var.hostname_format, count.index + 1)
  image_name  = var.image
  flavor_name = var.size
  key_pair    = openstack_compute_keypair_v2.tf-kube[0].name

  # Important: orders of network declaration matters because
  # public network is attached on ens4, so keep it at the end of the list

  network {
    access_network = false
    port           = openstack_networking_port_v2.kube-host-network[count.index].id
  }

  network {
    access_network = true
    port           = openstack_networking_port_v2.public[count.index].id
  }

  count = var.hosts

  # Set up private interface
  user_data = <<EOF
#cloud-config
write_files:
 # Set up private interface
 - path: /etc/systemd/network/10-ens3.network
   permissions: '0644'
   content: |
    [Match]
    Name=ens3 eth0
    [Network]
    DHCP=ipv4
    [DHCP]
    RouteMetric=2048
 # Set up public interface
 - path: /etc/systemd/network/20-ens4.network
   permissions: '0644'
   content: |
    [Match]
    Name=ens4 eth1
    [Network]
    DHCP=ipv4
    [DHCP]
    # favor ens4 default routes over ens3
    RouteMetric=1024
runcmd:
  # Enable root ssh for subsequent modules.
  - sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys
  - sudo systemctl restart systemd-networkd systemd-resolved sshd
  - ip -o addr show scope global
EOF

  connection {
    user        = "ubuntu"
    type        = "ssh"
    timeout     = "2m"
    host        = self.network[1].fixed_ip_v4
    agent       = false
    private_key = file("${var.ssh_key_path}")
  }

  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get install -yq jq net-tools ufw wireguard-tools wireguard ${join(" ", var.apt_packages)}",
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
  "root@${openstack_compute_instance_v2.host[0].network[1].fixed_ip_v4}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/
output "hostnames" {
  value = "${openstack_compute_instance_v2.host.*.name}"
}

output "public_ips" {
  value = [for index, host in openstack_compute_instance_v2.host :
    host.network[1].fixed_ip_v4
  ]
}

output "private_ips" {
  value = [for index, host in openstack_compute_instance_v2.host :
    host.network[0].fixed_ip_v4
  ]
}
/*
output "network_interfaces" {
  value = var.hosts > 0 ? lookup(data.external.network_interfaces[0].result, "iface") : ""
}
*/
output "public_network_interface" {
  value = "ens4"
}

output "private_network_interface" {
  value = "ens3"
}

output "ovh_servers" {
  value = "${openstack_compute_instance_v2.host}"
}

output "nodes" {

  value = [for index, server in openstack_compute_instance_v2.host : {
    hostname   = server.name
    public_ip  = server.network[1].fixed_ip_v4,
    private_ip = server.network[0].fixed_ip_v4,
  }]

}

