/**
 * n8n Code Node Example: Fetch Cloudflare-protected RSS feed using Chrome
 * 
 * This uses the lightweight Chrome service via Chrome DevTools Protocol
 * Memory usage: ~100-200MB when active
 * 
 * Usage: Create a Code node in n8n and paste this code
 */

const CDP = require('chrome-remote-interface');

// URL to scrape
const targetUrl = 'https://www.squawka.com/en/news/feed';

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

  // Wait for page to load (adjust timeout as needed)
  await Page.loadEventFired();
  
  // Wait additional time for JS to execute (for Cloudflare challenge)
  await new Promise(resolve => setTimeout(resolve, 5000));

  // Get page content
  const result = await Runtime.evaluate({
    expression: 'document.documentElement.outerHTML'
  });

  const html = result.result.value;

  // Close the connection
  await client.close();

  // Return the HTML content
  return [{ json: { html, url: targetUrl } }];

} catch (error) {
  throw new Error(`Failed to fetch page: ${error.message}`);
}

