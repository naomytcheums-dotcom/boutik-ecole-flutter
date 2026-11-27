// H13.1 lot ACTORS - validate_actors.mjs (lecture ET ecriture, WRITE_TESTS=1) est execute en conditions « connectees SIMULEES » : un mini-PostgREST local (HTTP) route les appels
// /auth/v1/token, /rest/v1/rpc/* et /rest/v1/<table> vers la base PGlite rejouee, sous le role Postgres et les jwt claims du compte connecte, avec la garde db_pre_request.
// Les 5 comptes sont crees par create_test_accounts.mjs lui-meme. Aucun appel hors de la machine ; AUCUN vrai projet Supabase n'est contacte.
// But : prouver que les noms de fonctions / parametres / droits des scenarios d'ecriture sont corrects AVANT de les jouer sur un projet de test reel.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_validate_ecriture.mjs
import http from 'http';
import path from 'path';
import { spawn } from 'child_process';
import { fileURLToPath, pathToFileURL } from 'url';
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 7);
  const { as, sup, rows, check } = b;
  const here = path.dirname(fileURLToPath(import.meta.url));
  const toolDir = path.resolve(here, '..', '..', '..', 'tool', 'connected');
  const tool = await import(pathToFileURL(path.join(toolDir, 'create_test_accounts.mjs')).href);
  await sup();
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  const jres = (code, obj) => ({ ok: code < 300, status: code, json: async () => obj, text: async () => JSON.stringify(obj) });
  const dbFetch = async (url, opts = {}) => {
    const u = new URL(url); const method = opts.method ?? 'GET';
    if (u.pathname === '/auth/v1/admin/users' && method === 'POST') {
      const body = JSON.parse(opts.body);
      if ((await rows(`select 1 from auth.users where email = '${body.email}'`)).length) return jres(422, {});
      return jres(200, (await rows(`insert into auth.users (id, email) values (gen_random_uuid(), '${body.email}') returning id`))[0]);
    }
    if (u.pathname === '/auth/v1/admin/users' && method === 'GET') return jres(200, { users: await rows('select id, email from auth.users') });
    if (/^\/auth\/v1\/admin\/users\//.test(u.pathname)) return jres(200, {});
    const t = /^\/rest\/v1\/([a-z_]+)$/.exec(u.pathname);
    if (t && method === 'POST') {
      const conflict = u.searchParams.get('on_conflict'); const data = JSON.parse(opts.body);
      const cols = [...new Set(data.flatMap((r) => Object.keys(r)))];
      await db.query(`insert into ${t[1]} (${cols.join(', ')}) select ${cols.join(', ')} from json_populate_recordset(null::${t[1]}, $1::json) on conflict (${conflict}) do update set ${cols.filter((c) => c !== conflict).map((c) => `${c} = excluded.${c}`).join(', ')}`, [JSON.stringify(data)]);
      return jres(201, {});
    }
    return jres(404, {});
  };
  const accounts = await tool.run({ env: { SUPABASE_URL: 'http://127.0.0.1:1', ALLOW_TEST_PROJECT: '1', SUPABASE_SERVICE_ROLE_KEY: 'k', TEST_PASSWORD: 'Motdepasse1234' }, argv: [], fetchImpl: dbFetch, log() {} });
  const byEmail = Object.fromEntries(tool.ACTORS.map((a) => [a.email, accounts.ids[a.key]]));

  // ---------------------------------------------------------------- mini-PostgREST
  const lit = (v) => (v === null || v === undefined ? 'null' : `'${(typeof v === 'object' ? JSON.stringify(v) : String(v)).replace(/'/g, "''")}'`);
  const filters = (u) => [...u.searchParams.entries()].filter(([k]) => !['select', 'limit', 'order', 'offset', 'on_conflict'].includes(k)).map(([k, v]) => {
    const m = /^eq\.(.*)$/.exec(v); if (!m || !/^[a-z_]+$/.test(k)) throw new Error(`filtre non pris en charge : ${k}=${v}`);
    return `${k} = ${lit(decodeURIComponent(m[1]))}`;
  });
  let queue = Promise.resolve();
  const handle = async (req, body) => {
    const u = new URL(req.url, 'http://x');
    const send = (code, obj) => ({ code, obj });
    if (u.pathname === '/auth/v1/token') {
      const { email } = JSON.parse(body); const id = byEmail[email];
      return id ? send(200, { access_token: `uid:${id}`, user: { id } }) : send(400, { error: 'invalid_grant' });
    }
    const auth = String(req.headers.authorization ?? '').replace('Bearer ', '');
    const uid = auth.startsWith('uid:') ? auth.slice(4) : null;
    await (uid ? as(uid) : as(null, 'anon'));
    const call = async (path_, method, sql) => {
      await db.exec(`select set_config('request.path', '${path_}', false), set_config('request.method', '${method}', false)`);
      try {
        await db.query('select enforce_mfa_on_sensitive()');
        return await db.query(sql);
      } catch (e) { return { error: e }; }
    };
    const rpc = /^\/rest\/v1\/rpc\/([a-z_0-9]+)$/.exec(u.pathname);
    if (rpc) {
      const args = body ? JSON.parse(body) : {};
      const argSql = Object.entries(args).map(([k, v]) => `${k} => ${lit(v)}`).join(', ');
      const meta = (await db.query(`select proretset from pg_proc where proname = '${rpc[1]}' and pronamespace = 'public'::regnamespace limit 1`)).rows[0];
      if (!meta) return send(404, { message: 'fonction inconnue' });
      const sql = meta.proretset ? `select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) r from ${rpc[1]}(${argSql}) t` : `select to_jsonb(${rpc[1]}(${argSql})) r`;
      const r = await call(`/rpc/${rpc[1]}`, 'POST', sql);
      if (r.error && /function .* does not exist/i.test(r.error.message)) return send(404, { message: r.error.message }); // PGRST202 : signature inconnue
      if (r.error) return send(/permission denied|Connexion requise|Compte suspendu|double auth/i.test(r.error.message) ? 401 : 400, { message: r.error.message });
      return send(200, r.rows[0].r);
    }
    const tab = /^\/rest\/v1\/([a-z_]+)$/.exec(u.pathname);
    if (tab) {
      const t = tab[1]; const f = filters(u); const where = f.length ? ` where ${f.join(' and ')}` : '';
      const cols = (u.searchParams.get('select') ?? '*').split(',').every((c) => /^[a-z_*]+$/.test(c)) ? (u.searchParams.get('select') ?? '*') : '*';
      const lim = u.searchParams.get('limit') ? ` limit ${Number(u.searchParams.get('limit'))}` : '';
      let sql;
      if (req.method === 'GET') sql = `select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) r from (select ${cols} from ${t}${where}${lim}) x`;
      else if (req.method === 'POST') { const row = JSON.parse(body); const ks = Object.keys(row); sql = `with i as (insert into ${t} (${ks.join(',')}) values (${ks.map((k) => lit(row[k]) + (Array.isArray(row[k]) ? '::text[]' : '')).join(',')}) returning *) select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb) r from i`; if (ks.some((k) => Array.isArray(row[k]))) sql = sql.replace(/'(\[[^\]]*\])'::text\[\]/g, (_, a) => `'{${JSON.parse(a).map((x) => `"${x}"`).join(',')}}'::text[]`); }
      else if (req.method === 'PATCH') { const row = JSON.parse(body); sql = `with i as (update ${t} set ${Object.entries(row).map(([k, v]) => `${k} = ${lit(v)}`).join(', ')}${where} returning *) select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb) r from i`; }
      else return send(405, {});
      const r = await call(`/${t}`, req.method === 'GET' ? 'GET' : req.method, sql);
      if (r.error) return send(/permission denied|row-level/i.test(r.error.message) ? 403 : 400, { message: r.error.message });
      return send(req.method === 'POST' ? 201 : 200, r.rows[0].r);
    }
    return send(404, {});
  };
  const srv = http.createServer((req, res) => {
    let body = ''; req.on('data', (c) => { body += c; });
    req.on('end', () => {
      queue = queue.then(() => handle(req, body)).then(({ code, obj }) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(obj)); }).catch((e) => { res.writeHead(500); res.end(JSON.stringify({ message: String(e.message) })); });
    });
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const url = `http://127.0.0.1:${srv.address().port}`;

  // ---------------------------------------------------------------- execution du vrai script, comme sur un projet de test
  const env = { PATH: process.env.PATH, SUPABASE_URL: url, SUPABASE_ANON_KEY: 'anon-test', ALLOW_TEST_PROJECT: '1', WRITE_TESTS: '1', MEDIA_BASE: 'https://abcdefgh.supabase.co/storage/v1/object/public',
    TEST_CLIENT: 'client-h131@test.invalid:Motdepasse1234', TEST_STUDENT: 'etudiant-h131@test.invalid:Motdepasse1234', TEST_ORG: 'organisation-h131@test.invalid:Motdepasse1234',
    TEST_DEPT: 'departement-h131@test.invalid:Motdepasse1234', TEST_ADMIN: 'admin-h131@test.invalid:Motdepasse1234' };
  const child = spawn(process.execPath, [path.join(toolDir, 'validate_actors.mjs')], { env });
  let out = ''; child.stdout.on('data', (d) => { out += d; }); child.stderr.on('data', (d) => { out += d; });
  const code = await new Promise((r) => child.on('close', r));
  await new Promise((r) => srv.close(r));
  console.log(out.split('\n').filter((l) => /^(OK|ECHEC|NON TESTE|==|validate_actors)/.test(l)).map((l) => `   | ${l}`).join('\n'));
  const lines = out.split('\n');
  const nOk = lines.filter((l) => l.startsWith('OK ')).length, nKo = lines.filter((l) => l.startsWith('ECHEC')).length, nSkip = lines.filter((l) => l.startsWith('NON TESTE')).length;
  check('VA1 validate_actors (lecture + ecriture) termine sans ECHEC contre la base simulee', code === 0 && nKo === 0, `code ${code}, ${nKo} ECHEC`);
  check('VA2 les 5 acteurs sont tous testes (aucun NON TESTE)', nSkip === 0, `${nSkip} NON TESTE`);
  check('VA3 les scenarios d\'ecriture ont tourne (>= 40 controles OK)', nOk >= 40, `${nOk} OK`);
  const w = await sup().then(() => rows(`select (select count(*)::int from orders) o, (select count(*)::int from shops where status = 'active') s, (select count(*)::int from listings where status = 'approved' and seller_id is not null) l`));
  check('VA4 effets persistants : une commande, une boutique active, une annonce approuvee', w[0].o === 1 && w[0].s === 1 && w[0].l === 1, JSON.stringify(w));
  check('VA5 aucune commande n\'est payee (aucun paiement simule)', (await rows('select count(*)::int n from orders where paid')).every((r) => r.n === 0));
  b.summary('h131_validate_ecriture');
}

