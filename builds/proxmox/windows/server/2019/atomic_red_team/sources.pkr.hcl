// proxmox-clone source for Atomic Red Team Windows Server 2019 build
source "proxmox-clone" "windows_server_2k19_atomic_red_team" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     # api token id
  token       = var.token_secret # api token secret

  // proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls

  // virtual machine setting
  clone_vm_id          = 9000
  vm_id                = 9014
  vm_name              = "win-server-2019-atomic-red-team"
  memory               = 8192
  cores                = 4
  sockets              = 1
  qemu_agent           = true
  disable_kvm          = true
  scsi_controller      = "virtio-scsi-single"
  task_timeout         = "20m"
  tags                 = "windows;server-2019;atomic-red-team;security;template"
  template_description = "Windows Server 2019 Datacenter with Atomic Red Team\nBuild Version: ${local.build_version}\nBuilt on: ${local.build_date}\nAuthor: ${local.git_author}\nCommitter: ${local.git_committer}\nCommit Timestamp: ${local.git_timestamp}\n${local.build_by}"

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = var.disk_storage_pool
    disk_size    = "64G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
    model    = "e1000"
    firewall = false
  }

  // communicator settings
  communicator   = "winrm"
  winrm_username = var.username
  winrm_password = var.password
  winrm_port     = 5985
  winrm_timeout  = "120m"
  winrm_insecure = true
  winrm_use_ssl  = false
}
