variable "longhorn_replicas" {
  default     = 3
  description = "Number of longhorn replicas"
}

locals {
  longhorn      = templatefile("${path.module}/templates/longhorn.yaml", {
    longhorn_replicas = var.node_count < 3 ? var.node_count : var.longhorn_replicas
    domain            = var.domain
  })
}

resource "null_resource" "longhorn_apply" {
  # Skip if use_longhorn is false.
  count    = var.node_count > 0 && var.install_app.longhorn == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    longhorn         = md5(local.longhorn)
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
  
  # Upload longhorn
  provisioner "file" {
    content     = local.longhorn
    destination = "/tmp/longhorn.yaml"
  }
  # Install longhorn
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      echo "[INFO] ---Installing Longhorn---";
      until kubectl apply --validate=false -f /tmp/longhorn.yaml; do nc -zvv localhost 6443; sleep 5; done;
      kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}';
      kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}';
      echo "[INFO] ---Finished installing Longhorn---";
    EOT
    ]
  }
  
  # Remove longhorn
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl delete storageclass longhorn;
      kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}';
    EOT
    ]
    
    when        = destroy
    on_failure  = continue
  }
  
}

output longhorn {
  value = local.longhorn
}
