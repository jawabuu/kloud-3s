variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "upcloud_floating_ip_address" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  zone  = var.location
}


output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(upcloud_floating_ip_address.kloud3s[0].ip_address, ""),
    provider      = "upcloud"
    provider_auth = var.password
  }
}