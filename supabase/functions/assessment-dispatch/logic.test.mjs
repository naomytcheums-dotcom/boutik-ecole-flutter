// Test Node de la logique « assessment-dispatch » contre un FAUX fournisseur local (aucun service réel, aucune clé réelle).
// Exécution : node --test supabase/functions/assessment-dispatch/logic.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { loadProviderConfig, processDispatch, processCallback, processHealth, isAuthorizedCaller, configPresence, parseTimestamp, hmacHex } from './logic.ts';

const REQ = '11111111-1111-4111-8111-111111111111';
const SECRET = 'secret-de-banc';

function fakeProvider(handler) {
  const calls = [];
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => { const call = { url: req.url, headers: req.headers, body: raw ? JSON.parse(raw) : null }; calls.push(call); handler(call, res); });
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, calls, url: `http://127.0.0.1:${server.address().port}` })));
}
const reply = (res, status, obj) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(obj)); };
const envOf = (o) => (n) => o[n];

function depsFor(env, active, claimed) {
  const log = { accepted: [], failed: [], claimedWith: null };
  return {
    log,
    deps: {
      env, fetchFn: fetch, callbackUrl: 'https://proj.supabase.co/functions/v1/assessment-dispatch',
      listActiveProviders: async () => active,
      claim: async (providers) => { log.claimedWith = providers; return claimed; },
      accepted: async (id, ref, url) => { log.accepted.push({ id, ref, url }); },
      failed: async (id, httpCode, detail) => { log.failed.push({ id, httpCode, detail }); },
    },
  };
}
const CLAIM = { request_id: REQ, provider: 'prov_test', family: 'informatique', mode: 'questionnaire', attempt: 1 };

test('configuration : sans URL https/clé -> null ; code invalide -> null', () => {
  assert.equal(loadProviderConfig('prov_test', envOf({})), null);
  assert.equal(loadProviderConfig('prov_test', envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'ftp://x', ASSESSMENT_PROV_TEST_API_KEY: 'k' })), null);
  assert.equal(loadProviderConfig('Bad Code', envOf({})), null);
  const c = loadProviderConfig('prov_test', envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'https://api.exemple.test/', ASSESSMENT_PROV_TEST_API_KEY: 'k' }));
  assert.equal(c.baseUrl, 'https://api.exemple.test'); assert.equal(c.webhookSecret, null);
});

test('dispatch : aucun fournisseur actif -> rien ; actif mais non configuré -> 503 not_configured, rien réclamé', async () => {
  let { deps, log } = depsFor(envOf({}), [], [CLAIM]);
  let o = await processDispatch(deps); assert.equal(o.status, 200); assert.equal(log.claimedWith, null);
  ({ deps, log } = depsFor(envOf({}), ['prov_test'], [CLAIM]));
  o = await processDispatch(deps); assert.equal(o.status, 503); assert.equal(o.body.code, 'not_configured'); assert.equal(log.claimedWith, null); assert.equal(log.accepted.length + log.failed.length, 0);
});

test('dispatch : envoi au faux fournisseur, aucune donnée personnelle, acceptation enregistrée', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { external_ref: 'EXT-9', candidate_url: 'https://passer.exemple.test/e/9' }));
  const env = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: p.url, ASSESSMENT_PROV_TEST_API_KEY: 'cle-bench', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: SECRET });
  const { deps, log } = depsFor(env, ['prov_test', 'autre_prov'], [CLAIM]);
  const o = await processDispatch(deps);
  assert.equal(o.status, 200); assert.deepEqual(log.claimedWith, ['prov_test']);
  assert.equal(p.calls.length, 1); assert.equal(p.calls[0].url, '/assessments'); assert.equal(p.calls[0].headers.authorization, 'Bearer cle-bench');
  assert.deepEqual(Object.keys(p.calls[0].body).sort(), ['callback_url', 'family', 'mode', 'reference']);
  assert.match(p.calls[0].body.callback_url, /provider=prov_test$/);
  assert.deepEqual(log.accepted, [{ id: REQ, ref: 'EXT-9', url: 'https://passer.exemple.test/e/9' }]); assert.equal(log.failed.length, 0);
  p.server.close();
});

