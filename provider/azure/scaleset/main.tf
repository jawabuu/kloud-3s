variable "client_id" {
  type    = string
  default = ""
}

variable "client_secret" {
  type    = string
  default = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

variable "subscription_id" {
  type    = string
  default = ""
}

variable "project" {
  type    = string
  default = "kloud-3s"
}

variable "resource_group" {
  type    = string
  default = ""
}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type    = string
  default = "pool1"

}

variable "region" {
  type = string
}

variable "image" {
  type = string
}

variable "size" {
  type = string
}

variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

variable "vpc_cidr" {
  default = "10.115.0.0/24"
}

variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

variable "cloud_init" {
  type    = string
  default = ""
}

variable "floating_ip" {
  description = "Floating IP"
  default     = {}
}


locals {
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
  cloud_init      = var.cloud_init
  network_security_group_id = lookup(var.floating_ip, "network_security_group_id", "")
}

provider "azurerm" {
  version = "=2.79"

  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  subscription_id            = var.subscription_id
  skip_provider_registration = true

  features {
    # virtual_machine_scale_set {
    #   roll_instances_when_required = false
    # }
    }
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
 count               = var.hosts > 0 ? 1 : 0
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
