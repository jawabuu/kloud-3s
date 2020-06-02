#!/bin/sh
set -e

ufw --force reset
ufw allow ssh
ufw allow in on ${private_interface} to any port ${vpn_port} # vpn on private interface
ufw allow in on ${vpn_interface}
ufw allow in on ${kubernetes_interface} # Kubernetes pod overlay interface
## Adding this because pods in a node cannot reach vpn_ip of the same node
## Especially necessary for CNIs that create multiple interfaces like cilium
ufw allow from ${overlay_cidr} # Allow communication on k8s pods network
ufw allow 6443 # Kubernetes API secure remote port
ufw allow 80
ufw allow 443
ufw default deny incoming
ufw --force enable
ufw status verbose
