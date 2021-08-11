locals {
  provider_map = {
    hcloud = "hetzner"
  }
  valid_provider = ["hcloud"]
  provider_auth  = lookup(var.floating_ip, "provider_auth", "")
  provider       = lookup(var.floating_ip, "provider", "")
  network_id     = lookup(var.floating_ip, "network_id", "")
  ssh_key_id     = lookup(var.floating_ip, "ssh_key_id", "")
  ssh_key        = lookup(var.floating_ip, "ssh_key", "")
  vpn_port       = 51820
  vpn_ips        = local.ha_cluster == true ? try(join(" ", slice(var.vpn_ips, 0, local.ha_nodes)),local.master_ip) : local.master_ip
  cluster-autoscaler = templatefile("${path.module}/templates/cluster-autoscaler.yaml", {
    domain             = var.domain
    provider_auth      = local.provider_auth
    provider           = local.provider
    validate_provider  = index(local.valid_provider, local.provider)
    formatted_provider = lookup(local.provider_map, local.provider, local.provider)
    node_pools         = ["0:5:CX11:NBG1:pool1", "0:5:CPX11:FSN1:pool2", "0:0:CPX21:HEL1:pool3"]
    vpn_port           = local.vpn_port
    network_id         = local.network_id
    ssh_key_id         = local.ssh_key_id
    cloud_init = base64encode(templatefile("${path.module}/templates/cloud-init.txt", {
      k3s_version          = local.k3s_version
      service_cidr         = local.service_cidr
      overlay_cidr         = local.overlay_cidr
      overlay_interface    = local.overlay_interface
      private_interface    = local.private_interface
      kubernetes_interface = local.kubernetes_interface
      agent_install_flags  = local.agent_install_flags
      registration_domain  = local.registration_domain
      vpn_interface        = local.vpn_interface
      cni                  = local.cni
      vpn_port             = local.vpn_port
      ssh_key              = local.ssh_key
      enable_wireguard     = var.enable_wireguard
      hosts                = join("\n", formatlist("echo '%s %s' >> /etc/hosts", split(" ", local.vpn_ips), local.registration_domain))
    }))
  })
}


resource "null_resource" "cluster-autoscaler" {
  count = var.node_count > 0 && lookup(var.install_app, "cluster-autoscaler", false) == true ? 1 : 0
  triggers = {
    k3s_id             = md5(join(" ", null_resource.k3s.*.id))
    cluster-autoscaler = md5(local.cluster-autoscaler)
    ssh_key_path       = local.ssh_key_path
    master_public_ip   = local.master_public_ip
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
  }

  # Upload cluster-autoscaler
  provisioner "file" {
    content     = local.cluster-autoscaler
    destination = "/var/lib/rancher/k3s/server/manifests/cluster-autoscaler.yaml"
  }
  
  # Upload clean-node
  provisioner "file" {
    source      = "${path.module}/templates/clean-node.yaml"
    destination = "/var/lib/rancher/k3s/server/manifests/clean-node.yaml"
  }
}

output "cluster-autoscaler" {
  value = local.cluster-autoscaler
}
