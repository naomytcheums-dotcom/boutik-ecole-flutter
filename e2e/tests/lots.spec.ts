import { expect, Page, test } from '@playwright/test';
import { execSync } from 'child_process';
import { randomUUID } from 'crypto';

// Lots « missions, vœux, certificats, états système, annulation avec motif » — ENVIRONNEMENT ISOLÉ UNIQUEMENT.
// Les rôles « dept » et l'approbation d'une annonce exigent le propriétaire de la base : ici, la base locale (docker).
// Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> BASE_URL=http://127.0.0.1:8099 npx playwright test lots --workers=1
const U = process.env.BE_URL ?? '';
const K = process.env.BE_KEY ?? '';
const DB = process.env.BE_DB ?? 'supabase_db_boutik_local';
const local = U.startsWith('http://127.0.0.1') || U.startsWith('http://localhost');

type Compte = { email: string; password: string; id: string };

const sql = (q: string) => execSync(`docker exec -i ${DB} psql -U postgres -t -A -q`, { input: q }).toString().trim();
const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function creer(role: string, staff?: string): Promise<Compte> {
  const email = `zz-test-lots-${randomUUID().slice(0, 8)}@example.com`;
  const password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const d = await (await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })).json();
  await fetch(`${U}/rest/v1/profiles`, {
    method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: d.user.id, name: 'Test ' + role, email, role }),
  });
  if (staff) sql(`update profiles set role = '${staff}' where id = '${d.user.id}';`);
  return { email, password, id: d.user.id };
}

async function jeton(c: Compte) {
  return (await (await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: c.email, password: c.password }) })).json()).access_token as string;
}

async function lire(c: Compte | null, chemin: string): Promise<any> {
  const h: Record<string, string> = { apikey: K };
  if (c) h.Authorization = 'Bearer ' + (await jeton(c));
  return (await fetch(`${U}/rest/v1/${chemin}`, { headers: h })).json();
}

