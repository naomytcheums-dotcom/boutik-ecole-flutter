// Tests de contrat des Edge Functions (H13.2 · agent 6) : chaque fonction est chargée telle quelle (index.ts) avec un faux Deno, un faux supabase-js et AUCUN réseau.
//   node --experimental-transform-types --import ./supabase/functions/_contract/register.mjs --test supabase/functions/_contract/contract.test.mjs
// Contrats vérifiés : jeton absent / expiré / session fermée / compte suspendu / vérification indisponible => refus SANS aucun accès aux données ni au fournisseur ;
// signature ou secret de webhook invalide => refus avant toute lecture ; corps invalide => 400 ; secret absent => 503 « not_configured » sans aucune valeur de secret dans la réponse ni les journaux.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, createHash } from 'node:crypto';

const W = globalThis.__CONTRACT__;
assert.ok(W, 'lancer avec --import ./supabase/functions/_contract/register.mjs');

const SECRETS = {
  SUPABASE_URL: 'https://projet-factice.local', SUPABASE_ANON_KEY: 'ANON-VALEUR-SECRETE-111', SUPABASE_SERVICE_ROLE_KEY: 'SERVICE-VALEUR-SECRETE-222',
  NOTCHPAY_KEY: 'NOTCH-CLE-SECRETE-333', NOTCHPAY_HASH: 'NOTCH-HASH-SECRET-444', TARA_API_KEY: 'TARA-CLE-SECRETE-555', TARA_BUSINESS_ID: 'TARA-BIZ-666', TARA_WEBHOOK_SECRET: 'TARA-WEBHOOK-SECRET-777',
  ANTHROPIC_API_KEY: 'ANTHROPIC-SECRETE-888', LIVEKIT_URL: 'wss://livekit.factice', LIVEKIT_API_KEY: 'LK-CLE-999', LIVEKIT_API_SECRET: 'LK-SECRET-1010', VAPID_PUBLIC_KEY: 'BPUBLIC-vapid-1212',
  MTN_MOMO_SUBSCRIPTION_KEY: 'MTN-SUB-1313', MTN_MOMO_API_USER: 'MTN-USER-1414', MTN_MOMO_API_KEY: 'MTN-KEY-1515', MTN_MOMO_TARGET_ENV: 'sandbox', MTN_MOMO_CALLBACK_SECRET: 'MTN-CALLBACK-SECRET-1616',
  INTEGRATIONS_ENC_KEY: Buffer.alloc(32, 7).toString('base64'), TWILIO_AUTH_TOKEN: 'TWILIO-SECRET-1717', TWILIO_ACCOUNT_SID: 'ACfactice', TWILIO_SMS_FROM: '+237600000000',
};
const SENSITIVE = Object.entries(SECRETS).filter(([k]) => !['SUPABASE_URL', 'LIVEKIT_URL', 'MTN_MOMO_TARGET_ENV', 'TWILIO_ACCOUNT_SID', 'TWILIO_SMS_FROM', 'VAPID_PUBLIC_KEY'].includes(k)).map(([, v]) => v);
const without = (...names) => Object.fromEntries(Object.entries(SECRETS).filter(([k]) => !names.includes(k)));

const LIVE = '00000000-0000-0000-0000-0000000000e1';
const UID = '00000000-0000-0000-0000-0000000000c1', SID = '00000000-0000-0000-0000-0000000000d1';
const jwt = (sub = UID, sid = SID) => `${Buffer.from('{"alg":"HS256"}').toString('base64url')}.${Buffer.from(JSON.stringify({ sub, session_id: sid, role: 'authenticated' })).toString('base64url')}.signature`;

