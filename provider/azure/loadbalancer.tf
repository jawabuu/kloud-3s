
variable "enable_loadbalancer" {
  default     = false
  description = "Whether to use a cloud loadbalancer or not"
}

resource "azurerm_public_ip" "load_balancer_ip" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  name                = "lb-${time_static.id.unix}"
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "kube-node"
  }
}

resource "azurerm_lb" "load_balancer" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  name                = "lb-${time_static.id.unix}"
  location            = data.azurerm_resource_group.kloud-3s.location
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  sku                 = "Standard"

  tags = {
    environment = "kube-node"
  }

  frontend_ip_configuration {
    name                 = element(azurerm_public_ip.load_balancer_ip.*.name, 0)
    public_ip_address_id = element(azurerm_public_ip.load_balancer_ip.*.id, 0)
  }

  lifecycle {
    ignore_changes = [
      frontend_ip_configuration["private_ip_address_version"]
    ]
  }
}

resource "azurerm_lb_rule" "load_balancer_rule" {
  count                          = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name            = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id                = azurerm_lb.load_balancer[0].id
  name                           = "k3s"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = element(azurerm_public_ip.load_balancer_ip.*.name, 0)
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_address_pool[0].id
  probe_id                       = azurerm_lb_probe.k3s[0].id
}

resource "azurerm_lb_rule" "http" {
  count                          = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name            = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id                = azurerm_lb.load_balancer[0].id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = element(azurerm_public_ip.load_balancer_ip.*.name, 0)
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_address_pool[0].id
  # probe_id                       = azurerm_lb_probe.http[0].id
}

resource "azurerm_lb_rule" "https" {
  count                          = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name            = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id                = azurerm_lb.load_balancer[0].id
  name                           = "https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = element(azurerm_public_ip.load_balancer_ip.*.name, 0)
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_address_pool[0].id
  # probe_id                       = azurerm_lb_probe.https[0].id
}

resource "azurerm_lb_rule" "tcp" {
  count                          = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name            = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id                = azurerm_lb.load_balancer[0].id
  name                           = "tcp"
  protocol                       = "Tcp"
  frontend_port                  = 8800
  backend_port                   = 8800
  frontend_ip_configuration_name = element(azurerm_public_ip.load_balancer_ip.*.name, 0)
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_address_pool[0].id
  # probe_id                       = azurerm_lb_probe.tcp[0].id
}

resource "azurerm_lb_probe" "k3s" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id     = azurerm_lb.load_balancer[0].id
  name                = "k3s"
  port                = 6443
}

resource "azurerm_lb_probe" "https" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id     = azurerm_lb.load_balancer[0].id
  name                = "https"
  port                = 443
}

resource "azurerm_lb_probe" "http" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id     = azurerm_lb.load_balancer[0].id
  name                = "http"
  port                = 80
}

resource "azurerm_lb_probe" "tcp" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  resource_group_name = data.azurerm_resource_group.kloud-3s.name
  loadbalancer_id     = azurerm_lb.load_balancer[0].id
  name                = "tcp"
  port                = 8800
}

resource "azurerm_lb_backend_address_pool" "lb_backend_address_pool" {
  count               = var.hosts > 0 && var.enable_loadbalancer ? 1 : 0
  loadbalancer_id     = azurerm_lb.load_balancer[0].id
  name                = "lb-${time_static.id.unix}"
}


# Connect the loadbalancer backend pool to the network interface
resource "azurerm_network_interface_backend_address_pool_association" "lb_association" {
  count                   = var.hosts > 0 && var.enable_loadbalancer ? var.hosts : 0
  network_interface_id    = azurerm_network_interface.default[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_address_pool[0].id
}

output "loadbalancer_ip" {
  value = try(azurerm_public_ip.load_balancer_ip[0].ip_address, "")
}