locals {
  cert_manager = templatefile("${path.module}/templates/cert_manager-helm.yaml", {
    domain       = var.domain
    dns_auth     = local.dns_auth
    acme_email   = var.acme_email == "" ? "info@${var.domain}" : var.acme_email
    create_certs = var.create_certs
  })
}

resource "null_resource" "cert_manager_apply" {
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    cert_manager     = md5(local.cert_manager)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    dns_auth         = md5(jsonencode(local.dns_auth))
    create_certs     = var.create_certs
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Upload cert_manager
  provisioner "file" {
    content     = local.cert_manager
    destination = "/var/lib/rancher/k3s/server/manifests/cert_manager.yaml"
  }
}

output cert_manager {
  value = local.cert_manager
}
