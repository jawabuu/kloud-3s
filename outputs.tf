output "private_key" {
  value = abspath(module.ssh.private_key)
}

output "public_key" {
  value = abspath(module.ssh.public_key)
}

output "instances" {
  value = module.provider.nodes
}

output "kubeconfig" {
  value = module.k3s.kubeconfig
}

output "ssh-master" {
  value = "ssh -i ${abspath(module.ssh.private_key)} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${module.provider.public_ips[0]}"
}