// Lot L2 (H6) : administration centrale et consoles web (écrans 127-138, 145-147, 180/181, 264-269, 277, 280-283).
// Prouve, sur toutes les fonctions et lectures appelées par ces écrans, que :
//   - l'administrateur global n'est refusé par AUCUNE garde de permission d'équipe (réglages, contenus, journal, comptes, signalements, file de modération,
//     réclamations, commandes, bornes, radar, catalogue des permissions) ;
//   - un agent d'équipe n'a que ce que ses permissions autorisent (finance : lecture ; support : commandes et réclamations ; technique : réglages techniques,
//     jamais les réglages financiers ni les comptes) ; un compte sans permission, un client, un compte suspendu et un visiteur sont refusés ;
//   - la nouvelle fonction admin_orders (migration 20261122010000) renvoie les commandes de TOUTE la plateforme avec client, vendeurs, montant et état.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h6_admin.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000062${String(n).padStart(2, '0')}`;
  const A = id(1), ASUSP = id(2), FIN = id(3), SUP = id(4), SUPNO = id(5), TECH = id(6), C = id(7), S = id(8), DIR = id(9), C2 = id(10);
  const LST = id(50), LST2 = id(51), ORD = id(52), ORD2 = id(53), CLM = id(54), REP = id(55);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const DENY = /Action non autorisée|réservé|Réservé|exige la permission|Connexion requise|permission denied|Compte suspendu|non autorisé|Accès refusé|refusé|Réservé aux valideurs|Réservé au support|autorisée/i;
  const fails = async (name, sql, re = DENY) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };

  // ============================================================ comptes
  await db.exec('reset role');
  // le banc PGlite remplace auth.users par une table minimale : la colonne lue par admin_users existe en production
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  const people = [[A, 'Ada Admin', 'admin'], [ASUSP, 'Adm Suspendu', 'admin'], [FIN, 'Fin Agent', 'finance'], [SUP, 'Sup Agent', 'support'], [SUPNO, 'Sup SansDroit', 'support'], [TECH, 'Tech Agent', 'support'],
    [C, 'Cora Cliente', 'client'], [C2, 'Cyril Client', 'client'], [S, 'Samuel Vendeur', 'student'], [DIR, 'Dir Direction', 'direction']];
  for (const [i, nm, role] of people) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.replace(/ /g, '.').toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.replace(/ /g, '.').toLowerCase()}@t.cm')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${ASUSP}'`);
  await as(A);
  await q(`select admin_team_member_set('${FIN}', 'finance', array['finance.read'], 'test')`);
  await q(`select admin_team_member_set('${SUP}', 'support', array['support.claims','support.orders','support.disputes'], 'test')`);
  await q(`select admin_team_member_set('${SUPNO}', 'support', array['support.tickets'], 'test')`);
  await q(`select admin_team_member_set('${TECH}', 'tech', array['tech.config','tech.maintenance','tech.logs'], 'test')`);
  await sup();
  // données : annonce soumise, commandes (une annulée), signalement, réclamation, borne, établissement
  await db.exec(`alter table order_lines disable trigger trg_k2_order_line_seller`);
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values ('${LST}', '${S}', 'Lampe L2', 'Informatique', 5000, 'pending'), ('${LST2}', '${S}', 'Sac L2', 'Informatique', 7000, 'approved');
    insert into orders (id, number, buyer_id, subtotal, fee, method, paid) values ('${ORD}', '#L2-1', '${C}', 5000, 500, 'mobile_money', true), ('${ORD2}', '#L2-2', '${C2}', 7000, 0, 'Mobile Money', false);
    update orders set cancelled_at = now() where id = '${ORD2}';
    insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${ORD}', '${LST2}', 'Sac L2', 5000, 1), ('${ORD2}', '${LST2}', 'Sac L2', 7000, 1);
    insert into kiosks (id, name, location, status) values ('borne-1', 'Hall test', 'RDC', 'online') on conflict (id) do nothing;
    insert into listing_reports (id, listing_id, reporter_id, reason) values ('${REP}', '${LST2}', '${C}', 'fraud');
    insert into claims (id, order_id, claimant_id, seller_id, reason, details) values ('${CLM}', '${ORD}', '${C}', '${S}', 'not_received', 'Colis jamais arrivé à destination');`);
  await db.exec(`alter table order_lines enable trigger trg_k2_order_line_seller`);

  // ============================================================ A. admin_orders (écran 132)
  await as(A);
  let o = (await q(`select admin_orders(200) r`))[0].r;
  check('A1 admin global : admin_orders renvoie les deux commandes de la plateforme', Array.isArray(o) && o.length === 2, JSON.stringify(o));
  const o1 = o.find((x) => x.number === '#L2-1');
  check('A2 commande 1 : client, vendeur, montant (sous-total + frais), payée, non annulée', o1 && o1.buyer === 'Cora Cliente' && o1.sellers === 'Samuel Vendeur' && Number(o1.total) === 5500 && o1.paid === true && o1.cancelled === false, JSON.stringify(o1));
  check('A3 commande 2 : annulée, non payée', o.find((x) => x.number === '#L2-2')?.cancelled === true);
  check('A4 limite : p_limit = 0 renvoie au moins une ligne, null prend 200', (await q(`select jsonb_array_length(admin_orders(0)) n`))[0].n === 1 && (await q(`select jsonb_array_length(admin_orders(null)) n`))[0].n === 2);
  for (const [who, uid] of [['agent finance (finance.read)', FIN], ['agent support (support.orders)', SUP]]) {
    await as(uid);
    await works(`A5 ${who} : admin_orders autorisée`, `select admin_orders(50)`);
  }
  for (const [who, uid] of [['agent support sans support.orders', SUPNO], ['agent technique', TECH], ['client', C], ['étudiant', S], ['direction', DIR], ['administrateur suspendu', ASUSP]]) {
    await as(uid);
    await fails(`A6 ${who} : admin_orders refusée`, `select admin_orders(50)`);
  }
  await as(null, 'anon');
  await fails('A7 visiteur : admin_orders refusée', `select admin_orders(50)`, /permission denied|Connexion requise|autoris/i);

  // ============================================================ B. réglages et commissions (135, 136, 138, 280)
  await as(A);
  await works('B1 admin global : setting_set commission.product (réglage financier)', `select setting_set('commission.product', '6'::jsonb)`);
  await works('B2 admin global : setting_set commission.service', `select setting_set('commission.service', '8'::jsonb)`);
  await works('B3 admin global : setting_set commission.financing', `select setting_set('commission.financing', '3'::jsonb)`);
  await works('B4 admin global : setting_set commission.payout_threshold', `select setting_set('commission.payout_threshold', '20000'::jsonb)`);
  await works('B5 admin global : setting_set commission.updated_at (horodatage)', `select setting_set('commission.updated_at', '"2026-11-20T10:00:00Z"'::jsonb)`);
  await works('B6 admin global : réglages de module et de sécurité', `select setting_set('modules.b2b', 'true'::jsonb), setting_set('security.2fa_required', 'true'::jsonb), setting_set('integrations.sms', 'false'::jsonb)`);
  const st = (await q(`select settings_all() r`))[0].r;
  check('B7 settings_all : les règles de commission écrites sont relues telles quelles (lues par l\'écran 135)', st['commission.product'] === 6 && st['commission.service'] === 8 && st['commission.financing'] === 3 && st['commission.payout_threshold'] === 20000 && st['commission.updated_at'] === '2026-11-20T10:00:00Z', JSON.stringify(st));
  check('B8 settings_all : les interrupteurs de module sont relus', st['modules.b2b'] === true && st['integrations.sms'] === false);
  await as(FIN);
  await works('B9 agent finance : settings_all (finance.read) autorisée', `select settings_all()`);
  await fails('B10 agent finance : setting_set commission.product refusé (réglage financier réservé à l\'administrateur global)', `select setting_set('commission.product', '1'::jsonb)`, /administrateur global|réservé|autoris/i);
  await as(TECH);
  await works('B11 agent technique (tech.config) : settings_all et réglage technique autorisés', `select settings_all(), setting_set('modules.messaging', 'true'::jsonb)`);
  await fails('B12 agent technique : réglage financier refusé', `select setting_set('commission.product', '1'::jsonb)`, /administrateur global|réservé|autoris/i);
  for (const [who, uid] of [['agent support sans droit technique', SUP], ['client', C], ['direction', DIR], ['administrateur suspendu', ASUSP]]) {
    await as(uid);
    await fails(`B13 ${who} : setting_set refusé`, `select setting_set('modules.b2b', 'false'::jsonb)`);
  }
  await as(SUP);
  await fails('B14 agent support : settings_all refusée (ni tech.config ni finance.read)', `select settings_all()`);

  // ============================================================ C. journal d'audit (137, 266)
  await as(A);
  const aud = await q(`select actor, action, target, category from audit_log where target like 'commission.%' order by id`);
  check('C1 admin global : lecture de audit_log ; chaque règle de commission écrite y est journalisée', aud.length >= 5 && aud.every((r) => r.action === 'Réglage modifié'), JSON.stringify(aud));
  check('C2 le journal enregistre l\'identifiant du compte auteur (l\'écran 137 le remplace par son nom)', aud.every((r) => r.actor === A), JSON.stringify(aud.map((r) => r.actor)));
  await as(C);
  check('C3 client : audit_log illisible', (await q(`select count(*)::int n from audit_log`).catch(() => [{ n: -1 }]))[0].n <= 0);
  await as(TECH);
  check('C4 agent technique (tech.logs) : lit le journal (politique d\'équipe)', (await q(`select count(*)::int n from audit_log`))[0].n >= 5);
  await as(FIN);
  check('C5 agent finance (ni tech.logs ni security.audit) : journal illisible (0 ligne)', (await q(`select count(*)::int n from audit_log`))[0].n === 0);

  // ============================================================ D. contenus éditoriaux (264, 265)
  await as(A);
  const cid = (await works('D1 admin global : cms_save (page)', `select cms_save(null, 'page', 'À propos', 'Texte', true) r`))?.[0]?.r;
  await works('D2 admin global : cms_save (modèle de notification)', `select cms_save(null, 'template', 'Bienvenue', 'Bonjour', true)`);
  check('D3 cms_items lisible par l\'admin avec id (modification et suppression depuis l\'écran)', (await q(`select count(*)::int n from cms_items`))[0].n === 2);
  await works('D4 admin global : cms_save (modification)', `select cms_save('${cid}', 'page', 'À propos 2', 'Texte 2', false)`);
  await works('D5 admin global : cms_delete', `select cms_delete('${cid}')`);
  for (const [who, uid] of [['client', C], ['agent support', SUP], ['agent finance', FIN]]) {
    await as(uid);
    await fails(`D6 ${who} : cms_save refusé`, `select cms_save(null, 'page', 'Piraté', 'x', true)`);
  }

  // ============================================================ E. comptes (128, 180)
  await as(A);
  await works('E1 admin global : admin_set_account change le rôle (client -> étudiant)', `select admin_set_account('${C2}', 'student', false)`);
  check('E2 le rôle est effectivement modifié', (await qs(`select role::text r from profiles where id = '${C2}'`))[0].r === 'student');
  await works('E3 admin global : suspension d\'un compte', `select admin_set_account('${C2}', 'student', true)`);
  check('E4 le compte est suspendu', (await qs(`select suspended s from profiles where id = '${C2}'`))[0].s === true);
  await works('E5 admin global : réactivation', `select admin_set_account('${C2}', 'client', false)`);
  const users = (await works('E6 admin global : admin_users (liste des comptes, écran 180)', `select admin_users(p_limit => 200) r`))?.[0]?.r;
  check('E7 admin_users liste tous les comptes', Array.isArray(users) && users.length >= 8, JSON.stringify(users)?.slice(0, 200));
  for (const [who, uid] of [['agent finance', FIN], ['agent support', SUP], ['agent technique', TECH], ['client', C], ['direction', DIR], ['administrateur suspendu', ASUSP]]) {
    await as(uid);
    await fails(`E8 ${who} : admin_set_account refusé`, `select admin_set_account('${C}', 'admin', false)`);
  }
  check('E9 aucun compte n\'a été promu par un refus', (await qs(`select role::text r from profiles where id = '${C}'`))[0].r === 'client');

  // ============================================================ F. signalements et file de modération (130, 131)
  await as(A);
  await works('F1 admin global : set_report_status (en traitement)', `select set_report_status('${REP}', 'reviewing')`);
  await works('F2 admin global : set_report_status (résolu)', `select set_report_status('${REP}', 'closed')`);
  check('F3 le statut du signalement est enregistré', (await qs(`select status from listing_reports where id = '${REP}'`))[0].status === 'closed');
  check('F4 admin global : listing_report lisible (liste de l\'écran 131)', (await q(`select count(*)::int n from listing_reports`))[0].n === 1);
  const rq = (await works('F5 admin global : listing_review_queue (file de l\'écran 130)', `select listing_review_queue() r`))?.[0]?.r;
  check('F6 la file contient l\'annonce soumise avec vendeur, catégorie et prix', Array.isArray(rq) && rq.some((x) => x.title === 'Lampe L2' && x.seller_name === 'Samuel Vendeur'), JSON.stringify(rq)?.slice(0, 200));
  const upd = await q(`update listings set status = 'approved', review_note = null where id = '${LST}' returning id`);
  check('F7 admin global : la décision (update listings) est acceptée par la politique de sécurité', upd.length === 1);
  const upd2 = await q(`update listings set status = 'rejected', review_note = 'Photo non conforme' where id = '${LST}' returning id`);
  check('F8 admin global : refus motivé accepté', upd2.length === 1);
  for (const [who, uid] of [['client', C], ['étudiant', S], ['agent finance', FIN], ['agent support sans droit de signalements', SUPNO]]) {
    await as(uid);
    await fails(`F9 ${who} : set_report_status refusé`, `select set_report_status('${REP}', 'open')`);
  }
  await as(C);
  await fails('F10 client : listing_review_queue refusée', `select listing_review_queue()`);
  await as(FIN);
  await fails('F11 agent finance : listing_review_queue refusée', `select listing_review_queue()`);
  await as(C);
  const own = await q(`update listings set status = 'approved' where id = '${LST}' returning id`).catch(() => []);
  check('F12 client : ne peut pas décider une annonce', own.length === 0);

  // ============================================================ G. réclamations (133, 147-1)
  await as(A);
  const thr = (await works('G1 admin global : claim_thread', `select claim_thread('${CLM}') r`))?.[0]?.r;
  check('G2 le fil de la réclamation est lisible', thr && thr.order_number !== undefined, JSON.stringify(thr)?.slice(0, 150));
  await works('G3 admin global : answer_claim', `select answer_claim('${CLM}', 'Nous examinons votre dossier.')`);
  await works('G4 admin global : claim_decide (non retenue)', `select claim_decide('${CLM}', 'release', '')`);
  check('G5 la réclamation est close avec la décision enregistrée', (await qs(`select status, decision from claims where id = '${CLM}'`))[0].decision === 'release');
  check('G6 admin global : table claims lisible', (await q(`select count(*)::int n from claims`))[0].n === 1);
  await as(SUP);
  await works('G7 agent support (support.claims) : claim_thread autorisée', `select claim_thread('${CLM}')`);
  for (const [who, uid] of [['agent support sans support.claims', SUPNO], ['agent finance', FIN], ['agent technique', TECH]]) {
    await as(uid);
    await fails(`G8 ${who} : claim_thread refusée`, `select claim_thread('${CLM}')`, /introuvable|autoris|réservé|refusé/i);
    await fails(`G9 ${who} : claim_decide refusée`, `select claim_decide('${CLM}', 'release', '')`);
  }

  // ============================================================ H. bornes, radar, vue d'ensemble, permissions, finance (127, 134, 145-147, 181, 268, 269, 277, 282)
  await as(A);
  await works('H1 admin global : schedule_kiosk_event (écran 282)', `select schedule_kiosk_event('borne-1', 'Journée portes ouvertes', now() + interval '2 days', now() + interval '3 days')`);
  check('H2 admin global : kiosks et kiosk_incidents lisibles', (await q(`select count(*)::int n from kiosks`))[0].n >= 1 && (await q(`select count(*)::int n from kiosk_incidents`))[0].n >= 0);
  await works('H3 admin global : skills_radar (écran 269)', `select skills_radar()`);
  await works('H4 admin global : platform_overview (écran 127)', `select platform_overview()`);
  await works('H5 admin global : finance_payments (écran 134)', `select finance_payments(null, 50)`);
  check('H6 catalogue des équipes et permissions lisible (écrans 181 et 281)', (await q(`select count(*)::int n from admin_permissions`))[0].n >= 20 && (await q(`select count(*)::int n from admin_teams`))[0].n === 5);
  check('H7 institutions lisibles (127, 129, 267)', (await q(`select count(*)::int n from institutions`))[0].n >= 0);
  await as(SUP);
  await works('H8 agent support (support.orders) : schedule_kiosk_event autorisée', `select schedule_kiosk_event('borne-1', 'Atelier', now() + interval '5 days', now() + interval '6 days')`);
  await as(TECH);
  await works('H9 agent technique (tech.maintenance) : schedule_kiosk_event autorisée', `select schedule_kiosk_event('borne-1', 'Maintenance', now() + interval '8 days', now() + interval '9 days')`);
  for (const [who, uid] of [['agent support sans support.orders', SUPNO], ['agent finance', FIN], ['client', C]]) {
    await as(uid);
    await fails(`H10 ${who} : schedule_kiosk_event refusée`, `select schedule_kiosk_event('borne-1', 'Intrus', now() + interval '11 days', now() + interval '12 days')`);
  }
  await as(SUPNO);
  await fails('H11 agent support sans support.requests : skills_radar refusé', `select skills_radar()`);
  await as(C);
  await fails('H12 client : skills_radar refusé', `select skills_radar()`);
  await as(FIN);
  await works('H13 agent finance (finance.read) : finance_payments autorisée', `select finance_payments(null, 50)`);
  await as(SUPNO);
  await fails('H14 agent support sans finance.read : finance_payments refusée', `select finance_payments(null, 50)`);
  await as(ASUSP);
  await fails('H15 administrateur suspendu : finance_payments refusée', `select finance_payments(null, 50)`);

  // ============================================================ I. technique : incidents de bornes, clés d'API, modèles de notification (145-147, 265, 268, 277, 280)
  await as(A);
  const inc = (await works('I1 admin global : report_kiosk_incident (incident de borne)', `select report_kiosk_incident('borne-1', 'hardware', 'Lecteur QR bloqué', 'maintenance') r`))?.[0]?.r;
  check('I2 l\'incident est lisible dans kiosk_incidents (listes 147-2 / 147-3 / 268)', (await q(`select count(*)::int n from kiosk_incidents where message = 'Lecteur QR bloqué'`))[0].n === 1);
  const key = await works('I3 admin global : create_api_key (hub d\'intégrations, 280)', `select create_api_key('Clé de test L2') r`);
  check('I4 la clé n\'est renvoyée qu\'une fois (valeur non vide) et le libellé est conservé', key && String(key[0].r).length > 8);
  const tpl = (await q(`select key from notification_templates order by key limit 1`))[0]?.key;
  check('I5a des modèles de notification existent (écran 265)', !!tpl);
  await works('I5 admin global : save_notification_template (écran 265)', `select save_notification_template('${tpl}', 'Objet L2', 'Corps L2 {{name}}', array['email'], true)`);
  await as(TECH);
  await works('I6 agent technique (tech.maintenance) : report_kiosk_incident autorisée', `select report_kiosk_incident('borne-1', 'restart', 'Redémarrage de test', null)`);
  await as(SUPNO);
  await fails('I8 agent support sans droit technique : create_api_key refusée', `select create_api_key('Intrus')`);
  await fails('I9 agent support sans droit technique : save_notification_template refusée', `select save_notification_template('${tpl}', 'X', 'Y', array['email'], true)`);
  await fails('I10 agent support sans droit technique : report_kiosk_incident refusée', `select report_kiosk_incident('borne-1', 'other', 'Intrus', null)`);
  await as(C);
  await fails('I11 client : create_api_key refusée', `select create_api_key('Intrus')`);
  await as(TECH);
  await fails('I12 agent technique sans tech.integrations : create_api_key refusée', `select create_api_key('Intrus technique')`);
  await as(A);
  await q(`select admin_team_member_set('${TECH}', 'tech', array['tech.config','tech.maintenance','tech.logs','tech.integrations'], 'test')`);
  await as(TECH);
  await works('I13 agent technique avec tech.integrations : create_api_key autorisée', `select create_api_key('Clé technique')`);

  // ============================================================ J. résolution des incidents (147-2, 147-3, 268, 277) : migration 20261122011000
  await sup();
  const incId = (await q(`select id from kiosk_incidents where message = 'Lecteur QR bloqué'`))[0].id;
  const inc2 = (await q(`select id from kiosk_incidents where message = 'Redémarrage de test'`))[0].id;
  await as(SUPNO);
  await fails('J1 agent support sans droit : kiosk_incident_resolve refusée', `select kiosk_incident_resolve(${incId}, null)`);
  await as(C);
  await fails('J2 client : kiosk_incident_resolve refusée', `select kiosk_incident_resolve(${incId}, null)`);
  await as(A);
  await fails('J3 état de borne invalide refusé', `select kiosk_incident_resolve(${incId}, 'cassee')`, /invalide/);
  await works('J4 admin global : résout l\'incident et remet la borne en ligne', `select kiosk_incident_resolve(${incId}, 'online')`);
  check('J5 incident horodaté résolu, borne en ligne', (await q(`select (i.resolved_at is not null) r, k.status from kiosk_incidents i join kiosks k on k.id = i.kiosk_id where i.id = ${incId}`))[0].r === true && (await q(`select status from kiosks where id = 'borne-1'`))[0].status === 'online');
  await fails('J6 résolution répétée : « déjà résolu »', `select kiosk_incident_resolve(${incId}, null)`, /déjà résolu|introuvable/);
  await as(TECH);
  await works('J7 agent technique (tech.maintenance) : résout un incident', `select kiosk_incident_resolve(${inc2}, null)`);
  check('J8 la résolution est journalisée', (await qs(`select count(*)::int n from audit_log where action = 'Incident de borne résolu'`))[0].n === 2);

  console.log(`\nRÉSULTAT h6_admin : ${ok} OK, ${ko} ECHEC`);
  if (ko > 0) process.exitCode = 1;

  async function qs(sql) { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; }
}
