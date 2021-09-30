resource "azurerm_virtual_network" "kube-hosts" {
  name                = "kube-hosts-${time_static.id.unix}"
  address_space       = [var.vpc_cidr]
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
}

resource "azurerm_subnet" "kube-vpc" {
  name                 = "kube-vpc-${time_static.id.unix}"
  resource_group_name  = data.azurerm_resource_group.kloud-3s.name
  virtual_network_name = azurerm_virtual_network.kube-hosts.name
  address_prefix       = var.vpc_cidr
}
