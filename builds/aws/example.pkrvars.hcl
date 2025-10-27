# Example Packer Variables File for AWS Builds
# 
# This file demonstrates how to customize AWS builds by overriding default variables.
# 
# Usage:
#   packer build -var-file="example.pkrvars.hcl" .
#   python3 ../../scripts/buildManager.py --os debian-11-aws --var-file example.pkrvars.hcl

# ==============================================================================
# AWS Region Configuration
# ==============================================================================

# Primary AWS region for building AMIs
aws_region = "us-west-2"

# Additional regions to copy the AMI to after build
ami_regions = [
  "us-east-1",
  "us-east-2",
  "eu-west-1"
]

# ==============================================================================
# Instance Configuration
# ==============================================================================

# Instance type for the build process
# Larger instances speed up builds but cost more
instance_type = "t3.xlarge"  # Default is t3.medium for Linux, t3.large for Windows

# ==============================================================================
# Network Configuration
# ==============================================================================

# Specify VPC and subnet if you need builds in a specific network
# Leave blank to use default VPC
vpc_id        = "vpc-0123456789abcdef0"
subnet_id     = "subnet-0123456789abcdef0"
security_group_id = "sg-0123456789abcdef0"

# ==============================================================================
# Storage Configuration
# ==============================================================================

# Root volume size in GB
volume_size = 50  # Default is 20GB for Linux, 30GB for Windows

# Volume type: gp2, gp3, io1, io2
volume_type = "gp3"

# ==============================================================================
# Encryption Configuration
# ==============================================================================

# Enable EBS encryption (recommended for production)
encrypt_boot = true

# Optional: Specify a custom KMS key for encryption
# Leave blank to use the default AWS-managed key
kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"

# ==============================================================================
# AMI Sharing Configuration
# ==============================================================================

# Share the AMI with other AWS accounts
ami_users = [
  "123456789012",  # Production account
  "234567890123"   # Development account
]

# ==============================================================================
# AMI Naming and Description
# ==============================================================================

# Customize AMI name prefix
ami_name_prefix = "company-debian-11-hardened"

# AMI description
ami_description = "Debian 11 - Hardened with CIS benchmarks - Built with Packer"

# ==============================================================================
# Tags
# ==============================================================================

# Tags applied to the final AMI and snapshots
tags = {
  OS           = "Debian 11"
  OS_Version   = "Bullseye"
  Architecture = "x86_64"
  BuildTool    = "Packer"
  Environment  = "Production"
  CostCenter   = "Engineering"
  Compliance   = "CIS-Level-1"
  ManagedBy    = "Infrastructure-Team"
  CreatedBy    = "packer-automation"
}

# Tags applied to the temporary build instance
run_tags = {
  Name        = "Packer Builder - Debian 11 Production"
  BuildTool   = "Packer"
  Temporary   = "true"
  AutoDelete  = "true"
}

# ==============================================================================
# Build Timeouts (Windows builds typically need longer timeouts)
# ==============================================================================

# WinRM timeout for Windows builds
winrm_timeout = "45m"  # Default is 30m

# Overall communicator timeout
communicator_timeout = "20m"  # Default is 15m

# ==============================================================================
# Source AMI Customization
# ==============================================================================

# Override the source AMI filter to use a specific version
# Useful for ensuring consistent base images
source_ami_name_filter = "debian-11-amd64-20241001-*"

# Override AMI owner (use with caution)
# source_ami_owner = "136693071363"  # Debian official

# ==============================================================================
# Example: Minimal Configuration
# ==============================================================================
# 
# If you only need to change the region and enable encryption:
# 
# aws_region   = "us-east-1"
# encrypt_boot = true
#

# ==============================================================================
# Example: Multi-Region Production Build
# ==============================================================================
#
# aws_region   = "us-west-2"
# instance_type = "t3.xlarge"
# encrypt_boot = true
# kms_key_id   = "arn:aws:kms:us-west-2:123456789012:key/prod-key"
# 
# ami_regions = [
#   "us-east-1",
#   "us-west-1",
#   "eu-west-1",
#   "ap-southeast-1"
# ]
# 
# ami_users = ["123456789012"]  # Share with production account
# 
# tags = {
#   Environment = "Production"
#   Compliance  = "SOC2"
#   CostCenter  = "Engineering"
# }
#

# ==============================================================================
# Example: Development Build (Faster, Cheaper)
# ==============================================================================
#
# aws_region    = "us-east-1"
# instance_type = "t3.medium"
# volume_size   = 20
# encrypt_boot  = false
# 
# tags = {
#   Environment = "Development"
#   AutoDelete  = "7-days"
# }
#
