variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

resource "vultr_block_storage" "kube_volume" {
  count       = var.enable_volumes ? var.hosts : 0
  size_gb     = var.volume_size
  region_id   = data.vultr_region.region.id #Must be "ewr"
  attached_id = vultr_server.host[count.index].id
  live        = "yes"
  label       = format(var.hostname_format, count.index + 1)
}


resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = vultr_block_storage.kube_volume[count.index].id
    server = vultr_server.host[count.index].id
  }

  connection {
    host        = vultr_server.host[count.index].main_ip
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
    host        = vultr_server.host[count.index].main_ip
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "resize2fs /dev/vdb || true",
      "df -h | grep vdb || true",
    ]
  }
}