test('dispatch : refus HTTP 500, réponse sans external_ref et URL non https -> échec ou lien ignoré, jamais une acceptation inventée', async () => {
  let mode = 500;
  const p = await fakeProvider((c, res) => (mode === 500 ? reply(res, 500, { error: 'x' }) : mode === 'noref' ? reply(res, 200, { ok: true }) : reply(res, 200, { external_ref: 'E', candidate_url: 'http://pas-https.test/x' })));
  const env = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: p.url, ASSESSMENT_PROV_TEST_API_KEY: 'k', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: SECRET });
  let { deps, log } = depsFor(env, ['prov_test'], [CLAIM]);
  await processDispatch(deps); assert.equal(log.failed[0].httpCode, 500); assert.equal(log.accepted.length, 0);
  mode = 'noref'; ({ deps, log } = depsFor(env, ['prov_test'], [CLAIM]));
  await processDispatch(deps); assert.match(log.failed[0].detail, /external_ref/); assert.equal(log.accepted.length, 0);
  mode = 'http'; ({ deps, log } = depsFor(env, ['prov_test'], [CLAIM]));
  await processDispatch(deps); assert.equal(log.accepted[0].url, null);
  p.server.close();
});

test('dispatch : fournisseur injoignable -> échec lisible', async () => {
  const env = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'http://127.0.0.1:1', ASSESSMENT_PROV_TEST_API_KEY: 'k', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: SECRET });
  const { deps, log } = depsFor(env, ['prov_test'], [CLAIM]);
  await processDispatch(deps); assert.equal(log.failed.length, 1); assert.equal(log.failed[0].detail, 'fournisseur injoignable');
});

// ------------------------------------------------------------ rappel
const ENV_CB = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'https://api.exemple.test', ASSESSMENT_PROV_TEST_API_KEY: 'k', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: SECRET });
function cbDeps(over = {}) {
  const seen = { result: null, failed: null };
  return { seen, deps: { env: ENV_CB, providerActive: async () => true,
    result: async (a) => { seen.result = a; return { data: { ok: true }, error: null }; },
    providerFailed: async (r, p, d) => { seen.failed = { r, p, d }; return { data: { ok: true }, error: null }; }, ...over } };
}
const good = { reference: REQ, external_ref: 'EXT-9', status: 'completed', competences: [{ name: 'SQL', level: 'intermediaire' }], criteria: [{ name: 'Requêtes', score: 7, max_score: 10 }], evidence: [], details: {}, limits: 'Questionnaire à distance : gestes non observés.', recommendations: [] };
const sign = async (raw) => 'sha256=' + (await hmacHex(SECRET, raw));

test('rappel : sans secret configuré -> 503 ; signature absente ou fausse -> 401, rien enregistré', async () => {
  const raw = JSON.stringify(good);
  let { deps, seen } = cbDeps({ env: envOf({}) });
  assert.equal((await processCallback('prov_test', raw, await sign(raw), deps)).status, 503);
  ({ deps, seen } = cbDeps());
  assert.equal((await processCallback('prov_test', raw, null, deps)).status, 401);
  assert.equal((await processCallback('prov_test', raw, 'sha256=' + '0'.repeat(64), deps)).status, 401);
  assert.equal(seen.result, null);
});

test('rappel : fournisseur non actif -> 409 ; résultat valide signé -> enregistré tel quel (rien ajouté)', async () => {
  const raw = JSON.stringify(good);
  let { deps, seen } = cbDeps({ providerActive: async () => false });
  assert.equal((await processCallback('prov_test', raw, await sign(raw), deps)).status, 409); assert.equal(seen.result, null);
  ({ deps, seen } = cbDeps());
  const o = await processCallback('prov_test', raw, await sign(raw), deps);
  assert.equal(o.status, 200); assert.equal(seen.result.request, REQ); assert.equal(seen.result.limits, good.limits); assert.deepEqual(seen.result.competences, good.competences);
});

test('rappel : corps invalides refusés (limites vides, compétences vides, référence, statut, forme) ; échec du fournisseur transmis', async () => {
  const cases = [
    [{ ...good, limits: '  ' }, 'missing_limits'], [{ ...good, competences: [] }, 'bad_competences'], [{ ...good, reference: 'x' }, 'bad_reference'],
    [{ ...good, status: 'weird' }, 'bad_status'], [{ ...good, criteria: 'x' }, 'bad_criteria'], [{ ...good, details: [] }, 'bad_shape'],
  ];
  for (const [body, code] of cases) {
    const raw = JSON.stringify(body); const { deps, seen } = cbDeps();
    const o = await processCallback('prov_test', raw, await sign(raw), deps);
    assert.equal(o.status, 400, code); assert.equal(o.body.code, code); assert.equal(seen.result, null);
  }
  const raw = JSON.stringify({ reference: REQ, status: 'failed', detail: 'abandon' }); const { deps, seen } = cbDeps();
  assert.equal((await processCallback('prov_test', raw, await sign(raw), deps)).status, 200); assert.equal(seen.failed.d, 'abandon');
});

