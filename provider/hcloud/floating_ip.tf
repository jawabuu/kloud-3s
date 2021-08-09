variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "hcloud_floating_ip" "kloud3s" {
  count         = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  type          = "ipv4"
  home_location = var.location
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(hcloud_floating_ip.kloud3s[0].ip_address, ""),
    provider      = "hcloud"
    provider_auth = var.token
    id            = try(hcloud_floating_ip.kloud3s[0].id, ""),
    network_id    = hcloud_network.kube-vpc.id
    ssh_key_id    = hcloud_ssh_key.tf-kube.id
    ssh_key       = chomp(file(var.ssh_pubkey_path))
  }
}

resource "null_resource" "floating_ip" {

  count = var.hosts > 0 && var.enable_floatingip ? var.hosts : 0
  triggers = {
    node_public_ip = element(hcloud_server.host.*.ipv4_address, count.index)
    floating_ip    = try(hcloud_floating_ip.kloud3s[0].ip_address, "")
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
  # This should ideally bind to public interface but inter-node networking breaks.
  provisioner "remote-exec" {
    inline = [<<EOT
cat <<-EOF > /etc/netplan/60-floating-ip.yaml
network:
  version: 2
  ethernets:
    lo:
      addresses:
        - ${self.triggers.floating_ip}/32:
            lifetime: 0
            label: "lo:0"
EOF
netplan apply;
ip -o addr show scope global | awk '{split($4, a, "/"); print $2" : "a[1]}';
    EOT
    ]
  }


  # Remove floating ip interface
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [<<EOT
    rm -rf /etc/netplan/60-floating-ip.yaml;
    netplan apply;
    ip -o addr show scope global | awk '{split($4, a, "/"); print $2" : "a[1]}';
        EOT
    ]
  }
}

/*
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - ${self.triggers.floating_ip}/32
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - ${self.triggers.floating_ip}/32:
            lifetime: 0
            label: "eth0:0"
*/