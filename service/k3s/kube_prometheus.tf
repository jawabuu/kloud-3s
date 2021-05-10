resource "null_resource" "kube_prometheus_apply" {
  count = var.node_count > 0 && lookup(var.install_app, "kube_prometheus", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    run              = false
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Upload kube_prometheus manifests 
  provisioner file {
    source      = "${path.module}/templates/kube_prometheus"
    destination = "/tmp"
  }

  # Install kube_prometheus
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      until kubectl apply -f /tmp/kube_prometheus/setup; do nc -zvv localhost 6443; sleep 5; done;
      until kubectl get customresourcedefinitions servicemonitors.monitoring.coreos.com ; do echo "Waiting for servicemonitors"; sleep 5; done;
      until kubectl apply -f /tmp/kube_prometheus; do nc -zvv localhost 6443; sleep 5; done;
    EOT
    ]
  }

  # Remove kube_prometheus
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl --request-timeout 10s delete -f /tmp/kube_prometheus;
      kubectl --request-timeout 10s delete -f /tmp/kube_prometheus/setup;
      kubectl --request-timeout 10s get po -A;
    EOT
    ]

    when       = destroy
    on_failure = continue
  }

}