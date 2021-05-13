variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

variable "ssh_keys_dir" {
  type = string
}

# Create SSH Keys for terraform
resource "null_resource" "create_ssh_keys" {

  count = fileexists("${var.ssh_key_path}") ? 0 : 1

  triggers = {
    ssh = fileexists("${var.ssh_key_path}")
  }

  provisioner "local-exec" {
    # Create ssh keys.
    command     = "mkdir -p ${var.ssh_keys_dir} && echo -e 'y\n' | ssh-keygen -N '' -b 4096 -t rsa -f ${var.ssh_key_path} -C 'hobby@kube' && ls -al"
    interpreter = ["bash", "-c"]
  }

}


output "private_key" {
  depends_on = [null_resource.create_ssh_keys]
  value = var.ssh_key_path
}

output "public_key" {
  depends_on = [null_resource.create_ssh_keys]
  value = var.ssh_pubkey_path
}