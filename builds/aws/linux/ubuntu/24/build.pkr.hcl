// Packer build file for AWS Ubuntu 24.04 (Noble Numbat)

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.4.3"
    }
  }
}

// Data sources
data "git-commit" "build" {
  path = "${path.root}/../../../../"
}

// Local variables
locals {
  build_timestamp = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
  build_version   = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author      = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer   = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  build_by        = "Built by: Hashicorp Packer ${packer.version}"
  
  manifest_path   = "./manifests/"
  manifest_output = "${local.manifest_path}${local.build_timestamp}.json"
}

// Build block
build {
  name = "ubuntu_2404_aws"

  sources = [
    "source.amazon-ebs.ubuntu_2404_base"
  ]

  // Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "echo 'Cloud-init complete'"
    ]
  }

  // Update system
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y"
    ]
  }

  // Install additional packages
  provisioner "shell" {
    inline = [
      "echo 'Installing additional packages...'",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${join(" ", var.additional_packages)}"
    ]
  }

  // Install AWS Systems Manager (SSM) Agent
  provisioner "shell" {
    inline = [
      "echo 'Installing AWS SSM Agent...'",
      "sudo mkdir -p /tmp/ssm",
      "cd /tmp/ssm",
      "wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb",
      "sudo dpkg -i amazon-ssm-agent.deb",
      "sudo systemctl enable amazon-ssm-agent",
      "cd ~",
      "sudo rm -rf /tmp/ssm"
    ]
  }

  // Install AWS CloudWatch Agent
  provisioner "shell" {
    inline = [
      "echo 'Installing AWS CloudWatch Agent...'",
      "wget https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb",
      "sudo dpkg -i -E ./amazon-cloudwatch-agent.deb",
      "rm amazon-cloudwatch-agent.deb"
    ]
  }

  // Cleanup
  provisioner "shell" {
    inline = [
      "echo 'Performing cleanup...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      
      # Clear bash history
      "cat /dev/null > ~/.bash_history && history -c"
    ]
  }

  // Post-processor: Generate manifest
  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_timestamp = local.build_timestamp
      build_version   = local.build_version
      git_author      = local.git_author
      git_committer   = local.git_committer
      source_ami      = "{{ .SourceAMI }}"
      ami_id          = "{{ .ArtifactId }}"
    }
  }
}
