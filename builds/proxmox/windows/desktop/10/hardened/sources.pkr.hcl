// proxmox-clone source for Windows 10 22H2 Hardened
source "proxmox-clone" "windows_10_22h2_hardened" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     # api token id
  token       = var.token_secret # api token secret

  // proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  task_timeout             = "30m"

  // virtual machine settings
  clone_vm_id          = 9021
  vm_id                = 9022
  vm_name              = "win-10-22h2-hardened"
  full_clone           = true
  memory               = 4096
  cores                = 2
  sockets              = 1
  qemu_agent           = true
  disable_kvm          = true
  scsi_controller      = "virtio-scsi-single"
  tags                 = "windows;desktop;windows-10;22h2;template;hardened;security"
  template_description = "Windows 10 22H2 Professional Hardened Template\nBuild Version: ${local.build_version}\nBuilt on: ${local.build_date}\nCIS Benchmarks Applied\nSecurity Hardening Configured\nAuthor: ${local.git_author}\nCommitter: ${local.git_committer}\nCommit Timestamp: ${local.git_timestamp}\n${local.build_by}"

  // communicator settings
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.password
  winrm_port     = 5985
  winrm_timeout  = "120m"
  winrm_insecure = true
  winrm_use_ssl  = false
  winrm_use_ntlm = false
  winrm_no_proxy = true
}
