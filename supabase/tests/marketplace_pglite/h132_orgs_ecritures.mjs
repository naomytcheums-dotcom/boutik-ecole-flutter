// H13.2 agent 5 - ECRITURES inter-camps : chaque fonction volatile executable est appelee par chaque acteur avec des arguments pointant vers les objets du camp B ;
// des declencheurs de journal (poses uniquement dans la base PGlite de test) enregistrent toute ligne modifiee ou creee, puis on cherche une ligne appartenant a l'autre camp
// (marque PRIV... ou identifiant d'un objet de l'autre camp). Aucune fuite ne doit rester non expliquee : ALLOW liste les ecritures voulues (notification d'un contact, etc.).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_orgs_ecritures.mjs   (compter les lignes ECHEC / ECRITURE)
import fs from 'fs';
import { bench } from './h131_lib.mjs';
import { buildFixture, SIDES } from './h132_orgs_fixture.mjs';
import { markFixture, buildActors, forbidden, MARK, claimsOf, callSql, isGeneric, FN_CATALOGUE_SQL } from './h132_orgs_lib.mjs';

const OUT = process.env.O5_OUT || '';
// ecritures voulues par conception : fonction -> tables (notifier / contacter l'autre camp est un effet normal)
// H13.2 : actions propres a l'appelant (le chef a relu les 45 lignes) ; toute NOUVELLE ecriture vers l'autre camp fait echouer le test.
// profile_set_academic : un compte peut declarer SON rattachement academique (risque connu, sans fuite : voir H132 rapport agent 5).
const ALLOW = JSON.parse(process.env.O5_ALLOW || JSON.stringify({
  mark_notifications_read: ['notifications'],
  profile_set_academic: ['profiles'],
  start_direct_conversation: ['conversation_participants', 'notifications'],
  block_user: ['user_blocks'],
  talent_profile_view_record: ['talent_profile_views'],
  follow_set: ['notifications', 'engagements'],
  profile_visit_record: ['profile_visits'],
}));

export async function run(db) {
  const b = bench(db, 5);
  const t0 = Date.now();
  const fx = await buildFixture(db, b);
  const { side } = fx;
  const rows = async (s) => (await db.query(s)).rows;
  await b.sup();
  const { sets, markedTables } = await markFixture(db, fx);
  const actors = buildActors(fx);

  await db.exec(`create table public.zz_wlog (id bigserial primary key, t text, op text, old_row jsonb, new_row jsonb);
    grant all on public.zz_wlog to anon, authenticated; grant all on sequence public.zz_wlog_id_seq to anon, authenticated;
    create function public.zz_wl() returns trigger language plpgsql security definer as $$ begin
      insert into public.zz_wlog (t, op, old_row, new_row) values (TG_TABLE_NAME, TG_OP, case when TG_OP <> 'INSERT' then to_jsonb(OLD) end, case when TG_OP <> 'DELETE' then to_jsonb(NEW) end); return null; end $$`);
  const tables = (await rows(`select c.relname t from pg_class c join pg_namespace s on s.oid = c.relnamespace where s.nspname = 'public' and c.relkind = 'r' and c.relname <> 'zz_wlog'`)).map((r) => r.t);
  for (const t of tables) { try { await db.exec(`create trigger zz_wl after insert or update or delete on public."${t}" for each row execute function public.zz_wl()`); } catch (_) { /* table partitionnee ou systeme */ } }

  const idsOf = (s) => new Set(['O', 'D', 'S'].flatMap((k) => [...(sets[k + s] || [])]));
  const foreignIds = { A: idsOf('B'), B: idsOf('A') };
  const asTx = async (a, path) => {
    await db.exec(`begin; set local role ${a.type === 'N' ? 'anon' : 'authenticated'}; select set_config('request.jwt.claim.sub', '${a.uid ?? ''}', true), set_config('request.jwt.claims', '${claimsOf(a.uid, a.type === 'N' ? 'anon' : 'authenticated')}', true), set_config('request.path', '${path}', true), set_config('request.method', '${'POST'}', true)`);
  };
  const P0 = (await rows(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;
  const fns = (await rows(FN_CATALOGUE_SQL)).filter((f) => f.vol !== 's');
  const pool = (s) => ['O', 'D', 'S'].flatMap((k) => [...(sets[k + s] || [])]);

  const hits = new Map(); // acteur|fonction|table|op|raison -> n
  const wanted = (actor) => actors.filter((a) => actor.includes(a.n));
  const attackers = wanted(['OrgA.proprietaire', 'OrgA.lecteur', 'OrgA.finance', 'DeptA.responsable', 'EtudiantA', 'Client', 'Anonyme']);
  let calls = 0;
  for (const f of fns) {
    if (!f.a && !f.n_) continue;
    const generic = isGeneric(f);
    for (const a of attackers) {
      if (a.type === 'N' ? !f.n_ : !f.a) continue;
      const tgt = a.side === 'A' ? 'B' : 'B';
      const cand = generic ? pool(tgt).slice(0, 12) : [null];
      for (const pid of cand) {
        const call = callSql(fx, P0, f, tgt, pid);
        if (!call) break;
        calls++;
        await asTx(a, `/rpc/${f.n}`);
        try {
          await db.query('select enforce_mfa_on_sensitive()');
          await db.query(`select to_jsonb(x)::text v from ${call} x limit 5`);
        } catch (e) { /* refuse : c'est le resultat attendu */ }
        try {
          const log = (await db.query('select t, op, old_row::text o, new_row::text n from public.zz_wlog')).rows;
          for (const w of log) {
            const reasons = new Set();
            for (const txt of [w.o, w.n]) {
              if (!txt) continue;
              for (const m of txt.matchAll(MARK)) if (forbidden({ ...a, type: a.type }, m) && (m[2] !== a.side || a.type === 'C' || a.type === 'N')) reasons.add('marque ' + m[0]);
              for (const id of foreignIds[a.side || 'A'] ?? []) if (txt.includes(id) && id !== a.uid) { reasons.add('objet ' + id.slice(-6)); break; }
            }
            if (!reasons.size) continue;
            const key = `${a.n}|${f.n}|${w.t}|${w.op}|${[...reasons][0].startsWith('marque') ? 'marque' : 'objet'}`;
            hits.set(key, (hits.get(key) || 0) + 1);
          }
        } catch (_) { /* rien */ }
        await db.exec('rollback').catch(() => {});
      }
    }
  }
  console.log(`ECRITURES: ${fns.length} fonctions volatiles, ${calls} appels (${((Date.now() - t0) / 1000) | 0}s)`);
  const out = [...hits.entries()].map(([k, n]) => { const [actor, fn, t, op, why] = k.split('|'); return { actor, fn, t, op, why, n }; });
  if (OUT) fs.writeFileSync(`${OUT}/o5_ecritures.json`, JSON.stringify(out, null, 1));
  let bad = 0;
  for (const r of out) {
    if ((ALLOW[r.fn] || []).includes(r.t)) continue;
    bad++; console.log('ECRITURE', r.actor, r.fn, r.t, r.op, r.why, r.n);
  }
  b.check('aucune ecriture inter-camp non expliquee', bad === 0, `${bad} ecriture(s)`);
  b.summary('h132_orgs_ecritures');
}
