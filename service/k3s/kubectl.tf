variable "api_secure_port" {
  default = "6443"
}

variable "kubeconfig_path" {
  type = string
}

resource "null_resource" "key_wait" {
  depends_on  = [ null_resource.k3s ]
  triggers = {
    k3s        = join(" ", null_resource.k3s.*.id)
    #always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command     = <<EOT
    ssh -i ${var.ssh_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${element(var.connections, 0)} \
    'while true; do if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then sleep 5; echo '[INFO] Waiting for K3S..'; else break; fi; done'
EOT
  }
}

resource null_resource kubeconfig {

  depends_on       = [ null_resource.key_wait ]

  triggers = {
    ip              = element(var.vpn_ips, 0)
    kubeconfig_path = var.kubeconfig_path
    key             = null_resource.key_wait.id
    #always_run      = "${timestamp()}"
  }  
  
  provisioner "local-exec" {
    on_failure  = continue
    interpreter = [ "bash", "-c" ]
    command     = <<EOT
    scp -i ${var.ssh_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${element(var.connections, 0)}:/etc/rancher/k3s/k3s.yaml ${var.kubeconfig_path}/k3s.yaml;
    #$HOME/.kube/${var.cluster_name};    
    sed -i 's/127.0.0.1/${element(var.connections, 0)}/g' ${var.kubeconfig_path}/k3s.yaml;    
    export KUBECONFIG=${var.kubeconfig_path}/k3s.yaml;
    kubectl config use $(kubectl config current-context);    
EOT 
  }  
    
  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    command     = "rm -f ${self.triggers.kubeconfig_path}/k3s.yaml"
  }
}

output "kubeconfig" {
  value = "export KUBECONFIG=${abspath(var.kubeconfig_path)}/k3s.yaml"
}
