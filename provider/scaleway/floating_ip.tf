variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "scaleway_instance_ip" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(scaleway_instance_ip.kloud3s[0].address, ""),
    provider      = "scaleway"
    provider_auth = var.secret_key
  }
}
