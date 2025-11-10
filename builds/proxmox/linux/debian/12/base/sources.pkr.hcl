// Source definition for Debian 12 Base ISO build
source "proxmox-iso" "base" {
  // Proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id
  token       = var.token_secret

  // Proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls

  // Virtual machine settings
  vm_name              = "debian-12-base"
  vm_id                = var.vm_id_base
  memory               = 2048
  cores                = 2
  sockets              = 1
  qemu_agent           = true
  task_timeout         = "20m"
  template_description = "Debian 12 Base Template\nBuild Version: ${local.build_version}\nBuild Date: ${local.build_date}\nBuilt By: ${local.build_by}\n\nThis is the base template built from ISO. Clone this for customized builds."
  tags                 = "linux;debian;12;base;template;packer"

  // Install media
  boot_iso {
    type         = "scsi"
    iso_file     = var.iso_file
    iso_checksum = var.iso_checksum
    unmount      = true
  }

  // Disk settings
  disks {
    type         = "scsi"
    storage_pool = var.storage_pool
    disk_size    = var.disk_size_base
    format       = "raw"
  }

  // Network settings
  network_adapters {
    bridge   = var.network_bridge
    firewall = false
    model    = "virtio"
  }

  // Cloud-init settings
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool

  // Boot settings
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter><wait>"
  ]

  // Communicator settings
  communicator         = "ssh"
  ssh_username         = var.username
  ssh_password         = var.password
  ssh_private_key_file = data.sshkey.install.private_key_path
  ssh_timeout          = "20m"

  // HTTP content for preseed
  http_content = local.source_content
}
