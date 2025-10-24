# n8n-stack

Self-hosted **n8n + NocoDB + Adminer + PostgreSQL + Caddy** stack.

## Quick start
```bash

# login to vps via ssh from terminal
ssh root@165.232.125.58

# stack repo
https://github.com/nryzhikh/n8n-stack.git

# create non-root user with strong password copy ssh key to that user
adduser deploy
usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy


# log off root user and login with new user
exit
ssh deploy@165.232.125.58 

# disable root ssh login
sudo nano /etc/ssh/sshd_config
    # set options:
    PermitRootLogin no
    PasswordAuthentication no

# Reload ssh
sudo systemctl restart ssh

# Basic firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable


# Docker verified key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg







git clone https://github.com/nryzhikh/n8n-stack.git
cd n8n-stack
cp .env.example .env
nano .env
docker compose up -d



DNS: https://www.duckdns.org/


docker logs --tail 50 n8n-stack-n8n-1


scp .env deploy@162.232.125.58:/home/deploy/n8n-stack