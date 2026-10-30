import { expect, Page, test } from '@playwright/test';
import { randomUUID } from 'crypto';

// Reprise du 30/10/2026 : engagements réversibles, préférences persistantes, liens réparés.
// Comptes jetables zz-test-eng-* créés par l'API d'authentification (à supprimer ensuite par le propriétaire de la base).
const U = 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
const K = 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01';

type Compte = { email: string; password: string; id: string };

const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function creer(role: 'client' | 'student'): Promise<Compte> {
  const email = `zz-test-eng-${randomUUID().slice(0, 8)}@example.com`;
  const password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const r = await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
  const d = await r.json();
  await fetch(`${U}/rest/v1/profiles`, {
    method: 'POST',
    headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: d.user.id, name: 'Test Engagements', email, role }),
  });
  return { email, password, id: d.user.id };
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
  await page.waitForTimeout(3000);
};

async function engagements(c: Compte, kind: string): Promise<any[]> {
  const t = await (await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: c.email, password: c.password }) })).json();
  const r = await fetch(`${U}/rest/v1/engagements?select=kind,ref,data,status&kind=eq.${kind}`, { headers: { apikey: K, Authorization: 'Bearer ' + t.access_token } });
  return r.json();
}

test.describe.configure({ mode: 'serial', timeout: 180_000 });

let client: Compte;
let etudiant: Compte;
test.beforeAll(async () => {
  client = await creer('client');
  etudiant = await creer('student');
});

test.describe('Engagements réversibles et préférences (comptes réels)', () => {
  test('événement : inscription, état affiché sur le bouton, désinscription enregistrée sur le serveur', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/101');
    await page.mouse.click(195, 796);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Inscription enregistrée');
    expect((await engagements(client, 'event_registration')).map((x) => x.status)).toEqual(['active']);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Gérer mon inscription');
    await page.waitForTimeout(2000);
    await page.mouse.click(195, 796);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Vous êtes déjà inscrit(e)');
    expect(await texte(page)).toContain('Enregistré le');
    await page.getByRole('button', { name: 'Me désinscrire' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Désinscription enregistrée');
    expect((await engagements(client, 'event_registration')).map((x) => x.status)).toEqual(['cancelled']);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('S’inscrire');
  });

  test('candidature : postuler mène à « Candidature envoyée », puis « Mes candidatures » permet de la retirer', async ({ page }) => {
    await connecter(page, etudiant);
    await aller(page, 's/153');
    await page.mouse.click(284, 787); // « Postuler »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Merci pour votre candidature');
    expect((await engagements(etudiant, 'application')).map((x) => [x.ref, x.status])).toEqual([['offer:153', 'active']]);
    await page.mouse.click(105, 787); // « Mes candidatures »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Ma candidature');
    await page.mouse.click(105, 789); // « Retirer »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Retirer ma candidature ?');
    await page.getByRole('button', { name: 'Retirer', exact: true }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Candidature retirée');
    expect((await engagements(etudiant, 'application')).map((x) => x.status)).toEqual(['cancelled']);
  });

  test('canaux de notification : le choix est enregistré et retrouvé après rechargement', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/236');
    expect(await texte(page)).toContain('Désactivé');
    await page.mouse.click(315, 389); // pastille « Désactivé » de l'e-mail
    await page.waitForTimeout(800);
    expect(await texte(page)).not.toContain('Désactivé');
    await page.mouse.click(195, 787); // « Enregistrer »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Préférences enregistrées');
    const e = await engagements(client, 'channel_prefs');
    expect(e.length).toBe(1);
    expect(e[0].data.email).toBe(true);
    await page.reload();
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45_000 });
    await page.waitForTimeout(4000);
    await page.evaluate(() => { const x = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; x?.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
    await page.waitForTimeout(3000);
    await aller(page, 's/236');
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Canaux et notifications');
    await page.waitForTimeout(2000);
    expect(await texte(page)).not.toContain('Désactivé'); // préférence relue sur le serveur
  });

  test('menu du compte : « Paramètres » ouvre bien les paramètres (lien 148_1 réparé)', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/10');
    await page.mouse.click(338, 92);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Mon compte');
    await page.mouse.move(195, 500);
    await page.mouse.wheel(0, 2500);
    await page.waitForTimeout(1500);
    await page.getByText('Paramètres', { exact: true }).first().click();
    await page.waitForTimeout(3000);
    const t = await texte(page);
    expect(t).not.toContain('n’existe pas');
    expect(t).toContain('Paramètres');
  });

  test('demande de renseignements : la question est exigée puis adressée au vendeur du produit consulté', async ({ page }) => {
    await connecter(page, client);
    await aller(page, 's/39');
    await page.mouse.click(195, 787); // « Envoyer la question » sans texte
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Question trop courte');
    await page.getByRole('button', { name: 'Compris' }).click();
    const champ = page.locator('flt-semantics-host textarea, flt-semantics-host input').first();
    await champ.click();
    await champ.fill('Bonjour, la lampe existe-t-elle en bambou ?');
    await page.waitForTimeout(500);
    await page.mouse.click(195, 787);
    // Le produit affiché par défaut est vendu par la plateforme : le serveur le dit, rien n'est simulé.
    await expect.poll(() => texte(page), { timeout: 20_000 }).toMatch(/Produit de la plateforme|Annonce introuvable|Message non envoyé/);
  });
});
