/**
 * Working Stealth Chrome for n8n - Using chrome-remote-interface
 * No puppeteer compatibility issues!
 */

const CDP = require('chrome-remote-interface');

const targetUrl = $input.first().json.url || 'https://www.squawka.com/en/news/feed';

try {
  // Create a new target (tab)
  const targetInfo = await CDP.New({
    host: 'chrome',
    port: 9222,
    url: 'about:blank'
  });

  // Connect to the new target
  const client = await CDP({
    host: 'chrome',
    port: 9222,
    target: targetInfo.id
  });

  const { Network, Page, Runtime, Emulation } = client;

  // Enable necessary domains
  await Network.enable();
  await Page.enable();
  await Runtime.enable();

  // === STEALTH TECHNIQUES ===

  // 1. Set realistic user agent
  await Network.setUserAgentOverride({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    acceptLanguage: 'en-US,en;q=0.9',
    platform: 'Win32'
  });

  // 2. Set device metrics (viewport)
  await Emulation.setDeviceMetricsOverride({
    width: 1920,
    height: 1080,
    deviceScaleFactor: 1,
    mobile: false
  });

  // 3. Hide automation - inject script before any page loads
  await Page.addScriptToEvaluateOnNewDocument({
    source: `
      // Remove webdriver property
      Object.defineProperty(navigator, 'webdriver', {
        get: () => false
      });
      
      // Add chrome object
      window.chrome = {
        runtime: {},
        loadTimes: function() {},
        csi: function() {},
        app: {}
      };
      
      // Fix permissions
      const originalQuery = window.navigator.permissions.query;
      window.navigator.permissions.query = (parameters) => (
        parameters.name === 'notifications' ?
          Promise.resolve({ state: Notification.permission }) :
          originalQuery(parameters)
      );
      
      // Fix plugins to look like real Chrome
      Object.defineProperty(navigator, 'plugins', {
        get: () => [
          {
            0: {type: "application/x-google-chrome-pdf", suffixes: "pdf", description: "Portable Document Format"},
            description: "Portable Document Format",
            filename: "internal-pdf-viewer",
            length: 1,
            name: "Chrome PDF Plugin"
          }
        ]
      });
      
      // Fix languages
      Object.defineProperty(navigator, 'languages', {
        get: () => ['en-US', 'en']
      });
      
      // Override toString to hide modifications
      const oldCall = Function.prototype.call;
      function call() {
        return oldCall.apply(this, arguments);
      }
      Function.prototype.call = call;
      
      const nativeToStringFunctionString = Error.toString().replace(/Error/g, "toString");
      const oldToString = Function.prototype.toString;
      
      function functionToString() {
        if (this === window.navigator.permissions.query) {
          return "function query() { [native code] }";
        }
        if (this === functionToString) {
          return nativeToStringFunctionString;
        }
        return oldCall.call(oldToString, this);
      }
      Function.prototype.toString = functionToString;
    `
  });

  // 4. Set extra headers
  await Network.setExtraHTTPHeaders({
    headers: {
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': 'https://www.google.com/',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Cache-Control': 'max-age=0'
    }
  });

  // 5. Navigate to the page
  console.log('Navigating to:', targetUrl);
  await Page.navigate({ url: targetUrl });

  // Wait for page to load
  await Page.loadEventFired();
  console.log('Page loaded');

  // 6. Wait for Cloudflare challenge (15 seconds)
  await new Promise(resolve => setTimeout(resolve, 15000));
  console.log('Waited 15 seconds for Cloudflare');

  // 7. Check if still on Cloudflare page
  let checkResult = await Runtime.evaluate({
    expression: 'document.title'
  });
  
  const title = checkResult.result.value;
  
  if (title && (title.includes('Attention Required') || title.includes('Cloudflare'))) {
    console.log('Still on Cloudflare page, waiting another 10 seconds...');
    await new Promise(resolve => setTimeout(resolve, 10000));
  }

  // 8. Simulate human behavior - scroll
  await Runtime.evaluate({
    expression: 'window.scrollBy(0, 100);'
  });
  
  await new Promise(resolve => setTimeout(resolve, 1000));

  // 9. Get final page content
  const result = await Runtime.evaluate({
    expression: 'document.documentElement.outerHTML'
  });

  const html = result.result.value;

  // Get final title and URL
  const finalTitleResult = await Runtime.evaluate({
    expression: 'document.title'
  });
  const finalTitle = finalTitleResult.result.value;

  const finalUrlResult = await Runtime.evaluate({
    expression: 'window.location.href'
  });
  const finalUrl = finalUrlResult.result.value;

  // Close the connection
  await client.close();

  // Close the target (tab) to free memory
  await CDP.Close({
    host: 'chrome',
    port: 9222,
    id: targetInfo.id
  });

  // Check if we got through Cloudflare
  const gotThrough = !html.includes('Cloudflare Ray ID') && 
                     !html.includes('cf-wrapper') &&
                     !html.includes('cf-error-details');

  console.log('Success:', gotThrough);

  return [{ json: {
    success: gotThrough,
    html: html,
    title: finalTitle,
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

