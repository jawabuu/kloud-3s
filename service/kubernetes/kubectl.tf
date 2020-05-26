variable "cluster_name" {
  type = string
}

variable "api_secure_port" {
  default = "6443"
}

resource "null_resource" "kubectl" {
  depends_on = [null_resource.kubernetes]

  triggers = {
    ip = element(var.vpn_ips, 0)
  }

  provisioner "local-exec" {
    command = "[ -d $HOME/.kube/${var.cluster_name} ] || mkdir -p $HOME/.kube/${var.cluster_name}"
    interpreter = [ "bash", "-c" ]
  }

  provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command = <<EOT
        scp -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ${var.ssh_key_path} \
        root@${element(var.connections, 0)}:/etc/kubernetes/pki/{apiserver-kubelet-client.key,apiserver-kubelet-client.crt,ca.crt} \
        $HOME/.kube/${var.cluster_name}
EOT
  }

  provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command = <<EOT
      kubectl config set-cluster ${var.cluster_name} \
      --certificate-authority=$HOME/.kube/${var.cluster_name}/ca.crt \
      --server=https://${element(var.connections, 0)}:${var.api_secure_port} \
      --embed-certs=true

      kubectl config set-credentials ${var.cluster_name}-admin \
        --client-key=$HOME/.kube/${var.cluster_name}/apiserver-kubelet-client.key \
        --client-certificate=$HOME/.kube/${var.cluster_name}/apiserver-kubelet-client.crt \
        --embed-certs=true

      kubectl config set-context ${var.cluster_name} \
        --cluster=${var.cluster_name} \
        --user=${var.cluster_name}-admin

      kubectl config use-context ${var.cluster_name}
      kubectl get nodes
EOT
  }

  provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command = "rm -rf $HOME/.kube/${var.cluster_name}"
  }
}
