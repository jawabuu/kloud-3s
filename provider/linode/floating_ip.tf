variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

output "floating_ip" {
  value = {}
}

resource "linode_instance_ip" "kloud3s" {
  count     = var.hosts > 0 && var.enable_floatingip ? 0 : 0
  linode_id = linode_instance.host[0].id
  public    = true
}