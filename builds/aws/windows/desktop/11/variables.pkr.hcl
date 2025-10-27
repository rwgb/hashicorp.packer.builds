# AWS Region Configuration
variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI"
  default     = "us-east-1"
}

# Instance Configuration
variable "instance_type" {
  type        = string
  description = "EC2 instance type for building the AMI"
  default     = "t3.large"
}

# Source AMI Configuration
variable "source_ami_owner" {
  type        = string
  description = "AWS account ID that owns the source AMI"
  default     = "801119661308" # Amazon
}

variable "source_ami_name_filter" {
  type        = string
  description = "Filter for finding the source AMI"
  default     = "Windows_11-English-Full-Base-*"
}

# Network Configuration
variable "subnet_id" {
  type        = string
  description = "Subnet ID for the build instance"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the build instance"
  default     = ""
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for the build instance"
  default     = ""
}

# Storage Configuration
variable "volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 30
}

variable "volume_type" {
  type        = string
  description = "Root volume type"
  default     = "gp3"
}

# AMI Configuration
variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the AMI name"
  default     = "windows-11-desktop"
}

variable "ami_description" {
  type        = string
  description = "Description for the AMI"
  default     = "Windows 11 Desktop - Built with Packer"
}

# Encryption Configuration
variable "encrypt_boot" {
  type        = bool
  description = "Enable EBS encryption for the boot volume"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for EBS encryption (blank for default key)"
  default     = ""
}

# AMI Sharing Configuration
variable "ami_users" {
  type        = list(string)
  description = "List of AWS account IDs to share the AMI with"
  default     = []
}

variable "ami_regions" {
  type        = list(string)
  description = "List of regions to copy the AMI to"
  default     = []
}

# WinRM Configuration
variable "winrm_username" {
  type        = string
  description = "WinRM username"
  default     = "Administrator"
}

variable "winrm_timeout" {
  type        = string
  description = "WinRM timeout duration"
  default     = "30m"
}

# Build Configuration
variable "communicator_timeout" {
  type        = string
  description = "Timeout for establishing communicator connection"
  default     = "15m"
}

# Tags
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default = {
    OS           = "Windows 11"
    OS_Version   = "Desktop"
    Architecture = "x86_64"
    BuildTool    = "Packer"
  }
}

variable "run_tags" {
  type        = map(string)
  description = "Tags to apply to the build instance"
  default = {
    Name      = "Packer Builder - Windows 11 Desktop"
    BuildTool = "Packer"
  }
}