let counter = 0;
function reset(env) {
  W.env = { ...env }; W.handler = null; W.tokens = new Map();
  W.dbCalls.length = W.rpcCalls.length = W.authCalls.length = W.fetchCalls.length = W.logs.length = 0;
  W.tableResult = () => ({ data: null, error: null, count: 0 });
  W.rpcResult = (fn) => (fn === '_session_status_of' ? { data: 'ok', error: null } : { data: null, error: null });
  W.fetchImpl = null;
}
async function load(fn, env = SECRETS) {
  reset(env);
  await import(new URL(`../${fn}/index.ts?c=${++counter}`, import.meta.url).href);
  assert.equal(typeof W.handler, 'function', `${fn} doit enregistrer un gestionnaire Deno.serve`);
  return W.handler;
}
const call = async (h, { method = 'POST', url = 'https://x.local/f', headers = {}, body } = {}) => {
  const init = { method, headers: { 'content-type': 'application/json', ...headers } };
  if (body !== undefined && method !== 'GET') init.body = typeof body === 'string' ? body : JSON.stringify(body);
  const res = await h(new Request(url, init));
  const text = await res.text();
  let json = null; try { json = JSON.parse(text); } catch { /* texte */ }
  return { status: res.status, text, json, headers: Object.fromEntries(res.headers) };
};
const untouched = (why) => {
  assert.deepEqual(W.dbCalls.map((c) => `${c.kind}:${c.table}`), [], `${why} : aucune lecture ni écriture de table`);
  assert.deepEqual(W.fetchCalls, [], `${why} : aucun appel à un fournisseur`);
  assert.ok(W.rpcCalls.every((c) => c.fn === '_session_status_of'), `${why} : aucune RPC hors contrôle de session`);
};
const noLeak = (res, why) => {
  const all = [res.text, JSON.stringify(res.headers), ...W.logs].join('\n');
  for (const s of SENSITIVE) assert.ok(!all.includes(s), `${why} : une valeur de secret fuit (${s.slice(0, 8)}…)`);
};
const ADMIN_PROFILE = (op) => (op.table === 'profiles' ? { data: { role: 'admin', suspended: false }, error: null } : { data: null, error: null, count: 0 });
const hmacHex = (secret, data) => createHmac('sha256', secret).update(data).digest('hex');

// ============================================================ 1. fonctions appelées par un utilisateur connecté
const CALLERS = [
  ['pay', { action: 'status', order_number: 'BE-1' }],
  ['tara-pay', { reference: 'R-1', network: 'MTN', phone: '237670000000' }],
  ['kela-chat', { messages: [{ role: 'user', content: 'Bonjour' }] }],
  ['admin-test-accounts', { action: 'list' }],
  ['integrations-oauth', { action: 'start', provider: 'dropbox' }],
  ['integrations-publish', { post: 'x' }],
  ['integrations-sync', { action: 'sync', connection: 'c' }],
  ['live-token', { live_id: LIVE }],
  ['live-record', { live_id: LIVE, action: 'start' }],
  ['live-moderate', { live_id: LIVE, action: 'mute', user_id: UID }],
  ['momo', { action: 'status', reference: 'r' }],
  ['auth-recovery', { action: 'phone_verify_request', phone: '+237670000000' }],
];

