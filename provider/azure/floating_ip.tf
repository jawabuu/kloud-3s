variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address          = "",
    provider            = "azure"
    provider_auth       = base64encode("${var.client_id}:${var.client_secret}:${var.tenant_id}:${var.subscription_id}:${data.azurerm_resource_group.kloud-3s.name}")
    client_id           = var.client_id
    client_secret       = var.client_secret
    tenant_id           = var.tenant_id
    subscription_id     = var.subscription_id
    location            = data.azurerm_resource_group.kloud-3s.location
    resource_group      = data.azurerm_resource_group.kloud-3s.name
    ssh_key             = chomp(file(var.ssh_pubkey_path))
    network_id          = azurerm_subnet.kube-vpc.id
    backend_address_pool_id = try(azurerm_lb_backend_address_pool.lb_backend_address_pool[0].id, "")
    network_security_group_id = azurerm_network_security_group.default.id
  }
}