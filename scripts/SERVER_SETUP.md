# Server Setup Guide

This guide explains how to use the `init_server.sh` script to securely initialize a fresh Ubuntu VPS for the n8n-stack deployment.

## What This Script Does

The initialization script automates the following security and setup tasks:

1. ✅ Updates all system packages
2. ✅ Creates a non-root `deploy` user with sudo privileges
3. ✅ Sets up SSH key authentication
4. ✅ **Disables root login** (security best practice)
5. ✅ **Disables password authentication** (SSH keys only)
6. ✅ Installs Docker and Docker Compose
7. ✅ Configures UFW firewall (allows SSH, HTTP, HTTPS)
8. ✅ Enables Fail2Ban for SSH brute-force protection
9. ✅ Creates deployment directory structure
10. ✅ Reboots the server to apply kernel updates

## Prerequisites

- A fresh Ubuntu 22.04 or 24.04 VPS
- Root access to the server
- Your SSH public key ready (from `~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`)

## Quick Start

### Option 1: Using GitHub SSH Keys (Easiest)

If your public SSH key is on GitHub, you can use it directly:

1. **Edit the script** to add your GitHub username:

```bash
nano scripts/init_server.sh
```

Change line 20 to:
```bash
PUBKEY_URL="https://github.com/YOUR_GITHUB_USERNAME.keys"
```

2. **Copy the script to your server:**

```bash
scp scripts/init_server.sh root@YOUR_SERVER_IP:/root/
```

3. **Run the script on the server:**

```bash
ssh root@YOUR_SERVER_IP
chmod +x /root/init_server.sh
/root/init_server.sh
```

### Option 2: Paste Your SSH Key Directly

1. **Get your public key:**

```bash
cat ~/.ssh/id_rsa.pub
# Or if you use Ed25519:
cat ~/.ssh/id_ed25519.pub
```

2. **Edit the script** and paste your key:

```bash
nano scripts/init_server.sh
```

Change line 21 to include your full public key:
```bash
PUBKEY_CONTENT="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAA... your full key here ..."
```

3. **Copy and run** (same as Option 1 steps 2-3)

### Option 3: One-Liner with Inline Key

Run everything in one command from your local machine:

```bash
SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
ssh root@YOUR_SERVER_IP 'bash -s' <<EOF
apt update && apt install -y curl
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/n8n-stack/main/scripts/init_server.sh | \
sed "s|PUBKEY_CONTENT=\"\"|PUBKEY_CONTENT=\"$SSH_KEY\"|" | bash
EOF
```

## After Running the Script

The server will automatically reboot after ~10 seconds. Wait 1-2 minutes, then:

### 1. Test SSH Access with Your Deploy User

```bash
ssh deploy@YOUR_SERVER_IP
```

You should be logged in **without a password prompt** (using your SSH key).

### 2. Verify Docker Installation

```bash
docker --version
docker compose version
docker ps
```

### 3. Check Firewall Status

```bash
sudo ufw status
```

Should show ports 22, 80, and 443 open.

### 4. Verify Fail2Ban is Running

```bash
sudo systemctl status fail2ban
```

## Security Features Explained

### SSH Key Authentication Only

- Password authentication is **disabled**
- You can only log in with your SSH private key
- Much more secure than passwords

### Root Login Disabled

- Direct root login is **blocked**
- Use `deploy` user with `sudo` for administrative tasks
- Reduces attack surface

### Passwordless Sudo (Optional)

By default, the `deploy` user can run sudo commands without entering a password. If you prefer to require a password:

1. Edit the script before running:
```bash
nano scripts/init_server.sh
```

2. Comment out lines 72-73:
```bash
# echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER
# chmod 440 /etc/sudoers.d/$NEW_USER
```

### Firewall Configuration

Only essential ports are open:
- **Port 22**: SSH access
- **Port 80**: HTTP (for Let's Encrypt verification)
- **Port 443**: HTTPS (for n8n web interface)

All other incoming connections are blocked by default.

### Fail2Ban Protection

Automatically bans IPs after multiple failed SSH login attempts:
- Protects against brute-force attacks
- Default: 5 failed attempts = 10-minute ban

## Troubleshooting

### "Permission denied (publickey)"

Your SSH key wasn't properly added. To fix:

1. Log in via your VPS provider's console (web-based terminal)
2. Add your key manually:

```bash
mkdir -p /home/deploy/.ssh
nano /home/deploy/.ssh/authorized_keys
# Paste your public key, save (Ctrl+O, Enter, Ctrl+X)
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
```

3. Try SSH again: `ssh deploy@YOUR_SERVER_IP`

### Can't Access Root Anymore

This is **by design** for security. If you need root access:

1. Log in as deploy: `ssh deploy@YOUR_SERVER_IP`
2. Use sudo: `sudo -i` (becomes root)

### Need to Re-enable Password Authentication

Only do this temporarily for troubleshooting:

```bash
sudo nano /etc/ssh/sshd_config
# Change: PasswordAuthentication no → yes
sudo systemctl restart ssh
```

**Remember to disable it again after troubleshooting!**

### Script Failed Mid-Execution

The script uses `set -e`, so it stops on any error. Common issues:

1. **DNS problems**: Check `/etc/resolv.conf` has valid nameservers
2. **Network issues**: Ensure the VPS has internet connectivity
3. **Package conflicts**: Try running `apt update && apt upgrade -y` first

## Customization

### Change the Default User Name

Edit line 18 in the script:
```bash
NEW_USER="myusername"  # Instead of "deploy"
```

### Change SSH Port

Edit line 19 in the script:
```bash
SSH_PORT=2222  # Instead of 22
```

**Important**: After changing the port, connect with:
```bash
ssh -p 2222 deploy@YOUR_SERVER_IP
```

### Add Additional Firewall Rules

Add before line 126 in the script:
```bash
ufw allow 8080/tcp comment 'Custom service'
```

## Next Steps

After server initialization is complete:

1. ✅ Test SSH access with `deploy` user
2. ✅ Update the IP address in `deploy.sh`
3. ✅ Run the deployment: `./deploy.sh`

See the main [README.md](../README.md) for deployment instructions.

## Security Best Practices

- ✅ **Never share your private SSH key** (`id_rsa` or `id_ed25519`)
- ✅ **Keep your server updated**: Run `sudo apt update && sudo apt upgrade` regularly
- ✅ **Monitor logs**: Check `/var/log/auth.log` for suspicious activity
- ✅ **Use strong passphrases** for your SSH keys
- ✅ **Backup regularly**: Especially your n8n workflows and data

## Additional Security Enhancements (Optional)

### 1. Enable Automatic Security Updates

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### 2. Set Up Log Monitoring

```bash
sudo apt install logwatch
```

### 3. Add 2FA to SSH (Advanced)

```bash
sudo apt install libpam-google-authenticator
# Follow setup instructions
```

## Support

If you encounter issues:

1. Check the server logs: `journalctl -xe`
2. Review SSH logs: `sudo tail -f /var/log/auth.log`
3. Check firewall: `sudo ufw status verbose`
4. Verify Docker: `docker ps` and `docker compose version`

For n8n-stack specific issues, see the main [README.md](../README.md).

