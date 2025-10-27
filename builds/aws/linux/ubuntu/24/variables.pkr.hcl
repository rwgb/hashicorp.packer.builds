// AWS Ubuntu 24.04 LTS (Noble Numbat) Variables

// AWS Configuration
variable "aws_region" {
  type        = string
  description = "AWS region where the AMI will be created"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use for authentication"
  default     = "default"
}

// Source AMI Configuration
variable "source_ami_owner" {
  type        = string
  description = "AWS account ID that owns the source AMI"
  default     = "099720109477" // Canonical (Ubuntu official)
}

variable "source_ami_name_filter" {
  type        = string
  description = "Name filter for source AMI search"
  default     = "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"
}

// Instance Configuration
variable "instance_type" {
  type        = string
  description = "EC2 instance type for building"
  default     = "t3.small"
}

variable "ssh_username" {
  type        = string
  description = "SSH username for connecting to instance"
  default     = "ubuntu"
}

variable "subnet_id" {
  type        = string
  description = "VPC subnet ID (optional)"
  default     = ""
}

variable "security_group_id" {
  type        = string
  description = "Security group ID (optional)"
  default     = ""
}

// AMI Configuration
variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the resulting AMI name"
  default     = "ubuntu-24.04-custom"
}

variable "ami_description" {
  type        = string
  description = "Description for the resulting AMI"
  default     = "Ubuntu 24.04 LTS (Noble Numbat) custom AMI"
}

variable "ami_regions" {
  type        = list(string)
  description = "Regions to copy the AMI to"
  default     = []
}

variable "ami_users" {
  type        = list(string)
  description = "AWS account IDs to share the AMI with"
  default     = []
}

variable "ami_groups" {
  type        = list(string)
  description = "Groups to share the AMI with"
  default     = []
}

// Build Configuration
variable "encrypt_boot" {
  type        = bool
  description = "Encrypt the AMI"
  default     = false
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for AMI encryption"
  default     = ""
}

variable "volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 8
}

variable "volume_type" {
  type        = string
  description = "Root volume type"
  default     = "gp3"
}

// Tags
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default = {
    OS          = "Ubuntu"
    Version     = "24.04"
    Codename    = "Noble Numbat"
    Builder     = "Packer"
    BuildDate   = ""
  }
}

// Additional packages
variable "additional_packages" {
  type        = list(string)
  description = "Additional packages to install"
  default = [
    "curl",
    "wget",
    "vim",
    "git",
    "htop",
    "build-essential"
  ]
}
