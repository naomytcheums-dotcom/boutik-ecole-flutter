// Test Node de la logique de la fonction « translate » contre un FAUX fournisseur local (aucun service externe, aucune clé réelle).
// Exécution : node --test supabase/functions/translate/logic.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { loadConfig, processTranslate, translateWith, readPath } from './logic.ts';

const KEY = 'cle-de-banc-123';

function fakeProvider(handler) {
  const calls = [];
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      const call = { headers: req.headers, body: raw ? JSON.parse(raw) : null };
      calls.push(call);
      handler(call, res);
    });
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, calls, url: `http://127.0.0.1:${server.address().port}/translate` })));
}
const reply = (res, status, obj) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(typeof obj === 'string' ? obj : JSON.stringify(obj)); };
const env = (o) => (n) => o[n];

function deps(cfg, over = {}) {
  const stored = [];
  const d = {
    cfg, userId: 'u1', fetchFn: fetch,
    requestTranslation: async () => ({ data: { status: 'pending', text: 'Bonjour le monde', provider: 'trad_a', target_lang: 'en' }, error: null }),
    storeTranslation: async (a) => { stored.push(a); return { data: null, error: null }; },
    ...over,
  };
  return { d, stored };
}

test('sans secrets : not_configured (503), aucun appel, aucun texte', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { translation: 'SIMULÉ' }));
  try {
    const cfg = loadConfig(env({}));
    assert.equal(cfg, null);
    const { d, stored } = deps(cfg);
    const out = await processTranslate({ message_id: 1, target_lang: 'en' }, d);
    assert.equal(out.status, 503);
    assert.equal(out.body.code, 'not_configured');
    assert.ok(!('text' in out.body));
    assert.equal(p.calls.length, 0);
    assert.equal(stored.length, 0);
  } finally { p.server.close(); }
});

test('secrets partiels ou adresse refusée : toujours not_configured', () => {
  assert.equal(loadConfig(env({ TRANSLATE_API_URL: 'http://127.0.0.1:1/t', TRANSLATE_API_KEY: KEY })), null, 'code fournisseur manquant');
  assert.equal(loadConfig(env({ TRANSLATE_API_URL: 'http://127.0.0.1:1/t', TRANSLATE_PROVIDER_CODE: 'trad_a' })), null, 'clé manquante');
  assert.equal(loadConfig(env({ TRANSLATE_API_URL: 'http://exemple.org/t', TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' })), null, 'http hors boucle locale refusé');
  assert.equal(loadConfig(env({ TRANSLATE_API_URL: 'pas une adresse', TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' })), null);
  assert.ok(loadConfig(env({ TRANSLATE_API_URL: 'https://exemple.org/t', TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'Trad_A' })));
});

test('parcours réussi : fournisseur appelé avec la clé, traduction enregistrée, clé jamais renvoyée', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { translation: 'Hello world', detected_source: 'FR' }));
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
    const { d, stored } = deps(cfg);
    const out = await processTranslate({ message_id: 7, target_lang: 'EN' }, d);
    assert.equal(out.status, 200);
    assert.deepEqual([out.body.status, out.body.text, out.body.source_lang, out.body.cached], ['translated', 'Hello world', 'fr', false]);
    assert.equal(p.calls.length, 1);
    assert.equal(p.calls[0].headers.authorization, `Bearer ${KEY}`);
    assert.deepEqual(p.calls[0].body, { text: 'Bonjour le monde', target: 'en' });
    assert.deepEqual(stored, [{ user: 'u1', message: 7, target: 'en', source: 'fr', provider: 'trad_a', text: 'Hello world' }]);
    assert.ok(!JSON.stringify(out).includes(KEY));
  } finally { p.server.close(); }
});

test('connecteur générique : en-tête, champs et chemin de réponse réglables', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { data: { items: [{ out: 'Hi' }] } }));
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a', TRANSLATE_AUTH_HEADER: 'X-Api-Key', TRANSLATE_AUTH_SCHEME: '',
      TRANSLATE_FIELD_TEXT: 'q', TRANSLATE_FIELD_TARGET: 'to', TRANSLATE_RESULT_PATH: 'data.items.0.out' }));
    const r = await translateWith(cfg, 'Salut', 'en', fetch);
    assert.deepEqual(r, { ok: true, text: 'Hi', source: null });
    assert.equal(p.calls[0].headers['x-api-key'], KEY);
    assert.equal(p.calls[0].headers.authorization, undefined);
    assert.deepEqual(p.calls[0].body, { q: 'Salut', to: 'en' });
    assert.equal(readPath({ a: { b: [1, 2] } }, 'a.b.1'), 2);
  } finally { p.server.close(); }
});

