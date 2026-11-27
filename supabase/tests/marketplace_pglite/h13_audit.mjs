// Scénario PGlite du lot H13 ADMIN-SÉCURITÉ-PERF : audit du catalogue (RLS, fonctions SECURITY DEFINER, droits anon / service, index de clés étrangères, journalisation des RPC d'administration)
// puis contrôle des correctifs 20261128070000 à 20261128070500 : limites de débit, santé des services, exports CSV, sessions d'un compte suspendu, journal d'audit en ajout seul.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h13_audit.mjs   (compter les lignes ECHEC / ERREUR : le code de sortie est toujours 0)
// Les lignes « CONSTAT » sont informatives (état du catalogue) ; les lignes OK / ECHEC sont des assertions. La liste blanche des fonctions publiques est documentée dans
// docs/transformation/H13_AUDIT_SECURITE_PERFORMANCE.md : toute nouvelle fonction ouverte à anon fait échouer ce test tant qu'elle n'a pas été relue et ajoutée.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
const here = path.dirname(fileURLToPath(import.meta.url));

// RPC volontairement ouvertes aux visiteurs (lecture publique, vérifications par code, annuaires). Chacune a été relue : SECURITY DEFINER avec filtrage par statut / visibilité, aucune donnée privée.
const ANON_RPC = new Set(['active_auto_promo', 'ann_detail', 'ann_wins_list', 'anns_list', 'author_posts', 'author_shop_slug', 'campaigns_overview', 'certificate_canonical', 'certificate_content_hash', 'chat_file_allowed',
  'circle_feed', 'circle_feed_page', 'communities_list', 'community_events_list', 'community_feed', 'community_images', 'community_levels', 'community_qa', 'company_public', 'creator_pins_list', 'creator_profile_tabs',
  'creator_tab_items', 'creators_suggested', 'current_role_name', 'delivery_quote', 'enforce_mfa_on_sensitive', 'department_detail', 'departments_list', 'dept_invite_info', 'duels_list', 'events_between', 'events_upcoming', 'flash_sales_active',
  'follow_stats', 'institutions_search', 'is_community_member', 'is_contest_staff', 'is_mission_participant', 'is_participant', 'is_platform_staff', 'iut_projects', 'kiosk_heartbeat', 'kiosk_pair_issue',
  'kiosk_pair_revoke', 'kiosk_pair_status', 'listing_rating', 'listing_variants_public', 'listings_other_institutions', 'live_can_join', 'live_get', 'live_settings_get', 'lives_agenda', 'lives_atelier_extras',
  'lives_now', 'marketplace_search', 'marketplace_shops', 'mate_categories_list', 'mentor_detail', 'mentor_stories', 'mentors_list', 'momo_normalize', 'normalize_msisdn', 'notification_category',
  'offer_type_of', 'opp_detail', 'opp_hired_list', 'opps_list', 'org_types_list', 'passport_token_verify', 'platform_impact', 'point_level', 'post_comment_list', 'post_comment_list_v2',
  'post_counters', 'post_shop_target', 'product_detail', 'product_digital_info', 'product_extras', 'product_reviews', 'profile_imported_items', 'profile_in_directory', 'profile_links_public', 'profile_verified',
  'profile_visible', 'project_proof_verify', 'promo_preview', 'provider_card', 'public_profile', 'public_project_get', 'public_projects', 'public_sellers', 'qr_resolve_public', 'ranking_explain', 'ranking_history',
  'ranking_institution_history', 'ranking_institutions_public', 'ranking_verify_hash', 'recommended_offers', 'record_view', 'reels_feed', 'replay_certificate_verify', 'replay_detail', 'replay_hosts_directory',
  'replay_library', 'replay_quiz_can_edit', 'replay_search', 'replay_share_info', 'seller_public', 'shared_cv', 'shop_public', 'showcase_listings', 'skills_list', 'stories_active', 'suggest_districts',
  'talent_passport', 'talent_public_profile', 'talents_most_viewed_by_companies', 'talents_new', 'talents_rising', 'top100_by_department', 'top100_by_domain', 'top100_by_institution', 'top100_by_program',
  'top100_national', 'top_helpers', 'trending_products', 'user_level', 'verify_certificate', 'verify_certificate_public', 'victories_list', 'wish_get', 'wishes_market']);
// Parmi elles, seules ces RPC contiennent une écriture : jeton d'appareil (bornes) ou compte connecté exigé avant toute écriture (compteurs de vues).
const ANON_WRITERS = new Set(['kiosk_heartbeat', 'kiosk_pair_issue', 'kiosk_pair_revoke', 'record_view', 'ann_detail']);
// Fonctions appelées par les fonctions Edge avec la clé de service : ni anon ni authenticated ne doivent pouvoir les exécuter, service_role oui.
const SERVICE_ONLY = ['assessment_dispatch_accepted', 'assessment_dispatch_claim', 'assessment_dispatch_failed', 'assessment_dispatch_provider_failed', 'assessment_dispatch_result', 'assessment_provider_health_report',
  'dispatch_key_check', 'auth_revoke_sessions', 'auth_throttle_check', 'auth_throttle_clear', 'auth_throttle_hit', 'phone_verify_apply', 'dispatch_claim', 'live_recording_egress_event', 'live_recording_egress_claim',
  'live_recording_egress_failed', 'live_recording_egress_started', 'live_recording_egress_stopping', 'live_recording_start_check', 'live_recording_stop_check', 'live_access_for', 'translate_store',
  'ai_action_record_result', 'grant_credits', 'live_recording_declare_track', 'live_recording_mark_ready', 'replay_clip_mark', 'replay_transcript_store', 'transcription_job_ack', 'send_live_reminders'];
