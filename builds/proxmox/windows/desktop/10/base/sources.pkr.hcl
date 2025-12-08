// proxmox-iso source for Windows 10 22H2 Base
source "proxmox-iso" "windows_10_22h2_base" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     # api token id
  token       = var.token_secret # api token secret

  // proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  task_timeout             = "20m"

  // virtual machine settings
  vm_id                = 9020
  vm_name              = "win-10-22h2-base"
  memory               = 8192
  cores                = 3
  sockets              = 2
  qemu_agent           = true
  disable_kvm          = true
  scsi_controller      = "virtio-scsi-single"
  tags                 = "windows;desktop;windows-10;22h2;template;base"
  template_description = "Windows 10 22H2 Professional Base Template\nBuild Version: ${local.build_version}\nBuilt on: ${local.build_date}\nAuthor: ${local.git_author}\nCommitter: ${local.git_committer}\nCommit Timestamp: ${local.git_timestamp}\n${local.build_by}"

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/Win10_22H2_English_x64v1.iso"
    iso_checksum = "none"
    unmount      = true
  }

  // cd files
  additional_iso_files {
    type             = "sata"
    cd_label         = "win10_drivers"
    iso_storage_pool = var.iso_storage_pool
    cd_files = [
      "${path.cwd}/drivers",
      "../../../scripts"
    ]
    cd_content = {
      "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
        is_efi           = false
        username         = var.username
        password         = var.password
        inst_os_language = var.guest_os_language
        inst_os_keyboard = var.guest_os_keyboard
        inst_os_image    = "Windows 10 Pro N for Workstations"
        kms_key          = "9FNHH-K3HBT-3W4TD-6383H-6XYWF"
        guest_os_language = var.guest_os_language
        guest_os_keyboard = var.guest_os_keyboard
        guest_os_timezone = var.guest_os_timezone
      })
    }
  }

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = var.disk_storage_pool
    disk_size    = "60G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
    model    = "e1000"
    firewall = false
  }

  // boot settings
  boot_wait    = "5s"
  boot_command = [
    "<spacebar><spacebar>",
    "<wait10><wait10><wait10>",
    "<enter><wait>",
    "<enter><wait>",
    "<enter><wait>"
  ]

  // communicator settings
  communicator   = "winrm"
  winrm_username = var.username
  winrm_password = var.password
  winrm_port     = 5985
  winrm_timeout  = "120m"
  winrm_insecure = true
  winrm_use_ssl  = false
  winrm_use_ntlm = true
}
