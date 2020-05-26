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
  default = "weave"
}

variable "overlay_cidr" {
  default = "10.96.0.0/16"
}

variable "drain_timeout" {
  default = "180"
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
  k3s_version = var.k3s_version == "latest" ? jsondecode(data.http.k3s_version[0].body).tag_name : var.k3s_version
  
  master_ip        = element(var.vpn_ips, 0)
  master_public_ip = element(var.connections, 0)
  
  agent_default_flags = [
    "-v 10",
    "--server https://${local.master_ip}:6443",
    "--token ${local.cluster_token}"
  ]
  
  agent_install_flags = join(" ", concat(local.agent_default_flags))
  
  server_default_flags = [
    "-v 10",
    "--disable servicelb", "--disable traefik", "--flannel-backend=none",
    "--node-ip ${local.master_ip}",
    "--tls-san ${local.master_public_ip}",
    "--tls-san ${local.master_ip}",
    #"--node-external-ip ${local.master_public_ip}",
    #"--cluster-domain ${var.cluster_name}",
    "--kube-apiserver-arg 'requestheader-allowed-names=system:auth-proxy,kubernetes-proxy'",
    "--token ${local.cluster_token}",
  ]
  
  server_install_flags = join(" ", concat(local.server_default_flags))
  
}

resource "null_resource" "k3s" {
  count = var.node_count
  
  triggers = {
    ip         = element(var.vpn_ips, 0)
    nodes      = var.node_count
    #always_run = "${timestamp()}"
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
  
  # Upload calico.yaml for CNI
  provisioner file {
    source      = "${path.module}/manifests/calico.yaml"
    destination = "/tmp/calico.yaml"
  }
      
  # Install K3S server
  provisioner "remote-exec" {
    inline = [<<EOT
      %{ if count.index == 0 ~}
        echo "[INFO] ---Installing k3s server---";
        ls -al /tmp;
        INSTALL_K3S_VERSION=${local.k3s_version} sh /tmp/k3s-installer ${local.server_install_flags};
        until kubectl get nodes | grep -v '[WARN] No resources found'; do sleep 5; done;
        until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
        kubectl apply -f /tmp/calico.yaml;
        #kubectl -n kube-system patch ds calico-node -p '{"spec":{"template":{"spec":{"containers":[{"env":[{"name":"IP_AUTODETECTION_METHOD","value":"interface=${var.overlay_interface}"},{"name":"CALICO_IPV4POOL_CIDR","value":"${var.overlay_cidr}"},{"name":"FELIX_HEALTHHOST","value":"0.0.0.0"}],"name":"calico-node"}]}}}}'
        #kubectl -n kube-system patch ds calico-node -p '{"spec":{"template":{"spec":{"containers":[{"env":[{"name":"IP_AUTODETECTION_METHOD","value":"interface=wg0"},{"name":"CALICO_IPV4POOL_CIDR","value":"10.42.0.0/16"},{"name":"FELIX_HEALTHHOST","value":"0.0.0.0"}],"name":"calico-node"}]}}}}'
        #kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')";
        echo "[INFO] ---Finished installing k3s server---";
      %{ else ~}
        echo "[INFO] ---Installing k3s agent---";
        until $(curl -fk -o nul https://${local.master_ip}:6443/ping); do echo '[WARN] Waiting for master to be ready'; sleep 5; done;
        until $(nc -z ${local.master_ip} 9099); do echo '[WARN] Waiting for calico'; sleep 5; done;
        until [ $(curl --write-out %%{http_code} -so nul http://${local.master_ip}:9099/readiness) -eq '204' ]; do echo '[WARN] Waiting for calico to be ready'; sleep 5; done;
        INSTALL_K3S_VERSION=${local.k3s_version} K3S_URL=https://${local.master_ip}:6443 K3S_TOKEN=${local.cluster_token} \
        sh /tmp/k3s-installer ${local.agent_install_flags} --node-ip ${element(var.vpn_ips, count.index)};
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
    #k3s_cache_obj   = null_resource.k3s_cache[count.index].triggers
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
      "kubectl drain ${self.triggers.node_name} --force --delete-local-data --ignore-daemonsets --timeout 180",
      "kubectl delete node ${self.triggers.node_name}",
      "sed -i \"/${self.triggers.node_name}/d\" /var/lib/rancher/k3s/server/cred/node-passwd",
    ]
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
