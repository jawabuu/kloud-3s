variable "acme_email" {
  type        = string
  default     = ""
}

locals {
  wildcard_cert  = templatefile("${path.module}/templates/wildcard_cert.yaml", {
    dns_auth     = local.dns_auth
    acme_email   = var.acme_email == "" ? "info@${var.domain}" : var.acme_email
    create_certs = var.create_certs
  })
}

resource "null_resource" "wildcard_cert_apply" {
  # Skip DNS management using wildcard_cert if trform_domain is true.
  # The terraform DNS module already manages this.
  count    = var.node_count > 0 && local.dns_auth.provider != "" ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    wildcard_cert     = md5(local.wildcard_cert)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    dns_auth         = md5(jsonencode(local.dns_auth))
  }  
  
  # Use master(s)
  connection {
    host  = self.triggers.master_public_ip
    user  = "root"
    agent = false
    private_key = file("${self.triggers.ssh_key_path}")
  }
  
  # Upload external-dns
  provisioner "file" {
    content     = local.wildcard_cert
    destination = "/tmp/wildcard_cert.yaml"
  }
  
  # Install external-dns
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      until kubectl apply -f /tmp/wildcard_cert.yaml; do nc -zvv localhost 6443; sleep 5; done;
    EOT
    ]
  }
  
  # Remove external-dns
  provisioner "remote-exec" {
    inline = [<<EOT
      kubectl --request-timeout 10s delete -f /tmp/wildcard_cert.yaml;
    EOT
    ]
    
    when        = destroy
    on_failure  = continue
  }
  
}

output wildcard_cert {
  value = local.wildcard_cert
}
