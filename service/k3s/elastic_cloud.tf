resource "null_resource" "elastic_cloud_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "elastic_cloud", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    elastic_cloud    = filemd5("${path.module}/templates/elastic_cloud-helm.yaml")
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Upload elastic-cloud
  provisioner "file" {
    source      = "${path.module}/templates/elastic_cloud-helm.yaml"
    destination = "/var/lib/rancher/k3s/server/manifests/elastic_cloud.yaml"
  }

}