test('registre sans fournisseur actif (RPC not_configured) ou fournisseur différent : 503, fournisseur non appelé', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { translation: 'SIMULÉ' }));
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
    for (const data of [{ status: 'not_configured' }, { status: 'pending', text: 'x', provider: 'autre' }]) {
      const { d, stored } = deps(cfg, { requestTranslation: async () => ({ data, error: null }) });
      const out = await processTranslate({ message_id: 1, target_lang: 'en' }, d);
      assert.equal(out.status, 503);
      assert.equal(out.body.code, 'not_configured');
      assert.equal(stored.length, 0);
    }
    assert.equal(p.calls.length, 0);
  } finally { p.server.close(); }
});

test('cache : traduction déjà connue renvoyée sans appeler le fournisseur', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { translation: 'SIMULÉ' }));
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
    const { d } = deps(cfg, { requestTranslation: async () => ({ data: { status: 'translated', text: 'Hello', source_lang: 'fr', target_lang: 'en', cached: true }, error: null }) });
    const out = await processTranslate({ message_id: 1, target_lang: 'en' }, d);
    assert.deepEqual([out.status, out.body.text, out.body.cached], [200, 'Hello', true]);
    assert.equal(p.calls.length, 0);
  } finally { p.server.close(); }
});

test('droits : non connecté 401 ; message étranger 404 sans appel au fournisseur ; entrées invalides 400', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { translation: 'x' }));
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
    assert.equal((await processTranslate({ message_id: 1, target_lang: 'en' }, deps(cfg, { userId: null }).d)).status, 401);
    const foreign = deps(cfg, { requestTranslation: async () => ({ data: null, error: { message: 'Message introuvable' } }) }).d;
    const out = await processTranslate({ message_id: 1, target_lang: 'en' }, foreign);
    assert.deepEqual([out.status, out.body.code], [404, 'not_found']);
    for (const bad of [{ message_id: '1', target_lang: 'en' }, { message_id: -3, target_lang: 'en' }, { message_id: 1, target_lang: 'x; drop' }, { message_id: 1 }, null, 'texte']) {
      assert.equal((await processTranslate(bad, deps(cfg).d)).status, 400, JSON.stringify(bad));
    }
    assert.equal(p.calls.length, 0);
  } finally { p.server.close(); }
});

test('sonde d\'état : 200 sans appel quand configuré', async () => {
  const cfg = loadConfig(env({ TRANSLATE_API_URL: 'https://exemple.org/t', TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
  const out = await processTranslate({ status: true }, deps(cfg, { fetchFn: () => { throw new Error('ne doit pas être appelé'); } }).d);
  assert.deepEqual([out.status, out.body.enabled], [200, true]);
});

test('erreurs du fournisseur : 502, rien n\'est enregistré, aucun texte', async () => {
  for (const [label, handler] of [
    ['http 500', (c, res) => reply(res, 500, { translation: 'ne pas utiliser' })],
    ['json invalide', (c, res) => reply(res, 200, 'pas du json')],
    ['résultat vide', (c, res) => reply(res, 200, { translation: '   ' })],
    ['résultat non textuel', (c, res) => reply(res, 200, { translation: { x: 1 } })],
  ]) {
    const p = await fakeProvider(handler);
    try {
      const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
      const { d, stored } = deps(cfg);
      const out = await processTranslate({ message_id: 1, target_lang: 'en' }, d);
      assert.deepEqual([out.status, out.body.code], [502, 'provider_error'], label);
      assert.ok(!('text' in out.body), label);
      assert.equal(stored.length, 0, label);
    } finally { p.server.close(); }
  }
});

test('délai dépassé et fournisseur injoignable : échec propre', async () => {
  const slow = await fakeProvider(() => { /* ne répond jamais */ });
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: slow.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
    assert.deepEqual(await translateWith(cfg, 'x', 'en', fetch, 150), { ok: false, reason: 'timeout' });
  } finally { slow.server.closeAllConnections(); slow.server.close(); }
  const cfg = loadConfig(env({ TRANSLATE_API_URL: 'http://127.0.0.1:1/t', TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
  assert.deepEqual(await translateWith(cfg, 'x', 'en', fetch, 2000), { ok: false, reason: 'network' });
});

test('échec d\'enregistrement du cache : 502, pas de succès affiché', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { translation: 'Hello' }));
  try {
    const cfg = loadConfig(env({ TRANSLATE_API_URL: p.url, TRANSLATE_API_KEY: KEY, TRANSLATE_PROVIDER_CODE: 'trad_a' }));
    const { d } = deps(cfg, { storeTranslation: async () => ({ data: null, error: { message: 'boom' } }) });
    const out = await processTranslate({ message_id: 1, target_lang: 'en' }, d);
    assert.equal(out.status, 502);
    assert.ok(!('text' in out.body));
  } finally { p.server.close(); }
});
