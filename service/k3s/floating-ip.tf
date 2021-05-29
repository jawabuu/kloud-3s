locals {
  floating-ip = templatefile("${path.module}/templates/floating-ip-secrets.yaml", {
    provider_auth = lookup(var.floating_ip, "provider_auth", "")
    provider      = lookup(var.floating_ip, "provider", "")
    floating_ip   = local.floating_ip
    zone          = lookup(var.floating_ip, "zone", var.region)
  })
}

resource "null_resource" "floating-ip_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "floating-ip", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    floating_ip      = md5(local.floating-ip)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload floating-ip-secrets
  provisioner "file" {
    content     = local.floating-ip
    destination = "/var/lib/rancher/k3s/server/manifests/floating-ip-secrets.yaml"
  }

  # Upload floating-ip
  provisioner "file" {
    source      = "${path.module}/templates/floating-ip.yaml"
    destination = "/var/lib/rancher/k3s/server/manifests/floating-ip.yaml"
  }
}

