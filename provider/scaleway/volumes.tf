variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

resource "scaleway_instance_volume" "kube_volume" {
  count      = var.enable_volumes ? var.hosts : 0
  type       = "b_ssd"
  name       = format(var.hostname_format, count.index + 1)
  size_in_gb = var.volume_size
}

resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = scaleway_instance_volume.kube_volume[count.index].id
    server = scaleway_instance_server.host[count.index].public_ip
  }

  connection {
    host        = scaleway_instance_server.host[count.index].public_ip
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "mkfs.ext4 -F /dev/sda",
      "mkdir -p /mnt/kloud3s",
      "mount -o discard,defaults /dev/sda /mnt/kloud3s",
      "echo '/dev/sda /mnt/kloud3s ext4 discard,nofail,defaults 0 0' >> /etc/fstab",
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
    host        = scaleway_instance_server.host[count.index].public_ip
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "resize2fs /dev/sda || true",
      "df -h | grep sda || true",
    ]
  }
}
