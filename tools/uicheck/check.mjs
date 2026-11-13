import puppeteer from 'puppeteer-core';

const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const browser = await puppeteer.launch({ executablePath: edge, headless: 'new', args: ['--no-sandbox', '--disable-gpu'] });
const page = await browser.newPage();
await page.setViewport({ width: 1400, height: 900 });
await page.goto('http://localhost:3000', { waitUntil: 'networkidle0' });

await page.click('button.primary');
await page.waitForSelector('input[maxlength="6"]', { timeout: 15000 });
await page.click('button.primary');
await page.waitForFunction(() => document.body.innerText.includes('Tổng quan'), { timeout: 20000 });
await new Promise((r) => setTimeout(r, 600));
await page.screenshot({ path: 'admin-dashboard.png', fullPage: true });

const clicked = await page.evaluate(() => {
  const buttons = [...document.querySelectorAll('button.nav')];
  const target = buttons.find((b) => b.textContent.includes('Daily'));
  if (target) { target.click(); return true; }
  return false;
});
if (clicked) {
  await new Promise((r) => setTimeout(r, 1500));
  await page.screenshot({ path: 'admin-daily.png', fullPage: true });
  console.log('ADMIN DAILY OK');
} else {
  console.log('DAILY NAV NOT FOUND');
}
await browser.close();
