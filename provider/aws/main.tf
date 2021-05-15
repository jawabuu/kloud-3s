variable "aws_access_key" {
  type    = string
  default = ""
}

variable "aws_secret_key" {
  type    = string
  default = ""
}

variable "region_zone" {
  type = string
}

variable "project" {
  type    = string
  default = "kloud-3s"
}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type = string
}

variable "region" {
  type = string
}

variable "image" {
  type = string
}

variable "size" {
  type = string
}

variable "apt_packages" {
  type    = list
  default = []
}

variable "ssh_key_path" {
  type = string
}

variable "ssh_pubkey_path" {
  type = string
}

variable "vpc_cidr" {
  default = "10.115.0.0/24"
}

resource "time_static" "id" {}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}


resource "aws_security_group" "allow_all" {
  name   = "kube-firewall"
  vpc_id = aws_vpc.kube-hosts.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


resource "aws_network_interface" "default" {
  count           = var.hosts
  subnet_id       = aws_subnet.kube-vpc.id
  private_ips     = [cidrhost(aws_subnet.kube-vpc.cidr_block, count.index + 101)]
  security_groups = [aws_security_group.allow_all.id]
  tags = {
    Name = format(var.hostname_format, count.index + 1)
  }
}


resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key-${time_static.id.unix}"
  public_key = file(var.ssh_pubkey_path)
  lifecycle {
    ignore_changes = [
      public_key
    ]
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "eip" {
  count = var.hosts
  vpc   = true
  tags = {
    Env = "kloud3s"
  }
  depends_on = [aws_internet_gateway.gw]
}


resource "aws_eip_association" "eip_assoc" {
  count                = var.hosts
  allocation_id        = aws_eip.eip[count.index].id
  network_interface_id = aws_network_interface.default[count.index].id
}

resource "aws_instance" "host" {

  count         = var.hosts
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.size
  key_name      = "ssh-key-${time_static.id.unix}"

  tags = {
    name = format(var.hostname_format, count.index + 1)
  }

  root_block_device {
    volume_size = 20
  }

  network_interface {
    network_interface_id = aws_network_interface.default[count.index].id
    device_index         = 0
  }

  connection {
    user        = "ubuntu"
    type        = "ssh"
    timeout     = "2m"
    host        = self.public_ip
    agent       = false
    private_key = file("${var.ssh_key_path}")
  }

  user_data = <<EOF
#cloud-config
runcmd:
  # Enable root ssh for subsequent modules.
  - sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys
  - sudo systemctl restart sshd
  - ip -o addr show scope global
EOF

  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get install -yq jq net-tools ufw wireguard-tools wireguard ${join(" ", var.apt_packages)}",
      "sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys",
      "sudo systemctl restart sshd",
    ]
  }

}

/*
data "external" "network_interfaces" {
  count   = var.hosts > 0 ? 1 : 0
  program = [
  "ssh",
  "-i", "${abspath(var.ssh_key_path)}",
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no",
  "-o", "UserKnownHostsFile=/dev/null",
  "root@${aws_instance.host[0].public_ip}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}
*/

output "hostnames" {
  value = "${aws_instance.host.*.tags.name}"
}

output "public_ips" {
  value = "${aws_instance.host.*.public_ip}"
}

output "private_ips" {
  value = "${aws_instance.host.*.private_ip}"
}

output "public_network_interface" {
  value = "eth0"
}

output "private_network_interface" {
  value = "eth0"
}

output "aws_instances" {
  value = "${aws_instance.host}"
}

output "region" {
  value = var.region
}

output "nodes" {

  value = [for index, server in aws_instance.host : {
    hostname   = server.tags.name
    public_ip  = server.public_ip
    private_ip = server.private_ip
  }]

}
