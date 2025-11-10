// Source definition for Debian 12 Configured build (clone-based)
source "proxmox-clone" "configured" {
  // Proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id
  token       = var.token_secret

  // Proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls

  // Clone settings
  clone_vm                 = var.clone_template
  full_clone               = true
  
  // Virtual machine settings
  vm_name              = "debian-12-${var.ansible_host_type}"
  vm_id                = var.vm_id_configured
  memory               = 2048
  cores                = 2
  sockets              = 1
  qemu_agent           = true
  task_timeout         = "20m"
  template_description = "Debian 12 Configured Template (${var.ansible_host_type})\nBuild Version: ${local.build_version}\nBuild Date: ${local.build_date}\nBuilt By: ${local.build_by}\nCloned from: ${var.clone_template}\nAnsible Role: ${var.ansible_host_type}"
  tags                 = "linux;debian;12;configured;${var.ansible_host_type};template;packer"

  // Network settings
  network_adapters {
    bridge   = var.network_bridge
    firewall = false
    model    = "virtio"
  }

  // Communicator settings
  communicator         = "ssh"
  ssh_username         = var.username
  ssh_password         = var.password
  ssh_private_key_file = data.sshkey.install.private_key_path
  ssh_timeout          = "20m"
}
