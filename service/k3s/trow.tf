variable "registry_user" {
  default     = "kloud-3s"
  description = "Trow Registry username"
}

variable "registry_password" {
  default     = ""
  description = "Trow Registry password"
}

locals {
  trow = templatefile("${path.module}/templates/trow-helm.yaml", {
    domain            = var.domain
    registry_user     = var.registry_user
    registry_password = var.registry_password
  })
}

resource "null_resource" "trow" {
  count      = var.node_count > 0 && lookup(var.install_app, "trow", false) == true ? 1 : 0
  depends_on = [null_resource.longhorn_apply]
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    trow             = md5(local.trow)
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

  # Upload trow
  provisioner "file" {
    content     = local.trow
    destination = "/var/lib/rancher/k3s/server/manifests/trow-helm.yaml"
  }
}

output "trow" {
  value = local.trow
}
