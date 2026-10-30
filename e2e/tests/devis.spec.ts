import { expect, Page, test } from '@playwright/test';
import fs from 'fs';

// Parcours réel services → demande de devis → réponse du prestataire → acceptation, avec trois comptes jetables.
// Préparation : `python supabase/tests/quotes_rest.py 1`, approbation du service par le propriétaire de la base,
// puis `STATE=<fichier> npx playwright test devis`. Sans STATE, ces tests sont ignorés.
const STATE = process.env.STATE;
const S = STATE && fs.existsSync(STATE) ? JSON.parse(fs.readFileSync(STATE, 'utf8')) : null;
const U = 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
const K = 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01';

type Compte = { email: string; password: string };

const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; e?.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
  await page.waitForTimeout(2500);
}

async function connecter(page: Page, c: Compte) {
  await demarrer(page, 's/11');
  const champs = page.locator('flt-semantics-host input');
  await champs.nth(0).fill(c.email);
  await page.waitForTimeout(600);
  await champs.nth(1).fill(c.password);
  await page.waitForTimeout(600);
  await page.mouse.click(198, 583);
  await expect.poll(() => texte(page), { timeout: 30_000 }).toContain('Bienvenue');
}

const aller = async (page: Page, hash: string) => {
  await page.evaluate((h) => (location.hash = '#/' + h), hash);
  await page.waitForTimeout(2500);
};

async function saisir(page: Page, index: number, valeur: string) {
  const champ = page.locator('flt-semantics-host textarea, flt-semantics-host input').nth(index);
  await champ.click();
  await page.waitForTimeout(400);
  await champ.fill(valeur);
  await page.waitForTimeout(400);
}

async function jeton(c: Compte): Promise<string> {
  const r = await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify(c) });
  return (await r.json()).access_token;
}

async function lire(c: Compte, chemin: string): Promise<any[]> {
  const r = await fetch(U + '/rest/v1/' + chemin, { headers: { apikey: K, Authorization: 'Bearer ' + (await jeton(c)) } });
  return r.json();
}

test.describe.configure({ mode: 'serial' });
test.skip(!S, 'STATE non fourni : comptes jetables absents');

test.describe('Services et devis (comptes réels)', () => {
  test('la liste des services montre le service publié et le catalogue produits ne le contient pas', async ({ page }) => {
    await connecter(page, S.C);
    await aller(page, 's/22b');
    const t = await texte(page);
    expect(t).toContain(S.title);
    expect(t).toContain('À partir de 30 000 FCFA');
    await aller(page, 's/22');
    expect(await texte(page)).not.toContain(S.title);
  });

  test('la fiche service affiche le titre et le prix du service', async ({ page }) => {
    await connecter(page, S.C);
    await aller(page, 's/22b');
    await page.mouse.click(198, 233); // première ligne
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Détail du service');
    const t = await texte(page);
    expect(t).toContain(S.title);
    expect(t).toContain('À partir de 30 000 FCFA');
    expect(t).not.toContain('Mariam Essono'); // maquette fictive absente
  });

  test('le demandeur envoie une demande de devis depuis la fiche', async ({ page }) => {
    await connecter(page, S.C);
    await aller(page, 's/22b');
    await page.mouse.click(198, 233);
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Détail du service');
    await page.mouse.move(195, 400);
    await page.mouse.wheel(0, 600); // la fiche dépasse l'écran : on descend jusqu'à la barre d'actions
    await page.waitForTimeout(1200);
    await page.mouse.click(105, 787); // « Demander un devis »
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Demande de devis');
    await saisir(page, 1, 'Site vitrine de cinq pages avec formulaire de contact.');
    await page.mouse.click(198, 787); // « Envoyer la demande »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Demande envoyée');
    const q = await lire(S.C, 'quote_requests?select=status,brief');
    expect(q.length).toBe(1);
    expect(q[0].status).toBe('requested');
  });

  test('le prestataire répond avec un devis depuis son tableau de bord', async ({ page }) => {
    await connecter(page, S.A);
    await aller(page, 's/57');
    await page.mouse.click(283, 737); // « Demandes de devis ›»
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('devis');
    await page.getByRole('button', { name: /Répondre avec un devis|Modifier mon devis/ }).first().click();
    const champs = page.locator('flt-semantics-host input, flt-semantics-host textarea');
    await champs.nth(0).click(); await page.keyboard.press('Control+A'); await page.keyboard.type('70000');
    await champs.nth(1).click(); await page.keyboard.press('Control+A'); await page.keyboard.type('10');
    await page.getByRole('button', { name: 'Envoyer le devis' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Devis envoyé');
    const q = await lire(S.A, 'quote_requests?select=status,quote_amount&order=created_at.desc');
    expect(q[0].status).toBe('quoted');
    expect(q[0].quote_amount).toBe(70000);
  });

  test('le demandeur accepte le devis reçu', async ({ page }) => {
    await connecter(page, S.C);
    await aller(page, 's/22b');
    await page.mouse.click(335, 177); // « Mes devis »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Accepter');
    await page.getByRole('button', { name: 'Accepter' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Devis accepté');
    const q = await lire(S.C, 'quote_requests?select=status&order=created_at.desc');
    expect(q[0].status).toBe('accepted');
    const n = await lire(S.A, 'notifications?select=title&kind=eq.quote');
    expect(n.map((x) => x.title)).toContain('Devis accepté');
  });
});
