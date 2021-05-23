variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

resource "vultr_reserved_ip" "kloud3s" {
  count     = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  label     = "kloud3s"
  region_id = data.vultr_region.region.id
  ip_type   = "v4"
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(vultr_reserved_ip.kloud3s[0].id, ""),
    provider      = "vultr"
    provider_auth = var.api_key
  }
}