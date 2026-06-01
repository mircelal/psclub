import { chromium } from 'playwright';

const url = process.argv[2] || 'https://ps.sayt.cam/#/login';
const logs = [];

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

page.on('console', (msg) => logs.push(`[console.${msg.type()}] ${msg.text()}`));
page.on('pageerror', (err) => logs.push(`[pageerror] ${err.message}`));
page.on('requestfailed', (req) => {
  logs.push(`[requestfailed] ${req.method()} ${req.url()} — ${req.failure()?.errorText}`);
});
page.on('response', async (res) => {
  const u = res.url();
  if (u.includes('psapi.sayt.cam/api')) {
    logs.push(`[api ${res.status()}] ${res.request().method()} ${u.split('?')[0]}`);
  }
});

console.log('Opening', url);
try {
  await page.goto(url, { waitUntil: 'load', timeout: 45000 });
} catch (e) {
  logs.push(`[goto-error] ${e.message}`);
}

for (let i = 1; i <= 8; i++) {
  await page.waitForTimeout(2000);
  const state = await page.evaluate(() => ({
    flutterView: !!document.querySelector('flutter-view'),
    fltGlass: !!document.querySelector('flt-glass-pane'),
    canvas: document.querySelectorAll('canvas').length,
    bodyChildren: document.body?.children?.length ?? 0,
  }));
  logs.push(`[t+${i * 2}s] dom ${JSON.stringify(state)}`);
}

const jsMarkers = await page.evaluate(async () => {
  try {
    const r = await fetch('/main.dart.js', { cache: 'no-store' });
    const t = await r.text();
    return {
      ok: r.ok,
      publicConfig: t.includes('/public/config'),
      ignorePointer: /IgnorePointer|ignorePointer/i.test(t),
      length: t.length,
    };
  } catch (e) {
    return { error: String(e) };
  }
});
logs.push(`[bundle] ${JSON.stringify(jsMarkers)}`);

await page.screenshot({ path: 'c:/laragon/www/psclub/dist/web-debug.png' });

console.log('\n--- LOG ---');
logs.forEach((l) => console.log(l));
await browser.close();
