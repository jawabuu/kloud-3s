locals {
  minio = templatefile("${path.module}/templates/minio-operator.yaml", {
    domain                   = var.domain
    dex_client_id            = random_password.dex_client_id.result
    dex_client_secret        = random_password.dex_client_secret.result
    s3_access_key            = random_password.s3_access_key.result
    s3_secret_key            = random_password.s3_secret_key.result
    console_pbkdf_salt       = random_password.console_pbkdf_salt.result
    console_pbkdf_passphrase = random_password.console_pbkdf_passphrase.result
  })
}

resource "random_password" "s3_access_key" {
  length  = 15
  special = false
}

resource "random_password" "s3_secret_key" {
  length  = 31
  special = false
}

resource "random_password" "console_pbkdf_salt" {
  length  = 8
  special = false
}

resource "random_password" "console_pbkdf_passphrase" {
  length  = 12
  special = false
}

resource "null_resource" "minio" {
  count = var.node_count > 0 && lookup(var.install_app, "minio", false) == true ? 1 : 0
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    minio            = md5(local.minio)
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

  # Upload minio
  provisioner "file" {
    content     = local.minio
    destination = "/var/lib/rancher/k3s/server/manifests/minio-operator.yaml"
  }
}

output "minio" {
  value = local.minio
}
