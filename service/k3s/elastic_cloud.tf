resource "null_resource" "elastic_cloud_apply" {
  count    = var.node_count > 0 && lookup(var.install_app, "elastic_cloud", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    always_run       = "${timestamp()}"
  }  
  
  # Use master(s)
  connection {
    host  = self.triggers.master_public_ip
    user  = "root"
    agent = false
    private_key = file("${self.triggers.ssh_key_path}")
  }
  
  # Upload elastic_cloud manifests 
  provisioner file {
    source      = "${path.module}/templates/elastic_cloud"
    destination = "/tmp"
  }
  
  # Install elastic_cloud
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      kubectl apply -f /tmp/elastic_cloud/elastic-cloud.yaml
      kubectl apply -f /tmp/elastic_cloud/apm_es_kibana.yaml
      kubectl apply -f /tmp/elastic_cloud/metricbeat-kubernetes.yaml
      kubectl apply -f /tmp/elastic_cloud/filebeat-kubernetes.yaml
    EOT
    ]
  }
  
  # Remove k8dash
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl --request-timeout 10s delete -f /tmp/elastic_cloud;
      kubectl --request-timeout 10s get po -A;
    EOT
    ]
    
    when        = destroy
    on_failure  = continue
  }
  
}