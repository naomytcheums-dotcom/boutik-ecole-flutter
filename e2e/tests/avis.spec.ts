import { expect, Page, test } from '@playwright/test';
import fs from 'fs';

// Parcours réel avis → réclamation → réponse → signalement, avec trois comptes jetables (vendeur A, acheteur B, tiers C).
// Préparation (hors navigateur) : `python supabase/tests/feedback_rest.py 1`, approbation et paiement simulés par le propriétaire
// de la base, puis `STATE=<fichier> npx playwright test avis`. Sans STATE, ces tests sont ignorés.
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

// Connexion par le vrai écran « Bon retour ! » (e-mail + mot de passe), puis navigation interne (sans recharger la page).
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

test.describe('Avis, réclamations et signalements (comptes réels)', () => {
  test('l\'acheteur voit sa commande réelle (et non l\'historique de démonstration)', async ({ page }) => {
    await connecter(page, S.B);
    await aller(page, 's/45');
    const t = await texte(page);
    expect(t).toContain(S.order);
    expect(t).not.toContain('Support téléphone'); // article de l'historique fictif
  });

  test('l\'acheteur publie un avis vérifié', async ({ page }) => {
    await connecter(page, S.B);
    await aller(page, 's/30');
    await page.mouse.click(198, 502); // « Évaluer la commande »
    await expect(page.getByText('Évaluer votre commande').first()).toBeVisible();
    expect(await texte(page)).toContain(S.title);
    await page.getByRole('button', { name: 'Publier mon avis' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Votre avis a été publié');
    const avis = await lire(S.B, 'reviews?select=rating,comment');
    expect(avis.length).toBe(1);
    expect(avis[0].rating).toBe(5);
  });

  test('un second avis sur le même article est refusé avec un message clair', async ({ page }) => {
    await connecter(page, S.B);
    await aller(page, 's/30');
    await page.mouse.click(198, 502);
    await page.getByRole('button', { name: 'Publier mon avis' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('déjà évalué');
  });

  test('l\'acheteur dépose une réclamation, le motif choisi est enregistré', async ({ page }) => {
    await connecter(page, S.B);
    await aller(page, 's/48');
    await page.mouse.click(200, 285); // « Article endommagé ou non conforme »
    await page.locator('flt-semantics-host textarea, flt-semantics-host input').first().fill('Article endommagé à la réception, voir photos.');
    await page.mouse.click(198, 787); // « Envoyer la demande »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Réclamation envoyée');
    const r = await lire(S.B, 'claims?select=reason,status,details');
    expect(r.length).toBe(1);
    expect(r[0].reason).toBe('damaged');
    expect(r[0].status).toBe('open');
  });

  test('une réclamation trop courte est refusée avant envoi', async ({ page }) => {
    await connecter(page, S.B);
    await aller(page, 's/48');
    await page.mouse.click(198, 787);
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('10 caractères');
  });

  test('le vendeur trouve la réclamation depuis son tableau de bord et répond', async ({ page }) => {
    await connecter(page, S.A);
    await aller(page, 's/57');
    expect(await texte(page)).toContain('Réclamations de mes acheteurs');
    await page.mouse.click(198, 737);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Article endommagé');
    await page.getByRole('button', { name: 'Répondre' }).click();
    await page.locator('flt-semantics-host textarea, flt-semantics-host input').first().fill('Nous vous remboursons ou échangeons l\'article.');
    await page.getByRole('button', { name: 'Envoyer' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Réponse envoyée');
    const r = await lire(S.A, 'claims?select=status,answer');
    expect(r[0].status).toBe('answered');
  });

  test('l\'acheteur voit la réponse et la notification', async ({ page }) => {
    await connecter(page, S.B);
    const n = await lire(S.B, 'notifications?select=title&kind=eq.claim');
    expect(n.map((x) => x.title)).toContain('Réponse à votre réclamation');
    const r = await lire(S.B, 'claims?select=status,answer');
    expect(r[0].answer).toContain('échangeons');
  });

  test('la note moyenne apparaît dans le catalogue et sur la fiche produit', async ({ page }) => {
    await connecter(page, S.C);
    await aller(page, 's/22');
    const cat = await texte(page);
    expect(cat).toContain(S.title);
    expect(cat).toContain('5.0 (1)');
    await page.mouse.click(90, 300); // première carte : l'annonce de test
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('(1 avis)');
  });

  test('un tiers signale l\'annonce depuis la fiche produit, une seule fois', async ({ page }) => {
    await connecter(page, S.C);
    await aller(page, 's/22');
    await page.mouse.click(90, 300);
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain(S.title);
    await page.mouse.click(330, 408); // lien « Signaler »
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Signaler une annonce');
    await page.mouse.click(200, 285); // « Photos ou description non conformes »
    await page.mouse.click(284, 787); // « Envoyer le signalement »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Signalement envoyé');
    const r = await lire(S.C, 'listing_reports?select=reason');
    expect(r.length).toBe(1);
    expect(r[0].reason).toBe('copied');
  });
});
