import { expect, Page, test } from '@playwright/test';

// Authentification sur le site en ligne SANS modifier aucun compte : identifiants inexistants (domaine réservé .invalid).
// Le refus vient du vrai serveur d'authentification ; aucune session n'est ouverte, aucun journal applicatif n'est écrit
// (le journal d'audit n'est alimenté que pour un utilisateur connecté).
// Usage : BASE_URL=https://boutik-ecole.vercel.app npx playwright test connexion_en_ligne --workers=1
const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
  await page.waitForTimeout(2500);
}

test('connexion refusée pour des identifiants inexistants, aucune session, écran du personnel inaccessible', async ({ page }) => {
  const erreursJs: string[] = [];
  page.on('pageerror', (e) => erreursJs.push(String(e).slice(0, 200)));
  const auth: number[] = [];
  page.on('response', (r) => { if (r.url().includes('/auth/v1/token')) auth.push(r.status()); });

  await demarrer(page, 's/11');
  const champs = page.locator('flt-semantics-host input');
  const email = `inexistant-${Date.now()}@example.invalid`, mdp = 'Mot-de-passe-faux-1!';
  for (let i = 0; i < 3; i++) {
    await champs.nth(0).fill(email);
    await page.waitForTimeout(500);
    await champs.nth(1).fill(mdp);
    await page.waitForTimeout(700);
    if ((await champs.nth(1).inputValue()) === mdp) break;
  }
  await page.mouse.click(198, 583);
  await expect.poll(() => texte(page), { timeout: 30_000 }).toContain('Identifiant ou mot de passe incorrect');
  expect(await texte(page)).not.toContain('Bienvenue');
  expect(auth).toEqual([400]); // refus du vrai serveur d'authentification
  const session = await page.evaluate(() => Object.keys(localStorage).filter((k) => /auth-token|supabase/i.test(k) && (localStorage.getItem(k) ?? '').includes('access_token')));
  expect(session).toEqual([]);

  await page.evaluate(() => (location.hash = '#/s/146-2'));
  await page.waitForTimeout(3000);
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Page introuvable');
  expect(await texte(page)).not.toContain('Confirmer la remise');
  expect(erreursJs).toEqual([]);
});
