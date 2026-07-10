const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  page.on('console', msg => console.log('PAGE LOG:', msg.type(), msg.text()));
  page.on('pageerror', error => console.log('PAGE ERROR:', error.message));
  
  page.on('response', async response => {
    if (response.status() === 400) {
      console.log(`400 ERROR URL: ${response.url()}`);
      try {
        const text = await response.text();
        console.log(`400 ERROR BODY: ${text}`);
      } catch (e) {
        console.log(`Could not read body for ${response.url()}`);
      }
    }
  });

  console.log('Navigating to http://localhost:5174/pos');
  await page.goto('http://localhost:5174/pos', { waitUntil: 'networkidle' });
  
  console.log('Page loaded. Waiting for 3 seconds...');
  await page.waitForTimeout(3000);
  
  await page.screenshot({ path: 'screenshot.png' });
  console.log('Screenshot saved to screenshot.png');
  
  await browser.close();
})();
