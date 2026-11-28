// H13.2 agent 5 - matrice acteur x objet (voir h132_orgs_fixture.mjs pour la description). Ce fichier : marquage, lecture de toutes les tables, appel de toutes les fonctions.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_orgs_matrice.mjs     (compter les lignes ECHEC / ERREUR / FUITE)
import fs from 'fs';
import { bench } from './h131_lib.mjs';
import { buildFixture, SIDES } from './h132_orgs_fixture.mjs';

const OUT = process.env.O5_OUT || '';
const SKIP_COL = /(^|_)(status|kind|type|role|state|code|currency|slug|unit|mode|visibility|scope|plan|period|lang|locale|channel|method|provider|bucket|mime|key|token|hash|gender|level|priority|frequency|format|source|category|action|event|direction|target|origin)$/;
const MARK = /PRIV([ODS])([AB])_([a-z0-9_]+)/g;

export async function run(db) {
  const b = bench(db, 5);
  const t0 = Date.now();
  const fx = await buildFixture(db, b);
  const { side, ids, F } = fx;
  const rows = async (s) => (await db.query(s)).rows;
  await b.sup();

  // ---------------------------------------------------------------- 1. marquage : chaque ligne qui se rattache a un camp recoit une marque dans ses colonnes texte
  const cols = await rows(`select c.table_name t, c.column_name col, c.data_type dt from information_schema.columns c join information_schema.tables x on x.table_schema = c.table_schema and x.table_name = c.table_name
    where c.table_schema = 'public' and x.table_type = 'BASE TABLE' order by 1, c.ordinal_position`);
  const byTable = new Map();
  for (const c of cols) { if (!byTable.has(c.t)) byTable.set(c.t, []); byTable.get(c.t).push(c); }
  const sets = {};
  const add = (k, v) => { (sets[k] ??= new Set()).add(v); };
  for (const s of SIDES) {
    const o = side[s];
    for (const u of [o.O, o.OAD, o.OFI, o.OVW]) add('O' + s, u);
    add('D' + s, o.D); add('D' + s, o.H);
    add('S' + s, o.S1); add('S' + s, o.S2);
  }
  await db.exec("set session_replication_role = replica");
  const matchSql = (t, k) => {
    const uu = byTable.get(t).filter((c) => c.dt === 'uuid').map((c) => `"${c.col}"::text = any(array[${[...sets[k]].map((x) => `'${x}'`).join(',')}])`);
    return uu.length ? uu.join(' or ') : null;
  };
  // fermeture : les identifiants des lignes d'un camp (missions, propositions...) rejoignent le camp pour marquer les tables liees (jalons, candidatures...)
  for (let round = 0; round < 3; round++) {
    for (const k of Object.keys(sets)) {
      for (const [t, cs] of byTable) {
        if (!cs.some((c) => c.col === 'id' && c.dt === 'uuid')) continue;
        const w = matchSql(t, k);
        if (!w) continue;
        try { for (const r of await rows(`select id from "${t}" where ${w} limit 300`)) add(k, r.id); } catch (e) { /* vue ou table illisible */ }
      }
    }
  }
  let marked = 0;
  const markedTables = new Set();
  for (const k of Object.keys(sets)) {
    for (const [t, cs] of byTable) {
      const w = matchSql(t, k);
      if (!w) continue;
      for (const c of cs) {
        if (!(c.dt === 'text' || c.dt === 'character varying') || SKIP_COL.test(c.col) || c.col === 'id') continue;
        try {
          await db.exec('begin');
          const r = await db.query(`update "${t}" set "${c.col}" = "${c.col}" || ' PRIV${k}_${c.col}' where (${w}) and "${c.col}" is not null`);
          await db.exec('commit');
          if (r.affectedRows) { marked += r.affectedRows; markedTables.add(t); }
        } catch (e) { try { await db.exec('rollback'); } catch (_) { /* rien */ } }
      }
    }
  }
  await db.exec("set session_replication_role = origin");
  console.log(`MARQUAGE ${marked} cellules, ${markedTables.size} tables, camps: ${Object.entries(sets).map(([k, v]) => k + '=' + v.size).join(' ')}`);
  if (OUT) fs.writeFileSync(`${OUT}/o5_marked_tables.json`, JSON.stringify([...markedTables].sort()));

  // ---------------------------------------------------------------- 2. acteurs
  const claims = (uid, role = 'authenticated') => JSON.stringify(uid ? { sub: uid, role, aal: 'aal1' } : { role });
  const actors = [];
  for (const s of SIDES) {
    const o = side[s];
    actors.push({ n: `Org${s}.proprietaire`, side: s, type: 'O', uid: o.O }, { n: `Org${s}.admin`, side: s, type: 'O', uid: o.OAD }, { n: `Org${s}.finance`, side: s, type: 'O', uid: o.OFI },
      { n: `Org${s}.lecteur`, side: s, type: 'O', uid: o.OVW }, { n: `Dept${s}.responsable`, side: s, type: 'D', uid: o.H }, { n: `Etudiant${s}`, side: s, type: 'S', uid: o.S1 });
  }
  actors.push({ n: 'Client', side: null, type: 'C', uid: F.CLI }, { n: 'Anonyme', side: null, type: 'N', uid: null, role: 'anon' });
  // regle : marque interdite pour l'acteur ?
  const forbidden = (a, m) => {
    const [, mt, ms] = m;
    if (a.type === 'N' || a.type === 'C') return true;
    if (a.type === 'O') return !(mt === 'O' && ms === a.side);
    if (a.type === 'D') return !((mt === 'D' || mt === 'S') && ms === a.side);
    if (a.type === 'S') return ms !== a.side; // l'etudiant voit ce qui le concerne ; l'inter-camp reste interdit
    return true;
  };
  const leaks = new Map(); // acteur|source|marque -> compte
  const own = new Map();   // acteur|source -> marques propres vues (preuve que la sonde atteint des donnees)
  const note = (a, src, text) => {
    for (const m of text.matchAll(MARK)) {
      const key = `${a.n}|${src}|${m[0]}`;
      if (forbidden(a, m)) leaks.set(key, (leaks.get(key) || 0) + 1);
      else own.set(`${a.n}|${src}`, (own.get(`${a.n}|${src}`) || 0) + 1);
    }
  };
  const asTx = async (a, path) => {
    await db.exec(`begin; set local role ${a.type === 'N' ? 'anon' : 'authenticated'}; select set_config('request.jwt.claim.sub', '${a.uid ?? ''}', true), set_config('request.jwt.claims', '${claims(a.uid, a.type === 'N' ? 'anon' : 'authenticated')}', true), set_config('request.path', '${path}', true), set_config('request.method', 'POST', true)`);
  };

  // ---------------------------------------------------------------- 3. toutes les tables et vues lisibles
  const tabs = await rows(`select c.relname t, c.relkind k, has_table_privilege('authenticated', c.oid, 'select') a, has_table_privilege('anon', c.oid, 'select') n
    from pg_class c join pg_namespace s on s.oid = c.relnamespace where s.nspname = 'public' and c.relkind in ('r','v','m','p') order by 1`);
  let tabRead = 0, tabDenied = 0;
  for (const a of actors) {
    for (const t of tabs) {
      if (a.type === 'N' ? !t.n : !t.a) { tabDenied++; continue; }
      try {
        await asTx(a, `/${t.t}`);
        const r = await db.query(`select x::text v from public."${t.t}" x limit 3000`);
        for (const x of r.rows) note(a, 'table:' + t.t, x.v);
        tabRead++;
      } catch (e) { tabDenied++; }
      finally { try { await db.exec('rollback'); } catch (_) { /* rien */ } }
    }
  }
  console.log(`TABLES lues: ${tabRead} lectures, ${tabDenied} refusees/illisibles (${((Date.now() - t0) / 1000) | 0}s)`);

  // ---------------------------------------------------------------- 4. toutes les fonctions executables
  const fns = await rows(`select p.oid, p.proname n, p.pronargdefaults nd, p.proargnames names, p.proargmodes modes, p.provolatile vol,
      (select coalesce(array_agg(format_type(t::oid, null) order by ord), '{}') from unnest(string_to_array(p.proargtypes::text, ' ')) with ordinality as x(t, ord) where t <> '') types,
      has_function_privilege('authenticated', p.oid, 'execute') a, has_function_privilege('anon', p.oid, 'execute') n_
    from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.prokind = 'f' and p.proname not like '\\_%' and p.proname not like 'trg\\_%' order by 1`);
  // objets de l'autre camp (cibles des attaques)
  const target = (a) => (a.side === 'A' ? 'B' : 'A');
  const pool = (s) => {
    const out = [];
    for (const k of ['O', 'D', 'S']) for (const v of sets[k + s]) out.push(v);
    return out;
  };
  const P0 = (await rows(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;
  const lit = (ty, name, side_, poolId) => {
    const o = side[side_];
    const nm = (name || '').toLowerCase();
    if (ty === 'uuid') {
      if (/owner|org|company|client_id|employer/.test(nm)) return `'${o.O}'::uuid`;
      if (/dept|department/.test(nm)) return `'${o.D}'::uuid`;
      if (/student|talent|user|account|candidate|member|profile|seller|author|target|recipient|invitee/.test(nm)) return `'${o.S1}'::uuid`;
      if (/program/.test(nm)) return `'${o.G}'::uuid`;
      if (/institution/.test(nm)) return `'${fx.I1}'::uuid`;
      return `'${poolId}'::uuid`;
    }
    if (/^(integer|bigint|smallint|numeric|double precision|real)$/.test(ty)) return /limit|count|size|top|max/.test(nm) ? '20' : /offset|page/.test(nm) ? '0' : '1';
    if (ty === 'boolean') return 'true';
    if (ty === 'date') return 'current_date';
    if (/^timestamp/.test(ty)) return 'now()';
    if (ty === 'jsonb' || ty === 'json') return `'{}'::${ty}`;
    if (ty === 'uuid[]') return `array['${o.S1}','${o.S2}']::uuid[]`;
    if (/\[\]$/.test(ty)) return `array[]::${ty}`;
    if (ty === 'text' || ty === 'character varying') {
      if (/period/.test(nm)) return `'${P0}'`;
      if (/kind|type/.test(nm)) return `'synthese'`;
      if (/status/.test(nm)) return `'pending'`;
      if (/email/.test(nm)) return `'x${side_}@t.cm'`;
      if (/role/.test(nm)) return `'viewer'`;
      return `'x'`;
    }
    return null;
  };
  const callFn = async (a, f, sideTarget, poolId) => {
    const names = f.names ? f.names.filter((_, i) => !f.modes || ['i', 'b', 'v'].includes(f.modes[i])) : [];
    const n = f.types.length;
    const req = n - f.nd;
    const args = [];
    for (let i = 0; i < n; i++) {
      const nm = names[i];
      const optional = i >= req;
      // les parametres optionnels de ciblage (organisation / departement) sont fournis : c'est la qu'un acteur tente de lire un autre camp
      if (optional && !(nm && /owner|org|company|dept|department|student|user/i.test(nm))) continue;
      const v = lit(f.types[i], nm, sideTarget, poolId);
      if (v === null) { if (!optional) return { skip: 'type' }; continue; }
      args.push(nm ? `"${nm}" => ${v}` : v);
    }
    const call = `public."${f.n}"(${args.join(', ')})`;
    await asTx(a, `/rpc/${f.n}`);
    try {
      await db.query('select enforce_mfa_on_sensitive()');
      const r = await db.query(`select to_jsonb(x)::text v from ${call} x limit 400`);
      let wr = [];
      try { wr = (await db.query(`select relname, n_tup_upd u, n_tup_del d from pg_stat_xact_user_tables where n_tup_upd + n_tup_del > 0`)).rows; } catch (_) { /* statistiques indisponibles */ }
      return { ok: true, text: r.rows.map((x) => x.v).join('\n'), wr, call };
    } catch (e) {
      return { ok: false, err: String(e.message).split('\n')[0].slice(0, 120) };
    } finally { try { await db.exec('rollback'); } catch (_) { /* rien */ } }
  };
  const fnStat = new Map(); // fonction -> {ok, err, errs}
  const writes = new Map();
  const attack = actors.filter((a) => ['O', 'D', 'S', 'C', 'N'].includes(a.type) && (a.side !== 'B'));
  let calls = 0;
  for (const f of fns) {
    if (!f.a && !f.n_) continue;
    const st = fnStat.get(f.n) || { ok: 0, err: 0, errs: {}, ownOk: 0, ownSeen: 0 };
    fnStat.set(f.n, st);
    const generic = f.types.some((t, i) => t === 'uuid' && !(f.names && /owner|org|company|dept|department|student|talent|user|account|candidate|member|profile|seller|author|target|recipient|invitee|program|institution/i.test((f.names.filter((_, j) => !f.modes || ['i', 'b', 'v'].includes(f.modes[j])))[i] || ''))
      && i < f.types.length - f.nd);
    for (const a of attack) {
      if (a.type === 'N' ? !f.n_ : !f.a) continue;
      // attaque : arguments = objets du camp oppose (camp B pour les acteurs A ; client / anonyme visent B aussi)
      const tgt = a.side ? target(a) : 'B';
      const candidates = generic ? pool(tgt).slice(0, 80) : [null];
      for (const pid of candidates) {
        const r = await callFn(a, f, tgt, pid);
        calls++;
        if (r.skip) break;
        if (r.ok) {
          st.ok++;
          note(a, 'fn:' + f.n, r.text);
          for (const w of r.wr) { const k = `${a.n}|${f.n}|${w.relname}`; const prev = writes.get(k) || { upd: 0, del: 0, n: 0 }; prev.upd += Number(w.u); prev.del += Number(w.d); prev.n++; writes.set(k, prev); }
          if (generic && r.text && r.text.length > 4) break; // reussite sur un identifiant etranger : inutile d'enumerer le reste
        } else { st.err++; st.errs[r.err] = (st.errs[r.err] || 0) + 1; }
      }
      // sonde positive : meme appel vers son propre camp
      const r2 = await callFn(a, f, a.side || 'A', generic ? pool(a.side || 'A')[0] : null);
      if (r2.ok) { st.ownOk++; if (MARK.test(r2.text)) st.ownSeen++; MARK.lastIndex = 0; }
    }
  }
  console.log(`FONCTIONS: ${fnStat.size} candidates, ${calls} appels d'attaque (${((Date.now() - t0) / 1000) | 0}s)`);

  const leakRows = [...leaks.entries()].map(([k, n]) => { const [actor, source, mark] = k.split('|'); return { actor, source, mark, n }; });
  if (OUT) fs.writeFileSync(`${OUT}/o5_leaks.json`, JSON.stringify(leakRows, null, 1));
  if (OUT) fs.writeFileSync(`${OUT}/o5_fnstat.json`, JSON.stringify([...fnStat.entries()], null, 0));
  if (OUT) fs.writeFileSync(`${OUT}/o5_writes.json`, JSON.stringify([...writes.entries()], null, 0));
  if (OUT) fs.writeFileSync(`${OUT}/o5_own.json`, JSON.stringify([...own.entries()], null, 0));
  for (const l of leakRows) console.log('FUITE', l.actor, l.source, l.mark, l.n);
  console.log('RESUME fuites:', leakRows.length, ' fonctions sans aucun succes:', [...fnStat.values()].filter((s) => s.ok === 0 && s.ownOk === 0).length);
  b.summary('h132_orgs_matrice');
}
