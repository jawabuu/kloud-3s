variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "upcloud_floating_ip_address" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  zone  = var.location
}


output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(upcloud_floating_ip_address.kloud3s[0].ip_address, ""),
    provider      = "upcloud"
    provider_auth = base64encode("${var.username}:${var.password}")
    id            = try(upcloud_floating_ip_address.kloud3s[0].id, ""),
  }
}



resource "null_resource" "floating_ip" {

  count = var.hosts > 0 && var.enable_floatingip ? var.hosts : 0
  triggers = {
    node_public_ip = try(upcloud_server.host[count.index].network_interface[0].ip_address, "")
    floating_ip    = try(upcloud_floating_ip_address.kloud3s[0].ip_address, "")
    ssh_key_path   = var.ssh_key_path
    a              = false
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
    inline = self.triggers.floating_ip == "" ? null : [<<EOT
cat <<-EOF > /etc/network/interfaces.d/60-my-floating-ip.cfg
auto eth0:1
iface eth0:1 inet static
address ${self.triggers.floating_ip}
netmask 255.255.255.255
EOF
echo 'source /etc/network/interfaces.d/*' >> /etc/network/interfaces
service networking restart;
ip -o addr show scope global | awk '{split($4, a, "/"); print $2" : "a[1]}';
    EOT
    ]
  }

}
