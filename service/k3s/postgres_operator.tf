locals {
  postgres-operator = templatefile("${path.module}/templates/postgres-operator-helm.yaml", {
    domain        = var.domain
    s3_endpoint   = lookup(var.s3_config, "s3_endpoint", "")
    s3_access_key = lookup(var.s3_config, "s3_access_key", "")
    s3_secret_key = lookup(var.s3_config, "s3_secret_key", "")
    s3_region     = lookup(var.s3_config, "s3_region", "")
    s3_bucket     = lookup(var.s3_config, "s3_bucket", "postgres")
    zone          = var.domain
  })
}

resource "null_resource" "postgres-operator" {
  count = var.node_count > 0 && lookup(var.install_app, "postgres-operator", false) == true ? 1 : 0
  triggers = {
    k3s_id            = md5(join(" ", null_resource.k3s.*.id))
    postgres-operator = md5(local.postgres-operator)
    ssh_key_path      = local.ssh_key_path
    master_public_ip  = local.master_public_ip
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload postgres-operator
  provisioner "file" {
    content     = local.postgres-operator
    destination = "/var/lib/rancher/k3s/server/manifests/postgres-operator-helm.yaml"
  }
}

output "postgres-operator" {
  value = local.postgres-operator
}
