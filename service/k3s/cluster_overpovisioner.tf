locals {
  cluster-overprovisioner = templatefile("${path.module}/templates/cluster-overprovisioner-helm.yaml", {
    domain   = var.domain
    cpu      = "1500m"
    memory   = "500Mi"
    replicas = 0
  })
}


resource "null_resource" "cluster-overprovisioner" {
  count = var.node_count > 0 && lookup(var.install_app, "cluster-overprovisioner", false) == true ? 1 : 0
  triggers = {
    k3s_id                  = md5(join(" ", null_resource.k3s.*.id))
    cluster-overprovisioner = md5(local.cluster-overprovisioner)
    ssh_key_path            = local.ssh_key_path
    master_public_ip        = local.master_public_ip
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload cluster-overprovisioner
  provisioner "file" {
    content     = local.cluster-overprovisioner
    destination = "/var/lib/rancher/k3s/server/manifests/cluster-overprovisioner-helm.yaml"
  }
}

output "cluster-overprovisioner" {
  value = local.cluster-overprovisioner
}
