// H13.1 lot ACTORS : petit banc commun des parcours par acteur (Visiteur/Client, Etudiant-vendeur, Organisation, Departement, Administrateur).
// Chaque parcours joue de VRAIS appels (fonctions RPC et ecritures directes) avec le role Postgres « authenticated » ou « anon » et des jwt claims propres a l'acteur,
// comme PostgREST. La garde de requete db_pre_request (enforce_mfa_on_sensitive : 2FA et comptes suspendus) est simulee avant chaque appel (request.path, request.method).
// Aucune donnee n'est creee hors de la base PGlite rejouee.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

export function bench(db, scenario) {
  let ok = 0, ko = 0, current = null;
  const raw = db.exec.bind(db);
  const U = (n) => `00000000-0000-0000-0000-0131${String(scenario)}${String(n).padStart(7, '0')}`;
  const claimsOf = (uid, role, aal) => (uid ? JSON.stringify({ sub: uid, role, aal: aal ?? 'aal1' }) : JSON.stringify({ role }));
  const as = async (uid, role = 'authenticated', aal = null) => {
    current = { uid, role, aal };
    await raw(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '${claimsOf(uid, role, aal)}', false)`);
    if (role) await raw(`set role ${role}`);
  };
  const anon = () => as(null, 'anon');
  const sup = async () => {
    current = null;
    await raw("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false), set_config('request.path', '', false), set_config('request.method', '', false)");
  };
  const rows = async (sql) => (await db.query(sql)).rows;
  // simulation de la garde PostgREST (db_pre_request) : chemin et methode de la requete, puis enforce_mfa_on_sensitive avec l'identite courante
  const guard = async (sql) => {
    if (!current) return;
    const s = sql.trim();
    let path_ = '/', method = 'POST';
    const fn = /^select\s+(?:\*\s+from\s+)?(?:public\.)?([a-z_0-9]+)\s*\(/i.exec(s);
    if (fn) path_ = `/rpc/${fn[1]}`;
    else {
      const t = /^(insert\s+into|update|delete\s+from|select\s+.*?\s+from)\s+(?:public\.)?([a-z_0-9]+)/i.exec(s);
      if (t) { path_ = `/${t[2]}`; method = /^insert/i.test(t[1]) ? 'POST' : /^update/i.test(t[1]) ? 'PATCH' : /^delete/i.test(t[1]) ? 'DELETE' : 'GET'; }
    }
    await raw(`select set_config('request.path', '${path_}', false), set_config('request.method', '${method}', false)`);
    await db.query('select enforce_mfa_on_sensitive()');
  };
  const q = async (sql) => { await guard(sql); return rows(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => {
    try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); if (process.env.H131_VERBOSE) console.log('   ->', String(e.message).slice(0, 140)); }
  };
  const works = async (name, sql, test = () => true) => {
    try { const r = await q(sql); check(name, test(r), JSON.stringify(r).slice(0, 300)); return r; } catch (e) { check(name, false, e.message); return null; }
  };
  // ecriture directe qui doit n'avoir AUCUN effet (RLS : zero ligne) ou etre refusee
  const noEffect = async (name, sql) => {
    try { const r = await q(sql); check(name, r.length === 0, `${r.length} ligne(s) touchee(s)`); } catch (e) { check(name, /permission denied|row-level security|violates/i.test(e.message), e.message); }
  };
  // requete hors acteurs (service) : l'identite courante est retablie ensuite
  const qs = async (sql) => { const prev = current; await sup(); try { return await rows(sql); } finally { if (prev) await as(prev.uid, prev.role, prev.aal); } };
  const user = async (n, name, role, extra = '') => {
    await raw(`insert into auth.users(id,email) values ('${U(n)}','h131-${scenario}-${n}@t.cm') on conflict do nothing`);
    await raw(`insert into profiles(id,name,role,email) values ('${U(n)}','${name.replace(/'/g, "''")}','${role}','h131-${scenario}-${n}@t.cm') on conflict do nothing`);
    if (extra) await raw(extra);
    return U(n);
  };
  // rejeu des migrations recentes (H13) : aucune ligne metier ne doit changer
  const replayMigrations = async (prefix = '202611280', tables = ['profiles', 'orders', 'order_lines', 'listings', 'shops', 'messages', 'notifications', 'audit_log']) => {
    const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
    const snap = async () => {
      await sup();
      const o = [];
      for (const t of tables) o.push(t + ':' + (await rows('select count(*) c, md5(coalesce(string_agg(x::text, \'|\' order by x::text), \'\')) h from ' + t + ' x'))[0].h);
      return o.join(';');
    };
    const before = await snap();
    let n = 0;
    for (const f of fs.readdirSync(path.join(repo, 'migrations')).filter((x) => x.startsWith(prefix)).sort()) {
      try { await sup(); await raw(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); n++; } catch (e) { if (/_rl_|_au_/.test(e.message) && /already exists/.test(e.message)) console.log('REMARQUE', `rejeu de ${f} : non reexecutable (enveloppe renommee deja presente)`); else check(`rejeu de ${f} sans erreur`, false, e.message); }
    }
    check(`rejeu de ${n} migrations H13 : aucune donnee metier modifiee`, (await snap()) === before);
  };
  const summary = (label) => console.log(`${label}: ${ok} OK, ${ko} KO`);
  const counts = () => ({ ok, ko });
  const DENY = /permission denied|Connexion requise|réservé|Réservé|non autorisé|Action non autorisée|refusé|introuvable|Introuvable|exige la permission|Accès|autorisée|row-level security|Seul|Seule|rattach|inconnu|propriétaire|membre|vôtre|Compte suspendu|double authentification/i;
  return { U, as, anon, sup, q, qs, rows, check, fails, works, noEffect, user, summary, counts, replayMigrations, raw, DENY };
}

