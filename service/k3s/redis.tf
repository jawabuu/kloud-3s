locals {
  redis = templatefile("${path.module}/templates/redis-helm.yaml", {
    domain         = var.domain
    redis_password = random_password.redis_password.result
  })
}

resource "random_password" "redis_password" {
  length  = 10
  special = false
}

resource "null_resource" "redis" {
  count = var.node_count > 0 && lookup(var.install_app, "redis", false) == true  ? 1 : 0
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    redis            = md5(local.redis)
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

  # Upload redis
  provisioner "file" {
    content     = local.redis
    destination = "/var/lib/rancher/k3s/server/manifests/redis-helm.yaml"
  }
}

output "redis" {
  value = local.redis
}
