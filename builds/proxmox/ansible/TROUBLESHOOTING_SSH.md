# Ansible Connection Failure Troubleshooting Guide

## Current Error

```
Failed to connect to the host via ssh:
packer@192.168.1.44: Permission denied (publickey,password).
```

**Error Type**: SSH Authentication Failure  
**Exit Code**: 4 (Connection failure)  
**Host**: 192.168.1.44  
**User**: packer

## Root Causes

The authentication is failing because Ansible cannot authenticate as the `packer` user. This happens when:

1. ❌ SSH key is not set up for passwordless authentication
2. ❌ SSH key is not in the remote host's `~/.ssh/authorized_keys`
3. ❌ Password authentication is disabled but no password provided
4. ❌ Wrong user or host configuration

## Solutions

### Solution 1: Add SSH Password to Inventory (Quick Fix)

Update your inventory file to include the SSH password:

```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_pass=YOUR_PASSWORD
```

**OR** use `--ask-pass` when running:
```bash
ansible-playbook -i inventory playbook.yml --ask-pass
```

### Solution 2: Set Up SSH Key Authentication (Recommended)

#### Step 1: Generate SSH key (if you don't have one)
```bash
ssh-keygen -t ed25519 -C "ansible-automation"
# Press Enter to accept defaults
```

#### Step 2: Copy your public key to the target host
```bash
ssh-copy-id packer@192.168.1.44
```

**OR** manually:
```bash
# On your local machine
cat ~/.ssh/id_ed25519.pub

# SSH into the target host
ssh packer@192.168.1.44  # You'll need password this time

# On the remote host
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### Step 3: Test the connection
```bash
ssh packer@192.168.1.44
# Should connect without asking for password
```

#### Step 4: Update inventory (optional - specify key)
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

### Solution 3: Use Different User

If the `packer` user has issues, try a different user that you know works:

```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=debian ansible_ssh_pass=YOUR_PASSWORD
```

Or if you have root access:
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### Solution 4: Test SSH Connection Manually

Before running Ansible, verify SSH works:

```bash
# Test basic connection
ssh packer@192.168.1.44

# Test with specific key
ssh -i ~/.ssh/id_ed25519 packer@192.168.1.44

# Verbose output to see what's failing
ssh -vvv packer@192.168.1.44
```

### Solution 5: Update ansible.cfg for Password Authentication

If you need to use passwords, ensure SSH password authentication is enabled:

```ini
[defaults]
# ... existing config ...
ask_pass = False  # Change to True if you want to be prompted
host_key_checking = False  # Already set

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o PreferredAuthentications=password,publickey
```

## Quick Diagnostic Commands

### Check if host is reachable
```bash
ping -c 3 192.168.1.44
```

### Check if SSH port is open
```bash
telnet 192.168.1.44 22
# or
nc -zv 192.168.1.44 22
```

### Test Ansible connection
```bash
ansible docker_hosts -i inventory -m ping
```

### Test with verbose output
```bash
ansible-playbook -i inventory playbook.yml -vvv
```

## Updated Inventory Examples

### Example 1: With Password
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_pass=packer_password

[docker_hosts:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Example 2: With SSH Key
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_private_key_file=~/.ssh/id_ed25519

[docker_hosts:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Example 3: With Both (Fallback)
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_ssh_pass=packer_password

[docker_hosts:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o PreferredAuthentications=publickey,password'
```

### Example 4: Different Port
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_port=2222 ansible_user=packer ansible_ssh_pass=packer_password
```

## Recommended Workflow

1. **Test SSH connection manually first:**
   ```bash
   ssh packer@192.168.1.44
   ```

2. **If password required, either:**
   - Add password to inventory (less secure)
   - Set up SSH key authentication (recommended)

3. **Test Ansible ping:**
   ```bash
   ansible docker_hosts -i inventory -m ping
   ```

4. **Run your playbook:**
   ```bash
   ansible-playbook -i inventory playbook.yml
   ```

## Security Best Practices

1. ✅ **Use SSH keys** instead of passwords
2. ✅ **Use Ansible Vault** to encrypt sensitive data:
   ```bash
   ansible-vault encrypt_string 'your_password' --name 'ansible_ssh_pass'
   ```
3. ✅ **Use SSH agent** for key management
4. ✅ **Limit SSH access** with specific keys per host
5. ✅ **Disable password authentication** on servers (after key setup)

## Next Steps

Choose the solution that works best for your environment:

- **Development/Testing**: Use password in inventory (quick)
- **Production**: Use SSH keys with proper key management
- **CI/CD**: Use SSH agent or encrypted vault variables

## Verification

After applying a solution, verify it works:

```bash
# Test connection
ansible docker_hosts -i inventory -m ping

# Expected output:
# test | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

Then run your playbook:
```bash
ansible-playbook -i inventory playbook.yml
```
