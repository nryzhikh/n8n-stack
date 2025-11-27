# 🚀 Quick Reference - Squawka RSS Scraping

## ⚡ Quick Start

### Start Services
```bash
cd /Users/nikitaryzhikh/repos/n8n-stack
docker compose up -d
```

### Check Status
```bash
# Check Chrome
curl -s http://localhost:9222/json/version | jq '.'

# Check n8n logs
docker logs n8n-stack-n8n-1 --tail 20

# Check all services
docker compose ps
```

### Restart if Needed
```bash
docker compose restart chrome n8n
```

---

## 📋 n8n Code Node (Copy & Paste)

**Use this code in your n8n Code node:**

```javascript
const CDP = require('chrome-remote-interface');

const targetUrl = $input.first().json.url || 'https://www.squawka.com/en/news/feed';

try {
  const client = await CDP({ host: 'chrome', port: 9222 });
  const { Network, Page, Runtime } = client;
  
  await Network.enable();
  await Page.enable();
  
  // Stealth techniques
  await Page.addScriptToEvaluateOnNewDocument({
    source: `
      Object.defineProperty(navigator, 'webdriver', { get: () => false });
      window.chrome = { runtime: {} };
      const originalQuery = window.navigator.permissions.query;
      window.navigator.permissions.query = (params) => (
        params.name === 'notifications' 
          ? Promise.resolve({ state: Notification.permission })
          : originalQuery(params)
      );
      Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3] });
      Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
    `
  });
  
  await Network.setExtraHTTPHeaders({
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Referer': 'https://www.google.com/',
      'DNT': '1'
    }
  });
  
  await Page.navigate({ url: targetUrl });
  await Page.loadEventFired();
  
  // Wait for Cloudflare
  await new Promise(resolve => setTimeout(resolve, 8000));
  
  const result = await Runtime.evaluate({
    expression: 'document.documentElement.outerHTML'
  });
  
  const html = result.result.value;
  await client.close();
  
  const gotThrough = !html.includes('Cloudflare Ray ID');
  
  return [{
    json: {
      success: gotThrough,
      html,
      url: targetUrl,
      fetchedAt: new Date().toISOString()
    }
  }];
  
} catch (error) {
  throw new Error(`Chrome fetch failed: ${error.message}`);
}
```

---

## 🔍 Common Issues & Fixes

| Problem | Quick Fix |
|---------|-----------|
| "Cannot find module" | `docker compose build n8n && docker compose up -d` |
| "No inspectable targets" | `docker compose restart chrome` |
| "ECONNREFUSED" | `docker compose up -d chrome` |
| Still blocked by Cloudflare | Increase wait time to 15000ms |
| High memory usage | Restart chrome: `docker compose restart chrome` |

---

## 📊 Memory Usage (1GB VPS)

```
n8n:       ~200MB
postgres:  ~50MB
nocodb:    ~100MB
redis:     ~30MB
chrome:    ~200MB (during scrape)
caddy:     ~20MB
-----------------------
Total:     ~600MB
Available: ~400MB
```

✅ Safe for 1GB VPS

---

## ⏱️ Performance

- Request time: ~10-15 seconds
- Cloudflare wait: 8 seconds
- Total workflow: ~20 seconds
- Success rate: ✅ Confirmed working

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `n8n-chrome-stealth-working.js` | ✅ Working code |
| `IMPLEMENTATION-SUMMARY.md` | Full documentation |
| `FINAL-WORKING-SOLUTION.md` | Technical details |
| `CLOUDFLARE-BYPASS-GUIDE.md` | All solutions compared |
| `docker-compose.yaml` | Service configuration |
| `n8n.Dockerfile` | Custom n8n build |

---

## 🎯 n8n Workflow Example

```
[Schedule: */2 * * * *]
    ↓
[Set: url = "https://www.squawka.com/en/news/feed"]
    ↓
[Code: Chrome Scraper] ← Use code above
    ↓
[IF: success === true]
    ↓ TRUE              ↓ FALSE
[Parse XML]          [Log Error]
    ↓
[Split RSS Items]
    ↓
[Process Articles]
    ↓
[Save to DB]
```

---

## 🔧 Useful Commands

```bash
# View logs
docker compose logs -f chrome
docker compose logs -f n8n

# Restart specific service
docker compose restart chrome

# Check memory usage
docker stats --no-stream

# Rebuild after changes
docker compose build n8n
docker compose up -d

# Clean up
docker compose down
docker system prune -f
```

---

## 📞 Quick Links

- n8n: http://localhost:5678
- NocoDb: http://localhost:8080
- Adminer: http://localhost:8081
- Chrome Debug: http://localhost:9222

---

## ✅ Verified Working

- ✅ Squawka.com RSS feed
- ✅ Bypasses Cloudflare protection
- ✅ Returns full RSS XML
- ✅ Works on 1GB VPS
- ✅ Tested: October 28, 2025

---

**Need more details?** See `IMPLEMENTATION-SUMMARY.md`

**Having issues?** Check `FINAL-WORKING-SOLUTION.md` troubleshooting section

