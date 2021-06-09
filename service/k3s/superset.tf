locals {
  superset = templatefile("${path.module}/templates/superset-helm.yaml", {
    domain        = var.domain
    mail_config   = var.mail_config
    oidc_config   = var.oidc_config
    client_id     = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientID"])
    client_secret = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientSecret"])
    dockerconfigjson = base64encode(jsonencode({
      "auths" : {
        "trow.${var.domain}" : {
          username = var.registry_user
          password = var.registry_password
          auth     = base64encode(join(":", [var.registry_user, var.registry_password]))
        }
      }
      })
    )
  })
}


resource "null_resource" "superset" {
  count      = var.node_count > 0 && lookup(var.install_app, "superset", false) == true ? 1 : 0
  depends_on = [null_resource.longhorn_apply]
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    superset         = md5(local.superset)
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

  # Upload superset
  provisioner "file" {
    content     = local.superset
    destination = "/var/lib/rancher/k3s/server/manifests/superset-helm.yaml"
  }

}

output "superset" {
  value = local.superset
}
