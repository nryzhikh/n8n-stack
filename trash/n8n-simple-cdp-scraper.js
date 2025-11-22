/**
 * Simple CDP HTML Scraper for n8n
 * For regular websites without anti-bot protection
 */

const CDP = require('chrome-remote-interface');

const targetUrl = $input.first().json.url || 'https://example.com';

try {
  // Create a new tab
  const targetInfo = await CDP.New({
    host: 'chrome',
    port: 9222,
    url: 'about:blank'
  });

  // Connect to the tab
  const client = await CDP({
    host: 'chrome',
    port: 9222,
    target: targetInfo.id
  });

  const { Network, Page, Runtime } = client;

  // Enable necessary domains
  await Network.enable();
  await Page.enable();
  await Runtime.enable();

  // Navigate to the page
  await Page.navigate({ url: targetUrl });

  // Wait for page to load
  await Page.loadEventFired();

  // Optional: Wait a bit for dynamic content (adjust as needed)
  await new Promise(resolve => setTimeout(resolve, 2000));

  // Get the HTML content
  const result = await Runtime.evaluate({
    expression: 'document.documentElement.outerHTML'
  });

  const html = result.result.value;

  // Get page title
  const titleResult = await Runtime.evaluate({
    expression: 'document.title'
  });
  const title = titleResult.result.value;

  // Get final URL (in case of redirects)
  const urlResult = await Runtime.evaluate({
    expression: 'window.location.href'
  });
  const finalUrl = urlResult.result.value;

  // Close connection
  await client.close();

  // Close the tab to free memory
  await CDP.Close({
    host: 'chrome',
    port: 9222,
    id: targetInfo.id
  });

  return [{ json: {
    success: true,
    html: html,
    title: title,
    url: finalUrl,
    originalUrl: targetUrl,
    fetchedAt: new Date().toISOString()
  }}];

} catch (error) {
  console.error('Error:', error.message);
  return [{ json: {
    success: false,
    error: error.message,
    stack: error.stack,
    url: targetUrl
  }}];
}

