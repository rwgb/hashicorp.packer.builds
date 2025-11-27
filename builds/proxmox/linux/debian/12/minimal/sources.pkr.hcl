// Source configuration for minimal Apache web server
source "proxmox-clone" "debian_12_minimal_apache" {
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
  vm_id               = 9005
  vm_name             = "debian-12-minimal-apache"
  template_description = "Debian 12 Minimal Apache Web Server - Built by Packer"
  tags                = "linux;debian-12;minimal;apache"
  disable_kvm         = true
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}

// Source configuration for minimal Docker host
source "proxmox-clone" "debian_12_minimal_docker" {
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
  vm_id               = 9006
  vm_name             = "debian-12-minimal-docker"
  template_description = "Debian 12 Minimal Docker Host - Built by Packer"
  tags                = "linux;debian-12;minimal;docker"
  disable_kvm         = true
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}

// Source configuration for minimal MySQL server
source "proxmox-clone" "debian_12_minimal_mysql" {
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
  vm_id               = 9007
  vm_name             = "debian-12-minimal-mysql"
  template_description = "Debian 12 Minimal MySQL Database Server - Built by Packer"
  tags                = "linux;debian-12;minimal;mysql"
  disable_kvm         = true
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}

// Source configuration for minimal Tomcat server
source "proxmox-clone" "debian_12_minimal_tomcat" {
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
  vm_id               = 9008
  vm_name             = "debian-12-minimal-tomcat"
  template_description = "Debian 12 Minimal Tomcat Application Server - Built by Packer"
  tags                = "linux;debian-12;minimal;tomcat"
  disable_kvm         = true
  
  // SSH settings
  ssh_username = var.username
  ssh_password = var.password
  ssh_timeout  = "15m"
}
