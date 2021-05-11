locals {
  pomerium = templatefile("${path.module}/templates/pomerium-helm.yaml", {
    domain        = var.domain
    shared_secret = base64encode(random_password.shared_secret.result)
    cookie_secret = base64encode(random_password.cookie_secret.result)
    oidc_config   = var.oidc_config
  })
}

resource "random_password" "shared_secret" {
  length = 32
}

resource "random_password" "cookie_secret" {
  length = 32
}


resource "null_resource" "pomerium" {
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    pomerium         = md5(local.pomerium)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Upload pomerium
  provisioner "file" {
    content     = local.pomerium
    destination = "/var/lib/rancher/k3s/server/manifests/pomerium-helm.yaml"
  }
}

output pomerium {
  value = local.pomerium
}
