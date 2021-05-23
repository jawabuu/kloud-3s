variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}


resource "openstack_networking_floatingip_v2" "kloud3s" {
  count = var.hosts > 0 && var.enable_floatingip ? 1 : 0
  pool  = openstack_networking_network_v2.kube-vpc.name #"Ext-Net"
}

output "floating_ip" {
  # Experimental
  value = {
    ip_address    = try(openstack_networking_floatingip_v2.kloud3s[0].address, ""),
    provider      = "ovh"
    provider_auth = base64encode("${var.application_key}:${var.application_secret}")
  }
}