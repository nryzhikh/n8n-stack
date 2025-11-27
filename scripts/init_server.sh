#!/bin/bash
# ==========================================================
# Secure Server Initialization Script for n8n-stack
# Works on Ubuntu 22.04 / 24.04 (DigitalOcean, Hetzner, AWS, etc.)
# 
# This script:
# - Creates a non-root deploy user with sudo privileges
# - Sets up SSH key authentication
# - Disables root login and password authentication
# - Installs Docker and Docker Compose
# - Configures UFW firewall
# - Enables Fail2Ban for SSH protection
# ==========================================================

set -e

# Configuration
NEW_USER="deploy"
SSH_PORT=22
PUBKEY_URL=""   # Optional: URL to your public SSH key (e.g. https://github.com/username.keys)
PUBKEY_CONTENT=""  # Or paste your public key string directly between quotes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run as root"
    exit 1
fi

echo "=========================================="
echo "  n8n-stack Server Initialization"
echo "  Starting secure server setup..."
echo "=========================================="
echo ""

# --- Update and upgrade system
print_status "Updating system packages..."
apt update && apt upgrade -y

# --- Install core packages
print_status "Installing essential packages..."
apt install -y curl ca-certificates gnupg ufw fail2ban sudo git wget

# --- Create a non-root user
print_status "Setting up deploy user..."
if id "$NEW_USER" &>/dev/null; then
  print_warning "User '$NEW_USER' already exists. Skipping creation."
else
  print_status "Creating user: $NEW_USER"
  adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  
  # Allow passwordless sudo for deploy user (optional, comment out if you want password prompt)
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER
  chmod 440 /etc/sudoers.d/$NEW_USER
  
  print_status "User '$NEW_USER' created with sudo privileges"
fi

# --- Setup SSH key for new user
print_status "Configuring SSH access for $NEW_USER..."
mkdir -p /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh

if [ -n "$PUBKEY_URL" ]; then
  print_status "Fetching SSH key from URL: $PUBKEY_URL"
  curl -fsSL "$PUBKEY_URL" -o /home/$NEW_USER/.ssh/authorized_keys
  print_status "SSH key downloaded successfully"
elif [ -n "$PUBKEY_CONTENT" ]; then
  print_status "Installing provided SSH key..."
  echo "$PUBKEY_CONTENT" > /home/$NEW_USER/.ssh/authorized_keys
  print_status "SSH key installed successfully"
else
  print_warning "No SSH key provided!"
  print_warning "You must add your SSH key manually to: /home/$NEW_USER/.ssh/authorized_keys"
  print_warning "Or you'll be locked out when password auth is disabled!"
fi

chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

# --- Secure SSH configuration
print_status "Hardening SSH configuration..."
print_warning "Disabling root login..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

print_warning "Disabling password authentication (SSH keys only)..."
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Ensure public key authentication is enabled
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Set SSH port
sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config

print_status "Restarting SSH service..."
systemctl restart ssh
print_status "SSH hardening complete"

# --- Setup UFW firewall
print_status "Configuring UFW firewall..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable

print_status "Firewall rules applied:"
sudo ufw status numbered

# --- Enable Fail2Ban
print_status "Enabling Fail2Ban for SSH protection..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
print_status "Fail2Ban is active"

# --- Install Docker using modern keyring method
print_status "Installing Docker and Docker Compose..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

# Allow new user to use Docker without sudo
usermod -aG docker $NEW_USER
print_status "Docker installed successfully"

# Verify Docker installation
DOCKER_VERSION=$(docker --version)
COMPOSE_VERSION=$(docker compose version)
print_status "$DOCKER_VERSION"
print_status "$COMPOSE_VERSION"

# --- Create deployment directory
print_status "Creating deployment directory..."
mkdir -p /home/$NEW_USER/n8n-stack
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/n8n-stack

# --- Clean up & reboot
print_status "Cleaning up..."
apt autoremove -y
apt clean

# Display summary
echo ""
echo "=========================================="
echo -e "${GREEN}✓ Server Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • User created: $NEW_USER (with sudo access)"
echo "  • Docker & Docker Compose: Installed"
echo "  • SSH hardening: Root login disabled, password auth disabled"
echo "  • Firewall: Configured (ports 22, 80, 443)"
echo "  • Fail2Ban: Active"
echo "  • Deployment directory: /home/$NEW_USER/n8n-stack"
echo ""
echo "Next steps:"
echo "  1. Test SSH access: ssh $NEW_USER@$(hostname -I | awk '{print $1}')"
echo "  2. Deploy n8n-stack from your local machine"
echo ""
print_warning "Rebooting server in 10 seconds to apply kernel updates..."
print_warning "Press Ctrl+C to cancel reboot"
echo ""
sleep 10
reboot
