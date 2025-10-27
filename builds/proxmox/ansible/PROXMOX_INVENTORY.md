# Proxmox Dynamic Inventory

This directory contains a Proxmox dynamic inventory configuration that automatically discovers VMs and containers from your Proxmox VE cluster.

## Prerequisites

The Proxmox dynamic inventory plugin is part of the `community.general` collection. Ensure it's installed:

```bash
ansible-galaxy collection install community.general
```

## Configuration

### 1. Edit `inventory.proxmox.yaml`

Update the following values:

```yaml
# Proxmox cluster URL
url: http://your-proxmox-server:8006

# Authentication (choose one method)

# Method 1: API Token (recommended for automation)
user: ansible@pve
token_name: ansible-token
token_value: your-api-token-value-here

# Method 2: Username/Password (not recommended for production)
# user: ansible@pve
# password: your_password_here
```

### 2. Create Proxmox API Token

If using API tokens (recommended):

```bash
# In Proxmox web UI:
# 1. Go to Datacenter → Permissions → API Tokens
# 2. Click "Add"
# 3. User: ansible@pve (or your user)
# 4. Token ID: ansible-token
# 5. Uncheck "Privilege Separation" (for full access)
# 6. Click "Add"
# 7. Copy the token value (you won't see it again!)
```

Or via CLI:

```bash
pveum user token add ansible@pve ansible-token --privsep 0
```

### 3. Set Required Permissions

The user/token needs these permissions:

```bash
# Give VM.Audit permissions to the user
pveum acl modify / -user ansible@pve -role PVEAuditor

# Or for a token:
pveum acl modify / -token 'ansible@pve!ansible-token' -role PVEAuditor
```

## Usage

### Test the Inventory

```bash
# List all discovered hosts
ansible-inventory -i inventory.proxmox.yaml --list

# Show inventory in graph format
ansible-inventory -i inventory.proxmox.yaml --graph

# Test connectivity to all hosts
ansible all -i inventory.proxmox.yaml -m ping
```

### Use with Playbooks

```bash
# Run playbook against all Proxmox hosts
ansible-playbook -i inventory.proxmox.yaml playbook.yml

# Run against specific group (created from Proxmox tags)
ansible-playbook -i inventory.proxmox.yaml playbook.yml --limit docker

# Run against specific host
ansible-playbook -i inventory.proxmox.yaml playbook.yml --limit vm-name
```

### Combine with Static Inventory

You can use both static and dynamic inventories:

```bash
ansible-playbook -i inventory -i inventory.proxmox.yaml playbook.yml
```

## Grouping

The inventory automatically creates groups based on Proxmox tags:

### Tag VMs in Proxmox

```bash
# Via CLI
qm set <vmid> --tags "docker,production"

# Or via web UI: VM → Options → Tags
```

### Available Groups

Based on the configuration, the following groups are created:

- `tag_docker` - VMs tagged with "docker"
- `tag_database` - VMs tagged with "database"  
- `tag_webserver` - VMs tagged with "webserver"
- `tag_production` - VMs tagged with "prod"
- `tag_development` - VMs tagged with "dev"

### Custom Groups

Edit `inventory.proxmox.yaml` to add more groups:

```yaml
groups:
  my_custom_group: "'my-tag' in (proxmox_tags_parsed|list)"
  linux_servers: "proxmox_ostype == 'l26'"  # Linux 2.6+ kernel
  windows_servers: "proxmox_ostype == 'win10'"
```

## Variables and Facts

When `want_facts: true`, the inventory provides these facts for each VM:

- `proxmox_name` - VM name
- `proxmox_vmid` - VM ID
- `proxmox_node` - Proxmox node hosting the VM
- `proxmox_status` - VM status (running, stopped, etc.)
- `proxmox_tags_parsed` - List of tags
- `proxmox_mem` - Memory in MB
- `proxmox_cores` - Number of CPU cores
- `proxmox_ostype` - OS type
- `proxmox_net0`, `proxmox_net1`, etc. - Network interfaces
- `proxmox_ipconfig0`, `proxmox_ipconfig1`, etc. - IP configurations

### Use Facts in Playbooks

```yaml
- name: Display VM info
  debug:
    msg: "{{ inventory_hostname }} is running on {{ proxmox_node }} with {{ proxmox_mem }}MB RAM"
```

## Troubleshooting

### Plugin Not Found Error

```
specifies unknown plugin 'community.general.proxmox'
```

**Solution**: Install the collection:
```bash
ansible-galaxy collection install community.general
```

### Connection Refused

```
Failed to connect to Proxmox API
```

**Solution**: Check that:
1. The Proxmox URL is correct and accessible
2. Port 8006 is open in firewall
3. The Proxmox API is running: `systemctl status pveproxy`

### Authentication Failed

```
401 Unauthorized
```

**Solution**: Verify:
1. API token exists: `pveum user token list ansible@pve`
2. Token has not been deleted
3. User has correct permissions: `pveum user list`
4. Token value is correct (regenerate if lost)

### SSL Certificate Errors

```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Solution**: Set `validate_certs: false` in inventory config (only for self-signed certs)

### No Hosts Found

```
No inventory was parsed
```

**Solution**:
1. Verify VMs are running in Proxmox
2. Check file extension is `.proxmox.yaml` or `.proxmox.yml`
3. Ensure plugin name is `community.general.proxmox`
4. Test API access: `curl -k https://your-proxmox:8006/api2/json/cluster/resources`

### Hosts Have No IP Address

**Solution**: The inventory uses `compose` to set `ansible_host`. Check:
1. VMs have network interfaces configured
2. QEMU guest agent is installed (for IP detection)
3. Update the `compose` section to match your network config

## Advanced Configuration

### Filter Hosts

Only include VMs matching certain criteria:

```yaml
filters:
  # Only running VMs
  - "proxmox_status == 'running'"
  # Only VMs with specific name pattern
  - "'web' in proxmox_name"
  # Only VMs on specific node
  - "proxmox_node == 'pve1'"
```

### Custom Host Variables

Add custom variables to hosts:

```yaml
compose:
  ansible_host: proxmox_ipconfig0.ip | default(proxmox_net0.ip) | ipaddr('address')
  ansible_user: debian
  custom_var: "{{ proxmox_name }}-custom-value"
```

### Caching

Enable caching to speed up inventory queries:

```yaml
cache: true
cache_plugin: jsonfile
cache_timeout: 300  # seconds
cache_connection: /tmp/proxmox_inventory_cache
```

## Examples

### Example 1: Deploy to All Docker Hosts

```bash
# Tag VMs in Proxmox with "docker"
ansible-playbook -i inventory.proxmox.yaml playbook.yml \
  -e "host_type=docker" \
  --limit tag_docker
```

### Example 2: Update All Production VMs

```bash
# Tag production VMs with "prod"
ansible-playbook -i inventory.proxmox.yaml playbook.yml \
  -e "update_packages=true" \
  --limit tag_production
```

### Example 3: Configure by Node

```bash
# Target all VMs on a specific Proxmox node
ansible-playbook -i inventory.proxmox.yaml playbook.yml \
  --limit proxmox_pve1
```

## References

- [Proxmox Inventory Plugin Docs](https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_inventory.html)
- [Ansible Dynamic Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html)
- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
