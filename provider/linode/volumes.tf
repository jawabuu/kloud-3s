variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

resource "linode_volume" "kube_volume" {
  count     = var.enable_volumes ? var.hosts : 0
  region    = var.location
  label     = format(var.hostname_format, count.index + 1)
  size      = var.volume_size
  linode_id = linode_instance.host[count.index].id
}

resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = linode_volume.kube_volume[count.index].id
    server = linode_instance.host[count.index].id
  }

  connection {
    host        = linode_instance.host[count.index].ip_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "mkfs.ext4 -F /dev/disk/by-id/scsi-0Linode_Volume_${linode_volume.kube_volume[count.index].label}",
      "mkdir -p /mnt/kloud3s",
      "mount -o discard,defaults /dev/disk/by-id/scsi-0Linode_Volume_${linode_volume.kube_volume[count.index].label} /mnt/kloud3s",
      "echo '/dev/disk/by-id/scsi-0Linode_Volume_${linode_volume.kube_volume[count.index].label} /mnt/kloud3s ext4 discard,nofail,defaults 0 0' >> /etc/fstab",
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
    host        = linode_instance.host[count.index].ip_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "resize2fs /dev/sdc || true",
      "df -h | grep sdc || true",
    ]
  }
}