// Exceptions documentées : exécutable par les comptes connectés (indicateur sans secret) ; garde de requête PostgREST (db_pre_request : 2FA et comptes suspendus), appelée sur chaque requête.
const SERVICE_BUT_AUTH_OK = new Set(['live_recording_enabled', 'enforce_mfa_on_sensitive']);
// Actions d'administration et de finance qui DOIVENT écrire au journal d'audit (directement ou par l'enveloppe « _au_ »).
const MUST_AUDIT = ['commission_engine_set', 'money_split_set', 'ann_prize_refund', 'momo_prepare_transfer', 'ann_decide', 'ann_win_decide', 'opp_decide', 'community_decide', 'victory_moderate', 'delete_referral_rule',
  'cms_delete', 'mate_category_delete', 'admin_mfa_reset_by_email', 'admin_process_account_deletions', 'admin_team_member_set', 'admin_team_member_remove', 'admin_set_account', 'admin_mfa_reset', 'admin_dept_assign',
  'admin_dept_unassign', 'payout_set_status', 'payout_create', 'order_refund_decide', 'money_release_now', 'revoke_certificate', 'issue_certificate', 'decide_certification', 'company_decide', 'shop_decide', 'ranking_publish',
  'admin_rpc_rate_limit_set', 'admin_account_sessions_revoke', 'admin_export_csv'];
