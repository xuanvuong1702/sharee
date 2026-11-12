import puppeteer from 'puppeteer-core';

const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const browser = await puppeteer.launch({ executablePath: edge, headless: 'new', args: ['--no-sandbox', '--disable-gpu'] });
const page = await browser.newPage();
await page.setViewport({ width: 800, height: 900 });
await page.goto('http://localhost:8081', { waitUntil: 'networkidle0' });
await new Promise((r) => setTimeout(r, 5000));
await page.mouse.click(400, 336);
await new Promise((r) => setTimeout(r, 2500));
await page.mouse.click(400, 370);
await new Promise((r) => setTimeout(r, 4000));
await page.mouse.click(400, 299);
await new Promise((r) => setTimeout(r, 5000));
await page.screenshot({ path: 'mobile-final.png' });
console.log('mobile OK');
await browser.close();
