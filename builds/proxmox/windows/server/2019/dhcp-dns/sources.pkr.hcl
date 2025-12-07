// proxmox-clone source for Windows Server 2019 DHCP/DNS Server
source "proxmox-clone" "windows_server_2k19_dhcp_dns" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     # api token id
  token       = var.token_secret # api token secret

  // proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls

  // virtual machine settings
  clone_vm_id     = 9010
  vm_id           = 9013
  vm_name         = "win-server-2019-dhcp-dns"
  memory          = 4096
  cores           = 2
  sockets         = 2
  qemu_agent      = true
  disable_kvm     = true
  scsi_controller = "virtio-scsi-single"
  task_timeout    = "30m"
  tags            = "windows;server-2019;dhcp;dns;template"
  template_description = "Windows Server 2019 DHCP/DNS Server Template\nBuilt with Packer\nConfigured with Ansible"

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = var.disk_storage_pool
    disk_size    = "40G"
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
