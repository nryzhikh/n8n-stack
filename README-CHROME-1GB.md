# Running Content Factory Stack on 1GB RAM VPS

## 📊 Memory Budget for 1GB VPS

With the optimized `docker-compose.yaml`:

| Service | Memory | Required? |
|---------|--------|-----------|
| **Postgres** | ~25 MB | ✅ Yes |
| **Redis** | ~15 MB | ✅ Yes |
| **n8n** | ~100 MB | ✅ Yes |
| **NocoDB** | ~50 MB | ⚠️ Optional |
| **Caddy** | ~20 MB | ✅ Yes |
| **RSSHub** | ~200 MB → 128 MB (limited) | ✅ Yes |
| **Chrome** | ~100-200 MB (on-demand) | ⚠️ For protected feeds |
| **Adminer** | ~10 MB | ⚠️ Optional |
| **TOTAL** | ~650 MB + swap | |

**Free RAM**: ~350 MB for bursts and system processes

---

## 🎯 Solution: Lightweight Chrome with Memory Limits

### What Changed:

1. ✅ **Removed Browserless** (was 1.17 GB!)
2. ✅ **Added Alpine Chrome** with strict memory limits (200 MB max)
3. ✅ **Added memory limits** to RSSHub (256 MB max)
4. ✅ **Optimized Chrome flags** for minimal resource usage

### Chrome Features:
- Uses **Chrome DevTools Protocol** (CDP) via WebSocket
- Memory limited to **200 MB**
- Automatically closes idle tabs
- Minimal background processes

---

## 🚀 Using Chrome from n8n

### Method 1: Code Node with CDP (Recommended)

```javascript
const CDP = require('chrome-remote-interface');

const client = await CDP({ host: 'chrome', port: 9222 });
const { Page, Runtime } = client;

await Page.enable();
await Page.navigate({ url: 'https://protected-site.com/feed' });
await Page.loadEventFired();

// Wait for Cloudflare challenge
await new Promise(r => setTimeout(r, 5000));

const result = await Runtime.evaluate({
  expression: 'document.documentElement.outerHTML'
});

await client.close();
return [{ json: { html: result.result.value } }];
```

See `n8n-chrome-example.js` for full example.

### Method 2: HTTP Request to Chrome JSON API

```
GET http://chrome:9222/json/version
```

Returns Chrome info and WebSocket URL.

---

## ⚙️ Server Setup for 1GB VPS

### 1. Enable Swap (CRITICAL!)

```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optimize for low memory
sudo sysctl vm.swappiness=10
sudo sysctl vm.vfs_cache_pressure=50
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
```

### 2. Monitor Memory

```bash
# Watch memory in real-time
watch -n 2 'free -h && docker stats --no-stream'

# Check if services are being OOM killed
sudo dmesg | grep -i "killed process"
```

### 3. Deploy

```bash
docker compose up -d
docker stats --no-stream
```

---

## 🔧 Troubleshooting

### Chrome crashes with "Out of Memory"

1. **Increase shm_size** in docker-compose.yaml:
   ```yaml
   shm_size: 512mb  # instead of 256mb
   ```

2. **Reduce concurrent Chrome tabs** in your n8n workflows
   - Process feeds sequentially, not in parallel
   - Close Chrome connections immediately after use

3. **Use Chrome only when necessary**
   - First try direct HTTP request
   - Only use Chrome if you get Cloudflare/403 errors

### RSSHub uses too much memory

Reduce cache:
```yaml
environment:
  CACHE_EXPIRE: 300  # 5 minutes instead of default
  CACHE_CONTENT_EXPIRE: 60
```

### Services randomly restart

Check OOM kills:
```bash
sudo dmesg | grep -i "out of memory"
```

Add more swap or reduce services.

---

## 📈 Performance Tips

1. **Schedule heavy tasks during off-peak hours**
   - Scrape protected feeds at night when traffic is low

2. **Cache aggressively in n8n**
   - Don't fetch same feed multiple times
   - Use n8n's built-in caching nodes

3. **Consider removing optional services**
   ```bash
   # Stop NocoDB if you don't need a database UI
   docker compose stop nocodb
   
   # Stop Adminer after initial setup
   docker compose stop adminer
   ```

4. **Use external services for heavy tasks**
   - **ScrapingBee**: $49/month for 100k requests
   - **BrowserBase**: Pay-per-use browser automation
   - **Apify**: Cloud scraping platform

---

## ✅ When This Setup Works

- ✅ **1-2 Cloudflare-protected sites** per hour
- ✅ **5-10 unprotected RSS feeds** continuously
- ✅ **Light n8n workflows** (< 10 active per minute)
- ✅ **Small databases** (< 100 MB)

## ❌ When You Need More Resources

- ❌ **5+ protected sites** simultaneously
- ❌ **Heavy browser automation** (screenshots, complex interactions)
- ❌ **Large dataset processing** (> 1000 records/minute)
- ❌ **Multiple parallel workflows**

→ **Upgrade to 2GB RAM VPS** ($10-12/month)

---

## 🎯 Recommended VPS Providers for 1GB

- **Hetzner**: €4.51/month (2 vCPU, 2 GB RAM) - Best value
- **DigitalOcean**: $6/month (1 vCPU, 1 GB RAM)
- **Vultr**: $5/month (1 vCPU, 1 GB RAM)
- **Linode**: $5/month (1 vCPU, 1 GB RAM)

💡 **Pro tip**: 2GB RAM is MUCH better for browser automation!

