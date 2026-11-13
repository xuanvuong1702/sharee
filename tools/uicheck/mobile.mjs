import puppeteer from 'puppeteer-core';

const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const browser = await puppeteer.launch({
  executablePath: edge,
  headless: 'new',
  args: ['--no-sandbox', '--disable-gpu'],
});
const page = await browser.newPage();
await page.setViewport({ width: 800, height: 900, deviceScaleFactor: 1 });
await page.goto('http://localhost:8081', { waitUntil: 'networkidle0' });
await new Promise((r) => setTimeout(r, 4500));

// Demo passenger login.
await page.mouse.click(300, 500);
await new Promise((r) => setTimeout(r, 2600));
await page.mouse.click(400, 500);
await new Promise((r) => setTimeout(r, 4500));
await page.screenshot({ path: 'mobile-home.png' });

// Search -> results -> detail.
await page.mouse.click(400, 289);
await new Promise((r) => setTimeout(r, 5000));
await page.screenshot({ path: 'mobile-results.png' });
await page.mouse.click(400, 300);
await new Promise((r) => setTimeout(r, 3500));
await page.screenshot({ path: 'mobile-detail.png' });

console.log('mobile OK');
await browser.close();