for (const [fn, body] of CALLERS) {
  test(`${fn} : jeton absent / expiré / session fermée / compte suspendu / contrôle indisponible => refus sans accès aux données`, async () => {
    const h = await load(fn);
    // 1. jeton absent
    let r = await call(h, { body });
    assert.equal(r.status, 401, `jeton absent : ${r.text}`); untouched('jeton absent'); noLeak(r, 'jeton absent');
    // 2. jeton expiré / invalide : refusé par GoTrue (identité inconnue), session encore « ok » en base
    reset(SECRETS); W.handler = h;
    r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body });
    assert.equal(r.status, 401, `jeton expiré : ${r.text}`); untouched('jeton expiré'); noLeak(r, 'jeton expiré');
    // 3. signature valide mais session fermée (GoTrue refuse + la base confirme)
    reset(SECRETS); W.handler = h; W.rpcResult = (f) => ({ data: f === '_session_status_of' ? 'session_revoked' : null, error: null });
    r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body });
    assert.equal(r.status, 401); assert.equal(r.json?.error ?? r.json?.code, 'session_revoked', r.text); untouched('session fermée (jeton refusé)');
    // 3b. GoTrue accepte encore le jeton mais la session n'existe plus en base
    reset(SECRETS); W.handler = h; W.tokens.set(jwt(), UID); W.rpcResult = (f) => ({ data: f === '_session_status_of' ? 'session_revoked' : null, error: null });
    r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body });
    assert.equal(r.status, 401); assert.equal(r.json?.error ?? r.json?.code, 'session_revoked', r.text); untouched('session fermée (jeton accepté)');
    // 4. compte suspendu
    reset(SECRETS); W.handler = h; W.tokens.set(jwt(), UID); W.rpcResult = (f) => ({ data: f === '_session_status_of' ? 'suspended' : null, error: null });
    r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body });
    assert.equal(r.status, 403); assert.equal(r.json?.error ?? r.json?.code, 'account_suspended', r.text); untouched('compte suspendu'); noLeak(r, 'compte suspendu');
    // 5. vérification indisponible : refus (jamais accepté par défaut)
    reset(SECRETS); W.handler = h; W.tokens.set(jwt(), UID); W.rpcResult = () => ({ data: null, error: { message: 'down' } });
    r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body });
    assert.equal(r.status, 503); assert.equal(r.json?.error ?? r.json?.code, 'session_check_unavailable', r.text); untouched('contrôle indisponible');
  });
}

test('témoin : avec un jeton valide et une session ouverte, les fonctions dépassent le contrôle de session (le test ne passe pas à vide)', async () => {
  for (const [fn, body] of CALLERS) {
    const h = await load(fn);
    W.tokens.set(jwt(), UID); W.tableResult = ADMIN_PROFILE;
    const r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body });
    assert.ok(![401, 403].includes(r.status) || /not_configured/.test(r.text), `${fn} : bloqué à tort (${r.status} ${r.text.slice(0, 120)})`);
  }
});

test('admin-test-accounts : réservé à l\'administrateur actif ; mot de passe faible refusé ; aucune écriture avant ces contrôles', async () => {
  const h = await load('admin-test-accounts');
  W.tokens.set(jwt(), UID);
  const auth = { Authorization: `Bearer ${jwt()}` };
  for (const [name, row] of [['client', { role: 'client', suspended: false }], ['étudiant', { role: 'student', suspended: false }], ['support', { role: 'support', suspended: false }], ['administrateur suspendu', { role: 'admin', suspended: true }], ['profil introuvable', null]]) {
    W.dbCalls.length = 0; W.tableResult = (op) => ({ data: op.table === 'profiles' ? row : null, error: null });
    const r = await call(h, { headers: auth, body: { action: 'password', password: 'MotDePasse123' } });
    assert.equal(r.status, 403, name); assert.ok(W.dbCalls.every((c) => c.kind === 'select'), name + ' : aucune écriture'); assert.equal(W.rpcCalls.filter((c) => c.fn !== '_session_status_of').length, 0);
  }
  W.tableResult = ADMIN_PROFILE; W.dbCalls.length = 0;
  const weak = await call(h, { headers: auth, body: { action: 'password', password: 'court' } });
  assert.equal(weak.status, 400); assert.equal(weak.json.error, 'weak_password'); assert.ok(W.dbCalls.every((c) => c.table === 'profiles' && c.kind === 'select'));
});

test('corps invalide (JSON illisible) avec un jeton valide : 400 bad_request, aucune écriture', async () => {
  for (const fn of ['pay', 'tara-pay', 'kela-chat', 'admin-test-accounts', 'integrations-oauth', 'integrations-publish', 'integrations-sync', 'live-token', 'live-record', 'live-moderate', 'momo']) {
    const h = await load(fn);
    W.tokens.set(jwt(), UID); W.tableResult = ADMIN_PROFILE;
    const r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body: '{pas du json' });
    assert.equal(r.status, 400, `${fn} : ${r.status} ${r.text.slice(0, 120)}`);
    assert.ok(/bad_request/.test(r.text), `${fn} : code bad_request attendu`);
    assert.ok(W.dbCalls.every((c) => c.kind === 'select'), `${fn} : aucune écriture`);
    assert.deepEqual(W.fetchCalls, [], `${fn} : aucun appel fournisseur`);
  }
});

