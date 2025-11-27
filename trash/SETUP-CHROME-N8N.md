# Setting Up Chrome Scraping in n8n

## 🚀 Quick Start Guide

### Step 1: Build Custom n8n Image

Your custom n8n image includes `chrome-remote-interface` and `puppeteer-core` for connecting to the Chrome service.

```bash
cd /Users/nikitaryzhikh/repos/n8n-stack
docker compose build n8n
docker compose up -d n8n
```

**Wait time**: ~2-3 minutes for build

---

### Step 2: Verify Installation

Check that n8n restarted successfully:

```bash
docker logs n8n-stack-n8n-1 --tail 20
```

Should see: `Editor is now accessible via: https://...`

---

### Step 3: Create n8n Workflow

#### Workflow Structure:

```
[Schedule Trigger] 
    → [Code Node: Fetch Protected RSS]
    → [XML Parser / RSS Parser]
    → [Process Items]
    → [Save to Database/API]
```

---

## 📝 Code Node Setup

### Method 1: chrome-remote-interface (Recommended)

**Pros:**
- ✅ Lightweight (~500 KB)
- ✅ Direct CDP access
- ✅ Faster connection
- ✅ Lower memory usage

**Code for n8n Code Node:**

```javascript
const CDP = require('chrome-remote-interface');

// Get URL from previous node or use default
const targetUrl = $input.first().json.url || 'https://www.squawka.com/en/news/feed';

try {
  const client = await CDP({
    host: 'chrome',
    port: 9222
  });

  const { Network, Page, Runtime } = client;

  await Network.enable();
  await Page.enable();
  await Page.navigate({ url: targetUrl });
  await Page.loadEventFired();
  
  // Wait for Cloudflare challenge (adjust as needed)
  await new Promise(resolve => setTimeout(resolve, 8000));

  const result = await Runtime.evaluate({
    expression: 'document.documentElement.outerHTML'
  });

  await client.close();

  return [{ json: { 
    html: result.result.value,
    url: targetUrl,
    fetchedAt: new Date().toISOString()
  }}];

} catch (error) {
  throw new Error(`Failed to fetch: ${error.message}`);
}
```

---

### Method 2: puppeteer-core (Alternative)

**Pros:**
- ✅ More familiar API
- ✅ Better documentation
- ✅ More control options

**Code for n8n Code Node:**

```javascript
const puppeteer = require('puppeteer-core');

const targetUrl = $input.first().json.url || 'https://www.squawka.com/en/news/feed';

try {
  // Get Chrome WebSocket endpoint
  const response = await fetch('http://chrome:9222/json/version');
  const versionInfo = await response.json();
  
  const browser = await puppeteer.connect({
    browserWSEndpoint: versionInfo.webSocketDebuggerUrl
  });

  const page = await browser.newPage();
  
  // Set realistic user agent
  await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  
  // Navigate with timeout
  await page.goto(targetUrl, { 
    waitUntil: 'networkidle0',
    timeout: 30000 
  });
  
  // Wait for Cloudflare
  await page.waitForTimeout(8000);
  
  const html = await page.content();
  
  await page.close();
  await browser.disconnect();
  
  return [{ json: { 
    html,
    url: targetUrl,
    fetchedAt: new Date().toISOString()
  }}];

} catch (error) {
  throw new Error(`Failed to fetch: ${error.message}`);
}
```

---

## 🔧 Complete Workflow Example

### 1. **Schedule Trigger**
```
Cron: 0 */2 * * *  (every 2 hours)
```

### 2. **Set Variable (Optional)**
```javascript
// Set URL to fetch
return [{ json: { 
  url: 'https://www.squawka.com/en/news/feed'
}}];
```

### 3. **Code Node: Fetch Protected Feed**
```javascript
// Use code from Method 1 or Method 2 above
```

### 4. **HTML Extract Node**
```
Mode: HTML Table
Selector: item, entry  (RSS feed items)
```

Or use **XML Node** if feed is XML:
```
Mode: Simplify
```

