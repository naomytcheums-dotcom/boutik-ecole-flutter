// Test Node de la logique « live-record » contre un FAUX serveur LiveKit local (aucun service réel, aucune clé réelle).
// Exécution : node --test supabase/functions/live-record/logic.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { loadRecorderConfig, processRecord, egressToken } from './logic.ts';

const LIVE = '11111111-1111-4111-8111-111111111111';
const REC = '22222222-2222-4222-8222-222222222222';
const USER = '33333333-3333-4333-8333-333333333333';

function fakeLivekit(handler) {
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
const FULL = (url) => ({ LIVEKIT_URL: url, LIVEKIT_API_KEY: 'cle-bench', LIVEKIT_API_SECRET: 'secret-de-banc', LIVEKIT_EGRESS_S3_ENDPOINT: 'https://s3.exemple.test/storage/v1/s3', LIVEKIT_EGRESS_S3_ACCESS_KEY: 'ak', LIVEKIT_EGRESS_S3_SECRET: 'sk' });

function depsFor(env, { start = { ok: true, recording_id: REC, live_id: LIVE, room_name: 'live-abc' }, stop = { ok: true, recording_id: REC, egress_id: 'EG-1' }, claim = true } = {}) {
  const log = { checks: [], claims: [], started: [], stopping: [], failed: [] };
  return {
    log,
    deps: {
      env, fetchFn: fetch, userId: USER,
      startCheck: async (l, u) => { log.checks.push(['start', l, u]); return start; },
      stopCheck: async (l, u) => { log.checks.push(['stop', l, u]); return stop; },
      claim: async (r) => { log.claims.push(r); return claim; },
      started: async (r, e) => { log.started.push([r, e]); },
      stopping: async (r) => { log.stopping.push(r); },
      failed: async (r, d) => { log.failed.push([r, d]); },
    },
  };
}

test('configuration : incomplète -> null ; wss converti en https ; valeurs par défaut du stockage', () => {
  assert.equal(loadRecorderConfig(envOf({})), null);
  const { LIVEKIT_EGRESS_S3_SECRET, ...sansSecret } = FULL('wss://x.exemple.test');
  assert.equal(loadRecorderConfig(envOf(sansSecret)), null);
  const c = loadRecorderConfig(envOf(FULL('wss://x.exemple.test/')));
  assert.equal(c.httpUrl, 'https://x.exemple.test'); assert.equal(c.s3.bucket, 'live-replays'); assert.equal(c.s3.region, 'us-east-1');
});

test('sans configuration : not_configured (503), aucune vérification, aucun appel, rien de simulé', async () => {
  const { deps, log } = depsFor(envOf({}));
  const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
  assert.equal(o.status, 503); assert.equal(o.body.error, 'not_configured');
  assert.equal(log.checks.length + log.claims.length + log.started.length, 0);
});

test('demande invalide : 400', async () => {
  const { deps } = depsFor(envOf(FULL('http://127.0.0.1:1')));
  for (const b of [null, {}, { live_id: 'x', action: 'start' }, { live_id: LIVE, action: 'detruire' }]) assert.equal((await processRecord(b, deps)).status, 400);
});

test('start : le serveur confirme, verrou pris, egress démarré chez le faux LiveKit, identifiant enregistré', async () => {
  const lk = await fakeLivekit((c, res) => reply(res, 200, { egress_id: 'EG-42', status: 'EGRESS_STARTING' }));
  const { deps, log } = depsFor(envOf(FULL(lk.url)));
  const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
  lk.server.close();
  assert.equal(o.status, 200); assert.equal(o.body.state, 'recording');
  assert.deepEqual(log.checks[0], ['start', LIVE, USER]); assert.deepEqual(log.claims, [REC]); assert.deepEqual(log.started, [[REC, 'EG-42']]);
  assert.equal(lk.calls.length, 1); assert.equal(lk.calls[0].url, '/twirp/livekit.Egress/StartRoomCompositeEgress');
  assert.equal(lk.calls[0].body.room_name, 'live-abc');
  assert.equal(lk.calls[0].body.file_outputs[0].filepath, `${LIVE}/${REC}.mp4`);
  assert.equal(lk.calls[0].body.file_outputs[0].s3.bucket, 'live-replays');
  const jwt = lk.calls[0].headers.authorization.replace('Bearer ', '');
  assert.equal(jwt.split('.').length, 3);
  assert.equal(JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString()).video.roomRecord, true);
});

