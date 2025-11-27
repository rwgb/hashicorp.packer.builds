// Shared variables for Debian 12 minimal builds
variable "proxmox_host" {
  type        = string
  description = "IP address or resolvable hostname of the proxmox host"
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
  description = "The proxmox node on which to build the virtual machine"
}

variable "pool" {
  type        = string
  description = "The name of the resource pool in which to create the virtual machine"
}

variable "insecure_tls" {
  type        = bool
  description = "Whether or not HTTPS certificate of the proxmox server should be validated"
  default     = true
}

variable "username" {
  type        = string
  description = "The SSH username for connecting to the cloned VM"
  default     = "packer"
}

variable "password" {
  type        = string
  description = "The SSH password for connecting to the cloned VM"
  default     = "packer"
}

variable "clone_vm_id" {
  type        = number
  description = "The VM ID of the base template to clone from"
  default     = 9000
}
