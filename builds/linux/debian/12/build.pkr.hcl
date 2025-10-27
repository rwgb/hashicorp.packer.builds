// Packer build file debian linux 12
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
  }
}

locals {
  instance_uuid   = uuidv4()
  short_id        = substr(replace(local.instance_uuid, "-", ""), 0, 8)
  bcrypt_password = bcrypt(var.password)
  source_content = {
    "/ks.cfg" = templatefile("${abspath(path.root)}/data/ks.pkrtpl.hcl", {
      username            = var.username
      password            = var.password
      password_encrypted  = local.bcrypt_password
      build_key           = data.sshkey.install.private_key_path
      guest_os_language   = var.guest_os_language
      guest_os_keyboard   = var.guest_os_keyboard
      guest_os_timezone   = var.guest_os_timezone
      additional_packages = join(" ", var.additional_packages)
    })
  }
}

data "git-commit" "build" {
  path = "${path.root}/../../../"
}

data "sshkey" "install" {}

locals {
  build_by   = "Built by: Hashicorp Packer ${packer.version}"
  build_date = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_key  = coalesce(var.build_key, data.sshkey.install.private_key_path)
  # Fallback to environment variable if git-commit fails
  ssh_public_key    = data.sshkey.install.public_key
  build_version     = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author        = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer     = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  git_timestamp     = try(data.git-commit.build.timestamp, timestamp(), "unknown")
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  manifest_path     = "./manifests/"
  manifest_date     = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_output   = "${local.manifest_path}${local.manifest_date}.json"
  
  # VM notes with build metadata
  vm_notes = <<-EOT
  Debian 12 Base Template
  
  Build Information:
  - Build Date: ${local.build_date}
  - Build Version: ${local.build_version}
  - Git Committer: ${local.git_committer}
  - Git Author: ${local.git_author}
  - Commit Timestamp: ${local.git_timestamp}
  
  Built with Packer ${packer.version}
  EOT
}

// Build block
build {
  name = "debian_linux_12"

  sources = ["source.proxmox-iso.debian_12_base"]

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_username = var.username
      build_date     = local.build_date
      build_version  = local.build_version
      author         = "${data.git-commit.build.author}"
      committer      = "${data.git-commit.build.committer}"
      timestamp      = "${data.git-commit.build.timestamp}"
    }
  }
}