locals {
  provider_map = {
    hcloud = "hetzner"
    azure  = "azure"
  }
  valid_provider = ["hcloud", "azure"]
  provider_auth  = lookup(var.floating_ip, "provider_auth", "")
  provider       = lookup(var.floating_ip, "provider", "")
  network_id     = lookup(var.floating_ip, "network_id", "")
  ssh_key_id     = lookup(var.floating_ip, "ssh_key_id", "")
  ssh_key        = lookup(var.floating_ip, "ssh_key", "")

  client_id       = lookup(var.floating_ip, "client_id", "")
  client_secret   = lookup(var.floating_ip, "client_secret", "")
  resource_group  = lookup(var.floating_ip, "resource_group", "")
  subscription_id = lookup(var.floating_ip, "subscription_id", "")
  tenant_id       = lookup(var.floating_ip, "tenant_id", "")
  location        = lookup(var.floating_ip, "location", "")
  network_security_group_id = lookup(var.floating_ip, "network_security_group_id", "")

  vpn_port          = 51820
  validate_provider = try(index(local.valid_provider, local.provider), "invalid")
  vpn_ips           = local.ha_cluster == true ? try(join(" ", slice(var.vpn_ips, 0, local.ha_nodes)), local.master_ip) : local.master_ip

  cloud_init = templatefile("${path.module}/templates/cloud-init.txt", {
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
    provider             = local.provider
    hosts                = join("\n", formatlist("echo '%s %s' >> /etc/hosts", split(" ", local.vpn_ips), local.registration_domain))
  })


  cluster-autoscaler = templatefile("${path.module}/templates/cluster-autoscaler.yaml", {
    domain             = var.domain
    provider_auth      = local.provider_auth
    provider           = local.provider
    validate_provider  = local.validate_provider
    formatted_provider = lookup(local.provider_map, local.provider, local.provider)
    node_pools         = local.provider == "azure" ? ["0:5:pool1"] : ["0:0:CX11:NBG1:pool1", "0:0:CPX11:HEL1:pool2", "0:0:CX21:NBG1:pool3"]
    vpn_port           = local.vpn_port
    network_id         = local.network_id
    ssh_key_id         = local.ssh_key_id
    # auto-discovery     = ""
    auto-discovery     = "label:cluster-autoscaler-enabled=true,cluster-autoscaler-name=kloud3s"

    client_id       = local.client_id
    client_secret   = local.client_secret
    resource_group  = local.resource_group
    subscription_id = local.subscription_id
    tenant_id       = local.tenant_id
    location        = local.location

    cloud_init = base64encode(local.cloud_init)
  })
}


resource "null_resource" "cluster-autoscaler" {
  # count = var.node_count > 0 && local.validate_provider != "invalid" && lookup(var.install_app, "cluster-autoscaler", false) == true ? 1 : 0
  count = var.node_count > 0 && lookup(var.install_app, "cluster-autoscaler", false) == true ? 1 : 0
  triggers = {
    k3s_id             = md5(join(" ", null_resource.k3s.*.id))
    cluster-autoscaler = md5(local.cluster-autoscaler)
    csi                = filemd5("${path.module}/templates/${local.provider}-csi.yaml")
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

  
  # Upload cloudprovider-csi
  provisioner "file" {
    source      = "${path.module}/templates/${local.provider}-csi.yaml"
    destination = "/var/lib/rancher/k3s/server/manifests/${local.provider}-csi.yaml"
  }


}

output "cluster-autoscaler" {
  value = local.cluster-autoscaler
}

output "cloud_init" {
  value = local.cloud_init
}
/*
provider "azurerm" {
  version = "=2.79"

  client_id                  = local.client_id
  client_secret              = local.client_secret
  tenant_id                  = local.tenant_id
  subscription_id            = local.subscription_id
  skip_provider_registration = true

  features {
    # virtual_machine_scale_set {
    #   roll_instances_when_required = false
    # }
    }
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
count                = var.node_count > 0 && local.provider == "azure" && lookup(var.install_app, "cluster-autoscaler", false) == true ? 1 : 0
 name                = "pool1"
 location            = local.location
 resource_group_name = local.resource_group
 sku                 = "Standard_B2s"
 instances           = 0
 admin_username      = "kloud3s"
 computer_name_prefix = "pool1"

 admin_ssh_key {
    username   = "kloud3s"
    public_key = local.ssh_key
  }

  os_disk  {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference  {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

 custom_data          = base64encode(local.cloud_init)

 network_interface {
    name    = "kloud3s"
    primary = true
  enable_ip_forwarding = true
  enable_accelerated_networking = false
  network_security_group_id = local.network_security_group_id

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = local.network_id
    }
  }


  tags = {
    environment = "kube-node"
    cluster-autoscaler-enabled = "true"
    cluster-autoscaler-name = "kloud3s"
    min = "0"
    max = "10"
    "k8s.io_cluster-autoscaler_node-template_label_k8s.io_node-type" = "agent"
  }

  lifecycle {
    ignore_changes = [
      instances
      # network_interface, instances, tags
    ]
  }
 
}
*/