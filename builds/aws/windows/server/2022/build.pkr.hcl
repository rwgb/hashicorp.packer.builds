// Packer build file for AWS Windows Server 2022

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
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
  name = "windows_server_2022_aws"

  sources = [
    "source.amazon-ebs.windows_server_2022_base"
  ]

  // Wait for Windows to be ready
  provisioner "powershell" {
    inline = [
      "Write-Host 'Waiting for Windows to be ready...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  // Install AWS Systems Manager (SSM) Agent
  provisioner "powershell" {
    inline = [
      "Write-Host 'Checking AWS SSM Agent...'",
      "$service = Get-Service -Name 'AmazonSSMAgent' -ErrorAction SilentlyContinue",
      "if ($service) {",
      "  Write-Host 'SSM Agent already installed'",
      "  Restart-Service -Name 'AmazonSSMAgent'",
      "} else {",
      "  Write-Host 'SSM Agent not found (should be pre-installed on Windows AMIs)'",
      "}"
    ]
  }

  // Install AWS CloudWatch Agent
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing AWS CloudWatch Agent...'",
      "$url = 'https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi'",
      "$output = 'C:\\Temp\\amazon-cloudwatch-agent.msi'",
      "New-Item -ItemType Directory -Force -Path C:\\Temp",
      "Invoke-WebRequest -Uri $url -OutFile $output",
      "Start-Process msiexec.exe -Wait -ArgumentList '/i', $output, '/qn', '/norestart'",
      "Remove-Item $output -Force"
    ]
  }

  // Install Chocolatey (optional package manager)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing Chocolatey...'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    ]
  }

  // Run Windows Update
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true"
    ]
    update_limit = 25
  }

  // Cleanup
  provisioner "powershell" {
    inline = [
      "Write-Host 'Performing cleanup...'",
      
      "# Clear Windows Update cache",
      "Stop-Service -Name wuauserv -Force",
      "Remove-Item C:\\Windows\\SoftwareDistribution\\Download\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Start-Service -Name wuauserv",
      
      "# Clear temp files",
      "Remove-Item C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item C:\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue",
      
      "# Clear event logs",
      "wevtutil el | Foreach-Object {wevtutil cl $_}",
      
      "Write-Host 'Cleanup complete'"
    ]
  }

  // Sysprep (prepare for AMI creation)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running EC2Launch Sysprep...'",
      "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\InitializeInstance.ps1 -Schedule",
      "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\SysprepInstance.ps1 -NoShutdown"
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
