locals {
  trform_domain = var.trform_domain
  dns_auth      = var.dns_auth
  external_dns = templatefile("${path.module}/templates/external-dns-helm.yaml", {
    dns_auth   = local.dns_auth
    master_ips = local.ha_cluster == true ? join(",", slice(var.connections, 0, local.ha_nodes)) : false
  })
}

resource "null_resource" "external_dns_apply" {
  # Skip DNS management using external_dns if trform_domain is true.
  # The terraform DNS module already manages this.
  count = var.node_count > 0 && local.trform_domain == false ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    external_dns     = md5(local.external_dns)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    dns_auth         = md5(jsonencode(local.dns_auth))
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload external-dns
  provisioner "file" {
    content     = local.external_dns
    destination = "/var/lib/rancher/k3s/server/manifests/external_dns.yaml"
  }

}

output "external_dns" {
  value = local.external_dns
}
