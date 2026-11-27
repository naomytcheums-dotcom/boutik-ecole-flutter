// H13.1 lot ACTORS - parcours ADMINISTRATEUR / PROPRIETAIRE sur la base PGlite rejouee, en vrais appels avec jwt claims par acteur et garde db_pre_request simulee.
// Etapes : gestion des utilisateurs et des roles, equipes (permissions fines), moderation (publications, boutiques, annonces, signalements), organisations et departements,
// commandes et incidents (reclamation), journal d'audit (lecture, immuabilite), parametres et integrations (reglages, cles d'API, sante, limites de debit),
// suspension / levee / revocation de sessions, tableaux de bord (donnees reelles du banc, jamais un 0 trompeur), double authentification (garde aal2).
// Aucun paiement n'est confirme : les tableaux financiers affichent 0 encaisse tant qu'aucune commande n'est payee.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_parcours_admin.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 5);
  const { U, as, anon, sup, q, qs, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  const I1 = U(800), D1 = U(801), D2 = U(802);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Etablissement Admin', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I1}', 'Gestion', 'verified')`);
  const ADM = await user(1, 'Ada Admin', 'admin');
  const SUP = await user(2, 'Sam Support', 'support');
  const FIN = await user(3, 'Fin Finance', 'finance');
  const DH = await user(4, 'Chef Informatique', 'dept');
  const SEL = await user(5, 'Awa Vendeuse', 'student', `update profiles set phone='691500005', phone_verified=true, certification='approved', institution_id='${I1}', department_id='${D1}', department='Informatique' where id='${U(5)}'`);
  const CLI = await user(6, 'Cora Cliente', 'client');
  const CLI2 = await user(7, 'Denis Client', 'client');
  const ORG = await user(8, 'Org En Attente', 'company');
  const VIC = await user(9, 'Compte A Suspendre', 'client');
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${SEL}', 'student_card', 'c.pdf', '${SEL}/c/c.pdf', 'application/pdf', 10, 'verified');
    insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name, contact_role) values ('${ORG}', 'Org En Attente', 'pending', 'Commerce', 'Douala', '690000000', 'M. Biya', 'DG');
    insert into auth.sessions (user_id) values ('${VIC}'), ('${VIC}'), ('${CLI2}');
    insert into shops (owner_id, name, slug, status) values ('${SEL}', 'Boutique Awa Admin', 'boutique-awa-admin', 'active')`);
  const IMG = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/l.jpg';
  await db.exec(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) select '${SEL}', 'Lampe Admin', 'Informatique', 'Maison', 9000, 4, 'approved', '{${IMG}}', id from shops where owner_id='${SEL}'`);
  const LST = (await qs(`select id from listings where title = 'Lampe Admin'`))[0].id;
  // commande a la livraison confirmee par l'acheteur : aucun argent n'est encaisse
  await as(CLI);
  const ord = (await q(`select marketplace_checkout('[{"id":"${LST}","qty":1}]'::jsonb, false, 'Paiement à la livraison') r`))[0].r;
  await q(`select confirm_cod_order('${ord.number}')`);
  const ord2 = (await q(`select marketplace_checkout('[{"id":"${LST}","qty":1}]'::jsonb, false, 'Mobile Money') r`))[0].r;
  await as(SEL);
  await q(`select set_seller_order_status('${ord.number}', 1)`);
  await q(`select set_seller_order_status('${ord.number}', 2)`);
  await q(`select set_seller_order_status('${ord.number}', 3)`);
  await sup();
  await as(SEL);
  const pr = (await q(`select create_post_v2('Publication a moderer MODMARK', '[]'::jsonb, null, '{}', null, null) id`))[0].id;
  const post = pr?.id ?? pr;

  // ---------------------------------------------------------------- 1. acces a l'administration : seul l'administrateur
  await as(ADM);
  await works('A1b ... et il est reconnu administrateur', `select my_admin_access() r`, (r) => r[0].r.is_admin === true);
  for (const [who, uid] of [['client', CLI], ['etudiant', SEL], ['departement', DH]]) {
    await as(uid);
    await fails(`A2 ${who} : aucune commande d'administration`, `select admin_orders(10)`, DENY);
    await fails(`A3 ${who} : pas de reglages d'administration`, `select setting_set('maintenance', 'false'::jsonb)`, DENY);
    await fails(`A4 ${who} : pas de changement de role`, `select admin_set_account('${CLI2}', 'admin', false)`, DENY);
    await works(`A5 ${who} : pas de droits d'administration`, `select my_admin_access() r`, (r) => r[0].r.is_admin !== true);
  }
  await anon();
  await fails('A6 anonyme : liste des utilisateurs refusee', `select admin_users()`, /permission denied|Connexion requise/);
  await fails('A7 anonyme : journal d\'audit non lisible', `select * from audit_log`, /permission denied/);

  // ---------------------------------------------------------------- 2. gestion des utilisateurs et des roles
  await as(ADM);
  const users = (await works('U1 liste des utilisateurs : donnees reelles du banc', `select admin_users(null, 100) r`, (r) => r[0].r.length >= 9))?.[0]?.r ?? [];
  check('U2 la liste contient les comptes crees par le test', ['Awa Vendeuse', 'Cora Cliente', 'Org En Attente'].every((n) => users.some((u) => u.name === n)));
  await works('U3 filtre par role (clients)', `select admin_users(array['client'], 100) r`, (r) => r[0].r.length === 3 && r[0].r.every((u) => u.role === 'client'));
  await works('U4 l\'administrateur promeut un client en Support (equipe)', `select admin_set_account('${CLI2}', 'support', false) r`);
  check('U5 le role a change', (await qs(`select role::text r from profiles where id = '${CLI2}'`))[0].r === 'support');
  await works('U6 puis le retablit client', `select admin_set_account('${CLI2}', 'client', false) r`);
  await fails('U7 un role inconnu est refuse', `select admin_set_account('${CLI2}', 'superman', false)`, /./);
  await as(SUP);
  await fails('U8 le support ne change pas de role', `select admin_set_account('${CLI2}', 'admin', false)`, DENY);
  await as(CLI);
  await noEffect('U9 un client ne s\'auto-promeut pas (ecriture directe)', `update profiles set role = 'admin' where id = '${CLI}' returning id`);
  check('U10 le client est resté client', (await qs(`select role::text r from profiles where id = '${CLI}'`))[0].r === 'client');
  await as(ADM);
  await works('U11 equipes : un support avec permissions fines', `select admin_team_member_set('${SUP}', 'support', array['support.claims','support.orders'], 'Agent de mediation') r`);
  await works('U12 equipes : une finance en lecture seule', `select admin_team_member_set('${FIN}', 'finance', array['finance.read'], 'Lecture des tableaux') r`);
  await works('U13 apercu des equipes', `select admin_teams_overview() r`, (r) => r[0].r != null);
  await as(SUP);
  await fails('U14 un agent ne modifie pas les equipes', `select admin_team_member_set('${FIN}', 'finance', array['finance.payments'], 'Escalade de droits')`, DENY);
  await as(FIN);
  await fails('U15 la finance en lecture seule ne valide pas de paiement', `select payment_set_status('${U(500)}', 'confirmed')`, /Action non autorisée|exige la permission|Réservé/i);

  // ---------------------------------------------------------------- 3. moderation
  await as(CLI);
  await works('MO1 un client signale une publication', `select report_post('${post}', 'Contenu douteux') r`);
  await as(CLI2);
  await fails('MO2 un client ne modere pas une publication', `select moderate_post('${post}', false, 'x')`, DENY);
  await as(SUP);
  await fails('MO3 un agent sans security.moderation ne modere pas', `select moderate_post('${post}', false, 'x')`, DENY);
  await as(ADM);
  await works('MO4 l\'administrateur retire la publication', `select moderate_post('${post}', false, 'Contenu non conforme') r`);
  await as(CLI2);
  await works('MO5 elle n\'est plus visible des autres comptes', `select id from posts where id = '${post}'`, (r) => r.length === 0);
  await as(SEL);
  await works('MO6 l\'auteur est notifie du retrait', `select title from notifications where kind = 'post'`, (r) => r.some((n) => /masqu|retir/i.test(n.title)));
  await as(ADM);
  await works('MO7 l\'administrateur suspend une boutique', `select shop_decide((select id from shops where owner_id = '${SEL}'), 'suspend', 'Controle qualite') r`);
  await anon();
  check('MO8 la boutique est suspendue', (await qs(`select status from shops where owner_id = '${SEL}'`))[0].status === 'suspended');
  await works('MO8b les annonces de la boutique suspendue ne sont plus proposees au public', `select marketplace_search('Lampe Admin') r`, (r) => !JSON.stringify(r[0].r).includes('Lampe Admin'));
  await as(SEL);
  await fails('MO9 la vendeuse ne reactive pas sa boutique', `select shop_decide((select id from shops where owner_id = '${SEL}'), 'approve')`, DENY);
  await as(ADM);
  await works('MO10 l\'administrateur retablit la boutique', `select shop_decide((select id from shops where owner_id = '${SEL}'), 'restore') r`);

  // ---------------------------------------------------------------- 4. organisations et departements
  await as(ADM);
  await works('OR1 la file de verification des organisations', `select company_queue() r`, (r) => r[0].r.length === 1);
  await as(DH);
  await fails('OR2 un responsable de departement ne decide pas d\'une organisation', `select company_decide('${ORG}', true)`, /Réservé à l'administrateur/);
  await as(ADM);
  await fails('OR3 refus sans motif impossible', `select company_decide('${ORG}', false, '')`, /motif/);
  await works('OR4 refus motive d\'une organisation', `select company_decide('${ORG}', false, 'Pieces illisibles') r`);
  await as(ORG);
  await works('OR5 l\'organisation est notifiee du refus', `select title from notifications where kind = 'company_review'`, (r) => r.length >= 1);
  await as(ADM);
  await works('OR6 departements : liste d\'administration', `select admin_departments() r`, (r) => JSON.stringify(r[0].r).includes('Informatique'));
  await works('OR7 rattachement d\'un responsable a un departement', `select admin_dept_assign('${DH}', '${D1}', 'Responsable') r`);
  await as(DH);
  await works('OR8 le responsable accede a son departement', `select my_department() r`, (r) => JSON.stringify(r[0].r).includes('Informatique'));
  await as(ADM);
  await works('OR9 retrait du rattachement', `select admin_dept_unassign('${DH}') r`);
  await as(DH);
  await fails('OR10 sans rattachement : plus d\'acces au departement', `select dept_overview()`, /rattaché à aucun département/);

  // ---------------------------------------------------------------- 5. commandes et incidents
  await as(ADM);
  const ao = (await works('CM1 liste des commandes de la plateforme (donnees du banc)', `select admin_orders(50) r`, (r) => JSON.stringify(r[0].r).includes(ord.number) && JSON.stringify(r[0].r).includes(ord2.number)))?.[0]?.r;
  await as(CLI);
  const cl = (await works('CM2 le client ouvre une reclamation sur sa commande', `select submit_claim('${ord.number}', 'not_received', 'Je n''ai rien recu du tout depuis une semaine') r`))?.[0]?.r;
  const claimId = cl?.id ?? cl;
  await as(CLI2);
  await works('CM3 un autre client ne voit pas la reclamation', `select id from claims`, (r) => r.length === 0);
  await fails('CM4 un autre client ne la decide pas', `select claim_decide('${claimId}', 'release', 'x')`, /Réservé à l'équipe de médiation/);
  await as(SUP);
  await works('CM5 l\'agent de mediation (support.claims) voit la reclamation', `select id from claims`, (r) => r.length === 1);
  await fails('CM6 l\'agent sans permission de remboursement ne rembourse pas', `select claim_decide('${claimId}', 'refund', 'Remboursement demande par le client')`, /Remboursement impossible|permission|Action non autorisée|exige/);
  await as(ADM);
  await fails('CM6b meme l\'administrateur ne rembourse pas une commande payee en especes a la livraison', `select claim_decide('${claimId}', 'refund', 'Remboursement demande par le client')`, /Remboursement impossible/);
  await works('CM7 l\'administrateur clot la reclamation (liberation)', `select claim_decide('${claimId}', 'release', 'Colis livre selon le suivi') r`);
  await fails('CM8 decision deja prise', `select claim_decide('${claimId}', 'release', 'Encore')`, /déjà clôturée/);
  await as(CLI);
  await works('CM9 le client voit la decision', `select status from claims`, (r) => r.length === 1 && r[0].status === 'closed');
  await as(SEL);
  await fails('CM10 la vendeuse ne decide pas de la reclamation', `select claim_decide('${claimId}', 'refund', 'Je rembourse moi-meme')`, /Réservé à l'équipe de médiation/);

  // ---------------------------------------------------------------- 6. parametres et integrations
  await as(ADM);
  await works('PA1 lecture des reglages', `select settings_all() r`, (r) => r[0].r != null);
  await works('PA2 modification d\'un reglage', `select setting_set('maintenance', 'false'::jsonb) r`);
  await works('PA3 sante des services', `select admin_service_health() r`, (r) => r[0].r != null);
  await works('PA4 limites de debit : liste', `select admin_rpc_rate_limits_list() r`, (r) => r[0].r != null);
  const key = (await works('PA5 creation d\'une cle d\'API de test', `select create_api_key('Cle du banc de test') r`))?.[0]?.r;
  check('PA6 la cle n\'est jamais reaffichee en clair par la table', !(JSON.stringify(await qs(`select * from api_keys`)).includes(typeof key === 'string' ? key : '__rien__')));
  await as(SUP);
  await fails('PA7 un agent ne change pas de reglage', `select setting_set('maintenance', 'true'::jsonb)`, DENY);
  await fails('PA8 un agent ne cree pas de cle d\'API', `select create_api_key('Cle pirate')`, DENY);
  await as(CLI);
  await fails('PA9 un client ne lit pas les reglages sensibles', `select admin_service_health()`, DENY);
  await as(ADM);
  await works('PA10 l\'administrateur exporte le journal d\'audit (CSV)', `select admin_export_csv('audit', '{}'::jsonb) r`, (r) => r[0].r != null);
  await works('PA10b ... et les rattachements (administrateur seul)', `select admin_export_csv('rattachements', '{}'::jsonb) r`, (r) => r[0].r != null);
  await as(CLI);
  await fails('PA11 un client n\'exporte rien', `select admin_export_csv('audit', '{}'::jsonb)`, DENY);

  // ---------------------------------------------------------------- 7. suspension, levee, revocation
  await as(ADM);
  check('S0 le compte a suspendre a 2 sessions ouvertes', (await qs(`select count(*)::int n from auth.sessions where user_id = '${VIC}'`))[0].n === 2);
  await works('S1 l\'administrateur suspend le compte', `select admin_set_account('${VIC}', 'client', true) r`);
  check('S2 le profil est suspendu et les sessions fermees', (await qs(`select (select suspended from profiles where id = '${VIC}') s, (select count(*)::int from auth.sessions where user_id = '${VIC}') n`)).every((r) => r.s === true && r.n === 0));
  await as(VIC);
  await fails('S3 le compte suspendu ne peut plus ecrire (garde de requete)', `select marketplace_checkout('[{"id":"${LST}","qty":1}]'::jsonb, false, 'Mobile Money')`, /Compte suspendu/);
  await fails('S4 ... ni ecrire en direct', `insert into favorites (user_id, listing_id) values ('${VIC}', '${LST}')`, /Compte suspendu/);
  await as(ADM);
  await works('S5 levee de la suspension', `select admin_set_account('${VIC}', 'client', false) r`);
  await as(VIC);
  await works('S6 le compte retrouve ses droits', `insert into favorites (user_id, listing_id) values ('${VIC}', '${LST}') returning listing_id`);
  await as(ADM);
  check('S7 sessions de Denis (avant revocation) : 1', (await qs(`select count(*)::int n from auth.sessions where user_id = '${CLI2}'`))[0].n === 1);
  await works('S8 revocation des sessions d\'un compte (sans suspension)', `select admin_account_sessions_revoke('${CLI2}', 'Appareil perdu signale par le titulaire') r`);
  check('S9 sessions revoquees, compte non suspendu', (await qs(`select (select count(*)::int from auth.sessions where user_id = '${CLI2}') n, (select suspended from profiles where id = '${CLI2}') s`)).every((r) => r.n === 0 && r.s === false));
  await as(CLI);
  await fails('S10 un client ne revoque pas les sessions d\'autrui', `select admin_account_sessions_revoke('${CLI2}', 'x')`, DENY);
  await fails('S11 un client ne suspend personne', `select admin_set_account('${CLI2}', 'client', true)`, DENY);

  // ---------------------------------------------------------------- 8. journal d'audit
  await as(ADM);
  const au = (await works('AU1 le journal d\'audit est lisible par l\'administrateur', `select action, category, actor from audit_log`, (r) => r.length >= 3)) ?? [];
  const acts = au.map((x) => x.action).join('|');
  check('AU2 les actions de ce parcours sont journalisees (organisation refusee, moderation...)', /Organisation|Publication|Boutique|Compte|Rôle|Réclamation|Litige|Signalement/i.test(acts), acts.slice(0, 300));
  await as(CLI);
  await noEffect('AU3 un client ne lit aucune ligne du journal', `select id from audit_log`);
  await as(SEL);
  await noEffect('AU4 la vendeuse ne lit pas le journal', `select id from audit_log`);
  await as(ADM);
  await noEffect('AU5 meme l\'administrateur ne supprime pas le journal (ecriture directe sans effet ou refusee)', `delete from audit_log returning id`);
  await noEffect('AU6 ... ni ne le modifie', `update audit_log set action = 'efface' returning id`);
  check('AU7 le journal est intact apres les tentatives', (await qs(`select count(*)::int n from audit_log`))[0].n >= au.length);

  // ---------------------------------------------------------------- 9. tableaux de bord : donnees reelles
  await as(ADM);
  await works('TB1 finance : aucun encaissement tant qu\'aucune commande n\'est payee (0 reel, pas simule)', `select finance_overview() r`, (r) => r[0].r.collected === 0 && r[0].r.orders_paid === 0);
  await works('TB2 argent sous sequestre : lecture', `select money_admin_overview() r`, (r) => r[0].r != null);
  await works('TB3 qualite des donnees', `select admin_data_quality() r`, (r) => r[0].r != null);
  await works('TB4 indicateurs nationaux du classement', `select admin_ranking_national_indicators() r`);
  await works('TB5 les commandes du banc sont comptees', `select count(*)::int n from orders`, (r) => r[0].n === 2);
  await as(FIN);
  await works('TB6 la finance (lecture) lit le tableau financier', `select finance_overview() r`, (r) => r[0].r.collected === 0);
  await as(CLI);
  await fails('TB7 un client ne lit pas le tableau financier', `select finance_overview()`, DENY);
  await as(SUP);
  await fails('TB8 le support (sans finance.read) ne lit pas le tableau financier', `select finance_overview()`, DENY);

  // ---------------------------------------------------------------- 10. double authentification : les operations sensibles exigent aal2
  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${ADM}', 'verified')`);
  await as(ADM, 'authenticated', 'aal1');
  await fails('MF1 administrateur en session aal1 avec 2FA : reglage refuse', `select setting_set('maintenance', 'false'::jsonb)`, /double authentification/);
  await fails('MF2 ... changement de role refuse', `select admin_set_account('${CLI2}', 'client', false)`, /double authentification/);
  await works('MF3 ... lecture de la liste des utilisateurs toujours possible', `select admin_users(null, 5) r`);
  await as(ADM, 'authenticated', 'aal2');
  await works('MF4 session aal2 : reglage accepte', `select setting_set('maintenance', 'false'::jsonb) r`);

  await b.replayMigrations();
  await as(ADM);
  await works('R1 apres rejeu : les droits d\'administration sont intacts', `select my_admin_access() r`, (r) => r[0].r.is_admin === true);
  b.summary('h131_parcours_admin');
}





