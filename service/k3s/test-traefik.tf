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

variable "auth_user" {
  default = "kloud-3s"
}

variable "auth_password" {
  default = ""
}

locals {
  test-traefik  = var.test-traefik
  create_certs  = var.create_certs
  auth_user     = var.auth_user
  auth_password = var.auth_password == "" ? random_string.default_password.result : var.auth_password
  traefik_test  = templatefile("${path.module}/templates/traefik_test.yaml", {
    domain       = var.domain
    create_certs = var.create_certs
  })
}

resource "random_string" "default_password" {
 length  = 16
 special = true
}

resource "null_resource" "traefik_test_apply" {
  # Skip if test-traefik is false.
  count    = var.node_count > 0 && local.test-traefik == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    traefik_test     = md5(local.traefik_test)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    auth_user        = md5(local.auth_user)
    auth_password    = md5(local.auth_password)
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
      # Create Traefik Basic Auth Secret
      kubectl create secret generic traefik --from-literal=users='${local.auth_user}:${bcrypt(local.auth_password)}' --dry-run -o yaml | kubectl apply -f -;
      kubectl get secret traefik --namespace=default --export -o yaml | kubectl apply -o yaml --namespace=kubernetes-dashboard -f -;
      kubectl get secret traefik --namespace=default --export -o yaml | kubectl apply -o yaml --namespace=kube-system -f -;
    EOT
    ]
  }
  
}

output traefik_test {
  value = local.traefik_test
}

output default_password {
  value = random_string.default_password.result
}
