variable "test-traefik" {
  type        = bool
  default     = true
  description = "Deploy traefik test."
}

variable "create_certs" {
  type        = bool
  default     = false
  description = "Option to create letsencrypt certs. Only enable if certain that your deployment is reachable."
}

locals {
  test-traefik  = var.test-traefik
  create_certs  = var.create_certs
  traefik_test  = templatefile("${path.module}/templates/traefik_test.yaml", {
    domain       = var.domain
    create_certs = var.create_certs
  })
}

resource "null_resource" "traefik_test_apply" {
  # Skip if test-traefik is false.
  count    = var.node_count > 0 && local.test-traefik == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    traefik_test     = md5(local.traefik_test)
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
  
  # Upload external-dns
  provisioner "file" {
    content     = local.traefik_test
    destination = "/tmp/traefik_test.yaml"
  }
  # Install basic traefik test
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      kubectl apply -f /tmp/traefik_test.yaml;
    EOT
    ]
  }
  
}

output traefik_test {
  value = local.traefik_test
}
