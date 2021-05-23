variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

resource "hcloud_volume_attachment" "kube_volume_attach" {
  count     = var.enable_volumes ? var.hosts : 0
  volume_id = hcloud_volume.kube_volume[count.index].id
  server_id = hcloud_server.host[count.index].id
  automount = true
}

resource "hcloud_volume" "kube_volume" {
  count    = var.enable_volumes ? var.hosts : 0
  name     = format(var.hostname_format, count.index + 1)
  location = var.location
  size     = var.volume_size
  format   = "ext4"
}


resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = hcloud_volume.kube_volume[count.index].linux_device
    server = hcloud_server.host[count.index].id
  }

  connection {
    host        = hcloud_server.host[count.index].ipv4_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "mkfs.ext4 -F ${hcloud_volume.kube_volume[count.index].linux_device}",
      "mkdir -p /mnt/kloud3s",
      "mount -o discard,defaults ${hcloud_volume.kube_volume[count.index].linux_device} /mnt/kloud3s",
      "echo '${hcloud_volume.kube_volume[count.index].linux_device} /mnt/kloud3s ext4 discard,nofail,defaults 0 0' >> /etc/fstab",
    ]
  }
}


resource "null_resource" "resize_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    size = var.volume_size
  }
  depends_on = [null_resource.mount_volume]

  connection {
    host        = hcloud_server.host[count.index].ipv4_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "resize2fs /dev/sdb || true",
      "df -h | grep sdb || true",
    ]
  }
}
