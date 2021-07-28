variable "tenancy_ocid" {
  type        = string
  description = "OCID of your tenancy"
}

variable "user_ocid" {
  type        = string
  description = "OCID of the user calling the API"
}

variable "private_key_path" {
  type        = string
  description = "The path (including filename) of the private key stored on your computer."
  default     = ""
}

variable "fingerprint" {
  type        = string
  description = " Fingerprint for the key pair being used"
  default     = ""
}

variable "hosts" {
  default = 0
}

variable "ssh_keys" {
  type = list(any)
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
  description = "OS to use"
}

variable "size" {
  type    = string
  default = "1c6g"
}

variable "shape" {
  default     = ""
  description = "Literal server shape, overrides oci_type e.g. VM.Standard.E2.1.Micro"
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

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  private_key_path = var.private_key_path
  fingerprint      = var.fingerprint
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id   = var.tenancy_ocid
  operating_system = "Canonical Ubuntu"

  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-20.04-([\\.0-9-]+)$"]
    regex  = true
  }
}

data "oci_core_images" "ubuntu-minimal" {
  compartment_id   = var.tenancy_ocid
  operating_system = "Canonical Ubuntu"

  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-20.04-Minimal-([\\.0-9-]+)$"]
    regex  = true
  }
}

data "oci_core_images" "ubuntu-aarch64" {
  compartment_id   = var.tenancy_ocid
  operating_system = "Canonical Ubuntu"

  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-20.04-aarch64-?([\\.0-9-]+)$"]
    regex  = true
  }
}


resource "oci_core_instance" "host" {
  count = var.hosts
  # Required
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.tenancy_ocid
  shape               = var.shape == "" ? (var.size == "2c1g" ? "VM.Standard.E2.1.Micro" : "VM.Standard.A1.Flex") : var.shape
  source_details {
    source_id   = var.size == "2c1g" ? data.oci_core_images.ubuntu.images.0.id : data.oci_core_images.ubuntu-aarch64.images.0.id
    source_type = "image"
  }

  # Optional
  display_name = format(var.hostname_format, count.index + 1)
  create_vnic_details {
    assign_public_ip = true
    display_name     = format(var.hostname_format, count.index + 1)
    hostname_label   = format(var.hostname_format, count.index + 1)
    private_ip       = cidrhost(oci_core_subnet.kube-hosts.cidr_block, count.index + 101)
    subnet_id        = oci_core_subnet.kube-hosts.id
  }

  shape_config {
    ocpus         = var.shape == "" ? null : (var.size == "2c1g" ? null : regex("([\\d]+)-([\\d]+)g", var.size)[0])
    memory_in_gbs = var.shape == "" ? null : (var.size == "2c1g" ? null : regex("([\\d]+)-([\\d]+)g", var.size)[1])
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_pubkey_path)
    user_data = base64encode(<<EOF
#cloud-config
runcmd:
  # Enable root ssh for subsequent modules.
  - sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys
  # Remove Oracle's default rules that REJECT all incoming connections
  - sudo sed -i.bak '/icmp-host-prohibited/d' /etc/iptables/rules.v4
  - sudo iptables-restore < /etc/iptables/rules.v4
  - sudo systemctl restart systemd-networkd systemd-resolved sshd
  - ip -o addr show scope global
EOF
    )
  }
  preserve_boot_volume = false


  connection {
    user        = "ubuntu"
    type        = "ssh"
    timeout     = "2m"
    host        = self.public_ip
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

  lifecycle {
    ignore_changes = [
      source_details
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
  "root@${oci_core_instance.host[0].public_ip}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/
output "hostnames" {
  value = [for index, host in oci_core_instance.host :
    host.display_name
  ]
}

output "public_ips" {
  value = [for index, host in oci_core_instance.host :
    host.public_ip
  ]
}

output "private_ips" {
  value = [for index, host in oci_core_instance.host :
    host.private_ip
  ]
}
/*
output "network_interfaces" {
  value = var.hosts > 0 ? lookup(data.external.network_interfaces[0].result, "iface") : ""
}
*/
output "public_network_interface" {
  value = "enp0s3"
}

output "private_network_interface" {
  value = "enp0s3"
}

output "oracle_servers" {
  value = oci_core_instance.host
}

output "region" {
  value = var.region
}

output "nodes" {

  value = [for index, server in oci_core_instance.host : {
    hostname   = server.display_name
    public_ip  = server.public_ip,
    private_ip = server.private_ip,
  }]

}
