import { expect, Page, test } from '@playwright/test';
import { randomUUID } from 'crypto';

// Production AVANT application de la migration 20261031a : les nouvelles actions ne simulent rien, elles annoncent
// que la fonction serveur n'est pas encore activée. Le test s'ignore de lui-même dès que la migration est appliquée.
const U = process.env.BE_URL ?? 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
const K = process.env.BE_KEY ?? 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01';

const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function migrationAbsente(): Promise<boolean> {
  const r = await fetch(`${U}/rest/v1/rpc/verify_certificate`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_code: 'BE-CERT-00000000' }) });
  return r.status === 404;
}

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; e?.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
  await page.waitForTimeout(2500);
}

test.describe.configure({ mode: 'serial', timeout: 150_000 });

test('avant migration : publier un vœu annonce une fonction non activée, sans rien simuler', async ({ page }) => {
  test.skip(!(await migrationAbsente()), 'migration 20261031a déjà appliquée');
  const email = `zz-test-prod-${randomUUID().slice(0, 8)}@example.com`, password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const d = await (await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })).json();
  await fetch(`${U}/rest/v1/profiles`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' }, body: JSON.stringify({ id: d.user.id, name: 'Test Prod', email, role: 'student' }) });
  await demarrer(page, 's/11');
  const champs = page.locator('flt-semantics-host input');
  await champs.nth(0).fill(email);
  await page.waitForTimeout(500);
  await champs.nth(1).fill(password);
  await page.waitForTimeout(700);
  await page.mouse.click(198, 583);
  await expect.poll(() => texte(page), { timeout: 30_000 }).toContain('Bienvenue');
  await page.evaluate(() => (location.hash = '#/s/218'));
  await page.waitForTimeout(3000);
  await page.mouse.click(284, 787); // « Publier »
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('pas encore activée');
  expect(await texte(page)).not.toContain('Vœu envoyé');
});

test('avant migration : la vérification publique d’un certificat ne prétend rien', async ({ page }) => {
  test.skip(!(await migrationAbsente()), 'migration 20261031a déjà appliquée');
  await page.setViewportSize({ width: 390, height: 960 });
  await demarrer(page, 's/211');
  await page.mouse.click(195, 873);
  await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Vérifier un certificat');
  await page.getByRole('button', { name: 'Vérifier' }).click();
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('pas encore activée');
  expect(await texte(page)).not.toContain('Certificat authentique');
});
