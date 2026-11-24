// Lot H9 / EVAL : socle fournisseur-agnostique du module « Talent Assessment » (migration 20261125095000).
// Prouve : 33 familles, registre vide, activation refusée sans test d'intégration, refus sans fournisseur actif (quota intact), quota mensuel (1 par mois civil, remise à zéro),
// quota consommé seulement à l'acceptation, prix absent / différent / identique, isolation, organisation, anonyme, non-étudiant, résultats (validation humaine), contestation, 2FA, rejeu.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h9_evaluation.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000091${String(n).padStart(2, '0')}`;
  const ADM = id(1), ADM2FA = id(2), ST1 = id(3), ST2 = id(4), CLI = id(5), ORG = id(6), ORG2 = id(7), TECH = id(8), SUP = id(9), VEND = id(10);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const asAal = async (uid, aal) => { cur = { uid, role: 'authenticated' }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false); set role authenticated`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const DENY = /Réservé|réservé|Accès refusé|Connexion requise|permission denied|exige la permission|row-level security/i;
  const req = async (fam, mode, funding = 'gratuite_mensuelle', price = 'null', consent = true, camp = 'null') =>
    (await q(`select assessment_request('${fam}', '${mode}', ${consent}, '${funding}', ${price}, ${camp}) r`))[0].r;
  const quota = async () => (await q(`select assessment_quota() r`))[0].r;

  // ============================================================ comptes
  await db.exec('reset role');
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [ADM2FA, 'Mfa Admin', 'admin'], [ST1, 'Etu Un', 'student'], [ST2, 'Etu Deux', 'student'], [CLI, 'Cli Client', 'client'],
    [ORG, 'Org Une', 'company'], [ORG2, 'Org Deux', 'company'], [TECH, 'Tech Agent', 'support'], [SUP, 'Sup Agent', 'support'], [VEND, 'Vend Etudiant', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','u${i.slice(-2)}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','u${i.slice(-2)}@t.cm')`);
  }
  await as(ADM);
  await q(`select admin_team_member_set('${TECH}', 'tech', array['tech.integrations'])`);
  await sup();

  // ============================================================ A. Familles et registre vide
  await as(ST1);
  const fams = (await q(`select assessment_families() r`))[0].r;
  check('A1 33 familles lues sur le serveur', fams.length === 33, String(fams.length));
  check('A2 codes stables uniques et libellés non vides', new Set(fams.map((f) => f.code)).size === 33 && fams.every((f) => f.label && f.code));
  check('A3 aucune famille couverte tant que le registre est vide', fams.every((f) => f.covered === false));
  check('A4 registre des fournisseurs vide (aucune ligne insérée)', (await qs(`select count(*)::int n from assessment_providers`))[0].n === 0);
  check('A5 aucune demande, aucun résultat à la livraison', (await qs(`select (select count(*) from assessment_requests) + (select count(*) from assessment_results) n`))[0].n == 0);
  let qt = await quota();
  check('A6 quota étudiant : 1 gratuite, 0 utilisée, 1 restante, aucun fournisseur actif', qt.eligible && qt.monthly_free === 1 && qt.used === 0 && qt.remaining === 1 && qt.active_providers === 0, JSON.stringify(qt));
  check('A7 prochaine remise à zéro = 1er du mois suivant (Douala)', new Date(qt.next_reset) > new Date() && new Date(qt.next_reset) - new Date() < 32 * 86400000, qt.next_reset);
  check('A8 prix supplémentaire non décidé : indisponible, aucun prix', qt.extra.available === false && qt.extra.price_xaf === null && /pas encore été décidé/.test(qt.extra.message), JSON.stringify(qt.extra));
  check('A9 liste vide au départ', (await q(`select assessment_my_list() r`))[0].r.length === 0);

  // ============================================================ B. Aucun fournisseur actif : refus sans consommation
  let r = await req('mecanique', 'simulation');
  check('B1 aucun fournisseur actif : demande refusée proprement', r.ok === false && r.code === 'no_provider' && /Aucun fournisseur actif/.test(r.message), JSON.stringify(r));
  check('B2 rien n\'est enregistré ni consommé', (await qs(`select count(*)::int n from assessment_requests`))[0].n === 0 && (await quota()).remaining === 1);
  r = await req('mecanique', 'simulation', 'gratuite_mensuelle', 'null', false);
  check('B3 consentement requis', r.ok === false && r.code === 'consent_required');

  // ============================================================ C. Activation d'un fournisseur (admin, 2FA, test d'intégration)
  for (const [who, uid] of [['étudiant', ST1], ['client', CLI], ['organisation', ORG], ['agent support', SUP], ['agent technique', TECH]]) {
    await as(uid);
    await fails(`C1 ${who} : enregistrement d'un fournisseur refusé`, `select assessment_provider_register('prov_a', 'Fournisseur A', array['mecanique'], array['simulation'])`, DENY);
    await fails(`C2 ${who} : changement de statut refusé`, `select assessment_provider_set_status('prov_a', 'actif')`, DENY);
    await fails(`C3 ${who} : modification d'une famille refusée`, `select assessment_family_set('zz_test', 'Test', true, null)`, DENY);
  }
  await as(TECH);
  check('C4 agent technique (tech.integrations) : liste des fournisseurs lisible', Array.isArray((await q(`select assessment_providers_admin_list() r`))[0].r));
  await as(SUP);
  await fails('C5 agent sans permission technique : liste refusée', `select assessment_providers_admin_list()`, DENY);
  await as(ST1);
  await fails('C6 étudiant : liste d\'administration refusée', `select assessment_providers_admin_list()`, DENY);

  await as(ADM);
  await works('C7 administrateur : enregistre un fournisseur candidat (test uniquement)', `select assessment_provider_register('prov_a', 'Fournisseur A', array['mecanique','soudure'], array['simulation','ecrit'])`);
  check('C8 statut initial candidat', (await q(`select status from assessment_providers where code = 'prov_a'`))[0].status === 'candidat');
  await fails('C9 activation refusée sans test d\'intégration', `select assessment_provider_set_status('prov_a', 'actif')`, /aucun test d'intégration réussi/);
  await works('C10 test d\'intégration ÉCHOUÉ enregistré', `select assessment_provider_record_test('prov_a', false, 'appel de test en échec')`);
  await fails('C11 activation refusée après un test échoué', `select assessment_provider_set_status('prov_a', 'actif')`, /aucun test d'intégration réussi/);
  check('C12 un test enregistré passe le fournisseur à « en_test »', (await q(`select status from assessment_providers where code = 'prov_a'`))[0].status === 'en_test');
  await as(ST1);
  r = await req('mecanique', 'simulation');
  check('C13 fournisseur en test : toujours refusé (non actif)', r.ok === false && r.code === 'no_provider');

  // 2FA : administrateur avec facteur vérifié
  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${ADM2FA}', 'verified')`);
  await asAal(ADM2FA, 'aal1');
  await fails('C14 administrateur avec 2FA en session aal1 : enregistrement refusé', `select assessment_provider_record_test('prov_a', true, 'ok')`, /double authentification/);
  await fails('C15 administrateur avec 2FA en session aal1 : activation refusée', `select assessment_provider_set_status('prov_a', 'actif')`, /double authentification/);
  await asAal(ADM2FA, 'aal2');
  await works('C16 session aal2 : test réussi enregistré', `select assessment_provider_record_test('prov_a', true, 'appel de test réussi (banc)')`);
  await works('C17 session aal2 : activation acceptée avec test réussi', `select assessment_provider_set_status('prov_a', 'actif')`);
  await sup();
  const audit = await q(`select action, level, actor_id from audit_log where category = 'Évaluations' order by id`);
  check('C18 journal d\'audit : enregistrement, tests, activation (Critique)', audit.length >= 4 && audit.some((a) => /actif/.test(a.action) && a.level === 'Critique') && audit.every((a) => a.actor_id), JSON.stringify(audit.map((a) => a.action)));
  await as(ADM);
  const lst = (await q(`select assessment_providers_admin_list() r`))[0].r;
  check('C19 liste admin : fournisseur actif, dernier test réussi', lst.length === 1 && lst[0].status === 'actif' && lst[0].last_test.ok === true, JSON.stringify(lst));
  await as(ST1);
  fams.splice(0, fams.length, ...(await q(`select assessment_families() r`))[0].r);
  check('C20 familles couvertes : mécanique et soudure seulement', fams.filter((f) => f.covered).map((f) => f.code).sort().join() === 'mecanique,soudure');
  await as(ADM);
  await sup();
  await db.exec(`update assessment_providers set modes = array['simulation','ecrit'] where code = 'prov_a'`);
  await as(ADM);
  await q(`select assessment_provider_register('prov_a', 'Fournisseur A', array['mecanique','soudure'], array['simulation','ecrit'])`);
  check('C21 ré-enregistrer ne change pas le statut', (await q(`select status from assessment_providers where code = 'prov_a'`))[0].status === 'actif');

  // ============================================================ D. Quota mensuel
  await as(ST1);
  r = await req('plomberie', 'simulation');
  check('D1 famille non couverte : refus sans consommation', r.ok === false && r.code === 'no_provider');
  r = await req('mecanique', 'presentation_video');
  check('D2 mode non couvert : refus sans consommation', r.ok === false && r.code === 'no_provider');
  r = await req('mecanique', 'simulation');
  check('D3 fournisseur actif : demande envoyée (en attente de réponse)', r.ok === true && r.status === 'envoyee', JSON.stringify(r));
  const REQ1 = r.id;
  qt = await quota();
  check('D4 envoyée mais non acceptée : quota NON consommé', qt.used === 0 && qt.remaining === 1 && qt.pending === true, JSON.stringify(qt));
  r = await req('soudure', 'ecrit');
  check('D5 seconde demande gratuite pendant l\'attente : refusée', r.ok === false && r.code === 'already_pending');
  await fails('D6 étudiant : ne peut pas accuser réception à la place du fournisseur', `select assessment_request_ack('${REQ1}', 'acceptee')`, DENY);
  await as(ADM);
  await works('D7 refus du fournisseur', `select assessment_request_ack('${REQ1}', 'refusee', 'Fournisseur indisponible')`);
  await as(ST1);
  qt = await quota();
  check('D8 demande refusée par le fournisseur : quota intact', qt.used === 0 && qt.remaining === 1 && qt.pending === false, JSON.stringify(qt));
  r = await req('mecanique', 'simulation');
  const REQ2 = r.id;
  await as(ADM);
  await works('D9 échec du fournisseur', `select assessment_request_ack('${REQ2}', 'echouee', 'erreur technique')`);
  await as(ST1);
  check('D10 demande échouée : quota intact', (await quota()).remaining === 1);
  r = await req('mecanique', 'simulation');
  const REQ3 = r.id;
  await as(ADM);
  await works('D11 le fournisseur actif ACCEPTE la demande', `select assessment_request_ack('${REQ3}', 'acceptee')`);
  await as(ST1);
  qt = await quota();
  check('D12 acceptée : quota consommé (« utilisée »), prochaine remise à zéro fournie', qt.used === 1 && qt.remaining === 0 && qt.next_reset, JSON.stringify(qt));
  r = await req('mecanique', 'ecrit');
  check('D13 2e évaluation gratuite du même mois refusée', r.ok === false && r.code === 'quota_exhausted' && r.next_reset, JSON.stringify(r));
  await as(ST2);
  check('D14 un autre étudiant garde son évaluation gratuite', (await quota()).remaining === 1);
  await as(ST1);
  // changement de mois : l'acceptation passe au mois précédent
  await sup();
  await db.exec(`update assessment_requests set accepted_at = _assessment_month_start(now()) - interval '2 days' where id = '${REQ3}'`);
  await as(ST1);
  qt = await quota();
  check('D15 changement de mois : quota remis à zéro', qt.used === 0 && qt.remaining === 1, JSON.stringify(qt));
  r = await req('mecanique', 'ecrit');
  check('D16 nouvelle évaluation gratuite possible le mois suivant', r.ok === true, JSON.stringify(r));
  const REQ4 = r.id;
  await sup();
  await db.exec(`update assessment_requests set accepted_at = _assessment_month_start(now()) where id = '${REQ3}'`);
  await as(ST1);
  check('D17 acceptation le 1er du mois (00:00 Douala) compte dans le mois courant', (await quota()).used === 1);
  await sup();
  await db.exec(`update assessment_requests set accepted_at = _assessment_month_start(now()) - interval '1 second' where id = '${REQ3}'`);
  await as(ST1);
  check('D18 une seconde avant minuit : mois précédent', (await quota()).used === 0);
  await as(ADM);
  await works('D19 la demande REQ4 est acceptée (consomme ce mois-ci)', `select assessment_request_ack('${REQ4}', 'acceptee')`);
  await fails('D20 une demande refusée n\'est plus modifiable', `select assessment_request_ack('${REQ1}', 'acceptee')`, /plus modifiable/);

  // ============================================================ E. Évaluations supplémentaires (prix = décision du propriétaire)
  await as(ST2);
  r = await req('mecanique', 'simulation', 'payee_candidat');
  check('E1 prix non décidé : évaluation supplémentaire INDISPONIBLE, non confirmée', r.ok === false && r.code === 'extra_unavailable' && /pas encore été décidé/.test(r.message), JSON.stringify(r));
  r = await req('mecanique', 'simulation', 'payee_candidat', '1000');
  check('E2 prix inventé par le client : toujours indisponible', r.ok === false && r.code === 'extra_unavailable');
  check('E3 aucune ligne créée', (await qs(`select count(*)::int n from assessment_requests where candidate_id = '${ST2}'`))[0].n === 0);
  await sup();
  await db.exec(`insert into platform_settings (key, value) values ('assessment.extra_price', '{"amount_xaf": 2500}'::jsonb)`);
  await as(ST2);
  qt = await quota();
  check('E4 prix décidé : annoncé par le serveur, paiement non en service', qt.extra.available === true && Number(qt.extra.price_xaf) === 2500 && qt.extra.payment_ready === false, JSON.stringify(qt.extra));
  r = await req('mecanique', 'simulation', 'payee_candidat');
  check('E5 prix annoncé non transmis : refus', r.ok === false && r.code === 'price_mismatch', JSON.stringify(r));
  r = await req('mecanique', 'simulation', 'payee_candidat', '1000');
  check('E6 prix annoncé différent : refus (prix réel renvoyé)', r.ok === false && r.code === 'price_mismatch' && Number(r.price_xaf) === 2500, JSON.stringify(r));
  check('E7 rien créé après refus de prix', (await qs(`select count(*)::int n from assessment_requests where candidate_id = '${ST2}'`))[0].n === 0);
  r = await req('mecanique', 'simulation', 'payee_candidat', '2500');
  check('E8 prix identique : enregistrée « paiement_requis », JAMAIS envoyée au fournisseur', r.ok === true && r.status === 'paiement_requis' && /pas encore en service/.test(r.message), JSON.stringify(r));
  const REQP = r.id;
  check('E9 la demande payante n\'a pas de fournisseur et ne consomme pas le quota gratuit', (await qs(`select provider_code is null as nop from assessment_requests where id = '${REQP}'`))[0].nop && (await quota()).remaining === 1);
  await as(ADM);
  await fails('E10 une demande en attente de paiement ne peut pas être acceptée par le fournisseur', `select assessment_request_ack('${REQP}', 'acceptee')`, /plus modifiable/);
  await sup();
  await db.exec(`update platform_settings set value = '"abc"'::jsonb where key = 'assessment.extra_price'`);
  await as(ST2);
  check('E11 réglage invalide : traité comme non décidé', (await quota()).extra.available === false);
  r = await req('mecanique', 'simulation', 'payee_candidat', '2500');
  check('E12 réglage invalide : demande payante refusée', r.ok === false && r.code === 'extra_unavailable');
  await sup();
  await db.exec(`delete from platform_settings where key = 'assessment.extra_price'`);
  check('E13 aucune dépendance candidature - évaluation (aucune clé étrangère entre les tables)',
    (await qs(`select count(*)::int n from information_schema.table_constraints c join information_schema.constraint_column_usage u on u.constraint_name = c.constraint_name
               where c.constraint_type = 'FOREIGN KEY' and ((c.table_name like 'assessment_%' and u.table_name in ('job_applications','applications','opportunity_applications','mission_proposals'))
                 or (c.table_name in ('job_applications','applications','opportunity_applications','mission_proposals') and u.table_name like 'assessment_%'))`))[0].n === 0);

  // ============================================================ F. Capacité : étudiant seul (vendeur non requis)
  await as(VEND);
  qt = await quota();
  check('F1 étudiant sans capacité vendeur : quota gratuit disponible', qt.eligible === true && qt.remaining === 1);
  r = await req('soudure', 'ecrit');
  check('F2 étudiant sans capacité vendeur : peut demander', r.ok === true, JSON.stringify(r));
  await as(CLI);
  qt = await quota();
  check('F3 client : quota gratuit non éligible', qt.eligible === false && qt.remaining === undefined, JSON.stringify(qt));
  await fails('F4 client : évaluation gratuite refusée', `select assessment_request('soudure', 'ecrit', true, 'gratuite_mensuelle', null, null)`, /réservée aux étudiants/);
  await as(ORG);
  await fails('F5 organisation : demande refusée', `select assessment_request('soudure', 'ecrit', true, 'gratuite_mensuelle', null, null)`, DENY);
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${ST2}'`);
  await as(ST2);
  await fails('F6 compte suspendu : demande refusée', `select assessment_request('soudure', 'ecrit', true, 'gratuite_mensuelle', null, null)`, DENY);
  await sup();
  await db.exec(`update profiles set suspended = false where id = '${ST2}'`);

  // ============================================================ G. Anonyme refusé
  await as(null, 'anon');
  for (const [n, sql] of [['familles', `select assessment_families()`], ['quota', `select assessment_quota()`], ['demande', `select assessment_request('soudure', 'ecrit', true, 'gratuite_mensuelle', null, null)`],
    ['liste', `select assessment_my_list()`], ['résultat', `select assessment_result('${id(99)}')`], ['contestation', `select assessment_dispute('${id(99)}', 'une raison suffisante')`],
    ['admin liste', `select assessment_providers_admin_list()`], ['activation', `select assessment_provider_set_status('prov_a', 'actif')`]]) {
    await fails(`G1 anonyme : ${n} refusé`, sql, /permission denied|Connexion requise|Réservé/i);
  }
  for (const t of ['assessment_families', 'assessment_providers', 'assessment_requests', 'assessment_results', 'assessment_disputes', 'assessment_campaigns', 'assessment_provider_tests', 'assessment_campaign_invites']) {
    await fails(`G2 anonyme : lecture de ${t} refusée`, `select * from ${t}`, /permission denied/i);
  }

  // ============================================================ H. Résultats, validation humaine, contestation, isolation
  await sup();
  const REQ_ST1 = (await q(`select id from assessment_requests where id = '${REQ4}'`))[0].id;
  await as(ADM);
  await fails('H1 résultat refusé tant que la demande n\'est pas acceptée', `select assessment_result_record('${REQP}', '{"limits":"x"}'::jsonb)`, /Aucun résultat avant l'acceptation/);
  const payload = JSON.stringify({
    competences: [{ name: 'Diagnostic de panne (analyse du dossier)', level: 'à confirmer', verifiable_remotely: true }, { name: 'Réglage manuel d\'un moteur', verifiable_remotely: false }],
    criteria: [{ name: 'Méthode' }], evidence: [{ kind: 'réponse écrite' }], details: { note: 'détail du banc de test' },
    limits: 'Évaluation à distance : le geste technique n\'a pas été observé.', recommendations: ['Faire valider le geste en présentiel'], validation_status: 'automatique' });
  const RES = (await q(`select assessment_result_record('${REQ_ST1}', '${payload.replace(/'/g, "''")}'::jsonb) r`))[0].r;
  check('H2 résultat enregistré', !!RES);
  check('H3 compétence non vérifiable à distance : validation humaine requise (forcée)', (await qs(`select validation_status from assessment_results where id = '${RES}'`))[0].validation_status === 'validation_humaine_requise');
  check('H4 la demande passe à « terminée »', (await qs(`select status from assessment_requests where id = '${REQ_ST1}'`))[0].status === 'terminee');
  await fails('H5 limites obligatoires', `insert into assessment_results (request_id, candidate_id, limits) values ('${REQP}', '${ST2}', '')`, /./);
  await as(ST1);
  const lst1 = (await q(`select assessment_my_list() r`))[0].r;
  check('H6 liste du candidat : ses demandes avec résultat et validation humaine', lst1.length === 4 && lst1.some((x) => x.result_id === RES && x.validation_status === 'validation_humaine_requise'), JSON.stringify(lst1.map((x) => x.status)));
  const res = (await q(`select assessment_result('${RES}') r`))[0].r;
  check('H7 résultat : compétences, critères, preuves, détails, limites, recommandations, contestation possible', res.competences.length === 2 && res.criteria.length === 1 && res.evidence.length === 1 && res.limits && res.recommendations.length === 1 && res.dispute_possible && res.human_validation_required === true, JSON.stringify(res));
  await as(ST2);
  await fails('H8 autre étudiant : résultat introuvable', `select assessment_result('${RES}')`, /introuvable/);
  await fails('H9 autre étudiant : contestation refusée', `select assessment_dispute('${RES}', 'je conteste un résultat qui n est pas le mien')`, /introuvable/);
  check('H10 autre étudiant : ne voit ni demandes ni résultats d\'autrui (RLS)', (await q(`select count(*)::int n from assessment_requests where candidate_id <> '${ST2}'`))[0].n === 0 && (await q(`select count(*)::int n from assessment_results`))[0].n === 0);
  check('H11 autre étudiant : sa liste ne contient pas la demande d\'autrui', (await q(`select assessment_my_list() r`))[0].r.every((x) => x.id !== REQ4));
  await as(CLI);
  check('H12 client : aucune demande visible', (await q(`select count(*)::int n from assessment_requests`))[0].n === 0);
  await as(ST1);
  await fails('H13 contestation : motif trop court refusé', `select assessment_dispute('${RES}', 'non')`, /10 à 2000/);
  const d = (await q(`select assessment_dispute('${RES}', 'Je conteste : le critère de méthode ne tient pas compte de mon dossier.') r`))[0].r;
  check('H14 contestation enregistrée', d.ok === true && d.id);
  await fails('H15 une seule contestation en cours par résultat', `select assessment_dispute('${RES}', 'Une deuxième contestation sur le même résultat.')`, /déjà en cours/);
  check('H16 le résultat expose la contestation et la liste son statut', (await q(`select assessment_result('${RES}') r`))[0].r.disputes[0].status === 'ouverte' && (await q(`select assessment_my_list() r`))[0].r.some((x) => x.dispute_status === 'ouverte'));
  check('H17 le candidat ne peut pas modifier ses données (écriture directe refusée)', await (async () => { try { await q(`update assessment_results set limits = 'x' where id = '${RES}'`); return (await qs(`select limits from assessment_results where id = '${RES}'`))[0].limits !== 'x'; } catch { return true; } })());
  await fails('H18 le candidat ne peut pas s\'attribuer une demande acceptée (insertion directe)', `insert into assessment_requests (candidate_id, family_code, mode, status, funding, consent, accepted_at) values ('${ST1}', 'mecanique', 'ecrit', 'acceptee', 'gratuite_mensuelle', true, now())`, /permission denied/i);
  await as(SUP);
  check('H19 agent support (support.disputes absent) : ne voit pas la contestation', (await q(`select count(*)::int n from assessment_disputes`))[0].n === 0);
  await as(ADM);
  check('H20 administrateur : voit la contestation et les demandes', (await q(`select count(*)::int n from assessment_disputes`))[0].n === 1 && (await q(`select count(*)::int n from assessment_requests`))[0].n >= 4);

  // ============================================================ I. Organisation : ses campagnes seulement
  await sup();
  const C1 = id(60), C2 = id(61);
  await db.exec(`insert into assessment_campaigns (id, org_id, title, family_code, mode, status) values ('${C1}', '${ORG}', 'Campagne soudeurs', 'soudure', 'ecrit', 'ouverte'), ('${C2}', '${ORG2}', 'Campagne mécanique', 'mecanique', 'simulation', 'ouverte');
    insert into assessment_campaign_invites (campaign_id, candidate_id) values ('${C1}', '${ST2}')`);
  await as(ST2);
  r = await req('soudure', 'ecrit', 'financee_organisation', 'null', true, `'${C2}'`);
  check('I1 campagne non invitée : refus', r.ok === false && r.code === 'campaign_invalid');
  r = await req('mecanique', 'ecrit', 'financee_organisation', 'null', true, `'${C1}'`);
  check('I2 famille/mode différents de la campagne : refus', r.ok === false && r.code === 'campaign_invalid');
  r = await req('soudure', 'ecrit', 'financee_organisation', 'null', true, `'${C1}'`);
  check('I3 candidat invité : demande financée par l\'organisation, sans quota gratuit ni prix', r.ok === true && r.status === 'envoyee', JSON.stringify(r));
  const REQ_ORG = r.id;
  check('I4 le quota gratuit du candidat n\'est pas touché', (await quota()).remaining === 1);
  await as(ADM);
  await q(`select assessment_request_ack('${REQ_ORG}', 'acceptee')`);
  await q(`select assessment_result_record('${REQ_ORG}', '{"limits":"Banc de test : évaluation écrite uniquement.","competences":[{"name":"Lecture de plans","verifiable_remotely":true}]}'::jsonb)`);
  await as(ORG);
  check('I5 organisation propriétaire : voit la demande de SA campagne', (await q(`select count(*)::int n from assessment_requests`))[0].n === 1);
  check('I6 organisation : voit le résultat de SA campagne seulement', (await q(`select count(*)::int n from assessment_results`))[0].n === 1);
  check('I7 organisation : voit sa campagne et pas celle d\'une autre', (await q(`select count(*)::int n from assessment_campaigns`))[0].n === 1);
  check('I8 organisation : ne voit pas les demandes gratuites des étudiants', (await q(`select count(*)::int n from assessment_requests where funding <> 'financee_organisation'`))[0].n === 0);
  await as(ORG2);
  check('I9 autre organisation : aucune demande, aucun résultat de la campagne d\'autrui', (await q(`select (select count(*) from assessment_requests) + (select count(*) from assessment_results) n`))[0].n == 0);
  await fails('I10 organisation : appel direct du RPC de résultats refusé', `select assessment_result_record('${REQ_ORG}', '{"limits":"x"}'::jsonb)`, DENY);
  await as(ORG);
  check('I11 organisation : pas d\'accès aux fournisseurs ni aux contestations', (await q(`select count(*)::int n from assessment_providers`))[0].n === 0 && (await q(`select count(*)::int n from assessment_disputes`))[0].n === 0);
  await sup();
  await db.exec(`update assessment_requests set share_with_org = false where id = '${REQ_ORG}'`);
  await as(ORG);
  check('I12 sans accord de partage : l\'organisation ne voit plus ni demande ni résultat', (await q(`select (select count(*) from assessment_requests) + (select count(*) from assessment_results) n`))[0].n == 0);

  // ============================================================ J. Familles évolutives et suspension
  await as(ADM);
  await works('J1 administrateur : ajoute une famille sans changement de structure', `select assessment_family_set('verrerie_art', 'Verrerie d''art', true, null)`);
  await works('J2 administrateur : désactive une famille', `select assessment_family_set('autres_metiers', 'Autres métiers et spécialités', false, null)`);
  await as(ST1);
  const fams2 = (await q(`select assessment_families() r`))[0].r;
  check('J3 34 familles - 1 désactivée = 33 actives, la nouvelle est visible', fams2.length === 33 && fams2.some((f) => f.code === 'verrerie_art') && !fams2.some((f) => f.code === 'autres_metiers'));
  r = await req('autres_metiers', 'ecrit');
  check('J4 famille désactivée : demande refusée', r.ok === false && r.code === 'unknown_family');
  await as(ADM);
  await works('J5 suspension du fournisseur', `select assessment_provider_set_status('prov_a', 'suspendu')`);
  await as(ST2);
  r = await req('mecanique', 'simulation');
  check('J6 fournisseur suspendu : refus sans consommation', r.ok === false && r.code === 'no_provider' && (await quota()).remaining === 1);
  await as(ADM);
  await works('J7 réactivation possible (dernier test réussi)', `select assessment_provider_set_status('prov_a', 'actif')`);
  await as(ADM);
  await works('J8 un test échoué suspend un fournisseur actif', `select assessment_provider_record_test('prov_a', false, 'régression')`);
  check('J9 statut suspendu après test échoué', (await q(`select status from assessment_providers where code = 'prov_a'`))[0].status === 'suspendu');

  // ============================================================ K. Rejeu de la migration (idempotence)
  await sup();
  const fs = await import('fs'); const path = await import('path'); const { fileURLToPath } = await import('url');
  const dir = path.dirname(fileURLToPath(import.meta.url));
  const f = '20261125095000_h9_eval_socle_fournisseur_agnostique.sql';
  try { await db.exec(fs.readFileSync(path.join(dir, '..', '..', 'migrations', f), 'utf8')); check('K1 migration rejouée sans erreur', true); } catch (e) { check('K1 migration rejouée sans erreur', false, e.message); }
  check('K2 le rejeu ne duplique ni ne réactive rien : 34 familles, 1 fournisseur', (await q(`select (select count(*) from assessment_families) = 34 and (select count(*) from assessment_providers) = 1 as okk`))[0].okk);

  console.log(`h9_evaluation : ${ok} OK, ${ko} ECHEC`);
  console.log(`${ok}/${ok + ko}`);
}