async function rpc(c: Compte, fn: string, body: object): Promise<any> {
  const r = await fetch(`${U}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + (await jeton(c)), 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  return r.json();
}

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; e?.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
  await page.waitForTimeout(2500);
}

async function connecter(page: Page, c: Compte) {
  await demarrer(page, 's/11');
  const champs = page.locator('flt-semantics-host input');
  for (let essai = 0; essai < 3; essai++) {
    await champs.nth(0).fill(c.email);
    await page.waitForTimeout(500);
    await champs.nth(1).fill(c.password);
    await page.waitForTimeout(700);
    if ((await champs.nth(1).inputValue()) === c.password) break;
  }
  await page.mouse.click(198, 583);
  await expect.poll(() => texte(page), { timeout: 30_000 }).toContain('Bienvenue');
}

const aller = async (page: Page, hash: string) => {
  await page.evaluate((h) => (location.hash = '#/' + h), hash);
  await page.waitForTimeout(3000);
};

async function taper(page: Page, x: number, y: number, valeur: string) {
  await page.mouse.click(x, y);
  await page.waitForTimeout(400);
  await page.keyboard.type(valeur);
  await page.waitForTimeout(300);
}

/** Champ d'une fenêtre de dialogue : focus réel puis frappe (fill() n'atteint pas le contrôleur Flutter). */
async function remplir(page: Page, index: number, valeur: string) {
  const champ = page.locator('flt-semantics-host input, flt-semantics-host textarea').nth(index);
  await champ.click();
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(valeur);
  await page.waitForTimeout(300);
}

/** Ouvre le menu du compte et choisit une entrée (la liste est longue : on la fait défiler jusqu'à l'entrée). */
async function menu(page: Page, entree: string) {
  await aller(page, 's/10');
  await page.mouse.click(338, 92);
  await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Mon compte');
  await page.mouse.move(195, 500);
  for (let i = 0; i < 25 && !(await texte(page)).includes(entree); i++) {
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(350);
  }
  await page.getByText(entree, { exact: true }).first().click();
  await page.waitForTimeout(1500);
}

test.describe.configure({ mode: 'serial', timeout: 180_000 });
test.skip(!local, 'Base locale isolée requise (BE_URL=http://127.0.0.1:54321)');

let entreprise: Compte, talent: Compte, dept: Compte, acheteur: Compte;
const besoin = 'Suivi clients ' + randomUUID().slice(0, 6);
test.beforeAll(async () => {
  if (!local) return;
  entreprise = await creer('company');
  talent = await creer('student');
  dept = await creer('client', 'dept');
  acheteur = await creer('client');
});

test.describe('Missions, vœux, certificats, états système, annulation (base isolée)', () => {
  test('entreprise : publier un besoin (écran 90) l’enregistre sur le serveur', async ({ page }) => {
    await connecter(page, entreprise);
    await aller(page, 's/90');
    await taper(page, 195, 232, besoin);
    await taper(page, 195, 420, 'Une application web pour suivre les clients et leurs commandes.');
    await page.mouse.click(284, 787);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Besoin publié');
    const m = await lire(entreprise, `missions?select=title,status,budget_min,budget_max&title=eq.${encodeURIComponent(besoin)}`);
    expect(m).toEqual([{ title: besoin, status: 'published', budget_min: 300000, budget_max: 500000 }]);
  });

  test('talent : « Besoins à pourvoir » permet de proposer un montant et un délai', async ({ page }) => {
    await connecter(page, talent);
    await menu(page, 'Besoins à pourvoir');
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain(besoin);
    await page.getByRole('button', { name: 'Proposer' }).first().click();
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Ma proposition');
    await remplir(page, 0, '400000');
    await remplir(page, 1, '14');
    await remplir(page, 2, 'Équipe de deux développeurs');
    await page.getByRole('button', { name: 'Envoyer' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Proposition envoyée');
    const p = await lire(talent, 'mission_proposals?select=amount,delay_days,status');
    expect(p).toEqual([{ amount: 400000, delay_days: 14, status: 'submitted' }]);
  });

  test('entreprise : « Accepter » (écran 93b) attribue la mission et crée les jalons', async ({ page }) => {
    await connecter(page, entreprise);
    await aller(page, 's/93b');
    await page.mouse.click(284, 787);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('400 000 FCFA');
    await page.getByRole('button', { name: 'Accepter' }).first().click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Proposition acceptée');
    const m = await lire(entreprise, `missions?select=status,total&title=eq.${encodeURIComponent(besoin)}`);
    expect(m).toEqual([{ status: 'assigned', total: 400000 }]);
    expect((await lire(talent, 'mission_milestones?select=position')).length).toBe(3);
  });

  test('vœu : l’étudiant l’envoie (218), le département le valide, il devient public', async ({ page, browser }) => {
    await connecter(page, talent);
    await aller(page, 's/218');
    await page.mouse.click(284, 787);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Vœu envoyé');
    const w = await lire(talent, `wishes?select=id,status&author_id=eq.${talent.id}`);
    expect(w.map((x: any) => x.status)).toEqual(['submitted']);
    expect(await lire(null, `wishes?select=id&id=eq.${w[0].id}`)).toEqual([]); // pas encore public

    const p2 = await (await browser.newContext({ viewport: { width: 390, height: 844 } })).newPage();
    await connecter(p2, dept);
    await menu(p2, 'Vœux à valider');
    await expect.poll(() => texte(p2), { timeout: 15_000 }).toContain('Lampe en bois recyclé');
    await p2.getByRole('button', { name: 'Valider' }).first().click();
    await expect.poll(() => texte(p2), { timeout: 15_000 }).toContain('Décision enregistrée');
    expect(await lire(null, `wishes?select=status&id=eq.${w[0].id}`)).toEqual([{ status: 'approved' }]);
  });

  test('certificat : émis par le département, vérifié publiquement sans compte', async ({ page, browser }) => {
    await connecter(page, dept);
    await menu(page, 'Émettre un certificat');
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Émettre un certificat');
    await remplir(page, 0, 'talent');
    await remplir(page, 1, 'Développeur web');
    await remplir(page, 2, talent.email);
    await remplir(page, 4, 'GI');
    await page.getByRole('button', { name: 'Émettre' }).click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Certificat émis');
    const code = (await texte(page)).match(/BE-CERT-[0-9A-F]{16}/)![0];

    const visiteur = await (await browser.newContext({ viewport: { width: 390, height: 960 } })).newPage();
    await demarrer(visiteur, 's/211');
    await visiteur.mouse.click(195, 873); // « Voir le certificat »
    await expect.poll(() => texte(visiteur), { timeout: 10_000 }).toContain('Vérifier un certificat');
    await remplir(visiteur, 0, code);
    await visiteur.getByRole('button', { name: 'Vérifier' }).click();
    await expect.poll(() => texte(visiteur), { timeout: 15_000 }).toContain('Certificat authentique');
    expect(await texte(visiteur)).toContain('Développeur web');
  });

  test('états système : coupure réseau → « Connexion impossible », retour → « Connexion rétablie »', async ({ page }) => {
    await demarrer(page, 's/03');
    await page.context().setOffline(true);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Connexion impossible');
    await page.mouse.click(195, 489); // « Réessayer » alors que le réseau est toujours coupé : on reste hors ligne
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Toujours hors ligne');
    await page.context().setOffline(false);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Connexion rétablie');
    await expect.poll(() => texte(page), { timeout: 10_000 }).not.toContain('Connexion impossible');
  });

  test('annulation avec motif : détail de commande (29) → écran 47 → commande annulée, motif enregistré', async ({ page }) => {
    const titre = 'zz-test-lampe-' + randomUUID().slice(0, 6);
    const vend = await fetch(`${U}/rest/v1/listings`, {
      method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + (await jeton(talent)), 'Content-Type': 'application/json', Prefer: 'return=representation' },
      body: JSON.stringify({ title: titre, department: 'Génie civil', category: 'Maison', price: 25000, stock: 5, status: 'pending' }),
    });
    expect(vend.status).toBe(201);
    sql(`update listings set status = 'approved' where title = '${titre}';`);
    const o = await rpc(acheteur, 'create_order', { p_items: [{ title: titre, qty: 1 }], p_home: false, p_method: 'Orange Money' });
    expect(o.number).toMatch(/^#BE-/);

    await connecter(page, acheteur);
    await page.waitForTimeout(3000);
    await aller(page, 's/29');
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain(o.number);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Annuler la commande');
    await page.mouse.click(301, 667);
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain('Motif de l’annulation');
    await page.mouse.click(195, 284); // « Délai de livraison trop long »
    await page.waitForTimeout(500);
    await page.mouse.click(284, 787);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Commande annulée');
    expect(await lire(acheteur, `orders?select=cancelled&number=eq.${encodeURIComponent(o.number)}`)).toEqual([{ cancelled: true }]);
    expect(await lire(acheteur, 'order_cancellations?select=reason')).toEqual([{ reason: 'too_slow' }]);
  });
});
