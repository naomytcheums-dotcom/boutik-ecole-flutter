import { expect, Page, test } from '@playwright/test';
import { execSync } from 'child_process';
import { randomUUID } from 'crypto';

// 16 dernières actions (migration 20261031b) — ENVIRONNEMENT ISOLÉ UNIQUEMENT (rôles du personnel et paiement posés par SQL local).
// Usage : BE_URL=http://127.0.0.1:54321 BE_KEY=<publishable locale> BASE_URL=http://127.0.0.1:8099 npx playwright test lots2 --workers=1
const U = process.env.BE_URL ?? '';
const K = process.env.BE_KEY ?? '';
const DB = process.env.BE_DB ?? 'supabase_db_boutik_local';
const local = U.startsWith('http://127.0.0.1') || U.startsWith('http://localhost');

type Compte = { email: string; password: string; id: string };
const sql = (q: string) => execSync(`docker exec -i ${DB} psql -U postgres -t -A -q`, { input: q }).toString().trim();
const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

async function creer(role: string, staff?: string): Promise<Compte> {
  const email = `zz-test-l2-${randomUUID().slice(0, 8)}@example.com`, password = 'Zz-test-' + randomUUID().slice(0, 8) + '!';
  const d = await (await fetch(`${U}/auth/v1/signup`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) })).json();
  await fetch(`${U}/rest/v1/profiles`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + d.access_token, 'Content-Type': 'application/json' }, body: JSON.stringify({ id: d.user.id, name: 'Test ' + role, email, role }) });
  if (staff) sql(`update profiles set role = '${staff}' where id = '${d.user.id}';`);
  return { email, password, id: d.user.id };
}
const jeton = async (c: Compte) => (await (await fetch(`${U}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: K, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: c.email, password: c.password }) })).json()).access_token as string;
async function lire(c: Compte | null, chemin: string): Promise<any> {
  const h: Record<string, string> = { apikey: K };
  if (c) h.Authorization = 'Bearer ' + (await jeton(c));
  return (await fetch(`${U}/rest/v1/${chemin}`, { headers: h })).json();
}
async function rpc(c: Compte, fn: string, body: object): Promise<any> {
  return (await fetch(`${U}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + (await jeton(c)), 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json();
}

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
  await page.waitForTimeout(2500);
}
async function connecter(page: Page, c: Compte, clic = { x: 198, y: 583 }) {
  await demarrer(page, 's/11');
  const champs = page.locator('flt-semantics-host input');
  for (let i = 0; i < 3; i++) {
    await champs.nth(0).fill(c.email);
    await page.waitForTimeout(500);
    await champs.nth(1).fill(c.password);
    await page.waitForTimeout(700);
    if ((await champs.nth(1).inputValue()) === c.password) break;
  }
  await page.mouse.click(clic.x, clic.y);
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

test.describe.configure({ mode: 'serial', timeout: 180_000 });
test.skip(!local, 'Base locale isolée requise (BE_URL=http://127.0.0.1:54321)');

let client: Compte, talent: Compte, support: Compte, direction: Compte, admin: Compte;
let mission = '';
test.beforeAll(async () => {
  if (!local) return;
  client = await creer('company');
  talent = await creer('student');
  support = await creer('client', 'support');
  direction = await creer('client', 'direction');
  admin = await creer('client', 'admin');
  mission = await rpc(client, 'save_mission', { p_id: null, p_title: 'Identité Mbella ' + randomUUID().slice(0, 4), p_description: 'Logo, charte et déclinaisons pour une marque de parfums.', p_budget_min: 150000, p_budget_max: 300000, p_deadline: '', p_publish: true, p_kind: 'besoin' });
  const p = await rpc(talent, 'propose_on_mission', { p_mission: mission, p_amount: 180000, p_delay_days: 30, p_message: '' });
  await rpc(client, 'decide_proposal', { p_id: p, p_accept: true });
});

test.describe('Dernières actions (base isolée)', () => {
  test('code de retrait : l’acheteur le voit (46), le kiosque confirme la remise avec ce code (146-2)', async ({ page, browser }) => {
    const titre = sql("select title from listings where status='approved' and stock > 0 and category <> 'Services' limit 1;");
    const o = await rpc(client, 'create_order', { p_items: [{ title: titre, qty: 1 }], p_home: false, p_method: 'Orange Money' });
    sql(`update orders set paid = true where number = '${o.number}';`); // mise en place : paiement confirmé
    await connecter(page, client);
    await page.waitForTimeout(3000);
    await aller(page, 's/46');
    await page.mouse.click(284, 797); // « Voir le code de retrait » (commande consultée : la plus récente)
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Code de retrait');
    const vrai = sql(`select pickup_code from orders where number = '${o.number}';`);
    expect(vrai).toMatch(/^\d{6}$/);
    await expect.poll(() => texte(page), { timeout: 10_000 }).toContain(vrai.slice(0, 3) + ' ' + vrai.slice(3)); // le code affiché est celui du serveur

    const k = await (await browser.newContext({ viewport: { width: 390, height: 844 } })).newPage();
    await connecter(k, support);
    await aller(k, 's/146-2');
    await k.mouse.click(195, 658); // « Confirmer la remise »
    await expect.poll(() => texte(k), { timeout: 10_000 }).toContain('Confirmer la remise Annuler');
    await remplir(k, 0, o.number);
    await remplir(k, 1, vrai === '000000' ? '111111' : '000000');
    await k.getByRole('button', { name: 'Confirmer' }).last().click();
    await expect.poll(() => texte(k), { timeout: 15_000 }).toContain('Code de retrait incorrect');
    await k.getByRole('button', { name: 'Compris' }).click();
    await k.mouse.click(195, 658);
    await expect.poll(() => texte(k), { timeout: 10_000 }).toContain('Confirmer la remise Annuler');
    await remplir(k, 0, o.number);
    await remplir(k, 1, vrai);
    await k.getByRole('button', { name: 'Confirmer' }).last().click();
    await expect.poll(() => texte(k), { timeout: 15_000 }).toContain('Remise confirmée');
    expect(sql(`select status || ',' || (picked_up_at is not null) from orders where number = '${o.number}';`)).toBe('3,true');
  });

  test('dossier de mission (196) : le prestataire écrit, le message est persisté et le client notifié', async ({ page }) => {
    await connecter(page, talent);
    await aller(page, 's/196');
    await page.mouse.click(284, 787); // « Envoyer »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Envoyer');
    await remplir(page, 0, 'Voici les trois pistes de logo.');
    await page.getByRole('button', { name: 'Envoyer' }).last().click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Message envoyé');
    expect((await lire(client, `mission_messages?select=body&mission_id=eq.${mission}`)).map((x: any) => x.body)).toEqual(['Voici les trois pistes de logo.']);
    expect((await lire(client, 'notifications?select=title&kind=eq.mission')).map((x: any) => x.title)).toContain('Nouveau message du dossier');
  });

  test('fichier de dossier (196) : un PDF déposé est visible du client, pas d’un tiers ; un .exe est refusé', async ({ page }) => {
    await connecter(page, talent);
    await aller(page, 's/196');
    const [choix] = await Promise.all([page.waitForEvent('filechooser'), page.mouse.click(105, 787)]); // « Ajouter un fichier »
    await choix.setFiles({ name: 'moodboard.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.4\n%test\n') });
    await expect.poll(() => texte(page), { timeout: 20_000 }).toContain('déposé');
    expect((await lire(client, `files?select=name&ref=eq.${mission}`)).map((x: any) => x.name)).toEqual(['moodboard.pdf']);
    const tiers = await creer('student');
    expect(await lire(tiers, `files?select=name&ref=eq.${mission}`)).toEqual([]);

    const [choix2] = await Promise.all([page.waitForEvent('filechooser'), page.mouse.click(105, 787)]);
    await choix2.setFiles({ name: 'virus.exe', mimeType: 'application/octet-stream', buffer: Buffer.from('MZ') });
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Type refusé');
  });

  test('lien de CV (228) : régénéré, consultable sans compte, l’ancien lien est invalidé', async ({ page, browser }) => {
    await connecter(page, talent);
    await aller(page, 's/228');
    await page.mouse.click(195, 797); // « Régénérer le lien »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Nouveau lien de CV');
    const lien1 = (await texte(page)).match(/#\/cv\/([0-9a-f]{32})/)![1];
    await page.getByRole('button', { name: 'Compris' }).click();
    const visiteur = await (await browser.newContext()).newPage();
    await visiteur.goto('/#/cv/' + lien1);
    await visiteur.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
    await visiteur.waitForTimeout(3500);
    await visiteur.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
    await expect.poll(() => texte(visiteur), { timeout: 15_000 }).toContain('Test student');
    expect(await texte(visiteur)).not.toContain('@example.com');

    await page.mouse.click(195, 797);
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Nouveau lien de CV');
    await visiteur.reload();
    await visiteur.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
    await visiteur.waitForTimeout(3500);
    await visiteur.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
    await expect.poll(() => texte(visiteur), { timeout: 15_000 }).toContain('Lien de CV invalide');
  });

  test('fichier de projet (279) : dépôt réel rattaché au projet de l’étudiant', async ({ page }) => {
    const p = await rpc(talent, 'save_project', { p_id: null, p_title: 'Lampe IoT', p_summary: 'Lampe connectée en bois recyclé, pilotée par téléphone.', p_department: 'GI', p_links: {}, p_submit: false });
    await connecter(page, talent);
    await aller(page, 's/279');
    const [choix] = await Promise.all([page.waitForEvent('filechooser'), page.mouse.click(195, 796)]);
    await choix.setFiles({ name: 'plan-lampe.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.4\n%plan\n') });
    await expect.poll(() => texte(page), { timeout: 20_000 }).toContain('déposé');
    expect((await lire(talent, `files?select=name,scope&ref=eq.${p}`))).toEqual([{ name: 'plan-lampe.pdf', scope: 'project' }]);
  });

  test('clé d’intégration (280) : créée par l’administrateur, affichée une fois, seule l’empreinte est conservée', async ({ page }) => {
    await connecter(page, admin);
    await aller(page, 's/280');
    await page.mouse.click(195, 796); // « Créer une clé »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Clés d’intégration');
    await page.getByRole('button', { name: 'Créer une clé' }).last().click();
    await remplir(page, 0, 'Portail entreprises');
    await page.getByRole('button', { name: 'Créer' }).last().click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Clé créée');
    const cle = (await texte(page)).match(/be_live_[0-9a-f]{48}/)![0];
    expect(sql(`select count(*) from api_keys where prefix = '${cle.slice(0, 12)}' and key_hash = encode(extensions.digest('${cle}', 'sha256'), 'hex');`)).toBe('1');
    expect(sql(`select count(*) from api_keys where key_hash = '${cle}';`)).toBe('0');
  });

  test('établissement (118) : la direction modifie le téléphone, valeur publique persistée ; refusé à un client', async ({ page }) => {
    await connecter(page, direction);
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.waitForTimeout(1500);
    await aller(page, 's/118');
    await page.mouse.click(396, 541); // « Enregistrer les modifications »
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Enregistrer les modifications');
    const tel = '+237 233 ' + Math.floor(10 + Math.random() * 89) + ' 00 00';
    await remplir(page, 4, tel);
    await page.getByRole('button', { name: 'Enregistrer les modifications' }).last().click();
    await expect.poll(() => texte(page), { timeout: 15_000 }).toContain('Identité de l’établissement enregistrée');
    expect(await lire(null, 'institution_settings?select=phone')).toEqual([{ phone: tel }]);
    const r = await rpc(client, 'save_institution', { p_name: 'X', p_acronym: 'XX', p_address: '', p_email: '', p_phone: '', p_primary: '#000000', p_accent: '#000000', p_font: '' });
    expect(JSON.stringify(r)).toContain('Réservé');
  });
});
