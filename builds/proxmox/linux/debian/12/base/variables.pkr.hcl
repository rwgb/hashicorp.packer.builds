// Variable definitions for Debian 12 Base build

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

// VM ID variables
variable "vm_id_base" {
  type        = number
  description = "The VM ID for the base template (ensures consistency)"
  default     = 9000
}

// ISO configuration
variable "iso_file" {
  type        = string
  description = "The ISO file path in Proxmox storage (e.g., local:iso/debian-12.iso)"
  default     = "local:iso/debian-12.iso"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the ISO file"
  default     = "sha256:9da6ae5b63a72161d0fd4480d0f090b250c4f6bf421474e4776e82eea5cb3143bf8936bf43244e438e74d581797fe87c7193bbefff19414e33932fe787b1400f"
}

// Storage configuration
variable "storage_pool" {
  type        = string
  description = "The storage pool for VM disks"
  default     = "local-lvm"
}

variable "cloud_init_storage_pool" {
  type        = string
  description = "The storage pool for cloud-init drive"
  default     = "local-lvm"
}

variable "disk_size_base" {
  type        = string
  description = "Disk size for base template"
  default     = "10G"
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

variable "guest_os_language" {
  type        = string
  description = "The operating system language that should be installed"
  default     = "en_US"
}

variable "guest_os_keyboard" {
  type        = string
  description = "The keyboard language that should be installed"
  default     = "us"
}

variable "guest_os_timezone" {
  type        = string
  description = "The timezone that the virtual machine should be set with"
  default     = "UTC"
}

variable "additional_packages" {
  type        = list(string)
  description = "A list of additional packages to install in the base template"
  default     = ["qemu-guest-agent", "cloud-init"]
}
