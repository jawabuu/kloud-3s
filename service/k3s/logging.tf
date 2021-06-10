locals {
  logging = templatefile("${path.module}/templates/logging-helm.yaml", {
    domain         = var.domain
    mail_config    = var.mail_config
    oidc_config    = var.oidc_config
    admin_password = var.auth_password == "" ? random_string.default_password.result : var.auth_password
    client_id      = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientID"])
    client_secret  = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientSecret"])
  })
}

resource "null_resource" "logging_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "logging", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    run              = false
    logging          = md5(local.logging)
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload logging
  provisioner "file" {
    content     = local.logging
    destination = "/var/lib/rancher/k3s/server/manifests/logging.yaml"
  }

}