### 5. **Loop Over Items**
```javascript
// Process each RSS item
const items = $input.first().json;

return items.map(item => ({
  json: {
    title: item.title,
    link: item.link,
    content: item.description,
    pubDate: item.pubDate
  }
}));
```

### 6. **Save to Database**
Use HTTP Request, Postgres, or any other node to save data.

---

## 🐛 Troubleshooting

### Error: "Cannot find module 'chrome-remote-interface'"

**Solution:**
```bash
# Rebuild n8n image
docker compose build n8n
docker compose up -d n8n

# Verify installation
docker exec n8n-stack-n8n-1 npm list chrome-remote-interface
```

---

### Error: "connect ECONNREFUSED chrome:9222"

**Solution:**
```bash
# Check if Chrome is running
docker ps | grep chrome

# Check Chrome logs
docker logs n8n-stack-chrome-1

# Restart Chrome
docker compose restart chrome
```

---

### Error: "Navigation timeout" or "Page load timeout"

**Solutions:**
1. Increase timeout in code
2. Increase wait time after page load (Cloudflare challenge)
3. Check if site is actually accessible

```javascript
// Increase wait time
await new Promise(resolve => setTimeout(resolve, 15000));  // 15 seconds
```

---

### Cloudflare Still Blocking

**Solutions:**

1. **Add more realistic headers:**
```javascript
await page.setExtraHTTPHeaders({
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate, br',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
});
```

2. **Randomize user agent:**
```javascript
const userAgents = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
];
await page.setUserAgent(userAgents[Math.floor(Math.random() * userAgents.length)]);
```

3. **Add viewport:**
```javascript
await page.setViewport({ width: 1920, height: 1080 });
```

4. **Try external service** (Apify, ScrapingBee) as fallback

---

## 📊 Performance Tips

### 1. Reuse Chrome Connection (Advanced)

Instead of creating new connection each time, reuse existing browser:

```javascript
// Global variable (persistent across executions)
let globalBrowser;

if (!globalBrowser) {
  const response = await fetch('http://chrome:9222/json/version');
  const info = await response.json();
  globalBrowser = await puppeteer.connect({
    browserWSEndpoint: info.webSocketDebuggerUrl
  });
}

const page = await globalBrowser.newPage();
// ... your code ...
await page.close();  // Close page, not browser
```

### 2. Parallel Fetching

For multiple URLs, use Split in Batches node:

```
[Schedule] 
  → [Set URLs Array]
  → [Split in Batches: 2 items]
  → [Code Node: Fetch]
  → [Loop back or Continue]
```

### 3. Caching

Add caching to avoid repeated fetches:

```javascript
// Check if fetched recently
const lastFetch = $('Memory Node').first().json.lastFetch;
const now = Date.now();

if (lastFetch && (now - lastFetch) < 3600000) {  // 1 hour
  // Return cached data
  return [{ json: $('Memory Node').first().json }];
}

// Fetch fresh data...
```

---

## 🎯 Production Checklist

- [ ] Built custom n8n image with dependencies
- [ ] Tested Chrome connection works
- [ ] Workflow handles errors gracefully
- [ ] Added retry logic for failed fetches
- [ ] Set reasonable fetch intervals (not too frequent)
- [ ] Monitor memory usage (`docker stats`)
- [ ] Set up alerts for workflow failures
- [ ] Document which sites need Chrome vs HTTP

---

## 📚 Additional Resources

- **chrome-remote-interface docs**: https://github.com/cyrus-and/chrome-remote-interface
- **Puppeteer docs**: https://pptr.dev/
- **n8n Code node docs**: https://docs.n8n.io/code-examples/
- **Chrome DevTools Protocol**: https://chromedevtools.github.io/devtools-protocol/

---

## 🚀 Next Steps

1. Build and deploy: `docker compose build n8n && docker compose up -d`
2. Create test workflow in n8n
3. Test with Squawka feed
4. Add error handling and retries
5. Schedule regular fetches
6. Monitor memory and performance

