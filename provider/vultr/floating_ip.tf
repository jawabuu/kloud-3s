variable "enable_floatingip" {
  default     = false
  description = "Whether to use a floating ip or not"
}

output "floating_ip" {
  value = {}
}