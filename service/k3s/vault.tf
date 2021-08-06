locals {
  vault = templatefile("${path.module}/templates/vault-helm.yaml", {
    domain         = var.domain
    mail_config    = var.mail_config
    oidc_config    = var.oidc_config
    admin_password = var.auth_password == "" ? random_password.default_password.result : var.auth_password
    client_id      = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientID"])
    client_secret  = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientSecret"])
  })
}

resource "null_resource" "vault_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "vault", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    run              = false
    vault            = filemd5("${path.module}/templates/vault-helm.yaml")
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload vault
  provisioner "file" {
    content     = local.vault
    destination = "/var/lib/rancher/k3s/server/manifests/vault.yaml"
  }

}
