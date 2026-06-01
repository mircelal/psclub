import { chromium } from 'playwright';

const url = process.argv[2] || 'https://ps.sayt.cam/#/login';
const logs = [];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });

page.on('console', (msg) => {
  const t = msg.text();
  if (msg.type() === 'error' || msg.type() === 'warning' || t.includes('401') || t.includes('Exception') || t.includes('Circular')) {
    logs.push(`[${msg.type()}] ${t}`);
  }
});
page.on('pageerror', (err) => logs.push(`[pageerror] ${err.message}`));

const apiCalls = [];
page.on('response', (res) => {
  const u = res.url();
  if (u.includes('/api/')) apiCalls.push(`${res.status()} ${res.request().method()} ${u.replace('https://psapi.sayt.cam', '')}`);
});

await page.goto(url, { waitUntil: 'load', timeout: 60000 });
await page.waitForTimeout(15000);

// Flutter web: click center (login card area)
await page.mouse.click(640, 400);
await page.waitForTimeout(500);
await page.keyboard.type('admin');
await page.waitForTimeout(300);
await page.keyboard.press('Tab');
await page.waitForTimeout(300);
await page.keyboard.type('admin');
await page.waitForTimeout(500);
await page.keyboard.press('Enter');
await page.waitForTimeout(8000);

const hash = await page.evaluate(() => location.hash);
logs.push(`[hash after login attempt] ${hash}`);

console.log('URL:', url);
console.log('API calls:', [...new Set(apiCalls)].join('\n  '));
console.log('Issues:', logs.length ? logs.join('\n') : '(none captured)');

await browser.close();
