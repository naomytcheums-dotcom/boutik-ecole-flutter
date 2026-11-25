// Test Node de « live-egress-webhook » : événements signés comme LiveKit (JWT HS256 + empreinte SHA-256 du corps), aucun serveur réel.
// Exécution : node --test supabase/functions/live-egress-webhook/logic.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { processEgressWebhook, verifyWebhook } from './logic.ts';

const KEY = 'cle-bench', SECRET = 'secret-de-banc';
const env = (o = {}) => (n) => ({ LIVEKIT_API_KEY: KEY, LIVEKIT_API_SECRET: SECRET, ...o })[n];
const b64u = (x) => Buffer.from(x).toString('base64url');

function sign(raw, { key = KEY, secret = SECRET, exp = Math.floor(Date.now() / 1000) + 300, sha = null } = {}) {
  const h = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const p = b64u(JSON.stringify({ iss: key, exp, nbf: Math.floor(Date.now() / 1000) - 5, sha256: sha ?? crypto.createHash('sha256').update(raw).digest('base64') }));
  const s = crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${s}`;
}
function depsFor(e = env()) {
  const log = [];
  return { log, deps: { env: e, event: async (...a) => { log.push(a); return { data: 'pret', error: null }; } } };
}
const ended = (o = {}) => JSON.stringify({ event: 'egress_ended', egressInfo: { egressId: 'EG-9', status: 'EGRESS_COMPLETE', fileResults: [{ filename: 'live/rec.mp4', location: 'https://x/live/rec.mp4', duration: '312400000000', size: '123' }], ...o } });

test('sans clé LiveKit : not_configured (503), rien traité', async () => {
  const { deps, log } = depsFor(() => undefined);
  const raw = ended();
  const o = await processEgressWebhook(raw, sign(raw), deps);
  assert.equal(o.status, 503); assert.equal(log.length, 0);
});

test('signature absente, fausse, mauvaise clé, corps modifié, expirée : 401, rien traité', async () => {
  const raw = ended();
  for (const auth of [null, '', 'abc', sign(raw, { secret: 'autre' }), sign(raw, { key: 'autre' }), sign(raw, { exp: Math.floor(Date.now() / 1000) - 10 }), sign(ended({ egressId: 'EG-AUTRE' }))]) {
    const { deps, log } = depsFor();
    const o = await processEgressWebhook(raw, auth, deps);
    assert.equal(o.status, 401, String(auth)); assert.equal(log.length, 0);
  }
});

test('verifyWebhook : jeton valide accepté (avec ou sans préfixe Bearer)', async () => {
  const raw = ended();
  assert.equal(await verifyWebhook(raw, sign(raw), KEY, SECRET), true);
  assert.equal(await verifyWebhook(raw, 'Bearer ' + sign(raw), KEY, SECRET), true);
});

test('egress terminé : fichier et durée (ns -> s) transmis au serveur', async () => {
  const { deps, log } = depsFor();
  const raw = ended();
  const o = await processEgressWebhook(raw, sign(raw), deps);
  assert.equal(o.status, 200); assert.deepEqual(log[0], ['EG-9', 'complete', 'live/rec.mp4', 312, null]);
});

test('egress terminé sans fichier ni durée : transmis tel quel (le serveur le refuse), jamais de valeur inventée', async () => {
  const { deps, log } = depsFor();
  const raw = ended({ fileResults: [] });
  const o = await processEgressWebhook(raw, sign(raw), deps);
  assert.equal(o.status, 200); assert.deepEqual(log[0], ['EG-9', 'complete', null, null, null]);
});

test('egress actif / démarré, échoué, interrompu, limite sans fichier', async () => {
  const cases = [
    [{ status: 'EGRESS_ACTIVE', fileResults: undefined }, 'active', null],
    [{ status: 'EGRESS_STARTING', fileResults: undefined }, 'active', null],
    [{ status: 'EGRESS_FAILED', error: 'disque plein', fileResults: undefined }, 'failed', 'disque plein'],
    [{ status: 'EGRESS_ABORTED', fileResults: undefined }, 'failed', 'enregistrement interrompu'],
    [{ status: 'EGRESS_LIMIT_REACHED', fileResults: [] }, 'failed', "limite de l'enregistreur atteinte sans fichier exploitable"],
    [{ status: 4, error: 'x', fileResults: undefined }, 'failed', 'x'],
  ];
  for (const [info, status, error] of cases) {
    const { deps, log } = depsFor();
    const raw = ended(info);
    const o = await processEgressWebhook(raw, sign(raw), deps);
    assert.equal(o.status, 200); assert.equal(log[0][1], status); assert.equal(log[0][4], error);
  }
});

test('egress en cours de fin (ENDING) et événements étrangers : ignorés avec 200 (pas de nouvelle tentative)', async () => {
  const { deps, log } = depsFor();
  let raw = ended({ status: 'EGRESS_ENDING' });
  assert.equal((await processEgressWebhook(raw, sign(raw), deps)).status, 200);
  raw = JSON.stringify({ event: 'room_started', room: { name: 'r' } });
  const o = await processEgressWebhook(raw, sign(raw), deps);
  assert.equal(o.status, 200); assert.equal(o.body.ignored, 'room_started'); assert.equal(log.length, 0);
});

test('corps invalide ou sans identifiant d\'egress : 400', async () => {
  const { deps, log } = depsFor();
  let raw = '{pas du json';
  assert.equal((await processEgressWebhook(raw, sign(raw), deps)).status, 400);
  raw = JSON.stringify({ event: 'egress_ended', egressInfo: { status: 'EGRESS_COMPLETE' } });
  assert.equal((await processEgressWebhook(raw, sign(raw), deps)).status, 400);
  assert.equal(log.length, 0);
});

test('erreur de la base : 500 pour que LiveKit réessaie', async () => {
  const deps = { env: env(), event: async () => ({ data: null, error: 'boom' }) };
  const raw = ended();
  assert.equal((await processEgressWebhook(raw, sign(raw), deps)).status, 500);
});
