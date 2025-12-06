// Packer variables for Windows Server 2019 Domain Controller

// Proxmox connection variables
variable "proxmox_host" {
  type        = string
  description = "Proxmox host address"
}

variable "token_id" {
  type        = string
  description = "Proxmox API token ID"
  sensitive   = true
}

variable "token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "node" {
  type        = string
  description = "Proxmox node name"
}

variable "pool" {
  type        = string
  description = "Proxmox resource pool"
  default     = ""
}

variable "insecure_tls" {
  type        = bool
  description = "Skip TLS verification"
  default     = true
}

// Storage variables
variable "iso_storage_pool" {
  type        = string
  description = "The Proxmox storage pool where ISO files are stored"
  default     = "local"
}

variable "disk_storage_pool" {
  type        = string
  description = "Storage pool for VM disks"
  default     = "local-lvm"
}

// VM credentials
variable "username" {
  type        = string
  description = "Administrator username"
  default     = "Administrator"
}

variable "password" {
  type        = string
  description = "Administrator password"
  sensitive   = true
}

variable "guest_os_language" {
  type        = string
  description = "The operating system language"
  default     = "en-US"
}

variable "guest_os_keyboard" {
  type        = string
  description = "The keyboard language"
  default     = "en-US"
}

variable "guest_os_timezone" {
  type        = string
  description = "The timezone"
  default     = "UTC"
}

// Domain variables
variable "domain_name" {
  type        = string
  description = "Active Directory domain name"
  default     = "lab.local"
}

variable "domain_netbios_name" {
  type        = string
  description = "NetBIOS domain name"
  default     = "LAB"
}

variable "safe_mode_password" {
  type        = string
  description = "Directory Services Restore Mode password"
  sensitive   = true
}
