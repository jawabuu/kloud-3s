locals {
  kube-prometheus = templatefile("${path.module}/templates/kube-prometheus-helm.yaml", {
    domain         = var.domain
    mail_config    = var.mail_config
    oidc_config    = var.oidc_config
    admin_password = var.auth_password == "" ? random_string.default_password.result : var.auth_password
    client_id      = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientID"])
    client_secret  = join(",", [for x in var.oidc_config : x.value if x.name == "authenticate.idp.clientSecret"])
  })
}

resource "null_resource" "kube_prometheus_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "kube_prometheus", false) == true ? 1 : 0
  triggers = {
    k3s_id           = md5(join(" ", null_resource.k3s.*.id))
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    run              = false
    kube_prometheus  = md5(local.kube-prometheus)
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload kube-prometheus
  provisioner "file" {
    content     = local.kube-prometheus
    destination = "/var/lib/rancher/k3s/server/manifests/kube-prometheus.yaml"
  }

}
