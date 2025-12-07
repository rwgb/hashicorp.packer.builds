// Packer variables for Windows Server 2019 DHCP/DNS Server

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

// DNS variables
variable "dns_zone" {
  type        = string
  description = "DNS zone name"
  default     = "lab.local"
}

// DHCP variables
variable "dhcp_scope_name" {
  type        = string
  description = "DHCP scope name"
  default     = "Lab Network"
}

variable "dhcp_scope_start" {
  type        = string
  description = "DHCP scope start IP"
  default     = "192.168.1.100"
}

variable "dhcp_scope_end" {
  type        = string
  description = "DHCP scope end IP"
  default     = "192.168.1.200"
}

variable "dhcp_subnet" {
  type        = string
  description = "DHCP subnet mask"
  default     = "255.255.255.0"
}

variable "dhcp_gateway" {
  type        = string
  description = "DHCP default gateway"
  default     = "192.168.1.1"
}
