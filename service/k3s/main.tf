variable "node_count" {}

variable "hostname_format" {
  type = string
}

variable "connections" {
  type = list
}

variable "ssh_key_path" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpn_ips" {
  type    = list
  default = []
}

variable "vpn_interface" {
  type = string
}

variable "private_ips" {
  type    = list
  default = []
}

variable "etcd_endpoints" {
  type    = list
  default = []
}

variable "k3s_version" {
  type = string
}

variable "debug_level" {
  description = "K3S debug level"
  default     = 5
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

variable "loadbalancer" {
  default     = "metallb"
  description = "How LoadBalancer IPs are assigned. Options are metallb(default), traefik, ccm & akrobateo"
}

variable "cni_to_overlay_interface_map" {
  description = "The interface created by the CNI e.g. calico=vxlan.calico, cilium=cilium_vxlan, weave-net=weave, flannel=cni0/flannel.1"
  type        = map
  default = {
    flannel = "cni0"
    weave   = "weave"
    cilium  = "cilium_host"
    calico  = "vxlan.calico"
  }
}

variable "install_app" {
  description = "Additional apps to Install"
  type        = map
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

variable "floating_ip" {
  description = "Floating IP"
  default     = {}
}

variable "longhorn_replicas" {
  default     = 3
  description = "Number of longhorn replicas"
}

variable "trform_domain" {
  type        = bool
  default     = false
  description = "Whether this domain is manged using terraform. If false external_dns will create DNS records."
}

variable "dns_auth" {
  type        = map
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

resource "random_string" "token1" {
  length  = 6
  upper   = false
  special = false
}

resource "random_string" "token2" {
  length  = 16
  upper   = false
  special = false
}

locals {
  cluster_token = "${random_string.token1.result}.${random_string.token2.result}"
  k3s_version   = var.k3s_version == "latest" ? jsondecode(data.http.k3s_version[0].body).tag_name : var.k3s_version
  domain        = var.domain
  debug_level   = var.debug_level
  cni           = var.cni
  valid_cni     = ["weave", "calico", "cilium", "flannel", "default"]
  validate_cni  = index(local.valid_cni, local.cni)
  loadbalancer  = var.loadbalancer
  floating_ip   = try(var.floating_ip.ip_address, "")

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
  ha_cluster          = var.ha_cluster
  registration_domain = "k3s.${local.domain}"

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
    "--kube-controller-manager-arg 'node-monitor-period=2s'",
    "--kube-controller-manager-arg 'node-monitor-grace-period=16s'",
    "--kube-controller-manager-arg 'pod-eviction-timeout=24s'",
    "--kube-apiserver-arg 'default-not-ready-toleration-seconds=20'",
    "--kube-apiserver-arg 'default-unreachable-toleration-seconds=20'",
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
    local.ha_cluster == true ? "--cluster-init" : "",
    local.floating_ip == "" ? "--tls-san 127.0.0.2" : "--tls-san ${local.floating_ip}",
  ]

  server_follower_flags = [
    "--server https://${local.registration_domain}:6443",
  ]

  server_install_flags   = join(" ", concat(local.server_default_flags, local.server_leader_flags))
  follower_install_flags = join(" ", concat(local.server_default_flags, local.server_follower_flags))

}

resource "null_resource" "set_dns_rr" {
  # Use for fixed registration address
  count = var.node_count
  triggers = {
    registration_domain = local.registration_domain
    vpn_ips             = local.ha_cluster == true ? join(" ", slice(var.vpn_ips, 0, 3)) : local.master_ip
    node_public_ip      = element(var.connections, count.index)
    ssh_key_path        = var.ssh_key_path
    domain              = local.domain
  }

  connection {
    host        = self.triggers.node_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "${join("\n", formatlist("echo '%s %s' >> /etc/hosts", split(" ", self.triggers.vpn_ips), self.triggers.registration_domain))}",
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
    registration_domain    = null_resource.set_dns_rr[count.index].triggers.registration_domain
    # Below is used to debug triggers
    # always_run            = "${timestamp()}"
  }

  connection {
    host        = element(var.connections, count.index)
    user        = "root"
    agent       = false
    private_key = file("${var.ssh_key_path}")
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get install -qy jq",
      "modprobe br_netfilter && echo br_netfilter >> /etc/modules",
    ]
  }

  # Upload k3s file
  provisioner file {
    content     = data.http.k3s_installer.body
    destination = "/tmp/k3s-installer"
  }

  # Upload calico.yaml for CNI
  provisioner "file" {
    content     = data.template_file.calico-configuration.rendered
    destination = "/tmp/calico.yaml"
  }

  # Upload flannel.yaml for CNI
  provisioner "file" {
    content     = data.template_file.flannel-configuration.rendered
    destination = "/tmp/flannel.yaml"
  }

  # Upload weave.yaml for CNI
  provisioner "file" {
    content     = data.template_file.weave-configuration.rendered
    destination = "/tmp/weave.yaml"
  }

  # Upload cilium.yaml for CNI
  provisioner "file" {
    content     = data.template_file.cilium-configuration.rendered
    destination = "/tmp/cilium.yaml"
  }

  # Install K3S server
  provisioner "remote-exec" {
    inline = [<<EOT
      %{if count.index == 0~}
      
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
        [ -d "/opt/cni/bin" ] || \
        (wget https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-amd64-v0.8.6.tgz && \
        tar zxvf cni-plugins-linux-amd64-v0.8.6.tgz && mkdir -p /opt/cni/bin && mv * /opt/cni/bin/);
        %{endif~}
        
        echo "[INFO] ---Installing k3s server---";
                
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
        kubectl rollout status ds kube-flannel-ds-amd64 -n kube-system;
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
        [ -d "/opt/cni/bin" ] || \
        (wget https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-amd64-v0.8.6.tgz && \
        tar zxvf cni-plugins-linux-amd64-v0.8.6.tgz && mkdir -p /opt/cni/bin && mv * /opt/cni/bin/);
        %{endif~}
        
        %{if local.cni == "cilium"~}
        sudo mount bpffs -t bpf /sys/fs/bpf
        %{endif~}
                
        until $(curl -fk -so nul https://${local.registration_domain}:6443/ping); do echo '[WARN] Waiting for master to be ready'; sleep 5; done;
        
        %{if local.ha_cluster == true && count.index < 3~}
        
        echo "[INFO] ---Installing k3s server-follower---";

        until $(curl -fv -so nul https://${local.registration_domain}:6443/ping --cacert /var/lib/rancher/k3s/agent/server-ca.crt); 
        do echo '[WARN] Waiting for master to be ready';

        INSTALL_K3S_VERSION=${local.k3s_version} sh /tmp/k3s-installer server ${local.follower_install_flags} \
        --node-name ${self.triggers.node_name} --node-ip ${self.triggers.node_ip} --node-external-ip ${self.triggers.node_public_ip} \
        --tls-san ${self.triggers.node_ip} --tls-san ${self.triggers.node_public_ip} --tls-san ${self.triggers.node_private_ip};
        
        done;
        echo "[INFO] ---Finished installing k3s server-follower---";
        
        %{else~}
        
        echo "[INFO] ---Installing k3s agent---";

        until $(curl -fv -so nul https://${local.registration_domain}:6443/ping --cacert /var/lib/rancher/k3s/agent/server-ca.crt); 
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
resource null_resource k3s_cache {
  count = var.node_count

  triggers = {
    node_name        = format(var.hostname_format, count.index + 1)
    master_public_ip = local.master_public_ip
    ssh_key_path     = var.ssh_key_path
  }
}

# Remove deleted node from cluster
resource null_resource k3s_cleanup {
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
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Clean up on deleting node
  provisioner remote-exec {

    when       = destroy
    on_failure = continue
    inline = [
      "echo 'Cleaning up ${self.triggers.node_name}...'",
      "kubectl drain ${self.triggers.node_name} --force --delete-local-data --ignore-daemonsets --timeout 180s",
      "kubectl delete node ${self.triggers.node_name}",
      "sed -i \"/${self.triggers.node_name}/d\" /var/lib/rancher/k3s/server/cred/node-passwd",
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
