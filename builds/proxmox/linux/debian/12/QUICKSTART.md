# Chained Builds - Quick Reference

## Structure at a Glance

```
debian/12/
│
├── 📦 base/                    ← Build from ISO (once)
│   ├── build.pkr.hcl          Packer configuration
│   ├── sources.pkr.hcl        proxmox-iso source
│   ├── variables.pkr.hcl      Variable definitions
│   └── data/
│       └── ks.pkrtpl.hcl      Kickstart preseed
│
├── 🔧 configured/              ← Clone + Configure (many times)
│   ├── build.pkr.hcl          Packer + Ansible
│   ├── sources.pkr.hcl        proxmox-clone source
│   └── variables.pkr.hcl      Variable definitions
│
├── ⚙️ common.auto.pkrvars.hcl  ← Shared configuration
├── 🚀 build-chain.sh           ← Orchestration script
├── 📖 README.md                ← Full documentation
└── 📝 MIGRATION.md             ← Migration guide
```

## Build Flow

```
     ┌─────────────┐
     │ Debian ISO  │
     └──────┬──────┘
            │
            │ proxmox-iso (20 min)
            ▼
     ┌─────────────┐
     │debian-12-base│ ← Base Template (VM 9000)
     │   (Template) │
     └──────┬──────┘
            │
            ├─────────┬──────────┬──────────┬──────────┐
            │         │          │          │          │
            │         │          │          │          │
      proxmox-clone   │          │          │          │
       (5-10 min)     │          │          │          │
            │         │          │          │          │
            ▼         ▼          ▼          ▼          ▼
     ┌──────────┐ ┌───────┐ ┌──────────┐ ┌─────────┐ ┌────────┐
     │ base     │ │docker │ │database  │ │webserver│ │monitoring│
     │(9100)    │ │(9101) │ │(9102)    │ │(9103)   │ │(9104)    │
     └──────────┘ └───────┘ └──────────┘ └─────────┘ └────────┘
          ↑          ↑          ↑            ↑           ↑
          └──────────┴──────────┴────────────┴───────────┘
                    Ansible Provisioning
```

## Commands Cheat Sheet

### Using build-chain.sh (Recommended)

```bash
# Build base template only
./build-chain.sh base

# Build configured template (default: base)
./build-chain.sh configured

# Build specific type
./build-chain.sh configured docker
./build-chain.sh configured database
./build-chain.sh configured webserver

# Build with custom VM ID
./build-chain.sh configured docker --vm-id 9101

# Build complete chain
./build-chain.sh all

# Help
./build-chain.sh --help
```

### Manual Building

```bash
# Base template
cd base/
packer init .
packer validate -var-file=../common.auto.pkrvars.hcl .
packer build -var-file=../common.auto.pkrvars.hcl .

# Configured template
cd ../configured/
packer init .
packer validate -var-file=../common.auto.pkrvars.hcl \
  -var ansible_host_type=docker .
packer build -var-file=../common.auto.pkrvars.hcl \
  -var ansible_host_type=docker .
```

## Template Overview

| Template | VM ID | Source | Time | Purpose |
|----------|-------|--------|------|---------|
| debian-12-base | 9000 | ISO | 20m | Foundation |
| debian-12-base (conf) | 9100 | Clone | 5m | Hardened base |
| debian-12-docker | 9101 | Clone | 5m | Docker host |
| debian-12-database | 9102 | Clone | 5m | DB server |
| debian-12-webserver | 9103 | Clone | 5m | Web server |
| debian-12-monitoring | 9104 | Clone | 5m | Monitoring |

## Variable Override Examples

```bash
# Custom VM ID
packer build -var vm_id_base=8000 ...

# Custom disk size
packer build -var disk_size_base="50G" ...

# Custom ISO
packer build -var iso_file="local:iso/debian-12.5.0-amd64-netinst.iso" ...

# Custom clone template
packer build -var clone_template="my-custom-base" ...

# Custom Ansible type
packer build -var ansible_host_type=my-custom-type ...
```

## Typical Workflows

### First Time Setup
```bash
# 1. Configure credentials
vim common.auto.pkrvars.hcl

# 2. Build base
./build-chain.sh base

# 3. Build configured types
./build-chain.sh configured docker
./build-chain.sh configured database
```

### Daily Development
```bash
# Update Ansible playbook
vim ../../../../ansible/playbook.yml

# Rebuild only configured template
./build-chain.sh configured docker
```

### CI/CD Pipeline
```bash
# Stage 1: Build base (nightly)
./build-chain.sh base

# Stage 2: Build all types (parallel)
./build-chain.sh configured docker &
./build-chain.sh configured database &
./build-chain.sh configured webserver &
wait
```

## Troubleshooting Quick Fixes

### Permission denied
```bash
chmod +x build-chain.sh
```

### Template not found
```bash
# Verify base template exists
packer build -var clone_template="debian-12-base" ...
```

### SSH timeout
```bash
# Increase timeout in sources.pkr.hcl
ssh_timeout = "30m"
```

### Ansible fails
```bash
# Test Ansible separately
ansible-playbook -i inventory playbook.yml \
  --extra-vars "host_type=docker"
```

## File Sizes (Approximate)

| Component | Size |
|-----------|------|
| Debian ISO | ~650 MB |
| Base template | ~2-3 GB |
| Configured template | +100-500 MB (depends on type) |
| Build manifest | ~5 KB |

## Time Comparison

### Old Approach (Single Build)
```
Build docker template: ~20 min (ISO install + Ansible)
Build database template: ~20 min (ISO install + Ansible)
Build webserver template: ~20 min (ISO install + Ansible)
Total: 60 minutes
```

### New Approach (Chained)
```
Build base: ~20 min (once)
Build docker: ~5 min (clone + Ansible)
Build database: ~5 min (clone + Ansible)
Build webserver: ~5 min (clone + Ansible)
Total: 35 minutes (43% faster!)
```

Plus: Parallel builds possible for configured templates!

## Key Benefits

✅ **Speed** - Clone vs reinstall  
✅ **Consistency** - Same base for all  
✅ **Modularity** - Easy to add types  
✅ **Maintainability** - Clear structure  
✅ **Testability** - Test layers independently  
✅ **CI/CD** - Pipeline-friendly  

## Next Steps

1. Read `README.md` for details
2. Check `MIGRATION.md` if upgrading
3. Configure `common.auto.pkrvars.hcl`
4. Run `./build-chain.sh base`
5. Create your first configured template!

---

📚 **Full Documentation:** `README.md`  
🔄 **Migration Guide:** `MIGRATION.md`  
🚀 **Build Script:** `build-chain.sh --help`
