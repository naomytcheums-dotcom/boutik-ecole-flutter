import { expect, Page, test } from '@playwright/test';
import { createHmac, randomUUID } from 'crypto';

// Écran 272 « Vérification en 2 étapes » : activation réelle d'une application d'authentification (TOTP) depuis l'interface.
// Ne dépend d'aucune migration : exécutable en production (compte jetable zz-test-mfa-*) comme sur la base isolée.
const U = process.env.BE_URL ?? 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
const K = process.env.BE_KEY ?? 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01';

const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

function totp(secret: string): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of secret.toUpperCase().replace(/=+$/, '')) bits += alphabet.indexOf(c).toString(2).padStart(5, '0');
  const key = Buffer.from(bits.match(/.{8}/g)!.map((b) => parseInt(b, 2)));
  const msg = Buffer.alloc(8);
  msg.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 1000 / 30)));
  const h = createHmac('sha1', key).update(msg).digest();
  const o = h[h.length - 1] & 0x0f;
  return ((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).toString().padStart(6, '0');
}

async function remplir(page: Page, index: number, valeur: string) {
  const champ = page.locator('flt-semantics-host input, flt-semantics-host textarea').nth(index);
  await champ.click();
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(valeur);
  await page.waitForTimeout(300);
}

test('vérification en 2 étapes (272) : QR code, code faux refusé, code exact accepté, facteur enregistré', async ({ page }) => {
  test.setTimeout(150_000);
  const email = `zz-test-mfa-${randomUUID().slice(0, 8)}@example.com`, password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const d = await (await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })).json();
  await fetch(`${U}/rest/v1/profiles`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' }, body: JSON.stringify({ id: d.user.id, name: 'Test MFA', email, role: 'client' }) });

  await page.goto('/#/s/11');
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
  await page.waitForTimeout(2500);
  const champs = page.locator('flt-semantics-host input');
  for (let i = 0; i < 3; i++) {
    await champs.nth(0).fill(email);
    await page.waitForTimeout(500);
    await champs.nth(1).fill(password);
    await page.waitForTimeout(700);
    if ((await champs.nth(1).inputValue()) === password) break;
  }
  await page.mouse.click(198, 583);
  await expect.poll(() => texte(page), { timeout: 30_000 }).toContain('Bienvenue');

  await page.evaluate(() => (location.hash = '#/s/272'));
  await page.waitForTimeout(3000);
  await page.mouse.click(195, 796); // « Vérifier »
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Scannez ce code');
  const secret = (await texte(page)).match(/Clé : ([A-Z2-7]{16,})/)![1];
  await page.getByRole('button', { name: 'J’ai ajouté le compte' }).click();
  await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('pour activer la protection');
  await remplir(page, 0, totp(secret) === '000000' ? '111111' : '000000');
  await page.getByRole('button', { name: 'Vérifier' }).last().click();
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Code incorrect');
  await page.getByRole('button', { name: 'Compris' }).click();

  // le même facteur reste à vérifier : la fenêtre de saisie revient
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('pour activer la protection');
  await remplir(page, 0, totp(secret));
  await page.getByRole('button', { name: 'Vérifier' }).last().click();
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Vérification en 2 étapes active');

  const t = await (await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })).json();
  const u = await (await fetch(`${U}/auth/v1/user`, { headers: { apikey: K, Authorization: 'Bearer ' + t.access_token } })).json();
  expect((u.factors ?? []).filter((f: any) => f.factor_type === 'totp' && f.status === 'verified').length).toBe(1);
});
