// Tests Node des gardes des outils de validation connectee (aucun appel vers un vrai service : serveur factice local uniquement).
//   node --test tool/connected/guards.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { assertTestEnvironment, GuardError, PROD_REF, isTestEmail } from './guards.mjs';
import { run as createAccounts, ACTORS, FIXTURES } from './create_test_accounts.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const jwt = (payload) => `${Buffer.from('{"alg":"HS256"}').toString('base64url')}.${Buffer.from(JSON.stringify(payload)).toString('base64url')}.sig`;
const TEST_URL = 'https://abcdefghijklmnopqrst.supabase.co';
const ok = { SUPABASE_URL: TEST_URL, ALLOW_TEST_PROJECT: '1' };
const refuses = (env, opts) => assert.throws(() => assertTestEnvironment(env, opts), (e) => e instanceof GuardError && /^REFUS/.test(e.message));

test('garde : refuse l\'URL de production (toutes les ecritures)', () => {
  refuses({ ...ok, SUPABASE_URL: `https://${PROD_REF}.supabase.co` });
  refuses({ ...ok, SUPABASE_URL: `https://${PROD_REF}.supabase.co/` });
  refuses({ ...ok, SUPABASE_URL: `HTTPS://${PROD_REF.toUpperCase()}.SUPABASE.CO` });
  refuses({ ...ok, SUPABASE_URL: `https://abcdefghijklmnopqrst.supabase.co/rest/v1/?ref=${PROD_REF}` });
  refuses({ ...ok, SUPABASE_URL: `https://x.supabase.co..example` });
});

test('garde : refuse sans ALLOW_TEST_PROJECT ou sans URL', () => {
  refuses({ SUPABASE_URL: TEST_URL });
  refuses({ SUPABASE_URL: TEST_URL, ALLOW_TEST_PROJECT: '' });
  refuses({ ALLOW_TEST_PROJECT: '1' });
});

test('garde : refuse un hote qui n\'est pas un projet Supabase ou localhost, et le http distant', () => {
  refuses({ ...ok, SUPABASE_URL: 'https://example.com' });
  refuses({ ...ok, SUPABASE_URL: 'https://supabase.co.evil.example' });
  refuses({ ...ok, SUPABASE_URL: 'http://abcdefghijklmnopqrst.supabase.co' });
  refuses({ ...ok, SUPABASE_URL: 'https://user:pass@abcdefghijklmnopqrst.supabase.co' });
  refuses({ ...ok, SUPABASE_URL: 'pas une url' });
});

test('garde : refuse une cle appartenant a la production (reference dans le jeton)', () => {
  refuses(ok, { keys: [jwt({ role: 'service_role', ref: PROD_REF })] });
  assert.doesNotThrow(() => assertTestEnvironment(ok, { keys: [jwt({ role: 'service_role', ref: 'abcdefghijklmnopqrst' }), 'cle-opaque'] }));
});

test('garde : accepte un projet de test explicite et localhost', () => {
  assert.equal(assertTestEnvironment(ok).host, 'abcdefghijklmnopqrst.supabase.co');
  assert.equal(assertTestEnvironment({ SUPABASE_URL: 'http://127.0.0.1:54321', ALLOW_TEST_PROJECT: '1' }).host, '127.0.0.1');
});

const cli = (script, env, args = []) => spawnSync(process.execPath, [path.join(here, script), ...args], { env: { PATH: process.env.PATH, ...env }, encoding: 'utf8', timeout: 20000 });

test('create_test_accounts : refuse en ligne de commande sur la production, meme en --dry-run, sans aucun appel reseau', () => {
  for (const args of [[], ['--dry-run']]) {
    const r = cli('create_test_accounts.mjs', { SUPABASE_URL: `https://${PROD_REF}.supabase.co`, SUPABASE_SERVICE_ROLE_KEY: 'x', ALLOW_TEST_PROJECT: '1', TEST_PASSWORD: 'Motdepasse1234' }, args);
    assert.equal(r.status, 2, r.stdout + r.stderr);
    assert.match(r.stderr, /REFUS.*PRODUCTION/);
  }
});

test('create_test_accounts : refuse sans ALLOW_TEST_PROJECT', () => {
  const r = cli('create_test_accounts.mjs', { SUPABASE_URL: TEST_URL, SUPABASE_SERVICE_ROLE_KEY: 'x', TEST_PASSWORD: 'Motdepasse1234' }, ['--dry-run']);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /ALLOW_TEST_PROJECT/);
});

test('create_test_accounts : sans mot de passe valide, refuse (hors dry-run)', async () => {
  await assert.rejects(createAccounts({ env: { ...ok, SUPABASE_SERVICE_ROLE_KEY: 'k', TEST_PASSWORD: 'court1' }, argv: [], fetchImpl: () => { throw new Error('reseau interdit'); }, log() {} }), /TEST_PASSWORD/);
  await assert.rejects(createAccounts({ env: { ...ok, TEST_PASSWORD: 'Motdepasse1234' }, argv: [], fetchImpl: () => { throw new Error('reseau interdit'); }, log() {} }), /SUPABASE_SERVICE_ROLE_KEY/);
});

test('create_test_accounts --dry-run : 5 acteurs @test.invalid, aucun appel reseau', async () => {
  const lines = [];
  const r = await createAccounts({ env: ok, argv: ['--dry-run'], fetchImpl: () => { throw new Error('reseau interdit'); }, log: (l) => lines.push(l) });
  assert.equal(r.dry, true);
  assert.equal(ACTORS.length, 5);
  assert.ok(ACTORS.every((a) => isTestEmail(a.email)));
  assert.deepEqual(ACTORS.map((a) => a.role).sort(), ['admin', 'client', 'company', 'dept', 'student']);
  assert.ok(lines.some((l) => /DRY-RUN.*affiliation|rattachement/i.test(l)));
  assert.ok(!lines.join('\n').includes('Motdepasse'));
});

