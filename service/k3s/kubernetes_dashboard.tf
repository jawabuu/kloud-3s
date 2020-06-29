resource "null_resource" "kubernetes_dashboard_apply" {
  count    = var.node_count > 0 && lookup(var.install_app, "kubernetes_dashboard", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
  }  
  
  # Use master(s)
  connection {
    host  = self.triggers.master_public_ip
    user  = "root"
    agent = false
    private_key = file("${self.triggers.ssh_key_path}")
  }
  
  # Upload kubernetes_dashboard manifests 
  provisioner file {
    source      = "${path.module}/templates/kubernetes_dashboard.yaml"
    destination = "/tmp/kubernetes_dashboard.yaml"
  }
  
  # Install kubernetes_dashboard
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      kubectl apply -f /tmp/kubernetes_dashboard.yaml;
    EOT
    ]
  }
  
  # Remove kubernetes_dashboard
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl --request-timeout 10s delete -f /tmp/kubernetes_dashboard.yaml;
    EOT
    ]
    
    when        = destroy
    on_failure  = continue
  }
  
}