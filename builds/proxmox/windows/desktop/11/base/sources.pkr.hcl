// proxmox-iso source for Windows 11 Base
source "proxmox-iso" "windows_11_base" {
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
  vm_id                = 9023
  vm_name              = "win-11-25H2-base"
  memory               = 4096
  cores                = 2
  sockets              = 2
  qemu_agent           = true
  disable_kvm          = true
  scsi_controller      = "virtio-scsi-single"
  tags                 = "windows;desktop;windows-11;template;base"
  template_description = "Windows 11 Enterprise Base Template\nBuild Version: ${local.build_version}\nBuilt on: ${local.build_date}\nAuthor: ${local.git_author}\nCommitter: ${local.git_committer}\nCommit Timestamp: ${local.git_timestamp}\n${local.build_by}"

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
    iso_checksum = "none"
    unmount      = true
  }

  // cd files
  additional_iso_files {
    type             = "sata"
    cd_label         = "win11_drivers"
    iso_storage_pool = var.iso_storage_pool
    cd_files = [
      "${path.cwd}/drivers",
      "../../../scripts"
    ]
    cd_content = {
      "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
        is_efi            = false
        username          = var.username
        password          = var.password
        inst_os_language  = var.guest_os_language
        inst_os_keyboard  = var.guest_os_keyboard
        inst_os_image     = "Windows 11 Enterprise Evaluation"
        kms_key           = ""
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
  boot_command = ["<spacebar><spacebar>"]

  // communicator settings
  communicator   = "winrm"
  winrm_username = var.username
  winrm_password = var.password
  winrm_port     = 5985
  winrm_timeout  = "60m"
  winrm_insecure = true
  winrm_use_ssl  = false
  winrm_use_ntlm = false
}
