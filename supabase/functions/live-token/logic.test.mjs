// Test Node de « live-token » : jetons LiveKit (structure, droits, signature, durée) et décision d'accès (aucun serveur, aucun secret réel).
// Exécution : node --test supabase/functions/live-token/logic.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { livekitToken, livekitAdminToken, liveTokenDecision } from './logic.ts';

const dec = (x) => JSON.parse(Buffer.from(x, 'base64url').toString());
const verify = (t, secret) => {
  const [h, p, s] = t.split('.');
  return crypto.createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url') === s;
};

test('jeton : HS256, signature valide, durée demandée, spectateur sans droit de publier', async () => {
  const t = await livekitToken('APIkey', 'secret-de-test', 'user-1', 'Awa', 'live-abc', true, 600);
  const [h, p] = t.split('.');
  assert.equal(dec(h).alg, 'HS256');
  const c = dec(p);
  assert.equal(c.iss, 'APIkey'); assert.equal(c.sub, 'user-1'); assert.equal(c.exp - c.iat, 600);
  assert.deepEqual(c.video, { room: 'live-abc', roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true });
  assert.equal(verify(t, 'secret-de-test'), true);
  assert.equal(verify(t, 'autre-secret'), false);
  const v = dec((await livekitToken('APIkey', 'secret-de-test', 'user-2', 'Paul', 'live-abc', false)).split('.')[1]);
  assert.equal(v.video.canPublish, false); assert.equal(v.video.canPublishData, false); assert.equal(v.exp - v.iat, 7200);
  assert.equal(JSON.stringify(c).includes('secret-de-test'), false, 'le secret n\'est jamais dans le jeton');
});

test('jeton d\'administration de salle : 60 s, roomAdmin sur UNE salle, aucun droit de publier', async () => {
  const t = await livekitAdminToken('APIkey', 'secret-de-test', 'live-abc');
  const c = dec(t.split('.')[1]);
  assert.equal(c.exp - c.iat, 60); assert.deepEqual(c.video, { roomAdmin: true, room: 'live-abc' });
  assert.equal(verify(t, 'secret-de-test'), true);
});

const live = (o = {}) => ({ host_id: 'H', status: 'live', room_name: 'live-abc', ...o });
const f = (o = {}) => ({ uid: 'V', live: live(), banned: false, suspended: false, access: { allowed: true }, accessError: false, coApproved: false, ...o });

test('décision : live introuvable ou annulé -> 404', () => {
  assert.equal(liveTokenDecision(f({ live: null })).status, 404);
  assert.equal(liveTokenDecision(f({ live: live({ status: 'cancelled' }) })).status, 404);
  assert.equal(liveTokenDecision(f({ uid: 'H', live: live({ status: 'cancelled' }) })).status, 404);
});

test('décision : spectateur seulement quand le live est en direct, jamais banni ni suspendu', () => {
  assert.deepEqual(liveTokenDecision(f()).grant, { role: 'viewer', canPublish: false, ttlSec: 3600 });
  for (const status of ['scheduled', 'ended']) assert.equal(liveTokenDecision(f({ live: live({ status }) })).status, 409);
  assert.equal(liveTokenDecision(f({ banned: true })).status, 403);
  assert.equal(liveTokenDecision(f({ banned: true })).body.error, 'banned');
  assert.equal(liveTokenDecision(f({ suspended: true })).body.error, 'suspended');
});

test('décision : règle d\'accès unique ; lecture en échec = refus (503), jamais ouverture par défaut', () => {
  assert.equal(liveTokenDecision(f({ accessError: true })).status, 503);
  assert.equal(liveTokenDecision(f({ access: null })).status, 503);
  const r = liveTokenDecision(f({ access: { allowed: false, reason: 'prive', message: 'Live privé : invitation requise.' } }));
  assert.equal(r.status, 403); assert.equal(r.body.error, 'prive'); assert.equal(r.body.message, 'Live privé : invitation requise.');
  assert.equal(liveTokenDecision(f({ access: { allowed: false } })).body.error, 'forbidden');
  assert.equal(liveTokenDecision(f({ access: {} })).status, 403, 'allowed doit valoir exactement true');
  assert.equal(liveTokenDecision(f({ access: { allowed: 'true' } })).status, 403);
});

test('décision : l\'hôte publie (2 h), sauf live terminé ou compte suspendu ; le co-diffuseur approuvé publie (1 h)', () => {
  assert.deepEqual(liveTokenDecision(f({ uid: 'H', access: null })).grant, { role: 'host', canPublish: true, ttlSec: 7200 });
  assert.deepEqual(liveTokenDecision(f({ uid: 'H', live: live({ status: 'scheduled' }), access: null })).grant, { role: 'host', canPublish: true, ttlSec: 7200 });
  assert.equal(liveTokenDecision(f({ uid: 'H', live: live({ status: 'ended' }) })).status, 409);
  assert.equal(liveTokenDecision(f({ uid: 'H', suspended: true })).status, 403);
  assert.deepEqual(liveTokenDecision(f({ coApproved: true })).grant, { role: 'cohost', canPublish: true, ttlSec: 3600 });
  assert.equal(liveTokenDecision(f({ coApproved: true, banned: true })).status, 403, 'un co-diffuseur banni est refusé');
  assert.equal(liveTokenDecision(f({ coApproved: true, access: { allowed: false, reason: 'prive' } })).status, 403);
  assert.equal(liveTokenDecision(f({ uid: 'H', coApproved: true })).grant.role, 'host');
});
