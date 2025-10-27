// cloud config

autoinstall:
  version: 1
  apt:
    geoip: true
    preserve_sources_list: false
    primary:
      - arches: [amd64, i386]
        uri: http://archive.ubuntu.com/ubuntu
      - arches: [default]
        uri: http://ports.ubuntu.com/ubuntu-ports
  early-commands:
    - sudo systemctl stop ssh
  locale: ${guest_os_language}
  keyboard:
    layout: ${guest_os_keyboard}
  identity:
    hostname: debian-${id}
    username: ${username}
    password: ${password}
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - openssh-server
    - open-vm-tools
    - cloud-init
%{ for package in additional_packages ~}
    - ${package}
%{ endfor ~}
  user-data:
    disable_root: false
    timezone: ${guest_os_timezone}
  late-commands:
    - sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /target/etc/ssh/sshd_config
    - echo '${username} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${username}
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${username}
    - curtin in-target --target=/target -- sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
    - curtin in-target --target=/target -- update-grub