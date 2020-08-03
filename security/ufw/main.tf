variable "node_count" {}

variable "connections" {
  type = list
}

variable "ssh_key_path" {
  type = string
}

variable "private_interface" {
  type = string
}

variable "vpn_interface" {
  type = string
}

variable "vpn_port" {
  type = string
}

variable "overlay_interface" {
  type = string
}

variable "overlay_cidr" {
  type = string
}

variable "additional_rules" {
  type    = list(string)
  default = []
}

resource "null_resource" "firewall" {
  count = var.node_count

  triggers = {
    template = data.template_file.ufw.rendered
  }

  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = false
    private_key = file("${var.ssh_key_path}")
    
  }

  provisioner "remote-exec" {
    inline = [
      "${data.template_file.ufw.rendered}"
    ]
      
  }
}

data "template_file" "ufw" {
  template = "${file("${path.module}/scripts/ufw.sh")}"

  vars = {
    private_interface    = var.private_interface
    overlay_interface    = var.overlay_interface
    vpn_interface        = var.vpn_interface
    vpn_port             = var.vpn_port
    overlay_cidr         = var.overlay_cidr
    additional_rules     = join("\nufw ", flatten(["", var.additional_rules]))
  }
}
