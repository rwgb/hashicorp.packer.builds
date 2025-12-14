// Variable definitions for Windows 10 Minimal Build
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
  default     = ""
}

variable "insecure_tls" {
  type        = bool
  description = "Whether or not HTTPS certificate of the proxmox server should be validated"
  default     = true
}

variable "username" {
  type        = string
  description = "The build username to use for provisioning"
  default     = "packer"
}

variable "password" {
  type        = string
  description = "The password to use for the Administrator account"
  sensitive   = true
}
