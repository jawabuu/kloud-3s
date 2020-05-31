variable "api_key" {}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type = string
}

variable "region_id" {
  type = string
}

variable "plan_id" {
  type = string
}

variable "os_id" {
  type = string
}

variable "ssh_keys" {
  type = list
}

provider "vultr" {
  api_key     = var.api_key
  rate_limit  = 700
  retry_limit = 3
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

resource "vultr_ssh_key" "tf-kube" {
    count      = fileexists("${var.ssh_pubkey_path}") ? 1 : 0
    name       = "tf-kube"
    ssh_key    = file("${var.ssh_pubkey_path}")
}

resource "vultr_server" "host" {
  hostname    = format(var.hostname_format, count.index + 1)
  region_id   = var.region_id
  os_id       = var.os_id
  plan_id     = var.plan_id
  ssh_key_ids = vultr_ssh_key.tf-kube.*.id
  network_ids = [ vultr_network.kube-vpc.id ]
  enable_private_network = true

  count = var.hosts

  connection {
    user = "root"
    type = "ssh"
    timeout = "2m"
    host = self.main_ip
    agent = false
    private_key = file("${var.ssh_key_path}")
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq jq ufw ${join(" ", var.apt_packages)}",
    ]
  }
  
  # Set up private interface
  provisioner "remote-exec" {
    inline = [<<EOT
INSTANCE_METADATA=$(curl --silent http://169.254.169.254/v1.json);
PRIVATE_IP=$(curl --silent http://169.254.169.254/v1.json | jq -r .interfaces[1].ipv4.address);
PUBLIC_MAC=$(curl --silent http://169.254.169.254/v1.json | jq -r '.interfaces[] | select(.["network-type"]=="public") | .mac');
PRIVATE_MAC=$(curl --silent http://169.254.169.254/v1.json | jq -r '.interfaces[] | select(.["network-type"]=="private") | .mac');
cat <<-EOF > /etc/systemd/network/public.network
  [Match]
  MACAddress=$PUBLIC_MAC
  [Network]
  DHCP=yes
EOF
cat <<-EOF > /etc/systemd/network/private.network
  [Match]
  MACAddress=$PRIVATE_MAC
  [Network]
  Address=$PRIVATE_IP
EOF
systemctl restart systemd-networkd systemd-resolved;
ip -o addr show scope global | awk '{split($4, a, "/"); print $2" : "a[1]}';
    EOT
    ]
  }
  
}

data "external" "network_interfaces" {

  program = [
  "ssh", 
  "-i", "${abspath(var.ssh_key_path)}", 
  "-o", "IdentitiesOnly=yes",
  "-o", "StrictHostKeyChecking=no", 
  "-o", "UserKnownHostsFile=/dev/null", 
  "root@${vultr_server.host[0].main_ip}",
  "IFACE=$(ip -json addr show scope global | jq -r '.|tostring'); jq -n --arg iface $IFACE '{\"iface\":$iface}';"
  ]

}

output "hostnames" {
  value = "${vultr_server.host.*.hostname}"
}

output "public_ips" {
  value = "${vultr_server.host.*.main_ip}"
}

output "private_ips" {
  value = "${vultr_server.host.*.internal_ip}"
}

output "public_network_interface" {
  # ens3
  value = jsondecode(lookup(data.external.network_interfaces.result, "iface"))[0].ifname
}

output "private_network_interface" {
  # ens7
  value = jsondecode(lookup(data.external.network_interfaces.result, "iface"))[1].ifname
}

output "vultr_servers" {
  value = "${vultr_server.host}"
}
