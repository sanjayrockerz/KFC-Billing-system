const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  page.on('console', msg => {
    console.log(`PAGE LOG: ${msg.type()} ${msg.text()}`);
  });
  
  page.on('pageerror', err => {
    console.error(`PAGE ERROR: ${err.message}`);
  });

  await page.setViewportSize({ width: 1440, height: 900 });
  console.log("Navigating to http://localhost:5174/dashboard");
  await page.goto('http://localhost:5174/dashboard', { waitUntil: 'networkidle' });
  
  // Fill in customer details
  console.log('Filling customer details...');
  await page.fill('input[placeholder="Enter name (optional)"]', 'John Doe');
  await page.fill('input[placeholder="9876543210 or +91 9876543210"]', '9876543210');
  
  // Add an item manually since catalogue search needs mock data
  // Wait for the buttons to be ready
  await page.waitForTimeout(2000);
  console.log('Clicking Add Custom Item...');
  await page.click('button:has-text("Add Custom Item")');
  console.log('Waiting for modal input...');
  await page.waitForSelector('input[placeholder="Item Name / Description"]');
  await page.fill('input[placeholder="Item Name / Description"]', 'Custom Product');
  await page.fill('input[placeholder="0"]', '100'); // Price
  await page.click('button:has-text("Add Item")');
  console.log('Item added');
  
  // Cash Payment
  console.log('Filling cash...');
  await page.fill('input[placeholder="0.00"]', '100');
  
  // Click complete sale
  console.log('Clicking Complete Sale');
  await page.click('button:has-text("Complete Sale")');
  
  // Wait a moment for network response
  await page.waitForTimeout(2000);
  
  await page.screenshot({ path: 'checkout_error.png' });
  console.log("Screenshot saved to checkout_error.png");
  
  await browser.close();
})();
