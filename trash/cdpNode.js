async function fetchMultipleWithCdp(urlItems) {
    let client, targetInfo;
    
    try {
      // ====== 1. CREATE TAB ONCE ======
      targetInfo = await CDP.New({
        host: 'chrome',
        port: 9222,
        url: 'about:blank'
      });
      
      client = await CDP({
        host: 'chrome',
        port: 9222,
        target: targetInfo.id
      });
      
      const { Network, Page, Runtime, Emulation } = client;
      
      // ====== 2. SETUP ONCE ======
      await Network.enable();
      await Page.enable();
      await Runtime.enable();
      
      await Network.setUserAgentOverride({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        acceptLanguage: 'en-US,en;q=0.9',
        platform: 'Win32'
      });
      
      await Emulation.setDeviceMetricsOverride({
        width: 1920,
        height: 1080,
        deviceScaleFactor: 1,
        mobile: false
      });
      
      await Page.addScriptToEvaluateOnNewDocument({
        source: `
          Object.defineProperty(navigator, 'webdriver', { get: () => false });
          window.chrome = { runtime: {}, loadTimes: () => {}, csi: () => {}, app: {} };
          Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
        `
      });
      
      await Network.setExtraHTTPHeaders({
        headers: {
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Referer': 'https://www.google.com/',
          'DNT': '1'
        }
      });
      
      // ====== 3. ADAPTIVE FETCHING ======
      const results = [];
      const hostFirstVisit = new Map(); // Track first visit per host
      
      for (const [index, item] of urlItems.entries()) {
        try {
          const host = new URL(item.url).hostname;
          const isFirstVisit = !hostFirstVisit.has(host);
          
          if (isFirstVisit) {
            console.log(`First visit to ${host} - using longer wait`);
            hostFirstVisit.set(host, true);
          }
          
          // Navigate
          await Page.navigate({ url: item.url });
          await Page.loadEventFired();
          
          // ADAPTIVE WAIT:
          // - First visit: 3-5 seconds (bot detection, JS challenges)
          // - Subsequent: 500-1000ms (just dynamic content)
          const waitTime = isFirstVisit ? 3000 : 500;
          await new Promise(resolve => setTimeout(resolve, waitTime));
          
          // Optional: Check if page is actually ready
          const isReady = await Runtime.evaluate({
            expression: 'document.readyState === "complete"'
          });
          
          if (!isReady.result.value && !isFirstVisit) {
            // Page not ready, wait a bit more
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
          
          // Extract content
          const [htmlRes, titleRes, urlRes] = await Promise.all([
            Runtime.evaluate({ expression: 'document.documentElement.outerHTML' }),
            Runtime.evaluate({ expression: 'document.title' }),
            Runtime.evaluate({ expression: 'window.location.href' })
          ]);
          
          results.push({
            success: true,
            html: htmlRes.result.value,
            title: titleRes.result.value,
            url: urlRes.result.value,
            originalUrl: item.url,
            originalData: item.originalData,
            fetchedAt: new Date().toISOString(),
            isFirstVisit
          });
          
          // Small delay between requests (polite scraping)
          if (index < urlItems.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 500));
          }
          
        } catch (error) {
          results.push({
            success: false,
            error: error.message,
            url: item.url,
            originalData: item.originalData
          });
        }
      }
      
      return results;
      
    } finally {
      if (client) await client.close().catch(() => {});
      if (targetInfo) {
        await CDP.Close({ host: 'chrome', port: 9222, id: targetInfo.id }).catch(() => {});
      }
    }
  }


  const CDP = require('chrome-remote-interface');

const url = $json.link
const result = await fetchWithCdp(url)
return {
  json: {
    ...$json,
    data: result.html
    }
}


async function fetchWithCdp(url) {
  try {
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
  
    const { Network, Page, Runtime, Emulation } = client;
  
    // Enable necessary domains
    await Network.enable();
    await Page.enable();
    await Runtime.enable();

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
  
    // Navigate to the page
    await Page.navigate({ url });
  
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
  
    return {
      success: true,
      html: html,
      title: title,
      url: finalUrl,
      originalUrl: url,
      fetchedAt: new Date().toISOString()
    }

  } catch (error) {
    return {
      success: false,
      error: error.message,
      stack: error.stack,
      url: url
    }
  }
}