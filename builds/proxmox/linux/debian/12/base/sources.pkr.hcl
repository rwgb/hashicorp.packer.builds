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
  vm_id               = 9000
  vm_name             = "debian-12-base"
  template_description = local.build_description
  memory              = 4096
  cores               = 2
  sockets             = 2
  qemu_agent          = true
  disable_kvm         = true
  task_timeout        = "45m"
  tags                = "linux;debian-12;template;base"

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "${var.iso_storage_pool}:iso/debian-12.12.0-amd64-netinst.iso"
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
    storage_pool = var.disk_storage_pool
    disk_size    = "15G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
    firewall = false
  }

  // cloud init settings
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool

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
  ssh_timeout          = "90m"

  // http content
  http_content = local.source_content
}