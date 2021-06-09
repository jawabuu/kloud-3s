locals {
  sentry = templatefile("${path.module}/templates/sentry-helm.yaml", {
    domain        = var.domain
    mail_config   = var.mail_config
    oidc_config   = var.oidc_config
    client_id     = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientID"])
    client_secret = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientSecret"])
  })
}


resource "null_resource" "sentry" {
  count      = var.node_count > 0 && lookup(var.install_app, "sentry", false) == true ? 1 : 0
  depends_on = [null_resource.longhorn_apply]
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    sentry           = md5(local.sentry)
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

  # Upload sentry
  provisioner "file" {
    content     = local.sentry
    destination = "/var/lib/rancher/k3s/server/manifests/sentry-helm.yaml"
  }
}

output "sentry" {
  value = local.sentry
}
