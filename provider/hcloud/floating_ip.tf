variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "hcloud_floating_ip" "kloud3s" {
  count         = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  type          = "ipv4"
  home_location = var.location
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(hcloud_floating_ip.kloud3s[0].ip_address, ""),
    provider      = "hcloud"
    provider_auth = var.token
  }
}