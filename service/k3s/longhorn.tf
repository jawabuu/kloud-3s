locals {
  longhorn = templatefile("${path.module}/templates/longhorn-helm.yaml", {
    longhorn_replicas = var.node_count < 4 ? (var.node_count == 3 ? 2 : 1) : var.longhorn_replicas
    domain            = var.domain
  })
}

resource "null_resource" "longhorn_apply" {
  # Skip if use_longhorn is false.
  count = var.node_count > 0 && lookup(var.install_app, "longhorn", false) == true ? 1 : 0
  triggers = {
    k3s_id           = join(" ", null_resource.k3s.*.id)
    longhorn         = md5(local.longhorn)
    ssh_key_path     = local.ssh_key_path
    master_public_ip = local.master_public_ip
    enable_volumes   = var.enable_volumes
  }

  # Use master(s)
  connection {
    host        = self.triggers.master_public_ip
    user        = "root"
    agent       = false
    private_key = file("${self.triggers.ssh_key_path}")
  }

  # Upload longhorn
  provisioner "file" {
    content     = local.longhorn
    destination = "/var/lib/rancher/k3s/server/manifests/longhorn.yaml"
  }

  # Annotate nodes
  provisioner "remote-exec" {
    inline = [<<EOT
      until $(nc -z localhost 6443); do echo '[WARN] Waiting for API server to be ready'; sleep 1; done;
      echo "[INFO] ---Annotating Nodes---";

      %{if var.enable_volumes == "true"~}
        until kubectl annotate --overwrite node --all node.longhorn.io/default-disks-config='[{ "path":"/var/lib/longhorn","allowScheduling":true},{"name":"fast-ssd-disk","path":"/mnt/kloud3s","allowScheduling":true,"storageReserved":524288000}]'; do nc -zvv localhost 6443; sleep 5; done;
      %{else~}
        until kubectl annotate --overwrite node --all node.longhorn.io/default-disks-config='[{ "path":"/var/lib/longhorn","allowScheduling":true}]'; do nc -zvv localhost 6443; sleep 5; done;
      %{endif~}

      echo "[INFO] ---Finished Annotating Nodes---";
    EOT
    ]
  }

}

output longhorn {
  value = local.longhorn
}
