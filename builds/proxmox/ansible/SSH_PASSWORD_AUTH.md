# SSH Password Authentication Guide for Ansible

## Your Current Setup

Your inventory has been updated to support SSH password authentication.

## Option 1: Password in Inventory (Quick but Less Secure)

**File**: `inventory`

```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_pass=YOUR_PASSWORD_HERE

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

**Steps**:
1. Replace `YOUR_PASSWORD_HERE` with your actual password
2. Run your playbook:
   ```bash
   ansible-playbook -i inventory playbook.yml
   ```

⚠️ **Warning**: This stores the password in plain text. Don't commit this to git!

---

## Option 2: Use --ask-pass (More Secure)

Remove the password from inventory and use the `--ask-pass` flag:

**File**: `inventory`

```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

**Run with password prompt**:
```bash
ansible-playbook -i inventory playbook.yml --ask-pass
```

Ansible will prompt you for the SSH password when you run the playbook.

---

## Option 3: Ansible Vault (Best for Security)

Encrypt your password using Ansible Vault:

### Step 1: Create encrypted password variable

```bash
ansible-vault encrypt_string 'your_actual_password' --name 'ansible_ssh_pass'
```

This will output something like:
```yaml
ansible_ssh_pass: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653236336462626566653063336164663966303231363934653561363964363833
          ...
```

### Step 2: Create a group_vars file

Create `group_vars/docker_hosts.yml`:
```yaml
ansible_ssh_pass: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          [paste the encrypted output here]
```

### Step 3: Update inventory

**File**: `inventory`
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Step 4: Run with vault password

```bash
ansible-playbook -i inventory playbook.yml --ask-vault-pass
```

Or use a password file:
```bash
echo "your_vault_password" > .vault_pass
ansible-playbook -i inventory playbook.yml --vault-password-file .vault_pass
```

---

## Option 4: SSH Agent with Password (Hybrid)

If you want to use SSH keys but need a password for the key:

```bash
# Start SSH agent
eval $(ssh-agent)

# Add your key (will prompt for password)
ssh-add ~/.ssh/id_rsa

# Run playbook without password
ansible-playbook -i inventory playbook.yml
```

---

## Testing Your Setup

### Test Ansible Connection
```bash
# Ping test
ansible docker_hosts -i inventory -m ping

# With --ask-pass
ansible docker_hosts -i inventory -m ping --ask-pass
```

### Expected Output
```
test | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

## Recommended Setup for Your Use Case

Based on your inventory, here's the recommended configuration:

### For Development/Testing (Quick)

**inventory**:
```ini
[docker_hosts]
test ansible_host=192.168.1.44 ansible_user=packer

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

**Run command**:
```bash
ansible-playbook -i inventory playbook.yml --ask-pass --ask-become-pass
```

### For Production (Secure)

1. Set up SSH key authentication:
   ```bash
   ssh-copy-id packer@192.168.1.44
   ```

2. Update inventory:
   ```ini
   [docker_hosts]
   test ansible_host=192.168.1.44 ansible_user=packer ansible_ssh_private_key_file=~/.ssh/id_ed25519

   [all:vars]
   ansible_python_interpreter=/usr/bin/python3
   ```

3. Run without passwords:
   ```bash
   ansible-playbook -i inventory playbook.yml
   ```

---

## Common Issues & Solutions

### Issue: "Permission denied (publickey,password)"
**Solution**: Make sure you're using `--ask-pass` or have the correct password in inventory

### Issue: "Incorrect sudo password"
**Solution**: Add `--ask-become-pass` to be prompted for sudo password

### Issue: "SSH connection failed"
**Solution**: Verify you can SSH manually first:
```bash
ssh packer@192.168.1.44
```

---

## Security Best Practices

1. ✅ **Never commit passwords** to git
   - Add `inventory` to `.gitignore`
   - Use `inventory.example` as a template

2. ✅ **Use Ansible Vault** for sensitive data
   ```bash
   # Create .gitignore entry
   echo "inventory" >> .gitignore
   echo ".vault_pass" >> .gitignore
   ```

3. ✅ **Prefer SSH keys** over passwords
   - More secure
   - No password prompts
   - Easier automation

4. ✅ **Use different credentials** per environment
   - Development: passwords OK for quick testing
   - Production: SSH keys mandatory

---

## Quick Start Commands

### For your current setup:

```bash
# 1. Edit inventory and add your password
vim inventory
# Replace YOUR_PASSWORD_HERE with actual password

# 2. Test connection
ansible docker_hosts -i inventory -m ping

# 3. Run playbook
ansible-playbook -i inventory playbook.yml

# Alternative: Use --ask-pass instead
ansible-playbook -i inventory playbook.yml --ask-pass --ask-become-pass
```

---

## Files to Update

### .gitignore
Add these entries to avoid committing sensitive data:
```
inventory
.vault_pass
*.retry
```

### Keep inventory.example
Your `inventory.example` is perfect - it shows the structure without sensitive data.

---

## Next Steps

1. Choose your authentication method (I recommend Option 2 with `--ask-pass` for now)
2. Update the password in inventory or use `--ask-pass`
3. Test the connection: `ansible docker_hosts -i inventory -m ping`
4. Run your playbook: `ansible-playbook -i inventory playbook.yml`

Good luck! 🚀
