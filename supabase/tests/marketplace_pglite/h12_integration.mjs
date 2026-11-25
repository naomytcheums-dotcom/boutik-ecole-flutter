// Scénario PGlite du lot H12 / INTEGRATION-SQL : branchement des sources réelles sur le moteur de score (migrations 20261127030000 à 030300), puis parcours complet
// « étudiant vérifié -> replay à 100 % -> badge -> événements de talent -> points (règle activée dans le test) -> classement figé -> Top 100 national et filière -> découverte
// par l'entreprise -> vivier -> demande de contact -> notification de l'étudiant », avec cas négatifs (replay non terminé, règle inactive, non vérifié / non consentant exclus,
// fraude, annulation, isolation entre organisations). Toutes les données sont des fixtures de test (aucune pondération n'est fixée par le code).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h12_integration.mjs
import fs from 'fs';
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-00000015${String(n).padStart(4, '0')}`;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims({})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const sup = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { await sup(); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const DENY = /permission denied|Connexion requise|Réservé|refusé|introuvable|exige/i;
  const P1 = (await qs(`select to_char(now() at time zone 'utc', 'YYYY-MM') p`))[0].p;
  const P0 = (await qs(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;

  // ============================================================ A. MIGRATIONS SEULES
  check('A1 migrations seules : aucun événement, aucune écriture de points, aucun score', (await qs(`select (select count(*) from talent_events) + (select count(*) from talent_score_ledger) + (select count(*) from talent_scores) n`))[0].n == 0);
  const trg = async () => (await qs(`select tgname from pg_trigger where tgname in ('trg_talent_lives', 'trg_talent_lives_delete', 'trg_talent_skills', 'trg_talent_skill_docs', 'trg_talent_collab_projects', 'trg_talent_collab_projects_delete', 'trg_talent_collab_members', 'trg_talent_replay_completions', 'trg_talent_user_badges') and not tgisinternal order by 1`)).map((x) => x.tgname);
  check('A2 déclencheurs des sources antérieures aux migrations 03xxxx posés (live, compétence, justificatif, collaboration)', (await trg()).length >= 7, (await trg()).join());
  const hooksBefore = (await trg()).filter((t) => /replay|badges/.test(t)).length;
  console.log(`INFO ordre des migrations : déclencheurs replay/badge déjà posés après les migrations seules = ${hooksBefore} (les tables replay naissent dans 20261127300100, après 030000 : l'installateur conditionnel doit être rappelé)`);
  await as(U(900));
  await fails('A3 un connecté ne peut pas appeler l\'installateur ni le moteur', `select _talent_install_replay_hooks()`, /permission denied/i);
  await fails('A3b un connecté ne peut pas enregistrer un événement de score', `select _talent_event_record('${U(900)}', 'live_hosted', 'live', 'x', now(), null, null, '{}'::jsonb)`, /permission denied/i);
  await as(null);
  await fails('A3c anonyme : mêmes fonctions refusées', `select _talent_sync_live('${U(900)}')`, /permission denied/i);
  await sup();
  const inst = await rpc(`_talent_install_replay_hooks()`);
  check('A4 installateur rappelé après les migrations replay : replay_completions et user_badges câblés', JSON.stringify(inst) === JSON.stringify(['replay_completions', 'user_badges']), JSON.stringify(inst));
  check('A5 les 9 déclencheurs sont posés, une seule fois chacun', (await trg()).length === 9, (await trg()).join());
  const inst2 = await rpc(`_talent_install_replay_hooks()`);
  check('A5b installateur idempotent : toujours 9 déclencheurs', JSON.stringify(inst2) === JSON.stringify(inst) && (await trg()).length === 9);

  // ============================================================ B. FIXTURES (créées dans le test)
  // 1 admin ; 2 agent de publication (ranking.publish + ranking.rules) ; 6 entreprise A ; 7 entreprise B ; 8 entreprise hôte de live ; 9 autre étudiant (client de test)
  const mkUser = async (n, role, name, email) => { await db.exec(`insert into auth.users(id,email) values ('${U(n)}','${email}'); insert into profiles(id,name,role,email) values ('${U(n)}','${name}','${role}','${email}')`); return U(n); };
  const ADM = await mkUser(1, 'admin', 'Admin Intégration', 'itg1@t.cm');
  const PUB = await mkUser(2, 'support', 'Agent Publication', 'itg2@t.cm');
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${PUB}', 'ranking', array['ranking.publish', 'ranking.rules'])`);
  const C1 = await mkUser(6, 'company', 'Entreprise Un', 'itg6@t.cm');
  const C2 = await mkUser(7, 'company', 'Entreprise Deux', 'itg7@t.cm');
  const C3 = await mkUser(8, 'company', 'Entreprise Hôte', 'itg8@t.cm');
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${C1}', 'Orange Intégration', 'approved'), ('${C2}', 'Camtel Intégration', 'approved')`);
  const I1 = '00000000-0000-0000-0000-00000015a001', D1 = '00000000-0000-0000-0000-00000015a011', G1 = '00000000-0000-0000-0000-00000015a021';
  await db.exec(`insert into institutions (id, name, short_name, status) values ('${I1}', 'Université Intégration', 'UIN', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified');
    insert into programs (id, institution_id, department_id, name) values ('${G1}', '${I1}', '${D1}', 'Génie logiciel')`);
  const mkStudent = async (n, { verified = true, consent = false, program = false, email = null, name = null } = {}) => {
    const id = U(100 + n);
    await db.exec(`insert into auth.users(id,email) values ('${id}','${email ?? `itgs${n}@t.cm`}'); insert into profiles(id,name,role,email) values ('${id}','${name ?? `Etudiant Int${n}`}','student','${email ?? `itgs${n}@t.cm`}')`);
    if (verified) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${id}', 'student_card', 'c.pdf', '${id}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${id}'`);
    if (program) await db.exec(`insert into student_affiliations (user_id, institution_id, department_id, program_id, promotion, status) values ('${id}', '${I1}', '${D1}', '${G1}', '2026', 'verified')`);
    if (consent) await db.exec(`insert into talent_visibility_settings (user_id, public_ranking, show_full_name, shared_sections) values ('${id}', true, true, array['rank','score','evolution','skills','badges','projects','passport'])`);
    return id;
  };
  // 1 hôte ; 2 héros (vérifié, consentant, rattaché) ; 3 non terminé ; 4 non vérifié ; 5 non consentant ; 6 alias de l'hôte (fraude) ; 7 retrait de points ; 8 partenaire de collaboration ; 9 et 10 comptes alias entre eux ;
  // 11 à 13 : autres étudiants du classement ; 14 spectateur
  const H = await mkStudent(1, { email: 'hote@t.cm', name: 'Hugo Hôte' });
  const HERO = await mkStudent(2, { consent: true, program: true, name: 'Héléna Héros' });
  const NT = await mkStudent(3);
  const NV = await mkStudent(4, { verified: false, consent: true, program: true });
  const NC = await mkStudent(5, { consent: false, program: true });
  const FR = await mkStudent(6, { consent: true, program: true, email: 'h.o.t.e+bis@t.cm', name: 'Alias Hôte' });
  const CX = await mkStudent(7);
  const E2 = await mkStudent(8, { name: 'Estelle Partenaire' });
  const HA = await mkStudent(9, { email: 'jeanne.d@t.cm' });
  const HB = await mkStudent(10, { email: 'jeanned+x@t.cm' });
  const F1 = await mkStudent(11, { consent: true, program: true }), F2 = await mkStudent(12, { consent: true, program: true }), F3 = await mkStudent(13, { consent: true, program: true });
  const V1 = await mkStudent(14);
  await db.exec(`grant select, delete on storage.objects to authenticated, anon`);

  const evs = (u, rule) => qs(`select id, status, status_reason, actor_id, source_kind, source_id, meta from talent_events where user_id = '${u}' and rule_code = '${rule}' order by id`);
  const total = async (u) => Number((await qs(`select coalesce((select total from talent_scores where user_id = '${u}'), 0) t`))[0].t);
  const ledgerSum = async (u) => Number((await qs(`select coalesce(sum(points), 0) t from talent_score_ledger where user_id = '${u}'`))[0].t);
  const consistent = async (u) => (await total(u)) === (await ledgerSum(u));
  const flags = (u) => qs(`select signal, status from talent_fraud_flags where user_id = '${u}' order by created_at`);

  // Un replay de 100 s sur un live terminé de l'hôte
  const mkLive = async (host, title, status = 'ended') => (await q(`insert into lives (host_id, title, status, started_at, ended_at) values ('${host}', '${title}', '${status}', now() - interval '2 hours', ${status === 'live' ? 'null' : `now() - interval '1 hour'`}) returning id`))[0].id;
  await sup();
  const LA = await mkLive(H, 'Atelier de soudure intégration');
  const RA = (await q(`insert into live_recordings (live_id, requested_by, status, storage_path, duration_sec, ready_at) values ('${LA}', '${H}', 'pret', '${H}/int.mp4', 100, now()) returning id`))[0].id;
  await db.exec(`insert into storage.objects (bucket_id, name) values ('live-replays', '${H}/int.mp4')`);
  const seq = { n: 0 };
  const ts = () => `(extract(epoch from clock_timestamp()) * 1000)::bigint + ${++seq.n}`;
  const arm = async (uid, rec, elapsed) => qs(`update replay_progress set session_at = clock_timestamp() - interval '${elapsed} seconds', win_start = null, win_count = 0 where user_id = '${uid}' and recording_id = '${rec}'`);
  const rep = async (uid, rec, from, to) => { await arm(uid, rec, 25); await as(uid); return rpc(`replay_progress_report('${rec}', ${from}, ${to}, ${ts()})`); };
  const watch = async (uid, rec, from, to) => {
    await sup();
    await as(uid); await rpc(`replay_playback_start('${rec}', ${from})`);
    await qs(`update replay_progress set created_at = now() - interval '3 hours' where user_id = '${uid}' and recording_id = '${rec}'`);
    let pos = from, last = null;
    while (pos < to) { const nx = Math.min(pos + 30, to); last = await rep(uid, rec, pos, nx); if (!last.accepted) return last; pos = nx; }
    await sup();
    return last;
  };

  // ============================================================ C. REPLAY ET BADGE : règles encore en brouillon (0 point)
  let o = await watch(NT, RA, 0, 60);
  check('C1 replay non terminé (60 %) : aucune complétion', o.accepted === true && o.completed === false && (await qs(`select count(*)::int n from replay_completions where user_id = '${NT}'`))[0].n === 0, JSON.stringify(o));
  check('C2 replay non terminé : aucun événement de replay, aucun badge, aucun événement de badge', (await evs(NT, 'replay_completed_100')).length === 0 && (await evs(NT, 'badge_verified')).length === 0
    && (await qs(`select count(*)::int n from user_badges where user_id = '${NT}'`))[0].n === 0);
  o = await watch(HERO, RA, 0, 100);
  check('C3 étudiant vérifié : replay suivi à 100 % -> complétion', o.accepted === true && o.completed === true && o.newly_completed === true, JSON.stringify(o));
  check('C4 badge « J\'ai suivi » attribué par le serveur', (await qs(`select count(*)::int n from user_badges where user_id = '${HERO}' and code = 'jai_suivi' and ref_id = '${RA}'`))[0].n === 1);
  let e = await evs(HERO, 'replay_completed_100');
  check('C5 événement replay_completed_100 confirmé, auteur = hôte du live', e.length === 1 && e[0].status === 'confirmed' && e[0].source_kind === 'replay_completion' && e[0].actor_id === H && e[0].meta.recording === RA, JSON.stringify(e));
  e = await evs(HERO, 'badge_verified');
  check('C6 événement badge_verified confirmé (badge adossé à la complétion)', e.length === 1 && e[0].status === 'confirmed' && e[0].source_kind === 'user_badge', JSON.stringify(e));
  check('C7 règles en brouillon : 0 point, aucune écriture de registre, score 0', (await total(HERO)) === 0 && (await ledgerSum(HERO)) === 0 && (await qs(`select count(*)::int n from talent_score_ledger where user_id = '${HERO}'`))[0].n === 0);
  await as(HERO);
  await works('C8 explication : deux activités tracées sans point (règle inactive)', `select my_talent_score_explain() r`,
    (r) => r[0].r.total === 0 && r[0].r.without_points.length === 2 && r[0].r.without_points.every((x) => x.cause === 'rule_inactive') && r[0].r.entries.length === 0);
  await sup();
  // négatifs : fraude, source non étudiante, non vérifié / non consentant (comptés, exclus plus loin)
  await watch(H, RA, 0, 100);
  e = await evs(H, 'replay_completed_100');
  check('C9 l\'hôte qui suit son propre replay : activité neutralisée (auto-interaction), alerte ouverte', e.length === 1 && e[0].status === 'neutralized' && /Auto-interaction/.test(e[0].status_reason)
    && (await flags(H)).some((f) => f.signal === 'self_dealing' && f.status === 'open'), JSON.stringify(e));
  await watch(FR, RA, 0, 100);
  e = await evs(FR, 'replay_completed_100');
  check('C10 compte lié à l\'hôte (même e-mail à l\'alias près) : replay et badge neutralisés, alerte « linked_accounts »', e.length === 1 && e[0].status === 'neutralized' && /Comptes liés/.test(e[0].status_reason)
    && (await evs(FR, 'badge_verified'))[0].status === 'neutralized' && (await flags(FR)).some((f) => f.signal === 'linked_accounts'), JSON.stringify(e));
  await db.exec(`insert into replay_completions (user_id, recording_id, live_id, coverage, watched_sec) values ('${C1}', '${RA}', '${LA}', 1, 100)`);
  check('C11 complétion d\'un compte non étudiant : aucun événement de score', (await qs(`select count(*)::int n from talent_events where user_id = '${C1}'`))[0].n === 0);
  await watch(NV, RA, 0, 100);
  await watch(NC, RA, 0, 100);
  check('C12 étudiant non vérifié et non consentant : activités enregistrées (exclusion au classement, pas au moteur)', (await evs(NV, 'replay_completed_100')).length === 1 && (await evs(NC, 'replay_completed_100')).length === 1);
  await as(NT);
  o = await rpc(`replay_progress_get('${RA}')`);
  check('C13 étudiant non terminé : toujours 60 % de couverture, pas de complétion', o.completed === false && o.covered_sec === 60, JSON.stringify(o));
  await sup();
  o = await watch(NT, RA, 60, 100);
  check('C14 le replay terminé ensuite compte à ce moment-là seulement', o.completed === true && (await evs(NT, 'replay_completed_100')).length === 1 && (await evs(NT, 'badge_verified')).length === 1);

  // ============================================================ D. ACTIVATION DES RÈGLES ET ATTRIBUTION
  await as(ADM);
  await works('D1 admin : règle replay_completed_100 activée (10 points)', `select admin_talent_rule_set('replay_completed_100', 10, null, null, 0, true, 'Règle active pour le scénario d''intégration') r`, (r) => r[0].r.active === true);
  await works('D2 admin : règle badge_verified activée (5 points)', `select admin_talent_rule_set('badge_verified', 5, null, null, 0, true, 'Règle active pour le scénario d''intégration') r`, (r) => r[0].r.active === true);
  check('D3 l\'activation n\'attribue rien rétroactivement', (await total(HERO)) === 0);
  await as(ADM);
  await works('D4 recalcul : 2 activités attribuées, 15 points, registre cohérent', `select admin_talent_recompute('${HERO}', 'Règle activée après coup pour le test') r`, (r) => r[0].r.events_awarded === 2 && r[0].r.points_added === 15 && r[0].r.total === 15 && r[0].r.consistent === true);
  await works('D5 recalcul rejoué : idempotent (0 point ajouté)', `select admin_talent_recompute('${HERO}', 'Rejeu du recalcul pour le test') r`, (r) => r[0].r.events_awarded === 0 && r[0].r.points_added === 0 && r[0].r.total === 15);
  await rpc(`admin_talent_recompute('${H}', 'Contrôle des activités neutralisées')`);
  await rpc(`admin_talent_recompute('${FR}', 'Contrôle des activités neutralisées')`);
  check('D6 activités neutralisées (auto-interaction, compte lié) : 0 point après recalcul', (await total(H)) === 0 && (await total(FR)) === 0);
  check('D7 une règle jamais activée (event_attended) reste en brouillon', (await qs(`select count(*)::int n from talent_score_rules where active and code = 'event_attended'`))[0].n === 0);
  await as(HERO);
  await works('D8 explication de l\'étudiant : replay 10 + badge 5', `select my_talent_score_explain() r`,
    (r) => r[0].r.total === 15 && r[0].r.by_rule.find((x) => x.code === 'replay_completed_100').points === 10 && r[0].r.by_rule.find((x) => x.code === 'badge_verified').points === 5 && r[0].r.without_points.length === 0);
  await sup();
  await as(ADM);
  for (const u of [NV, NC, NT]) await rpc(`admin_talent_recompute('${u}', 'Attribution de test après activation')`);
  check('D9 les autres étudiants vérifiés ou non reçoivent leurs points (15) : le moteur ne juge pas la vérification', (await total(NV)) === 15 && (await total(NC)) === 15 && (await total(NT)) === 15);

  // ============================================================ E. ANNULATION RETIRE LES POINTS
  await sup();
  await watch(CX, RA, 0, 100);
  check('E1 règle déjà active : 15 points attribués dès la complétion', (await total(CX)) === 15 && (await ledgerSum(CX)) === 15);
  await db.exec(`delete from replay_completions where user_id = '${CX}' and recording_id = '${RA}'`);
  check('E2 complétion retirée : replay ET badge passent « cancelled », points retirés exactement', (await evs(CX, 'replay_completed_100'))[0].status === 'cancelled' && (await evs(CX, 'badge_verified'))[0].status === 'cancelled'
    && (await total(CX)) === 0 && (await consistent(CX)), JSON.stringify(await evs(CX, 'badge_verified')));
  check('E3 registre en ajout seul : attributions + annulations conservées', (await qs(`select count(*) filter (where kind = 'award')::int a, count(*) filter (where kind = 'reversal')::int r from talent_score_ledger where user_id = '${CX}'`))[0].a === 2
    && (await qs(`select count(*) filter (where kind = 'reversal')::int r from talent_score_ledger where user_id = '${CX}'`))[0].r === 2);
  await db.exec(`delete from user_badges where user_id = '${NV}'`);
  check('E4 badge seul retiré : badge_verified annulé (−5), replay conservé (10 points)', (await evs(NV, 'badge_verified'))[0].status === 'cancelled' && (await evs(NV, 'replay_completed_100'))[0].status === 'confirmed' && (await total(NV)) === 10);
  await as(CX);
  await works('E5 l\'étudiant voit l\'annulation, sans point', `select my_talent_score_explain() r`, (r) => r[0].r.total === 0 && r[0].r.not_counted.filter((x) => x.status === 'cancelled').length === 2);
  await sup();

  // ============================================================ F. LIVE ANIMÉ (lives terminés de l'hôte, participants réels)
  const live = async (host, viewers, end = true) => {
    const l = (await q(`insert into lives (host_id, title, status, started_at) values ('${host}', 'Live intégration', 'live', now() - interval '90 minutes') returning id`))[0].id;
    for (const v of viewers) await db.exec(`insert into live_viewers (live_id, user_id) values ('${l}', '${v}')`);
    if (end) await db.exec(`update lives set status = 'ended', ended_at = now() where id = '${l}'`);
    return l;
  };
  const LV1 = await live(HERO, [V1, E2]);
  e = await evs(HERO, 'live_hosted');
  check('F1 live terminé avec 2 participants réels : activité confirmée, durée et participants tracés', e.length === 1 && e[0].status === 'confirmed' && e[0].source_id === LV1 && e[0].meta.participants === 2 && e[0].meta.duration_sec > 0 && e[0].actor_id === null, JSON.stringify(e));
  check('F2 règle live_hosted en brouillon : 0 point', (await total(HERO)) === 15);
  const LV0 = await live(HERO, []);
  check('F3 live terminé sans aucun participant : aucune activité', (await qs(`select count(*)::int n from talent_events where rule_code = 'live_hosted' and source_id = '${LV0}'`))[0].n === 0);
  const LVx = await live(HERO, [V1], false);
  check('F4 live encore en cours : aucune activité', (await qs(`select count(*)::int n from talent_events where rule_code = 'live_hosted' and source_id = '${LVx}'`))[0].n === 0);
  await db.exec(`update lives set status = 'cancelled' where id = '${LVx}'`);
  const LVa = await live(HA, [HB]);
  e = await evs(HA, 'live_hosted');
  check('F5 seuls participants = compte lié à l\'hôte : activité neutralisée, alerte', e.length === 1 && e[0].status === 'neutralized' && e[0].actor_id === HB && (await flags(HA)).some((f) => f.signal === 'linked_accounts'), JSON.stringify(e));
  const LVc = await live(C3, [V1, E2]);
  check('F6 hôte non étudiant : aucune activité', (await qs(`select count(*)::int n from talent_events where user_id = '${C3}'`))[0].n === 0);
  await as(ADM);
  await rpc(`admin_talent_rule_set('live_hosted', 30, null, null, 0, true, 'Règle active pour le scénario d''intégration')`);
  await works('F7 règle activée puis recalcul : +30 points pour le live confirmé', `select admin_talent_recompute('${HERO}', 'Attribution du live après activation') r`, (r) => r[0].r.events_awarded === 1 && r[0].r.points_added === 30 && r[0].r.total === 45);
  await sup();
  const LV2 = await live(HERO, [V1]);
  check('F8 second live avec règle active : +30 immédiat', (await total(HERO)) === 75);
  await db.exec(`update lives set status = 'cancelled' where id = '${LV2}'`);
  check('F9 live annulé : activité annulée, points retirés', (await evs(HERO, 'live_hosted')).find((x) => x.source_id === LV2).status === 'cancelled' && (await total(HERO)) === 45 && (await consistent(HERO)));
  await db.exec(`delete from lives where id = '${LV1}'`);
  check('F10 live supprimé : activité annulée', (await evs(HERO, 'live_hosted')).find((x) => x.source_id === LV1).status === 'cancelled' && (await total(HERO)) === 15);
  const LV3 = await live(HERO, [V1, E2, NT]);
  check('F11 nouveau live terminé : +30 (score du héros = 45)', (await total(HERO)) === 45 && (await consistent(HERO)));

  // ============================================================ G. COMPÉTENCE DÉMONTRÉE (justificatif vérifié par un humain)
  await as(ADM);
  await rpc(`admin_talent_rule_set('skill_demonstrated', 8, null, null, 0, true, 'Règle active pour le scénario d''intégration')`);
  await sup();
  const doc = async (owner, n) => (await q(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values ('${owner}', 'certificate', 'att.pdf', '${owner}/cert/${n}.pdf', 'application/pdf', 10) returning id`))[0].id;
  const D_H = await doc(HERO, 'h1');
  const sk = (await q(`insert into talent_skills (owner_id, domain, skill, level) values ('${HERO}', 'Informatique', 'Développement web', 'avance') returning id`))[0].id;
  check('G1 compétence déclarée sans justificatif : aucune activité', (await evs(HERO, 'skill_demonstrated')).length === 0);
  await db.exec(`update talent_skills set proof_document_id = '${D_H}' where id = '${sk}'`);
  check('G2 justificatif déposé mais en attente : aucune activité', (await evs(HERO, 'skill_demonstrated')).length === 0);
  const sk2 = (await q(`insert into talent_skills (owner_id, domain, skill, level, proof_document_id) values ('${HERO}', 'Informatique', 'Réseaux', 'avance', '${await doc(E2, 'e1')}') returning id`))[0].id;
  await db.exec(`update user_documents set status = 'verified', reviewed_by = '${ADM}', reviewed_at = now() where owner_id = '${E2}' and path like '%e1.pdf'`);
  check('G3 justificatif vérifié mais appartenant à un autre compte : aucune activité', (await evs(HERO, 'skill_demonstrated')).every((x) => x.source_id !== sk2));
  await db.exec(`update user_documents set status = 'verified', reviewed_by = '${ADM}', reviewed_at = now() where id = '${D_H}'`);
  e = await evs(HERO, 'skill_demonstrated');
  check('G4 justificatif vérifié par un humain : activité confirmée, auteur = vérificateur, +8', e.length === 1 && e[0].status === 'confirmed' && e[0].source_id === sk && e[0].actor_id === ADM && (await total(HERO)) === 53, JSON.stringify(e));
  await db.exec(`update user_documents set status = 'rejected' where id = '${D_H}'`);
  check('G5 justificatif rejeté ensuite : activité annulée, −8', (await evs(HERO, 'skill_demonstrated'))[0].status === 'cancelled' && (await total(HERO)) === 45);
  await db.exec(`update user_documents set status = 'verified' where id = '${D_H}'`);
  check('G6 justificatif re-vérifié : activité rétablie, +8 (pas de doublon)', (await evs(HERO, 'skill_demonstrated')).length === 1 && (await evs(HERO, 'skill_demonstrated'))[0].status === 'confirmed' && (await total(HERO)) === 53 && (await consistent(HERO)));
  const D_E = await doc(E2, 'e2');
  const sk3 = (await q(`insert into talent_skills (owner_id, domain, skill, level, proof_document_id) values ('${E2}', 'Informatique', 'Python', 'avance', '${D_E}') returning id`))[0].id;
  await db.exec(`update user_documents set status = 'verified', reviewed_by = '${ADM}', reviewed_at = now() where id = '${D_E}'`);
  check('G7 autre étudiant : son activité est la sienne (isolation)', (await evs(E2, 'skill_demonstrated')).length === 1 && (await evs(HERO, 'skill_demonstrated')).length === 1);
  await db.exec(`delete from talent_skills where id = '${sk3}'`);
  check('G8 compétence supprimée : activité annulée', (await evs(E2, 'skill_demonstrated'))[0].status === 'cancelled');

  // ============================================================ H. COLLABORATION (projet approuvé, plusieurs étudiants réels)
  await as(ADM);
  await rpc(`admin_talent_rule_set('collaboration', 6, null, null, 0, true, 'Règle active pour le scénario d''intégration')`);
  await sup();
  const PJ = (await q(`insert into projects (owner_id, title, summary, status) values ('${HERO}', 'Projet collaboratif', 'Un projet à plusieurs', 'approved') returning id`))[0].id;
  check('H1 projet approuvé avec un seul membre : aucune collaboration', (await qs(`select count(*)::int n from talent_events where rule_code = 'collaboration'`))[0].n === 0);
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ}', '${E2}', 'invited')`);
  check('H2 invitation non acceptée : aucune collaboration', (await qs(`select count(*)::int n from talent_events where rule_code = 'collaboration'`))[0].n === 0);
  await db.exec(`update project_members set status = 'accepted', responded_at = now() where project_id = '${PJ}' and user_id = '${E2}'`);
  check('H3 invitation acceptée : une activité par membre réel, +6 chacun', (await evs(HERO, 'collaboration'))[0].status === 'confirmed' && (await evs(E2, 'collaboration'))[0].status === 'confirmed'
    && (await total(HERO)) === 59 && (await evs(HERO, 'collaboration'))[0].source_id === `${PJ}:${HERO}`);
  await db.exec(`delete from project_members where project_id = '${PJ}' and user_id = '${E2}'`);
  check('H4 membre parti : collaborations annulées pour les deux, −6 chacun', (await evs(HERO, 'collaboration'))[0].status === 'cancelled' && (await evs(E2, 'collaboration'))[0].status === 'cancelled' && (await total(HERO)) === 53);
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ}', '${E2}', 'accepted')`);
  check('H5 membre revenu : rétablie sans doublon', (await evs(HERO, 'collaboration')).length === 1 && (await evs(HERO, 'collaboration'))[0].status === 'confirmed' && (await total(HERO)) === 59);
  await db.exec(`update projects set status = 'submitted' where id = '${PJ}'`);
  check('H6 projet repassé hors « approuvé » : collaborations annulées', (await evs(HERO, 'collaboration'))[0].status === 'cancelled' && (await total(HERO)) === 53);
  await db.exec(`update projects set status = 'approved' where id = '${PJ}'`);
  check('H7 projet de nouveau approuvé : rétablies (score du héros = 59)', (await total(HERO)) === 59 && (await consistent(HERO)));
  const PJ2 = (await q(`insert into projects (owner_id, title, summary, status) values ('${HA}', 'Projet de comptes liés', 'Deux alias', 'approved') returning id`))[0].id;
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ2}', '${HB}', 'accepted')`);
  check('H8 deux comptes liés entre eux : collaboration neutralisée des deux côtés', (await evs(HA, 'collaboration'))[0].status === 'neutralized' && (await evs(HB, 'collaboration'))[0].status === 'neutralized'
    && (await total(HB)) === 0 && (await flags(HB)).some((f) => f.signal === 'linked_accounts'));
  const PJ3 = (await q(`insert into projects (owner_id, title, summary, status) values ('${V1}', 'Projet avec entreprise', 'Un seul étudiant', 'approved') returning id`))[0].id;
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ3}', '${C1}', 'accepted')`);
  check('H9 membre non étudiant : pas une collaboration entre étudiants réels', (await evs(V1, 'collaboration')).length === 0);
  await db.exec(`delete from projects where id = '${PJ}'`);
  check('H10 projet supprimé : collaborations annulées (héros 53, partenaire 0)', (await evs(HERO, 'collaboration'))[0].status === 'cancelled' && (await total(HERO)) === 53);
  const PJ4 = (await q(`insert into projects (owner_id, title, summary, status) values ('${HERO}', 'Projet collaboratif final', 'Projet stable', 'approved') returning id`))[0].id;
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ4}', '${E2}', 'accepted')`);
  check('H11 nouveau projet collaboratif : héros à 59 points', (await total(HERO)) === 59 && (await consistent(HERO)));

  // ============================================================ I. ÉVÉNEMENTS : AUCUNE PRÉSENCE RÉELLE EXISTANT => NON BRANCHÉ
  const EVT = (await q(`insert into events (title, kind, starts_at, status, created_by) values ('Masterclass intégration', 'atelier', now() - interval '1 day', 'published', '${ADM}') returning id`))[0].id;
  await db.exec(`insert into event_registrations (event_id, user_id, status) values ('${EVT}', '${HERO}', 'confirmed')`);
  check('I1 inscription confirmée à un événement passé : AUCUN événement de score (aucun champ de présence réelle n\'existe)', (await qs(`select count(*)::int n from talent_events where rule_code = 'event_attended'`))[0].n === 0);
  check('I2 aucun point d\'événement, héros inchangé', (await total(HERO)) === 59);

  // ============================================================ J. ISOLATION ENTRE ÉTUDIANTS, ANONYME
  await as(HERO);
  await works('J1 l\'étudiant liste ses activités', `select my_talent_events(null, 200) r`, (r) => r[0].r.length > 0);
  const mine = (await q(`select my_talent_events(null, 200) r`))[0].r.length;
  check('J2 nombre d\'activités = celles du héros seulement', mine === (await qs(`select count(*)::int n from talent_events where user_id = '${HERO}'`))[0].n, String(mine));
  await as(HERO);
  await fails('J3 lecture directe de talent_events / registre refusée', `select * from talent_events`, /permission denied/i);
  await fails('J4 lecture directe du registre refusée', `select * from talent_score_ledger`, /permission denied/i);
  await as(E2);
  await works('J5 un autre étudiant voit son propre score (6 points de collaboration, jamais celui du héros)', `select my_talent_dashboard() r`, (r) => r[0].r.total === 6);
  await as(null);
  await fails('J6 anonyme : score refusé', `select my_talent_dashboard()`, DENY);
  await fails('J7 anonyme : lecture directe de user_badges refusée', `select * from user_badges`, /permission denied/i);
  await sup();

  // ============================================================ K. CLASSEMENT FIGÉ
  await as(ADM);
  await rpc(`admin_talent_setting_set('min_cohort', 3, 'Cohorte de test du scénario d''intégration')`);
  await as(PUB);
  await works('K1 réglages décidés (seuil 10 points, portées national / filière / établissement)', `select admin_ranking_settings_set(10, null, 100, array['national','program','institution'], 'Seuil de test du scénario d''intégration') r`, (r) => r[0].r.decided === true);
  await sup();
  // classement du mois précédent : 3 étudiants de la filière, points antidatés au mois précédent (fixtures)
  const seed = async (u, pts) => {
    const id = (await q(`insert into talent_events (user_id, rule_code, source_kind, source_id) values ('${u}', 'sale_confirmed', 'fixture', 'fx-${u.slice(-4)}') returning id`))[0].id;
    await db.exec(`select _talent_ledger_add(${id}, '${u}', 'award', ${pts}, 'sale_confirmed', 1, 'fixture'); alter table talent_score_ledger disable trigger trg_talent_ledger_guard; update talent_score_ledger set period = '${P0}' where event_id = ${id}; alter table talent_score_ledger enable trigger trg_talent_ledger_guard`);
  };
  await seed(F1, 40); await seed(F2, 30); await seed(F3, 20);
  await as(PUB);
  await works('K2 prévisualisation : 4 éligibles (héros + 3), 1 non vérifié, 1 non consentant, 1 fraude', `select admin_ranking_readiness('${P1}') r`,
    (r) => r[0].r.students.eligibles === 4 && r[0].r.students.non_verifies === 1 && r[0].r.students.non_consentants === 1 && r[0].r.students.fraude === 1);
  const pub0 = (await q(`select ranking_publish('${P0}') r`))[0].r;
  check('K3 publication du mois précédent : 3 étudiants (national, filière, établissement = 9 entrées)', pub0.ok === true && pub0.entries === 9, JSON.stringify(pub0));
  await sup();
  check('K4 notifications « entrée au classement » : F1, F2, F3 prévenus (déjà émises par ranking_publish)', (await qs(`select count(*)::int n from notifications where kind = 'ranking_entry' and user_id in ('${F1}', '${F2}', '${F3}')`))[0].n === 3);
  await as(PUB);
  const pub1 = (await q(`select ranking_publish('${P1}') r`))[0].r;
  check('K5 publication du mois courant : 12 entrées (4 étudiants x 3 portées)', pub1.ok === true && pub1.entries === 12, JSON.stringify(pub1));
  await sup();
  check('K6 héros : notification « entrée au classement » (nouvel entrant)', (await qs(`select count(*)::int n from notifications where kind = 'ranking_entry' and user_id = '${HERO}' and data->>'period' = '${P1}'`))[0].n === 1);
  check('K7 changement de rang notable : F1, F2, F3 reculent d\'un rang, notifiés à la publication suivante (déjà émises par ranking_publish)',
    (await qs(`select count(*)::int n from notifications where kind = 'ranking_rank_change' and user_id in ('${F1}', '${F2}', '${F3}')`))[0].n === 3);
  check('K8 aucune notification de classement pour les exclus (non vérifié, non consentant, fraude)', (await qs(`select count(*)::int n from notifications where kind in ('ranking_entry', 'ranking_rank_change') and user_id in ('${NV}', '${NC}', '${FR}', '${H}', '${E2}')`))[0].n === 0);
  await as(null);
  const nat = (await q(`select top100_national('${P1}') r`))[0].r;
  check('K9 anonyme : top100_national contient le héros au rang 1 avec 59 points', nat.published === true && nat.items.length === 4 && nat.items[0].user_id === HERO && nat.items[0].rank === 1 && nat.items[0].score === 59, JSON.stringify(nat.items.map((x) => [x.rank, x.score])));
  check('K10 exclus absents (non vérifié, non consentant, fraude, partenaire non rattaché, hôte)', ![NV, NC, FR, E2, H, CX, NT].some((u) => nat.items.some((x) => x.user_id === u)));
  const prog = (await q(`select top100_by_program('${G1}', '${P1}') r`))[0].r;
  check('K11 classement de la filière : héros au rang 1, 4 étudiants', prog.items.length === 4 && prog.items[0].user_id === HERO && prog.items[0].rank === 1);
  const prev = (await q(`select top100_national('${P0}') r`))[0].r;
  check('K12 le mois précédent reste figé sans le héros', prev.items.length === 3 && !prev.items.some((x) => x.user_id === HERO));
  await sup();
  await db.exec(`delete from user_badges where user_id = '${HERO}'`);
  check('K13 après publication, annuler le badge retire 5 points du score courant', (await total(HERO)) === 54 && (await consistent(HERO)));
  await as(null);
  const nat2 = (await q(`select top100_national('${P1}') r`))[0].r;
  check('K14 mais le classement publié ne bouge pas (figé : 59 points)', nat2.items[0].user_id === HERO && nat2.items[0].score === 59);
  await works('K15 empreintes des deux mois intactes', `select ranking_verify_hash('${P0}') a, ranking_verify_hash('${P1}') b`, (r) => r[0].a.intact === true && r[0].b.intact === true);
  await as(HERO);
  await works('K16 l\'étudiant voit ses positions publiées (rang 1)', `select my_ranking_positions() r`, (r) => JSON.stringify(r[0].r).includes('"rank":1'));

  // ============================================================ L. DÉCOUVERTE PAR L'ENTREPRISE, VIVIER, CONTACT, NOTIFICATION
  await as(C1);
  const sr = async (args = '') => (await q(`select discovery_search(${args}) r`))[0].r;
  let s0 = await sr();
  check('L1 l\'entreprise découvre le héros en tête de discovery_search (rang 1, décision automatique = false)', s0.published === true && s0.items[0].user_id === HERO && s0.items[0].rank === 1 && s0.automatic_decision === false && s0.total === 4, JSON.stringify(s0.items.map((x) => x.rank)));
  check('L2 exclus jamais proposés (non vérifié, non consentant, fraude, partenaire, hôte)', ![NV, NC, FR, E2, H, CX].some((u) => s0.items.some((x) => x.user_id === u)));
  check('L3 filtre filière : 4 talents ; filtre compétence « web » : le héros seul', (await sr(`p_program => '${G1}'`)).items.length === 4 && (await sr(`p_skill => 'web'`)).items.map((x) => x.user_id).join() === HERO);
  const lid = (await q(`select pool_list_create('Vivier intégration') id`))[0].id;
  await works('L4 l\'entreprise ajoute le héros à son vivier', `select discovery_pool_add('${HERO}', '${lid}', 'Profil découvert via le Top 100') r`, (r) => r[0].r.added === true);
  await works('L5 le vivier (H10) le liste', `select pool_list_members_get('${lid}') r`, (r) => r[0].r.length === 1 && r[0].r[0].id === HERO);
  await works('L6 demande de contact envoyée', `select discovery_contact_request('${HERO}', 'contact', 'Bonjour, nous aimerions échanger sur vos projets') r`, (r) => r[0].r.ok === true);
  await fails('L7 talent non consentant : demande refusée', `select discovery_contact_request('${NC}', 'contact', 'Bonjour')`, /introuvable/);
  await fails('L8 talent non vérifié : ajout au vivier refusé', `select discovery_pool_add('${NV}', '${lid}')`, /introuvable/);
  await fails('L9 talent en alerte de fraude : demande refusée', `select discovery_contact_request('${FR}', 'contact', 'Bonjour')`, /introuvable/);
  await fails('L9b talent en alerte de fraude : favori refusé aussi', `select discovery_favorite_set('${FR}', true)`, /introuvable/);
  await sup();
  check('L10 notification serveur à l\'étudiant (talent_contact), émise par l\'entreprise', (await qs(`select count(*)::int n from notifications where user_id = '${HERO}' and kind = 'talent_contact' and data->>'from' = '${C1}'`))[0].n === 1);
  await as(HERO);
  await works('L11 l\'étudiant voit la demande dans my_talent_contact_requests', `select my_talent_contact_requests() r`, (r) => r[0].r.length === 1 && r[0].r[0].kind === 'contact' && /Orange Intégration/.test(r[0].r[0].sender));
  await as(C2);
  s0 = await sr();
  check('L12 isolation : l\'autre entreprise ne voit ni vivier, ni favori, ni étape', s0.items[0].in_pool === false && s0.items[0].favorite === false && s0.items[0].stage === null);
  await fails('L13 isolation : ajout dans la liste de l\'entreprise A refusé', `select discovery_pool_add('${HERO}', '${lid}', '', '${C1}')`, /Accès refusé/);
  await fails('L14 isolation : demande au nom de l\'entreprise A refusée', `select discovery_contact_request('${HERO}', 'contact', 'Usurpation', '${C1}')`, /Accès refusé/);
  await works('L15 isolation : ses propres favoris vides', `select discovery_favorites() r`, (r) => r[0].r.length === 0);
  await as(C3);
  await fails('L16 entreprise non approuvée : découverte refusée', `select discovery_search()`, /vérifiée|Accès|Réservé/i);
  await as(HERO);
  await fails('L17 un étudiant ne découvre pas d\'autres étudiants', `select discovery_search()`, DENY);
  await as(null);
  await fails('L18 anonyme : découverte refusée', `select discovery_search()`, DENY);

  // ============================================================ M. REJEU DES MIGRATIONS 030000 À 030300 : aucun effet de bord
  await sup();
  const snap = async () => JSON.stringify((await qs(`select (select count(*) from talent_events) e, (select count(*) from talent_score_ledger) l, (select count(*) from talent_scores) s, (select sum(total) from talent_scores) t,
    (select count(*) from talent_fraud_flags) f, (select count(*) from ranking_periods) p, (select count(*) from ranking_entries) re, (select count(*) from talent_contacts) c, (select count(*) from notifications) n,
    (select count(*) from talent_score_rules where active) r`))[0]);
  const before = await snap();
  const migDir = new URL('../../migrations/', import.meta.url);
  const files = fs.readdirSync(migDir).filter((f) => /^202611270[3]\d{4}_.*\.sql$/.test(f)).sort();
  check('M1 4 migrations du lot INTEGRATION présentes', files.length === 4, files.join());
  let replayOk = true;
  for (const f of files) { try { await db.exec(fs.readFileSync(new URL(f, migDir), 'utf8')); } catch (er) { replayOk = false; console.log('ECHEC rejeu', f, er.message); } }
  check('M2 rejeu des 4 migrations : exécution sans erreur', replayOk);
  check('M3 rejeu : aucune donnée créée, supprimée ni modifiée', (await snap()) === before, before + ' / ' + (await snap()));
  check('M4 rejeu : toujours 9 déclencheurs, un par nom', (await trg()).length === 9);
  await works('M5 rejeu : empreintes des classements intactes', `select ranking_verify_hash('${P0}') a, ranking_verify_hash('${P1}') b`, (r) => r[0].a.intact === true && r[0].b.intact === true);
  await as(null);
  await fails('M6 rejeu : droits inchangés (anonyme refusé sur le moteur)', `select _talent_sync_collab('${U(900)}')`, /permission denied/i);
  await sup();
  check('M7 cohérence finale : pour tout étudiant, score = somme du registre', (await qs(`select count(*)::int n from talent_scores s where s.total <> coalesce((select sum(points) from talent_score_ledger l where l.user_id = s.user_id), 0)`))[0].n === 0);

  console.log(`\nh12_integration : ${ok} OK / ${ko} ECHEC`);
}