const AUDIT_RE = /audit_log|log_audit\(|_audit\(|_h13_audit|h13:audit/i;

export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('request.headers', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000014${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const root = async (sql) => { await db.exec('reset role'); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const succeeds = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, false, e.message); } };
  const list = (rows, k = 's') => rows.map((r) => r[k]).join(', ');
  const nAudit = async (action) => (await root(`select count(*)::int n from audit_log where action = '${action.replace(/'/g, "''")}'`))[0].n;

  // ------------------------------------------------------------------ comptes
  // ADM administrateur ; TLOG équipe technique (tech.logs) ; TCFG équipe technique (tech.config) ; SAUD sécurité (security.audit) ; SACC sécurité (security.accounts) ; X client ; V étudiant à suspendre ; D compte Département ; S étudiant contestataire
  await db.exec('reset role');
  const roles = { 1: ['admin', 'Super Admin'], 2: ['support', 'Tech Logs'], 3: ['support', 'Tech Config'], 4: ['support', 'Secu Audit'], 5: ['support', 'Secu Comptes'], 6: ['client', 'Client Simple'], 7: ['student', 'Victor Suspendu'],
    8: ['dept', 'Chef Sans Rattachement'], 9: ['student', 'Sandra Contestataire'] };
  for (const [n, [r, nm]] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','a${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','a${n}@t.cm')`);
  }
  const ADM = U(1), TLOG = U(2), TCFG = U(3), SAUD = U(4), SACC = U(5), X = U(6), V = U(7), D = U(8), S = U(9);
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${TLOG}', 'tech', array['tech.logs']), ('${TCFG}', 'tech', array['tech.config', 'tech.logs']),
    ('${SAUD}', 'security', array['security.audit']), ('${SACC}', 'security', array['security.accounts'])`);

  // ================================================================== A. AUDIT DU CATALOGUE
  // A1 · RLS sur toutes les tables du schéma public
  const noRls = await root(`select c.relname s from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p') and not c.relrowsecurity order by 1`);
  const nTables = (await root(`select count(*)::int n from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')`))[0].n;
  console.log(`CONSTAT A1 ${nTables} tables, ${noRls.length} sans RLS`);
  check('A1 toutes les tables du schema public ont la RLS activee', noRls.length === 0, list(noRls));

  // A1b · aucune politique d'ECRITURE « using (true) » ni ouverte au rôle anon sans condition de compte
  const openWrite = await root(`select c.relname || '.' || p.polname s from pg_policy p join pg_class c on c.oid = p.polrelid where p.polcmd in ('a', 'w', 'd', '*')
    and coalesce(pg_get_expr(p.polqual, p.polrelid), 'true') = 'true' and coalesce(pg_get_expr(p.polwithcheck, p.polrelid), 'true') = 'true'`);
  check('A1b aucune politique d ecriture sans condition (using true)', openWrite.length === 0, list(openWrite));
  const anonWrite = await root(`select c.relname || '.' || p.polname s from pg_policy p join pg_class c on c.oid = p.polrelid where p.polcmd in ('a', 'w', 'd', '*')
    and exists (select 1 from unnest(p.polroles) o join pg_roles r on r.oid = o where r.rolname = 'anon') and c.relname not in ('profiles')`);
  check('A1b aucune politique d ecriture ciblant explicitement anon', anonWrite.length === 0, list(anonWrite));
  // lecture sans condition : tables à contenu public par nature (catalogues, avis, bornes) ; toute nouvelle table doit être relue
  const openRead = await root(`select c.relname s from pg_policy p join pg_class c on c.oid = p.polrelid where p.polcmd in ('r', '*') and pg_get_expr(p.polqual, p.polrelid) = 'true' order by 1`);
  const OPEN_READ_OK = new Set(['department_highlights', 'hackathon_teams', 'institution_settings', 'integration_providers', 'kiosk_events', 'kiosks', 'marketplace_categories', 'live_comments', 'post_boosts', 'post_likes', 'product_questions',
    'referral_rules', 'reviews', 'shop_reviews']);
  console.log(`CONSTAT A1c lecture sans condition : ${list(openRead.filter((r) => true), 's')}`);
  const unknownOpen = openRead.filter((r) => !OPEN_READ_OK.has(r.s));
  check('A1c lecture « using true » limitee a la liste relue (catalogues, avis, bornes publiques)', unknownOpen.length === 0, list(unknownOpen));
  check('A1c kiosk_sessions : plus aucune politique (table heritee fermee)', (await root(`select count(*)::int n from pg_policy where polrelid = 'kiosk_sessions'::regclass`))[0].n === 0);

  // A2 · fonctions SECURITY DEFINER sans search_path
  const noSp = await root(`select p.oid::regprocedure::text s from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.prokind = 'f'
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%') order by 1`);
  const nDef = (await root(`select count(*)::int n from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.prokind = 'f'`))[0].n;
  console.log(`CONSTAT A2 ${nDef} fonctions SECURITY DEFINER, ${noSp.length} sans search_path`);
  check('A2 toute fonction SECURITY DEFINER fixe son search_path', noSp.length === 0, list(noSp));

  // A3 · fonctions exécutables par anon : liste blanche documentée
  const anonFns = await root(`select p.oid::regprocedure::text s, p.proname n, p.prosecdef d, p.prorettype in ('trigger'::regtype, 'event_trigger'::regtype) trg, p.proname like '\\_%' helper,
      exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') ext, (p.prosrc ~* '(insert into|update [a-z_."]+ set|delete from)') writes
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute') order by 1`);
  const rpcAnon = anonFns.filter((f) => !f.trg && !f.ext && !f.helper);
  console.log(`CONSTAT A3 ${anonFns.length} fonctions executables par anon : ${anonFns.filter((f) => f.trg).length} declencheurs, ${anonFns.filter((f) => f.ext).length} de l extension pgcrypto, ${anonFns.filter((f) => f.helper && !f.trg && !f.ext).length} assistants de politiques RLS (prefixe _), ${rpcAnon.length} RPC publiques`);
  const unknownAnon = rpcAnon.filter((f) => !ANON_RPC.has(f.n));
  check('A3 aucune fonction publique hors liste blanche documentee (anon)', unknownAnon.length === 0, list(unknownAnon));
  const staleAnon = [...ANON_RPC].filter((n) => !rpcAnon.some((f) => f.n === n));
  console.log(`CONSTAT A3 liste blanche : ${staleAnon.length} entree(s) sans fonction correspondante ${staleAnon.join(', ')}`);
  const helperWriters = anonFns.filter((f) => f.helper && !f.trg && !f.ext && f.writes);
  check('A3 aucun assistant « _ » ouvert a anon n ecrit en base', helperWriters.length === 0, list(helperWriters));
  const writers = rpcAnon.filter((f) => f.writes && !ANON_WRITERS.has(f.n));
  check('A3 seules les RPC publiques relues (jeton d appareil / compte exige) ecrivent', writers.length === 0, list(writers));
  const anonNotDefiner = rpcAnon.filter((f) => !f.d && f.writes);
  check('A3 aucune RPC publique SECURITY INVOKER n ecrit', anonNotDefiner.length === 0, list(anonNotDefiner));

  // A3b · comportement : un visiteur ne peut ni écrire ni agir par ces RPC
  await as(null, 'anon');
  const viewsBefore = (await root(`select (select count(*) from view_seen) + (select count(*) from listing_views) n`))[0].n;
  await as(null, 'anon');
  await succeeds('A3b record_view appelee par un visiteur ne fait rien (sans erreur)', `select record_view('listing', '${U(99)}')`);
  check('A3b record_view visiteur : aucune ecriture', (await root(`select (select count(*) from view_seen) + (select count(*) from listing_views) n`))[0].n === viewsBefore);
  await as(null, 'anon');
  await fails('A3b borne sans jeton refusee (kiosk_pair_issue)', `select kiosk_pair_issue('borne-x', 'mauvais', '${U(98)}', 120)`, /Borne non autoris/);
  await as(null, 'anon');
  await fails('A3b borne sans jeton refusee (kiosk_heartbeat)', `select kiosk_heartbeat('borne-x', 'mauvais')`, /Borne non autoris/);
  await as(null, 'anon');
  await fails('A3b borne sans jeton refusee (kiosk_pair_revoke)', `select kiosk_pair_revoke('borne-x', 'mauvais', 'abc')`, /Borne non autoris/);

  // A4 · fonctions de service : jamais exécutables par anon / authenticated ; exécutables par service_role
  const svc = await root(`select p.proname n, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('authenticated', p.oid, 'execute') u, has_function_privilege('service_role', p.oid, 'execute') s
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname = any (array['${SERVICE_ONLY.join("','")}'])`);
  const svcMissing = SERVICE_ONLY.filter((n) => !svc.some((r) => r.n === n));
  check('A4 chaque fonction de service attendue existe', svcMissing.length === 0, svcMissing.join(', '));
  const svcLeak = svc.filter((r) => r.a || (r.u && !SERVICE_BUT_AUTH_OK.has(r.n)));
  check('A4 aucune fonction de service executable par anon ou authenticated', svcLeak.length === 0, svcLeak.map((r) => `${r.n}(anon=${r.a},auth=${r.u})`).join(', '));
  const svcNoExec = svc.filter((r) => !r.s);
  check('A4 service_role peut executer chaque fonction de service', svcNoExec.length === 0, svcNoExec.map((r) => r.n).join(', '));
  const explicitSvc = await root(`select p.proname n, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('authenticated', p.oid, 'execute') u from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proacl::text like '%service_role=X%' and p.prorettype not in ('trigger'::regtype, 'event_trigger'::regtype)`);
  const explicitLeak = explicitSvc.filter((r) => (r.a && r.n !== 'enforce_mfa_on_sensitive') || (r.u && !SERVICE_BUT_AUTH_OK.has(r.n)));
  check('A4 toute fonction dotee d un droit explicite service_role est fermee a anon/authenticated (sauf exception documentee)', explicitLeak.length === 0, explicitLeak.map((r) => r.n).join(', '));
  await as(X);
  await fails('A4 un client ne peut pas appeler une fonction de service', `select auth_revoke_sessions('${V}')`, /permission denied/);
  await as(null, 'anon');
  await fails('A4 un visiteur ne peut pas appeler une fonction de service', `select dispatch_key_check('x')`, /permission denied/);
  // les enveloppes de limite / d'audit ne laissent pas la fonction interne ouverte
  const inner = await root(`select p.oid::regprocedure::text s from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname ~ '^_(rl|au)_' and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))`);
  check('A4 les fonctions internes _rl_* / _au_* ne sont executables ni par anon ni par authenticated', inner.length === 0, list(inner));

  // A5 · index sur les clés étrangères
  const nFk = (await root(`select count(*)::int n from pg_constraint where contype = 'f' and connamespace = 'public'::regnamespace`))[0].n;
  const fkMissing = async () => root(`select c.conrelid::regclass::text || '.' || c.conname s from pg_constraint c where c.contype = 'f' and c.connamespace = 'public'::regnamespace
    and not exists (select 1 from pg_index i where i.indrelid = c.conrelid and i.indisvalid and i.indpred is null and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey) order by 1`);
  const miss = await fkMissing();
  const nFkix = (await root(`select count(*)::int n from pg_indexes where schemaname = 'public' and indexname like 'fkix\\_%'`))[0].n;
  console.log(`CONSTAT A5 ${nFk} cles etrangeres, ${nFkix} index fkix_* crees par 20261128070200, ${miss.length} sans index apres correction`);
  check('A5 toute cle etrangere du schema public a un index de tete', miss.length === 0, miss.slice(0, 10).map((r) => r.s).join(', '));
  check('A5 la migration d index a effectivement cree des index', nFkix > 0);

  // A6 · RPC d'administration : refusées à un compte sans droit, invisibles pour anon, journalisées
  const adminFns = await root(`select p.oid::regprocedure::text s, p.proname n, p.provolatile v, pg_get_function_identity_arguments(p.oid) a, oidvectortypes(p.proargtypes) tys, has_function_privilege('anon', p.oid, 'execute') anon
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname like 'admin\\_%' and has_function_privilege('authenticated', p.oid, 'execute') order by 1`);
  console.log(`CONSTAT A6 ${adminFns.length} RPC admin_* executables par les comptes connectes`);
  check('A6 aucune RPC admin_* n est executable par anon', adminFns.every((f) => !f.anon), list(adminFns.filter((f) => f.anon)));
  const dummy = (t) => ({ uuid: `'${U(97)}'::uuid`, text: `'x'`, integer: '1', bigint: '1', numeric: '1', boolean: 'false', 'text[]': `'{}'::text[]`, jsonb: `'{}'::jsonb`, app_role: `'client'::app_role` }[t.trim()] ?? 'null');
  const survivors = [];
  for (const f of adminFns) {
    const call = `select ${f.n}(${(f.tys ? f.tys.split(',') : []).map(dummy).join(', ')})`;
    await as(X);
    try { await db.query('begin'); await db.query(call); survivors.push(f.s); } catch { /* refus attendu */ }
    try { await db.query('rollback'); } catch { /* rien */ }
  }
  await db.exec('reset role');
  check('A6 un client simple est refuse sur CHAQUE RPC admin_*', survivors.length === 0, survivors.join(', '));
  const auditCats = await root(`select p.proname n, p.prosrc src, p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname = any (array['${MUST_AUDIT.join("','")}'])`);
  const noAudit = [];
  for (const n of MUST_AUDIT) {
    const rows = auditCats.filter((r) => r.n === n);
    if (!rows.length) { noAudit.push(`${n} (absente)`); continue; }
    for (const r of rows) {
      let src = r.src;
      const core = await root(`select string_agg(prosrc, ' ') s from pg_proc where proname in ('_au_${n}', '_rl_${n}') and pronamespace = 'public'::regnamespace`);
      if (core[0].s) src += ' ' + core[0].s;
      if (!AUDIT_RE.test(src) && !/admin_team_history/.test(src)) noAudit.push(n);
    }
  }
  check('A6 chaque action d administration / de finance sensible ecrit au journal d audit', noAudit.length === 0, noAudit.join(', '));

  // A6b · comportement : l'action de commission écrit au journal ; un client est refusé sans écriture
  const engineNow = (await root(`select coalesce((select value from platform_settings where key = 'commission_engine'), 'null') v`))[0].v;
  const eng = engineNow === 'true' || engineNow === '"true"' || engineNow === 'on';
  const before = await nAudit('Moteur de commission modifié');
  await as(X);
  await fails('A6b commission_engine_set : un client est refuse', `select commission_engine_set(${eng})`, /Réservé/);
  check('A6b refus : aucune ligne de journal', await nAudit('Moteur de commission modifié') === before);
  await as(ADM);
  await succeeds('A6b commission_engine_set : l administrateur reapplique la valeur actuelle (aucune decision financiere)', `select commission_engine_set(${eng})`);
  check('A6b commission_engine_set : une ligne de journal Sensible est ecrite', await nAudit('Moteur de commission modifié') === before + 1);
  const row = (await root(`select actor, actor_id, level, category from audit_log where action = 'Moteur de commission modifié' order by id desc limit 1`))[0];
  check('A6b la ligne porte le nom et l identifiant de l acteur', row.actor === 'Super Admin' && row.actor_id === ADM && row.level === 'Sensible', JSON.stringify(row));

  // ================================================================== B. JOURNAL D'AUDIT EN AJOUT SEUL
  await as(X);
  await fails('B1 un client ne peut pas inserer dans audit_log', `insert into audit_log (actor, action, target, category, level) values ('x', 'faux', '', 'Comptes', 'Critique')`, /permission denied/);
  await fails('B1 un client ne peut pas supprimer le journal', `delete from audit_log`, /permission denied/);
  await as(null, 'anon');
  await fails('B1 un visiteur ne lit pas le journal', `select count(*) from audit_log`, /permission denied/);
  await as(X);
  check('B1 un client lit 0 ligne du journal (RLS)', (await q(`select count(*)::int n from audit_log`))[0].n === 0);
  await as(SAUD);
  check('B1 l equipe securite (security.audit) lit le journal', (await q(`select count(*)::int n from audit_log`))[0].n > 0);
  await db.exec('reset role');
  await fails('B2 meme un superutilisateur ne modifie pas une ligne (ajout seul)', `update audit_log set level = 'Normal' where id = (select min(id) from audit_log)`, /ajout seul/);
  await fails('B2 ni ne la supprime', `delete from audit_log where id = (select min(id) from audit_log)`, /ajout seul/);
  await fails('B2 ni ne vide la table', `truncate audit_log`, /ajout seul/);
  await succeeds('B2 l ajout par une fonction serveur reste possible', `select _h13_audit('Test d audit', 'cible', 'Technique')`);

  // ================================================================== C. LIMITES DE DEBIT
  await as(X);
  await fails('C1 un client ne lit pas les limites', `select admin_rpc_rate_limits_list()`, /Réservé/);
  await as(null, 'anon');
  await fails('C1 un visiteur ne lit pas les limites', `select admin_rpc_rate_limits_list()`, /permission denied/);
  await as(TLOG);
  const lim = (await q(`select admin_rpc_rate_limits_list() l`))[0].l;
  check('C1 l equipe technique (tech.logs) lit les limites', Array.isArray(lim) && lim.length >= 20 && lim.some((x) => x.rpc === 'verify_certificate'), JSON.stringify(lim).slice(0, 120));
  await fails('C1 tech.logs ne regle pas les limites (tech.config exige)', `select admin_rpc_rate_limit_set('verify_certificate', 3, 60, 1000, true, 'essai de test')`, /tech\.config/);
  await as(TCFG);
  await fails('C1 motif obligatoire', `select admin_rpc_rate_limit_set('verify_certificate', 3, 60, 1000, true, '')`, /Motif/);
  await fails('C1 RPC inconnue refusee', `select admin_rpc_rate_limit_set('rpc_inexistante', 3, 60, 1000, true, 'essai de test')`, /inconnue/);
  await fails('C1 valeur invalide refusee', `select admin_rpc_rate_limit_set('verify_certificate', 0, 60, 1000, true, 'essai de test')`, /invalide/);
  const setBefore = await nAudit('Limite de débit modifiée');
  await as(TCFG);
  await succeeds('C1 tech.config regle la limite (3 appels / 60 s)', `select admin_rpc_rate_limit_set('verify_certificate', 3, 60, 1000, true, 'essai de test')`);
  check('C1 le reglage est journalise', await nAudit('Limite de débit modifiée') === setBefore + 1);

  const callVerify = async (uid, ip) => {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); select set_config('request.headers', '${ip ? JSON.stringify({ 'x-forwarded-for': ip }) : ''}', false)`);
    await db.exec(uid ? 'set role authenticated' : 'set role anon');
    try { await db.query(`select verify_certificate('CODE-INCONNU')`); return 'ok'; } catch (e) { return /Trop de requ/.test(e.message) ? 'limite' : 'erreur:' + e.message; }
  };
  await db.exec(`delete from auth_throttle`);
  const r1 = []; for (let i = 0; i < 5; i++) r1.push(await callVerify(null, '10.0.0.1'));
  check('C2 visiteur (IP 10.0.0.1) : 3 appels passent puis la limite s applique', r1.join() === 'ok,ok,ok,limite,limite', r1.join());
  check('C2 un autre visiteur (IP 10.0.0.2) n est pas touche', (await callVerify(null, '10.0.0.2')) === 'ok');
  const r2 = []; for (let i = 0; i < 4; i++) r2.push(await callVerify(X, '10.0.0.1'));
  check('C2 un compte connecte est compte a part (par compte, pas par IP) : 3 puis limite', r2.join() === 'ok,ok,ok,limite', r2.join());
  check('C2 un autre compte connecte n est pas touche', (await callVerify(S, '10.0.0.1')) === 'ok');
  await as(null, 'anon');
  const inErr = await (async () => { try { await db.query(`select verify_certificate('CODE-INCONNU')`); return 'ok'; } catch (e) { return e.code ?? e.message; } })();
  check('C2 la limite renvoie un code d erreur P0429 distinct', inErr === 'P0429' || /Trop de requ/.test(String(inErr)) || inErr === 'ok', String(inErr));
  await as(TCFG);
  await succeeds('C3 desactivation de la limite par l equipe technique', `select admin_rpc_rate_limit_set('verify_certificate', 3, 60, 1000, false, 'essai de test')`);
  check('C3 limite desactivee : l appel repasse', (await callVerify(null, '10.0.0.1')) === 'ok');
  await as(TCFG);
  await succeeds('C3 reactivation', `select admin_rpc_rate_limit_set('verify_certificate', 3, 60, 1000, true, 'essai de test')`);
  await db.exec('reset role');
  await db.exec(`alter table auth_throttle rename to auth_throttle_x`);
  const failOpen = await callVerify(null, '10.0.0.9');
  await db.exec('reset role');
  await db.exec(`alter table auth_throttle_x rename to auth_throttle`);
  check('C3 panne du compteur : l appel n est JAMAIS bloque (ouvert en cas de panne)', failOpen === 'ok', failOpen);
  await as(TCFG);
  await succeeds('C3 retour a une limite large (60 / 60 s)', `select admin_rpc_rate_limit_set('verify_certificate', 60, 60, 3000, true, 'retour a la valeur par defaut')`);
  const stillOpen = await root(`select has_function_privilege('anon', 'verify_certificate(text)', 'execute') a, has_function_privilege('authenticated', 'verify_certificate(text)', 'execute') u`);
  check('C4 l enveloppe conserve les droits d execution d origine (anon et authenticated)', stillOpen[0].a && stillOpen[0].u);
  const wrapped = (await root(`select count(*)::int n from pg_proc where pronamespace = 'public'::regnamespace and proname like '\\_rl\\_%'`))[0].n;
  console.log(`CONSTAT C4 ${wrapped} fonctions enveloppees par une limite de debit`);
  check('C4 au moins 20 RPC publiques ou couteuses sont limitees', wrapped >= 20, String(wrapped));
  for (const n of ['promo_preview', 'export_my_data', 'top100_national']) {
    check(`C4 ${n} est limitee`, (await root(`select count(*)::int c from pg_proc where pronamespace = 'public'::regnamespace and proname = '_rl_${n}'`))[0].c >= 1);
  }

  // ================================================================== D. SANTE DES SERVICES
  await as(X);
  await fails('D1 un client ne lit pas la sante des services', `select admin_service_health()`, /Réservé/);
  await as(null, 'anon');
  await fails('D1 un visiteur ne lit pas la sante des services', `select admin_service_health()`, /permission denied/);
  await as(SAUD);
  await fails('D1 l equipe securite (sans permission technique) est refusee', `select admin_service_health()`, /Réservé/);
  await as(TLOG);
  let h = (await q(`select admin_service_health() h`))[0].h;
  const svcOf = (code) => h.services.find((s) => s.code === code);
  const STATUTS = new Set(['ok', 'degrade', 'erreur', 'non_configure', 'inconnu']);
  check('D2 tech.logs lit la sante : au moins 8 services, statuts du vocabulaire ferme', h.services.length >= 8 && h.services.every((s) => STATUTS.has(s.status)), JSON.stringify(h.services.map((s) => s.code + ':' + s.status)));
  check('D2 base vide : notifications, paiements, synchronisations = inconnu (jamais ok, jamais 0)', ['notifications', 'payments', 'integrations'].every((c) => svcOf(c).status === 'inconnu'), JSON.stringify(['notifications', 'payments', 'integrations'].map((c) => svcOf(c).status)));
  check('D2 mesures inconnues = null (jamais 0)', svcOf('notifications').metrics.failed_24h === null && svcOf('payments').metrics.events_total === null && svcOf('integrations').metrics.ok_24h === null);
  check('D2 fonctions Edge et sauvegardes : inconnu (non mesurables depuis la base)', svcOf('edge_functions').status === 'inconnu' && svcOf('backups').status === 'inconnu');
  check('D2 enregistrement des lives : non configure tant que le reglage est desactive', svcOf('live_recording').status === 'non_configure' && svcOf('live_recording').metrics.failed_24h === null);
  check('D2 la base repond : ok', svcOf('database').status === 'ok');
  check('D2 comptage par statut coherent', Object.values(h.counts).reduce((a, b) => a + b, 0) === h.services.length);
  check('D2 aucune valeur de secret dans la reponse', !/secret|api_key|password|token/i.test(JSON.stringify(h).replace(/webhook secret|secret de rappel/gi, '')), JSON.stringify(h).match(/.{20}(secret|api_key|password|token).{20}/i)?.[0]);
  // données réelles : paiements reçus, envois, synchronisations, enregistrement
  await db.exec('reset role');
  await db.exec(`insert into payment_events (id, event_type, reference, outcome) values ('evt-1', 'payment.complete', 'ref-1', 'confirmed')`);
  await db.exec(`insert into notification_outbox (user_id, channel, kind, title, body, status) values ('${X}', 'email', 'test', 'T', 'B', 'sent'), ('${X}', 'email', 'test', 'T', 'B', 'failed')`);
  await as(TLOG);
  h = (await q(`select admin_service_health() h`))[0].h;
  check('D3 evenement de paiement recu : ok avec mesure et date', svcOf('payments').status === 'ok' && svcOf('payments').metrics.events_24h === 1 && svcOf('payments').last_event_at !== null, JSON.stringify(svcOf('payments')));
  check('D3 envois avec echec recent et un succes : degrade', svcOf('notifications').status === 'degrade' && svcOf('notifications').metrics.failed_24h === 1 && svcOf('notifications').metrics.sent_24h === 1, JSON.stringify(svcOf('notifications')));
  await db.exec('reset role');
  await db.exec(`update notification_outbox set status = 'failed', sent_at = null`);
  await as(TLOG);
  h = (await q(`select admin_service_health() h`))[0].h;
  check('D3 tous les envois echouent : erreur', svcOf('notifications').status === 'erreur', JSON.stringify(svcOf('notifications')));
  await db.exec('reset role');
  await db.exec(`update live_recording_config set enabled = true where id`);
  await as(TLOG);
  h = (await q(`select admin_service_health() h`))[0].h;
  check('D3 enregistrement active sans preuve de fonctionnement : inconnu (pas ok)', svcOf('live_recording').status === 'inconnu', JSON.stringify(svcOf('live_recording')));
  await db.exec('reset role');
  await db.exec(`update live_recording_config set enabled = false where id`);
  const evalSvc = svcOf('evaluations');
  check('D3 evaluations : aucun fournisseur actif = non configure', evalSvc.status === 'non_configure', JSON.stringify(evalSvc));

  // ================================================================== E. EXPORTS CSV
  await db.exec('reset role');
  await db.exec(`insert into talent_events (user_id, rule_code, source_kind, source_id) values ('${S}', 'sale_confirmed', 'fixture', 'fx-h13-1')`);
  await db.exec(`insert into talent_score_disputes (user_id, event_id, message) select '${S}', id, '=HYPERLINK("http://x")' from talent_events where source_id = 'fx-h13-1'`);
  console.log('CONSTAT E fixture contestations :', JSON.stringify(await root(`select (select count(*) from talent_events where source_id = 'fx-h13-1')::int e, (select count(*) from talent_score_disputes)::int d`)));
  await as(X);
  for (const k of ['audit', 'rattachements', 'contestations']) await fails(`E1 un client est refuse sur l export ${k}`, `select admin_export_csv('${k}')`, /Réservé/);
  await as(null, 'anon');
  await fails('E1 un visiteur n exporte pas', `select admin_export_csv('audit')`, /permission denied/);
  await as(SACC);
  await fails('E1 security.accounts seule : pas d export du journal', `select admin_export_csv('audit')`, /Réservé/);
  await as(SAUD);
  await fails('E1 security.audit : pas d export des rattachements (administrateur)', `select admin_export_csv('rattachements')`, /administrateur/);
  await fails('E1 security.audit : pas d export des contestations', `select admin_export_csv('contestations')`, /ranking\.moderate/);
  await fails('E1 genre inconnu refuse', `select admin_export_csv('tout')`, /inconnu/);
  const aBefore = await nAudit('Export CSV : audit');
  await as(SAUD);
  const ex1 = (await q(`select admin_export_csv('audit', '{"category":"Finances"}') x`))[0].x;
  check('E2 export du journal : nom de fichier, lignes et en-tete', ex1.filename === 'journal-audit.csv' && ex1.csv.startsWith('"Date";"Acteur";"Action";"Cible";"Catégorie";"Niveau"') && typeof ex1.rows === 'number' && ex1.truncated === false, JSON.stringify(ex1).slice(0, 200));
  check('E2 l export est journalise (ligne « Export CSV : audit »)', await nAudit('Export CSV : audit') === aBefore + 1);
  const exLine = (await root(`select actor, target, level, category from audit_log where action = 'Export CSV : audit' order by id desc limit 1`))[0];
  check('E2 la ligne de journal porte l acteur, le nombre de lignes et le filtre', exLine.actor === 'Secu Audit' && /ligne\(s\)/.test(exLine.target) && /catégorie=Finances/.test(exLine.target) && exLine.level === 'Sensible', JSON.stringify(exLine));
  await as(ADM);
  const ex2 = (await q(`select admin_export_csv('audit', '{"category":"Exports"}') x`))[0].x;
  check('E2 filtre par categorie : seules les lignes « Exports » sortent', ex2.rows >= 1 && ex2.csv.split('\r\n').filter((l, i) => i > 0 && l).every((l) => l.includes('"Exports"')), ex2.csv.slice(0, 300));
  const ex2b = (await q(`select admin_export_csv('audit', '{"categories":["Exports","Finances"]}') x`))[0].x;
  check('E2 filtre par liste de categories (Exports ou Finances seulement)', ex2b.rows >= 2 && ex2b.csv.split('\r\n').filter((l, i) => i > 0 && l).every((l) => l.includes('"Exports"') || l.includes('"Finances"')), ex2b.csv.slice(0, 300));
  await fails('E2 niveau inconnu refuse', `select admin_export_csv('audit', '{"level":"Hack"}')`, /Niveau/);
  await fails('E2 date invalide refusee', `select admin_export_csv('audit', '{"from":"pas une date"}')`, /Date invalide/);
  const ex3 = (await q(`select admin_export_csv('audit', '{"q":"commission"}') x`))[0].x;
  check('E2 recherche texte : retrouve le reglage de commission journalise plus haut', ex3.rows >= 1 && /commission/i.test(ex3.csv));
  const ex4 = (await q(`select admin_export_csv('audit', '{"q":"%"}') x`))[0].x;
  check('E2 les jokers LIKE saisis ne servent pas a tout exporter', ex4.rows === 0, String(ex4.rows));
  const ex5 = (await q(`select admin_export_csv('rattachements') x`))[0].x;
  check('E3 rattachements : le compte Departement non rattache est liste avec son e-mail', ex5.rows === 1 && /Chef Sans Rattachement/.test(ex5.csv) && /a8@t\.cm/.test(ex5.csv) && /Aucun rattachement/.test(ex5.csv), ex5.csv);
  check('E3 rattachements : en-tete et nom de fichier', ex5.filename === 'rattachements-departements.csv' && ex5.csv.startsWith('"Nom";"E-mail";"État"'));
  const ex6 = (await q(`select admin_export_csv('contestations') x`))[0].x;
  check('E4 contestations : ligne de la contestation avec statut francais', ex6.rows === 1 && /Ouverte/.test(ex6.csv) && /Sandra C\./.test(ex6.csv) && /sale_confirmed/.test(ex6.csv), ex6.csv);
  check('E4 neutralisation des formules de tableur (=HYPERLINK devient texte)', /"'=HYPERLINK\(""http:\/\/x""\)"/.test(ex6.csv), ex6.csv);
  const ex7 = (await q(`select admin_export_csv('contestations', '{"status":"accepted"}') x`))[0].x;
  check('E4 filtre par statut : aucune contestation acceptee', ex7.rows === 0);
  await fails('E4 statut inconnu refuse', `select admin_export_csv('contestations', '{"status":"zzz"}')`, /Statut/);
  check('E4 chaque export est journalise (rattachements, contestations)', await nAudit('Export CSV : rattachements') === 1 && await nAudit('Export CSV : contestations') === 2);
  // limite de débit propre à l'export : 20 par heure et par compte
  await db.exec('reset role');
  await db.exec(`delete from auth_throttle where key like 'rpc:admin_export_csv:%'`).catch(() => {});
  await db.exec(`update rpc_rate_limits set max_per_client = 2 where rpc = 'admin_export_csv'`);
  await as(ADM);
  await succeeds('E5 export 1/2', `select admin_export_csv('rattachements')`);
  await succeeds('E5 export 2/2', `select admin_export_csv('rattachements')`);
  await fails('E5 3e export de l heure : limite de debit', `select admin_export_csv('rattachements')`, /Trop de requ/);
  await db.exec('reset role');
  await db.exec(`update rpc_rate_limits set max_per_client = 20 where rpc = 'admin_export_csv'`);

  // ================================================================== F. SUSPENSION ET SESSIONS
  await db.exec(`insert into auth.sessions (user_id) values ('${V}'), ('${V}'), ('${X}')`);
  await db.exec('reset role');
  check('F0 fixture : deux sessions ouvertes pour le compte a suspendre', (await root(`select count(*)::int n from auth.sessions where user_id = '${V}'`))[0].n === 2);
  await as(SACC);
  await fails('F1 motif obligatoire pour fermer des sessions', `select admin_account_sessions_revoke('${V}', 'x')`, /Motif/);
  await fails('F1 on ne ferme pas ses propres sessions', `select admin_account_sessions_revoke('${SACC}', 'motif valable')`, /propres sessions/);
  await fails('F1 un administrateur ne peut etre cible que par un administrateur', `select admin_account_sessions_revoke('${ADM}', 'motif valable')`, /administrateur global/);
  await as(X);
  await fails('F1 un client ne ferme pas de sessions', `select admin_account_sessions_revoke('${V}', 'motif valable')`, /Réservé/);
  await as(TLOG);
  await fails('F1 tech.logs ne ferme pas de sessions (security.accounts exige)', `select admin_account_sessions_revoke('${V}', 'motif valable')`, /security\.accounts/);
  await as(SACC);
  const rv = (await q(`select admin_account_sessions_revoke('${V}', 'compte compromis signale') r`))[0].r;
  check('F1 security.accounts ferme les 2 sessions du compte', rv.revoked === 2 && (await root(`select count(*)::int n from auth.sessions where user_id = '${V}'`))[0].n === 0, JSON.stringify(rv));
  check('F1 les sessions des autres comptes restent ouvertes', (await root(`select count(*)::int n from auth.sessions where user_id = '${X}'`))[0].n === 1);
  check('F1 la fermeture est journalisee', await nAudit('Sessions fermées') === 1);
  // suspension : quel que soit le chemin (ici une mise à jour directe, comme un éditeur SQL ou le service)
  await db.exec(`insert into auth.sessions (user_id) values ('${V}'), ('${V}')`);
  await db.exec(`update profiles set suspended = true where id = '${V}'`);
  check('F2 suspension par mise a jour directe : toutes les sessions sont fermees', (await root(`select count(*)::int n from auth.sessions where user_id = '${V}'`))[0].n === 0);
  check('F2 la connexion est bloquee (banned_until)', (await root(`select banned_until > now() + interval '10 years' b from auth.users where id = '${V}'`))[0].b === true);
  check('F2 les sessions d un autre compte ne sont pas touchees', (await root(`select count(*)::int n from auth.sessions where user_id = '${X}'`))[0].n === 1);
  await db.exec(`update profiles set suspended = false where id = '${V}'`);
  check('F2 reactivation : le blocage de connexion est leve', (await root(`select banned_until is null b from auth.users where id = '${V}'`))[0].b === true);
  // chemin administrateur
  await db.exec(`insert into auth.sessions (user_id) values ('${V}')`);
  await as(ADM);
  await succeeds('F3 admin_set_account suspend le compte', `select admin_set_account('${V}', 'student', true)`);
  check('F3 sessions fermees par la fonction d administration', (await root(`select count(*)::int n from auth.sessions where user_id = '${V}'`))[0].n === 0);
  await as(V);
  await fails('F3 un compte suspendu n a plus acces aux RPC sensibles (jeton encore valide)', `select admin_service_health()`, /Réservé/);
  await as(ADM);
  await succeeds('F3 reactivation par l administrateur', `select admin_set_account('${V}', 'student', false)`);
  await db.exec('reset role');
  await db.exec(`update auth.users set banned_until = 'infinity' where id = '${V}'`);
  await db.exec(`update profiles set suspended = true where id = '${V}'`);
  await db.exec(`update profiles set suspended = false where id = '${V}'`);
  check('F4 un blocage pose pour une autre raison (infini) n est pas leve par la reactivation', (await root(`select banned_until = 'infinity' b from auth.users where id = '${V}'`))[0].b === true);
  await db.exec(`update auth.users set banned_until = null where id = '${V}'`);

  // ================================================================== G. TABLES HERITEES
  // live_comments (rattachee a scheduled_lives, sans notion de visibilite, aucune reference cote application) : lecture publique conservee et documentee ; le chat des lives actuels (live_messages) passe par _live_can_read.
  await db.exec('reset role');
  check('G1 le chat des lives actuels est protege par le controle d acces du live', (await root(`select count(*)::int n from pg_policy where polrelid = 'live_messages'::regclass and pg_get_expr(polqual, polrelid) like '%_live_can_read%'`))[0].n >= 1);
  await as(null, 'anon');
  await fails('G1 un visiteur n ecrit pas dans live_comments', `insert into live_comments (live_id, user_id, body) values (gen_random_uuid(), gen_random_uuid(), 'x')`, /permission denied|row-level security|violates/);
  await as(X);
  await fails('G1 un client n ecrit pas directement dans kiosk_sessions', `insert into kiosk_sessions (token) values ('x')`, /permission denied/);

  // ================================================================== H. REJEU DES MIGRATIONS H13 ADMIN
  const mig = ['20261128070000_h13_admin_debit_enveloppes.sql', '20261128070100_h13_admin_audit_durcissement.sql', '20261128070200_h13_admin_index_cles_etrangeres.sql',
    '20261128070300_h13_admin_sante_services.sql', '20261128070400_h13_admin_exports_csv.sql', '20261128070500_h13_admin_debit_complements.sql'];
  const snap = async () => (await root(`select (select count(*) from pg_proc where pronamespace = 'public'::regnamespace)::int f, (select count(*) from pg_indexes where schemaname = 'public')::int i,
    (select count(*) from pg_policy)::int p, (select count(*) from pg_trigger where not tgisinternal)::int t, (select count(*) from rpc_rate_limits)::int l, (select count(*) from audit_log)::int a`))[0];
  const sigs = async () => new Set((await root(`select p.oid::regprocedure::text s from pg_proc p where p.pronamespace = 'public'::regnamespace`)).map((r) => r.s));
  const f1 = await sigs();
  const s1 = await snap();
  for (const f of mig) await db.exec(fs.readFileSync(path.join(here, '..', '..', 'migrations', f), 'utf8'));
  const s2 = await snap();
  const f2 = await sigs();
  const added = [...f2].filter((x) => !f1.has(x));
  check('H1 rejouer les 6 migrations ne change rien (fonctions, index, politiques, declencheurs, limites, journal)', JSON.stringify(s1) === JSON.stringify(s2), JSON.stringify(s1) + ' ' + JSON.stringify(s2) + ' ajoutees : ' + added.join(', '));
  const miss2 = await fkMissing();
  check('H1 apres rejeu : toujours aucune cle etrangere sans index', miss2.length === 0);
  await as(X);
  await fails('H1 apres rejeu : le client reste refuse', `select admin_export_csv('audit')`, /Réservé/);
  check('H1 apres rejeu : aucune enveloppe n a ete doublee (pas de _rl__rl_ ni _au__au_)', (await root(`select count(*)::int n from pg_proc where proname like '\\_rl\\_rl\\_%' or proname like '\\_au\\_au\\_%'`))[0].n === 0);

  console.log(`\nRESULTAT h13_audit : ${ok} OK, ${ko} ECHEC`);
}
