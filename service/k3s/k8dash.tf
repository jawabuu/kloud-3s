resource "null_resource" "k8dash_apply" {
  count    = var.node_count > 0 && lookup(var.install_app, "k8dash", false) == true ? 1 : 0
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
  
  # Install k8dash
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      until kubectl apply -f https://raw.githubusercontent.com/herbrandson/k8dash/master/kubernetes-k8dash.yaml; do nc -zvv localhost 6443; sleep 5; done;
      until kubectl apply -f https://raw.githubusercontent.com/herbrandson/k8dash/master/kubernetes-k8dash-serviceaccount.yaml; do nc -zvv localhost 6443; sleep 5; done;
    EOT
    ]
  }
  
  # Remove k8dash
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl --request-timeout 10s delete -f https://raw.githubusercontent.com/herbrandson/k8dash/master/kubernetes-k8dash.yaml;
      kubectl --request-timeout 10s delete -f https://raw.githubusercontent.com/herbrandson/k8dash/master/kubernetes-k8dash-serviceaccount.yaml;
    EOT
    ]
    
    when        = destroy
    on_failure  = continue
  }
  
}


data "external" "k8dash-token" {
  count   = var.node_count > 0  ? 1 : 0
  program = [
  "ssh", 
  "-i", "${abspath(var.ssh_key_path)}", 
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no", 
  "-o", "UserKnownHostsFile=/dev/null", 
  "root@${local.master_public_ip}",
  "TOKEN=$(kubectl get secret $(kubectl get secret | grep k8dash-sa | awk '{print $1}') -o jsonpath='{.data.token}' | base64 --decode); jq -n --arg token $TOKEN '{\"token\":$token}';"
  ]
}

output "k8dash-token" {
  value = data.external.k8dash-token.*.result
}