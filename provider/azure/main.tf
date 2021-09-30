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
  type = string
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

variable "apt_packages" {
  type    = list(any)
  default = []
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

resource "time_static" "id" {}

provider "azurerm" {
  version = "=2.4.0"

  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  skip_provider_registration  = true

  features {}
}

resource "azurerm_resource_group" "kloud-3s" {
  count    = var.resource_group == "" ? 1 : 0
  name     = var.project
  location = var.region
}

data "azurerm_resource_group" "kloud-3s" {
  name     = var.resource_group == "" ? azurerm_resource_group.kloud-3s[0].name : var.resource_group
}

resource "azurerm_network_security_group" "default" {
  name                = "kube-firewall"
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name

  security_rule {
    name                       = "kube-firewall"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "kube-node"
  }
}


resource "azurerm_public_ip" "default" {
  count               = var.hosts
  name                = format(var.hostname_format, count.index + 1)
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "kube-node"
  }
}


resource "azurerm_network_interface" "default" {
  count               = var.hosts
  name                = format(var.hostname_format, count.index + 1)
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name

  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.kube-vpc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.kube-vpc.address_prefix, count.index + 101)
    public_ip_address_id          = azurerm_public_ip.default[count.index].id
  }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "default" {
  count                     = var.hosts
  network_interface_id      = azurerm_network_interface.default[count.index].id
  network_security_group_id = azurerm_network_security_group.default.id
}


resource "azurerm_linux_virtual_machine" "host" {

  count               = var.hosts
  name                = format(var.hostname_format, count.index + 1)
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  size                = var.size
  admin_username      = "kloud3s"
  network_interface_ids = [
    azurerm_network_interface.default[count.index].id,
  ]

  admin_ssh_key {
    username   = "kloud3s"
    public_key = file(var.ssh_pubkey_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  connection {
    user        = "kloud3s"
    type        = "ssh"
    timeout     = "2m"
    host        = self.public_ip_address
    agent       = false
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get install -yq jq net-tools ufw wireguard-tools wireguard open-iscsi nfs-common ${join(" ", var.apt_packages)}",
      "sudo cp /home/kloud3s/.ssh/authorized_keys /root/.ssh/authorized_keys",
      "sudo systemctl restart sshd",
    ]
  }

  lifecycle {
    ignore_changes = [
      admin_ssh_key
    ]
  }

}

/*
data "external" "network_interfaces" {
  count   = var.hosts > 0 ? 1 : 0
  program = [
  "ssh",
  "-i", "${abspath(var.ssh_key_path)}",
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no",
  "-o", "UserKnownHostsFile=/dev/null",
  "root@${azurerm_linux_virtual_machine.host[0].public_ip_address}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/

output "hostnames" {
  value = azurerm_linux_virtual_machine.host.*.name
}

output "public_ips" {
  value = azurerm_linux_virtual_machine.host.*.public_ip_address
}

output "private_ips" {
  value = azurerm_linux_virtual_machine.host.*.private_ip_address
}

output "public_network_interface" {
  value = "eth0"
}

output "private_network_interface" {
  value = "eth0"
}

output "azurerm_linux_virtual_machines" {
  value = azurerm_linux_virtual_machine.host
}

output "region" {
  value = var.region
}

output "nodes" {

  value = [for index, server in azurerm_linux_virtual_machine.host : {
    hostname   = server.name
    public_ip  = server.public_ip_address
    private_ip = server.private_ip_address
  }]

}
