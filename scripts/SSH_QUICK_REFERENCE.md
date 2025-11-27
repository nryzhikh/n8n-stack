# SSH Quick Reference Card

Quick commands for SSH key management and server access.

## 🔑 Check Your SSH Keys

```bash
# List all SSH keys
ls -la ~/.ssh/

# View your RSA public key
cat ~/.ssh/id_rsa.pub

# View your Ed25519 public key (recommended)
cat ~/.ssh/id_ed25519.pub
```

## 📋 Copy Key to Clipboard

```bash
# macOS - RSA
cat ~/.ssh/id_rsa.pub | pbcopy

# macOS - Ed25519
cat ~/.ssh/id_ed25519.pub | pbcopy

# Linux (requires xclip)
cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
```

## 🔐 Generate New SSH Key

```bash
# Ed25519 (Recommended - faster, more secure)
ssh-keygen -t ed25519 -C "your_email@example.com"

# RSA (Traditional, widely compatible)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Press Enter to accept defaults, then optionally set a passphrase.

## 🚀 Add Key to Server

### Method 1: ssh-copy-id (Easiest)
```bash
ssh-copy-id username@server-ip
```

### Method 2: Manual
```bash
cat ~/.ssh/id_rsa.pub | ssh username@server-ip \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && \
   chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

### Method 3: GitHub Keys
```bash
# Use your GitHub public keys
curl https://github.com/YOUR_USERNAME.keys | ssh username@server-ip \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

## 🔒 Test SSH Connection

```bash
# Standard connection
ssh username@server-ip

# Test without login
ssh -T username@server-ip

# Verbose output (for debugging)
ssh -v username@server-ip

# Use specific key
ssh -i ~/.ssh/id_ed25519 username@server-ip
```

## 🛡️ Harden SSH Server

### Disable Password Authentication
```bash
sudo nano /etc/ssh/sshd_config

# Add/modify:
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no

# Restart SSH
sudo systemctl restart sshd
```

## 🔍 Troubleshooting

### Permission Denied (publickey)
```bash
# Check SSH key permissions on local machine
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Check on server
ssh username@server-ip
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### View Server SSH Logs
```bash
# On server
sudo tail -f /var/log/auth.log    # Ubuntu/Debian
sudo tail -f /var/log/secure       # CentOS/RHEL
```

### Test SSH Key Authentication
```bash
# Check which key is being used
ssh -v username@server-ip 2>&1 | grep identity
```

## 📱 SSH Config File

Create `~/.ssh/config` for easier access:

```bash
# Edit config
nano ~/.ssh/config

# Add entry:
Host myserver
    HostName 89.191.234.118
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    Port 22

# Save and use:
ssh myserver
```

## 🔐 SSH Agent

Load keys into SSH agent (avoid typing passphrase repeatedly):

```bash
# Start agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l

# Remove all keys
ssh-add -D
```

## 🌐 Remote Commands

```bash
# Run single command
ssh user@server 'docker ps'

# Run multiple commands
ssh user@server 'cd ~/app && docker compose up -d'

# Redirect output to local file
ssh user@server 'cat /var/log/app.log' > local-log.txt
```

## 🔄 SSH Tunneling

```bash
# Local port forwarding (access remote service locally)
ssh -L 8080:localhost:80 user@server

# Remote port forwarding (expose local service remotely)
ssh -R 9000:localhost:3000 user@server

# Dynamic port forwarding (SOCKS proxy)
ssh -D 8080 user@server
```

## 📦 File Transfer

```bash
# Copy file to server
scp local-file.txt user@server:/remote/path/

# Copy from server
scp user@server:/remote/file.txt ./local-path/

# Copy directory recursively
scp -r ./local-dir user@server:/remote/path/

# Using rsync (better for large transfers)
rsync -avz ./local-dir/ user@server:/remote/path/
```

## 🚨 Emergency Access

If locked out and SSH keys don't work:

1. **Use VPS provider's console** (web-based terminal)
2. Log in as root
3. Check `/home/username/.ssh/authorized_keys`
4. Fix permissions:
   ```bash
   chmod 700 /home/username/.ssh
   chmod 600 /home/username/.ssh/authorized_keys
   chown -R username:username /home/username/.ssh
   ```

## 🔧 Quick Server Info

```bash
# Check memory usage
free -h

# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Check running containers
docker ps

# Check firewall status
sudo ufw status

# Check SSH service status
sudo systemctl status sshd
```

---

**Pro Tip**: Add these to your shell aliases:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias sshprod='ssh deploy@89.191.234.118'
alias deploystack='cd ~/repos/n8n-stack && ./deploy.sh'
```