// ============================================================ 2. secret absent => not_configured, sans fuite
test('secret absent : 503 « not_configured » sans valeur de secret, sans accès aux données ni au fournisseur', async () => {
  const cases = [
    ['pay', without('NOTCHPAY_KEY'), { action: 'status', order_number: 'BE-1' }, {}],
    ['tara-pay', without('TARA_API_KEY'), { reference: 'R', network: 'MTN', phone: '237670000000' }, {}],
    ['tara-pay', without('TARA_BUSINESS_ID'), { reference: 'R', network: 'MTN', phone: '237670000000' }, {}],
    ['tara-pay', without('TARA_WEBHOOK_SECRET'), { reference: 'R', network: 'MTN', phone: '237670000000' }, {}],
    ['kela-chat', without('ANTHROPIC_API_KEY'), { messages: [] }, {}],
    ['push-config', without('VAPID_PUBLIC_KEY'), undefined, { method: 'GET' }],
    ['notchpay-webhook', without('NOTCHPAY_HASH'), { type: 'payment.complete' }, {}],
    ['notchpay-webhook', without('NOTCHPAY_KEY'), { type: 'payment.complete' }, {}],
    ['tara-webhook', without('TARA_WEBHOOK_SECRET'), { status: 'success' }, {}],
    ['momo-callback', without('MTN_MOMO_CALLBACK_SECRET'), { externalId: 'r' }, {}],
    ['momo-callback', without('MTN_MOMO_API_KEY'), { externalId: 'r' }, { url: 'https://x.local/f?s=MTN-CALLBACK-SECRET-1616' }],
    ['live-egress-webhook', without('LIVEKIT_API_SECRET'), { event: 'egress_ended' }, {}],
  ];
  for (const [fn, env, body, extra] of cases) {
    const h = await load(fn, env);
    const r = await call(h, { body, ...extra });
    assert.equal(r.status, 503, `${fn} sans ${Object.keys(SECRETS).filter((k) => !(k in env)).join(',')} : ${r.status} ${r.text.slice(0, 100)}`);
    assert.ok(/not_configured/.test(r.text), `${fn} : « not_configured » attendu (${r.text.slice(0, 100)})`);
    untouched(`${fn} non configuré`); noLeak(r, `${fn} non configuré`);
  }
  for (const fn of ['live-token', 'live-moderate']) {
    const h = await load(fn, without('LIVEKIT_API_SECRET'));
    W.tokens.set(jwt(), UID);
    const r = await call(h, { headers: { Authorization: `Bearer ${jwt()}` }, body: { live_id: LIVE, action: 'mute', user_id: UID } });
    assert.equal(r.status, 503, `${fn} : ${r.status} ${r.text.slice(0, 100)}`); assert.ok(/not_configured/.test(r.text)); noLeak(r, `${fn} non configuré`);
    assert.deepEqual(W.fetchCalls, []);
  }
  // traduction : sans fournisseur configuré, jamais un texte simulé
  const h = await load('translate', {});
  const r = await call(h, { body: { message_id: 'm', target: 'en' } });
  assert.equal(r.status, 503); assert.ok(/not_configured/.test(r.text)); assert.deepEqual(W.fetchCalls, []);
});

test('push-config : clé publique seulement (jamais d\'autre secret), CORS limité aux origines connues', async () => {
  const h = await load('push-config');
  const r = await call(h, { method: 'GET', headers: { Origin: 'https://boutik-ecole.vercel.app' } });
  assert.equal(r.status, 200); assert.deepEqual(r.json, { publicKey: SECRETS.VAPID_PUBLIC_KEY }); noLeak(r, 'push-config');
  const evil = await call(h, { method: 'GET', headers: { Origin: 'https://evil.example' } });
  assert.notEqual(evil.headers['access-control-allow-origin'], 'https://evil.example');
});

