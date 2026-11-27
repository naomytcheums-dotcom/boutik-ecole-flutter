// Scénario PGlite du lot H12 / TOP100-B : classements figés et publication (20261127020000), établissements (020100), lecture publique (020200),
// Talent Discovery entreprise (020300), gouvernance (020400).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h12_top100b.mjs
import fs from 'fs';
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-00000014${String(n).padStart(4, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const qs = async (sql) => { await sup(); return q(sql); };
  const DENY = /permission denied|Connexion requise|Réservé|refusé|introuvable|périmètre|exige/i;
  const P1 = (await qs(`select to_char(now() at time zone 'utc', 'YYYY-MM') p`))[0].p;
  const P0 = (await qs(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;

  // ============================================================ MIGRATIONS SEULES
  check('migrations seules : aucun réglage, aucun consentement, aucune période, aucune entrée',
    (await qs(`select (select count(*) from ranking_settings) + (select count(*) from talent_visibility_settings) + (select count(*) from ranking_periods) + (select count(*) from ranking_entries)
      + (select count(*) from ranking_institution_entries) + (select count(*) from ranking_corrections) + (select count(*) from talent_profile_views) n`))[0].n == 0);

  // ============================================================ FIXTURES (créées dans le test)
  // 1 admin ; 2 modérateur (ranking.moderate seule) ; 3 agent publication (ranking.publish + ranking.rules) ; 4 client ; 5 responsable institution I1 ; 6 entreprise ; 7 autre entreprise
  const staff = { 1: 'admin', 2: 'support', 3: 'support', 4: 'client', 5: 'support' };
  for (const [n, r] of Object.entries(staff)) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100b${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte B ${n}','${r}','t100b${n}@t.cm')`);
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${U(2)}', 'ranking', array['ranking.moderate']), ('${U(3)}', 'ranking', array['ranking.publish', 'ranking.rules'])`);
  const I1 = '00000000-0000-0000-0000-00000014a001', I2 = '00000000-0000-0000-0000-00000014a002';
  const D1 = '00000000-0000-0000-0000-00000014a011', D2 = '00000000-0000-0000-0000-00000014a012';
  const G1 = '00000000-0000-0000-0000-00000014a021', G2 = '00000000-0000-0000-0000-00000014a022';
  await db.exec(`insert into institutions (id, name, short_name, status) values ('${I1}', 'Université B Alpha', 'UBA', 'verified'), ('${I2}', 'Institut B Beta', 'IBB', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I2}', 'Génie civil', 'verified');
    insert into programs (id, institution_id, department_id, name) values ('${G1}', '${I1}', '${D1}', 'Génie logiciel'), ('${G2}', '${I2}', '${D2}', 'Travaux publics')`);
  let fx = 0;
  const mkStudent = async (n, { verified = true, consent = true, program = null, suspended = false, name = null, full = false } = {}) => {
    const id = U(100 + n);
    await db.exec(`insert into auth.users(id,email) values ('${id}','t100bs${n}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${name ?? `Etudiant Bravo${n}`}','student','t100bs${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69140' || lpad('${n}', 4, '0'), phone_verified = true where id = '${id}'`);
    if (verified) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${id}', 'student_card', 'c.pdf', '${id}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${id}'`);
    if (program) {
      const inst = program === G1 ? I1 : I2, dep = program === G1 ? D1 : D2;
      await db.exec(`insert into student_affiliations (user_id, institution_id, department_id, program_id, promotion, status) values ('${id}', '${inst}', '${dep}', '${program}', '2026', 'verified')`);
    }
    if (consent) await db.exec(`insert into talent_visibility_settings (user_id, public_ranking, show_full_name, shared_sections) values ('${id}', true, ${full}, array['rank','score','evolution','skills','badges','projects','passport'])`);
    if (suspended) await db.exec(`update profiles set suspended = true where id = '${id}'`);
    return id;
  };
  const award = async (u, pts, period = null) => {
    const e = (await qs(`insert into talent_events (user_id, rule_code, source_kind, source_id) values ('${u}', 'sale_confirmed', 'fixture', 'fx-${++fx}') returning id`))[0].id;
    await db.exec(`select _talent_ledger_add(${e}, '${u}', 'award', ${pts}, 'sale_confirmed', 1, 'fixture')`);
    if (period) {
      await db.exec(`alter table talent_score_ledger disable trigger trg_talent_ledger_guard; update talent_score_ledger set period = '${period}' where event_id = ${e}; alter table talent_score_ledger enable trigger trg_talent_ledger_guard`);
    }
    return e;
  };
  // I1 / G1 : 5 étudiants ; I2 / G2 : 3 ; cas d'exclusion : 9 non consentant, 10 non vérifié, 11 suspendu, 12 fraude, 13 sous le seuil, 14 sans rattachement
  const S = {};
  const base = { 1: 500, 2: 400, 3: 300, 4: 200, 5: 100, 6: 450, 7: 350, 8: 250 };
  for (const n of [1, 2, 3, 4, 5]) S[n] = await mkStudent(n, { program: G1, full: n === 1 });
  for (const n of [6, 7, 8]) S[n] = await mkStudent(n, { program: G2 });
  S[9] = await mkStudent(9, { program: G1, consent: false });
  S[10] = await mkStudent(10, { program: G1, verified: false });
  S[11] = await mkStudent(11, { program: G1 });
  S[12] = await mkStudent(12, { program: G1 });
  S[13] = await mkStudent(13, { program: G1 });
  S[14] = await mkStudent(14, {});
  // règle active (le moteur n'attribue rien tant qu'elle est en brouillon : les points de test passent par le registre)
  await as(U(1));
  await works('lecture des réglages : rien de décidé', `select admin_ranking_settings_get() r`, (r) => r[0].r.decided === false && r[0].r.undecided.length === 3 && r[0].r.min_score === null);
  await sup();
  for (const n of [1, 2, 3, 4, 5, 6, 7, 8]) await award(S[n], base[n], P0);
  await award(S[9], 999, P0); await award(S[10], 998, P0); await award(S[11], 997, P0); await award(S[12], 996, P0); await award(S[13], 10, P0); await award(S[14], 995, P0);
  await db.exec(`update profiles set suspended = true where id = '${S[11]}'`);
  const fev = (await qs(`select id from talent_events where user_id = '${S[12]}' limit 1`))[0].id;
  await db.exec(`insert into talent_fraud_flags (event_id, user_id, signal, detail) values (${fev}, '${S[12]}', 'other', 'Alerte de test')`);
  for (const n of [1, 2, 3, 6]) await db.exec(`insert into talent_skills (owner_id, domain, skill, level) values ('${S[n]}', 'Informatique', 'Développement web', 'avance')`);
  await db.exec(`insert into talent_skills (owner_id, domain, skill, level) values ('${S[7]}', 'Génie civil', 'Béton armé', 'expert')`);

  // ============================================================ DROITS ET REFUS
  await as(null, 'anon');
  await fails('anonyme : ranking_publish refusé', `select ranking_publish('${P0}')`, DENY);
  await fails('anonyme : admin_ranking_settings_get refusé', `select admin_ranking_settings_get()`, DENY);
  await fails('anonyme : my_top100_visibility_get refusé', `select my_top100_visibility_get()`, DENY);
  await fails('anonyme : lecture directe de ranking_entries refusée', `select * from ranking_entries`, DENY);
  await as(S[1]);
  await fails('étudiant : ranking_publish refusé', `select ranking_publish('${P0}')`, DENY);
  await fails('étudiant : réglages refusés', `select admin_ranking_settings_set(50, null, 100, array['national'], 'Tentative étudiante')`, DENY);
  await fails('étudiant : lecture directe de ranking_entries refusée', `select * from ranking_entries`, DENY);
  await fails('étudiant : lecture directe de talent_visibility_settings refusée', `select * from talent_visibility_settings`, DENY);
  await as(U(2));
  await fails('modérateur sans ranking.publish : publication refusée', `select ranking_publish('${P0}')`, DENY);
  await fails('modérateur sans ranking.rules : réglages refusés', `select admin_ranking_settings_set(50, null, 100, array['national'], 'Tentative du modérateur')`, DENY);
  await as(U(4));
  await fails('client : publication refusée', `select ranking_publish('${P0}')`, DENY);

  // ============================================================ PAS DE PUBLICATION SANS DÉCISION
  await as(U(3));
  await works('readiness : réglages non décidés et règles inactives bloquent', `select admin_ranking_readiness('${P0}') r`, (r) => r[0].r.ready === false && r[0].r.blockers.length === 2);
  await fails('publication refusée : réglages non décidés et aucune règle active', `select ranking_publish('${P0}')`, /Publication impossible.*Réglages.*Aucune règle de score active/);
  await fails('réglages : motif court refusé', `select admin_ranking_settings_set(50, null, 100, array['national'], 'court')`, /Motivez/);
  await fails('réglages : portée inconnue refusée', `select admin_ranking_settings_set(50, null, 100, array['monde'], 'Portée inconnue pour test')`, /Portées/);
  await fails('réglages : nombre d’entrées hors bornes refusé', `select admin_ranking_settings_set(50, null, 5000, array['national'], 'Bornes de test des entrées')`, /Nombre d'entrées/);
  await works('agent ranking.rules : réglages décidés', `select admin_ranking_settings_set(50, null, 100, array['national','program','institution','department','domain'], 'Seuil de test du scénario') r`,
    (r) => r[0].r.decided === true && r[0].r.min_score === 50 && r[0].r.entries_limit === 100 && r[0].r.scopes.length === 5);
  await fails('publication refusée : toujours aucune règle de score active', `select ranking_publish('${P0}')`, /Aucune règle de score active/);
  await fails('publication refusée : mois futur', `select ranking_publish('2099-01')`, /invalide ou future/);
  await as(U(1));
  await works('admin : règle de score activée', `select admin_talent_rule_set('sale_confirmed', 100, null, null, 0, true, 'Règle active pour le scénario de publication') r`, (r) => r[0].r.active === true);
  await as(U(1));
  await works('admin : min_cohort abaissé à 3 pour les fixtures', `select admin_talent_setting_set('min_cohort', 3, 'Cohorte de test du scénario') r`, (r) => r[0].r.value == 3);

  // ============================================================ CONSENTEMENT
  await as(S[9]);
  await works('étudiant : consentement par défaut = rien de partagé', `select my_top100_visibility_get() r`, (r) => r[0].r.public_ranking === false && r[0].r.show_full_name === false && r[0].r.show_photo === false && r[0].r.shared_sections.length === 0 && r[0].r.availability_public === false);
  await fails('consentement : rubrique inconnue refusée', `select my_top100_visibility_set(true, false, false, array['mot_de_passe'], false)`, /Rubrique/);
  await fails('consentement : choix incomplet refusé', `select my_top100_visibility_set(true, null, false, array['rank'], false)`, /incomplet/);
  await as(U(4));
  await fails('client : consentement refusé', `select my_top100_visibility_get()`, /étudiants/);

  // ============================================================ PRÉVISUALISATION DES EXCLUSIONS
  await as(U(1));
  await works('readiness : exclusions comptées par cause', `select admin_ranking_readiness('${P0}') r`, (r) => {
    const s = r[0].r.students;
    return r[0].r.ready === true && s.eligibles === 8 && s.non_consentants === 1 && s.non_verifies === 1 && s.suspendus === 1 && s.fraude === 1 && s.sous_le_seuil === 1 && s.sans_rattachement_verifie === 1;
  });

  // ============================================================ NORMALISATION DES ÉTABLISSEMENTS : fixtures (non consentants : absents des classements d'étudiants)
  const I3 = '00000000-0000-0000-0000-00000014a003', I4 = '00000000-0000-0000-0000-00000014a004', I5 = '00000000-0000-0000-0000-00000014a005';
  const G3 = '00000000-0000-0000-0000-00000014a023', G4 = '00000000-0000-0000-0000-00000014a024', G5 = '00000000-0000-0000-0000-00000014a025';
  await sup();
  await db.exec(`insert into institutions (id, name, short_name, status) values ('${I3}', 'Grande Université B Gamma', 'GUBG', 'verified'), ('${I4}', 'Petit Institut B Delta', 'PIBD', 'verified'), ('${I5}', 'Micro École B Epsilon', 'MEBE', 'verified');
    insert into programs (id, institution_id, name) values ('${G3}', '${I3}', 'Gestion'), ('${G4}', '${I4}', 'Électronique'), ('${G5}', '${I5}', 'Design')`);
  let k = 20;
  const bulk = async (count, inst, prog, pts) => { for (let i = 0; i < count; i++) { const n = ++k; const id = await mkStudent(n, { consent: false }); await db.exec(`insert into student_affiliations (user_id, institution_id, program_id, promotion, status) values ('${id}', '${inst}', '${prog}', '2026', 'verified')`); await award(id, pts, P0); } };
  await bulk(10, I3, G3, 10);
  await bulk(3, I4, G4, 300);
  await bulk(2, I5, G5, 900);
  await as(null, 'anon');
  await works('anonyme : avant toute publication, aucun classement d’établissements (état honnête)', `select ranking_institutions_public() r`, (r) => r[0].r.published === false && r[0].r.items.length === 0 && /Aucun classement/.test(r[0].r.note));

  // ============================================================ PUBLICATION DU MOIS PRÉCÉDENT
  await as(U(3));
  const pub0 = (await q(`select ranking_publish('${P0}') r`))[0].r;
  check('publication P0 : 36 entrées (8 national + 8 filières + 8 établissements + 8 départements + 4 domaine)', pub0.ok === true && pub0.entries === 36 && pub0.groups === 8, JSON.stringify(pub0));
  await sup();
  const cnt = async (kind, ref = '', period = P0) => (await qs(`select count(*)::int n from ranking_entries e join ranking_periods p on p.id = e.period_id where p.period = '${period}' and e.scope_kind = '${kind}' and e.scope_ref = '${ref}' and e.voided_at is null`))[0].n;
  check('P0 national : 8 entrées', (await cnt('national')) === 8);
  check('P0 filière G1 : 5 entrées', (await cnt('program', G1)) === 5);
  check('P0 filière G2 : 3 entrées', (await cnt('program', G2)) === 3);
  check('P0 établissement I1 : 5 / I2 : 3', (await cnt('institution', I1)) === 5 && (await cnt('institution', I2)) === 3);
  check('P0 département D1 : 5 / D2 : 3', (await cnt('department', D1)) === 5 && (await cnt('department', D2)) === 3);
  check('P0 domaine Informatique : 4 ; Génie civil (1 étudiant < cohorte) : non publié', (await cnt('domain', 'Informatique')) === 4 && (await cnt('domain', 'Génie civil')) === 0);
  const excluded = (await qs(`select count(*)::int n from ranking_entries e join ranking_periods p on p.id = e.period_id where p.period = '${P0}' and e.user_id in ('${S[9]}', '${S[10]}', '${S[11]}', '${S[12]}', '${S[13]}', '${S[14]}')`))[0].n;
  check('non consentant, non vérifié, suspendu, fraude, sous le seuil, sans rattachement : AUCUNE entrée', excluded === 0);
  const rk = async (n, kind = 'national', ref = '', period = P0) => (await qs(`select e.rank, e.score, e.delta_rank, e.is_new from ranking_entries e join ranking_periods p on p.id = e.period_id where p.period = '${period}' and e.scope_kind = '${kind}' and e.scope_ref = '${ref}' and e.user_id = '${S[n]}'`))[0];
  check('rangs nationaux P0 : 500→1, 450→2, 400→3, 350→4, 300→5, 250→6, 200→7, 100→8',
    (await rk(1)).rank === 1 && (await rk(6)).rank === 2 && (await rk(2)).rank === 3 && (await rk(7)).rank === 4 && (await rk(3)).rank === 5 && (await rk(8)).rank === 6 && (await rk(4)).rank === 7 && (await rk(5)).rank === 8);
  check('rang par filière G1 : 500→1, 400→2 ; G2 : 450→1', (await rk(1, 'program', G1)).rank === 1 && (await rk(2, 'program', G1)).rank === 2 && (await rk(6, 'program', G2)).rank === 1);
  check('première publication : toutes les entrées sont nouvelles, sans delta', (await rk(1)).is_new === true && (await rk(1)).delta_rank === null);
  const h0 = (await qs(`select content_hash h from ranking_periods where period = '${P0}'`))[0].h;
  await works('empreinte vérifiable par tous (anonyme compris) : intacte', `select ranking_verify_hash('${P0}') r`, (r) => r[0].r.found === true && r[0].r.intact === true && r[0].r.content_hash === h0);
  await as(null, 'anon');
  await works('anonyme : ranking_verify_hash accessible, rien d’autre révélé', `select ranking_verify_hash('${P0}') r`, (r) => Object.keys(r[0].r).sort().join(',') === 'content_hash,corrections,found,intact,period,status');
  await sup();
  // ---- établissements : indicateurs normalisés par étudiant vérifié
  await as(null, 'anon');
  const inst0 = (await q(`select ranking_institutions_public('${P0}') r`))[0].r;
  const byName = (r, n) => r.items.find((x) => x.name === n);
  check('anonyme : classement des établissements publié lisible', inst0.published === true && inst0.items.length === 4, JSON.stringify(inst0.items.map((x) => x.name)));
  check('ordre par points moyens PAR ÉTUDIANT VÉRIFIÉ : Alpha, Beta, Delta, Gamma', inst0.items.map((x) => x.short_name).join(',') === 'UBA,IBB,PIBD,GUBG', JSON.stringify(inst0.items.map((x) => [x.short_name, x.avg_score])));
  check('normalisation : le plus grand effectif (Gamma, 10) n’est pas avantagé, le petit (Delta, 3) le dépasse', byName(inst0, 'Grande Université B Gamma').verified_students === 10 && byName(inst0, 'Grande Université B Gamma').rank === 4
    && byName(inst0, 'Petit Institut B Delta').verified_students === 3 && byName(inst0, 'Petit Institut B Delta').rank === 3);
  check('moyennes : Alpha 438,13 (3505/8), Beta 350, Delta 300, Gamma 10', byName(inst0, 'Université B Alpha').avg_score == 438.13 && byName(inst0, 'Institut B Beta').avg_score == 350 && byName(inst0, 'Petit Institut B Delta').avg_score == 300 && byName(inst0, 'Grande Université B Gamma').avg_score == 10);
  check('effectif vérifié : étudiants non vérifiés et suspendus exclus (Alpha = 8)', byName(inst0, 'Université B Alpha').verified_students === 8);
  check('établissement sous la cohorte minimale (2 étudiants) : non classé', !inst0.items.some((x) => x.short_name === 'MEBE'));
  check('talents classés (consentants publiés) : Alpha 5, Beta 3, Gamma 0', byName(inst0, 'Université B Alpha').ranked_talents === 5 && byName(inst0, 'Institut B Beta').ranked_talents === 3 && byName(inst0, 'Grande Université B Gamma').ranked_talents === 0);
  check('étudiants actifs et taux d’activité du mois (Alpha 8/8)', byName(inst0, 'Université B Alpha').active_students === 8 && byName(inst0, 'Université B Alpha').active_rate == 100);
  check('répartition par filière (Alpha : Génie logiciel 8) et ratios par étudiant', byName(inst0, 'Université B Alpha').programs[0].name === 'Génie logiciel' && byName(inst0, 'Université B Alpha').programs[0].verified_students === 8
    && byName(inst0, 'Université B Alpha').per_student.projects !== undefined && byName(inst0, 'Université B Alpha').other_programs_students === 0);
  check('première publication : établissements nouveaux, sans delta', byName(inst0, 'Université B Alpha').is_new === true && byName(inst0, 'Université B Alpha').delta_rank === null);
  await works('filtre par établissement', `select ranking_institutions_public('${P0}', '${I2}') r`, (r) => r[0].r.items.length === 1 && r[0].r.items[0].short_name === 'IBB');
  await sup();
  check('établissements : pas de mise à jour directe', await (async () => { try { await db.exec(`update ranking_institution_entries set rank = 9`); return false; } catch (e) { return /ne se modifie pas/.test(e.message); } })());
  check('établissements : pas de suppression directe', await (async () => { try { await db.exec(`delete from ranking_institution_entries`); return false; } catch (e) { return /ne se modifie pas/.test(e.message); } })());
  check('empreinte de la période inclut les établissements : altération détectée', await (async () => {
    await db.exec(`alter table ranking_institution_entries disable trigger trg_ranking_guard_inst; update ranking_institution_entries set avg_score = 999 where institution_id = '${I1}'`);
    const bad = (await q(`select ranking_verify_hash('${P0}') r`))[0].r.intact === false;
    await db.exec(`update ranking_institution_entries set avg_score = 438.13 where institution_id = '${I1}'; alter table ranking_institution_entries enable trigger trg_ranking_guard_inst`);
    return bad && (await q(`select ranking_verify_hash('${P0}') r`))[0].r.intact === true;
  })());
  check('notifications : les 8 entrants prévenus', (await qs(`select count(*)::int n from notifications where kind = 'ranking_entry' and data->>'period' = '${P0}'`))[0].n === 8);
  check('notification : jamais pour un exclu', (await qs(`select count(*)::int n from notifications where kind = 'ranking_entry' and user_id in ('${S[9]}', '${S[10]}', '${S[11]}', '${S[12]}', '${S[13]}')`))[0].n === 0);

  // ============================================================ FIGÉ : un recalcul ne change rien
  await as(U(3));
  await fails('republier le même mois est refusé (une publication ne change plus)', `select ranking_publish('${P0}')`, /déjà publié/);
  await sup();
  // l'activité continue : points du mois courant, un nouvel étudiant, une suppression de consentement
  await award(S[5], 700); await award(S[1], 10); await award(S[13], 200);
  await as(U(1));
  await works('recomposition du score d’un étudiant : sans effet sur P0', `select admin_talent_recompute('${S[5]}', 'Recomposition après nouvelle activité') r`, (r) => r[0].r.ok === true);
  check('P0 : rang et score de l’étudiant 5 inchangés malgré +700 points', (await rk(5)).rank === 8 && (await rk(5)).score === 100);
  check('P0 : empreinte inchangée après nouvelle activité', (await qs(`select content_hash h from ranking_periods where period = '${P0}'`))[0].h === h0);
  await sup();
  await fails('mise à jour directe d’une entrée refusée', `update ranking_entries set rank = 1 where scope_kind = 'national'`, /ne se modifie pas/);
  await fails('mise à jour directe d’une période refusée', `update ranking_periods set status = 'archived'`, /ne se modifie pas/);
  await fails('suppression directe d’une entrée refusée', `delete from ranking_entries`, /ne se supprime pas/);
  await fails('suppression directe d’une période refusée', `delete from ranking_periods`, /ne se supprime pas/);

  // ============================================================ MOIS COURANT : delta et nouveaux
  const pub1 = await (async () => { await as(U(3)); return (await q(`select ranking_publish('${P1}') r`))[0].r; })();
  check('publication P1 : réussie', pub1.ok === true && pub1.entries > 0, JSON.stringify(pub1));
  await sup();
  check('P1 national : S5 (800 points) passe 8e -> 1er, delta +7', (await rk(5, 'national', '', P1)).rank === 1 && (await rk(5, 'national', '', P1)).delta_rank === 7);
  check('P1 : S13 (210 points) entre (nouveau), sans delta', (await rk(13, 'national', '', P1)).is_new === true && (await rk(13, 'national', '', P1)).delta_rank === null);
  check('P1 : S1 (510) 2e, delta -1', (await rk(1, 'national', '', P1)).rank === 2 && (await rk(1, 'national', '', P1)).delta_rank === -1);
  await as(null, 'anon');
  const inst1 = (await q(`select ranking_institutions_public() r`))[0].r;
  check('établissements P1 (par défaut : dernier mois publié) : Alpha 1er, delta de rang 0, progression +113,75', inst1.period === P1 && byName(inst1, 'Université B Alpha').rank === 1 && byName(inst1, 'Université B Alpha').delta_rank === 0
    && byName(inst1, 'Université B Alpha').delta_avg_score == 113.75 && byName(inst1, 'Université B Alpha').is_new === false, JSON.stringify(byName(inst1, 'Université B Alpha')));
  check('établissements P1 : activité du mois (3 actifs sur 8, 37,5 %)', byName(inst1, 'Université B Alpha').active_students === 3 && byName(inst1, 'Université B Alpha').active_rate == 37.5);
  await works('historique d’un établissement : P1 puis P0 (anonyme)', `select ranking_institution_history('${I1}') r`, (r) => r[0].r.length === 2 && r[0].r[0].period === P1 && r[0].r[1].period === P0);
  await fails('historique : établissement obligatoire', `select ranking_institution_history(null)`, /obligatoire/);
  await sup();
  check('P1 : points du mois figés (S5 = 700)', (await qs(`select e.month_points m from ranking_entries e join ranking_periods p on p.id = e.period_id where p.period = '${P1}' and e.scope_kind = 'national' and e.user_id = '${S[5]}'`))[0].m === 700);
  check('P0 toujours intact après publication de P1', (await qs(`select content_hash h from ranking_periods where period = '${P0}'`))[0].h === h0 && (await rk(5)).rank === 8);
  check('notifications : changement de rang notifié, S5 prévenu', (await qs(`select count(*)::int n from notifications where user_id = '${S[5]}' and kind = 'ranking_rank_change'`))[0].n === 1);
  check('la période stocke les règles et réglages figés', (await qs(`select (rules->0->>'code') c, settings->>'min_score' m from ranking_periods where period = '${P1}'`))[0].c === 'sale_confirmed');

  // ============================================================ LECTURE PUBLIQUE (020200)
  await sup();
  for (const [n, r] of Object.entries({ 6: 'company', 7: 'company', 8: 'company', 9: 'client' })) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100b${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Entreprise B ${n}','${r}','t100b${n}@t.cm')`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${U(6)}', 'Orange B', 'approved'), ('${U(7)}', 'Camtel B', 'approved'), ('${U(8)}', 'Brouillon B', 'draft');
    insert into company_members (owner_id, user_id, role, status, joined_at) values ('${U(6)}', '${U(9)}', 'admin', 'active', now())`);
  await db.exec(`update talent_visibility_settings set shared_sections = array['rank'] where user_id = '${S[4]}'`);
  await db.exec(`insert into projects (owner_id, title, summary, status, links) values ('${S[1]}', 'Projet pont B', 'Un pont en béton', 'approved', '{"demo": "https://exemple.cm/pont"}')`);
  const ids = (r) => r.items.map((x) => x.user_id);
  await as(null, 'anon');
  const nat = (await q(`select top100_national() r`))[0].r;
  check('anonyme : TOP national du dernier mois publié (P1), 9 entrées', nat.published === true && nat.period === P1 && nat.items.length === 9 && nat.total === 9, JSON.stringify(nat.items.map((x) => [x.rank, x.name])));
  check('rangs P1 : S5, S1, S6, S2, S7, S3, S8, S13, S4', ids(nat).join() === [5, 1, 6, 2, 7, 3, 8, 13, 4].map((n) => S[n]).join());
  check('nom public : complet seulement avec le consentement (S1), sinon prénom + initiale', nat.items[1].name === 'Etudiant Bravo1' && nat.items[0].name === 'Etudiant B.');
  check('chaque fiche : rang, établissement, filière, score, compétences, badges, projets', nat.items[1].rank === 2 && nat.items[1].institution === 'Université B Alpha' && nat.items[1].program === 'Génie logiciel' && nat.items[1].score === 510
    && Array.isArray(nat.items[1].skills) && Array.isArray(nat.items[1].badges) && nat.items[1].projects !== null);
  check('rubriques non partagées masquées (S4 : seul le rang)', nat.items[8].score === null && nat.items[8].skills === null && nat.items[8].delta_rank === null && nat.items[8].rank === 9);
  check('non consentant, non vérifié, suspendu, fraude : jamais visibles', ![9, 10, 11, 12, 14].some((n) => ids(nat).includes(S[n])));
  check('aucun champ privé exposé (e-mail, téléphone)', !/t100bs|69140/.test(JSON.stringify(nat)));
  await works('filtre mois (P0) : 8 entrées', `select top100_national('${P0}') r`, (r) => r[0].r.items.length === 8 && r[0].r.period === P0);
  await works('filtre établissement I2 : 3 entrées, rang national conservé', `select top100_national(null, 100, 0, '${I2}') r`, (r) => r[0].r.items.length === 3 && r[0].r.items[0].rank === 3);
  await works('filtre filière G1 : 6 entrées', `select top100_national(null, 100, 0, null, '${G1}') r`, (r) => r[0].r.items.length === 6);
  await works('filtre département D2 : 3 entrées', `select top100_national(null, 100, 0, null, null, '${D2}') r`, (r) => r[0].r.items.length === 3);
  await works('filtre domaine Informatique : S1, S6, S2, S3', `select top100_national(null, 100, 0, null, null, null, 'informatique') r`, (r) => ids(r[0].r).join() === [1, 6, 2, 3].map((n) => S[n]).join());
  await works('filtre niveau vérifié 2026 : 9 entrées ; 2025 : aucune', `select (select top100_national(null, 100, 0, null, null, null, null, '2026')) a, (select top100_national(null, 100, 0, null, null, null, null, '2025')) b`, (r) => r[0].a.items.length === 9 && r[0].b.items.length === 0);
  await works('pagination : limite 3, décalage 3', `select top100_national(null, 3, 3) r`, (r) => r[0].r.items.length === 3 && r[0].r.items[0].rank === 4 && r[0].r.total === 9);
  await works('TOP par filière G2 : 450, 350, 250', `select top100_by_program('${G2}') r`, (r) => ids(r[0].r).join() === [6, 7, 8].map((n) => S[n]).join() && r[0].r.items[0].rank === 1);
  await works('TOP par établissement I1 avec filtre filière', `select top100_by_institution('${I1}', null, '${G1}') r`, (r) => r[0].r.items.length === 6 && r[0].r.items[0].user_id === S[5]);
  await works('TOP par département D1', `select top100_by_department('${D1}') r`, (r) => r[0].r.items.length === 6);
  await works('TOP par domaine (insensible à la casse) : rangs dans le domaine', `select top100_by_domain('INFORMATIQUE') r`, (r) => r[0].r.items.length === 4 && r[0].r.items[0].user_id === S[1] && r[0].r.items[0].rank === 1);
  await works('domaine d’une cohorte trop petite : non publié', `select top100_by_domain('Génie civil') r`, (r) => r[0].r.items.length === 0);
  await works('mois inconnu : état honnête, aucune donnée', `select top100_national('2019-05') r`, (r) => r[0].r.published === false && r[0].r.items.length === 0);
  const rise = (await q(`select talents_rising() r`))[0].r;
  check('talents en progression : S5 (+7)', rise.items.length === 1 && rise.items[0].user_id === S[5] && rise.items[0].delta_rank === 7, JSON.stringify(rise.items));
  const nw = (await q(`select talents_new() r`))[0].r;
  check('nouveaux talents du mois : S13 seulement', nw.items.length === 1 && nw.items[0].user_id === S[13] && nw.items[0].is_new === true, JSON.stringify(nw.items));
  const hist = (await q(`select ranking_history() r`))[0].r;
  check('historique des classements : P1 puis P0, tête de classement publique', hist.length === 2 && hist[0].period === P1 && hist[1].period === P0 && hist[0].top.length === 3 && hist[0].top[0].user_id === S[5] && hist[0].content_hash.length === 64);
  // retrait du consentement : effet immédiat
  await sup();
  await db.exec(`update talent_visibility_settings set public_ranking = false where user_id = '${S[2]}'`);
  await as(null, 'anon');
  await works('consentement retiré : S2 disparaît tout de suite des listes publiques', `select top100_national() r`, (r) => r[0].r.items.length === 8 && !ids(r[0].r).includes(S[2]));
  await works('consentement retiré : page publique introuvable', `select talent_public_profile('${S[2]}') r`, (r) => r[0].r.found === false);
  await sup();
  await db.exec(`update talent_visibility_settings set public_ranking = true where user_id = '${S[2]}'`);

  // ---- page publique d'un talent
  await as(null, 'anon');
  const pp = (await q(`select talent_public_profile('${S[1]}') r`))[0].r;
  check('page publique (anonyme) : identité selon consentement, établissement et filière vérifiés', pp.found === true && pp.name === 'Etudiant Bravo1' && pp.institution === 'Université B Alpha' && pp.program === 'Génie logiciel' && pp.promotion === '2026');
  check('page publique : rangs national et filière, score, évolution sur 2 mois', pp.ranking.some((x) => x.scope === 'national' && x.rank === 2) && pp.ranking.some((x) => x.scope === 'program' && x.rank === 2) && pp.score === 510 && pp.evolution.length === 2 && pp.evolution[0].delta_rank === -1);
  check('page publique : compétences, badges, projets approuvés, passeport', pp.skills.length === 1 && pp.skills[0].skill === 'Développement web' && Array.isArray(pp.badges) && pp.projects.length === 1 && pp.projects[0].title === 'Projet pont B' && pp.passport !== null);
  check('page publique : disponibilité non publiable par défaut', pp.availability === null && pp.contact === 'login_required');
  const pm = (await q(`select talent_public_profile('${S[4]}') r`))[0].r;
  check('page publique : rubriques non partagées absentes (S4 : rang seulement)', pm.found === true && pm.ranking !== null && pm.score === null && pm.skills === null && pm.badges === null && pm.projects === null && pm.passport === null && pm.evolution === null);
  await works('non consentant : page introuvable, sans fuite', `select talent_public_profile('${S[9]}') r`, (r) => JSON.stringify(r[0].r) === '{"found":false}');
  await works('non vérifié : page introuvable', `select talent_public_profile('${S[10]}') r`, (r) => r[0].r.found === false);
  await works('compte non étudiant : page introuvable', `select talent_public_profile('${U(6)}') r`, (r) => r[0].r.found === false);
  await sup();
  await db.exec(`insert into student_availability (user_id, kinds) values ('${S[5]}', array['internship']); update talent_visibility_settings set availability_public = true where user_id = '${S[5]}'`);
  await as(U(6));
  await works('entreprise vérifiée : contact autorisé, disponibilité publiée visible', `select talent_public_profile('${S[5]}') r`, (r) => r[0].r.contact === 'allowed' && r[0].r.availability.kinds[0] === 'internship');
  await as(S[3]);
  await works('autre étudiant : contact non autorisé', `select talent_public_profile('${S[5]}') r`, (r) => r[0].r.contact === 'not_allowed');
  await as(S[5]);
  await works('l’étudiant voit sa propre page : contact « self »', `select talent_public_profile('${S[5]}') r`, (r) => r[0].r.contact === 'self');
  await works('mes positions : national rang 1', `select my_ranking_positions() r`, (r) => r[0].r.published === true && r[0].r.positions[0].scope === 'national' && r[0].r.positions[0].rank === 1);
  await as(S[9]);
  await works('mes positions sans consentement : aucune entrée, état honnête', `select my_ranking_positions() r`, (r) => r[0].r.positions.length === 0 && r[0].r.public === false);
  await as(null, 'anon');
  await fails('anonyme : my_ranking_positions refusé', `select my_ranking_positions()`, DENY);
  await fails('anonyme : enregistrement de vue refusé', `select talent_profile_view_record('${S[1]}')`, DENY);

  // ---- vues d'entreprises : dédoublonnage et anonymisation
  await as(U(6));
  await works('vue enregistrée par une entreprise vérifiée', `select talent_profile_view_record('${S[1]}') r`, (r) => r[0].r.recorded === true);
  await works('même entreprise, même jour : non recomptée', `select talent_profile_view_record('${S[1]}') r`, (r) => r[0].r.recorded === false && r[0].r.reason === 'already_counted_today');
  await as(U(9));
  await works('membre de l’entreprise : compté pour l’organisation (donc pas deux fois)', `select talent_profile_view_record('${S[1]}') r`, (r) => r[0].r.recorded === false);
  await as(U(7));
  await works('autre entreprise vérifiée : vue enregistrée', `select talent_profile_view_record('${S[1]}') r`, (r) => r[0].r.recorded === true);
  await works('seconde entreprise : vue sur S5', `select talent_profile_view_record('${S[5]}') r`, (r) => r[0].r.recorded === true);
  await as(U(8));
  await works('entreprise non vérifiée : non comptée', `select talent_profile_view_record('${S[1]}') r`, (r) => r[0].r.recorded === false && r[0].r.reason === 'not_verified_company');
  await as(S[3]);
  await works('étudiant : non compté', `select talent_profile_view_record('${S[1]}') r`, (r) => r[0].r.recorded === false);
  await as(U(6));
  await works('talent non consentant : non compté', `select talent_profile_view_record('${S[9]}') r`, (r) => r[0].r.recorded === false && r[0].r.reason === 'not_public');
  await as(null, 'anon');
  const mv = (await q(`select talents_most_viewed_by_companies() r`))[0].r;
  check('les plus consultés : S1 (2 entreprises, 2 vues) puis S5 (1, 1)', mv.items.length === 2 && mv.items[0].user_id === S[1] && mv.items[0].companies === 2 && mv.items[0].views === 2 && mv.items[1].companies === 1, JSON.stringify(mv.items));
  check('les plus consultés : identité des entreprises jamais exposée', !/Orange B|Camtel B|Brouillon B/.test(JSON.stringify(mv)) && !JSON.stringify(mv).includes(U(6)) && !JSON.stringify(mv).includes(U(7)) && !JSON.stringify(mv).includes(U(9)));
  await works('les plus consultés, autre mois : aucun compteur', `select talents_most_viewed_by_companies('${P0}') r`, (r) => r[0].r.items.length === 0);
  await fails('période invalide refusée', `select talents_most_viewed_by_companies('bientot')`, /invalide/);
  await fails('table des vues : lecture directe refusée', `select * from talent_profile_views`, DENY);
  await as(U(6));
  await fails('entreprise : lecture directe des vues refusée', `select * from talent_profile_views`, DENY);

  // ============================================================ TALENT DISCOVERY (020300)
  const sr = async (args = '') => (await q(`select discovery_search(${args}) r`))[0].r;
  await as(null, 'anon');
  await fails('anonyme : discovery_search refusé', `select discovery_search()`, DENY);
  await fails('anonyme : discovery_contact_request refusé', `select discovery_contact_request('${S[1]}', 'contact', '')`, DENY);
  await as(S[3]);
  await fails('étudiant : discovery_search refusé', `select discovery_search()`, /entreprises|Réservé|refusé/i);
  await as(U(4));
  await fails('client : discovery_search refusé', `select discovery_search()`, /entreprises|Réservé|refusé/i);
  await as(U(8));
  await fails('entreprise non vérifiée : recherche refusée', `select discovery_search()`, /vérifiée/);
  await as(U(6));
  let r0 = await sr();
  check('recherche sans filtre : 9 talents du classement publié, dans l’ordre des rangs, décision automatique = false', r0.items.length === 9 && r0.items[0].user_id === S[5] && r0.automatic_decision === false && r0.period === P1);
  check('explication minimale : figure au classement publié, aucun score opaque', r0.items[0].why.length === 1 && r0.items[0].why[0].criterion === 'published_ranking' && !('match_score' in r0.items[0]));
  check('recherche : non consentants, non vérifiés, suspendus, fraude jamais proposés', ![9, 10, 11, 12, 14].some((n) => r0.items.some((x) => x.user_id === S[n])));
  r0 = await sr(`p_program => '${G2}'`);
  check('filtre filière : 3 talents, « pourquoi » = Filière : Travaux publics', r0.items.length === 3 && r0.items[0].why.some((w) => w.criterion === 'program' && w.label === 'Filière : Travaux publics' && w.satisfied === true));
  r0 = await sr(`p_institution => '${I1}', p_department => '${D1}'`);
  check('filtres établissement + département : 6 talents', r0.items.length === 6);
  r0 = await sr(`p_skill => 'web', p_min_level => 'avance'`);
  check('filtre compétence (niveau avancé) : S1, S6, S2, S3 ; pourquoi mentionne la compétence', r0.items.map((x) => x.user_id).join() === [1, 6, 2, 3].map((n) => S[n]).join() && r0.items[0].why.some((w) => w.criterion === 'skill'));
  check('compétence : niveau expert exigé -> aucun résultat', (await sr(`p_skill => 'web', p_min_level => 'expert'`)).items.length === 0);
  await fails('niveau sans compétence refusé', `select discovery_search(p_min_level => 'avance')`, /exige une compétence/);
  check('filtre domaine Informatique : 4 talents', (await sr(`p_domain => 'informatique'`)).items.length === 4);
  r0 = await sr(`p_max_rank => 2`);
  check('classement : rang 2 ou mieux = S5, S1', r0.items.map((x) => x.user_id).join() === [5, 1].map((n) => S[n]).join() && r0.items[1].why.some((w) => w.criterion === 'rank'));
  check('score minimal 400 : S5, S1, S6, S2 (S4 ne partage pas son score : jamais révélé ni filtré)', (await sr(`p_min_score => 400`)).items.map((x) => x.user_id).join() === [5, 1, 6, 2].map((n) => S[n]).join());
  check('progression minimale +1 rang : S5 seul', (await sr(`p_min_progression => 1`)).items.length === 1);
  check('disponibilité publiée : S5 seul ; stage : S5 ; emploi : aucun', (await sr(`p_available => true`)).items.length === 1 && (await sr(`p_availability_kind => 'internship'`)).items[0].user_id === S[5] && (await sr(`p_availability_kind => 'job'`)).items.length === 0);
  check('badge vérifiable « certified » : 8 talents (S4 ne partage pas ses badges)', (await sr(`p_badge => 'certified'`)).items.length === 8);
  check('promotion vérifiée 2026 : 9 ; 2025 : 0', (await sr(`p_promotion => '2026'`)).items.length === 9 && (await sr(`p_promotion => '2025'`)).items.length === 0);
  check('tri par score : S5 puis S1 ; par progression : S5 en tête', (await sr(`p_sort => 'score'`)).items[1].user_id === S[1] && (await sr(`p_sort => 'progression'`)).items[0].user_id === S[5]);
  await fails('tri inconnu refusé', `select discovery_search(p_sort => 'hasard')`, /Tri inconnu/);
  await fails('portée inconnue refusée', `select discovery_search(p_scope => 'monde')`, /Portée/);
  check('pagination : limite 2, décalage 2', await (async () => { const x = await sr(`p_limit => 2, p_offset => 2`); return x.items.length === 2 && x.total === 9 && x.items[0].rank === 3; })());
  check('mois sans classement : état honnête', (await sr(`p_period => '2019-01'`)).published === false);

  // ---- favoris, vivier et isolation entre organisations
  await works('favori : S1 ajouté par l’organisation 6', `select discovery_favorite_set('${S[1]}', true) r`, (r) => r[0].r.favorite === true);
  await fails('favori : talent non consentant refusé', `select discovery_favorite_set('${S[9]}', true)`, /introuvable/);
  check('recherche : S1 marqué favori pour l’organisation 6', (await sr()).items.find((x) => x.user_id === S[1]).favorite === true);
  await as(U(9));
  await works('membre de l’organisation 6 : lit les favoris', `select discovery_favorites('${U(6)}') r`, (r) => r[0].r.length === 1 && r[0].r[0].user_id === S[1]);
  await works('membre : ajoute S5 aux favoris de l’organisation', `select discovery_favorite_set('${S[5]}', true, '${U(6)}') r`, (r) => r[0].r.favorite === true);
  await as(U(7));
  await fails('autre organisation : favoris de l’organisation 6 refusés', `select discovery_favorites('${U(6)}')`, /Accès refusé/);
  await works('autre organisation : ses propres favoris vides', `select discovery_favorites() r`, (r) => r[0].r.length === 0);
  check('autre organisation : aucun favori ni vivier hérité dans la recherche', (await sr()).items.every((x) => x.favorite === false && x.in_pool === false && x.stage === null));
  await as(U(6));
  const lid = (await q(`select pool_list_create('Vivier B') id`))[0].id;
  await works('vivier : S1 ajouté à la liste privée', `select discovery_pool_add('${S[1]}', '${lid}', 'Profil prometteur') r`, (r) => r[0].r.added === true);
  await works('vivier : visible par les fonctions H10 (pool_list_members_get)', `select pool_list_members_get('${lid}') r`, (r) => r[0].r.length === 1 && r[0].r[0].id === S[1]);
  await fails('vivier : talent non consentant refusé', `select discovery_pool_add('${S[9]}', '${lid}')`, /introuvable/);
  await works('vivier : étape posée (H10)', `select pool_talent_set('${S[1]}', 'preselectionne', array['web'], null) r`, (r) => r[0].r.stage === 'preselectionne');
  await as(U(7));
  await fails('autre organisation : ajout dans la liste de l’organisation 6 refusé', `select discovery_pool_add('${S[1]}', '${lid}', '', '${U(6)}')`, /Accès refusé/);
  await fails('autre organisation : liste inconnue de son propre vivier', `select discovery_pool_add('${S[1]}', '${lid}')`, /Liste introuvable/);

  // ---- comparaison
  await as(U(6));
  const cmp = (await q(`select discovery_compare(array['${S[1]}', '${S[5]}', '${S[4]}']::uuid[]) r`))[0].r;
  check('comparaison de 3 profils : profil public selon consentement + matrice', cmp.talents.length === 3 && cmp.matrix.length === 7 && cmp.automatic_decision === false);
  check('comparaison : données privées de l’organisation (étape) pour S1, rubriques non partagées vides pour S4', cmp.talents[0].stage === 'preselectionne' && cmp.talents[0].in_pool === true
    && cmp.matrix.find((m) => m.criterion === 'score').values.find((v) => v.user_id === S[4]).value === null && cmp.matrix.find((m) => m.criterion === 'national_rank').values.find((v) => v.user_id === S[5]).value === '1');
  await fails('comparaison : 1 seul profil refusé', `select discovery_compare(array['${S[1]}']::uuid[])`, /de 2 à 4/);
  await fails('comparaison : 5 profils refusés', `select discovery_compare(array['${S[1]}', '${S[2]}', '${S[3]}', '${S[4]}', '${S[5]}']::uuid[])`, /de 2 à 4/);
  await fails('comparaison : doublon refusé', `select discovery_compare(array['${S[1]}', '${S[1]}']::uuid[])`, /double/);
  await fails('comparaison : talent non consentant refusé', `select discovery_compare(array['${S[1]}', '${S[9]}']::uuid[])`, /introuvable/);
  await as(U(7));
  const cmp7 = (await q(`select discovery_compare(array['${S[1]}', '${S[5]}']::uuid[]) r`))[0].r;
  check('comparaison par une autre organisation : aucune donnée privée de l’organisation 6', cmp7.talents[0].stage === null && cmp7.talents[0].in_pool === false && cmp7.talents[0].tags.length === 0);

  // ---- demandes de contact, d'entretien, propositions
  await as(U(6));
  await works('invitation à un entretien', `select discovery_contact_request('${S[1]}', 'interview', 'Entretien technique jeudi à 10 h') r`, (r) => r[0].r.ok === true && r[0].r.kind === 'interview');
  await fails('même demande le même jour refusée', `select discovery_contact_request('${S[1]}', 'interview', 'Entretien technique jeudi à 10 h')`, /déjà adressé/);
  await works('proposition d’emploi', `select discovery_contact_request('${S[1]}', 'job_offer', 'Poste de développeur junior à Douala') r`, (r) => r[0].r.kind === 'job_offer');
  await works('proposition de stage', `select discovery_contact_request('${S[1]}', 'internship_offer', 'Stage de trois mois en développement') r`, (r) => r[0].r.kind === 'internship_offer');
  await works('proposition de mission', `select discovery_contact_request('${S[1]}', 'mission_offer', 'Mission de refonte du site vitrine') r`, (r) => r[0].r.kind === 'mission_offer');
  await fails('proposition sans message suffisant refusée', `select discovery_contact_request('${S[5]}', 'job_offer', 'court')`, /10 caractères/);
  await fails('type inconnu refusé', `select discovery_contact_request('${S[1]}', 'recrutement_auto', 'Message suffisant ici')`, /inconnu/);
  await fails('talent non consentant : demande refusée', `select discovery_contact_request('${S[9]}', 'contact', '')`, /introuvable/);
  await as(U(9));
  await works('membre de l’organisation : demande de contact au nom de l’organisation', `select discovery_contact_request('${S[1]}', 'contact', 'Bonjour, échangeons sur vos projets', '${U(6)}') r`, (r) => r[0].r.ok === true);
  await as(U(7));
  await fails('autre organisation : envoi au nom de l’organisation 6 refusé', `select discovery_contact_request('${S[1]}', 'contact', 'Usurpation', '${U(6)}')`, /Accès refusé/);
  await as(U(6));
  await works('historique de contact du vivier (H10) : demandes de la plateforme visibles', `select pool_contacts_get('${S[1]}') r`, (r) => r[0].r.length >= 4 && r[0].r.some((c) => c.source === 'plateforme' && /Entretien technique/.test(c.summary)));
  await sup();
  check('talent_contacts : types élargis enregistrés', (await qs(`select count(distinct kind)::int n from talent_contacts where target_id = '${S[1]}'`))[0].n === 5);
  await fails('contrainte : type inconnu refusé en base', `insert into talent_contacts (sender_id, target_id, kind, message) values ('${U(6)}', '${S[1]}', 'virement', 'x')`, /check|violat/i);
  check('talent notifié de chaque demande', (await qs(`select count(*)::int n from notifications where user_id = '${S[1]}' and kind = 'talent_contact'`))[0].n === 5);
  await as(S[1]);
  const inbox = (await q(`select my_talent_contact_requests() r`))[0].r;
  check('étudiant : demandes reçues, expéditeur = entreprise vérifiée (membre compris)', inbox.length === 5 && inbox.every((c) => c.sender === 'Orange B'), JSON.stringify(inbox.map((c) => c.sender)));
  await as(S[3]);
  await works('un autre étudiant ne voit pas ces demandes', `select my_talent_contact_requests() r`, (r) => r[0].r.length === 0);
  await as(U(6));
  await fails('entreprise : my_talent_contact_requests refusé', `select my_talent_contact_requests()`, /étudiants/);
  await sup();
  await db.exec(`update talent_visibility_settings set public_ranking = false where user_id = '${S[2]}'`);
  await as(U(6));
  check('consentement retiré : S2 disparaît de la recherche', (await sr()).items.length === 8 && !(await sr()).items.some((x) => x.user_id === S[2]));
  await sup();
  await db.exec(`update talent_visibility_settings set public_ranking = true where user_id = '${S[2]}'`);

  // ============================================================ GOUVERNANCE (020400)
  await sup();
  for (const [n, r] of Object.entries({ 15: 'dept', 16: 'dept', 17: 'support' })) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100b${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte B ${n}','${r}','t100b${n}@t.cm')`);
  await db.exec(`insert into department_accounts (user_id, department_id, assigned_by) values ('${U(15)}', '${D1}', '${U(1)}'), ('${U(16)}', '${D2}', '${U(1)}')`);
  await as(U(1));
  await works('admin nomme le responsable de I1 (U5) et de I2 (U17)', `select admin_institution_manager_set('${U(5)}', '${I1}', true) a, admin_institution_manager_set('${U(17)}', '${I2}', true) b`, (r) => r[0].a.manager === true && r[0].b.manager === true);
  await sup();
  const S15 = await mkStudent(15, { consent: false });
  await db.exec(`update profiles set matricule = 'MAT-DUP-1', institution_id = '${I1}' where id in ('${S[1]}', '${S[2]}'); update profiles set institution_id = '${I2}' where id = '${S[3]}'`);
  await as(S[14]);
  await works('étudiant sans filière : demande de rattachement en attente', `select student_affiliation_request('${G1}', '2026') r`, (r) => r[0].r.status === 'pending');
  await as(null, 'anon');
  await fails('anonyme : indicateurs nationaux refusés', `select admin_ranking_national_indicators()`, DENY);
  await fails('anonyme : scope_dashboard refusé', `select scope_dashboard()`, DENY);
  for (const [who, uid] of [['étudiant', S[3]], ['client', U(4)], ['entreprise', U(6)], ['responsable de département', U(15)], ['responsable d’établissement', U(5)]]) {
    await as(uid);
    await fails(`${who} : indicateurs nationaux refusés`, `select admin_ranking_national_indicators()`, DENY);
    await fails(`${who} : qualité des données refusée`, `select admin_data_quality()`, DENY);
    await fails(`${who} : anomalies refusées`, `select admin_ranking_anomalies()`, DENY);
  }
  await as(U(2));
  const ind = (await q(`select admin_ranking_national_indicators() r`))[0].r;
  check('indicateurs nationaux (modérateur) : effectifs agrégés', ind.students.verified === 28 && ind.students.affiliated_verified === 26 && ind.students.consenting === 10 && ind.students.active_this_month === 3, JSON.stringify(ind.students));
  check('indicateurs nationaux : file d’attente, établissements, classements', ind.queue.pending_affiliations === 1 && ind.queue.open_fraud_flags === 1 && ind.institutions.verified === 5 && ind.institutions.with_students === 5
    && ind.rankings.published_periods === 2 && ind.rankings.rules_active === 1 && ind.rankings.settings_decided === true && ind.rankings.latest.period === P1 && ind.by_institution.length === 5, JSON.stringify([ind.queue, ind.institutions, ind.rankings]));
  check('indicateurs nationaux : agrégés seulement (aucun nom d’étudiant, aucun identifiant d’étudiant)', !/Bravo/.test(JSON.stringify(ind)) && !JSON.stringify(ind).includes(S[1]));
  await as(U(1));
  const dq = (await q(`select admin_data_quality() r`))[0].r;
  check('qualité : affiliations en attente (1, établissement Alpha)', dq.pending_affiliations.total === 1 && dq.pending_affiliations.by_institution[0].institution_id === I1);
  check('qualité : étudiants vérifiés sans filière (2, dont 1 avec demande en attente)', dq.students_without_program.verified_without_affiliation === 2 && dq.students_without_program.with_pending_request === 1 && dq.students_without_program.sample.length === 2);
  check('qualité : matricule en doublon (1), profil incohérent avec le rattachement (1), aucune filière ni établissement orphelin', dq.matricule_duplicates === 1 && dq.profile_affiliation_mismatch === 1 && dq.programs.active_without_students === 0 && dq.institutions.verified_without_programs === 0, JSON.stringify(dq));
  const an = (await q(`select admin_ranking_anomalies() r`))[0].r;
  check('anomalies : 1 alerte ouverte (other), aucune contestation, empreintes intactes, rien à corriger', an.flags_open === 1 && an.flags_open_by_signal.other === 1 && an.disputes_open === 0 && an.integrity.length === 2 && an.integrity.every((x) => x.intact === true) && an.published_needing_correction.length === 0, JSON.stringify(an));

  // ---- périmètres des responsables (lecture agrégée de SON périmètre seulement)
  await as(U(5));
  await works('responsable de I1 : ses périmètres', `select my_ranking_scopes() r`, (r) => r[0].r.institutions.length === 1 && r[0].r.institutions[0].id === I1 && r[0].r.department === null && r[0].r.admin === false);
  const sd = (await q(`select scope_dashboard() r`))[0].r;
  check('responsable de I1 : tableau de bord agrégé (8 vérifiés, 6 talents classés, 1 rattachement en attente)', sd.scope.kind === 'institution' && sd.scope.id === I1 && sd.verified_students === 8 && sd.ranked_talents === 6 && sd.pending_affiliations === 1
    && sd.programs[0].name === 'Génie logiciel' && sd.avg_score_per_verified_student !== null && sd.institution_ranking.rank === 1, JSON.stringify(sd));
  check('tableau de bord : aucun nom ni identifiant d’étudiant', !/Bravo|Etudiant/.test(JSON.stringify(sd)) && !JSON.stringify(sd).includes(S[1]));
  await fails('responsable de I1 : lecture de I2 refusée', `select scope_dashboard('${I2}')`, /hors de votre périmètre/);
  await fails('responsable de I1 : lecture du département D2 (autre établissement) refusée', `select scope_dashboard(null, '${D2}')`, /hors de votre périmètre/);
  await works('responsable de I1 : lecture du département D1 de son établissement', `select scope_dashboard(null, '${D1}') r`, (r) => r[0].r.scope.kind === 'department' && r[0].r.verified_students === 8);
  await as(U(17));
  await works('responsable de I2 : 3 vérifiés, moyenne visible (cohorte atteinte)', `select scope_dashboard() r`, (r) => r[0].r.scope.id === I2 && r[0].r.verified_students === 3 && r[0].r.avg_score_per_verified_student !== null && r[0].r.ranked_talents === 3);
  await fails('responsable de I2 : lecture de I1 refusée', `select scope_dashboard('${I1}')`, /hors de votre périmètre/);
  await as(U(15));
  await works('responsable du département D1 : ses périmètres', `select my_ranking_scopes() r`, (r) => r[0].r.department.id === D1 && r[0].r.institutions.length === 0);
  await works('responsable du département D1 : tableau de bord de son département', `select scope_dashboard() r`, (r) => r[0].r.scope.kind === 'department' && r[0].r.scope.id === D1 && r[0].r.verified_students === 8);
  await fails('responsable de D1 : lecture de D2 refusée', `select scope_dashboard(null, '${D2}')`, /hors de votre périmètre/);
  await fails('responsable de D1 : lecture de l’établissement entier refusée', `select scope_dashboard('${I1}')`, /hors de votre périmètre/);
  await as(U(16));
  await fails('responsable de D2 : lecture de D1 refusée', `select scope_dashboard(null, '${D1}')`, /hors de votre périmètre/);
  await as(S[3]);
  await fails('étudiant : scope_dashboard refusé', `select scope_dashboard('${I1}')`, /hors de votre périmètre|Précisez/);
  await works('étudiant : aucun périmètre', `select my_ranking_scopes() r`, (r) => r[0].r.institutions.length === 0 && r[0].r.department === null && r[0].r.admin === false);
  await as(U(4));
  await fails('client : scope_dashboard refusé', `select scope_dashboard('${I1}')`, /hors de votre périmètre/);
  await as(U(1));
  await fails('administrateur sans périmètre précisé : demande de précision', `select scope_dashboard()`, /Précisez/);
  await works('administrateur : établissement trop petit (2 vérifiés) : moyenne masquée', `select scope_dashboard('${I5}') r`, (r) => r[0].r.verified_students === 2 && r[0].r.avg_score_per_verified_student === null && r[0].r.avg_hidden_reason === 'cohorte_insuffisante');
  await works('administrateur : grand établissement lisible (I3 : 10 vérifiés, 0 classé)', `select scope_dashboard('${I3}') r`, (r) => r[0].r.verified_students === 10 && r[0].r.ranked_talents === 0 && r[0].r.institution_ranking.rank === 4);
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${U(5)}'`);
  await as(U(5));
  await fails('responsable suspendu : plus aucun accès', `select scope_dashboard('${I1}')`, /hors de votre périmètre|Précisez/);
  await sup();
  await db.exec(`update profiles set suspended = false where id = '${U(5)}'`);

  // ============================================================ CORRECTION AUDITÉE
  await as(U(1));
  await fails('correction : motif court refusé', `select ranking_correct('${P1}', 'court', '${S[1]}')`, /Motivez/);
  await as(U(2));
  await fails('modérateur : correction refusée', `select ranking_correct('${P1}', 'Correction demandée par le modérateur', '${S[1]}')`, DENY);
  await as(U(3));
  await fails('correction d’un mois non publié refusée', `select ranking_correct('2020-01', 'Mois inexistant pour test', null)`, /introuvable/);
  await fails('correction sans entrée concernée refusée', `select ranking_correct('${P1}', 'Aucun inéligible attendu ici', null)`, /Aucune entrée/);
  const hBefore = (await qs(`select content_hash h from ranking_periods where period = '${P1}'`))[0].h;
  await as(U(3));
  const cor = (await q(`select ranking_correct('${P1}', 'Fraude confirmée sur l''étudiant 1', '${S[1]}') r`))[0].r;
  check('correction : S1 retiré de toutes ses portées', cor.ok === true && cor.voided === 5 && cor.old_hash === hBefore && cor.new_hash !== hBefore, JSON.stringify(cor));
  await sup();
  check('correction : entrée retirée (voided) mais conservée', (await qs(`select count(*)::int n from ranking_entries e join ranking_periods p on p.id = e.period_id where p.period = '${P1}' and e.user_id = '${S[1]}' and e.voided_at is not null`))[0].n === 5);
  check('correction : rangs recalculés (S2 : 4e -> 3e)', (await rk(2, 'national', '', P1)).rank === 3);
  const corrRows = await qs(`select field, old_value, new_value, reason from ranking_corrections order by id`);
  check('journal : ancienne et nouvelle valeur, motif', corrRows.some((c) => c.field === 'entry' && c.old_value.rank === 2 && c.new_value.voided === true && /Fraude confirmée/.test(c.reason)) && corrRows.some((c) => c.field === 'rank'));
  check('audit : correction journalisée avec les deux empreintes', (await qs(`select count(*)::int n from audit_log where action like 'Classement corrigé%' and target like '%ancienne empreinte%'`))[0].n === 1);
  check('empreinte modifiée et intègre après correction', (await qs(`select content_hash h, correction_count c from ranking_periods where period = '${P1}'`))[0].c === 1);
  await works('verify après correction : intact', `select ranking_verify_hash('${P1}') r`, (r) => r[0].r.intact === true && r[0].r.corrections === 1);
  check('étudiant retiré notifié', (await qs(`select count(*)::int n from notifications where user_id = '${S[1]}' and kind = 'ranking_correction'`))[0].n === 1);
  await as(U(3));
  await fails('même étudiant : plus rien à corriger', `select ranking_correct('${P1}', 'Deuxième correction identique', '${S[1]}')`, /Aucune entrée/);
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${S[3]}'`);
  await as(U(2));
  await works('anomalies : classements publiés contenant des entrées devenues inéligibles (S3 suspendu : 5 entrées dans P1 et dans P0)', `select admin_ranking_anomalies() r`, (r) => r[0].r.published_needing_correction.length === 2 && r[0].r.published_needing_correction[0].period === P1 && r[0].r.published_needing_correction[0].entries === 5);
  await as(U(3));
  const cor2 = (await q(`select ranking_correct('${P1}', 'Compte suspendu depuis la publication', null) r`))[0].r;
  check('correction sans étudiant : retire les inéligibles devenus suspendus', cor2.voided === 5, JSON.stringify(cor2));
  await as(U(2));
  await works('anomalies : P1 corrigé ; P0 (non corrigé) reste signalé', `select admin_ranking_anomalies() r`, (r) => r[0].r.published_needing_correction.length === 1 && r[0].r.published_needing_correction[0].period === P0 && r[0].r.integrity.every((x) => x.intact === true));
  await as(U(3));
  await works('corrections listées pour ranking.publish', `select admin_ranking_corrections_list('${P1}') r`, (r) => r[0].r.length >= 10);
  await sup();
  await fails('journal des corrections : ajout seul (modification refusée)', `update ranking_corrections set reason = 'x'`, /ajout seul/);
  await fails('journal des corrections : ajout seul (suppression refusée)', `delete from ranking_corrections`, /ajout seul/);
  await as(U(2));
  await fails('modérateur : liste des corrections refusée', `select admin_ranking_corrections_list('${P1}')`, DENY);

  // ============================================================ ARCHIVAGE
  await as(U(3));
  await fails('archivage : motif court refusé', `select ranking_archive('${P0}', 'court')`, /Motivez/);
  await works('archivage de P0', `select ranking_archive('${P0}', 'Clôture du mois précédent') r`, (r) => r[0].r.status === 'archived');
  await fails('archivage rejoué refusé', `select ranking_archive('${P0}', 'Clôture du mois précédent')`, /déjà archivé/);
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${S[2]}'`);
  await as(U(3));
  await fails('correction d’un classement archivé refusée', `select ranking_correct('${P0}', 'Correction tardive sur archive', '${S[2]}')`, /archivé/);
  await works('liste des périodes : P0 archivé, P1 publié avec corrections', `select admin_ranking_periods_list() r`, (r) => r[0].r.length === 2 && r[0].r.find((p) => p.period === P0).status === 'archived' && r[0].r.find((p) => p.period === P1).corrections === 2);
  await sup();
  await fails('archivé : mise à jour directe refusée', `update ranking_entries set rank = 3 where period_id = (select id from ranking_periods where period = '${P0}')`, /ne se modifie pas/);
  await db.exec(`update profiles set suspended = false where id in ('${S[2]}', '${S[3]}')`);

  // ============================================================ NON PUBLICATION SANS RÈGLES ACTIVES (règle désactivée après coup)
  const P2 = (await qs(`select to_char((now() at time zone 'utc') - interval '2 month', 'YYYY-MM') p`))[0].p;
  await as(U(1));
  await works('admin : règle de score désactivée', `select admin_talent_rule_set('sale_confirmed', 100, null, null, 0, false, 'Désactivation pour tester la non-publication') r`, (r) => r[0].r.active === false);
  await as(U(3));
  await fails('règles inactives : publication refusée', `select ranking_publish('${P2}')`, /Aucune règle de score active/);
  await works('règles inactives : readiness bloquée', `select admin_ranking_readiness('${P2}') r`, (r) => r[0].r.ready === false && r[0].r.blockers.includes('Aucune règle de score active'));
  await as(U(1));
  await works('admin : règle réactivée', `select admin_talent_rule_set('sale_confirmed', 100, null, null, 0, true, 'Réactivation après le test de non-publication') r`, (r) => r[0].r.active === true);
  await as(U(3));
  await fails('mois sans aucun score : rien à publier, aucune période créée', `select ranking_publish('${P2}')`, /Aucun étudiant éligible|dans l'ordre/);
  check('refus : aucune période ni entrée créée par la tentative', (await qs(`select count(*)::int n from ranking_periods where period = '${P2}'`))[0].n === 0);

  // ============================================================ REJEU DES MIGRATIONS 020000 À 020400 : aucun effet de bord
  const snap = async () => JSON.stringify((await qs(`select (select count(*) from ranking_periods) p, (select count(*) from ranking_entries) e, (select count(*) from ranking_institution_entries) i,
    (select count(*) from ranking_corrections) c, (select count(*) from talent_visibility_settings) v, (select count(*) from ranking_settings) s, (select count(*) from talent_profile_views) w,
    (select count(*) from talent_contacts) t, (select count(*) from talent_lists) l, (select string_agg(content_hash, ',' order by period) from ranking_periods) h`))[0]);
  const before = await snap();
  const migDir = new URL('../../migrations/', import.meta.url);
  const files = fs.readdirSync(migDir).filter((f) => /^202611270[2]\d{4}_.*\.sql$/.test(f)).sort();
  check('5 migrations du lot B présentes', files.length === 5, files.join());
  let replayOk = true;
  for (const f of files) { try { await db.exec(fs.readFileSync(new URL(f, migDir), 'utf8')); } catch (e) { replayOk = false; console.log('ECHEC rejeu', f, e.message); } }
  check('rejeu des migrations 020000-020400 : exécution sans erreur', replayOk);
  check('rejeu : aucune donnée créée, supprimée ni modifiée (périodes, entrées, empreintes, consentements, vues, contacts, listes)', (await snap()) === before);
  await works('rejeu : empreintes toujours intactes (P0 et P1)', `select ranking_verify_hash('${P0}') a, ranking_verify_hash('${P1}') b`, (r) => r[0].a.intact === true && r[0].b.intact === true);
  await as(null, 'anon');
  await works('rejeu : lecture publique inchangée', `select top100_national('${P1}') r`, (r) => r[0].r.published === true && r[0].r.items.length >= 1);
  await fails('rejeu : droits inchangés (anonyme refusé sur ranking_publish)', `select ranking_publish('${P2}')`, DENY);
  await sup();
  check('rejeu : une seule fonction ranking_publish, un seul déclencheur par garde', (await qs(`select (select count(*)::int from pg_proc where proname = 'ranking_publish') f, (select count(*)::int from pg_trigger where tgname = 'trg_ranking_guard_entry') t`))[0].f === 1);

  console.log(`\nh12_top100b : ${ok} OK / ${ko} ECHEC`);
}
