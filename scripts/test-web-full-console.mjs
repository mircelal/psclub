import { chromium } from 'playwright';

const url = process.argv[2] || 'https://ps.sayt.cam/#/login';
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });

const lines = [];
page.on('console', (msg) => lines.push(`[${msg.type()}] ${msg.text()}`));
page.on('pageerror', (e) => lines.push(`[PAGEERROR] ${e.message}`));

await page.goto(url, { waitUntil: 'load', timeout: 45000 });
await page.waitForTimeout(20000);

// dump last 40 lines only if too many
console.log('=== ALL CONSOLE (last 50) ===');
lines.slice(-50).forEach((l) => console.log(l));

const errors = lines.filter((l) =>
  /error|401|Circular|Exception|memory|OOM|failed/i.test(l)
);
console.log('\n=== FILTERED ERRORS ===');
errors.forEach((l) => console.log(l));

await browser.close();
