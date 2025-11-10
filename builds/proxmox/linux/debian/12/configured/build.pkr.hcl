// Packer build file for Debian 12 Configured Template
// This build clones the base template and applies Ansible provisioning

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
    sshkey = {
      version = ">= 1.0.1"
      source  = "github.com/ivoronin/sshkey"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.4.3"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

data "git-commit" "build" {
  path = "${path.root}/../../../../../"
}

data "sshkey" "install" {}

locals {
  build_by          = "Built by: Hashicorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  ssh_public_key    = data.sshkey.install.public_key
  build_version     = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author        = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer     = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  git_timestamp     = try(data.git-commit.build.timestamp, timestamp(), "unknown")
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  manifest_path     = "./manifests/"
  manifest_date     = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
  manifest_output   = "${local.manifest_path}${local.manifest_date}.json"
}

// Build block for configured template
build {
  name = "debian_12_configured"

  sources = ["source.proxmox-clone.configured"]

  // Ansible provisioner for system configuration
  provisioner "ansible" {
    playbook_file = "${path.root}/../../../../ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars",
      "host_type=${var.ansible_host_type}",
      "--extra-vars",
      "ansible_user=${var.username}",
      "--extra-vars",
      "ansible_ssh_private_key_file=${data.sshkey.install.private_key_path}",
      "--connection=ssh",
      "--timeout=300",
      "--ssh-extra-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'",
      "-v"
    ]
    user                    = var.username
    use_proxy               = false
    ansible_env_vars        = ["ANSIBLE_HOST_KEY_CHECKING=False", "ANSIBLE_SSH_PIPELINING=True"]
    inventory_file_template = <<EOF
[packer]
default ansible_host={{ .Host }} ansible_port={{ .Port }} ansible_user={{ .User }} ansible_ssh_private_key_file={{ .SSHPrivateKeyFile }}
EOF
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_type        = "configured"
      build_username    = var.username
      build_date        = local.build_date
      build_version     = local.build_version
      author            = local.git_author
      committer         = local.git_committer
      timestamp         = local.git_timestamp
      template_name     = "debian-12-configured"
      ansible_host_type = var.ansible_host_type
      clone_template    = var.clone_template
    }
  }
}
