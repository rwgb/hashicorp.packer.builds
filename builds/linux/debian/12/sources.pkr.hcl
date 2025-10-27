source "proxmox-iso" "debian_12_base" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     #api token id
  token       = var.token_secret #api token secret

  // proxmox settings
  node                     = var.node         # proxmox node
  pool                     = var.pool         # resource pool
  insecure_skip_tls_verify = var.insecure_tls # disables https checks during connections

  // virtual machine settings
  vm_name      = "debian12base"
  memory       = 1024
  cores        = 1
  sockets      = 1
  qemu_agent   = true
  task_timeout = "20m"
  tags         = "linux;debian;12;template;base"
  vm_notes     = local.vm_notes

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "shared-iso:iso/debian-12.1.0-amd64-netinst.iso"
    iso_checksum = "sha256:9da6ae5b63a72161d0fd4480d0f090b250c4f6bf421474e4776e82eea5cb3143bf8936bf43244e438e74d581797fe87c7193bbefff19414e33932fe787b1400f"
    unmount      = true
  }

  // cd files
  /*
  additional_iso_files {
    type             = "sata"
    iso_storage_pool = "packer_iso"
    cd_content = {
      "user-data" = templatefile("${abspath(path.root)}/data/user-data.pkrtpl.hcl", {
        guest_os_language   = var.guest_os_language
        guest_os_keyboard   = var.guest_os_keyboard
        guest_os_timezone   = var.guest_os_timezone
        username            = var.username
        password            = var.password
        id                  = local.short_id
        additional_packages = var.additional_packages
      })
      "meta-data" = templatefile("${abspath(path.root)}/data/meta-data.pkrtpl.hcl", {
        instance_id = "ci-${local.short_id}"
        hostname    = "debian-${local.short_id}"
      })
    }
  }
  */

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = "local-lvm"
    disk_size    = "5G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
    firewall = false
  }

  // cloud init settings
  cloud_init              = true
  cloud_init_storage_pool = "cidata"

  // boot settings
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter><wait>"
  ]

  // communicator settings
  communicator         = "ssh"
  ssh_username         = var.username
  ssh_password         = var.password
  ssh_private_key_file = data.sshkey.install.private_key_path
  ssh_timeout          = "20m"

  // http content
  http_content = local.source_content
}