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
  type = list
}

variable "vpn_interface" {
  type = string
}

variable "private_ips" {
  type = list
  default = []
}

variable "etcd_endpoints" {
  type    = list
  default = []
}

variable "k3s_version" {
  type = string
}

variable "cluster_cidr_pods" {
  default = "10.42.0.0/16"
}

variable "cluster_cidr_services" {
  default = "10.43.0.0/16"
}

variable "overlay_interface" {
  default = "cni0"
}

variable "kubernetes_interface" {
  default     = ""
  description = "Interface on host that nodes use to communicate with each other. Can be the private interface or wg0 if wireguard is enabled."
}

variable "overlay_cidr" {
  default = "10.42.0.0/16"
}

variable "cni" {
  default = "flannel"
}

variable "private_interface" {
  default = "eth0"
}

variable "domain" {
  default = "example.com"
}

variable "drain_timeout" {
  default = "60"
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
  cni           = var.cni
  
  overlay_cidr         = var.overlay_cidr
  overlay_interface    = var.overlay_interface
  private_interface    = var.private_interface
  kubernetes_interface = var.kubernetes_interface == "" ? var.vpn_interface : var.kubernetes_interface
  
  master_ip            = element(var.vpn_ips, 0)
  master_public_ip     = element(var.connections, 0)
  master_private_ip    = element(var.private_ips, 0)
  
  agent_default_flags = [
    "-v 5",
    "--server https://${local.master_ip}:6443",
    "--token ${local.cluster_token}",
    local.cni == "flannel" ? "--flannel-iface ${local.kubernetes_interface}" : "--kubelet-arg 'network-plugin=cni'",
  ]
  
  agent_install_flags = join(" ", concat(local.agent_default_flags))
  
  server_default_flags = [
    "-v 5",
    # Explicitly set flannel interface
    local.cni == "flannel" ? "--flannel-iface ${local.kubernetes_interface}" : "--flannel-backend=none",
    # Optionally disable network policy
    local.cni == "flannel" ? "--disable-network-policy" : "--disable-network-policy",
    # Optionally disable service load balancer
    local.cni == "flannel" ? "--disable servicelb" : "--disable servicelb",
    "--disable traefik",
    "--node-ip ${local.master_ip}",
    "--tls-san ${local.master_ip}",
    "--tls-san ${local.master_public_ip}",
    "--tls-san ${local.master_private_ip}",
    "--cluster-cidr ${local.overlay_cidr}",
    "--token ${local.cluster_token}",
    "--kubelet-arg 'network-plugin=cni'",
    # Flags left below to serve as examples for args that may need editing.    
    #"--node-external-ip ${local.master_private_ip}",
    #"--cluster-domain ${var.cluster_name}",  
    #"--cluster-cidr ${var.cluster_cidr_pods}",
    #"--service-cidr ${var.cluster_cidr_services}",    
    #"--kube-apiserver-arg 'requestheader-allowed-names=system:auth-proxy,kubernetes-proxy'",  
    
  ]
  
  server_install_flags = join(" ", concat(local.server_default_flags))
  
}

