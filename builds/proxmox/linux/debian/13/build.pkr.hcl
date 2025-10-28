// Packer build file debian linux 13
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
  path = "${path.root}/../../../../"
}

data "sshkey" "install" {}

locals {
  build_by   = "Built by: Hashicorp Packer ${packer.version}"
  build_date = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  # Fallback to environment variable if git-commit fails
  ssh_public_key    = data.sshkey.install.private_key_path
  build_version     = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author        = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer     = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  git_timestamp     = try(data.git-commit.build.timestamp, timestamp(), "unknown")
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  manifest_path     = "./manifests/"
  manifest_date     = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
  manifest_output   = "${local.manifest_path}${local.manifest_date}.json"
  ansible_root      = "${path.root}/../../ansible"
}

// Build block
build {
  name = "debian_linux_13"

  sources = ["source.proxmox-iso.debian_13_base"]

  // Wait for system to be ready
  provisioner "shell" {
    inline = [
      "echo 'Waiting for system to be ready...'",
      "cloud-init status --wait || true",
      "sudo apt-get update",
      "echo 'System ready for provisioning'"
    ]
  }

  // Install Python and prerequisites for Ansible
  provisioner "shell" {
    inline = [
      "echo 'Installing Python and Ansible prerequisites...'",
      "sudo apt-get install -y python3 python3-pip python3-apt aptitude",
      "python3 --version"
    ]
  }

  // Configure as Docker host using Ansible
  provisioner "ansible" {
    playbook_file = "${local.ansible_root}/playbook.yml"
    
    extra_arguments = [
      "--extra-vars", "host_type=docker",
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "docker_users=['${var.username}']",
      "--extra-vars", "docker_install_compose=true",
      "--extra-vars", "common_timezone=${var.guest_os_timezone}",
      "--extra-vars", "security_enable_ufw=true",
      "--extra-vars", "security_enable_fail2ban=true",
      "--extra-vars", "monitoring_enable=true",
      "-v"
    ]
    
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_SSH_ARGS=-o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null",
      "ANSIBLE_STDOUT_CALLBACK=yaml"
    ]
    
    user = var.username
  }

  // Verify Docker installation
  provisioner "shell" {
    inline = [
      "echo '=== Docker Installation Verification ==='",
      "docker --version",
      "docker compose version",
      "sudo systemctl status docker --no-pager || true",
      "sudo docker info",
      "echo '=== Running test container ==='",
      "sudo docker run --rm hello-world",
      "echo '=== Docker installation successful! ==='"
    ]
  }

  // Clean up for template
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up for template...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "sudo rm -rf /var/log/ansible.log",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo cloud-init clean --logs || true",
      "history -c",
      "sudo sync"
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_username    = var.username
      build_date        = local.build_date
      build_version     = local.build_version
      author            = local.git_author
      committer         = local.git_committer
      timestamp         = local.git_timestamp
      template_type     = "docker-host"
      ansible_roles     = "common,security,docker,monitoring"
      docker_compose    = "true"
      security_hardened = "true"
    }
  }
}