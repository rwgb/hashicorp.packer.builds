source "proxmox-iso" "debian_13_base" {
  // proxmox connection info
  proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
  username    = var.token_id     #api token id
  token       = var.token_secret #api token secret

  // proxmox settings
  node                     = var.node         # proxmox node
  pool                     = var.pool         # resource pool
  insecure_skip_tls_verify = var.insecure_tls # disables https checks during connections

  // virtual machine settings
  vm_name      = "debian13base"
  memory       = 1024
  cores        = 1
  sockets      = 1
  qemu_agent   = true
  task_timeout = "20m"
  tags         = "linux;debian;13;template;base"

  // install media
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/debian-13.1.0-amd64-netinst.iso"
    iso_checksum = "sha512:873e9aa09a913660b4780e29c02419f8fb91012c8092e49dcfe90ea802e60c82dcd6d7d2beeb92ebca0570c49244eee57a37170f178a27fe1f64a334ee357332"
    unmount      = true
  }

  // disk settings
  disks {
    type         = "scsi"
    storage_pool = "local-lvm"
    disk_size    = "5G"
  }

  // network settings
  network_adapters {
    bridge   = "vmbr0"
    firewall = false
  }

  // cloud init settings
  cloud_init              = true
  cloud_init_storage_pool = "cidata"

  // boot settings
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter><wait>"
  ]

  // communicator settings
  communicator         = "ssh"
  ssh_username         = var.username
  ssh_password         = var.password
  ssh_private_key_file = data.sshkey.install.private_key_path
  ssh_timeout          = "20m"

  // http content
  http_content = local.source_content
}