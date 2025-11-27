// Packer build file for Debian 12 hardened variants
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

locals {
  build_date    = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  manifest_path = "./manifests/"
  manifest_date = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
}

// Build block for all hardened variants
build {
  name = "debian_12_hardened"

  sources = [
    "source.proxmox-clone.debian_12_hardened_apache",
    "source.proxmox-clone.debian_12_hardened_docker",
    "source.proxmox-clone.debian_12_hardened_mysql",
    "source.proxmox-clone.debian_12_hardened_tomcat"
  ]

  // Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'System ready for provisioning'"
    ]
  }

  // Install Ansible if not present
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y ansible python3-pip"
    ]
  }

  // Run Ansible playbook based on build source
  // Extract role name from source.name (e.g., "debian_12_hardened_apache" -> "apache")
  provisioner "ansible" {
    playbook_file = "${path.root}/../../../../ansible/hardened-${split("_", source.name)[3]}.yml"
    use_proxy     = false
    user          = var.username
  }

  // Cleanup
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*"
    ]
  }

  post-processor "manifest" {
    output     = "${local.manifest_path}${source.name}-${local.manifest_date}.json"
    strip_path = true
    strip_time = true
    custom_data = {
      build_date   = local.build_date
      source_vm_id = var.clone_vm_id
      variant      = "hardened"
      role         = source.name
    }
  }
}
