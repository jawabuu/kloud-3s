variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "vultr_reserved_ip" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  # label     = "kloud3s"
  region_id = data.vultr_region.region.id
  ip_type   = "v4"
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(vultr_reserved_ip.kloud3s[0].subnet, ""),
    provider      = "vultr"
    provider_auth = var.api_key
    id            = try(vultr_reserved_ip.kloud3s[0].id, ""),
  }
}


resource "null_resource" "floating_ip" {

  count = var.hosts > 0 && var.enable_floatingip ? var.hosts : 0
  triggers = {
    node_public_ip = element(vultr_server.host.*.main_ip, count.index)
    floating_ip    = try(vultr_reserved_ip.kloud3s[0].subnet, "")
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
    ens3:
      addresses:
        - ${self.triggers.floating_ip}/32:
            lifetime: 0
            label: "ens3:0"
EOF
netplan apply;
ip -o addr show scope global | awk '{split($4, a, "/"); print $2" : "a[1]}';
    EOT
    ]
  }

}
