variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "digitalocean_floating_ip" "kloud3s" {
  count  = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  region = var.region
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(digitalocean_floating_ip.kloud3s[0].ip_address, ""),
    provider      = "digitalocean"
    provider_auth = var.token
  }
}