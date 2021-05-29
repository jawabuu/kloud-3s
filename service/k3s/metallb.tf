locals {
  metallb_config = templatefile("${path.module}/templates/metallb-helm.yaml", {
    master_public_ip = local.floating_ip == "" ? local.master_public_ip : local.floating_ip
    ip_config        = local.floating_ip == "" ? true : false
  })
}

resource "null_resource" "metallb_install" {
  count = var.node_count > 0 && var.loadbalancer == "metallb" ? 1 : 0

  triggers = {
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    k3s_id           = join(" ", null_resource.k3s.*.id)
    metallb_config   = md5(local.metallb_config)
    floating_ip      = local.floating_ip
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload metallb
  provisioner "file" {
    content     = local.metallb_config
    destination = "/var/lib/rancher/k3s/server/manifests/metallb.yaml"
  }

}

output "metallb_config" {
  value = local.metallb_config
}