// Serveur factice : imite uniquement les routes Auth admin et REST utilisees par l'outil.
const fakeServer = async () => {
  const state = { users: [], tables: {}, calls: [] };
  const srv = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      const u = new URL(req.url, 'http://x');
      state.calls.push(`${req.method} ${u.pathname}`);
      const send = (code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(obj)); };
      if (req.headers.authorization !== 'Bearer service-test-key') return send(401, { message: 'cle invalide' });
      if (u.pathname === '/auth/v1/admin/users' && req.method === 'POST') {
        const b = JSON.parse(body);
        if (state.users.some((x) => x.email === b.email)) return send(422, { code: 'email_exists' });
        const user = { id: `00000000-0000-0000-0000-${String(state.users.length + 1).padStart(12, '0')}`, email: b.email, password: b.password };
        state.users.push(user);
        return send(200, user);
      }
      if (u.pathname === '/auth/v1/admin/users' && req.method === 'GET') return send(200, { users: state.users });
      const put = /^\/auth\/v1\/admin\/users\/([^/]+)$/.exec(u.pathname);
      if (put && req.method === 'PUT') { const x = state.users.find((y) => y.id === put[1]); if (x) x.password = JSON.parse(body).password; return send(200, x ?? {}); }
      const t = /^\/rest\/v1\/([a-z_]+)$/.exec(u.pathname);
      if (t && req.method === 'POST') {
        const conflict = u.searchParams.get('on_conflict');
        const tab = (state.tables[t[1]] ??= new Map());
        for (const row of JSON.parse(body)) tab.set(row[conflict], { ...(tab.get(row[conflict]) ?? {}), ...row });
        res.writeHead(201); return res.end();
      }
      return send(404, { message: 'route inconnue' });
    });
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  return { state, url: `http://127.0.0.1:${srv.address().port}`, close: () => new Promise((r) => srv.close(r)) };
};

test('create_test_accounts : cree 5 comptes @test.invalid avec leurs affiliations, de facon idempotente (serveur factice)', async () => {
  const s = await fakeServer();
  try {
    const env = { SUPABASE_URL: s.url, ALLOW_TEST_PROJECT: '1', SUPABASE_SERVICE_ROLE_KEY: 'service-test-key', TEST_PASSWORD: 'Motdepasse1234' };
    const log = [];
    const a = await createAccounts({ env, argv: [], log: (l) => log.push(l) });
    assert.equal(s.state.users.length, 5);
    assert.ok(s.state.users.every((u) => isTestEmail(u.email) && u.password === 'Motdepasse1234'));
    const profiles = [...s.state.tables.profiles.values()];
    assert.equal(profiles.length, 5);
    assert.ok(profiles.every((p) => p.is_test === true && isTestEmail(p.email)));
    const byRole = Object.fromEntries(profiles.map((p) => [p.role, p]));
    assert.ok(byRole.student.certification === 'approved' && byRole.student.department_id === FIXTURES.deptA);
    assert.equal(byRole.dept.department_id, FIXTURES.deptA);
    const aff = [...s.state.tables.student_affiliations.values()][0];
    assert.ok(aff.status === 'verified' && aff.user_id === a.ids.student && aff.program_id === FIXTURES.program);
    assert.equal([...s.state.tables.department_accounts.values()][0].user_id, a.ids.dept);
    assert.equal([...s.state.tables.company_profiles.values()][0].owner_id, a.ids.org);
    assert.equal([...s.state.tables.institutions.values()].length, 1);
    assert.ok(!log.join('\n').includes('Motdepasse1234'), 'le mot de passe ne doit jamais etre affiche');
    // seconde execution : aucun doublon, mot de passe realigne
    await createAccounts({ env: { ...env, TEST_PASSWORD: 'AutreMotdepasse99' }, argv: [], log() {} });
    assert.equal(s.state.users.length, 5);
    assert.equal(s.state.tables.profiles.size, 5);
    assert.ok(s.state.users.every((u) => u.password === 'AutreMotdepasse99'));
    assert.ok(s.state.calls.every((c) => !c.includes('supabase.co')));
  } finally { await s.close(); }
});

test('create_test_accounts : refuse une cle de service appartenant a la production', async () => {
  await assert.rejects(createAccounts({ env: { ...ok, SUPABASE_SERVICE_ROLE_KEY: jwt({ ref: PROD_REF, role: 'service_role' }), TEST_PASSWORD: 'Motdepasse1234' }, argv: [], fetchImpl: () => { throw new Error('reseau interdit'); }, log() {} }), /PRODUCTION/);
});

test('validate_actors WRITE_TESTS=1 : refuse sur la production et sans ALLOW_TEST_PROJECT, avant tout appel reseau', () => {
  const base = { SUPABASE_ANON_KEY: 'anon', WRITE_TESTS: '1' };
  let r = cli('validate_actors.mjs', { ...base, SUPABASE_URL: `https://${PROD_REF}.supabase.co`, ALLOW_TEST_PROJECT: '1' });
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(r.stdout, /REFUS.*PRODUCTION/);
  assert.ok(!/Visiteur/.test(r.stdout), 'aucun controle ne doit avoir demarre');
  r = cli('validate_actors.mjs', { ...base, SUPABASE_URL: TEST_URL });
  assert.equal(r.status, 2);
  assert.match(r.stdout, /ALLOW_TEST_PROJECT/);
  r = cli('validate_actors.mjs', { ...base, SUPABASE_URL: `https://${PROD_REF}.supabase.co`, SUPABASE_ANON_KEY: jwt({ ref: PROD_REF }) });
  assert.equal(r.status, 2);
});

