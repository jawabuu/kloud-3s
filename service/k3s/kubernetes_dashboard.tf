locals {
  kubernetes_dashboard = templatefile("${path.module}/templates/kubernetes-dashboard-helm.yaml", {
    domain = var.domain
  })
}

resource "null_resource" "kubernetes_dashboard_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "kubernetes_dashboard", false) == true ? 1 : 0
  triggers = {
    k3s_id               = md5(join(" ", null_resource.k3s.*.id))
    ssh_key_path         = local.ssh_key_path
    master_public_ip     = local.master_public_ip
    kubernetes_dashboard = local.kubernetes_dashboard
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload kubernetes_dashboard
  provisioner "file" {
    content     = local.kubernetes_dashboard
    destination = "/var/lib/rancher/k3s/server/manifests/kubernetes_dashboard.yaml"
  }

}

output "kubernetes_dashboard" {
  value = local.kubernetes_dashboard
}
