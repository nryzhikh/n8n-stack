# n8n-stack

Self-hosted **n8n + NocoDB + Adminer + PostgreSQL + Caddy + RSSHub** automation stack with SSL.

## 📦 What's Included

- **n8n** - Workflow automation platform
- **NocoDB** - No-code database (Airtable alternative)
- **PostgreSQL** - Primary database
- **Adminer** - Database management interface
- **Caddy** - Reverse proxy with automatic SSL
- **RSSHub** - RSS feed aggregator and transformer

## 🚀 Quick Start

### 1. Server Initialization (New VPS)

**For a fresh Ubuntu VPS**, use the automated setup script:

```bash
# See detailed instructions in:
./scripts/SERVER_SETUP.md
```

The initialization script will:
- ✅ Create secure `deploy` user
- ✅ Install Docker & Docker Compose
- ✅ Configure firewall
- ✅ Disable root login & password authentication
- ✅ Set up Fail2Ban protection

**Quick setup:**
```bash
# 1. Copy script to your server
scp scripts/init_server.sh root@YOUR_SERVER_IP:/root/

# 2. Run on server
ssh root@YOUR_SERVER_IP
chmod +x /root/init_server.sh
/root/init_server.sh
```

📖 **[Full Server Setup Guide →](scripts/SERVER_SETUP.md)**

### 2. Deploy the Stack

After server initialization, deploy from your local machine:

```bash
# Update the server IP in deploy.sh
nano deploy.sh  # Change REMOTE_HOST="YOUR_SERVER_IP"

# Run deployment
./deploy.sh
```







The deployment script automatically:
- Builds and copies Docker images
- Sets up environment configuration
- Starts all services with Docker Compose
- Configures SSL certificates via Caddy

## 🔧 Manual Deployment (Alternative)

If you prefer manual deployment:

```bash
# 1. Clone the repository on server
ssh deploy@YOUR_SERVER_IP
git clone https://github.com/nryzhikh/n8n-stack.git
cd n8n-stack

# 2. Configure environment
cp .env.example .env
nano .env  # Update your settings

# 3. Start the stack
docker compose up -d

# 4. Check logs
docker logs --tail 50 n8n-stack-n8n-1
```

## 🌐 DNS Setup

Configure your domain to point to your server:

- **Recommended**: Use [DuckDNS](https://www.duckdns.org/) for free dynamic DNS
- Or use your own domain registrar

Add A records:
```
n8n.yourdomain.com     → YOUR_SERVER_IP
nocodb.yourdomain.com  → YOUR_SERVER_IP
rsshub.yourdomain.com  → YOUR_SERVER_IP
```

## 💾 Performance Optimization

### Create Swap File (Recommended for VPS with <2GB RAM)

```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```



## 📡 RSSHub Usage Examples

Transform any website into RSS feeds:

### JSON API Transform
```
https://rsshub.yourdomain.com/rsshub/transform/json/
  https%3A%2F%2Fapi.github.com%2Frepos%2Fginuerzh%2Fgost%2Freleases/
  title=Gost%20releases&itemTitle=tag_name&itemLink=html_url&itemDesc=body
```

### HTML Page Transform
```
https://rsshub.yourdomain.com/rsshub/transform/html/
  https%3A%2F%2Fexample.com%2F/
  item=article&itemTitle=h2&itemLink=a&itemDesc=.content
```

### Social Media Feeds
```
https://rsshub.yourdomain.com/twitter/user/username?format=json
```

## 🛠️ Useful Commands

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker logs -f n8n-stack-n8n-1
docker logs -f n8n-stack-nocodb-1
```

### Restart Services
```bash
docker compose restart
```

### Update Stack
```bash
./deploy.sh
```

### Database Management

Create additional databases:
```bash
docker exec -it n8n-stack-postgres-1 psql -U your_postgres_user -c "CREATE DATABASE dbname;"
```

### Backup
```bash
# Automated backups (see scripts/backup.sh)
./scripts/backup.sh
```

## 🔐 Security Features

- ✅ SSH key authentication only
- ✅ Root login disabled
- ✅ UFW firewall configured
- ✅ Fail2Ban for SSH protection
- ✅ Automatic SSL certificates via Caddy
- ✅ Non-root user for deployment
- ✅ Isolated Docker networks

## 📚 Additional Resources

- [Server Setup Guide](scripts/SERVER_SETUP.md) - Detailed VPS initialization
- [n8n Documentation](https://docs.n8n.io/)
- [NocoDB Documentation](https://docs.nocodb.com/)
- [RSSHub Documentation](https://docs.rsshub.app/)
- [Caddy Documentation](https://caddyserver.com/docs/)

## 🤝 Contributing

Issues and pull requests are welcome!

## 📝 License

MIT License - See LICENSE file for details

---

**Current Production Server**: `89.191.234.118`

rsshub:
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/nryzhikh/rsshub:latest \
  --push \
  .