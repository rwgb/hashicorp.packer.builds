// AWS EBS Source for Ubuntu 24.04 (Noble Numbat)

source "amazon-ebs" "ubuntu_2404_base" {
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
  ssh_username  = var.ssh_username
  ssh_timeout   = "10m"

  // Network Configuration
  subnet_id         = var.subnet_id != "" ? var.subnet_id : null
  security_group_id = var.security_group_id != "" ? var.security_group_id : null

  // When not specifying subnet/security group, Packer creates temporary ones
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
    device_name           = "/dev/xvda"
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
    Name    = "Packer Builder - Ubuntu 24.04"
    Builder = "Packer"
  }
}
