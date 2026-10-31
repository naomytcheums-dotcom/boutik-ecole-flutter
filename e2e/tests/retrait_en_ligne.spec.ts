import { expect, Page, test } from '@playwright/test';

// Écran de retrait (146-2) sur le site RÉELLEMENT EN LIGNE, sans aucune écriture en production :
// TOUT le trafic vers Supabase est intercepté dans le navigateur (session « support » simulée, réponses de confirm_pickup simulées),
// le temps réel (websocket) est coupé, et le test vérifie qu'aucune requête n'a atteint le serveur.
// Usage : BASE_URL=https://boutik-ecole.vercel.app npx playwright test retrait_en_ligne --workers=1
const U = process.env.BE_URL ?? 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

const UID = '00000000-0000-4000-8000-00000000c0de';
const EMAIL = 'agent-kiosque-simule@example.invalid';
const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
const exp = Math.floor(Date.now() / 1000) + 3600;
const JWT = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: UID, email: EMAIL, role: 'authenticated', aud: 'authenticated', aal: 'aal1', exp, session_id: 'simulee' })}.signature-simulee`;
const USER = { id: UID, aud: 'authenticated', role: 'authenticated', email: EMAIL, email_confirmed_at: '2026-10-31T00:00:00Z', app_metadata: { provider: 'email' }, user_metadata: {}, identities: [], factors: [], created_at: '2026-10-31T00:00:00Z', updated_at: '2026-10-31T00:00:00Z' };
const SESSION = { access_token: JWT, token_type: 'bearer', expires_in: 3600, expires_at: exp, refresh_token: 'jeton-simule', user: USER };
const PROFIL = { id: UID, name: 'Agent kiosque (simulé)', email: EMAIL, role: 'support', suspended: false, phone: '', city: '', institution: '', department: '', birth: '', bio: '', skills: '', avatar_url: '', certification: 'none' };
const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*', 'access-control-expose-headers': '*', 'content-type': 'application/json' };

type Scenario = (corps: string) => Promise<{ status?: number; body?: string; abort?: boolean }>;
let scenario: Scenario = async () => ({ status: 200, body: '"incorrect"' });
const vus: string[] = [];
const traitees: string[] = [];
const envoisRetrait: string[] = [];

async function intercepter(page: Page) {
  await page.routeWebSocket(/supabase\.co/, (ws) => ws.close()); // temps réel coupé : aucune connexion au serveur
  await page.route(`${U}/**`, async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const m = req.method();
    traitees.push(`${m} ${url.pathname}`);
    if (m === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    const json = (status: number, body: unknown) => route.fulfill({ status, headers: CORS, body: typeof body === 'string' ? body : JSON.stringify(body) });
    if (url.pathname.startsWith('/auth/v1/token')) return json(200, SESSION);
    if (url.pathname.startsWith('/auth/v1/user')) return json(200, USER);
    if (url.pathname.startsWith('/auth/v1/logout')) return route.fulfill({ status: 204, headers: CORS });
    if (url.pathname.startsWith('/auth/v1/factors')) return json(200, []);
    if (url.pathname === '/rest/v1/profiles' && m === 'GET') return json(200, (req.headers()['accept'] ?? '').includes('vnd.pgrst.object') ? PROFIL : [PROFIL]);
    if (url.pathname === '/rest/v1/rpc/confirm_pickup') {
      envoisRetrait.push(req.postData() ?? '');
      const r = await scenario(req.postData() ?? '');
      if (r.abort) return route.abort('failed').catch(() => {});
      return route.fulfill({ status: r.status ?? 200, headers: CORS, body: r.body ?? 'null' }).catch(() => {});
    }
    if (m === 'GET' || m === 'HEAD') return json(200, []);
    return json(200, m === 'POST' && url.pathname.startsWith('/rest/v1/rpc/') ? 'null' : []);
  });
}

async function demarrer(page: Page, hash: string) {
  await page.goto('/#/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => (document.querySelector('flt-semantics-placeholder') as HTMLElement | null)?.dispatchEvent(new MouseEvent('click', { bubbles: true })));
  await page.waitForTimeout(2500);
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
const ECHANTILLONNEUR = () => {
  const w = window as any;
  w.__vus = new Set<string>();
  setInterval(() => { const t = (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText; if (t) w.__vus.add(t.replace(/\s+/g, ' ')); }, 100);
};
const affiches = async (k: Page) => (await k.evaluate(() => [...((window as any).__vus ?? [])].join(' | '))) as string;
const oublier = (k: Page) => k.evaluate(() => (window as any).__vus?.clear());
const erreurServeur = (status: number, message: string) => ({ status, body: JSON.stringify({ code: status === 400 ? 'P0001' : String(status), message, details: null, hint: null }) });

test.describe.configure({ mode: 'serial', timeout: 420_000 });

test('site en ligne, écran de retrait (146-2), serveur entièrement simulé : jamais de faux « Remise confirmée »', async ({ page: k }) => {
  const erreursJs: string[] = [];
  k.on('pageerror', (e) => erreursJs.push(String(e).slice(0, 200)));
  const reseau: string[] = [];
  k.on('request', (r) => { if (r.url().startsWith(U)) reseau.push(`${r.method()} ${new URL(r.url()).pathname}`); });
  await k.addInitScript(ECHANTILLONNEUR);
  await intercepter(k);

  await test.step('connexion simulée d’un agent « support » par le vrai écran de connexion', async () => {
    await demarrer(k, 's/11');
    const champs = k.locator('flt-semantics-host input');
    for (let i = 0; i < 3; i++) {
      await champs.nth(0).fill(EMAIL);
      await k.waitForTimeout(500);
      await champs.nth(1).fill('mot-de-passe-simule');
      await k.waitForTimeout(700);
      if ((await champs.nth(1).inputValue()) === 'mot-de-passe-simule') break;
    }
    await k.mouse.click(198, 583);
    await expect.poll(() => texte(k), { timeout: 30_000 }).toContain('Bienvenue');
    await aller(k, 's/146-2');
    await expect.poll(() => texte(k), { timeout: 15_000 }).toContain('Confirmer la remise');
  });

  const cas: [string, Scenario, string][] = [
    ['1. code erroné', async () => ({ status: 200, body: '"incorrect"' }), 'Code de retrait incorrect'],
    ['3. cinq essais : blocage du serveur', async () => erreurServeur(400, "Trop d'essais : l'acheteur doit afficher un nouveau code de retrait"), "Trop d'essais"],
    ['4. code remplacé / commande déjà remise', async () => erreurServeur(400, 'Commande déjà remise'), 'Commande déjà remise'],
    ['6. HTTP 401', async () => erreurServeur(401, 'JWT expired'), 'Remise refusée'],
    ['6. HTTP 403', async () => erreurServeur(403, 'permission denied for function confirm_pickup'), 'Remise refusée'],
    ['6. HTTP 500', async () => erreurServeur(500, 'internal error'), 'Remise refusée'],
    ['5a. erreur réseau', async () => ({ abort: true }), 'Remise refusée'],
    ['2. réponse null', async () => ({ status: 200, body: 'null' }), 'Remise non confirmée'],
    ['2. réponse "ok"', async () => ({ status: 200, body: '"ok"' }), 'Remise non confirmée'],
    ['2. réponse true', async () => ({ status: 200, body: 'true' }), 'Remise non confirmée'],
  ];
  for (const [nom, sc, attendu] of cas) {
    await test.step(`${nom} : « ${attendu} », jamais « Remise confirmée »`, async () => {
      await oublier(k);
      scenario = sc;
      await confirmer(k, '#BE-2026-0999', '123456');
      await expect.poll(() => texte(k), { timeout: 15_000 }).toContain(attendu);
      expect(await affiches(k)).not.toContain('Remise confirmée');
      await fermer(k);
    });
  }

  await test.step('5b. délai dépassé : « n’a pas répondu à temps », jamais de succès', async () => {
    await oublier(k);
    scenario = async () => { await new Promise((ok) => setTimeout(ok, 26_000)); return { abort: true }; };
    await confirmer(k, '#BE-2026-0999', '123456');
    await expect.poll(() => texte(k), { timeout: 30_000 }).toContain('n’a pas répondu à temps');
    expect(await affiches(k)).not.toContain('Remise confirmée');
    await fermer(k);
    await k.waitForTimeout(6_000); // la requête retenue est abandonnée avant l'étape suivante
  });

  await test.step('7. soumission répétée pendant l’attente : refusée par l’écran, un seul envoi', async () => {
    await oublier(k);
    const avant = envoisRetrait.length;
    scenario = async () => { await new Promise((ok) => setTimeout(ok, 5_000)); return { status: 200, body: '"incorrect"' }; };
    await confirmer(k, '#BE-2026-0999', '123456');
    await k.waitForTimeout(800);
    await k.mouse.click(195, 658);
    await expect.poll(() => texte(k), { timeout: 5_000 }).toContain('déjà en cours');
    await expect.poll(() => texte(k), { timeout: 15_000 }).toContain('Code de retrait incorrect');
    expect(envoisRetrait.length - avant).toBe(1);
    expect(await affiches(k)).not.toContain('Remise confirmée');
    await fermer(k);
  });

  await test.step('2. réponse « delivered » : « Remise confirmée », avec les valeurs saisies', async () => {
    await oublier(k);
    scenario = async () => ({ status: 200, body: '"delivered"' });
    await confirmer(k, '#BE-2026-0999', '654 321');
    await expect.poll(() => affiches(k), { timeout: 15_000 }).toContain('Remise confirmée');
    expect(JSON.parse(envoisRetrait[envoisRetrait.length - 1])).toEqual({ p_number: '#BE-2026-0999', p_code: '654321' });
  });

  await test.step('aucune requête n’a atteint le serveur de production', async () => {
    expect(reseau.length).toBeGreaterThan(0);
    // chaque requête émise vers Supabase a été traitée par l'interception (aucune poursuite vers le réseau)
    const nonTraitees = reseau.filter((r) => !traitees.includes(r));
    expect(nonTraitees).toEqual([]);
    console.log(`requêtes interceptées : ${traitees.length} ; envois confirm_pickup : ${envoisRetrait.length} ; erreurs JavaScript non interceptées : ${erreursJs.length}`);
    if (erreursJs.length) console.log(erreursJs.join('\n'));
  });
});
