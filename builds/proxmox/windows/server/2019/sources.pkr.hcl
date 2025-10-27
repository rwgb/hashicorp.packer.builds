// proxmox-iso sources
source "proxmox-iso" "windows_server_2k19_data_center_base" {
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
  vm_name         = "ws2k19dcbase"
  memory          = 4096
  cores           = 2
  sockets         = 2
  qemu_agent      = true
  scsi_controller = "virtio-scsi-single"
  tags            = "windows;server;2019;data_center;template;base"

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/en_windows_server_2019_updated_aug_2019_x64_dvd_cdf24600.iso"
    iso_checksum = "sha256:930d902d3880ba6462acc6f54ccabd2bf3f39f1c4514f08a02b3714f8ecf166e"
    unmount      = true
  }

  // cd files
  additional_iso_files {
    type             = "sata"
    cd_label         = "2k19_drivers"
    iso_storage_pool = "packer_iso"
    cd_files = [
      "${path.cwd}/drivers",
      "../../scripts"
    ]
    cd_content = {
      "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
        is_efi            = false
        username          = var.username
        password          = var.password
        inst_os_language  = "en-US"
        inst_os_keyboard  = "en-US"
        inst_os_image     = "Windows Server 2019 SERVERDATACENTER"
        kms_key           = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"
        guest_os_language = "en-US"
        guest_os_keyboard = "en-US"
        guest_os_timezone = "CST"
      })
    }
  }

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = "local-lvm"
    disk_size    = "32G"
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
  boot_wait    = "5s"
  boot_command = ["<spacebar><spacebar>"]

  // communicator settings
  communicator   = "winrm"
  winrm_username = var.username
  winrm_password = var.password
  winrm_port     = 5985
  winrm_timeout  = "10m"
  winrm_insecure = true
  winrm_use_ssl  = false
  winrm_use_ntlm = false
}

// proxmox-clone sources
source "proxmox-clone" "windows_server_2k19_data_center_base" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     # api token id
  token       = var.token_secret # api token secret

  // proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls

  // virtual machine settings
  clone_vm_id     = 100
  vm_name         = "ws2k19dc.clone"
  memory          = 4096
  cores           = 2
  sockets         = 2
  qemu_agent      = true
  scsi_controller = "virtio-scsi-single"
  task_timeout    = "20m"
  tags            = "windows;server;2019;data_center;clone;base"

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = "local-lvm"
    disk_size    = "32G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
    model    = "e1000"
    firewall = false
  }

  // cd files
  additional_iso_files {
    type             = "sata"
    cd_label         = "autounattend"
    iso_storage_pool = "packer_iso"
    cd_content = {
      "autounattend.xml" = templatefile("${abspath(path.root)}/data/autounattend.pkrtpl.hcl", {
        is_efi            = false
        username          = var.username
        password          = var.password
        inst_os_language  = "en-US"
        inst_os_keyboard  = "en-US"
        inst_os_image     = "Windows Server 2019 SERVERDATACENTER"
        kms_key           = "WMDGN-G9PQG-XVVXX-R3X43–63DFG"
        guest_os_language = "en-US"
        guest_os_keyboard = "en-US"
        guest_os_timezone = "CST"
      })
    }
  }

  // cloud init settings
  cloud_init              = true
  cloud_init_storage_pool = "cidata"

  // boot settings
  boot_wait    = "5s"
  boot_command = ["<spacebar><spacebar>"]

  // communicator settings
  communicator   = "winrm"
  winrm_username = var.username
  winrm_password = var.password
  winrm_port     = 5985
}