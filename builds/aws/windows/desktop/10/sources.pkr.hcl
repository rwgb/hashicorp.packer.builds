data "git-commit" "cwd-head" {
  path = "${path.root}/../../../../"
}

source "amazon-ebs" "windows_10_desktop" {
  # AWS Configuration
  region = var.aws_region

  # Source AMI
  source_ami_filter {
    filters = {
      name                = var.source_ami_name_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = [var.source_ami_owner]
    most_recent = true
  }

  # Instance Configuration
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_id        = var.vpc_id

  # Security
  security_group_id = var.security_group_id

  # Communicator Configuration
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_timeout  = var.winrm_timeout
  winrm_use_ssl  = true
  winrm_insecure = true

  # User data to enable WinRM
  user_data_file = "${path.root}/userdata.ps1"

  # AMI Configuration
  ami_name        = "${var.ami_name_prefix}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  ami_description = var.ami_description

  # Storage
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
    encrypted             = var.encrypt_boot
    kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null
  }

  # AMI Distribution
  ami_regions = var.ami_regions
  ami_users   = var.ami_users

  # Snapshot settings
  snapshot_tags = merge(
    var.tags,
    {
      Name = "${var.ami_name_prefix}-snapshot"
    }
  )

  # Tags
  tags     = var.tags
  run_tags = var.run_tags

  # Timeouts
  communicator_timeout = var.communicator_timeout
}
