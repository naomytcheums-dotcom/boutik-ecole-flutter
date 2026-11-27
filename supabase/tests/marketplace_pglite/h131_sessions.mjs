// Scénario PGlite H13.1 · lot SESSIONS : refus effectif des requêtes d'une session fermée ou d'un compte suspendu (garde db_pre_request + helper _session_is_live()).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_sessions.mjs   (compter les lignes ECHEC / ERREUR : le code de sortie est toujours 0)
// Simulation de PostgREST : pour chaque requête, request.jwt.claims (sub, role, session_id, aal), request.path et request.method sont posés, la garde « public.enforce_mfa_on_sensitive() »
// (pgrst.db_pre_request) est exécutée, puis la requête elle-même sous le rôle « authenticated ». Le jeton n'est JAMAIS révoqué au sens GoTrue : seule la base refuse la requête.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
const here = path.dirname(fileURLToPath(import.meta.url));

export async function run(db) {
  const raw = db.exec.bind(db);
  db.exec = (s) => raw('reset role; ' + s);
  const U = (n) => `00000000-0000-0000-0000-0000000131${String(n).padStart(2, '0')}`;
  const SID = (n) => `00000000-0000-0000-0000-0000000132${String(n).padStart(2, '0')}`;
  const q = async (sql) => (await db.query(sql)).rows;
  const root = async (sql) => { await db.exec('reset role'); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const esc = (s) => String(s).replace(/'/g, "''");
  // une requête PostgREST : garde puis requête ; renvoie { rows } ou { err }
  const api = async (uid, sid, method, route, sql, extra = {}) => {
    const claims = uid ? { sub: uid, role: extra.role ?? 'authenticated', aal: extra.aal ?? 'aal1', ...(sid ? { session_id: sid } : {}) } : { role: 'anon' };
    await db.exec('reset role');
    await db.exec(`select set_config('request.jwt.claims', '${esc(JSON.stringify(claims))}', false), set_config('request.jwt.claim.sub', '${uid ?? ''}', false),
      set_config('request.path', '${route}', false), set_config('request.method', '${method}', false)`);
    await raw(`set role ${extra.role === 'service_role' ? 'service_role' : uid ? 'authenticated' : 'anon'}`);
    try { await q('select public.enforce_mfa_on_sensitive()'); } catch (e) { return { err: e, stage: 'garde' }; }
    try { return { rows: await q(sql) }; } catch (e) { return { err: e, stage: 'requete' }; }
  };
  const allowed = (name, r) => check(name, !r.err, r.err && `${r.stage}: ${r.err.message}`);
  const revoked = (name, r) => check(name, r.err && r.stage === 'garde' && r.err.code === 'PT401' && /Session expirée ou révoquée, reconnectez-vous/.test(r.err.message) && r.err.hint === 'session_revoked',
    r.err ? `${r.stage} ${r.err.code} ${r.err.message} ${r.err.hint}` : 'aurait du etre refuse');
  const suspended = (name, r) => check(name, r.err && r.stage === 'garde' && r.err.code === '42501' && /Compte suspendu/.test(r.err.message) && r.err.hint === 'account_suspended',
    r.err ? `${r.stage} ${r.err.code} ${r.err.message} ${r.err.hint}` : 'aurait du etre refuse');
  const READ = (uid, sid) => api(uid, sid, 'GET', '/profiles', `select name from profiles where id = '${uid}'`);
  const RPC_READ = (uid, sid) => api(uid, sid, 'POST', '/rpc/current_role_name', `select current_role_name()::text r`);
  const WRITE_TABLE = (uid, sid) => api(uid, sid, 'PATCH', '/profiles', `update profiles set name = 'Nom ' || substr(md5(random()::text), 1, 4) where id = '${uid}'`);
  const WRITE_RPC = (uid, sid) => api(uid, sid, 'POST', '/rpc/save_profile_links', `select save_profile_links('[]'::jsonb)`);

  // ------------------------------------------------------------------ fixtures
  await db.exec('reset role');
  await db.exec(`alter table auth.refresh_tokens add column if not exists revoked boolean default false; alter table auth.refresh_tokens add column if not exists updated_at timestamptz default now();
    alter table auth.refresh_tokens add column if not exists token text; alter table auth.sessions add column if not exists not_after timestamptz`);
  const people = { 1: ['admin', 'Admin Sessions'], 2: ['student', 'Etudiant A Suspendre'], 3: ['student', 'Etudiant Intact'], 4: ['client', 'Client Revoque'], 5: ['student', 'Etudiant Banni'], 6: ['student', 'Etudiant Delai'] };
  for (const [n, [r, nm]] of Object.entries(people)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','s${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','s${n}@t.cm')`);
  }
  const ADM = U(1), ST = U(2), OT = U(3), RV = U(4), BN = U(5), TM = U(6);
  // sessions : ST a deux appareils
  await db.exec(`insert into auth.sessions (id, user_id) values ('${SID(1)}','${ADM}'), ('${SID(2)}','${ST}'), ('${SID(3)}','${ST}'), ('${SID(4)}','${OT}'), ('${SID(5)}','${RV}'), ('${SID(6)}','${BN}'), ('${SID(7)}','${TM}')`);

  // ================================================================== A. AVANT SUSPENSION : tout fonctionne
  allowed('A1 compte connecte : lecture de table (GET /profiles)', await READ(ST, SID(2)));
  allowed('A1 compte connecte : RPC de lecture', await RPC_READ(ST, SID(2)));
  allowed('A1 compte connecte : ecriture de table (PATCH /profiles)', await WRITE_TABLE(ST, SID(2)));
  allowed('A1 compte connecte : RPC d ecriture', await WRITE_RPC(ST, SID(2)));
  allowed('A1 second appareil du meme compte', await READ(ST, SID(3)));
  allowed('A1 administrateur', await api(ADM, SID(1), 'POST', '/rpc/admin_service_health', `select 1`));
  // exceptions : anonyme, service_role, jeton sans session_id
  allowed('A2 appel anonyme (sans sub) : jamais refuse', await api(null, null, 'POST', '/rpc/current_role_name', `select 1`));
  allowed('A2 service_role avec un session_id inexistant : jamais refuse', await api(ST, SID(99), 'POST', '/rpc/current_role_name', `select 1`, { role: 'service_role' }));
  allowed('A2 jeton sans session_id (ancien format) : non controle sur la session', await READ(ST, null));
  revoked('A3 session_id qui n a jamais existe : refuse', await READ(ST, SID(99)));
  revoked('A3 session d un AUTRE compte presentee avec le sub de ST : refuse', await READ(ST, SID(4)));
  allowed('A3 le refus n a rien casse pour les autres (compte intact)', await READ(OT, SID(4)));

  // ================================================================== B. SUSPENSION PAR L'ADMINISTRATEUR
  const adm = await api(ADM, SID(1), 'POST', '/rpc/admin_set_account', `select admin_set_account('${ST}', 'student', true)`);
  allowed('B1 admin_set_account suspend le compte (jeton admin)', adm);
  check('B1 sessions du compte suspendu supprimees', (await root(`select count(*)::int n from auth.sessions where user_id = '${ST}'`))[0].n === 0);
  check('B1 connexion bloquee (banned_until)', (await root(`select banned_until > now() + interval '10 years' b from auth.users where id = '${ST}'`))[0].b === true);
  // le jeton d'accès émis AVANT la suspension (signature et expiration valides) : toute requête est refusée, lecture comprise
  revoked('B2 ancien jeton : lecture de table refusee', await READ(ST, SID(2)));
  revoked('B2 ancien jeton : RPC de lecture refusee', await RPC_READ(ST, SID(2)));
  revoked('B2 ancien jeton : ecriture de table refusee', await WRITE_TABLE(ST, SID(2)));
  revoked('B2 ancien jeton : RPC d ecriture refusee', await WRITE_RPC(ST, SID(2)));
  revoked('B2 ancien jeton du second appareil refuse aussi', await READ(ST, SID(3)));
  check('B2 rien n a ete ecrit par les requetes refusees', (await root(`select name from profiles where id = '${ST}'`))[0].name.startsWith('Nom ') === true);
  // isolation
  allowed('B3 autre compte intact : lecture', await READ(OT, SID(4)));
  allowed('B3 autre compte intact : ecriture', await WRITE_TABLE(OT, SID(4)));
  allowed('B3 autre compte intact : RPC d ecriture', await WRITE_RPC(OT, SID(4)));
  allowed('B3 administrateur non affecte', await api(ADM, SID(1), 'POST', '/rpc/admin_service_health', `select 1`));
  allowed('B3 anonyme non affecte', await api(null, null, 'GET', '/marketplace_categories', `select 1`));
  check('B3 sessions des autres comptes intactes', (await root(`select count(*)::int n from auth.sessions where user_id in ('${OT}', '${ADM}')`))[0].n === 2);

  // ================================================================== C. COMPTE SUSPENDU DONT LA SESSION N'A PAS ETE SUPPRIMEE (ban GoTrue seul, session recreee, etc.)
  await db.exec(`insert into auth.sessions (id, user_id) values ('${SID(8)}', '${ST}')`);
  suspended('C1 session encore presente mais compte suspendu : lecture refusee', await READ(ST, SID(8)));
  suspended('C1 ... ecriture de table refusee', await WRITE_TABLE(ST, SID(8)));
  suspended('C1 ... RPC d ecriture refusee', await WRITE_RPC(ST, SID(8)));
  suspended('C1 ... RPC de lecture refusee', await RPC_READ(ST, SID(8)));
  for (const fn of ['support_ticket_create', 'request_account_deletion', 'accept_terms', 'unregister_all_devices', 'log_audit']) {
    const r = await api(ST, SID(8), 'POST', `/rpc/${fn}`, `select 1`);
    check(`C2 exception documentee pour un compte suspendu : /rpc/${fn} passe la garde`, !(r.err && r.stage === 'garde'), r.err && r.err.message);
  }
  revoked('C3 ... mais une session fermee reste refusee meme pour ces RPC', await api(ST, SID(2), 'POST', '/rpc/support_ticket_create', `select 1`));
  await db.exec(`delete from auth.sessions where id = '${SID(8)}'`);

  // ================================================================== D. REACTIVATION : acces restaure apres une NOUVELLE session
  allowed('D1 reactivation par l administrateur', await api(ADM, SID(1), 'POST', '/rpc/admin_set_account', `select admin_set_account('${ST}', 'student', false)`));
  check('D1 blocage de connexion leve', (await root(`select banned_until is null b from auth.users where id = '${ST}'`))[0].b === true);
  revoked('D2 l ancien jeton reste refuse apres la reactivation (session supprimee)', await READ(ST, SID(2)));
  revoked('D2 ... y compris le second appareil', await READ(ST, SID(3)));
  await db.exec(`insert into auth.sessions (id, user_id) values ('${SID(9)}', '${ST}')`);
  allowed('D3 nouvelle session : lecture', await READ(ST, SID(9)));
  allowed('D3 nouvelle session : ecriture de table', await WRITE_TABLE(ST, SID(9)));
  allowed('D3 nouvelle session : RPC d ecriture', await WRITE_RPC(ST, SID(9)));

  // ================================================================== E. FERMETURE MANUELLE + REFRESH TOKENS
  await db.exec(`insert into auth.refresh_tokens (user_id, session_id, token, revoked) values ('${RV}', '${SID(5)}', 'a', false), ('${RV}', null, 'b', false), ('${OT}', '${SID(4)}', 'c', false)`);
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${ADM}', 'security', array['security.accounts']) on conflict do nothing`);
  allowed('E0 client : requete avant fermeture', await READ(RV, SID(5)));
  const rv = await api(ADM, SID(1), 'POST', '/rpc/admin_account_sessions_revoke', `select admin_account_sessions_revoke('${RV}', 'compte compromis signale') r`);
  allowed('E1 admin_account_sessions_revoke', rv);
  check('E1 une session fermee', rv.rows && rv.rows[0].r.revoked === 1, JSON.stringify(rv.rows));
  check('E1 refresh tokens du compte marques revoked = true (y compris sans session)', (await root(`select count(*)::int n from auth.refresh_tokens where user_id = '${RV}' and revoked`))[0].n === 2);
  check('E1 refresh token d un autre compte intact', (await root(`select count(*)::int n from auth.refresh_tokens where user_id = '${OT}' and not revoked`))[0].n === 1);
  revoked('E2 ancien jeton du compte ferme : refuse (lecture)', await READ(RV, SID(5)));
  revoked('E2 ancien jeton du compte ferme : refuse (ecriture)', await WRITE_TABLE(RV, SID(5)));
  allowed('E2 le compte n est PAS suspendu : une nouvelle session fonctionne', await (async () => { await db.exec(`insert into auth.sessions (id, user_id) values ('${SID(10)}', '${RV}')`); return READ(RV, SID(10)); })());

  // ================================================================== F. BLOCAGE GOTRUE SEUL (banned_until) ET SESSION A DUREE MAXIMALE
  await db.exec(`update auth.users set banned_until = now() + interval '1 day' where id = '${BN}'`);
  suspended('F1 banned_until futur : refuse', await READ(BN, SID(6)));
  await db.exec(`update auth.users set banned_until = now() - interval '1 day' where id = '${BN}'`);
  allowed('F1 banned_until echu : accepte', await READ(BN, SID(6)));
  await db.exec(`update auth.users set banned_until = null where id = '${BN}'`);
  await db.exec(`update auth.sessions set not_after = now() - interval '1 minute' where id = '${SID(7)}'`);
  revoked('F2 session dont not_after est depasse : refusee', await READ(TM, SID(7)));
  await db.exec(`update auth.sessions set not_after = now() + interval '1 hour' where id = '${SID(7)}'`);
  allowed('F2 session avec not_after futur : acceptee', await READ(TM, SID(7)));

  // ================================================================== G. HELPER _session_is_live() ET DROITS
  const live = async (uid, sid, role = 'authenticated') => {
    const claims = uid ? { sub: uid, role, ...(sid ? { session_id: sid } : {}) } : { role: 'anon' };
    await db.exec('reset role');
    await db.exec(`select set_config('request.jwt.claims', '${esc(JSON.stringify(claims))}', false), set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`);
    await raw(`set role ${uid ? role : 'anon'}`);
    return (await q('select _session_is_live() l'))[0].l;
  };
  check('G1 _session_is_live : session ouverte', (await live(OT, SID(4))) === true);
  check('G1 _session_is_live : session supprimee', (await live(OT, SID(99))) === false);
  check('G1 _session_is_live : anonyme', (await live(null, null, 'anon')) === true);
  check('G1 _session_is_live : service_role', (await live(OT, SID(99), 'service_role')) === true);
  await db.exec('reset role');
  const priv = (await q(`select has_function_privilege('anon', '_session_status_of(uuid, uuid)', 'execute') a, has_function_privilege('authenticated', '_session_status_of(uuid, uuid)', 'execute') u,
    has_function_privilege('service_role', '_session_status_of(uuid, uuid)', 'execute') s, has_function_privilege('authenticated', '_session_revoke_tokens(uuid)', 'execute') rt,
    has_function_privilege('anon', '_session_is_live()', 'execute') la, has_function_privilege('authenticated', '_session_is_live()', 'execute') lu`))[0];
  check('G2 _session_status_of : service_role seulement', priv.s && !priv.a && !priv.u, JSON.stringify(priv));
  check('G2 _session_revoke_tokens : non exposee', !priv.rt);
  check('G2 _session_is_live : appelable par les politiques (anon, authenticated)', priv.la && priv.lu);
  const defs = await q(`select proname, prosecdef, provolatile from pg_proc where pronamespace = 'public'::regnamespace and proname in ('_session_is_live', '_session_status', '_session_status_of')`);
  check('G2 helpers stable + security definer', defs.length === 3 && defs.every((d) => d.prosecdef && d.provolatile === 's'), JSON.stringify(defs));
  check('G2 auth.sessions : lookup par cle primaire (id)', (await q(`select count(*)::int n from pg_index i where i.indrelid = 'auth.sessions'::regclass and i.indisprimary`))[0].n === 1);

  // ================================================================== H. STORAGE : politique de compartiment prive utilisant le helper
  await db.exec(`insert into storage.buckets (id, name, public) values ('h131-prive', 'h131-prive', false) on conflict do nothing;
    grant select, insert on storage.objects to authenticated;
    create policy h131_prive_lecture on storage.objects for select to authenticated using (bucket_id = 'h131-prive' and (select _session_is_live()) and (storage.foldername(name))[1] = auth.uid()::text);
    create policy h131_prive_ecriture on storage.objects for insert to authenticated with check (bucket_id = 'h131-prive' and (select _session_is_live()) and (storage.foldername(name))[1] = auth.uid()::text)`);
  await db.exec(`insert into storage.objects (bucket_id, name, owner) values ('h131-prive', '${OT}/doc.pdf', '${OT}'), ('h131-prive', '${TM}/doc.pdf', '${TM}')`);
  const stor = async (uid, sid, sql) => { await db.exec('reset role'); await db.exec(`select set_config('request.jwt.claims', '${esc(JSON.stringify({ sub: uid, role: 'authenticated', session_id: sid }))}', false), set_config('request.jwt.claim.sub', '${uid}', false)`); await raw('set role authenticated'); try { return { rows: await q(sql) }; } catch (e) { return { err: e }; } };
  check('H1 Storage : session ouverte lit son objet', ((await stor(OT, SID(4), `select name from storage.objects where bucket_id = 'h131-prive'`)).rows ?? []).length === 1);
  check('H1 Storage : session ouverte ecrit dans son dossier', !(await stor(OT, SID(4), `insert into storage.objects (bucket_id, name, owner) values ('h131-prive', '${OT}/b.pdf', '${OT}')`)).err);
  check('H2 Storage : session supprimee : lecture vide', ((await stor(OT, SID(99), `select name from storage.objects where bucket_id = 'h131-prive'`)).rows ?? []).length === 0);
  check('H2 Storage : session supprimee : ecriture refusee', /row-level security/.test((await stor(OT, SID(99), `insert into storage.objects (bucket_id, name, owner) values ('h131-prive', '${OT}/c.pdf', '${OT}')`)).err?.message ?? ''));
  check('H2 Storage : autre compte intact lit toujours son dossier', ((await stor(TM, SID(7), `select name from storage.objects where bucket_id = 'h131-prive'`)).rows ?? []).length === 1);
  await db.exec(`reset role; drop policy h131_prive_lecture on storage.objects; drop policy h131_prive_ecriture on storage.objects; delete from storage.objects where bucket_id = 'h131-prive'; delete from storage.buckets where id = 'h131-prive'`);

  // ================================================================== I. COUT DU CONTROLE
  await db.exec('reset role');
  await db.exec(`select set_config('request.jwt.claims', '${esc(JSON.stringify({ sub: OT, role: 'authenticated', session_id: SID(4) }))}', false), set_config('request.path', '/rpc/current_role_name', false), set_config('request.method', 'POST', false)`);
  const N = 3000;
  let t0 = performance.now();
  await q(`select count(*) from generate_series(1, ${N}) g where _session_status() = 'ok'`);
  const perCall = (performance.now() - t0) / N;
  t0 = performance.now();
  await q(`select count(*) from generate_series(1, ${N}) g where current_setting('request.path', true) is not null`);
  const baseline = (performance.now() - t0) / N;
  console.log(`CONSTAT I cout du controle de session : ${perCall.toFixed(4)} ms par requete (3 lookups par cle primaire : auth.sessions, profiles, auth.users) ; reference sans controle ${baseline.toFixed(4)} ms ; PGlite en memoire, ordre de grandeur`);
  check('I1 cout du controle < 1 ms par requete (PGlite)', perCall < 1, String(perCall));

  // ================================================================== J. REJEU DE LA MIGRATION
  const mig = fs.readFileSync(path.join(here, '..', '..', 'migrations', '20261129020000_h131_sessions_garde.sql'), 'utf8');
  const snap = async () => (await root(`select (select count(*) from pg_proc where pronamespace = 'public'::regnamespace)::int f, (select count(*) from pg_trigger where not tgisinternal)::int t, (select count(*) from pg_policy)::int p,
    (select count(*) from auth.sessions)::int s, (select count(*) from profiles)::int pr`))[0];
  const s1 = await snap();
  await db.exec('reset role');
  let rej = true; try { await db.exec(mig); await db.exec(mig); } catch (e) { rej = false; console.log(e.message); }
  const s2 = await snap();
  check('J1 migration rejouee deux fois sans erreur ni effet de bord', rej && JSON.stringify(s1) === JSON.stringify(s2), JSON.stringify([s1, s2]));
  allowed('J2 apres rejeu : compte intact toujours accepte', await READ(OT, SID(4)));
  revoked('J2 apres rejeu : session supprimee toujours refusee', await READ(ST, SID(2)));
  const defOf = async () => (await root(`select pg_get_functiondef('enforce_mfa_on_sensitive()'::regprocedure) d`))[0].d;
  const cnt = (s, sub) => s.split(sub).length - 1;
  const d1 = await defOf();
  check('J3 la garde 2FA et sa liste d operations sont conservees (money_freeze, admin_team_member_set)', /money_freeze/.test(d1) && /admin_team_member_set/.test(d1) && /double authentification/.test(d1));
  check('J3 un seul appel a _session_guard en tete de la garde', cnt(d1, '_session_guard()') === 1);
  for (const f of ['20261121010000_k1_mfa_operations_sensibles.sql', '20261126010000_h10_fin_rapprochement_reel.sql']) {
    let okk = true; try { await db.exec(fs.readFileSync(path.join(here, '..', '..', 'migrations', f), 'utf8')); } catch (e) { okk = false; console.log(e.message); }
    check(`J4 ${f} rejouee apres la migration : sans erreur`, okk);
  }
  const d2 = await defOf();
  check('J4 apres rejeu des migrations 2FA : garde de session toujours presente une seule fois', cnt(d2, '_session_guard()') === 1 && /money_freeze/.test(d2));
  revoked('J4 session supprimee toujours refusee', await READ(ST, SID(2)));

  console.log(`\nRESULTAT h131_sessions : ${ok} OK, ${ko} ECHEC`);
}
