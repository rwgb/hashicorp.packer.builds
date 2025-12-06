// proxmox-iso source for Windows Server 2019 Domain Controller
source "proxmox-iso" "windows_server_2k19_domain_controller" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     # api token id
  token       = var.token_secret # api token secret

  // proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  task_timeout             = "60m"

  // virtual machine settings
  vm_id                = 9012
  vm_name              = "win-server-2019-dc"
  memory               = 8192
  cores                = 2
  sockets              = 2
  qemu_agent           = true
  disable_kvm          = true
  scsi_controller      = "virtio-scsi-single"
  tags                 = "windows;server-2019;domain-controller;template"
  template_description = "Windows Server 2019 Domain Controller Template\nBuilt with Packer\nConfigured with Ansible"

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
    iso_checksum = "sha256:930d902d3880ba6462acc6f54ccabd2bf3f39f1c4514f08a02b3714f8ecf166e"
    unmount      = true
  }

  // cd files
  additional_iso_files {
    type             = "sata"
    cd_label         = "2k19_drivers"
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
        inst_os_language  = "en-US"
        inst_os_keyboard  = "en-US"
        inst_os_image     = "Windows Server 2019 SERVERDATACENTER"
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
    disk_size    = "40G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
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
  winrm_timeout  = "120m"
  winrm_insecure = true
  winrm_use_ssl  = false
  winrm_use_ntlm = false
}