test('start : refus du serveur (consentement, non autorisé, pas en direct) : rien n\'est envoyé à LiveKit', async () => {
  const lk = await fakeLivekit((c, res) => reply(res, 200, { egress_id: 'EG-X' }));
  for (const [reason, status] of [['consentement_manquant', 409], ['non_autorise', 403], ['pas_en_direct', 409], ['introuvable', 404], ['non_configure', 503]]) {
    const { deps, log } = depsFor(envOf(FULL(lk.url)), { start: { ok: false, reason, message: 'refus' } });
    const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
    assert.equal(o.status, status, reason); assert.equal(o.body.error, reason); assert.equal(log.claims.length, 0);
  }
  lk.server.close();
  assert.equal(lk.calls.length, 0);
});

test('start : vérification en échec (RPC) -> 503, jamais d\'ouverture par défaut', async () => {
  const lk = await fakeLivekit((c, res) => reply(res, 200, { egress_id: 'EG-X' }));
  const { deps } = depsFor(envOf(FULL(lk.url)), { start: null });
  const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
  lk.server.close();
  assert.equal(o.status, 503); assert.equal(lk.calls.length, 0);
});

test('start : verrou déjà pris -> 409, LiveKit non appelé', async () => {
  const lk = await fakeLivekit((c, res) => reply(res, 200, { egress_id: 'EG-X' }));
  const { deps, log } = depsFor(envOf(FULL(lk.url)), { claim: false });
  const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
  lk.server.close();
  assert.equal(o.status, 409); assert.equal(o.body.error, 'deja_demarre'); assert.equal(lk.calls.length, 0); assert.equal(log.started.length, 0);
});

test('start : LiveKit en erreur / sans identifiant / injoignable -> échec enregistré, 502, aucun « démarré »', async () => {
  for (const handler of [(c, res) => reply(res, 500, { code: 'internal' }), (c, res) => reply(res, 200, { status: 'EGRESS_STARTING' })]) {
    const lk = await fakeLivekit(handler);
    const { deps, log } = depsFor(envOf(FULL(lk.url)));
    const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
    lk.server.close();
    assert.equal(o.status, 502); assert.equal(log.started.length, 0); assert.equal(log.failed.length, 1); assert.equal(log.failed[0][0], REC);
  }
  const { deps, log } = depsFor(envOf(FULL('http://127.0.0.1:1')));
  const o = await processRecord({ live_id: LIVE, action: 'start' }, deps);
  assert.equal(o.status, 502); assert.match(log.failed[0][1], /injoignable/);
});

test('stop : egress arrêté chez le faux LiveKit puis état « arrêt en cours »', async () => {
  const lk = await fakeLivekit((c, res) => reply(res, 200, { egress_id: 'EG-1', status: 'EGRESS_ENDING' }));
  const { deps, log } = depsFor(envOf(FULL(lk.url)));
  const o = await processRecord({ live_id: LIVE, action: 'stop' }, deps);
  lk.server.close();
  assert.equal(o.status, 200); assert.equal(o.body.state, 'processing');
  assert.equal(lk.calls[0].url, '/twirp/livekit.Egress/StopEgress'); assert.equal(lk.calls[0].body.egress_id, 'EG-1'); assert.deepEqual(log.stopping, [REC]);
});

test('stop : aucun enregistrement en cours / non autorisé : refus, LiveKit non appelé', async () => {
  const lk = await fakeLivekit((c, res) => reply(res, 200, {}));
  for (const [reason, status] of [['aucun_enregistrement_en_cours', 409], ['non_autorise', 403]]) {
    const { deps } = depsFor(envOf(FULL(lk.url)), { stop: { ok: false, reason, message: 'refus' } });
    const o = await processRecord({ live_id: LIVE, action: 'stop' }, deps);
    assert.equal(o.status, status);
  }
  lk.server.close();
  assert.equal(lk.calls.length, 0);
});

test('egressToken : JWT HS256 valable 60 s avec le droit roomRecord, jamais le secret', async () => {
  const t = await egressToken('cle', 'secret-de-banc');
  const [h, p] = t.split('.').slice(0, 2).map((x) => JSON.parse(Buffer.from(x, 'base64url').toString()));
  assert.equal(h.alg, 'HS256'); assert.equal(p.iss, 'cle'); assert.equal(p.exp - p.iat, 60); assert.ok(!t.includes('secret-de-banc'));
});
