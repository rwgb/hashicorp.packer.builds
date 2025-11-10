// Variable definitions for Debian 12 Configured builds

// Proxmox connection variables
variable "proxmox_host" {
  type        = string
  description = "IP address or resolvable hostname of the Proxmox host"
}

variable "token_id" {
  type        = string
  description = "API Token ID in $username@pve!$token_id format"
}

variable "token_secret" {
  type        = string
  description = "The API token secret"
  sensitive   = true
}

variable "node" {
  type        = string
  description = "The Proxmox node on which to build the virtual machine"
}

variable "pool" {
  type        = string
  description = "The name of the resource pool in which to create the virtual machine"
  default     = ""
}

variable "insecure_tls" {
  type        = bool
  description = "Whether or not HTTPS certificate of the Proxmox server should be validated"
  default     = true
}

// Clone configuration
variable "clone_template" {
  type        = string
  description = "The name of the template to clone from (usually debian-12-base)"
  default     = "debian-12-base"
}

variable "vm_id_configured" {
  type        = number
  description = "The VM ID for the configured template"
  default     = null
}

// Network configuration
variable "network_bridge" {
  type        = string
  description = "The network bridge to use"
  default     = "vmbr0"
}

// Guest OS configuration
variable "username" {
  type        = string
  description = "The build username to use for SSH connections"
  default     = "packer"
}

variable "password" {
  type        = string
  description = "The password to use for the build user"
  default     = "packer"
  sensitive   = true
}

// Ansible configuration
variable "ansible_host_type" {
  type        = string
  description = "The Ansible host type to provision (e.g., base, docker, database, webserver)"
  default     = "base"
}
