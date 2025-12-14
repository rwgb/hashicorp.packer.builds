// packer build file for Windows 10 Minimal
packer {
  required_version = ">= 1.9.4"
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }

    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = ">= 0.14.3"
    }

    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.4.3"
    }
  }
}

data "git-commit" "build" {
  path = "${path.root}/../../../../"
}

locals {
  build_by          = "Built by: Hashicorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version     = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author        = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer     = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  git_timestamp     = try(data.git-commit.build.timestamp, timestamp(), "unknown")
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  manifest_path     = "./manifests/"
  manifest_date     = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
  manifest_output   = "${local.manifest_path}${local.manifest_date}.json"
}

// build block
build {
  name = "windows_10_22h2_minimal"
  sources = [
    "source.proxmox-clone.windows_10_22h2_minimal"
  ]

  // Copy ESET config file to the VM
  provisioner "file" {
    source      = "../../../scripts/install_config.ini"
    destination = "C:\\Windows\\Temp\\install_config.ini"
  }

  // Install ESET Protect Agent
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    scripts = [
      "../../../scripts/install-eset-agent.ps1"
    ]
  }

  provisioner "powershell" {
    environment_vars = [
      "BUILD_USER=${var.username}"
    ]
    elevated_user     = "Administrator"
    elevated_password = var.password
    scripts = [
      "../../../scripts/windows-prepare.ps1"
    ]
  }

  provisioner "windows-update" {
    pause_before    = "30s"
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*VMware*'",
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Defender*'",
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true"
    ]
    update_limit = 25
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_username = var.username
      build_date     = local.build_date
      build_version  = local.build_version
      build_type     = "minimal"
      author         = local.git_author
      committer      = local.git_committer
      timestamp      = local.git_timestamp
    }
  }
}
