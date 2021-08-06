variable "node_count" {}

variable "hostname_format" {
  type = string
}

variable "connections" {
  type = list(any)
}

variable "ssh_key_path" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpn_ips" {
  type    = list(any)
  default = []
}

variable "vpn_interface" {
  type = string
}

variable "private_ips" {
  type    = list(any)
  default = []
}

variable "etcd_endpoints" {
  type    = list(any)
  default = []
}

variable "k3s_version" {
  type = string
}

variable "debug_level" {
  description = "K3S debug level"
  default     = 3
}

variable "overlay_interface" {
  default = ""
}

variable "kubernetes_interface" {
  default     = ""
  description = "Interface on host that nodes use to communicate with each other. Can be the private interface or wg0 if wireguard is enabled."
}

variable "overlay_cidr" {
  default     = "10.42.0.0/16"
  description = "Cluster pod cidr"
}

variable "service_cidr" {
  default     = "10.43.0.0/16"
  description = "Cluster service cidr"
}

variable "vpn_iprange" {
  default     = "10.0.1.0/24"
  description = "Wireguard cidr"
}

variable enable_wireguard {
  default     = true
  description = "Create a vpn network for the hosts"
}

variable "cni" {
  default = "default"
}

variable "private_interface" {
  default = "eth0"
}

variable "domain" {
  default = "kloud3s.io"
}

variable "drain_timeout" {
  default = "60"
}

variable "ha_cluster" {
  default     = false
  type        = bool
  description = "Enable High Availability, Minimum number of nodes must be 3"
}

variable "ha_nodes" {
  default     = 3
  description = "Number of controller nodes for HA cluster. Must be greater than 3 and odd-numbered."
}

variable "loadbalancer" {
  default     = "metallb"
  description = "How LoadBalancer IPs are assigned. Options are metallb(default), traefik, ccm & akrobateo"
}

variable "cni_to_overlay_interface_map" {
  description = "The interface created by the CNI e.g. calico=vxlan.calico, cilium=cilium_vxlan, weave-net=weave, flannel=cni0/flannel.1"
  type        = map(any)
  default = {
    flannel = "cni0"
    weave   = "weave"
    cilium  = "cilium_host"
    calico  = "vxlan.calico"
    kilo    = "kilo0"
  }
}

variable "install_app" {
  description = "Additional apps to Install"
  type        = map(any)
  default     = {}
}

variable "oidc_config" {
  type        = list(map(string))
  description = "OIDC Configuration for protecting private resources. Used by Pomerium IAP & Vault."
  default     = []
}

variable "mail_config" {
  type        = map(string)
  description = "SMTP Configuration for email services."
  default     = {}
}

variable "s3_config" {
  type        = map(string)
  description = "S3 config for backups and other storage needs."
  default     = {}
}

variable "floating_ip" {
  description = "Floating IP"
  default     = {}
}

variable "longhorn_replicas" {
  default     = 3
  description = "Number of longhorn replicas, automatically set based on number of nodes"
}

variable "trform_domain" {
  type        = bool
  default     = false
  description = "Whether this domain is manged using terraform. If false external_dns will create DNS records."
}

variable "dns_auth" {
  type        = map(any)
  description = "Auth for configuring DNS including the provider"
  default = {
    provider = ""
    auth     = ""
  }
}

variable "create_certs" {
  type        = bool
  default     = false
  description = "Option to create letsencrypt certs. Only enable if certain that your deployment is reachable."
}

variable "acme_email" {
  type    = string
  default = ""
}

variable "auth_user" {
  default = "kloud-3s"
}

variable "auth_password" {
  default = ""
}

variable "region" {
  default = "k3s"
}

variable "enable_volumes" {
  default = "false"
}

resource "random_password" "token1" {
  length  = 16
  upper   = false
  special = false
}

resource "random_password" "token2" {
  length  = 16
  upper   = false
  special = false
}

