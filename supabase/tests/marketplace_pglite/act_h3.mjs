// Lot H3 (Direction) : migrations 20261120030000 à 20261120030200 — la direction n'a aucun pouvoir technique, voit tout en lecture,
// gère les partenariats institutionnels et rend des décisions de validation.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./act_h3.mjs  (attendu : aucune ligne ECHEC)
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000030${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const n = async (sql) => (await q(sql))[0].n;
  const j = async (sql) => (await q(sql))[0].r;

  await db.exec('reset role');
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  // 1 direction, 2 direction suspendue, 3 dept info, 4 dept gestion, 5 étudiante info, 6 client, 7 organisation, 8 admin, 9 finance, 10 support, 11 étudiant gestion
  const users = [[1, 'Directrice Test', 'direction'], [2, 'Direction Suspendue', 'direction'], [3, 'Doua Dept Info', 'dept'], [4, 'Gaby Dept Gestion', 'dept'], [5, 'Awa Etudiante', 'student'],
    [6, 'Kim Cliente', 'client'], [7, 'Orange Cameroun', 'company'], [8, 'Mod Admin', 'admin'], [9, 'Fin Agent', 'finance'], [10, 'Sup Agent', 'support'], [11, 'Gil Etudiant', 'student']];
  for (const [id, nm, role] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${U(id)}','h3u${id}@t.cm'); insert into profiles(id,name,role,email) values ('${U(id)}','${nm}','${role}','h3u${id}@t.cm')`);
  }
  const I1 = '00000000-0000-0000-0000-00000000a301', D1 = '00000000-0000-0000-0000-00000000a311', D2 = '00000000-0000-0000-0000-00000000a312';
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test H3', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I1}', 'Gestion', 'verified');
    update profiles set department_id = '${D1}', department = 'Informatique' where id in ('${U(3)}', '${U(5)}');
    update profiles set department_id = '${D2}', department = 'Gestion' where id in ('${U(4)}', '${U(11)}');
    update profiles set certification = 'approved' where role = 'student';
    insert into department_accounts (user_id, department_id) values ('${U(3)}', '${D1}'), ('${U(4)}', '${D2}');
    insert into department_partnerships (department_id, partner_name, kind, status) values ('${D1}', 'Camtel Stages', 'stage', 'actif'), ('${D2}', 'Banque Locale', 'convention', 'prospect');
    insert into sponsors (id, name, owner_id) values ('00000000-0000-0000-0000-0000000030a1', 'Orange Cameroun', '${U(7)}');
    insert into sponsorships (sponsor_id, title, department, amount, students, status) values ('00000000-0000-0000-0000-0000000030a1', 'Serre intelligente', 'Informatique', 900000, 4, 'termine');
    insert into company_profiles (owner_id, company_name, status) values ('${U(7)}', 'Orange Cameroun', 'approved');
    insert into projects (owner_id, title, summary, department, status, kind) values
      ('${U(5)}', 'Application de gestion', 'Resume', 'Informatique', 'approved', 'projet'), ('${U(5)}', 'Capteur solaire', 'Resume', 'Informatique', 'approved', 'innovation'),
      ('${U(11)}', 'Caisse enregistreuse', 'Resume', 'Gestion', 'submitted', 'projet'), ('${U(11)}', 'Brouillon prive', 'Resume', 'Gestion', 'draft', 'projet');
    insert into listings (id, seller_id, title, department, price, status) values ('00000000-0000-0000-0000-0000000030e1', '${U(5)}', 'Lampe H3', 'Informatique', 5000, 'approved');
    insert into orders (id, number, buyer_id, subtotal, fee, method, paid) values ('00000000-0000-0000-0000-0000000030d1', '#BE-2026-3001', '${U(6)}', 5000, 100, 'mobile_money', true);
    insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('00000000-0000-0000-0000-0000000030d1', '00000000-0000-0000-0000-0000000030e1', 'Lampe H3', 5000, 1);
    insert into audit_log (actor, action, target, category, level) values ('Test', 'Action de test', 'x', 'Test', 'Info');
    insert into mentors (name, role, specialty) values ('Mentor H3', 'Mentor', 'Web');
    insert into productions (title, team, status) values ('Prod H3', 'Equipe', 'en_cours')`);
  const suspend = async (id, on) => { await db.exec('reset role'); await db.exec(`update profiles set suspended = ${on} where id = '${U(id)}'`); };
  await suspend(2, true);

  // ============================================================ 1. Retrait des pouvoirs techniques / d'administration
  await as(U(1));
  await fails('H3-1 : direction : plus de lecture des réglages de la plateforme', `select settings_all()`, /non autorisée/);
  await fails('H3-1 : direction : plus de création de contenu éditorial', `select cms_save(null, 'page', 'Titre', 'Corps', true)`, /non autorisée/);
  await fails('H3-1 : direction : plus de modération des campagnes publicitaires', `select ad_campaign_review('00000000-0000-0000-0000-0000000030f1', true, null)`, /non autorisée/);
  await fails('H3-1 : direction : plus de liste des retraits en borne', `select pickups_list()`, /non autorisée/);
  await fails('H3-1 : direction : plus de liste complète des comptes (e-mails, connexions)', `select admin_users(null, 10)`, /non autorisée/);
  await fails('H3-1 : direction : plus de journal financier détaillé', `select finance_journal(10)`, /non autorisée/);
  await fails('H3-1 : direction : plus de liste des paiements individuels', `select finance_payments(null, 10)`, /non autorisée/);
  await fails('H3-1 : direction : plus de liste des versements aux vendeurs', `select finance_payouts(10)`, /non autorisée/);
  await fails('H3-1 : direction : ne crée pas de versement', `select payout_create('${U(5)}', 1000, 'Mobile Money', current_date)`, /non autorisée/);
  await fails('H3-1 : direction : ne modifie aucun réglage', `select setting_set('security.2fa_required', 'false'::jsonb)`, /non autorisée/);
  await fails('H3-1 : direction : n ajoute pas de mentor (suivi en lecture seule)', `select mentor_create('Intrus', 'Mentor', 'Web')`, /non autorisée/);
  await fails('H3-1 : direction : ne crée pas de production', `select production_create('Prod X', 'Equipe', null, null)`, /non autorisée/);
  check('H3-1 : direction : le suivi (lecture) du département reste possible', Array.isArray(await j(`select staff_mentors() r`)) && Array.isArray(await j(`select staff_productions() r`)));
  check('H3-1 : direction : aucune transaction de paiement visible', (await n(`select count(*)::int n from payment_transactions`)) === 0);
  check('H3-1 : direction : aucun lot de reversement visible', (await n(`select count(*)::int n from payout_batches`)) === 0);
  check('H3-1 : direction : aucun journal d audit technique visible', (await n(`select count(*)::int n from audit_log`)) === 0);
  check('H3-1 : direction : ne lit pas les profils des autres comptes (e-mails, téléphones)', (await n(`select count(*)::int n from profiles where id = '${U(6)}'`)) === 0);
  check('H3-1 : direction : la vue d\'ensemble consolidée reste lisible', (await j(`select platform_overview() r`)).orders_paid === 1);
  check('H3-1 : direction : la finance consolidée (vue d\'ensemble) reste lisible', (await j(`select finance_overview() r`)).orders_paid === 1);
  check('H3-1 : direction : la finance consolidée par département reste lisible', Array.isArray(await j(`select finance_by_department() r`)));
  await db.exec('reset role');
  await db.exec(`insert into payment_transactions (id, payer_id, kind, subject, amount, reference, status, provider) values ('00000000-0000-0000-0000-0000000030f9', '${U(6)}', 'order', 'x', 5100, 'REF-H3', 'pending', 'manual')`).catch((e) => console.log('   (info) insertion transaction :', e.message.slice(0, 120)));
  await as(U(1));
  check('H3-1 : direction : une transaction existante reste invisible', (await n(`select count(*)::int n from payment_transactions`)) === 0);
  await as(U(9));
  check('H3-1 : finance : garde ses lectures (journal, paiements, versements)', Array.isArray((await j(`select finance_payments(null, 10) r`))) && (await j(`select finance_journal(10) r`)).rows !== undefined && Array.isArray(await j(`select finance_payouts(10) r`)));
  await as(U(8));
  check('H3-1 : admin : garde les réglages', typeof (await j(`select settings_all() r`)) === 'object');
  check('H3-1 : admin : garde la liste des comptes', Array.isArray(await j(`select admin_users(null, 10) r`)));
  check('H3-1 : admin : voit le journal d\'audit et les profils', (await n(`select count(*)::int n from audit_log`)) >= 1 && (await n(`select count(*)::int n from profiles where id = '${U(6)}'`)) === 1);
  await as(U(10));
  check('H3-1 : support : garde la liste des comptes', Array.isArray(await j(`select admin_users(null, 10) r`)));
  await as(U(3));
  check('H3-1 : département : garde le suivi en écriture (mentors, productions)', typeof (await j(`select mentor_create('Mentor Dept', 'Mentor', 'Reseaux') r`)) === 'string');
  await as(U(2));
  await fails('H3-1 : direction suspendue : plus rien (finance consolidée)', `select finance_overview()`, /non autorisée/);
  await as(null, 'anon');
  await fails('H3-1 : visiteur : aucun accès à la finance consolidée', `select finance_overview()`, /permission|Connexion/);

  // ============================================================ 2. Vision transversale en lecture
  const fnsRead = ['direction_dashboard()', 'direction_departments()', `direction_department_detail('${D1}')`, `direction_activity('projects')`, 'direction_performance()', `direction_people('students')`,
    'direction_finance_summary(6)', 'direction_consolidated_report()', 'direction_decisions_journal(10)', 'direction_dept_partnerships()', 'direction_sponsors_report()'];
  for (const [id, who] of [[5, 'étudiant'], [6, 'client'], [7, 'organisation'], [9, 'finance'], [10, 'support'], [3, 'département'], [2, 'direction suspendue']]) {
    await as(U(id));
    let denied = 0;
    for (const f of fnsRead) { try { await q(`select ${f} r`); } catch (e) { if (/Réservé à la direction|permission|Connexion/.test(e.message)) denied++; } }
    check(`H3-2 : ${who} : aucune fonction direction_* n'est accessible (${denied}/${fnsRead.length})`, denied === fnsRead.length);
  }
  await as(null, 'anon');
  let deniedAnon = 0;
  for (const f of fnsRead) { try { await q(`select ${f} r`); } catch (e) { if (/permission|Connexion/.test(e.message)) deniedAnon++; } }
  check(`H3-2 : visiteur : aucune fonction direction_* (${deniedAnon}/${fnsRead.length})`, deniedAnon === fnsRead.length);

  await as(U(1));
  const dash = await j(`select direction_dashboard() r`);
  check('H3-2 : tableau de bord : étudiants vérifiés = 2', dash.students_verified === 2, JSON.stringify(dash));
  check('H3-2 : tableau de bord : projets 1, innovations 1, en attente 1', dash.projects === 1 && dash.innovations === 1 && dash.projects_pending === 1);
  check('H3-2 : tableau de bord : 2 départements, 2 responsables', dash.departments >= 2 && dash.dept_heads === 2);
  check('H3-2 : tableau de bord : commandes payées et chiffre consolidés', dash.orders_paid === 1 && Number(dash.paid_revenue) === 5100);
  check('H3-2 : tableau de bord : 6 mois d\'évolution', Array.isArray(dash.months) && dash.months.length === 6);
  const deps = await j(`select direction_departments() r`);
  const dInfo = deps.find((x) => x.id === D1), dGest = deps.find((x) => x.id === D2);
  check('H3-2 : départements : Informatique voit ses chiffres (1 étudiant, 1 projet, 1 innovation, 5000 de ventes)', dInfo && dInfo.students === 1 && dInfo.projects === 1 && dInfo.innovations === 1 && Number(dInfo.sales) === 5000, JSON.stringify(dInfo));
  check('H3-2 : départements : Gestion a un projet en attente et aucune vente', dGest && dGest.projects_pending === 1 && Number(dGest.sales) === 0 && dGest.head === 'Gaby Dept Gestion');
  const det = await j(`select direction_department_detail('${D2}') r`);
  check('H3-2 : fiche département : brouillons privés exclus, projet soumis visible', det.recent_projects.length === 1 && det.recent_projects[0].title === 'Caisse enregistreuse', JSON.stringify(det.recent_projects));
  await fails('H3-2 : fiche département inconnue : refusée', `select direction_department_detail('${U(99)}')`, /introuvable/);
  const act = await j(`select direction_activity('innovations') r`);
  check('H3-2 : activités : innovations (1) avec département', act.length === 1 && act[0].department === 'Informatique');
  check('H3-2 : activités : projets filtrés par département', (await j(`select direction_activity('projects', '${D2}') r`)).length === 1);
  check('H3-2 : activités : productions et événements et offres listables', Array.isArray(await j(`select direction_activity('productions') r`)) && Array.isArray(await j(`select direction_activity('events') r`)) && Array.isArray(await j(`select direction_activity('opportunities') r`)));
  await fails('H3-2 : activités : type inconnu refusé', `select direction_activity('mots-de-passe')`, /inconnu/);
  const perf = await j(`select direction_performance() r`);
  const pInfo = perf.departments.find((x) => x.id === D1);
  check('H3-2 : performances : taux et ratios par département', pInfo && pInfo.projects_approved === 1 && pInfo.projects_per_100_students === 200 && Number(pInfo.sales) === 5000, JSON.stringify(pInfo));
  check('H3-2 : performances : comparaison de périodes présente', perf.periods.projects.current >= 3);
  const ppl = await j(`select direction_people('students') r`);
  check('H3-2 : personnes : étudiants sans e-mail ni téléphone', ppl.length === 2 && ppl.every((x) => !('email' in x) && !('phone' in x)));
  const heads = await j(`select direction_people('responsables') r`);
  check('H3-2 : personnes : responsables de département seulement, sans e-mail', heads.length === 2 && heads.every((x) => x.role === 'dept' && !('email' in x)));
  check('H3-2 : personnes : mentors listés', (await j(`select direction_people('mentors') r`)).some((x) => x.name === 'Mentor H3'));
  const dpt = await j(`select direction_dept_partnerships() r`);
  check('H3-2 : suivi des partenariats de départements : lecture de tous les départements', dpt.length === 2 && dpt.some((x) => x.partner === 'Camtel Stages' && x.department === 'Informatique') && (await j(`select direction_dept_partnerships('${D2}') r`)).length === 1);
  check('H3-2 : tableau de bord : partenariats de départements actifs = 1', (await j(`select direction_dashboard() r`)).dept_partnerships_active === 1);
  const spr = await j(`select direction_sponsors_report() r`);
  check('H3-2 : rapport de sponsoring consolidé (tous sponsors)', Number(spr.total) === 900000 && spr.students === 4 && spr.rows.length === 1 && spr.rows[0].sponsor === 'Orange Cameroun');
  const fin = await j(`select direction_finance_summary(3) r`);
  check('H3-2 : finance consolidée : agrégats mensuels sans donnée individuelle', fin.months.length === 3 && Number(fin.totals.collected) === 5100 && Number(fin.totals.fees) === 100 && !JSON.stringify(fin).includes('REF-H3'));
  const rep = await j(`select direction_consolidated_report(null, null) r`);
  check('H3-2 : rapport consolidé : lignes globales et par département', rep.lines.length > 20 && rep.lines.some((l) => l.department === 'Informatique') && rep.generated_by === 'Directrice Test');
  await fails('H3-2 : rapport : période inversée refusée', `select direction_consolidated_report('2026-12-01', '2026-01-01')`, /suit la date/);
  await as(U(8));
  check('H3-2 : admin : peut aussi lire le tableau de bord', (await j(`select direction_dashboard() r`)).projects === 1);

  // ============================================================ 3. Partenariats institutionnels
  await as(U(1));
  const P1 = await j(`select partnership_save(null, 'Orange Cameroun', 'entreprise', '${D1}', '${U(7)}', 'M. Contact', 'contact@orange.cm', '+237600000000', 'Stages et recrutement', array['stages','recrutement'], '2026-12-01', '2027-12-01') r`);
  check('H3-3 : direction : crée un partenariat', typeof P1 === 'string' && P1.length === 36);
  await db.exec('reset role');
  check('H3-3 : partenariat créé au statut proposé', (await n(`select count(*)::int n from institutional_partnerships where id = '${P1}' and status = 'proposed'`)) === 1);
  check('H3-3 : une validation « partenariat » en attente est ouverte', (await n(`select count(*)::int n from institutional_validations where kind = 'partnership' and subject_id = '${P1}' and status = 'pending'`)) === 1);
  await as(U(1));
  await fails('H3-3 : nom trop court refusé', `select partnership_save(null, 'A', 'entreprise', null, null, '', '', '', '', null, null, null)`, /Nom du partenaire/);
  await fails('H3-3 : type invalide refusé', `select partnership_save(null, 'Partenaire X', 'mafia', null, null, '', '', '', '', null, null, null)`, /Type de partenaire/);
  await fails('H3-3 : e-mail invalide refusé', `select partnership_save(null, 'Partenaire X', 'ong', null, null, '', 'pas-un-mail', '', '', null, null, null)`, /e-mail/);
  await fails('H3-3 : dates incohérentes refusées', `select partnership_save(null, 'Partenaire X', 'ong', null, null, '', '', '', '', null, '2027-01-01', '2026-01-01')`, /date de fin/);
  await fails('H3-3 : département inconnu refusé', `select partnership_save(null, 'Partenaire X', 'ong', '${U(98)}', null, '', '', '', '', null, null, null)`, /Département introuvable/);
  await fails('H3-3 : organisation inconnue refusée', `select partnership_save(null, 'Partenaire X', 'ong', null, '${U(98)}', '', '', '', '', null, null, null)`, /Organisation introuvable/);
  await fails('H3-3 : décision inconnue refusée', `select partnership_decide('${P1}', 'detruire', null)`, /inconnue/);
  await fails('H3-3 : suspendre un partenariat non actif refusé', `select partnership_decide('${P1}', 'suspend', 'Motif valable')`, /actif peut être suspendu/);
  // Un département propose pour SON département
  await as(U(3));
  const P2 = await j(`select partnership_save(null, 'Association Jeunes Dev', 'association', '${D2}', null, 'Mme Contact', '', '', 'Ateliers', array['formation'], null, null) r`);
  await db.exec('reset role');
  check('H3-3 : département : sa proposition est rattachée à SON département (le département envoyé est ignoré)', (await n(`select count(*)::int n from institutional_partnerships where id = '${P2}' and department_id = '${D1}' and status = 'proposed'`)) === 1);
  check('H3-3 : la direction est notifiée de la proposition', (await n(`select count(*)::int n from notifications where user_id = '${U(1)}' and title = 'Partenariat à valider'`)) === 1);
  check('H3-3 : la direction suspendue n\'est pas notifiée', (await n(`select count(*)::int n from notifications where user_id = '${U(2)}'`)) === 0);
  await as(U(3));
  await fails('H3-3 : département : ne décide pas', `select partnership_decide('${P2}', 'approve', null)`, /Réservé à la direction/);
  const listDept = await j(`select partnerships_list() r`);
  check('H3-3 : département : voit seulement les partenariats de son département', listDept.length === 2 && listDept.some((x) => x.id === P2) && listDept.every((x) => x.department_id === D1));
  await fails('H3-3 : département : ne modifie pas le partenariat de la direction', `select partnership_save('${P1}', 'Détourné', 'entreprise', null, null, '', '', '', '', null, null, null)`, /Seule votre proposition/);
  await q(`select partnership_save('${P2}', 'Association Jeunes Dev 2', 'association', null, null, 'Mme Contact', '', '', 'Ateliers de code', array['formation'], null, null)`);
  check('H3-3 : département : corrige sa proposition en attente', (await j(`select partnerships_list() r`))[0].name === 'Association Jeunes Dev 2');
  await as(U(4));
  check('H3-3 : autre département : ne voit pas les partenariats d\'Informatique', (await j(`select partnerships_list() r`)).length === 0);
  await as(U(5));
  await fails('H3-3 : étudiant : aucune liste de partenariats', `select partnerships_list()`, /non autorisée/);
  await fails('H3-3 : étudiant : ne propose pas de partenariat', `select partnership_save(null, 'Partenaire X', 'ong', null, null, '', '', '', '', null, null, null)`, /non autorisée/);
  await as(U(6));
  await fails('H3-3 : client : aucune liste de partenariats', `select partnerships_list()`, /non autorisée/);
  await as(null, 'anon');
  await fails('H3-3 : visiteur : aucun partenariat', `select partnerships_list()`, /permission|Connexion/);
  await as(U(2));
  await fails('H3-3 : direction suspendue : ne crée rien', `select partnership_save(null, 'Partenaire X', 'ong', null, null, '', '', '', '', null, null, null)`, /non autorisée/);
  await as(U(7));
  check('H3-3 : organisation : ne voit pas un partenariat encore proposé', (await j(`select partnerships_list() r`)).length === 0);
  // Décisions
  await as(U(1));
  await fails('H3-3 : refus sans motif impossible', `select partnership_decide('${P2}', 'reject', '')`, /motif/);
  check('H3-3 : direction valide le partenariat Orange', (await j(`select partnership_decide('${P1}', 'approve', 'Convention signée') r`)) === 'active');
  await fails('H3-3 : valider deux fois refusé', `select partnership_decide('${P1}', 'approve', null)`, /plus en attente/);
  check('H3-3 : direction refuse l\'autre proposition avec motif', (await j(`select partnership_decide('${P2}', 'reject', 'Périmètre à préciser') r`)) === 'rejected');
  await db.exec('reset role');
  check('H3-3 : les validations liées sont closes (accordée / refusée)', (await n(`select count(*)::int n from institutional_validations where kind = 'partnership' and status = 'approved' and subject_id = '${P1}'`)) === 1 && (await n(`select count(*)::int n from institutional_validations where kind = 'partnership' and status = 'rejected' and subject_id = '${P2}'`)) === 1);
  check('H3-3 : le proposant (département) est notifié du refus avec le motif', (await n(`select count(*)::int n from notifications where user_id = '${U(3)}' and title = 'Partenariat refusé' and body like '%Périmètre à préciser%'`)) === 1);
  check('H3-3 : l\'organisation liée est notifiée de la validation', (await n(`select count(*)::int n from notifications where user_id = '${U(7)}' and title = 'Partenariat validé'`)) === 1);
  check('H3-3 : les décisions sont dans le journal institutionnel et l\'audit', (await n(`select count(*)::int n from institutional_decision_log`)) === 2 && (await n(`select count(*)::int n from audit_log where category = 'Institution' and level = 'Sensible'`)) === 2);
  await as(U(7));
  const orgList = await j(`select partnerships_list() r`);
  check('H3-3 : organisation : voit son partenariat actif', orgList.length === 1 && orgList[0].id === P1 && orgList[0].company === 'Orange Cameroun');
  await as(U(1));
  await fails('H3-3 : suspension sans motif refusée', `select partnership_decide('${P1}', 'suspend', 'x')`, /motif/);
  check('H3-3 : suspension avec motif', (await j(`select partnership_decide('${P1}', 'suspend', 'Convention à renouveler') r`)) === 'suspended');
  check('H3-3 : reprise', (await j(`select partnership_decide('${P1}', 'resume', null) r`)) === 'active');
  check('H3-3 : clôture avec motif', (await j(`select partnership_decide('${P1}', 'end', 'Fin de convention') r`)) === 'ended');
  await fails('H3-3 : un partenariat clos ne se modifie plus', `select partnership_save('${P1}', 'Orange', 'entreprise', null, null, '', '', '', '', null, null, null)`, /clos/);
  check('H3-3 : filtre par statut', (await j(`select partnerships_list('ended') r`)).length === 1 && (await j(`select partnerships_list('active') r`)).length === 0);
  await as(U(8));
  check('H3-3 : admin : voit tous les partenariats', (await j(`select partnerships_list() r`)).length === 2);
  await as(U(9));
  await fails('H3-3 : finance : aucun partenariat', `select partnerships_list()`, /non autorisée/);
  await as(U(1));
  await fails('H3-3 : aucun accès direct aux tables de partenariats', `select count(*) from institutional_partnerships`, /permission/);

  // ============================================================ 4. Validations institutionnelles
  await as(U(4));
  const V1 = await j(`select institutional_validation_request('report', 'Rapport semestriel Gestion', 'Résultats du semestre', null, null) r`);
  await fails('H3-4 : type de validation invalide refusé', `select institutional_validation_request('partnership', 'Contournement', '', null, null)`, /Type de validation/);
  await fails('H3-4 : objet trop court refusé', `select institutional_validation_request('report', 'ab', '', null, null)`, /Objet/);
  await as(U(5));
  await fails('H3-4 : étudiant : ne demande pas de validation institutionnelle', `select institutional_validation_request('report', 'Rapport étudiant', '', null, null)`, /non autorisée/);
  await as(U(4));
  const vl = await j(`select institutional_validations_list('pending') r`);
  check('H3-4 : département : voit sa demande (département Gestion)', vl.length === 1 && vl[0].id === V1 && vl[0].department === 'Gestion');
  await as(U(3));
  check('H3-4 : autre département : ne voit pas la demande de Gestion', (await j(`select institutional_validations_list('all') r`)).every((x) => x.id !== V1));
  await fails('H3-4 : département : ne décide pas', `select institutional_validation_decide('${V1}', true, null)`, /Réservé à la direction/);
  await as(U(1));
  const allV = await j(`select institutional_validations_list('pending') r`);
  check('H3-4 : direction : voit la file des validations en attente', allV.some((x) => x.id === V1));
  await fails('H3-4 : refus sans motif impossible', `select institutional_validation_decide('${V1}', false, null)`, /motif/);
  check('H3-4 : direction accorde la validation', (await j(`select institutional_validation_decide('${V1}', true, 'Conforme') r`)) === 'approved');
  await fails('H3-4 : deuxième décision refusée', `select institutional_validation_decide('${V1}', false, 'Trop tard')`, /déjà été traitée/);
  await db.exec('reset role');
  check('H3-4 : le demandeur est notifié', (await n(`select count(*)::int n from notifications where user_id = '${U(4)}' and title = 'Validation accordée'`)) === 1);
  await as(U(4));
  const V2 = await j(`select institutional_validation_request('event', 'Journée portes ouvertes', '', null, null) r`);
  await q(`select institutional_validation_cancel('${V2}')`);
  check('H3-4 : le demandeur retire sa demande en attente', (await j(`select institutional_validations_list('cancelled') r`)).length === 1);
  await as(U(3));
  await fails('H3-4 : on ne retire pas la demande d\'un autre', `select institutional_validation_cancel('${V1}')`, /introuvable/);
  await as(U(1));
  const V3 = await j(`select institutional_validation_request('department_request', 'Nouvelle filière Data', 'Création', '${D1}', null) r`);
  const P3 = await j(`select partnership_save(null, 'ONG Eau Propre', 'ong', '${D2}', null, '', '', '', 'Projets eau', null, null, null) r`);
  const vPart = (await j(`select institutional_validations_list('pending') r`)).find((x) => x.subject_id === P3);
  check('H3-4 : un partenariat proposé apparaît dans la file des validations', !!vPart && vPart.kind === 'partnership');
  check('H3-4 : valider la ligne « partenariat » active le partenariat', (await j(`select institutional_validation_decide('${vPart.id}', true, 'Ok') r`)) === 'approved' && (await j(`select partnerships_list('active') r`)).some((x) => x.id === P3));
  check('H3-4 : refus d\'une demande de département avec motif', (await j(`select institutional_validation_decide('${V3}', false, 'Dossier incomplet') r`)) === 'rejected');
  const jr = await j(`select direction_decisions_journal(50) r`);
  check('H3-4 : journal des décisions : décisions de partenariat et de validation, avec acteur et motif', jr.length >= 5 && jr.some((x) => x.action === 'Validation refusée' && x.note === 'Dossier incomplet' && x.actor === 'Directrice Test'));
  await as(U(8));
  check('H3-4 : admin : lit le journal des décisions', (await j(`select direction_decisions_journal(5) r`)).length === 5);
  await as(U(3));
  await fails('H3-4 : département : pas de journal des décisions', `select direction_decisions_journal(5)`, /Réservé à la direction/);

  console.log(`\n${ok}/${ok + ko}`);
}
