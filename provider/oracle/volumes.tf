variable "enable_volumes" {
  default     = false
  description = "Whether to use volumes or not"
}

variable "volume_size" {
  default     = 50
  description = "Volume size"
}

resource "oci_core_volume" "kube_volume" {
  count               = var.enable_volumes ? var.hosts : 0
  availability_domain = oci_core_instance.host[count.index].availability_domain
  #Required
  compartment_id = var.tenancy_ocid

  #Optional
  display_name = format(var.hostname_format, count.index + 1)
  size_in_gbs  = var.volume_size
}

resource "oci_core_volume_attachment" "kube_volume_attach" {
  count = var.enable_volumes ? var.hosts : 0
  #Required
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.host[count.index].id
  volume_id       = oci_core_volume.kube_volume[count.index].id

  #Optional
  # device = var.volume_attachment_device
  display_name = format(var.hostname_format, count.index + 1)
}

resource "null_resource" "mount_volume" {
  count = var.enable_volumes ? var.hosts : 0
  triggers = {
    volume = oci_core_volume.kube_volume[count.index].id
    server = oci_core_instance.host[count.index].id
  }

  depends_on = [oci_core_volume_attachment.kube_volume_attach]

  connection {
    host        = oci_core_instance.host[count.index].public_ip
    user        = "root"
    agent       = false
    private_key = file(var.ssh_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      "mkfs.ext4 -F /dev/sdb",
      "mkdir -p /mnt/kloud3s",
      "mount -o discard,defaults /dev/sdb /mnt/kloud3s",
      "echo '/dev/sdb /mnt/kloud3s ext4 discard,nofail,defaults 0 0' >> /etc/fstab",
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
    host        = oci_core_instance.host[count.index].public_ip
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