// H13.1 lot ACTORS - parcours RESPONSABLE DE DEPARTEMENT sur la base PGlite rejouee, en vrais appels avec jwt claims par acteur et garde db_pre_request simulee.
// Deux departements (A = Informatique, B = Gestion) dans un meme etablissement : le responsable de A ne voit, ne lit et ne modifie QUE ce qui releve de A.
// Etapes : acces limite a son departement, etudiants autorises, projets et productions, validations (projets, annonces, certification), evenements et rapports,
// partenariats, isolation entre departements (refus croises, lectures directes de tables), refus des surfaces d'administration, compte non rattache, compte suspendu.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_parcours_departement.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 4);
  const { U, as, anon, sup, q, qs, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  const I1 = U(800), DA = U(801), DB = U(802);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Etablissement Departements', 'verified');
    insert into departments (id, institution_id, name, status) values ('${DA}', '${I1}', 'Informatique', 'verified'), ('${DB}', '${I1}', 'Gestion', 'verified')`);
  const ADM = await user(1, 'Ada Admin', 'admin');
  const HA = await user(2, 'Chef Informatique', 'dept');
  const HB = await user(3, 'Chef Gestion', 'dept');
  const H0 = await user(4, 'Chef Sans Rattachement', 'dept');
  const SA1 = await user(5, 'Aline Alpha MARKA', 'student');
  const SA2 = await user(6, 'Alain Alpha MARKA', 'student');
  const SB1 = await user(7, 'Boris Beta MARKB', 'student');
  const CLI = await user(8, 'Cora Cliente', 'client');
  const ORG = await user(9, 'Org Recruteur', 'company');
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${HA}', '${DA}'), ('${HB}', '${DB}');
    update profiles set institution_id='${I1}', department_id='${DA}', department='Informatique' where id in ('${HA}','${SA1}','${SA2}');
    update profiles set institution_id='${I1}', department_id='${DB}', department='Gestion' where id in ('${HB}','${SB1}');
    update profiles set phone='691400001', phone_verified=true, certification='approved', bio='bio MARKA' where id='${SA1}';
    update profiles set phone='691400002', phone_verified=true, certification='approved', bio='bio MARKB', skills='compta' where id='${SB1}';
    insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${SA1}', 'student_card', 'c.pdf', '${SA1}/c/c.pdf', 'application/pdf', 10, 'verified'), ('${SB1}', 'student_card', 'c.pdf', '${SB1}/c/c.pdf', 'application/pdf', 10, 'verified');
    insert into company_profiles (owner_id, company_name, status) values ('${ORG}', 'Org Recruteur', 'approved')`);
  const IMG = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/p.jpg';
  await db.exec(`insert into shops (owner_id, name, slug, status) values ('${SA1}', 'Boutique Alpha', 'boutique-alpha-p4', 'active'), ('${SB1}', 'Boutique Beta', 'boutique-beta-p4', 'active');
    insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) select '${SA1}', 'Lampe MARKA', 'Informatique', 'Maison', 5000, 3, 'pending', '{${IMG}}', id from shops where owner_id='${SA1}';
    insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) select '${SB1}', 'Lampe MARKB', 'Gestion', 'Maison', 5000, 3, 'pending', '{${IMG}}', id from shops where owner_id='${SB1}'`);
  const LA = (await qs(`select id from listings where title = 'Lampe MARKA'`))[0].id, LB = (await qs(`select id from listings where title = 'Lampe MARKB'`))[0].id;
  const detail = '{"domain":"agri","problem":"Arrosage manuel","solution":"Capteurs et pompe","progress":"prototype","contact_email":"a@b.cm"}';
  const mkProject = async (st, title, dept) => { await as(st); return (await q(`select project_save_full(null, 'projet', '${title}', 'Une description suffisamment longue pour publier ce projet.', '${dept}', '${detail}'::jsonb, '[]'::jsonb, 'public', true) id`))[0].id; };
  const PA = await mkProject(SA1, 'Projet MARKA serre', 'Informatique');
  const PB = await mkProject(SB1, 'Projet MARKB comptabilite', 'Gestion');
  await sup();

  // ---------------------------------------------------------------- 1. acces limite a son departement
  await as(HA);
  await works('D1 le responsable lit son departement', `select my_department() r`, (r) => JSON.stringify(r[0].r).includes('Informatique'));
  await works('D2 vue d\'ensemble de son departement', `select dept_overview() r`, (r) => r[0].r != null);
  await fails('D3 vue d\'ensemble d\'un AUTRE departement refusee', `select dept_overview('${DB}')`, /pas le vôtre/);
  await works('D4 son tableau de statistiques', `select dept_stats() r`);
  await anon();
  await fails('D5 anonyme : vue d\'ensemble refusee', `select dept_overview()`, /permission denied|Connexion requise/);
  await as(H0);
  await fails('D6 un responsable non rattache ne lit aucune vue d\'ensemble', `select dept_overview()`, /rattaché à aucun département/);
  await works('D7 ... et sa liste d\'etudiants est vide', `select dept_students() r`, (r) => r[0].r.length === 0);
  await as(SA1);
  await fails('D8 un etudiant n\'accede pas a la vue d\'ensemble du departement', `select dept_overview()`, /non autorisée/);
  await as(CLI);
  await fails('D9 un client n\'accede pas a la liste des etudiants du departement', `select dept_students_list()`, /non autorisée/);
  await as(ORG);
  await fails('D10 une organisation n\'accede pas aux rapports de departement', `select dept_report('synthese')`, /non autorisée/);

  // ---------------------------------------------------------------- 2. etudiants autorises
  await as(HA);
  const sl = (await works('E1 liste des etudiants de son departement', `select dept_students_list('', 50, 0) r`, (r) => r[0].r.rows.length >= 2))?.[0]?.r ?? [];
  const slTxt = JSON.stringify(sl);
  check('E2 elle contient ses etudiants (SA1, SA2) et aucun etudiant de l\'autre departement', slTxt.includes(SA1) && slTxt.includes(SA2) && !slTxt.includes(SB1) && !slTxt.includes('MARKB'), slTxt.slice(0, 250));
  check('E3 aucun telephone ni e-mail dans la liste', !slTxt.includes('69140000') && !slTxt.includes('h131-4-'), slTxt.slice(0, 250));
  await works('E4 fiche detaillee d\'un de ses etudiants', `select dept_student_detail('${SA1}') d`, (r) => JSON.stringify(r[0].d).includes('Aline') && !JSON.stringify(r[0].d).includes('69140000'));
  await fails('E5 fiche d\'un etudiant d\'un autre departement refusee', `select dept_student_detail('${SB1}')`, /introuvable dans ce département/);
  await works('E6 lecture directe des profils : aucun etudiant de l\'autre departement', `select id from profiles where role = 'student'`, (r) => !r.some((x) => x.id === SB1));
  await as(HB);
  await works('E7 le responsable de B ne voit que ses etudiants', `select dept_students_list('', 50, 0) r`, (r) => JSON.stringify(r[0].r).includes(SB1) && !JSON.stringify(r[0].r).includes(SA1));
  await fails('E8 ... et pas la fiche d\'un etudiant de A', `select dept_student_detail('${SA1}')`, /introuvable dans ce département/);

  // ---------------------------------------------------------------- 3. projets et productions
  await as(HA);
  await works('P1 projets soumis de son departement', `select dept_projects() r`, (r) => JSON.stringify(r[0].r).includes('Projet MARKA serre') && !JSON.stringify(r[0].r).includes('MARKB'));
  await fails('P2 type de projet inconnu refuse', `select dept_projects('autre')`, /Type inconnu/);
  await as(HB);
  await fails('P3 le responsable de B ne valide pas le projet de A', `select review_project('${PA}', true, '')`, /autre département/);
  await works('P4 ... et ne voit pas les projets de A', `select dept_projects() r`, (r) => !JSON.stringify(r[0].r).includes('MARKA'));
  await as(SA1);
  await fails('P5 un etudiant ne valide pas son propre projet', `select review_project('${PA}', true, '')`, DENY);
  await as(HA);
  await works('P6 son responsable valide le projet de son departement', `select review_project('${PA}', true, '') r`, (r) => r[0].r === 'approved');
  await works('P7 mise en avant du projet valide', `select dept_highlight_set('project', '${PA}', 'Belle realisation') r`, (r) => r[0].r === true);
  await fails('P8 mise en avant d\'un projet de B refusee', `select dept_highlight_set('project', '${PB}')`, /de votre département/);
  const pr = (await works('P9 production creee', `select production_create('Production Alpha MARKA', 'Equipe A', null, null) r`))?.[0]?.r;
  const prId = pr?.id ?? pr;
  await works('P10 ses productions sont listees', `select staff_productions() r`, (r) => JSON.stringify(r[0].r).includes('Production Alpha MARKA'));
  await works('P11 mise a jour d\'avancement', `select production_update('${prId}', 40, 'en_cours') r`);
  await as(HB);
  await works('P12 le responsable de B ne voit pas les productions de A', `select staff_productions() r`, (r) => !JSON.stringify(r[0].r).includes('MARKA'));
  await fails('P13 ... ne les modifie pas', `select production_update('${prId}', 100, 'terminee')`, DENY);
  await noEffect('P14 ... ni en ecriture directe', `update productions set progress = 100 where id = '${prId}' returning id`);
  await as(SA1);
  await fails('P15 un etudiant ne cree pas de production', `select production_create('Fausse production', 'x', null, null)`, DENY);
  await as(HA);
  check('P16 avancement de la production inchange par les refus', (await qs(`select progress from productions where id = '${prId}'`))[0].progress === 40);

  // ---------------------------------------------------------------- 4. validations de contenus de son perimetre
  await as(HA);
  await works('V1 file de validation des annonces : celle de son etudiant seulement', `select listing_review_queue() r`, (r) => JSON.stringify(r[0].r).includes('Lampe MARKA') && !JSON.stringify(r[0].r).includes('MARKB'));
  await noEffect('V2 annonce d\'un autre departement : validation impossible (RLS)', `update listings set status = 'approved' where id = '${LB}' returning id`);
  await works('V3 annonce de son departement : validation', `update listings set status = 'approved' where id = '${LA}' returning id`, (r) => r.length === 1);
  await as(SA1);
  await works('V4 l\'etudiant est notifie de la validation de son annonce', `select title from notifications where kind = 'listing'`, (r) => r.some((n) => n.title === 'Annonce validée'));
  await works('V5 l\'etudiant est notifie de la validation de son projet', `select title from notifications where kind = 'project'`, (r) => r.some((n) => /Projet/.test(n.title)));
  await as(SB1);
  await works('V6 l\'etudiant de B n\'a recu aucune notification de A', `select id from notifications where title in ('Annonce validée', 'Projet accepté')`, (r) => r.length === 0);
  await as(HA);
  const iv = (await works('V7 demande de validation institutionnelle a l\'administration', `select institutional_validation_request('other', 'Convention de stage MARKA', 'Details de la convention', '${DA}', null) r`))?.[0]?.r;
  await works('V8 ses demandes de validation sont listees', `select institutional_validations_list('pending', 50) r`, (r) => JSON.stringify(r[0].r).includes('Convention de stage MARKA'));
  await as(HB);
  await works('V9 le responsable de B ne voit pas les demandes de A', `select institutional_validations_list('pending', 50) r`, (r) => !JSON.stringify(r[0].r).includes('MARKA'));
  await works('V10 une demande de B vise toujours B (le departement passe en parametre est ignore)', `select institutional_validation_request('other', 'Intrusion visant A', 'x', '${DA}', null) r`, (r) => !!r[0].r);
  check('V10b ... et n\'apparait jamais dans la file de A', (await qs(`select count(*)::int n from institutional_validations where title = 'Intrusion visant A' and department_id = '${DA}'`))[0].n === 0);
  await as(HA);
  await fails('V11 le responsable ne decide pas lui-meme de sa demande', `select institutional_validation_decide('${iv?.id ?? iv}', true, 'ok')`, DENY);
  await as(ADM);
  await works('V12 l\'administrateur decide de la demande', `select institutional_validation_decide('${iv?.id ?? iv}', true, 'Valide') r`);
  await qs(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${SA2}', 'student_card', 'c.pdf', '${SA2}/c/c.pdf', 'application/pdf', 10, 'pending')`);
  await as(SA2);
  await works('V14 l\'etudiant demande la certification de son compte', `select submit_certification_request('Etudiant en L2, je souhaite publier', 'https://exemple.cm/a2') r`);
  await as(HB);
  await fails('V15 le responsable de B ne certifie pas un etudiant de A', `select decide_certification('${SA2}', 'approved', 'hors perimetre')`, DENY);
  await as(HA);
  await works('V16 le responsable de A certifie son etudiant', `select decide_certification('${SA2}', 'approved', 'Inscrit') r`);

  // ---------------------------------------------------------------- 5. evenements et rapports
  await as(HA);
  const ev = (await works('EV1 evenement cree par le departement', `select event_create('Journee portes ouvertes Informatique', 'Presentation des filieres', 'conference', now() + interval '10 days', now() + interval '10 days 3 hours', 'Amphi A', 0, 50) r`))?.[0]?.r;
  const evId = ev?.id ?? ev;
  await works('EV2 ses evenements geres', `select events_managed() r`, (r) => JSON.stringify(r[0].r).includes('Journee portes ouvertes'));
  await as(HB);
  await works('EV3 le responsable de B ne gere pas les evenements de A', `select events_managed() r`, (r) => !JSON.stringify(r[0].r).includes('portes ouvertes'));
  await fails('EV4 ... ne le modifie pas', `select event_update('${evId}', 'Detourne', '', 'conference', now() + interval '11 days', null, 'x', 0, 10)`, /Événement introuvable/);
  await fails('EV5 ... ne l\'annule pas', `select event_cancel('${evId}', 'Annulation sauvage')`, DENY);
  await fails('EV6 ... ne lit pas ses inscrits', `select event_registrants('${evId}')`, DENY);
  await as(SA1);
  await fails('EV7 un etudiant ne cree pas d\'evenement', `select event_create('Evenement etudiant', '', 'atelier', now() + interval '5 days', null, 'x', 0, 10)`, /non autorisée/);
  await works('EV8 l\'etudiant s\'inscrit a l\'evenement gratuit', `select event_register('${evId}') r`);
  await as(HA);
  await works('EV9 l\'organisateur voit l\'inscrit', `select event_registrants('${evId}') r`, (r) => r[0].r.length === 1);
  await works('EV10 il modifie la date de l\'evenement (inscrits prevenus)', `select event_update('${evId}', 'Journee portes ouvertes Informatique', 'Presentation', 'conference', now() + interval '12 days', null, 'Amphi B', 0, 50) r`);
  for (const k of ['synthese', 'etudiants', 'projets', 'competences']) await works(`RP ${k} : rapport de son departement`, `select dept_report('${k}') r`, (r) => r[0].r != null);
  await works('RP5 le rapport de synthese ne contient que son departement', `select dept_report('etudiants') r`, (r) => !JSON.stringify(r[0].r).includes('MARKB') && !JSON.stringify(r[0].r).includes('Boris'));
  await fails('RP6 rapport inconnu refuse', `select dept_report('secret')`, /Rapport inconnu/);
  await fails('RP7 rapport d\'un autre departement refuse', `select dept_report('synthese', null, null, '${DB}')`, /pas le vôtre/);
  await as(HB);
  await works('RP8 le responsable de B ne lit que ses etudiants dans son rapport', `select dept_report('etudiants') r`, (r) => !JSON.stringify(r[0].r).includes('Aline') && !JSON.stringify(r[0].r).includes('MARKA'));

  // ---------------------------------------------------------------- 6. partenariats, identite : refus croises
  await as(HA);
  const part = (await works('PT1 partenariat enregistre', `select dept_partnership_save('{"partner_name":"Orange Cameroun MARKA","kind":"stage","status":"actif","contact_email":"rh@orange.cm","students":12}'::jsonb) id`))?.[0]?.id;
  await works('PT2 identite du departement', `select dept_identity_save('{"description":"Formation en genie logiciel MARKA","contact_email":"gl@iut.cm"}'::jsonb) r`);
  await as(HB);
  await works('PT3 le responsable de B ne lit pas les partenariats de A', `select dept_partnerships() r`, (r) => !JSON.stringify(r[0].r).includes('MARKA'));
  await fails('PT4 ... ni en visant A', `select dept_partnerships('${DA}')`, /pas le vôtre/);
  await fails('PT5 ... ne supprime pas un partenariat de A', `select dept_partnership_delete('${part}')`, DENY);
  await fails('PT6 ... n\'ecrit pas l\'identite de A', `select dept_identity_save('{"description":"detournee"}'::jsonb, '${DA}')`, /pas le vôtre/);
  await fails('PT7 ... n\'invite personne dans A', `select dept_invite_create('${DA}', 'intrus@t.cm', 'Responsable', 7)`, DENY);
  await as(SA1);
  await fails('PT8 un etudiant n\'ecrit pas de partenariat', `select dept_partnership_save('{"partner_name":"Intrus"}'::jsonb)`, /non autorisée/);

  // ---------------------------------------------------------------- 7. isolation par lecture directe de toutes les tables sensibles (marque MARKB hors de A)
  await as(HA);
  const mark = async (name, sql) => { const r = JSON.stringify(await q(sql)); check(name, !r.includes('MARKB') && !r.includes('691400002'), r.slice(0, 200)); };
  await mark('I1 lecture directe des profils : aucune marque de B', `select name, bio, phone from profiles`);
  await mark('I2 lecture directe des annonces', `select title from listings`);
  await mark('I3 lecture directe des projets', `select title, summary from projects`);
  await mark('I4 lecture directe des boutiques', `select name from shops`);
  await mark('I5 productions et evenements geres', `select staff_productions() a, events_managed() b`);
  await mark('I6 documents d\'etudiants : aucune piece de B', `select name, path from user_documents`);
  await mark('I7 fonctions de liste du departement', `select dept_students_list('', 50, 0) a, dept_projects(null, null, 100, null) b, dept_partnerships(null) c, staff_mentors() d, staff_productions() e`);
  await noEffect('I8 ecriture sur un profil de B sans effet', `update profiles set name = 'Piratage' where id = '${SB1}' returning id`);
  await noEffect('I9 ecriture sur un projet de B sans effet', `update projects set title = 'Piratage' where id = '${PB}' returning id`);
  check('I10 donnees de B intactes', (await qs(`select (select name from profiles where id='${SB1}') n, (select title from projects where id='${PB}') t`)).every((r) => r.n.includes('MARKB') && r.t.includes('MARKB')));

  // ---------------------------------------------------------------- 8. surfaces d'administration refusees au responsable
  await as(HA);
  await fails('AD1 le responsable ne publie pas de classement', `select ranking_publish('2026-01')`, DENY);
  await fails('AD2 le responsable n\'accede pas aux commandes de l\'administration', `select admin_orders(10)`, DENY);
  await fails('AD3 il ne decide pas d\'une organisation', `select company_decide('${ORG}', true)`, /Réservé à l'administrateur/);
  await fails('AD4 il ne modifie pas les reglages', `select setting_set('maintenance', 'true'::jsonb)`, DENY);
  await fails('AD5 il n\'affecte pas un autre compte de departement', `select admin_dept_assign('${H0}', '${DA}', 'Responsable')`, DENY);
  await fails('AD6 il ne change pas le role d\'un compte', `select admin_set_account('${SA1}', 'admin', false)`, DENY);
  await fails('AD7 il ne decide pas d\'une valorisation financiere (paiement)', `select payment_set_status('${U(500)}', 'confirmed')`, /Action non autorisée|permission denied|réservé|Réservé/i);

  // ---------------------------------------------------------------- 9. garde de requete : compte suspendu
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${HB}'`);
  await as(HB);
  await fails('S1 responsable suspendu : ecriture refusee par la garde', `select production_create('Production suspendue', 'x', null, null)`, /Compte suspendu/);
  await fails('S2 responsable suspendu : vue d\'ensemble refusee', `select dept_overview()`, /Compte suspendu|non autorisée|Action non autorisée/);

  await b.replayMigrations();
  await as(HA);
  await works('R1 apres rejeu : le cloisonnement tient', `select dept_students_list('', 50, 0) r`, (r) => !JSON.stringify(r[0].r).includes('MARKB'));
  b.summary('h131_parcours_departement');
}



