variable "api_secure_port" {
  default = "6443"
}

variable "kubeconfig_path" {
  type = string
}

resource "null_resource" "key_wait" {
  triggers = {
    k3s        = null_resource.k3s[0].id
  }
  provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command     = <<EOT
    ssh -i ${var.ssh_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${local.master_public_ip} \
    'while true; do if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then sleep 5; echo '[INFO] Waiting for K3S..'; else break; fi; done'
EOT
  }
}

resource null_resource kubeconfig {

  triggers = {
    ip              = local.master_public_ip
    kubeconfig_path = var.kubeconfig_path
    key             = null_resource.key_wait.id
    cluster_name    = var.cluster_name
  }  
  
  provisioner "local-exec" {
    on_failure  = continue
    interpreter = [ "bash", "-c" ]
    command     = <<EOT
    scp -i ${var.ssh_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@${local.master_public_ip}:/etc/rancher/k3s/k3s.yaml ${var.kubeconfig_path}/k3s.yaml;
    
    export KUBECONFIG=${var.kubeconfig_path}/k3s.yaml;
    
    # Create new cluster entry
    kubectl config set-cluster ${var.cluster_name}-cluster --server=https://${local.master_public_ip}:${var.api_secure_port};
    # Set certificate data
    kubectl config set clusters.${var.cluster_name}-cluster.certificate-authority-data $(kubectl config view --raw | grep certificate-authority-data | cut -d ' ' -f 6)
    # Create new context
    kubectl config set-context ${var.cluster_name} --cluster=${var.cluster_name}-cluster --user ${var.cluster_name}-admin;
    # Delete default cluster and context, cleanup
    kubectl config delete-cluster default;
    kubectl config delete-context default;
    # Update username to match user created above
    sed -i -e 's/default/${var.cluster_name}-admin/g' ${var.kubeconfig_path}/k3s.yaml;
    
    ## An easier less convoluted method for the block above would be; 
    # kubectl config set-cluster ${var.cluster_name}-cluster --server=https://${local.master_public_ip}:${var.api_secure_port};
    # sed -i -e 's/default/${var.cluster_name}/g' ${var.kubeconfig_path}/k3s.yaml;
    ## This would set the cluster,context and user entries to the same value.
    
    kubectl config use ${var.cluster_name};
    kubectl get nodes;
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
