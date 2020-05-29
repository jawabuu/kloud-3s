resource "null_resource" "metallb_install" {
    
  triggers = {
    ssh_key_path     = null_resource.k3s_cache[0].triggers.ssh_key_path
    master_public_ip = null_resource.k3s_cache[0].triggers.master_public_ip
  }  
  
  # Use master(s)
  connection {
    host  = self.triggers.master_public_ip
    user  = "root"
    agent = false
    private_key = file("${self.triggers.ssh_key_path}")
  }
  
  # Upload metallb.yaml for assigning loadbalancer IP
  provisioner file {
    source      = "${path.module}/manifests/metallb.yaml"
    destination = "/tmp/metallb.yaml"
  }

  # Upload net-tools.yaml for debugging
  # nslookup kube-dns.kube-system
  provisioner file {
    source      = "${path.module}/manifests/net-tools.yaml"
    destination = "/tmp/net-tools.yaml"
  }
  
  # Install metallb
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      kubectl apply -f /tmp/metallb.yaml;
      kubectl apply -f /tmp/net-tools.yaml;
    EOT
    ]
  }
  
  
  # Clean up on modifying metal-lb
  provisioner remote-exec { 
    
    when = destroy
    inline = [
      "echo 'Cleaning up metal-lb...'",
      "kubectl delete -n metallb-system",
    ]
  }
  
}

resource "local_file" "metallb_config" {
  filename = "${path.module}/manifests/metallb_config.yaml"
  content = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      avoid-buggy-ips: true
      addresses:
      - ${local.master_public_ip}/32
      auto-assign: true
    - name: backup
      protocol: layer2
      avoid-buggy-ips: true
      addresses:%{ for connection in slice(var.connections,1,length(var.connections))}
      - ${connection}/32 %{ endfor }
      auto-assign: false
YAML
  }

### Notes: Make all IPs available for metallb
#addresses:%{ for connection in slice(var.connections,1,length(var.connections))}
#addresses:%{ for connection in var.connections}
### End Notes

resource "null_resource" "metallb_apply" {
  
  triggers = {
    metallb          = null_resource.metallb_install.id
    metallb_config   = md5(local_file.metallb_config.content)
    ssh_key_path     = null_resource.k3s_cache[0].triggers.ssh_key_path
    master_public_ip = null_resource.k3s_cache[0].triggers.master_public_ip
  }  
  
  # Use master(s)
  connection {
    host  = self.triggers.master_public_ip
    user  = "root"
    agent = false
    private_key = file("${self.triggers.ssh_key_path}")
  }
  
  # Upload metallb_config.yaml
  provisioner file {
    source      = local_file.metallb_config.filename
    destination = "/tmp/metallb_config.yaml"
  }
  
  # Start metallb
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl apply -f /tmp/metallb_config.yaml;
    EOT
    ]
  }
  
  # Clean up on modifying metal-lb
  provisioner remote-exec { 
    
    when = destroy
    inline = [
      "echo 'Cleaning up metal-lb...'",
      "kubectl delete -n metallb-system configmap config",
    ]
  }
}
