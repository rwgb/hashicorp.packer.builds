# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Repository overview
- This repo contains HashiCorp Packer templates for building Proxmox VE images for:
  - Linux: Debian 12
  - Windows: Server 2019 and Server 2022
- Each OS/version lives in its own subdirectory under builds/ with a consistent layout:
  - build.pkr.hcl: The build block and post-processors (manifests)
  - sources.pkr.hcl: proxmox-iso and/or proxmox-clone sources
  - variables.pkr.hcl: variable declarations
  - variables.auto.pkrvars.hcl: example values auto-loaded when running in that directory
  - data/*.pkrtpl.hcl: unattended install assets (Windows autounattend.xml, Debian preseed/ks.cfg, cloud-init templates)
  - windows/scripts/*.ps1: provisioning scripts invoked during Windows first logon
- Plugins are declared per template via required_plugins (packer init installs them):
  - Proxmox builder (proxmox-iso/proxmox-clone)
  - Windows Update provisioner (Windows builds)
  - git-commit data source to capture VCS metadata in manifests
- Builds write a manifest JSON to manifests/<timestamp>.json with commit metadata and other custom fields.

Common commands
- Format (lint-style check):
  - packer fmt -recursive builds
  - packer fmt -recursive -check builds
- Initialize plugins for a template (run per build directory):
  - packer init builds/linux/debian/12
  - packer init builds/windows/server/2019
  - packer init builds/windows/server/2022
- Validate a single template (acts as “tests” for packer configs):
  - From repo root (using the example autovars file in-place):
    - packer validate -var-file=builds/linux/debian/12/variables.auto.pkrvars.hcl builds/linux/debian/12
    - packer validate -var-file=builds/windows/server/2019/variables.auto.pkrvars.hcl builds/windows/server/2019
    - packer validate -var-file=builds/windows/server/2022/variables.auto.pkrvars.hcl builds/windows/server/2022
  - Or, run inside the target directory (auto-loads *.auto.pkrvars.hcl):
    - packer validate .
- Build images (selecting exact sources where multiple exist):
  - Debian 12 (ISO-based):
    - packer build builds/linux/debian/12
  - Windows Server 2022:
    - ISO:    packer build -only=proxmox-iso.windows_server_2k22_data_center_base builds/windows/server/2022
    - Clone:  packer build -only=proxmox-clone.windows_server_2k22_data_center_base builds/windows/server/2022
  - Windows Server 2019:
    - ISO:    packer build -only=proxmox-iso.windows_server_2k19_data_center_base builds/windows/server/2019
    - Clone:  packer build -only=proxmox-clone.windows_server_2k19_data_center_base builds/windows/server/2019

Supplying variables (recommended)
- You can inject variables via environment variables to avoid relying on local *.auto.pkrvars.hcl files. Packer will read PKR_VAR_ prefixed environment variables automatically.
- Example (bash/zsh):
  - export PKR_VAR_proxmox_host={{PROXMOX_HOST}}
  - export PKR_VAR_token_id={{PROXMOX_TOKEN_ID}}
  - export PKR_VAR_token_secret={{PROXMOX_TOKEN_SECRET}}
  - export PKR_VAR_node={{PROXMOX_NODE}}
  - export PKR_VAR_pool={{PROXMOX_POOL}}
  - Optional overrides:
    - export PKR_VAR_username={{BUILD_USERNAME}}   # default: "packer"
    - export PKR_VAR_password={{BUILD_PASSWORD}}   # default: "packer"
    - export PKR_VAR_insecure_tls={{true|false}}   # default: true
- After exporting, run packer validate/build from repo root without -var-file flags.

Architecture and key behaviors
- Debian 12 (builds/linux/debian/12):
  - Uses proxmox-iso to install from local:iso/debian-12.1.0-amd64-netinst.iso with SSH communicator.
  - Enables Proxmox cloud-init and sets cloud_init_storage_pool (cidata) so the resulting VM template is cloud-init ready.
  - Serves a generated preseed (ks.cfg) over Packer’s built-in HTTP server via http_content; boot_command points the installer to http://<HTTPIP>:<HTTPPort>/ks.cfg.
  - Disk layout leverages LVM with multiple XFS logical volumes (see ks.pkrtpl.hcl) and injects the provided SSH public key into root and the build user.
  - Manifest post-processor records build time, git author/committer/timestamp, and template metadata.
- Windows Server 2019/2022 (builds/windows/server/{2019,2022}):
  - Two sources available per version: proxmox-iso to install from a Windows Server ISO, and proxmox-clone to clone an existing VM ID.
  - Autounattend.xml is rendered from data/autounattend.pkrtpl.hcl and attached via additional_iso_files; it sets language, partitioning (EFI or BIOS), product key (KMS), timezone, and first-logon commands.
  - additional_iso_files also mounts:
    - A drivers directory at D:\drivers (expected at builds/windows/server/<ver>/drivers) for virtio/QEMU drivers.
    - scripts directory containing windows-init.ps1 and windows-prepare.ps1; the former configures WinRM/firewall and installs QEMU GA, the latter performs OS hardening, Cloudbase-Init install/config, and RDP enablement.
  - Communicator is WinRM (HTTP, no SSL, with the configured build username/password) and cloud-init is enabled for the resulting template.
  - Manifests are emitted with VCS metadata from the git-commit data source.

Operational prerequisites and notes
- Proxmox storage prerequisites must exist and contain the referenced artifacts:
  - ISO storage: local:iso/<...>.iso for the specified Debian/Windows media.
  - Additional ISO storage: packer_iso for Windows drivers/scripts attachment.
  - cloud-init storage pool: cidata.
- The Windows drivers directory should contain the virtio/QEMU drivers compatible with your Proxmox/QEMU version; update paths in sources.pkr.hcl if you place drivers elsewhere.
- When running from repo root and using -var-file, pass the path to the versioned directory’s variables.auto.pkrvars.hcl. When running inside that directory, Packer auto-loads *.auto.pkrvars.hcl.
- Build outputs include a Proxmox VM/template (as configured) and a manifests/<timestamp>.json file with metadata.