locals {
  cluster_token = "${random_password.token1.result}.${random_password.token2.result}"
  k3s_version   = var.k3s_version == "latest" ? jsondecode(data.http.k3s_version[0].body).tag_name : var.k3s_version
  domain        = var.domain
  debug_level   = var.debug_level
  cni           = var.cni
  valid_cni     = ["weave", "calico", "cilium", "flannel", "default", (var.enable_wireguard == false ? "kilo" : "")]
  validate_cni  = index(local.valid_cni, local.cni)
  loadbalancer  = var.loadbalancer
  floating_ip   = lookup(var.floating_ip, "ip_address", "")

  # Set overlay interface from map, but optionally allow override
  overlay_interface    = var.overlay_interface == "" ? lookup(var.cni_to_overlay_interface_map, local.cni, "cni0") : var.overlay_interface
  overlay_cidr         = var.overlay_cidr
  service_cidr         = var.service_cidr
  private_interface    = var.private_interface
  kubernetes_interface = var.kubernetes_interface == "" ? var.vpn_interface : var.kubernetes_interface

  master_ip         = length(var.vpn_ips) > 0 ? var.vpn_ips[0] : ""
  master_public_ip  = length(var.connections) > 0 ? var.connections[0] : ""
  master_private_ip = length(var.private_ips) > 0 ? var.private_ips[0] : ""
  ssh_key_path      = var.ssh_key_path
  # Add validation for high availability here i.e. node_count > 3
  ha_nodes            = var.ha_nodes >= 3 && var.ha_nodes % 2 == 1 ? var.ha_nodes : 3
  ha_cluster          = var.node_count >= local.ha_nodes ? var.ha_cluster : false
  registration_domain = "k3s.${local.domain}"
  vpn_iprange         = var.vpn_iprange

  agent_node_labels = [
    "topology.kubernetes.io/region=${var.region}",
    "node.longhorn.io/create-default-disk=config",
  ]
  server_node_labels = [
    "topology.kubernetes.io/region=${var.region}",
    "node.longhorn.io/create-default-disk=config",
    "submariner.io/gateway=true",
  ]

  agent_default_flags = [
    "-v ${local.debug_level}",
    "--server https://${local.registration_domain}:6443",
    "--token ${local.cluster_token}",
    local.cni == "default" ? "--flannel-iface ${local.kubernetes_interface}" : "",
    # https://github.com/kubernetes/kubernetes/issues/75457
    "--kubelet-arg 'node-labels=role.node.kubernetes.io/worker=worker'",
    "--kubelet-arg 'node-status-update-frequency=4s'",
    "--kubelet-arg 'node-labels=${join(",", local.agent_node_labels)}'",
  ]

  agent_install_flags = join(" ", concat(local.agent_default_flags))

  server_default_flags = [
    "-v ${local.debug_level}",
    # Explicitly set default flannel interface
    local.cni == "default" ? "--flannel-iface ${local.kubernetes_interface}" : "--flannel-backend=none",
    # Disable network policy
    "--disable-network-policy",
    # Conditonally Disable service load balancer
    local.loadbalancer == "traefik" ? "" : "--disable servicelb",
    # Disable Traefik
    "--disable traefik",
    "--token ${local.cluster_token}",
    "--kubelet-arg 'node-status-update-frequency=4s'",
    "--kube-controller-manager-arg 'node-monitor-period=4s'",
    "--kube-controller-manager-arg 'node-monitor-grace-period=12s'",
    "--kube-controller-manager-arg 'pod-eviction-timeout=24s'",
    "--kube-apiserver-arg 'default-not-ready-toleration-seconds=10'",
    "--kube-apiserver-arg 'default-unreachable-toleration-seconds=10'",
    "--kubelet-arg 'node-labels=${join(",", local.server_node_labels)}'",
    # Flags left below to serve as examples for args that may need editing.
    # "--kube-controller-manager-arg 'node-cidr-mask-size=22'",
    # "--kubelet-arg 'max-pods=500'",
    # "--kube-apiserver-arg 'requestheader-allowed-names=system:auth-proxy,kubernetes-proxy'",

  ]

  server_leader_flags = [
    "--node-ip ${local.master_ip}",
    "--tls-san ${local.master_ip}",
    "--tls-san ${local.master_public_ip}",
    "--tls-san ${local.master_private_ip}",
    "--cluster-cidr ${local.overlay_cidr}",
    "--service-cidr ${local.service_cidr}",
    "--node-label 'kloud-3s.io/deploy-traefik=true'",
    local.ha_cluster == true ? "--cluster-init" : "--cluster-init",
    local.floating_ip == "" ? "--tls-san 127.0.0.2" : "--tls-san ${local.floating_ip}",
  ]

  server_follower_flags = [
    "--server https://${local.registration_domain}:6443",
    "--cluster-cidr ${local.overlay_cidr}",
    "--service-cidr ${local.service_cidr}",
  ]

  server_install_flags   = join(" ", concat(local.server_default_flags, local.server_leader_flags))
  follower_install_flags = join(" ", concat(local.server_default_flags, local.server_follower_flags))

}

