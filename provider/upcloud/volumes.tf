variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

resource "upcloud_storage" "kube_volume" {
  count = var.enable_volumes ? var.hosts : 0
  size  = var.volume_size
  title = format(var.hostname_format, count.index + 1)
  zone  = var.location
}


resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = upcloud_storage.kube_volume[count.index].id
    server = upcloud_server.host[count.index].id
  }

  connection {
    host        = upcloud_server.host[count.index].network_interface[0].ip_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "mkfs.ext4 -F /dev/vdb",
      "mkdir -p /mnt/kloud3s",
      "mount -o discard,defaults /dev/vdb /mnt/kloud3s",
      "echo '/dev/vdb /mnt/kloud3s ext4 discard,nofail,defaults 0 0' >> /etc/fstab",
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
    host        = upcloud_server.host[count.index].network_interface[0].ip_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "resize2fs /dev/vdb || true",
      "df -h | grep vdb || true",
      ## UpCloud stops instances when resizing volumes.
      ## DNS breaks and you may have to turn on instances from the console.
      "systemctl restart systemd-resolved.service",
    ]
  }
}