test('rappel : refus du serveur (garde-fous SQL) -> 422 ; doublon -> 200 duplicate ; demande non en cours -> 409', async () => {
  const raw = JSON.stringify(good); const sig = await sign(raw);
  let { deps } = cbDeps({ result: async () => ({ data: { ok: false, reason: 'result_rejected' }, error: null }) });
  assert.equal((await processCallback('prov_test', raw, sig, deps)).status, 422);
  ({ deps } = cbDeps({ result: async () => ({ data: { ok: true, duplicate: true }, error: null }) }));
  const d = await processCallback('prov_test', raw, sig, deps); assert.equal(d.status, 200); assert.equal(d.body.duplicate, true);
  ({ deps } = cbDeps({ result: async () => ({ data: { ok: false, reason: 'not_running' }, error: null }) }));
  assert.equal((await processCallback('prov_test', raw, sig, deps)).status, 409);
  ({ deps } = cbDeps({ result: async () => ({ data: null, error: 'boom' }) }));
  assert.equal((await processCallback('prov_test', raw, sig, deps)).status, 422);
});

// ------------------------------------------------------------ H13 : trois secrets, santé, horodatage, appelant autorisé
test('dispatch : sans secret de rappel le fournisseur n\'est PAS configuré (rien réclamé, rien envoyé)', async () => {
  const p = await fakeProvider((c, res) => reply(res, 200, { external_ref: 'X' }));
  const env = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: p.url, ASSESSMENT_PROV_TEST_API_KEY: 'k' });
  const { deps, log } = depsFor(env, ['prov_test'], [CLAIM]);
  const o = await processDispatch(deps);
  assert.equal(o.status, 503); assert.equal(o.body.code, 'not_configured'); assert.equal(log.claimedWith, null); assert.equal(p.calls.length, 0);
  p.server.close();
});

test('configPresence : booléens seulement, URL http(s) exigée, code invalide -> tout faux', () => {
  assert.deepEqual(configPresence('prov_test', envOf({})), { base_url: false, api_key: false, webhook_secret: false });
  assert.deepEqual(configPresence('prov_test', envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'ftp://x', ASSESSMENT_PROV_TEST_API_KEY: ' ', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: 's' })), { base_url: false, api_key: false, webhook_secret: true });
  assert.deepEqual(configPresence('Bad Code', ENV_CB), { base_url: false, api_key: false, webhook_secret: false });
});

test('santé : rapport par fournisseur sans appel réseau ni valeur de secret ; actifs configurés comptés', async () => {
  let reported = null; let fetched = 0;
  const realFetch = globalThis.fetch; globalThis.fetch = async () => { fetched++; throw new Error('aucun appel attendu'); };
  try {
    const env = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'https://api.exemple.test', ASSESSMENT_PROV_TEST_API_KEY: 'cle-secrete-xyz', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: SECRET, ASSESSMENT_PROV_B_API_KEY: 'k' });
    const o = await processHealth({ env, listProviders: async () => [{ code: 'prov_test', status: 'actif' }, { code: 'prov_b', status: 'actif' }, { code: 'prov_c', status: 'candidat' }], report: async (rows) => { reported = rows; return { error: null }; } });
    assert.equal(o.status, 200); assert.deepEqual(o.body, { ok: true, providers: 3, active: 2, active_configured: 1, active_not_configured: 1 });
    assert.deepEqual(reported, [
      { provider: 'prov_test', base_url: true, api_key: true, webhook_secret: true },
      { provider: 'prov_b', base_url: false, api_key: true, webhook_secret: false },
      { provider: 'prov_c', base_url: false, api_key: false, webhook_secret: false },
    ]);
    assert.equal(fetched, 0);
    const text = JSON.stringify(reported) + JSON.stringify(o.body);
    assert.ok(!text.includes('cle-secrete-xyz') && !text.includes(SECRET) && !text.includes('api.exemple.test'), 'aucune valeur ne fuite');
  } finally { globalThis.fetch = realFetch; }
});

