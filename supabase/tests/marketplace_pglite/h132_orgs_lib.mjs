// H13.2 agent 5 - outils communs des matrices organisations / departements : marquage des donnees privees et regle d'acces par acteur.
import { SIDES } from './h132_orgs_fixture.mjs';

const SKIP_COL = /(^|_)(status|kind|type|role|state|code|currency|slug|unit|mode|visibility|scope|plan|period|lang|locale|channel|method|provider|bucket|mime|key|token|hash|gender|level|priority|frequency|format|source|category|action|event|direction|target|origin)$/;
export const MARK = /PRIV([ODS])([AB])_([a-z0-9_]+)/g;

// Chaque ligne rattachee a un camp (organisation O, departement D, etudiants S) recoit « PRIV<type><camp>_<colonne> » dans ses colonnes texte :
// une fuite revele alors la table et la colonne en cause.
export async function markFixture(db, fx) {
  const { side } = fx;
  const rows = async (s) => (await db.query(s)).rows;
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
  await db.exec('set session_replication_role = replica');
  const matchSql = (t, k) => {
    const uu = byTable.get(t).filter((c) => c.dt === 'uuid').map((c) => `"${c.col}"::text = any(array[${[...sets[k]].map((x) => `'${x}'`).join(',')}])`);
    return uu.length ? uu.join(' or ') : null;
  };
  // fermeture : les identifiants des lignes d'un camp (missions, propositions...) rejoignent le camp pour marquer les tables liees
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
  await db.exec('set session_replication_role = origin');
  return { sets, marked, markedTables };
}

export function buildActors(fx) {
  const { side, F } = fx;
  const actors = [];
  for (const s of SIDES) {
    const o = side[s];
    actors.push({ n: `Org${s}.proprietaire`, side: s, type: 'O', uid: o.O }, { n: `Org${s}.admin`, side: s, type: 'O', uid: o.OAD }, { n: `Org${s}.finance`, side: s, type: 'O', uid: o.OFI },
      { n: `Org${s}.lecteur`, side: s, type: 'O', uid: o.OVW }, { n: `Dept${s}.responsable`, side: s, type: 'D', uid: o.H }, { n: `Etudiant${s}`, side: s, type: 'S', uid: o.S1 });
  }
  actors.push({ n: 'Client', side: null, type: 'C', uid: F.CLI }, { n: 'Anonyme', side: null, type: 'N', uid: null, role: 'anon' });
  return actors;
}

// marque interdite pour l'acteur ? (le client et l'anonyme ne doivent voir aucune donnee privee d'aucun camp)
export function forbidden(a, m) {
  const [, mt, ms] = m;
  if (a.type === 'N' || a.type === 'C') return true;
  if (a.type === 'O') return !(mt === 'O' && ms === a.side);
  if (a.type === 'D') return !((mt === 'D' || mt === 'S') && ms === a.side);
  if (a.type === 'S') return ms !== a.side;
  return true;
}

export const claimsOf = (uid, role = 'authenticated') => JSON.stringify(uid ? { sub: uid, role, aal: 'aal1' } : { role });

const ACTOR_NAME = /owner|org|company|dept|department|student|talent|user|account|candidate|member|profile|seller|author|target|recipient|invitee|program|institution/i;

function lit(fx, P0, ty, name, sideKey, poolId) {
  const o = fx.side[sideKey];
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
    if (/email/.test(nm)) return `'x${sideKey}@t.cm'`;
    if (/role/.test(nm)) return `'viewer'`;
    return `'x'`;
  }
  return null;
}

// fonction du catalogue dont un argument obligatoire est un uuid « generique » (identifiant d'objet quelconque : on essaie les objets du camp vise)
export function isGeneric(f) {
  const names = f.names ? f.names.filter((_, j) => !f.modes || ['i', 'b', 'v'].includes(f.modes[j])) : [];
  return f.types.some((t, i) => t === 'uuid' && !ACTOR_NAME.test(names[i] || '') && i < f.types.length - f.nd);
}

// appel SQL d'une fonction avec des arguments qui visent les objets d'un camp ; null si un type obligatoire est inconnu
export function callSql(fx, P0, f, sideKey, poolId) {
  const names = f.names ? f.names.filter((_, i) => !f.modes || ['i', 'b', 'v'].includes(f.modes[i])) : [];
  const n = f.types.length, req = n - f.nd, args = [];
  for (let i = 0; i < n; i++) {
    const nm = names[i];
    // les parametres optionnels de ciblage (organisation / departement) sont fournis : c'est la qu'un acteur tente de lire ou d'ecrire chez l'autre camp
    if (i >= req && !(nm && /owner|org|company|dept|department|student|user/i.test(nm))) continue;
    const v = lit(fx, P0, f.types[i], nm, sideKey, poolId);
    if (v === null) { if (i < req) return null; continue; }
    args.push(nm ? `"${nm}" => ${v}` : v);
  }
  return `public."${f.n}"(${args.join(', ')})`;
}

export const FN_CATALOGUE_SQL = `select p.oid, p.proname n, p.pronargdefaults nd, p.proargnames names, p.proargmodes modes, p.provolatile vol,
    (select coalesce(array_agg(format_type(t::oid, null) order by ord), '{}') from unnest(string_to_array(p.proargtypes::text, ' ')) with ordinality as x(t, ord) where t <> '') types,
    has_function_privilege('authenticated', p.oid, 'execute') a, has_function_privilege('anon', p.oid, 'execute') n_
  from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.prokind = 'f' and p.proname not like '\\_%' and p.proname not like 'trg\\_%' order by 1`;
