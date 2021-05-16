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
    command     = "mkdir -p ${var.ssh_keys_dir} && echo -e 'y\n' | ssh-keygen -N '' -b 4096 -t rsa -f ${var.ssh_key_path} -C 'terraform@kloud3s' && ls -al"
    interpreter = ["bash", "-c"]
  }

}
# This will make dependent modules wait until the key is created.
# Terraform 0.13 can use depends_on with modules.
data "external" "ssh_keys" {
  query = {
    create_ssh_keys = join(" ", null_resource.create_ssh_keys.*.id)
  }
  program = ["bash", "-c", <<-EOF
  while ! test -f ${var.ssh_pubkey_path}; do echo 'waiting for keys..'; ((c++)) && ((c==10)) && break; sleep 5; done
  echo "{\"private_key\":\"${var.ssh_key_path}\",\"public_key\":\"${var.ssh_pubkey_path}\"}"
EOF
  ]
}

output "private_key" {
  value = fileexists("${var.ssh_key_path}") ? var.ssh_key_path : data.external.ssh_keys.result["private_key"]
}

output "public_key" {
  value = fileexists("${var.ssh_pubkey_path}") ? var.ssh_pubkey_path : data.external.ssh_keys.result["public_key"]
}