// ============================================================ 3. webhooks : signature / secret invalide
test('notchpay-webhook : signature absente, fausse, mal formée ou calculée avec une autre clé => 401 avant toute lecture ; GET => 405', async () => {
  const h = await load('notchpay-webhook');
  const raw = JSON.stringify({ type: 'payment.complete', data: { transaction: { reference: 'BE-1-1' } } });
  const attempts = { absente: {}, fausse: { 'x-notch-signature': 'a'.repeat(64) }, tronquee: { 'x-notch-signature': hmacHex(SECRETS.NOTCHPAY_HASH, raw).slice(0, 30) }, 'autre clé (clé API)': { 'x-notch-signature': hmacHex(SECRETS.NOTCHPAY_KEY, raw) },
    'autre corps': { 'x-notch-signature': hmacHex(SECRETS.NOTCHPAY_HASH, raw + ' ') }, 'non hexadécimale': { 'x-notch-signature': 'zz' + hmacHex(SECRETS.NOTCHPAY_HASH, raw).slice(2) } };
  for (const [name, headers] of Object.entries(attempts)) {
    const r = await call(h, { headers, body: raw });
    assert.equal(r.status, 401, `${name} : ${r.status}`); assert.equal(r.json.error, 'invalid_signature'); untouched(`signature ${name}`); noLeak(r, `signature ${name}`);
  }
  assert.ok(W.logs.some((l) => /signature invalide/.test(l)), 'refus journalisé');
  assert.equal((await call(h, { method: 'GET' })).status, 405);
  // signature valide (préfixe sha256= toléré) + corps non JSON : 400 sans lecture de table
  const bad = '{pas du json';
  const r = await call(h, { headers: { 'x-notch-signature': 'sha256=' + hmacHex(SECRETS.NOTCHPAY_HASH, bad) }, body: bad });
  assert.equal(r.status, 400); assert.equal(r.json.error, 'bad_json'); untouched('corps invalide');
  // signature valide, événement sans référence : ignoré sans écriture
  const ign = JSON.stringify({ type: 'customer.created' });
  const r2 = await call(h, { headers: { 'x-notch-signature': hmacHex(SECRETS.NOTCHPAY_HASH, ign) }, body: ign });
  assert.equal(r2.status, 200); assert.equal(r2.json.ignored, true); untouched('événement ignoré');
});

test('notchpay-webhook : rejeu refusé, commande inconnue ignorée, paiement insuffisant non confirmé, paiement complet confirmé UNE fois', async () => {
  const raw = JSON.stringify({ type: 'payment.complete', data: { transaction: { reference: 'BE-1-1' } } });
  const sig = { 'x-notch-signature': hmacHex(SECRETS.NOTCHPAY_HASH, raw) };
  const updates = () => W.dbCalls.filter((c) => c.kind === 'update' && c.table === 'orders');
  // rejeu : la clé primaire de payment_events refuse le doublon
  let h = await load('notchpay-webhook');
  W.tableResult = (op) => (op.table === 'payment_events' && op.kind === 'insert' ? { data: null, error: { code: '23505', message: 'dup' } } : { data: null, error: null });
  let r = await call(h, { headers: sig, body: raw });
  assert.equal(r.json.duplicate, true); assert.equal(updates().length, 0); assert.deepEqual(W.fetchCalls, []);
  // référence inconnue
  h = await load('notchpay-webhook');
  r = await call(h, { headers: sig, body: raw });
  assert.equal(r.json.ignored, 'unknown_reference'); assert.equal(updates().length, 0);
  // montant insuffisant chez le fournisseur
  const order = { id: 'o1', number: 'BE-1', subtotal: 5000, fee: 500, paid: false, cancelled: false, cancelled_at: null };
  const provider = (amount) => async () => new Response(JSON.stringify({ transaction: { status: 'complete', reference: 'BE-1-1', amount, currency: 'XAF' } }), { status: 200 });
  h = await load('notchpay-webhook');
  W.tableResult = (op) => (op.table === 'orders' && op.kind === 'select' ? { data: order, error: null } : { data: [], error: null });
  W.fetchImpl = provider(100);
  r = await call(h, { headers: sig, body: raw });
  assert.equal(r.json.confirmed, false); assert.ok(r.json.problems.includes('underpaid')); assert.equal(updates().length, 0, 'jamais payé sur un montant insuffisant');
  // paiement complet : une seule transition non payé -> payé
  h = await load('notchpay-webhook');
  W.tableResult = (op) => (op.table === 'orders' && op.kind === 'select' ? { data: order, error: null } : { data: [{ id: 'o1' }], error: null });
  W.fetchImpl = provider(5500);
  r = await call(h, { headers: sig, body: raw });
  assert.equal(r.json.confirmed, true); assert.equal(updates().length, 1); assert.deepEqual(updates()[0].payload, { paid: true, status: 1 });
  assert.ok(updates()[0].filters.some((f) => f[0] === 'eq' && f[1] === 'paid' && f[2] === false), 'condition paid = false (idempotence)');
  // commande annulée : jamais confirmée
  h = await load('notchpay-webhook');
  W.tableResult = (op) => (op.table === 'orders' && op.kind === 'select' ? { data: { ...order, cancelled: true }, error: null } : { data: [], error: null });
  W.fetchImpl = provider(5500);
  r = await call(h, { headers: sig, body: raw });
  assert.equal(r.json.confirmed, false); assert.equal(updates().length, 0);
});

