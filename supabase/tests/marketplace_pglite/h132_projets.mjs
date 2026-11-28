// H13.2 agent 4 : projets, missions, candidatures, certificats. L'etat change reellement cote serveur ET les deux cotes (etudiant / departement ou organisation) lisent le meme statut ;
// un certificat n'existe (et n'est donc affichable) que s'il a ete emis cote serveur ; revocation visible partout.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_projets.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 8);
  const { U, as, anon, sup, q, qs, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  const I1 = U(800), DA = U(801);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Etablissement Parcours', 'verified'); insert into departments (id, institution_id, name, status) values ('${DA}', '${I1}', 'Informatique', 'verified')`);
  const ADM = await user(1, 'Ada Admin', 'admin');
  const HA = await user(2, 'Chef Informatique', 'dept');
  const S1 = await user(3, 'Alice Talent', 'student');
  const S2 = await user(4, 'Bob Autre', 'student');
  const O = await user(5, 'Orange Test', 'company');
  const O2 = await user(6, 'Autre Corp', 'company');
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${HA}', '${DA}');
    update profiles set institution_id='${I1}', department_id='${DA}', department='Informatique' where id in ('${HA}','${S1}','${S2}');
    update profiles set phone='69016'||right(id::text,4), phone_verified=true, certification='approved', skills='Flutter, Dart' where id in ('${S1}','${S2}');
    insert into company_profiles (owner_id, company_name, status, sector, city) values ('${O}', 'Orange Test', 'approved', 'Telecoms', 'Douala'), ('${O2}', 'Autre Corp', 'approved', 'Conseil', 'Yaounde')`);
  for (const s of [S1, S2]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${s}', 'student_card', 'c.pdf', '${s}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  const emailOf = async (id) => (await qs(`select email from profiles where id = '${id}'`))[0].email;
  const notifs = async (uid, kind) => qs(`select title from notifications where user_id = '${uid}' and kind = '${kind}'`);

  // ---------------------------------------------------------------- 1. projet : soumission, refus, nouvelle soumission, validation
  const detail = '{"domain":"agri","problem":"Arrosage manuel","solution":"Capteurs et pompe","progress":"prototype","contact_email":"a@b.cm"}';
  await as(S1);
  const pid = (await works('PJ1 l\'etudiant soumet un projet public', `select project_save_full(null, 'projet', 'Serre connectee MARQPROJ', 'Une description suffisamment longue pour publier ce projet.', 'Informatique', '${detail}'::jsonb, '[]'::jsonb, 'public', true) id`))?.[0]?.id;
  const mine = async (id) => (await qs(`select status, review_note from projects where id = '${id}'`))[0];
  check('PJ2 etat serveur : le projet est soumis (pas valide)', (await mine(pid)).status === 'submitted', JSON.stringify(await mine(pid)));
  await anon();
  await works('PJ3 anonyme : un projet soumis n\'est pas public', `select public_projects() r`, (r) => !JSON.stringify(r[0].r).includes('MARQPROJ'));
  await as(S2);
  await works('PJ4 un autre etudiant ne lit pas le projet soumis', `select id from projects where id = '${pid}'`, (r) => r.length === 0);
  await as(HA);
  const dp = async () => { const r = (await q(`select dept_projects() r`))[0].r; return (Array.isArray(r) ? r : r.rows ?? r.items ?? []).find((x) => x.id === pid); };
  const seen = await dp();
  check('PJ5 le departement voit le projet avec le meme statut que l\'etudiant', !!seen && seen.status === 'submitted', JSON.stringify(seen));
  await fails('PJ6 refus sans motif : rejete', `select review_project('${pid}', false, '')`, /./);
  await works('PJ7 le departement refuse avec un motif', `select review_project('${pid}', false, 'Precisez le budget') r`, (r) => r[0].r === 'rejected');
  check('PJ8 etat serveur : refuse + motif conserve', (await mine(pid)).status === 'rejected' && (await mine(pid)).review_note === 'Precisez le budget', JSON.stringify(await mine(pid)));
  check('PJ9 le departement lit le meme statut', (await dp())?.status === 'rejected');
  await as(S1);
  check('PJ10 l\'etudiant est notifie du refus', (await notifs(S1, 'project')).length === 1);
  await works('PJ11 l\'etudiant corrige et soumet a nouveau', `select project_save_full('${pid}', 'projet', 'Serre connectee MARQPROJ', 'Une description suffisamment longue et corrigee pour publier ce projet.', 'Informatique', '${detail}'::jsonb, '[]'::jsonb, 'public', true) id`);
  check('PJ12 etat serveur : de nouveau soumis', (await mine(pid)).status === 'submitted', JSON.stringify(await mine(pid)));
  await as(HA);
  await works('PJ13 le departement valide', `select review_project('${pid}', true, '') r`, (r) => r[0].r === 'approved');
  check('PJ14 etat serveur et vue departement identiques : valide', (await mine(pid)).status === 'approved' && (await dp())?.status === 'approved');
  await anon();
  await works('PJ15 anonyme : le projet valide devient public', `select public_projects() r`, (r) => JSON.stringify(r[0].r).includes('MARQPROJ'));
  await as(S1);
  check('PJ16 l\'etudiant est notifie de la validation (2 notifications au total)', (await notifs(S1, 'project')).length === 2);

  // ---------------------------------------------------------------- 2. certificat : n'existe que s'il est emis cote serveur
  const em1 = await emailOf(S1);
  await as(S1);
  await works('CE1 avant emission : aucun certificat pour l\'etudiant', `select code from certificates where holder_id = '${S1}'`, (r) => r.length === 0);
  await works('CE2 avant emission : le passeport n\'annonce aucun certificat', `select talent_passport('${S1}') r`, (r) => !JSON.stringify(r[0].r.badges).includes('certificates'));
  await fails('CE3 l\'etudiant ne s\'emet pas de certificat', `select issue_certificate('project', 'Serre connectee MARQPROJ', '${em1}', 'Alice', 'Informatique')`, /Émission réservée/);
  await works('CE4 refus : aucun certificat cree', `select code from certificates where holder_id = '${S1}'`, (r) => r.length === 0);
  await as(HA);
  const code = (await works('CE5 le departement emet le certificat', `select issue_certificate('project', 'Serre connectee MARQPROJ', '${em1}', 'Alice', 'Informatique') c`))?.[0]?.c;
  await fails('CE6 pas de doublon valide', `select issue_certificate('project', 'Serre connectee MARQPROJ', '${em1}', 'Alice', 'Informatique')`, /existe déjà/);
  await as(S1);
  await works('CE7 l\'etudiant lit exactement ce certificat, avec le meme code', `select code, revoked from certificates where holder_id = '${S1}'`, (r) => r.length === 1 && r[0].code === code && r[0].revoked === false);
  check('CE8 l\'etudiant est notifie une fois', (await notifs(S1, 'certificate')).length === 1);
  await works('CE9 le passeport annonce 1 certificat', `select talent_passport('${S1}') r`, (r) => JSON.stringify(r[0].r.badges).includes('"certificates"'));
  await as(S2);
  await works('CE10 un autre etudiant ne voit pas ce certificat', `select code from certificates where code = '${code}'`, (r) => r.length === 0);
  await anon();
  await works('CE11 verification publique par code : valide', `select verify_certificate('${code}') r`, (r) => r[0].r.valide === true && !JSON.stringify(r[0].r).includes(S1));
  await works('CE12 un code inexistant n\'est pas valide', `select verify_certificate('BE-CERT-0000000000000000') r`, (r) => r[0].r.valide === false && r[0].r.introuvable === true);
  await as(HA);
  await works('CE13 le departement revoque', `select revoke_certificate('${code}', 'Erreur de saisie') r`);
  await as(S1);
  await works('CE14 l\'etudiant voit la revocation (meme etat serveur)', `select revoked from certificates where holder_id = '${S1}'`, (r) => r.length === 1 && r[0].revoked === true);
  await works('CE15 le passeport ne compte plus le certificat revoque', `select talent_passport('${S1}') r`, (r) => !JSON.stringify(r[0].r.badges).includes('"certificates"'));
  await anon();
  await works('CE16 verification publique apres revocation : invalide', `select verify_certificate('${code}') r`, (r) => r[0].r.valide === false && r[0].r.statut === 'revoque');

  // ---------------------------------------------------------------- 3. candidature : meme statut des deux cotes
  await as(O);
  const need = `select opp_save('Orange Test', 'stage', 'academique', 'Stagiaire Flutter MARQOPP', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', current_date + 10, array['Flutter'], 'Description complete de l offre pour les etudiants', array['Developper des ecrans','Tester'], 'Etudiant motive', 'Informatique', 'L3', array['Transport'], '', true, '', false) id`;
  const opp = (await works('OP1 l\'organisation publie une offre', need))?.[0]?.id;
  await as(ADM);
  await works('OP2 l\'administrateur valide l\'offre', `select opp_decide('${opp}', true, true) r`);
  await as(S1);
  const app = (await works('OP3 l\'etudiant candidate', `select opp_apply('${opp}', 'Je suis tres motivee pour ce stage de developpement Flutter', 'https://cv.exemple.cm/alice') id`))?.[0]?.id;
  const stud = async () => (await q(`select opp_my_applications() r`))[0].r.find((x) => x.id === app || x.application_id === app || x.opportunity_id === opp || x.opp_id === opp);
  const org = async () => { await as(O); const r = (await q(`select opp_applications_for('${opp}') r`))[0].r; await as(S1); return r.find((x) => x.id === app || x.application_id === app); };
  const s0 = await stud(), o0 = await org();
  check('OP4 les deux cotes voient la candidature avec le meme statut initial', !!s0 && !!o0 && s0.status === o0.status, `${s0?.status} / ${o0?.status}`);
  await as(O2);
  await fails('OP5 une autre organisation ne decide pas', `select opp_application_decide('${app}', 'hired')`, DENY);
  await as(O);
  await works('OP6 l\'organisation presélectionne', `select opp_application_decide('${app}', 'shortlisted') r`);
  await as(S1);
  check('OP7 etat serveur identique des deux cotes : shortlisted', (await stud())?.status === 'shortlisted' && (await org())?.status === 'shortlisted');
  await as(O);
  await works('OP8 l\'organisation retient le candidat', `select opp_application_decide('${app}', 'hired') r`);
  await as(S1);
  check('OP9 etat serveur identique des deux cotes : hired', (await stud())?.status === 'hired' && (await org())?.status === 'hired');
  const after = (await qs(`select count(*)::int n from notifications where user_id = '${S1}' and data::text like '%${app}%'`))[0].n;
  check('OP10 l\'etudiant est notifie des decisions sur sa candidature (presélection puis embauche)', after === 2, String(after));

  // ---------------------------------------------------------------- 4. mission : proposition, choix, jalons ; meme statut des deux cotes
  await as(O);
  const m1 = (await works('MI1 l\'organisation publie un besoin', `select save_mission(null, 'Application MARQMIS', 'Un besoin decrit avec plus de vingt caracteres', 50000, 100000, '2027-01-31', true, 'besoin', false, null) id`))?.[0]?.id;
  await as(S1);
  const p1 = (await works('MI2 le talent propose ses services', `select propose_on_mission('${m1}', 80000, 10, 'Je developpe en Flutter') id`))?.[0]?.id;
  const mstat = async (uid) => { await as(uid); const r = (await q(uid === O ? `select org_missions() r` : `select my_missions() r`))[0].r; return r.find((x) => x.id === m1); };
  await as(O);
  await works('MI3 l\'organisation retient le prestataire', `select decide_proposal('${p1}', true) r`, (r) => r[0].r === 'accepted');
  const ms = await mstat(S1), mo = await mstat(O);
  check('MI4 etat serveur : mission attribuee', (await qs(`select status from missions where id = '${m1}'`))[0].status === 'assigned', JSON.stringify(await qs(`select status from missions where id = '${m1}'`)));
  check('MI5 les deux cotes lisent le meme statut de mission', !!ms && !!mo && ms.status === mo.status, `${ms?.status} / ${mo?.status}`);
  await as(S1);
  await works('MI6 livraison du jalon 1', `select submit_milestone('${m1}', 1::smallint, 'Maquettes livrees et validables', '{}') r`, (r) => r[0].r === 'submitted');
  await as(O);
  await works('MI7 validation du jalon 1', `select decide_milestone('${m1}', 1::smallint, true, null) r`, (r) => r[0].r === 'validated');
  const jal = async (uid) => { await as(uid); return (await q(`select status from mission_milestones where mission_id = '${m1}' and position = 1`)).map((x) => x.status).join(); };
  check('MI8 jalon 1 : meme statut lu par le prestataire et par l\'organisation', (await jal(S1)) === 'validated' && (await jal(O)) === 'validated');
  await as(O2);
  await works('MI9 une autre organisation ne voit pas cette mission', `select org_missions() r`, (r) => !JSON.stringify(r[0].r).includes('MARQMIS'));
  await as(S2);
  await works('MI10 un autre etudiant ne voit pas la mission attribuee', `select my_missions() r`, (r) => !JSON.stringify(r[0].r).includes('MARQMIS'));

  await b.replayMigrations();
  await as(S1);
  await works('R1 apres rejeu : le certificat de l\'etudiant est intact', `select code from certificates where holder_id = '${S1}'`, (r) => r.length === 1);
  b.summary('h132_projets');
}