resource "null_resource" "k3s" {
  count = var.node_count
  
  triggers = {
    master_public_ip      = local.master_public_ip
    node_public_ip        = element(var.connections, count.index)
    node_name             = format(var.hostname_format, count.index + 1)
    k3s_version           = local.k3s_version
    overlay_cidr          = local.overlay_cidr
    overlay_interface     = local.overlay_interface
    private_interface     = local.private_interface
    kubernetes_interface  = local.kubernetes_interface
    # Below is used to debug triggers
    always_run            = "${timestamp()}"
  }

  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = false
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
  
  # Upload manifests 
  provisioner file {
    source      = "${path.module}/manifests"
    destination = "/tmp"
  }
  
  # Upload calico.yaml for CNI
  provisioner "file" {
    content     = data.template_file.calico-configuration.rendered
    destination = "/tmp/calico.yaml"
  }
  
  # Upload basic certificate issuer
  provisioner "file" {
    content     = data.template_file.basic-cert-issuer.rendered
    destination = "/tmp/basic-cert-issuer.yaml"
  }
  
  # Upload basic traefik test
  provisioner "file" {
    content     = data.template_file.basic-traefik-test.rendered
    destination = "/tmp/basic-traefik-test.yaml"
  }
      
  # Install K3S server
  provisioner "remote-exec" {
    inline = [<<EOT
      %{ if count.index == 0 ~}
      
        echo "[INFO] ---Uninstalling k3s-sever---";
        k3s-uninstall.sh && ip route | grep 'calico\|weave\|cilium' | while read -r line; do ip route del $line; done; \
        ls /sys/class/net | grep 'cili\|cali\|weave\|veth\|vxlan' | while read -r line; do ip link delete $line; done; \
        rm -rf /etc/cni/net.d/*; \
        echo "[INFO] ---Uninstalled k3s-server---" || \
        echo "[INFO] ---k3s not found. Skipping...---";
        
        echo "[INFO] ---Installing k3s server---";
        
        %{ if local.cni == "weave" ~}
        wget https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-amd64-v0.8.6.tgz && tar zxvf cni-plugins-linux-amd64-v0.8.6.tgz && mkdir -p /opt/cni/bin && mv * /opt/cni/bin/;
        %{ endif ~}
        
        INSTALL_K3S_VERSION=${local.k3s_version} sh /tmp/k3s-installer ${local.server_install_flags} \
        --node-name ${self.triggers.node_name};
        # until kubectl get nodes | grep -v '[WARN] No resources found'; do sleep 5; done;
        until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
        echo "[SUCCESS] API server is ready";
        until $(curl -fk -so nul https://${local.master_ip}:6443/ping); do echo '[WARN] Waiting for master to be ready'; sleep 5; done;
        
        echo "[SUCCESS] Master is ready";
        echo "[INFO] ---Installing CNI ${local.cni}---";
        
        %{ if local.cni == "cilium" ~}
        sudo mount bpffs -t bpf /sys/fs/bpf
        kubectl apply -f /tmp/manifests/cilium.yaml;
        echo "[INFO] ---Master waiting for cilium---";
        kubectl rollout status ds cilium -n kube-system;
        %{ endif ~}
        
        %{ if local.cni == "calico" ~}
        until kubectl apply -f /tmp/calico.yaml;do nc -zvv localhost 6443; sleep 5; done;
        echo "[INFO] ---Master waiting for calico---";
        kubectl rollout status ds calico-node -n kube-system;
        until $(nc -z ${local.master_ip} 9099); do echo '[WARN] Waiting for calico'; sleep 5; done;
        %{ endif ~}
        
        %{ if local.cni == "weave" ~}
        kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.NO_MASQ_LOCAL=1&env.IPALLOC_RANGE=${local.overlay_cidr}&env.WEAVE_MTU=1500";
        %{ endif ~}
        
        echo "[INFO] ---Finished installing CNI ${local.cni}---";
        
        # Install cert-manager
        kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.yaml;
        # Wait for cert-manager-webhook to be ready
        kubectl rollout status -n cert-manager deployment cert-manager-webhook --timeout 150s;
        # Install basic cert issuer
        kubectl apply -f /tmp/basic-cert-issuer.yaml;
        # Install traefik
        kubectl apply -f /tmp/manifests/traefik-k3s.yaml;
        # Install basic traefik test
        kubectl apply -f /tmp/basic-traefik-test.yaml;
        
        echo "[INFO] ---Finished installing k3s server---";
      %{ else ~}
        echo "[INFO] ---Uninstalling k3s---";
        k3s-agent-uninstall.sh && ip route | grep 'calico\|weave\|cilium' | while read -r line; do ip route del $line; done; \
        ls /sys/class/net | grep 'cili\|cali\|weave\|veth\|vxlan' | while read -r line; do ip link delete $line; done; \
        rm -rf /etc/cni/net.d/*; \
        echo "[INFO] ---Uninstalled k3s-server---" || \
        echo "[INFO] ---k3s not found. Skipping...---";
        
        echo "[INFO] ---Installing k3s agent---";        
        # CNI specific commands to run for nodes.
        # It is desirable to wait for networking to complete before proceeding with agent installation
        %{ if local.cni == "cilium" ~}
        sudo mount bpffs -t bpf /sys/fs/bpf
        %{ endif ~}
        
        %{ if local.cni == "calico" ~}
        echo "[INFO] ---Agent waiting for calico---";
        until $(nc -z ${local.master_ip} 9099); do echo '[WARN] Waiting for calico'; sleep 5; done;
        %{ endif ~}
        
        %{ if local.cni == "weave" ~}
        wget https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-amd64-v0.8.6.tgz && tar zxvf cni-plugins-linux-amd64-v0.8.6.tgz && mkdir -p /opt/cni/bin && mv * /opt/cni/bin/;
        %{ endif ~}
        
        until $(curl -fk -so nul https://${local.master_ip}:6443/ping); do echo '[WARN] Waiting for master to be ready'; sleep 5; done;
        
        INSTALL_K3S_VERSION=${local.k3s_version} K3S_URL=https://${local.master_ip}:6443 K3S_TOKEN=${local.cluster_token} \
        sh /tmp/k3s-installer ${local.agent_install_flags} --node-ip ${element(var.vpn_ips, count.index)} \
        --node-name ${self.triggers.node_name};
        echo "[INFO] ---Finished installing k3s agent---";
      %{ endif ~}
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
    host  = self.triggers.master_public_ip
    user  = "root"
    agent = false
    private_key = file("${self.triggers.ssh_key_path}")
  }
  
  # Clean up on deleting node
  provisioner remote-exec { 
    
    when = destroy
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
    interface     =  local.kubernetes_interface
    calico_cidr   =  local.overlay_cidr
  }
}

data "template_file" "basic-cert-issuer" {
  template = file("${path.module}/templates/basic-cert-issuer.yaml")

  vars = {
    domain        =  local.domain
  }
}

data "template_file" "basic-traefik-test" {
  template = file("${path.module}/templates/basic-traefik-test.yaml")

  vars = {
    domain        =  local.domain
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
  value = var.overlay_interface
}

output "overlay_cidr" {
  value = var.overlay_cidr
}
