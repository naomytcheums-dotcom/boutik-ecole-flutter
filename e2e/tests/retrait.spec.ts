import { expect, Page, Request, test } from '@playwright/test';
import { execSync } from 'child_process';
import { randomUUID } from 'crypto';

// Écran de retrait au kiosque (146-2) : aucune issue autre que la réponse « delivered » du serveur ne doit afficher
// « Remise confirmée ». ENVIRONNEMENT ISOLÉ UNIQUEMENT (rôle support et paiement posés par SQL local, aucune écriture en production).
// Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> BASE_URL=http://127.0.0.1:8099 npx playwright test retrait --workers=1
const U = process.env.BE_URL ?? '';
const K = process.env.BE_KEY ?? '';
const DB = process.env.BE_DB ?? 'supabase_db_boutik_local';
const local = U.startsWith('http://127.0.0.1') || U.startsWith('http://localhost');
// RETRAIT_SOFT=1 : toutes les étapes s'exécutent et chaque écart est listé (pour comparer deux versions de l'écran).
const v = process.env.RETRAIT_SOFT ? expect.configure({ soft: true }) : expect;

type Compte = { email: string; password: string; id: string };
const sql = (q: string) => execSync(`docker exec -i ${DB} psql -U postgres -t -A -q`, { input: q }).toString().trim();
const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function creer(role: string, staff?: string): Promise<Compte> {
  const email = `zz-test-ret-${randomUUID().slice(0, 8)}@example.com`, password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const d = await (await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })).json();
  await fetch(`${U}/rest/v1/profiles`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' }, body: JSON.stringify({ id: d.user.id, name: 'Test ' + role, email, role }) });
  if (staff) sql(`update profiles set role = '${staff}' where id = '${d.user.id}';`);
  return { email, password, id: d.user.id };
}
const jeton = async (c: Compte) => (await (await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: c.email, password: c.password }) })).json()).access_token as string;
async function rpc(c: Compte, fn: string, body: object): Promise<any> {
  return (await fetch(`${U}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + (await jeton(c)), 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json();
}
async function commandePayee(acheteur: Compte): Promise<string> {
  const titre = sql("select title from listings where status='approved' and stock > 0 and category <> 'Services' limit 1;");
  const o = await rpc(acheteur, 'create_order', { p_items: [{ title: titre, qty: 1 }], p_home: false, p_method: 'Orange Money' });
  sql(`update orders set paid = true where number = '${o.number}';`); // mise en place locale : paiement confirmé
  return o.number;
}
const etat = (n: string) => sql(`select pickup_attempts || ',' || status || ',' || (picked_up_at is not null) from orders where number = '${n}';`);

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
  await page.waitForTimeout(2500);
}
async function connecter(page: Page, c: Compte) {
  await demarrer(page, 's/11');
  const champs = page.locator('flt-semantics-host input');
  for (let i = 0; i < 3; i++) {
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
async function remplir(page: Page, index: number, valeur: string) {
  const champ = page.locator('flt-semantics-host input, flt-semantics-host textarea').nth(index);
  await champ.click();
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(valeur);
  await page.waitForTimeout(300);
}
// Ouvre « Confirmer la remise », saisit numéro et code, valide.
async function confirmer(k: Page, numero: string, code: string) {
  await k.mouse.click(195, 658);
  await expect.poll(() => texte(k), { timeout: 10_000 }).toContain('Confirmer la remise Annuler');
  await remplir(k, 0, numero);
  await remplir(k, 1, code);
  await k.getByRole('button', { name: 'Confirmer' }).last().click();
}
async function fermer(k: Page) {
  const b = k.getByRole('button', { name: 'Compris' });
  if (await b.count()) await b.click();
  await k.waitForTimeout(800);
}
// Tout texte affiché, même brièvement (notification éphémère), est mémorisé par la page toutes les 100 ms.
const ECHANTILLONNEUR = () => {
  const w = window as any;
  w.__vus = new Set<string>();
  setInterval(() => { const t = (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText; if (t) w.__vus.add(t.replace(/\s+/g, ' ')); }, 100);
};
const vus = async (k: Page) => (await k.evaluate(() => [...((window as any).__vus ?? [])].join(' | '))) as string;
const oublier = (k: Page) => k.evaluate(() => (window as any).__vus?.clear());
const faux = (vrai: string) => (vrai === '000000' ? '111111' : '000000');
const CORS = { 'access-control-allow-origin': '*', 'content-type': 'application/json' };
const RPC = '**/rest/v1/rpc/confirm_pickup*';

test.describe.configure({ mode: 'serial', timeout: 420_000 });
test.skip(!local, 'Base locale isolée requise (BE_URL=http://127.0.0.1:54321)');

test('écran de retrait (146-2) : seule la réponse « delivered » affiche « Remise confirmée »', async ({ page: k }) => {
  const acheteur = await creer('client');
  const support = await creer('client', 'support');
  const numero = await commandePayee(acheteur);
  const premier = String(await rpc(acheteur, 'my_pickup_code', { p_number: numero }));
  expect(premier).toMatch(/^\d{6}$/);
  await k.addInitScript(ECHANTILLONNEUR);
  const envois: Request[] = [];
  k.on('request', (r) => { if (r.url().includes('/rpc/confirm_pickup') && r.method() === 'POST') envois.push(r); });

  await connecter(k, support);
  await aller(k, 's/146-2');

  await test.step('1. code erroné : « Code de retrait incorrect », essai compté et journalisé, aucune remise', async () => {
    await oublier(k);
    await confirmer(k, numero, faux(premier));
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Code de retrait incorrect');
    v(await vus(k)).not.toContain('Remise confirmée');
    v(etat(numero)).toBe('1,0,false');
    v(sql(`select count(*) from audit_log where action = 'Code de retrait erroné' and target = '${numero}';`)).toBe('1');
    await fermer(k);
  });

  for (const status of [401, 403, 500]) {
    await test.step(`6. réponse HTTP ${status} : refus affiché, jamais de succès, aucune remise`, async () => {
      await oublier(k);
      await k.route(RPC, (r) => r.fulfill({ status, headers: CORS, body: JSON.stringify({ code: String(status), message: `erreur simulée ${status}`, details: null, hint: null }) }));
      await confirmer(k, numero, premier);
      await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Remise refusée');
      v(await vus(k)).not.toContain('Remise confirmée');
      await k.unroute(RPC);
      await fermer(k);
      v(etat(numero)).toBe('1,0,false');
    });
  }

  await test.step('5a. erreur réseau : refus affiché, jamais de succès', async () => {
    await oublier(k);
    await k.route(RPC, (r) => r.abort('failed'));
    await confirmer(k, numero, premier);
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Remise refusée');
    v(await vus(k)).not.toContain('Remise confirmée');
    await k.unroute(RPC);
    await fermer(k);
    v(etat(numero)).toBe('1,0,false');
  });

  for (const corps of ['null', '"ok"', 'true']) {
    await test.step(`2. réponse positive inattendue (${corps}) : jamais « Remise confirmée »`, async () => {
      await oublier(k);
      await k.route(RPC, (r) => r.fulfill({ status: 200, headers: CORS, body: corps }));
      await confirmer(k, numero, premier);
      await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Remise non confirmée');
      v(await vus(k)).not.toContain('Remise confirmée');
      await k.unroute(RPC);
      await fermer(k);
    });
  }

  await test.step('5b. délai dépassé (serveur muet) : message explicite, la remise n’est PAS confirmée', async () => {
    await oublier(k);
    let fini: Promise<void> = Promise.resolve();
    await k.route(RPC, async (r) => { fini = (async () => { await new Promise((ok) => setTimeout(ok, 26_000)); await r.abort('timedout').catch(() => {}); })(); await fini; });
    await confirmer(k, numero, premier);
    await v.poll(() => texte(k), { timeout: 30_000 }).toContain('n’a pas répondu à temps');
    v(await vus(k)).not.toContain('Remise confirmée');
    await fermer(k);
    await fini; // la requête interceptée est abandonnée avant de retirer l'interception (sinon elle partirait vers le serveur)
    await k.unroute(RPC);
    v(etat(numero)).toBe('1,0,false');
  });

  await test.step('7a. soumission répétée pendant l’attente : refusée par l’écran, un seul envoi', async () => {
    await oublier(k);
    await k.route(RPC, async (r) => { await new Promise((ok) => setTimeout(ok, 5_000)); await r.continue(); });
    const avant = envois.length;
    await confirmer(k, numero, faux(premier));
    await k.waitForTimeout(800);
    await k.mouse.click(195, 658); // nouvelle tentative pendant que la première est en cours
    await v.poll(() => texte(k), { timeout: 5_000 }).toContain('déjà en cours');
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Code de retrait incorrect');
    v(envois.length - avant).toBe(1);
    await k.unroute(RPC);
    await fermer(k);
    v(etat(numero)).toBe('2,0,false');
  });

  await test.step('3. cinq essais erronés : blocage annoncé, même le bon code est refusé', async () => {
    await oublier(k);
    for (let i = 0; i < 3; i++) v(await rpc(support, 'confirm_pickup', { p_number: numero, p_code: faux(premier) })).toBe('incorrect');
    v(etat(numero)).toBe('5,0,false');
    await confirmer(k, numero, premier);
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Trop d\'essais');
    v(await vus(k)).not.toContain('Remise confirmée');
    await fermer(k);
    v(etat(numero)).toBe('5,0,false');
  });

  const second = String(await rpc(acheteur, 'my_pickup_code', { p_number: numero }));
  await test.step('4. code remplacé : l’ancien code est refusé, sans succès', async () => {
    await oublier(k);
    expect(second).toMatch(/^\d{6}$/);
    v(etat(numero)).toBe('0,0,false'); // nouveau code, compteur remis à zéro
    test.skip(second === premier, 'nouveau code identique à l’ancien (probabilité 1/1 000 000)');
    await confirmer(k, numero, premier);
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Code de retrait incorrect');
    v(await vus(k)).not.toContain('Remise confirmée');
    await fermer(k);
  });

  await test.step('2. bon code : « Remise confirmée » uniquement après la réponse « delivered »', async () => {
    await oublier(k);
    let reponse = '';
    k.on('response', async (r) => { if (r.url().includes('/rpc/confirm_pickup') && r.request().method() === 'POST') reponse = await r.text().catch(() => ''); });
    await confirmer(k, numero, second);
    await v.poll(() => vus(k), { timeout: 15_000 }).toContain('Remise confirmée');
    v(reponse).toBe('"delivered"');
    v(etat(numero).split(',').slice(1).join(',')).toBe('3,true');
  });

  const retireLe = sql(`select picked_up_at from orders where number = '${numero}';`);
  await test.step('8. actualisation après le retrait : état conservé, nouvelle remise refusée, code plus délivré', async () => {
    await oublier(k);
    await k.reload();
    await demarrer(k, 's/03');
    await aller(k, 's/146-2');
    // sans « Se souvenir de moi », l'actualisation ferme la session (choix de l'application) : l'écran du personnel n'est plus accessible
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Page introuvable');
    await connecter(k, support);
    await aller(k, 's/146-2');
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Confirmer la remise');
    await confirmer(k, numero, second);
    await v.poll(() => texte(k), { timeout: 15_000 }).toContain('Commande déjà remise');
    v(await vus(k)).not.toContain('Remise confirmée');
    await fermer(k);
    v(sql(`select picked_up_at from orders where number = '${numero}';`)).toBe(retireLe);
    v(JSON.stringify(await rpc(acheteur, 'my_pickup_code', { p_number: numero }))).toContain('déjà retirée');
    v(sql(`select count(*) from notifications where user_id = '${acheteur.id}' and title = 'Commande retirée';`)).toBe('1');
  });

  await test.step('7b. deux confirmations simultanées du bon code : une seule remise (garantie serveur)', async () => {
    await oublier(k);
    const autre = await commandePayee(acheteur);
    const code = String(await rpc(acheteur, 'my_pickup_code', { p_number: autre }));
    const r = await Promise.all([1, 2, 3].map(() => rpc(support, 'confirm_pickup', { p_number: autre, p_code: code })));
    v(r.filter((x) => x === 'delivered').length).toBe(1);
    v(r.filter((x) => JSON.stringify(x).includes('déjà remise')).length).toBe(2);
    v(sql(`select count(*) from notifications where user_id = '${acheteur.id}' and title = 'Commande retirée';`)).toBe('2');
  });
});
