#!/bin/bash
# ==========================================================
# Secure Server Initialization Script
# Works on Ubuntu 22.04 / 24.04 (DigitalOcean, Hetzner, AWS)
# Sets up a hardened environment with Docker & Firewall
# ==========================================================

set -e

NEW_USER="deploy"
SSH_PORT=22
PUBKEY_URL=""   # <-- optional: paste a URL to your public SSH key (e.g. from GitHub)
PUBKEY_CONTENT=""  # <-- or paste your public key string directly between quotes

echo "Starting secure server setup..."

# --- Update and upgrade system
apt update && apt upgrade -y

# --- Install core packages
apt install -y curl ca-certificates gnupg ufw fail2ban sudo

# --- Create a non-root user
if id "$NEW_USER" &>/dev/null; then
  echo "User '$NEW_USER' already exists."
else
  echo "Creating user: $NEW_USER"
  adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
fi

# --- Setup SSH key for new user
mkdir -p /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh

if [ -n "$PUBKEY_URL" ]; then
  echo "Fetching SSH key from URL..."
  curl -fsSL "$PUBKEY_URL" -o /home/$NEW_USER/.ssh/authorized_keys
elif [ -n "$PUBKEY_CONTENT" ]; then
  echo "Writing provided SSH key..."
  echo "$PUBKEY_CONTENT" > /home/$NEW_USER/.ssh/authorized_keys
else
  echo "No SSH key provided — please add manually to /home/$NEW_USER/.ssh/authorized_keys"
fi

chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

# --- Secure SSH configuration
echo " Securing SSH..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config

systemctl restart ssh

# --- Setup UFW firewall
echo " Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT
ufw allow 80
ufw allow 443
ufw --force enable

# --- Enable Fail2Ban
echo "Enabling Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban

# --- Install Docker using modern keyring method
echo "Installing Docker..."
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

# --- Clean up & reboot
echo "Cleaning up..."
apt autoremove -y
apt clean

echo "Setup complete!"
echo "You can now log in as: ssh $NEW_USER@$(hostname -I | awk '{print $1}')"
echo "Rebooting to apply kernel updates..."
sleep 5
reboot
