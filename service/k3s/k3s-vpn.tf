locals{
    k3s_vpn         = false
    k3s_vpn_iprange = "10.10.10.8/29"
}


 resource "null_resource" "k3s_vpn" {
  count = local.k3s_vpn  ? ( local.ha_cluster ? local.ha_nodes : 1 ) : 0

  triggers = {
    node_public_ip        = element(var.connections, count.index)
    node_name             = format(var.hostname_format, count.index + 1)
    vpn_ip                = cidrhost(local.k3s_vpn_iprange, count.index + 1)
  }

  connection {
    host        = element(var.connections, count.index)
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
  }


  provisioner "remote-exec" {
    inline = [<<EOT
    cat <<-EOF > /etc/systemd/system/k3s_vpn.service
[Unit]
Description=K3S Node VPN
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
Environment="KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
ExecStart=/bin/bash -c 'kgctl connect ${self.triggers.node_name} --allowed-ip=${self.triggers.vpn_ip}/32 --allowed-ips=${local.service_cidr} --log-level=debug --topology-label=kubernetes.io/hostname --clean-up=false --private-key=/etc/wg-privatekey'
TimeoutSec=30
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    wget -q https://github.com/squat/kilo/releases/download/0.5.0/kgctl-linux-amd64 && \
    mv kgctl-linux-amd64 /usr/bin/kgctl && chmod a+x /usr/bin/kgctl;
    [ -f /etc/wg-privatekey ] && echo "wg key exists" || wg genkey > /etc/wg-privatekey;
    systemctl enable k3s_vpn.service;
    systemctl start k3s_vpn.service;
    
    EOT
    ]
  }
}