test('tara-webhook : secret absent/faux => 403 avant toute lecture ; corps invalide => 400 ; statut inconnu ignoré ; confirmation exigeant montant ou référence prouvée', async () => {
  let h = await load('tara-webhook');
  for (const [name, url, headers] of [['sans secret', 'https://x.local/f', {}], ['mauvais secret (URL)', 'https://x.local/f?s=faux', {}], ['mauvais secret (en-tête)', 'https://x.local/f', { 'x-webhook-secret': 'faux' }], ['secret tronqué', `https://x.local/f?s=${SECRETS.TARA_WEBHOOK_SECRET.slice(0, 10)}`, {}]]) {
    const r = await call(h, { url, headers, body: { productId: 'R1', status: 'success' } });
    assert.equal(r.status, 403, name); untouched(name); noLeak(r, name);
  }
  const ok = { headers: { 'x-webhook-secret': SECRETS.TARA_WEBHOOK_SECRET } };
  assert.equal((await call(h, { ...ok, body: '{pas du json' })).status, 400); untouched('corps invalide');
  const ign = await call(h, { ...ok, body: { productId: 'R1', status: 'en-cours' } });
  assert.equal(ign.text, 'ignored'); untouched('statut inconnu');
  const noRef = await call(h, { ...ok, body: { status: 'success' } });
  assert.equal(noRef.text, 'ignored'); untouched('sans référence');
  const writes = () => W.dbCalls.filter((c) => c.kind !== 'select').map((c) => `${c.kind}:${c.table}:${JSON.stringify(c.payload)?.slice(0, 80)}`);
  // référence inconnue
  h = await load('tara-webhook');
  assert.equal((await call(h, { ...ok, body: { productId: 'R1', status: 'success', amount: 100 } })).text, 'unknown_reference'); assert.deepEqual(writes(), []);
  // transaction déjà confirmée : rejeu sans effet
  h = await load('tara-webhook');
  W.tableResult = (op) => (op.table === 'payment_transactions' && op.kind === 'select' ? { data: { id: 't1', status: 'confirmed', amount: 1000, provider_ref: 'P1' }, error: null } : { data: [], error: null });
  assert.equal((await call(h, { ...ok, body: { productId: 'R1', status: 'success', amount: 1000 } })).text, 'already_done'); assert.deepEqual(writes(), []);
  // montant insuffisant : échec, pas de confirmation
  h = await load('tara-webhook');
  W.tableResult = (op) => (op.table === 'payment_transactions' && op.kind === 'select' ? { data: { id: 't1', status: 'pending', amount: 1000, provider_ref: 'P1' }, error: null } : { data: [], error: null });
  assert.equal((await call(h, { ...ok, body: { productId: 'R1', status: 'success', amount: 10 } })).text, 'mismatch');
  assert.ok(!writes().some((w) => /confirmed/.test(w)), 'aucune confirmation sur un montant insuffisant');
  // succès sans montant et sans référence de transaction prouvée : à vérifier par la finance, jamais confirmé
  h = await load('tara-webhook');
  W.tableResult = (op) => (op.table === 'payment_transactions' && op.kind === 'select' ? { data: { id: 't1', status: 'pending', amount: 1000, provider_ref: 'P1' }, error: null } : { data: [], error: null });
  assert.equal((await call(h, { ...ok, body: { productId: 'R1', status: 'success', transactionId: 'AUTRE' } })).text, 'needs_review');
  assert.ok(!writes().some((w) => /"status":"confirmed"/.test(w)), 'aucune confirmation sans preuve');
  // succès complet : une confirmation conditionnée par le statut
  h = await load('tara-webhook');
  W.tableResult = (op) => (op.table === 'payment_transactions' && op.kind === 'select' ? { data: { id: 't1', status: 'pending', amount: 1000, provider_ref: 'P1' }, error: null } : { data: [{ id: 't1' }], error: null });
  assert.equal((await call(h, { ...ok, body: { productId: 'R1', status: 'success', amount: 1000 } })).text, 'confirmed');
  assert.equal(W.dbCalls.filter((c) => c.kind === 'update' && /confirmed/.test(JSON.stringify(c.payload))).length, 1);
});

