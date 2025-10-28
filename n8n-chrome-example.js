/**
 * n8n Code Node Example: Fetch Cloudflare-protected RSS feed using Chrome
 * 
 * METHOD 1: Using chrome-remote-interface (Lightweight, Best for your setup)
 * Memory usage: ~100-200MB when active
 * 
 * Prerequisites:
 * 1. Build custom n8n image: docker compose build n8n
 * 2. Restart n8n: docker compose up -d n8n
 * 3. Create a Code node in n8n and paste this code
 */

// ===== METHOD 1: chrome-remote-interface (Recommended) =====
const CDP = require('chrome-remote-interface');

// Get URL from input or use default
const targetUrl = $input.first().json.url || 'https://www.squawka.com/en/news/feed';

try {
  // Connect to Chrome via WebSocket
  const client = await CDP({
    host: 'chrome',
    port: 9222
  });

  const { Network, Page, Runtime } = client;

  // Enable necessary domains
  await Network.enable();
  await Page.enable();

  // Navigate to the page
  await Page.navigate({ url: targetUrl });

  // Wait for page to load
  await Page.loadEventFired();
  
  // Wait additional time for JS to execute (Cloudflare challenge)
  await new Promise(resolve => setTimeout(resolve, 8000));

  // Get page content
  const result = await Runtime.evaluate({
    expression: 'document.documentElement.outerHTML'
  });

  const html = result.result.value;

  // Close the connection
  await client.close();

  // Return the HTML content
  return [{ json: { html, url: targetUrl, fetchedAt: new Date().toISOString() } }];

} catch (error) {
  throw new Error(`Failed to fetch page: ${error.message}`);
}


// ===== METHOD 2: puppeteer-core (Alternative) =====
/*
const puppeteer = require('puppeteer-core');

const targetUrl = $input.first().json.url || 'https://www.squawka.com/en/news/feed';

try {
  // Connect to Chrome via WebSocket
  const browser = await puppeteer.connect({
    browserWSEndpoint: 'ws://chrome:9222/devtools/browser',
  });

  const page = await browser.newPage();
  
  // Set user agent to avoid detection
  await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  
  // Navigate to the page
  await page.goto(targetUrl, { 
    waitUntil: 'networkidle0',
    timeout: 30000 
  });
  
  // Wait for Cloudflare challenge
  await page.waitForTimeout(8000);
  
  // Get page content
  const html = await page.content();
  
  // Close page and browser
  await page.close();
  await browser.disconnect();
  
  return [{ json: { html, url: targetUrl, fetchedAt: new Date().toISOString() } }];

} catch (error) {
  throw new Error(`Failed to fetch page: ${error.message}`);
}
*/

