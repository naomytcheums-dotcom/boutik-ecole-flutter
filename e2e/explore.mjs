import { chromium } from '@playwright/test';
import fs from 'fs';

const S = JSON.parse(fs.readFileSync(process.env.STATE, 'utf8'));
const who = process.argv[2] || 'B';
const hash = process.argv[3] || '#/s/30';
const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await (await b.newContext({ viewport: { width: 390, height: 844 } })).newPage();
const sess = JSON.stringify(S[who].session);
await page.addInitScript(([k, v, k2, v2]) => { localStorage.setItem(k, v); localStorage.setItem(k2, v2); }, ['flutter.sb-zxqcnmgwhtbxkdpjqtlr-auth-token', JSON.stringify(sess), 'flutter.boutik_remember_email', JSON.stringify(S[who].email)]);
page.on('request', r => { if (r.url().includes('supabase.co')) console.log('REQ', r.method(), r.url().slice(36, 110)); });
await page.goto('https://boutik-ecole.vercel.app/#/' + hash);
await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45000 });
await page.waitForTimeout(4000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
await page.waitForTimeout(3000);
console.log((await page.evaluate(() => document.querySelector('flt-semantics-host')?.innerText ?? '')).replace(/\s+/g, ' ').slice(0, 600));
console.log(await page.evaluate(() => Object.keys(localStorage).join(',')));
if (process.argv[4]) {
  const [x, y] = process.argv[4].split(',').map(Number);
  await page.mouse.click(x, y);
  await page.waitForTimeout(3500);
  console.log('APRES:', (await page.evaluate(() => document.querySelector('flt-semantics-host')?.innerText ?? '')).replace(/\s+/g, ' ').slice(0, 700));
}
await page.screenshot({ path: 'results/explore.png' });
await b.close();
