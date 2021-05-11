resource "null_resource" "kube_prometheus_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "kube_prometheus", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    run              = false
    kube_prometheus  = filemd5("${path.module}/templates/kube_prometheus-helm.yaml")
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Upload kube-prometheus
  provisioner "file" {
    source      = "${path.module}/templates/kube_prometheus-helm.yaml"
    destination = "/var/lib/rancher/k3s/server/manifests/kube_prometheus.yaml"
  }

}