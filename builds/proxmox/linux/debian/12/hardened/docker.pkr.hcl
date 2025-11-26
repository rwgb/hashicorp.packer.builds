// Individual build for hardened Docker host
build {
  name = "debian_12_hardened_docker_only"
  
  sources = ["source.proxmox-clone.debian_12_hardened_docker"]
  
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "sudo apt-get update",
      "sudo apt-get install -y ansible"
    ]
  }
  
  provisioner "ansible-local" {
    playbook_file = "${path.root}/../../ansible/hardened-docker.yml"
  }
  
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*"
    ]
  }
  
  post-processor "manifest" {
    output = "./manifests/debian-12-hardened-docker-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}.json"
    strip_path = true
    strip_time = true
  }
}
