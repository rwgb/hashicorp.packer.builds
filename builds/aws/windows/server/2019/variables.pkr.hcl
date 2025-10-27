// AWS Windows Server 2019 Variables

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
  default     = "801119661308" // Amazon Windows AMIs
}

variable "source_ami_name_filter" {
  type        = string
  description = "Name filter for source AMI search"
  default     = "Windows_Server-2019-English-Full-Base-*"
}

// Instance Configuration
variable "instance_type" {
  type        = string
  description = "EC2 instance type for building"
  default     = "t3.large"
}

variable "communicator" {
  type        = string
  description = "Communicator type (winrm or ssh)"
  default     = "winrm"
}

variable "winrm_username" {
  type        = string
  description = "WinRM username"
  default     = "Administrator"
}

variable "winrm_insecure" {
  type        = bool
  description = "Skip WinRM certificate validation"
  default     = true
}

variable "winrm_use_ssl" {
  type        = bool
  description = "Use SSL for WinRM"
  default     = true
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
  default     = "windows-server-2019-custom"
}

variable "ami_description" {
  type        = string
  description = "Description for the resulting AMI"
  default     = "Windows Server 2019 Datacenter custom AMI"
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
  default     = 30
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
    OS          = "Windows Server"
    Version     = "2019"
    Edition     = "Datacenter"
    Builder     = "Packer"
    BuildDate   = ""
  }
}

// User data for EC2Config/EC2Launch
variable "user_data_file" {
  type        = string
  description = "Path to user data file"
  default     = ""
}