test('momo-callback : secret faux => 403 avant toute lecture ; corps invalide => 400 ; référence inconnue sans effet', async () => {
  const h = await load('momo-callback');
  for (const url of ['https://x.local/f', 'https://x.local/f?s=faux', `https://x.local/f?s=${SECRETS.MTN_MOMO_CALLBACK_SECRET}x`]) {
    const r = await call(h, { url, body: { externalId: 'r' } });
    assert.equal(r.status, 403); untouched('secret faux'); noLeak(r, 'secret faux');
  }
  const url = `https://x.local/f?s=${SECRETS.MTN_MOMO_CALLBACK_SECRET}`;
  assert.equal((await call(h, { url, body: '{pas du json' })).status, 400);
  assert.equal((await call(h, { url, body: {} })).text, 'ignored'); untouched('sans référence');
  assert.equal((await call(h, { url, body: { externalId: 'inconnue' } })).text, 'unknown_reference');
  assert.ok(W.dbCalls.every((c) => c.kind === 'select'));
  assert.deepEqual(W.fetchCalls, [], 'aucun appel MTN pour une référence inconnue');
});

test('live-egress-webhook : GET => 405 ; signature absente ou fausse => 401 sans accès aux données', async () => {
  const h = await load('live-egress-webhook');
  assert.equal((await call(h, { method: 'GET' })).status, 405);
  for (const headers of [{}, { Authorization: 'Bearer faux.faux.faux' }]) {
    const r = await call(h, { headers, body: { event: 'egress_ended', egressInfo: { egressId: 'e1', status: 'EGRESS_COMPLETE' } } });
    assert.equal(r.status, 401); assert.equal(r.json.code, 'bad_signature'); untouched('signature LiveKit'); noLeak(r, 'signature LiveKit');
  }
});

test('assessment-dispatch / dispatch-notifications : appel sans clé de service refusé avant toute lecture', async () => {
  for (const fn of ['assessment-dispatch', 'dispatch-notifications']) {
    const h = await load(fn);
    const r = await call(h, { url: 'https://x.local/f?action=dispatch', headers: { Authorization: 'Bearer pas-la-cle' }, body: { action: 'dispatch' } });
    assert.ok([401, 403, 405].includes(r.status), `${fn} : ${r.status} ${r.text.slice(0, 100)}`);
    assert.ok(W.dbCalls.every((c) => c.kind === 'select') && W.fetchCalls.length === 0, `${fn} : aucune écriture ni appel externe`);
    noLeak(r, fn);
  }
});
