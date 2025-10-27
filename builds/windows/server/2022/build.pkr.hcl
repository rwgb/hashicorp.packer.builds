// packer build file
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
  path = "${path.root}/../../"
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
  name = "windows_server_2k22"
  sources = [
    //"source.proxmox-clone.windows_server_2k22_data_center_base",
    "source.proxmox-iso.windows_server_2k22_data_center_base",
  ]
  // redundant scripts. keeping provisioner for future builds
  /*
  provisioner "powershell" {
    environment_vars = [
      "BUILD_USER=${var.username}"
    ]
    elevated_user     = var.username
    elevated_password = var.password
    scripts = [
      "../../scripts/windows-init.ps1",
      "../../scripts/windows-prepare.ps1"
    ]
  }
  */
  // commenting out for base build.
  /*
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
  }
*/
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