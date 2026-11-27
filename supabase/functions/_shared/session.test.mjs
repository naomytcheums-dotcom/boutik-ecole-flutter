// Test Node du contrôle serveur de session des Edge Functions (_shared/session.ts) contre de FAUX services (aucun appel réseau, aucune clé réelle).
// Exécution : node --test supabase/functions/_shared/session.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyCaller, sessionIdOf, claimsOf } from './session.ts';

const UID = '00000000-0000-0000-0000-000000000001';
const SID = '00000000-0000-0000-0000-0000000000a1';
const jwt = (claims) => `Bearer ${Buffer.from('{"alg":"HS256"}').toString('base64url')}.${Buffer.from(JSON.stringify(claims)).toString('base64url')}.signature`;
const H = jwt({ sub: UID, session_id: SID, role: 'authenticated' });

// faux GoTrue + faux base : `sessions` = sessions ouvertes, `suspended` = comptes suspendus
function fake({ getUser = UID, sessions = new Set([SID]), suspended = new Set(), dbDown = false, getUserThrows = false } = {}) {
  const calls = { getUser: 0, status: [] };
  return {
    calls,
    deps: {
      getUserId: async () => { calls.getUser++; if (getUserThrows) throw new Error('reseau'); return getUser; },
      sessionStatus: async (uid, sid) => {
        calls.status.push([uid, sid]);
        if (dbDown) return null;
        if (sid && !sessions.has(sid)) return 'session_revoked';
        return suspended.has(uid) ? 'suspended' : 'ok';
      },
    },
  };
}

test('session ouverte, compte actif : accepte, identite issue de GoTrue', async () => {
  const f = fake();
  const r = await verifyCaller(H, f.deps);
  assert.deepEqual(r, { ok: true, uid: UID, sessionId: SID });
  assert.equal(f.calls.getUser, 1);
  assert.deepEqual(f.calls.status, [[UID, SID]]);
});

test('jeton valide cryptographiquement mais session supprimee : 401 session_revoked (meme si GoTrue repond encore)', async () => {
  const r = await verifyCaller(H, fake({ sessions: new Set() }).deps);
  assert.equal(r.ok, false);
  assert.equal(r.status, 401);
  assert.equal(r.body.code, 'session_revoked');
  assert.match(r.body.message, /Session expirée ou révoquée, reconnectez-vous/);
});

test('GoTrue refuse le jeton (session absente) : le motif session_revoked est precise si la base le confirme', async () => {
  const r = await verifyCaller(H, fake({ getUser: null, sessions: new Set() }).deps);
  assert.equal(r.ok, false);
  assert.equal(r.status, 401);
  assert.equal(r.body.code, 'session_revoked');
});

test('GoTrue refuse le jeton et la session existe (jeton expire ou falsifie) : 401 unauthorized, jamais accepte', async () => {
  const r = await verifyCaller(H, fake({ getUser: null }).deps);
  assert.equal(r.ok, false);
  assert.equal(r.status, 401);
  assert.equal(r.body.code, 'unauthorized');
});

test('compte suspendu avec session encore presente : 403 account_suspended', async () => {
  const r = await verifyCaller(H, fake({ suspended: new Set([UID]) }).deps);
  assert.equal(r.ok, false);
  assert.equal(r.status, 403);
  assert.equal(r.body.code, 'account_suspended');
});

test('verification de session indisponible : refus (503), jamais acceptation par defaut', async () => {
  const r = await verifyCaller(H, fake({ dbDown: true }).deps);
  assert.equal(r.ok, false);
  assert.equal(r.status, 503);
  assert.equal(r.body.code, 'session_check_unavailable');
});

test('erreur reseau vers GoTrue : refus', async () => {
  const r = await verifyCaller(H, fake({ getUserThrows: true }).deps);
  assert.equal(r.ok, false);
  assert.equal(r.status, 401);
});

test('un sub ou un session_id forges dans le jeton ne donnent aucune identite : seule la reponse de GoTrue compte', async () => {
  const forged = jwt({ sub: '00000000-0000-0000-0000-0000000000ff', session_id: SID });
  const r = await verifyCaller(forged, fake({ getUser: null }).deps);
  assert.equal(r.ok, false);
  const r2 = await verifyCaller(forged, fake({ getUser: UID }).deps);
  assert.equal(r2.ok && r2.uid, UID);
});

test('sans en-tete, jeton mal forme ou sans session_id', async () => {
  assert.equal((await verifyCaller('', fake({ getUser: null }).deps)).ok, false);
  assert.equal((await verifyCaller('Bearer abc', fake({ getUser: null }).deps)).ok, false);
  assert.equal(sessionIdOf('Bearer abc'), null);
  assert.equal(sessionIdOf(jwt({ sub: UID })), null);
  assert.equal(sessionIdOf(jwt({ sub: UID, session_id: 'pas-un-uuid' })), null);
  assert.equal(sessionIdOf(H), SID);
  assert.deepEqual(claimsOf(undefined), {});
  // ancien format sans session_id : la base controle quand meme le compte
  const f = fake({ suspended: new Set([UID]) });
  const r = await verifyCaller(jwt({ sub: UID }), f.deps);
  assert.equal(r.status, 403);
  assert.deepEqual(f.calls.status, [[UID, null]]);
});
