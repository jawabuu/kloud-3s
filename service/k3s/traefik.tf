locals {
  traefik = templatefile("${path.module}/templates/traefik-helm.yaml", {
    domain        = var.domain
    create_certs  = var.create_certs
    auth_user     = var.auth_user
    auth_password = var.auth_password == "" ? random_string.default_password.result : var.auth_password
    master_ips    = local.ha_cluster == true ? join(",", slice(var.connections, 0, local.ha_nodes)) : false
  })
}

resource "random_password" "default_password" {
  length  = 16
  special = true
}

resource "null_resource" "traefik_apply" {
  count = var.node_count > 0 ? 1 : 0
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    traefik          = md5(local.traefik)
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

  # Upload traefik
  provisioner "file" {
    content     = local.traefik
    destination = "/var/lib/rancher/k3s/server/manifests/traefik-helm.yaml"
  }
}

output "traefik" {
  value = local.traefik
}

output "default_password" {
  value = random_string.default_password.result
}