variable "floating_ip_auth" {
  description = "Provider credentials to use for authenticating"
  default     = ""
}

locals {
  ip-floater = templatefile("${path.module}/templates/ip-floater.yaml", {
    hcloud_token = lookup(var.floating_ip, "provider_auth", "")
    provider     = lookup(var.floating_ip, "provider", "")
    floating_ip  = local.floating_ip
  })
}

resource "null_resource" "ip-floater_apply" {
  # Skip if use_ip-floater is false.
  count = var.node_count > 0 && lookup(var.install_app, "ip-floater", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ip-floater       = md5(local.ip-floater)
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

  # Upload ip-floater
  provisioner "file" {
    content     = local.ip-floater
    destination = "/var/lib/rancher/k3s/server/manifests/ip-floater.yaml"
  }
}