test('santé : aucun fournisseur -> aucun rapport écrit ; échec d\'écriture -> 500', async () => {
  let called = 0;
  let o = await processHealth({ env: envOf({}), listProviders: async () => [], report: async () => { called++; return { error: null }; } });
  assert.equal(o.status, 200); assert.equal(o.body.providers, 0); assert.equal(called, 0);
  o = await processHealth({ env: envOf({}), listProviders: async () => [{ code: 'prov_test', status: 'actif' }], report: async () => ({ error: 'boom' }) });
  assert.equal(o.status, 500); assert.equal(o.body.code, 'report_failed');
});

test('appelant : clé de service ou clé interne vérifiée par la base ; sinon refusé', async () => {
  const base = { serviceKey: 'SERVICE', checkDispatchKey: async (k) => k === 'CRON' };
  assert.equal(await isAuthorizedCaller({ ...base, bearer: 'SERVICE', dispatchKey: '' }), true);
  assert.equal(await isAuthorizedCaller({ ...base, bearer: '', dispatchKey: 'CRON' }), true);
  assert.equal(await isAuthorizedCaller({ ...base, bearer: 'AUTRE', dispatchKey: 'MAUVAISE' }), false);
  assert.equal(await isAuthorizedCaller({ ...base, bearer: '', dispatchKey: '' }), false);
  assert.equal(await isAuthorizedCaller({ serviceKey: '', bearer: '', dispatchKey: '', checkDispatchKey: async () => true }), false);
});

test('horodatage : absent -> contrat historique ; présent -> signé avec le corps, ±5 min, secondes ou millisecondes', () => {
  assert.equal(parseTimestamp('1700000000'), 1700000000); assert.equal(parseTimestamp('1700000000123'), 1700000000);
  for (const bad of ['abc', '17000', '', '1700000000.5', '-1700000000']) assert.equal(parseTimestamp(bad), null, bad);
});

test('rappel : horodatage valide et signé accepté ; périmé, futur, non signé, mal formé -> 401 sans rien enregistrer', async () => {
  const raw = JSON.stringify(good); const NOW = 1_800_000_000;
  const signTs = async (ts) => 'sha256=' + (await hmacHex(SECRET, `${ts}.${raw}`));
  const call = async (ts, sig, over = {}) => { const { deps, seen } = cbDeps({ now: () => NOW * 1000, ...over }); const o = await processCallback('prov_test', raw, sig, deps, ts); return { o, seen }; };
  let r = await call(String(NOW - 10), await signTs(NOW - 10));
  assert.equal(r.o.status, 200); assert.equal(r.seen.result.request, REQ);
  r = await call(String(NOW * 1000), await signTs(NOW * 1000)); assert.equal(r.o.status, 200, 'millisecondes acceptées');
  r = await call(String(NOW - 301), await signTs(NOW - 301)); assert.equal(r.o.status, 401); assert.equal(r.o.body.code, 'stale_timestamp'); assert.equal(r.seen.result, null);
  r = await call(String(NOW + 301), await signTs(NOW + 301)); assert.equal(r.o.status, 401); assert.equal(r.o.body.code, 'stale_timestamp');
  r = await call('pas-un-nombre', await signTs('pas-un-nombre')); assert.equal(r.o.status, 401); assert.equal(r.seen.result, null);
  // horodatage ajouté à un message dont la signature ne le couvre pas (rejeu avec horodatage neuf) : refusé
  r = await call(String(NOW), await sign(raw)); assert.equal(r.o.status, 401); assert.equal(r.o.body.code, 'bad_signature'); assert.equal(r.seen.result, null);
  // sans horodatage : contrat historique inchangé
  r = await call(null, await sign(raw)); assert.equal(r.o.status, 200);
});

test('rappel : ASSESSMENT_<CODE>_REQUIRE_TIMESTAMP=1 impose l\'en-tête', async () => {
  const raw = JSON.stringify(good);
  const env = envOf({ ASSESSMENT_PROV_TEST_BASE_URL: 'https://api.exemple.test', ASSESSMENT_PROV_TEST_API_KEY: 'k', ASSESSMENT_PROV_TEST_WEBHOOK_SECRET: SECRET, ASSESSMENT_PROV_TEST_REQUIRE_TIMESTAMP: '1' });
  const { deps, seen } = cbDeps({ env });
  const o = await processCallback('prov_test', raw, await sign(raw), deps, null);
  assert.equal(o.status, 401); assert.equal(o.body.code, 'timestamp_required'); assert.equal(seen.result, null);
});
