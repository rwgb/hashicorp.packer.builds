// packer build file for Windows Server 2019 DHCP/DNS Server
packer {
  required_version = ">= 1.9.4"
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
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
  ansible_playbook  = "${path.root}/../../../../ansible/windows-dhcp-dns.yml"
}

// build block
build {
  name = "windows_server_2k19_dhcp_dns"
  sources = [
    "source.proxmox-clone.windows_server_2k19_dhcp_dns"
  ]

  // Configure WinRM for Ansible
  provisioner "powershell" {
    inline = [
      "Write-Host 'Configuring WinRM for Ansible...'",
      "Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true -Force",
      "Set-Item -Path WSMan:\\localhost\\Service\\AllowUnencrypted -Value $true -Force",
      "Restart-Service WinRM"
    ]
  }

  // Run Ansible playbook to configure DHCP/DNS Server
  provisioner "ansible" {
    playbook_file = local.ansible_playbook
    user          = var.username
    use_proxy     = true
    extra_arguments = [
      "--extra-vars",
      "ansible_user=${var.username} ansible_password=${var.password} ansible_connection=winrm ansible_winrm_server_cert_validation=ignore dns_zone=${var.dns_zone} dhcp_scope_name=${var.dhcp_scope_name} dhcp_scope_start=${var.dhcp_scope_start} dhcp_scope_end=${var.dhcp_scope_end} dhcp_subnet=${var.dhcp_subnet} dhcp_gateway=${var.dhcp_gateway}"
    ]
  }

  // Cleanup
  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up temporary files...'",
      "Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path C:\\Users\\${var.username}\\AppData\\Local\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue"
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_type     = "dhcp-dns"
      build_username = var.username
      build_date     = local.build_date
      build_version  = local.build_version
      author         = local.git_author
      committer      = local.git_committer
      timestamp      = local.git_timestamp
      dns_zone       = var.dns_zone
    }
  }
}
