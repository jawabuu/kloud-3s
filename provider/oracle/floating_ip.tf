variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "oci_core_vnic_attachment" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  #Required
  create_vnic_details {
    subnet_id = oci_core_subnet.kube-hosts.id
  }
  instance_id = oci_core_instance.host[count.index].id

  #Optional
  display_name = "kloud3s"
}

resource "oci_core_private_ip" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  #Optional
  display_name   = "kloud3s"
  hostname_label = "kloud3s"
  ip_address     = cidrhost(oci_core_subnet.kube-hosts.cidr_block, count.index + 201)
  vnic_id        = oci_core_vnic_attachment.kloud3s[count.index].vnic_id

  lifecycle {
    ignore_changes = [
      vnic_id
    ]
  }
}

resource "oci_core_public_ip" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  #Required
  compartment_id = var.tenancy_ocid
  lifetime       = "RESERVED"

  #Optional
  display_name  = "kloud3s"
  private_ip_id = oci_core_private_ip.kloud3s[0].id
}

resource "oci_identity_dynamic_group" "kloud3s" {
  #Required
  compartment_id = var.tenancy_ocid
  description    = "kloud3s instances"
  matching_rule  = "instance.compartment.id = '${var.tenancy_ocid}'"
  name           = "kloud3s"
}

resource "oci_identity_policy" "kloud3s" {
  name           = oci_identity_dynamic_group.kloud3s.name
  description    = "Policy to update IPs"
  compartment_id = oci_identity_dynamic_group.kloud3s.compartment_id
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.kloud3s.name} to manage virtual-network-family in compartment id ${oci_identity_dynamic_group.kloud3s.compartment_id}"
  ]
}

resource "null_resource" "floating_ip" {

  count = var.hosts > 0 && var.enable_floatingip ? var.hosts : 0
  triggers = {
    node_public_ip = element(oci_core_instance.host.*.public_ip, count.index)
    floating_ip    = try(oci_core_private_ip.kloud3s[0].ip_address, "")
    ssh_key_path   = var.ssh_key_path
  }

  connection {
    host        = self.triggers.node_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
    timeout     = "30s"
  }

  # Set up floating ip interface
  provisioner "remote-exec" {
    inline = [<<EOT
cat <<-EOF > /etc/netplan/60-floating-ip.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      addresses:
        - ${self.triggers.floating_ip}/32:
            lifetime: 0
            label: "enp0s3:0"
EOF
netplan apply;
ip -o addr show scope global | awk '{split($4, a, "/"); print $2" : "a[1]}';
    EOT
    ]
  }
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(oci_core_private_ip.kloud3s[0].ip_address, ""),
    provider      = "oracle"
    provider_auth = base64encode("${var.user_ocid}:${file(var.private_key_path)}")
    id            = try(oci_core_private_ip.kloud3s[0].id, ""),
  }
}
