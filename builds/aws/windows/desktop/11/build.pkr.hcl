packer {
  required_version = ">= 1.9.0"
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
    git = {
      version = ">= 0.3.2"
      source  = "github.com/ethanmdavidson/git"
    }
    windows-update = {
      version = ">= 0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

build {
  name    = "windows-11-desktop"
  sources = ["source.amazon-ebs.windows_11_desktop"]

  # Wait for cloud-init / system to be ready
  provisioner "powershell" {
    inline = [
      "Write-Host 'Waiting for system to be ready...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  # Verify SSM Agent is installed (comes pre-installed on Windows AMIs)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Verifying SSM Agent installation...'",
      "Get-Service AmazonSSMAgent"
    ]
  }

  # Install CloudWatch Agent
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing CloudWatch Agent...'",
      "$ProgressPreference = 'SilentlyContinue'",
      "Invoke-WebRequest -Uri 'https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi' -OutFile 'C:\\amazon-cloudwatch-agent.msi'",
      "Start-Process msiexec.exe -Wait -ArgumentList '/i C:\\amazon-cloudwatch-agent.msi /qn'",
      "Remove-Item 'C:\\amazon-cloudwatch-agent.msi' -Force"
    ]
  }

  # Install Chocolatey
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing Chocolatey...'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    ]
  }

  # Run Windows Update
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Insider*'",
      "include:$true"
    ]
    update_limit = 25
  }

  # Cleanup tasks
  provisioner "powershell" {
    inline = [
      "Write-Host 'Performing cleanup...'",
      "# Remove temporary files",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path 'C:\\Users\\*\\AppData\\Local\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "# Clear Windows Update cache",
      "Stop-Service -Name wuauserv -Force",
      "Remove-Item -Path 'C:\\Windows\\SoftwareDistribution\\Download\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Start-Service -Name wuauserv",
      "# Clear event logs",
      "wevtutil el | Foreach-Object {wevtutil cl $_}",
      "# Defragment the drive",
      "Optimize-Volume -DriveLetter C -Defrag -Verbose"
    ]
  }

  # Sysprep
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running Sysprep...'",
      "& C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\InitializeInstance.ps1 -Schedule",
      "& C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\SysprepInstance.ps1 -NoShutdown"
    ]
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "${path.root}/manifests/${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}.json"
    strip_path = true
    custom_data = {
      source_ami_name = "${build.SourceAMIName}"
      git_commit      = "${data.git-commit.cwd-head.hash}"
      build_time      = "${timestamp()}"
    }
  }
}
