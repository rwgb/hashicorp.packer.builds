// Individual build for minimal MySQL database server
build {
  name = "debian_12_minimal_mysql_only"
  
  sources = ["source.proxmox-clone.debian_12_minimal_mysql"]
  
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "sudo apt-get update",
      "sudo apt-get install -y ansible"
    ]
  }
  
  provisioner "ansible-local" {
    playbook_file = "${path.root}/../../../../ansible/minimal-mysql.yml"
  }
  
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*"
    ]
  }
  
  post-processor "manifest" {
    output = "./manifests/debian-12-minimal-mysql-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}.json"
    strip_path = true
    strip_time = true
  }
}