resource "null_resource" "set_dns_rr" {
  # Use for fixed registration address
  count = var.node_count
  triggers = {
    registration_domain = local.registration_domain
    vpn_ips             = local.ha_cluster == true ? join(" ", slice(var.vpn_ips, 0, local.ha_nodes)) : local.master_ip
    node_public_ip      = element(var.connections, count.index)
    ssh_key_path        = var.ssh_key_path
    domain              = local.domain
  }

  connection {
    host        = self.triggers.node_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      join("\n", formatlist("echo '%s %s' >> /etc/hosts", split(" ", self.triggers.vpn_ips), self.triggers.registration_domain)),
    ]
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "grep -F -v '${self.triggers.registration_domain}' /etc/hosts > /etc/hosts.tmp && mv /etc/hosts.tmp /etc/hosts",
    ]
  }
}

resource "null_resource" "syslog_config" {
  count = var.node_count

  triggers = {
    node_public_ip = element(var.connections, count.index)
  }

  connection {
    host        = element(var.connections, count.index)
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [<<EOT
    cat <<-EOF > /etc/custom-logrotate.conf
/var/log/syslog
{
        su root syslog
        rotate 7
        daily
        maxsize 50M
        missingok
        notifempty
        delaycompress
        compress
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
EOF
      sed "s|/etc/logrotate.conf|/etc/custom-logrotate.conf|;s|exit 0|echo 'Exit Skipped'|" /etc/cron.daily/logrotate > /etc/cron.hourly/custom-logrotate;
      chmod +x /etc/cron.hourly/custom-logrotate;
      logrotate -d /etc/custom-logrotate.conf;
      logrotate -f -v /etc/custom-logrotate.conf;
      EOT
    ]
  }
}

resource "null_resource" "k3s" {
  count = var.node_count

  triggers = {
    master_public_ip       = local.master_public_ip
    node_public_ip         = element(var.connections, count.index)
    node_name              = format(var.hostname_format, count.index + 1)
    node_ip                = element(var.vpn_ips, count.index)
    node_private_ip        = element(var.private_ips, count.index)
    k3s_version            = local.k3s_version
    service_cidr           = local.service_cidr
    overlay_cidr           = local.overlay_cidr
    overlay_interface      = local.overlay_interface
    private_interface      = local.private_interface
    kubernetes_interface   = local.kubernetes_interface
    server_install_flags   = local.server_install_flags
    agent_install_flags    = local.agent_install_flags
    follower_install_flags = local.follower_install_flags
    ha_cluster             = local.ha_cluster
    registration_domain    = null_resource.set_dns_rr[count.index].triggers.registration_domain
    node_type              = count.index == 0 ? "controller" : (local.ha_cluster == true && count.index < local.ha_nodes ? "ha_controller" : "agent")
  }

  connection {
    host        = element(var.connections, count.index)
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "modprobe br_netfilter && echo br_netfilter >> /etc/modules",
    ]
  }

  # Upload k3s file
  provisioner "file" {
    content     = data.http.k3s_installer.body
    destination = "/tmp/k3s-installer"
  }

  # Unify CNI upload
  provisioner "remote-exec" {
    inline = count.index == 0 && local.cni != "default" ? [<<EOT
  %{if local.cni == "flannel"~}
  cat <<-EOF > /tmp/flannel.yaml
${data.template_file.flannel-configuration.rendered}
EOF
  %{endif~}
  %{if local.cni == "calico"~}
  cat <<-EOF > /tmp/calico.yaml
${data.template_file.calico-configuration.rendered}
EOF
  %{endif~}
  %{if local.cni == "cilium"~}
  cat <<-EOF > /tmp/cilium.yaml
${data.template_file.cilium-configuration.rendered}
EOF
  %{endif~}
  %{if local.cni == "weave"~}
  cat <<-EOF > /tmp/weave.yaml
${data.template_file.weave-configuration.rendered}
EOF
  %{endif~}
  %{if local.cni == "kilo"~}
  cat <<-EOF > /tmp/kilo.yaml
${data.template_file.kilo-configuration.rendered}
EOF
  %{endif~}
      EOT
    ] : null
  }


  # Install K3S server
  provisioner "remote-exec" {
    inline = [<<EOT
      %{if self.triggers.node_type == "controller"~}
      
        echo "[INFO] ---Uninstalling k3s-server---";
        # Clear CNI routes
        k3s-uninstall.sh && ip route | grep -e 'calico' -e 'weave' -e 'cilium' -e 'bird' | \
        while read -r line; do ip route del $line; done; \
        # Clear CNI interfaces
        ls /sys/class/net | grep -e 'cili' -e 'cali' -e 'weave' -e 'veth' -e 'vxlan' -e 'datapath' | \
        while read -r line; do ip link delete $line; done; \
        # Clean CNI config folder
        rm -rf /etc/cni/net.d/*; \
        # Rename weave interface as it cannot be deleted
        ifconfig datapath down; \
        ip link set datapath name dt$(date +'%y%m%d%H%M%S'); \
        echo "[INFO] ---Uninstalled k3s-server---" || \
        echo "[INFO] ---k3s not found. Skipping...---";
        
        # Download CNI plugins to /opt/cni/bin/ because most CNI's will look in that path
        %{if local.cni != "default"~}
        rm -rf /opt/cni/bin
        arch=$(uname -i)
        if [ "$arch" = "$${arch#arm}" ] || [ "$arch" = "aarch64" ]; then
          export id_arch=arm64
        else
          export id_arch=amd64
        fi
        [ -d "/opt/cni/bin" ] || \
        (echo "[ARCH] $(uname -i) : $id_arch" && \
        wget https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-$${id_arch}-v0.9.1.tgz && \
        tar zxvf cni-plugins-linux-$${id_arch}-v0.9.1.tgz && mkdir -p /opt/cni/bin && mv * /opt/cni/bin/);
        %{endif~}
        
        echo "==================================";
        echo "[INFO] ---Installing %{if local.ha_cluster~}HA%{endif} k3s server ${self.triggers.node_type}[${count.index}]---";
        echo "===================================";
                
        INSTALL_K3S_VERSION=${local.k3s_version} sh /tmp/k3s-installer server ${local.server_install_flags} \
        --node-name ${self.triggers.node_name} --node-external-ip ${self.triggers.node_public_ip};
        until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
        echo "[SUCCESS] API server is ready";
        until $(curl -fk -so nul https://${local.registration_domain}:6443/ping); do echo '[WARN] Waiting for master to be ready'; sleep 5; done;
        
        echo "[SUCCESS] Master is ready";
        
        # Patch coredns to tolerate external cloud provider taint
        kubectl -n kube-system patch deployment coredns --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]';
        
        echo "[INFO] ---Installing CNI ${local.cni}---";
        
        %{if local.cni == "cilium"~}
        sudo mount bpffs -t bpf /sys/fs/bpf
        kubectl apply -f /tmp/cilium.yaml;
        echo "[INFO] ---Master waiting for cilium---";
        kubectl rollout status ds cilium -n kube-system;
        %{endif~}
        
        %{if local.cni == "calico"~}
        until kubectl apply -f /tmp/calico.yaml;do nc -zvv localhost 6443; sleep 5; done;
        echo "[INFO] ---Master waiting for calico---";
        kubectl rollout status ds calico-node -n kube-system;
        %{endif~}
        
        %{if local.cni == "weave"~}
        # kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.NO_MASQ_LOCAL=1&env.IPALLOC_RANGE=${local.overlay_cidr}&env.WEAVE_MTU=1500";
        kubectl apply -f /tmp/weave.yaml;
        kubectl rollout status ds weave-net -n kube-system;
        %{endif~}
        
        %{if local.cni == "flannel"~}
        kubectl apply -f /tmp/flannel.yaml;
        kubectl rollout status ds kube-flannel-ds -n kube-system;
        %{endif~}
        
        %{if local.cni == "kilo"~}
        kubectl apply -f /tmp/kilo.yaml;
        %{endif~}
        
        echo "[INFO] ---Finished installing CNI ${local.cni}---";        
                        
        echo "[INFO] ---Finished installing k3s server---";
      %{else~}
        echo "[INFO] ---Uninstalling k3s---";
        # Clear CNI routes
        (k3s-agent-uninstall.sh || k3s-uninstall.sh) && ip route | grep -e 'calico' -e 'weave' -e 'cilium' -e 'bird' | \
        while read -r line; do ip route del $line; done; \
        # Clear CNI interfaces
        ls /sys/class/net | grep -e 'cili' -e 'cali' -e 'weave' -e 'veth' -e 'vxlan' -e 'datapath' | \
        while read -r line; do ip link delete $line; done; \
        # Clean CNI config folder
        rm -rf /etc/cni/net.d/*; \
        # Rename weave interface as it cannot be deleted
        ifconfig datapath down; \
        ip link set datapath name dt$(date +'%y%m%d%H%M%S'); \
        echo "[INFO] ---Uninstalled k3s---" || \
        echo "[INFO] ---k3s not found. Skipping...---";
        
               
        # CNI specific commands to run for nodes.
        # It is desirable to wait for networking to complete before proceeding with agent installation
        
        # Download CNI plugins to /opt/cni/bin/ because most CNI's will look in that path
        %{if local.cni != "default"~}
        rm -rf /opt/cni/bin
        arch=$(uname -i)
        if [ "$arch" = "$${arch#arm}" ] || [ "$arch" = "aarch64" ]; then
          export id_arch=arm64
        else
          export id_arch=amd64
        fi
        [ -d "/opt/cni/bin" ] || \
        (echo "[ARCH] $(uname -i) : $id_arch" && \
        wget https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-$${id_arch}-v0.9.1.tgz && \
        tar zxvf cni-plugins-linux-$${id_arch}-v0.9.1.tgz && mkdir -p /opt/cni/bin && mv * /opt/cni/bin/);
        %{endif~}
        
        %{if local.cni == "cilium"~}
        sudo mount bpffs -t bpf /sys/fs/bpf
        %{endif~}
                
        until $(curl -fk -so nul https://${local.registration_domain}:6443/ping); do echo '[WARN] Waiting for master to be ready'; sleep 5; done;
        
        %{if self.triggers.node_type == "ha_controller"~}
        
        echo "=============================================";
        echo "[INFO] ---Installing k3s server ${self.triggers.node_type}[${count.index}]---";
        echo "=============================================";

        until $(curl -f -so nul https://${local.registration_domain}:6443/ping --cacert /var/lib/rancher/k3s/agent/server-ca.crt); 
        do echo '[WARN] Waiting for master to be ready';

        INSTALL_K3S_VERSION=${local.k3s_version} sh /tmp/k3s-installer server ${local.follower_install_flags} \
        --node-name ${self.triggers.node_name} --node-ip ${self.triggers.node_ip} --node-external-ip ${self.triggers.node_public_ip} \
        --tls-san ${self.triggers.node_ip} --tls-san ${self.triggers.node_public_ip} --tls-san ${self.triggers.node_private_ip};
        
        done;
        echo "[INFO] ---Finished installing k3s server-follower---";
        
        %{else~}
        
        echo "===================================";
        echo "[INFO] ---Installing k3s ${self.triggers.node_type}[${count.index}]---";
        echo "===================================";

        until $(curl -f -so nul https://${local.registration_domain}:6443/ping --cacert /var/lib/rancher/k3s/agent/server-ca.crt); 
        do echo '[WARN] Waiting for master to be ready';

        INSTALL_K3S_VERSION=${local.k3s_version} \
        sh /tmp/k3s-installer agent ${local.agent_install_flags} --node-ip ${self.triggers.node_ip} \
        --node-name ${self.triggers.node_name} --node-external-ip ${self.triggers.node_public_ip};
        
        done;
        echo "[INFO] ---Finished installing k3s agent---";
        
        %{endif~}
        
      %{endif~}
    EOT
    ]
  }

}

# Get rid of cyclic errors by storing all required variables to be used in destroy provisioner
resource "null_resource" "k3s_cache" {
  count = var.node_count

  triggers = {
    node_name        = format(var.hostname_format, count.index + 1)
    master_public_ip = local.master_public_ip
    ssh_key_path     = var.ssh_key_path
  }
}

# Remove deleted node from cluster
resource "null_resource" "k3s_cleanup" {
  count = var.node_count

  triggers = {
    node_init        = null_resource.k3s[count.index].id
    k3s_cache        = null_resource.k3s_cache[count.index].id
    ssh_key_path     = null_resource.k3s_cache[count.index].triggers.ssh_key_path
    master_public_ip = null_resource.k3s_cache[count.index].triggers.master_public_ip
    node_name        = null_resource.k3s_cache[count.index].triggers.node_name
  }


  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file(self.triggers.ssh_key_path)
    timeout     = "2m"
  }

  # Clean up on deleting node
  provisioner "remote-exec" {

    when       = destroy
    on_failure = continue
    inline = [
      "echo 'Cleaning up ${self.triggers.node_name}...'",
      "kubectl drain ${self.triggers.node_name} --force --delete-emptydir-data --ignore-daemonsets --timeout 60s",
      "kubectl delete node ${self.triggers.node_name} --timeout 30s",
      "kubectl patch node ${self.triggers.node_name} -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge",
      "sed -i \"/${self.triggers.node_name}/d\" /var/lib/rancher/k3s/server/cred/node-passwd",
      "rm -rf /var/lib/rancher/k3s/agent/server-ca.crt",
    ]
  }

}

data "template_file" "calico-configuration" {
  template = file("${path.module}/templates/calico.yaml")

  vars = {
    interface   = local.kubernetes_interface
    calico_cidr = local.overlay_cidr
  }
}

data "template_file" "flannel-configuration" {
  template = file("${path.module}/templates/flannel.yaml")

  vars = {
    interface    = local.kubernetes_interface
    flannel_cidr = local.overlay_cidr
  }
}

data "template_file" "weave-configuration" {
  template = file("${path.module}/templates/weave.yaml")

  vars = {
    interface  = local.kubernetes_interface
    weave_cidr = local.overlay_cidr
  }
}

data "template_file" "cilium-configuration" {
  template = file("${path.module}/templates/cilium.yaml")

  vars = {
    interface   = local.kubernetes_interface
    cilium_cidr = local.overlay_cidr
  }
}

data "template_file" "kilo-configuration" {
  template = file("${path.module}/templates/kilo.yaml")

  vars = {
    interface = local.kubernetes_interface
    kilo_cidr = local.vpn_iprange
  }
}

data "http" "k3s_version" {
  count = var.k3s_version == "latest" ? 1 : 0
  url   = "https://api.github.com/repos/rancher/k3s/releases/latest"
}

data "http" "k3s_installer" {
  url = "https://raw.githubusercontent.com/rancher/k3s/master/install.sh"
}

output "overlay_interface" {
  value = local.overlay_interface
}

output "overlay_cidr" {
  value = local.overlay_cidr
}
