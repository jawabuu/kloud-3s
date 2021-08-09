#!/bin/sh
set -e

ufw --force reset
ufw allow ssh
ufw allow in on ${vpn_interface}
# Kubernetes pod overlay interface created by CNI
ufw allow in on ${overlay_interface}

%{if enable_wireguard~}
# VPN on private interface
ufw allow in on ${private_interface} to any port ${vpn_port}
%{else~}
# VPN plus etcd and metrics ports
ufw allow in on ${private_interface}
%{endif~}

%{if cni == "kilo" ~}
echo net.ipv4.ip_forward=1 > /etc/sysctl.conf
sysctl -p
# ufw default allow routed
ufw default deny routed
## Instead of `ufw default allow routed`, we try to be more specific
ufw route allow in on ${overlay_interface}
ufw route allow in on ${vpn_interface}
## Packets from the internet to, for example, traefik pods
ufw route allow out on ${overlay_interface} to ${overlay_cidr}
%{endif~}

## Enable this to debug if pods cannot communicate across nodes and we pick the wrong overlay_interface
## Especially useful for CNIs that create multiple interfaces
# ufw allow from ${overlay_cidr} # Allow communication on k8s pods network
ufw allow 6443 # Kubernetes API secure remote port
ufw allow 80
ufw allow 443
${additional_rules}
ufw default deny incoming
ufw --force enable || ufw logging off && ufw --force enable  ||  true
ufw status verbose
# https://bugs.launchpad.net/ubuntu/+source/ufw/+bug/1726856
sed -i.bak '/ufw enable/d' /etc/crontab && echo '@reboot root ufw enable' >> /etc/crontab