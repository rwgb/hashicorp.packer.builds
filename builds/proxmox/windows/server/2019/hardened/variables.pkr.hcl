// Packer variables for Windows Server 2019 Hardened

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
