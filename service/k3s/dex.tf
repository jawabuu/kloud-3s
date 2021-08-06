locals {
  dex = templatefile("${path.module}/templates/dex-helm.yaml", {
    domain            = var.domain
    dex_client_id     = random_password.dex_client_id.result
    dex_client_secret = random_password.dex_client_secret.result
    client_id         = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientID"])
    client_secret     = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientSecret"])
    idp_url           = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.url"])
    idp_id            = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.provider"])
    idp_name          = try(join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.provider"]).title, "Kloud-3s")
    logo_url          = ""
  })
}

resource "random_password" "dex_client_id" {
  length  = 8
  special = false
}

resource "random_password" "dex_client_secret" {
  length  = 16
  special = false
}


resource "null_resource" "dex" {
  count = var.node_count > 0 ? 1 : 0
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    dex              = md5(local.dex)
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

  # Upload dex
  provisioner "file" {
    content     = local.dex
    destination = "/var/lib/rancher/k3s/server/manifests/dex-helm.yaml"
  }
}

output "dex" {
  value = local.dex
}
