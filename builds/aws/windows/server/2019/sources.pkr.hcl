// AWS EBS Source for Windows Server 2019

source "amazon-ebs" "windows_server_2019_base" {
  // AWS Configuration
  region  = var.aws_region
  profile = var.aws_profile

  // Source AMI
  source_ami_filter {
    filters = {
      name                = var.source_ami_name_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "x86_64"
    }
    owners      = [var.source_ami_owner]
    most_recent = true
  }

  // Instance Configuration
  instance_type = var.instance_type

  // WinRM Communicator Configuration
  communicator   = var.communicator
  winrm_username = var.winrm_username
  winrm_insecure = var.winrm_insecure
  winrm_use_ssl  = var.winrm_use_ssl
  winrm_timeout  = "30m"

  // User data to enable WinRM
  user_data_file = var.user_data_file != "" ? var.user_data_file : null
  
  // Default user data if none specified
  user_data = var.user_data_file == "" ? templatefile("${path.root}/userdata.ps1", {}) : null

  // Network Configuration
  subnet_id         = var.subnet_id != "" ? var.subnet_id : null
  security_group_id = var.security_group_id != "" ? var.security_group_id : null

  // Public IP for temporary instances
  associate_public_ip_address = var.subnet_id == "" ? true : null

  // AMI Configuration
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = var.ami_description

  // AMI Sharing
  ami_regions = var.ami_regions
  ami_users   = var.ami_users
  ami_groups  = var.ami_groups

  // Encryption
  encrypt_boot = var.encrypt_boot
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  // Storage Configuration
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
  }

  // Tags
  tags = merge(
    var.tags,
    {
      Name      = "${var.ami_name_prefix}-{{timestamp}}"
      BuildDate = "{{timestamp}}"
    }
  )

  run_tags = {
    Name    = "Packer Builder - Windows Server 2019"
    Builder = "Packer"
  }
}
