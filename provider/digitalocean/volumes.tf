variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 10
  description = "Volume size"
}

resource "digitalocean_volume_attachment" "kube_volume_attach" {
  count      = var.enable_volumes ? var.hosts : 0
  droplet_id = digitalocean_droplet.host[count.index].id
  volume_id  = digitalocean_volume.kube_volume[count.index].id
}

resource "digitalocean_volume" "kube_volume" {
  count       = var.enable_volumes ? var.hosts : 0
  region      = var.region
  name        = format(var.hostname_format, count.index + 1)
  size        = var.volume_size
  description = "kloud3s extra volume"
}

resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = digitalocean_volume.kube_volume[count.index].id
    server = digitalocean_droplet.host[count.index].id
  }

  depends_on = [digitalocean_volume_attachment.kube_volume_attach]

  connection {
    host        = digitalocean_droplet.host[count.index].ipv4_address
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "mkfs.ext4 -F /dev/disk/by-id/scsi-0DO_Volume_${digitalocean_volume.kube_volume[count.index].name}",
      "mkdir -p /mnt/kloud3s",
      "mount -o discard,defaults /dev/disk/by-id/scsi-0DO_Volume_${digitalocean_volume.kube_volume[count.index].name} /mnt/kloud3s",
      "echo '/dev/disk/by-id/scsi-0DO_Volume_${digitalocean_volume.kube_volume[count.index].name} /mnt/kloud3s ext4 discard,nofail,defaults 0 0' >> /etc/fstab",
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
    host        = digitalocean_droplet.host[count.index].ipv4_address
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
