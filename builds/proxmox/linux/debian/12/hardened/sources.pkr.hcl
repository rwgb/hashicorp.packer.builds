// Source configuration for hardened Apache web server
source "proxmox-clone" "debian_12_hardened_apache" {
  // Proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id
  token       = var.token_secret
  
  // Proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  
  // Clone settings
  clone_vm_id = var.clone_vm_id
  full_clone  = true
  
  // VM settings
  vm_id               = 9001
  vm_name             = "debian-12-hardened-apache"
  template_description = "Debian 12 Hardened Apache Web Server - Built by Packer"
  tags                = "linux;debian-12;hardened;apache"
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}

// Source configuration for hardened Docker host
source "proxmox-clone" "debian_12_hardened_docker" {
  // Proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id
  token       = var.token_secret
  
  // Proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  
  // Clone settings
  clone_vm_id = var.clone_vm_id
  full_clone  = true
  
  // VM settings
  vm_id               = 9002
  vm_name             = "debian-12-hardened-docker"
  template_description = "Debian 12 Hardened Docker Host - Built by Packer"
  tags                = "linux;debian-12;hardened;docker"
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}

// Source configuration for hardened MySQL server
source "proxmox-clone" "debian_12_hardened_mysql" {
  // Proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id
  token       = var.token_secret
  
  // Proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  
  // Clone settings
  clone_vm_id = var.clone_vm_id
  full_clone  = true
  
  // VM settings
  vm_id               = 9003
  vm_name             = "debian-12-hardened-mysql"
  template_description = "Debian 12 Hardened MySQL Database Server - Built by Packer"
  tags                = "linux;debian-12;hardened;mysql"
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}

// Source configuration for hardened Tomcat server
source "proxmox-clone" "debian_12_hardened_tomcat" {
  // Proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id
  token       = var.token_secret
  
  // Proxmox settings
  node                     = var.node
  pool                     = var.pool
  insecure_skip_tls_verify = var.insecure_tls
  
  // Clone settings
  clone_vm_id = var.clone_vm_id
  full_clone  = true
  
  // VM settings
  vm_id               = 9004
  vm_name             = "debian-12-hardened-tomcat"
  template_description = "Debian 12 Hardened Tomcat Application Server - Built by Packer"
  tags                = "linux;debian-12;hardened;tomcat"
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}
