import { expect, Page, test } from '@playwright/test';
import { randomUUID } from 'crypto';

// Parcours réels : accès réservé au visiteur, action enregistrée sur le serveur (inscription à un événement), menu du compte par rôle.
// Les comptes jetables sont créés par l'API d'authentification ; les supprimer ensuite (voir docs/final-audit/TESTS_ET_PREUVES.md).
const U = 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
const K = 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01';

type Compte = { email: string; password: string; id: string; role: string };

const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function creer(role: 'client' | 'student'): Promise<Compte> {
  const email = `zz-test-par-${randomUUID().slice(0, 8)}@example.com`;
  const password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const r = await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
  const d = await r.json();
  await fetch(`${U}/rest/v1/profiles`, {
    method: 'POST',
    headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: d.user.id, name: 'Test Parcours', email, role }),
  });
  return { email, password, id: d.user.id, role };
}

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

async function engagements(c: Compte): Promise<any[]> {
  const t = await (await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: c.email, password: c.password }) })).json();
  const r = await fetch(`${U}/rest/v1/engagements?select=kind,ref,status`, { headers: { apikey: K, Authorization: 'Bearer ' + t.access_token } });
  return r.json();
}

test.describe.configure({ mode: 'serial', timeout: 150_000 });

let client: Compte;
let etudiant: Compte;
test.beforeAll(async () => {
  client = await creer('client');
  etudiant = await creer('student');
});

test.describe('Parcours réels par rôle', () => {
  test('visiteur : « S\'inscrire » à un événement demande de se connecter, sans rien enregistrer', async ({ page }) => {
    await demarrer(page, 's/101');
    await page.mouse.click(195, 796);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Un compte est nécessaire');
    expect(await texte(page)).toContain('Plus tard'); // le visiteur peut renoncer et continuer à explorer
  });

  test('client connecté : l\'inscription est enregistrée sur le serveur, le doublon est annoncé', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/101');
    await page.mouse.click(195, 796);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Inscription enregistrée');
    const e = await engagements(client);
    expect(e.filter((x) => x.kind === 'event_registration' && x.status === 'active').length).toBe(1);
    await page.waitForTimeout(2500);
    await page.mouse.click(195, 796);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('déjà inscrit');
    expect((await engagements(client)).length).toBe(1);
  });

  test('client : le menu du compte propose ses achats et pas l\'espace vendeur', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/10');
    await page.mouse.click(338, 92); // ⋮ du profil
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Mon compte');
    const t = await texte(page);
    expect(t).toContain('Mes commandes');
    expect(t).toContain('Mes favoris');
    expect(t).not.toContain('Publier un service');
    expect(t).not.toContain('Administration globale');
  });

  test('étudiant-vendeur : le menu du compte propose aussi son espace vendeur', async ({ page }) => {
    await connecter(page, etudiant);
    await aller(page, 's/10');
    await page.mouse.click(338, 92);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Mon compte');
    await page.mouse.move(195, 500);
    await page.mouse.wheel(0, 700); // la liste est longue : on descend jusqu'au groupe vendeur
    await page.waitForTimeout(1500);
    const t = await texte(page);
    expect(t).toContain('Espace étudiant-vendeur');
    expect(t).toContain('Publier un service');
    expect(t).not.toContain('Administration globale');
  });

  test('le menu du compte ouvre réellement « Mes commandes » (liste du compte, sans historique fictif)', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/10');
    await page.mouse.click(338, 92);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Mes commandes');
    await page.getByText('Mes commandes', { exact: true }).first().click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('pas encore de commande'); // compte neuf : état vide, pas l'historique fictif
    const t = await texte(page);
    expect(t).not.toContain('8 commandes');
    expect(t).not.toContain('Support téléphone');
  });
});
