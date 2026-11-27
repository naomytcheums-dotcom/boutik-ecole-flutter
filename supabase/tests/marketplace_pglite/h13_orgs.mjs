// Scénario PGlite du lot H13 ORGS : missions de bout en bout (organisation + étudiant), viviers, contacts de talents, multi-organisations.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h13_orgs.mjs   (compter les lignes ECHEC / ERREUR : le code de sortie est toujours 0)
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
const here = path.dirname(fileURLToPath(import.meta.url));
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000013${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const asRoot = async (sql) => { await db.exec('reset role'); const r = await q(sql); return r; };
  const notifs = async (uid, title) => (await asRoot(`select count(*)::int n from notifications where user_id = '${uid}' and title = '${title.replace(/'/g, "''")}'`))[0].n;
  const J = (x) => JSON.stringify(x);

  // ------------------------------------------------------------------ comptes
  // O : propriétaire de l'organisation Orange ; AD administrateur d'équipe ; FI finance ; VW lecteur ; O2 autre organisation (+ son administrateur A2) ; M2 membre des DEUX organisations
  // S1, S2 : talents éligibles (vérifié + téléphone vérifié) ; S3 : étudiant non éligible ; D : département ; ADM : administrateur ; X : client
  await db.exec('reset role');
  const roles = { 1: ['company', 'Orange Cameroun'], 2: ['student', 'Alice Talent'], 3: ['student', 'Bob Talent'], 4: ['student', 'Carl Libre'], 5: ['dept', 'Chef Dept'], 6: ['admin', 'Super Admin'],
    7: ['company', 'Xena Corp'], 8: ['client', 'Client Prive'], 9: ['client', 'Admin Equipe'], 10: ['client', 'Finance Equipe'], 11: ['client', 'Lecteur Equipe'], 12: ['client', 'Admin Deux'], 13: ['client', 'Multi Membre'] };
  for (const [n, [r, nm]] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','u${n}@t.cm')`);
  }
  const O = U(1), S1 = U(2), S2 = U(3), S3 = U(4), D = U(5), ADM = U(6), O2 = U(7), X = U(8), AD = U(9), FI = U(10), VW = U(11), A2 = U(12), M2 = U(13);
  await db.exec(`update profiles set phone = '69013' || right(id::text, 4), phone_verified = true, certification = 'approved' where id in ('${S1}', '${S2}')`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city) values ('${O}', 'Orange Cameroun', 'approved', 'Telecoms', 'Douala'), ('${O2}', 'Xena Corp', 'approved', 'Conseil', 'Yaounde')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status, joined_at) values
    ('${O}', '${AD}', 'admin', 'active', now()), ('${O}', '${FI}', 'finance', 'active', now()), ('${O}', '${VW}', 'viewer', 'active', now()), ('${O}', '${M2}', 'viewer', 'active', now()),
    ('${O2}', '${A2}', 'admin', 'active', now()), ('${O2}', '${M2}', 'admin', 'active', now())`);

  // ================================================================== A. MISSION DE BOUT EN BOUT
  const need = (t, owner = O) => `select save_mission(null, '${t}', 'Un besoin decrit avec plus de vingt caracteres', 50000, 100000, '2027-01-31', true, 'besoin', false, ${owner ? `'${owner}'` : 'null'}) id`;
  await as(AD);
  const m1 = (await q(need('Site web vitrine')))[0].id;
  check('A1 publication par un administrateur d equipe au nom de l organisation', (await asRoot(`select client_id, created_by, status from missions where id = '${m1}'`))[0].client_id === O);
  check('A1 le proprietaire est prevenu une fois', await notifs(O, 'Besoin publié par votre équipe') === 1);
  await as(VW);
  await fails('A1 un lecteur ne publie pas', need('Refus lecteur'), /Réservé au propriétaire/);
  await as(FI);
  await fails('A1 la finance ne publie pas', need('Refus finance'), /Réservé au propriétaire/);
  await as(A2);
  await fails('A1 une autre organisation ne publie pas au nom d Orange', need('Refus autre org'), /Accès refusé/);

  // propositions : seuls les talents éligibles (règle existante 20261122030000)
  await as(S1);
  const p1 = (await q(`select propose_on_mission('${m1}', 80000, 10, 'Equipe de deux developpeurs') id`))[0].id;
  await as(S3);
  await fails('A2 un etudiant non eligible ne propose pas', `select propose_on_mission('${m1}', 70000, 10, 'Je peux')`, /prestation de service/);
  await as(S2);
  const p2 = (await q(`select propose_on_mission('${m1}', 90000, 14, 'Studio') id`))[0].id;
  await as(S2);
  await fails('A2 doublon de proposition refuse', `select propose_on_mission('${m1}', 90000, 14, 'Studio')`, /déjà proposé/);
  check('A2 proprietaire : une notification par proposition', await notifs(O, 'Nouvelle proposition') === 2);
  check('A2 administrateur d equipe : une notification par proposition', await notifs(AD, 'Nouvelle proposition') === 2);
  check('A2 finance et lecteur : aucune notification de proposition', await notifs(FI, 'Nouvelle proposition') === 0 && await notifs(VW, 'Nouvelle proposition') === 0);

  // lecture : l organisation voit ses propositions, pas les autres
  await as(VW);
  const lec = (await q(`select company_proposals('${O}') r`))[0].r;
  check('A3 un lecteur lit les propositions de son organisation', lec.length === 2, J(lec));
  await as(A2);
  await fails('A3 une autre organisation ne lit pas les propositions', `select company_proposals('${O}')`, /Accès refusé/);
  check('A3 une autre organisation ne voit aucune proposition par lecture directe', (await q(`select count(*)::int n from mission_proposals where mission_id = '${m1}'`))[0].n === 0);
  await as(S3);
  check('A3 un etudiant tiers ne voit pas les propositions des autres', (await q(`select count(*)::int n from mission_proposals where mission_id = '${m1}'`))[0].n === 0);

  // choix du prestataire : droits par role
  await as(VW);
  await fails('A4 un lecteur ne decide pas', `select decide_proposal('${p1}', true)`, /Réservé au propriétaire/);
  await as(FI);
  await fails('A4 la finance ne decide pas', `select decide_proposal('${p1}', true)`, /Réservé au propriétaire/);
  await as(A2);
  await fails('A4 une autre organisation ne decide pas', `select decide_proposal('${p1}', true)`, /Proposition introuvable/);
  await as(S2);
  await fails('A4 un talent ne decide pas de sa propre proposition', `select decide_proposal('${p2}', true)`, /Proposition introuvable/);
  await as(null);
  await fails('A4 sans session : refuse', `select decide_proposal('${p1}', true)`, /Connexion requise/);
  await as(null, 'anon');
  await fails('A4 anonyme : execution refusee', `select decide_proposal('${p1}', true)`, /permission denied/);
  check('A4 anonyme : lecture de missions sans erreur de droit, aucune ligne', (await q(`select count(*)::int n from missions`))[0].n === 0);
  for (const t of ['mission_proposals', 'mission_milestones', 'mission_agreements']) {
    await fails(`A4 anonyme : ${t} refuse (aucun droit de table)`, `select count(*) from ${t}`, /permission denied/);
  }
  await as(AD);
  check('A4 un administrateur d equipe retient le prestataire', (await q(`select decide_proposal('${p1}', true) r`))[0].r === 'accepted');
  await fails('A4 rejeu : proposition deja traitee', `select decide_proposal('${p1}', true)`, /déjà traitée/);
  await fails('A4 une deuxieme acceptation refusee', `select decide_proposal('${p2}', true)`, /déjà traitée/);
  check('A4 proprietaire prevenu une fois du choix de son equipe', await notifs(O, 'Prestataire retenu par votre équipe') === 1);
  check('A4 le prestataire retenu est prevenu une fois', await notifs(S1, 'Proposition acceptée') === 1);
  check('A4 le talent non retenu est prevenu une fois', await notifs(S2, 'Proposition non retenue') === 1);
  const st = await asRoot(`select (select status from missions where id = '${m1}') ms, (select count(*)::int from mission_milestones where mission_id = '${m1}') nj, (select count(*)::int from mission_agreements where mission_id = '${m1}') na`);
  check('A4 mission attribuee, trois jalons, un accord', st[0].ms === 'assigned' && st[0].nj === 3 && st[0].na === 1, J(st));

  // etats coherents entre les deux acteurs
  await as(S1);
  const mp = (await q(`select my_missions() r`))[0].r.find((x) => x.id === m1);
  await as(VW);
  const mo = (await q(`select org_missions('${O}') r`))[0].r.find((x) => x.id === m1);
  check('A5 etat identique des deux cotes (statut, total, jalons)', mp && mo && mp.status === mo.status && mp.total === mo.total && J(mp.milestones.map((j) => j.status)) === J(mo.milestones.map((j) => j.status)), J([mp?.status, mo?.status]));
  check('A5 le lecteur lit mais ne peut ni decider ni payer', mo.can_decide === false && mo.can_pay === false && mo.my_role === 'viewer');
  check('A5 le prestataire ne voit pas l identite du client', mp.role === 'provider' && mp.counterpart === null);
  await as(A2);
  check('A5 une autre organisation ne voit aucune mission de l organisation', (await q(`select org_missions() r`))[0].r.length === 0);
  await fails('A5 ... ni en visant l organisation', `select org_missions('${O}')`, /Accès refusé/);
  check('A5 une mission attribuee n est plus lisible par une autre organisation (RLS)', (await q(`select count(*)::int n from missions where id = '${m1}'`))[0].n === 0);
  await as(S3);
  check('A5 ... ni par un etudiant sans proposition', (await q(`select count(*)::int n from missions where id = '${m1}'`))[0].n === 0);
  await as(S2);
  check('A5 un proposant non retenu ne lit pas la table missions (cloisonnement MONEY conserve)', (await q(`select count(*)::int n from missions where id = '${m1}'`))[0].n === 0);
  await as(VW);
  check('A5 le lecteur lit la mission et ses jalons par RLS', (await q(`select (select count(*)::int from missions where id = '${m1}') a, (select count(*)::int from mission_milestones where mission_id = '${m1}') b`))[0].b === 3);

  // jalons
  await as(S1);
  await fails('A6 le jalon 2 ne se livre pas avant la validation du 1', `select submit_milestone('${m1}', 2::smallint, 'Livraison du deuxieme jalon', '{}')`, /jalon précédent/);
  await fails('A6 une preuve est obligatoire', `select submit_milestone('${m1}', 1::smallint, 'ok', '{}')`, /preuve/);
  check('A6 livraison du jalon 1', (await q(`select submit_milestone('${m1}', 1::smallint, 'Maquettes livrees et validables', '{}') r`))[0].r === 'submitted');
  await fails('A6 rejeu : jalon deja livre', `select submit_milestone('${m1}', 1::smallint, 'Maquettes livrees et validables', '{}')`, /déjà livré/);
  check('A6 proprietaire et administrateur : une notification chacun', await notifs(O, 'Jalon livré') === 1 && await notifs(AD, 'Jalon livré') === 1);
  check('A6 finance et lecteur : aucune', await notifs(FI, 'Jalon livré') === 0 && await notifs(VW, 'Jalon livré') === 0);
  await as(VW);
  await fails('A6 un lecteur ne valide pas', `select decide_milestone('${m1}', 1::smallint, true, null)`, /Réservé au propriétaire/);
  await as(FI);
  await fails('A6 la finance ne valide pas', `select decide_milestone('${m1}', 1::smallint, true, null)`, /Réservé au propriétaire/);
  await as(A2);
  await fails('A6 une autre organisation ne valide pas', `select decide_milestone('${m1}', 1::smallint, true, null)`, /Mission introuvable/);
  await as(AD);
  check('A6 un administrateur valide le jalon 1', (await q(`select decide_milestone('${m1}', 1::smallint, true, null) r`))[0].r === 'validated');
  await fails('A6 rejeu : deja traite', `select decide_milestone('${m1}', 1::smallint, true, null)`, /pas été livré/);
  check('A6 le prestataire est prevenu une fois de la validation', await notifs(S1, 'Jalon validé') === 1);
  check('A6 le proprietaire est prevenu de la decision de son equipe', await notifs(O, 'Jalon validé par votre équipe') === 1);
  await as(S1);
  await q(`select submit_milestone('${m1}', 2::smallint, 'Version beta deployee', '{}')`);
  await as(O);
  await fails('A6 correction : motif obligatoire', `select decide_milestone('${m1}', 2::smallint, false, 'x')`, /Précisez la correction/);
  check('A6 le proprietaire demande une correction', (await q(`select decide_milestone('${m1}', 2::smallint, false, 'Corrigez la page contact') r`))[0].r === 'correction');
  await as(S1);
  check('A6 le prestataire re-livre apres correction', (await q(`select submit_milestone('${m1}', 2::smallint, 'Page contact corrigee', '{}') r`))[0].r === 'submitted');
  await as(O);
  await q(`select decide_milestone('${m1}', 2::smallint, true, null)`);
  await as(S1);
  await q(`select submit_milestone('${m1}', 3::smallint, 'Mise en production effectuee', '{}')`);
  await as(AD);
  await q(`select decide_milestone('${m1}', 3::smallint, true, null)`);
  check('A6 tous les jalons valides : mission livree des deux cotes', (await asRoot(`select status from missions where id = '${m1}'`))[0].status === 'delivered');

  // messages
  await as(S1);
  await q(`select send_mission_message('${m1}', 'Bonjour, la mise en ligne est faite', null)`);
  check('A7 message du prestataire : proprietaire et administrateur prevenus une fois', await notifs(O, 'Nouveau message du dossier') === 1 && await notifs(AD, 'Nouveau message du dossier') === 1);
  check('A7 finance et lecteur non prevenus', await notifs(FI, 'Nouveau message du dossier') === 0 && await notifs(VW, 'Nouveau message du dossier') === 0);
  await as(AD);
  await q(`select send_mission_message('${m1}', 'Merci, on controle ce soir', null)`);
  check('A7 reponse de l equipe : le prestataire est prevenu une fois', await notifs(S1, 'Nouveau message du dossier') === 1);
  await as(VW);
  await fails('A7 un lecteur n ecrit pas', `select send_mission_message('${m1}', 'Je commente', null)`, /Dossier introuvable/);
  check('A7 un lecteur lit le dossier', (await q(`select count(*)::int n from mission_messages where mission_id = '${m1}'`))[0].n === 2);
  await as(A2);
  await fails('A7 une autre organisation n ecrit pas', `select send_mission_message('${m1}', 'Intrus', null)`, /Dossier introuvable/);
  check('A7 ... ne lit pas', (await q(`select count(*)::int n from mission_messages where mission_id = '${m1}'`))[0].n === 0);
  await as(S2);
  await fails('A7 un proposant non retenu n ecrit pas', `select send_mission_message('${m1}', 'Intrus', null)`, /Dossier introuvable/);
  check('A7 ... ne lit pas', (await q(`select count(*)::int n from mission_messages where mission_id = '${m1}'`))[0].n === 0);

  // paiement tracé (regle existante : declaration par le client, confirmation par le prestataire)
  await as(VW);
  await fails('A8 un lecteur ne declare pas de paiement', `select milestone_pay_declare('${m1}', 1::smallint, 'Mobile Money', 'REF1')`, /Réservé au propriétaire/);
  await as(FI);
  check('A8 la finance declare le paiement du jalon valide', (await q(`select milestone_pay_declare('${m1}', 1::smallint, 'Mobile Money', 'REF1') r`))[0].r === 'declared');
  check('A8 le prestataire est prevenu une fois', await notifs(S1, 'Paiement déclaré') === 1);
  await as(S1);
  check('A8 le prestataire confirme la reception', (await q(`select milestone_pay_confirm('${m1}', 1::smallint, true) r`))[0].r === 'confirmed');
  check('A8 proprietaire et administrateur : une notification chacun, finance non', await notifs(O, 'Paiement confirmé') === 1 && await notifs(AD, 'Paiement confirmé') === 1 && await notifs(FI, 'Paiement confirmé') === 0);

  // cloture
  await as(VW);
  await fails('A9 un lecteur ne cloture pas', `select mission_close('${m1}')`, /Réservé au propriétaire/);
  await as(FI);
  await fails('A9 la finance ne cloture pas', `select mission_close('${m1}')`, /Réservé au propriétaire/);
  await as(A2);
  await fails('A9 une autre organisation ne cloture pas', `select mission_close('${m1}')`, /Mission introuvable/);
  await as(S1);
  await fails('A9 le prestataire ne cloture pas', `select mission_close('${m1}')`, /Mission introuvable/);
  await fails('A9 pas d avis avant la cloture', `select mission_review_save('${m1}', 5, 'Top')`, /clôturée/);
  await as(AD);
  check('A9 un administrateur cloture', (await q(`select mission_close('${m1}') r`))[0].r === 'closed');
  check('A9 rejeu de la cloture : sans effet de bord', (await q(`select mission_close('${m1}') r`))[0].r === 'closed' && await notifs(S1, 'Mission clôturée') === 1 && await notifs(O, 'Mission clôturée par votre équipe') === 1);

  // avis
  await as(VW);
  await fails('A10 un lecteur ne donne pas d avis', `select mission_review_save('${m1}', 5, 'Top')`, /Réservé au propriétaire/);
  await as(S2);
  await fails('A10 un tiers ne donne pas d avis', `select mission_review_save('${m1}', 5, 'Top')`, /Mission introuvable/);
  await as(AD);
  await fails('A10 note hors bornes', `select mission_review_save('${m1}', 6, 'Top')`, /de 1 à 5/);
  check('A10 le client note le prestataire', (await q(`select mission_review_save('${m1}', 5, 'Travail soigne') r`))[0].r === 'client_to_provider');
  await fails('A10 un seul avis par sens', `select mission_review_save('${m1}', 4, 'Encore')`, /déjà été donné/);
  check('A10 le prestataire est prevenu une fois', await notifs(S1, 'Nouvel avis sur une mission') === 1);
  await as(S1);
  check('A10 le prestataire note le client', (await q(`select mission_review_save('${m1}', 4, 'Client reactif') r`))[0].r === 'provider_to_client');
  check('A10 l organisation est prevenue une fois', await notifs(O, 'Nouvel avis sur une mission') === 1);
  await as(S1);
  const rv1 = (await q(`select mission_reviews_get('${m1}') r`))[0].r;
  await as(VW);
  const rv2 = (await q(`select mission_reviews_get('${m1}') r`))[0].r;
  check('A10 les deux parties voient les memes avis', rv1.length === 2 && rv2.length === 2 && rv1.map((r) => r.rating).sort().join() === rv2.map((r) => r.rating).sort().join(), J([rv1, rv2]));
  check('A10 chaque acteur identifie son propre avis', rv1.find((r) => r.mine).direction === 'provider_to_client' && rv2.find((r) => r.mine).direction === 'client_to_provider');
  await as(A2);
  await fails('A10 une autre organisation ne lit pas les avis', `select mission_reviews_get('${m1}')`, /Mission introuvable/);
  check('A10 table des avis fermee en lecture directe', await (async () => { try { await q(`select * from mission_reviews`); return false; } catch (e) { return /permission denied/.test(e.message); } })());
  const fin = await asRoot(`select status from missions where id = '${m1}'`);
  await as(S1);
  const mp2 = (await q(`select my_missions() r`))[0].r.find((x) => x.id === m1);
  check('A10 etat final coherent : cloturee, tout valide et confirme cote prestataire', fin[0].status === 'closed' && mp2.status === 'closed' && mp2.milestones[0].pay_status === 'confirmed');

  // annulation d un besoin publie par un administrateur d equipe
  await as(AD);
  const m2 = (await q(need('Besoin a retirer')))[0].id;
  await as(S2);
  await q(`select propose_on_mission('${m2}', 60000, 5, 'Possible')`);
  await as(VW);
  await fails('A11 un lecteur n annule pas un besoin', `select mission_cancel('${m2}')`, /Réservé au propriétaire/);
  await as(A2);
  await fails('A11 une autre organisation n annule pas', `select mission_cancel('${m2}')`, /Besoin introuvable/);
  await as(AD);
  check('A11 un administrateur retire le besoin', (await q(`select mission_cancel('${m2}') r`))[0].r === 'cancelled');
  check('A11 la proposition en attente est declinee et le talent prevenu une fois', (await asRoot(`select status from mission_proposals where mission_id = '${m2}'`))[0].status === 'declined' && await notifs(S2, 'Besoin retiré') === 1);

  // besoins publies : lisibles par toute organisation connectee (liste publique), pas les brouillons des autres
  await as(AD);
  const m3 = (await q(`select save_mission(null, 'Brouillon prive', '', null, null, '', false, 'besoin', false, '${O}') id`))[0].id;
  const m4 = (await q(need('Besoin public ouvert')))[0].id;
  await as(A2);
  check('A12 un besoin publie n est pas lisible en table par une autre organisation (il passe par open_needs_list)', (await q(`select count(*)::int n from missions where id = '${m4}'`))[0].n === 0);
  check('A12 un brouillon n est lisible que par l organisation', (await q(`select count(*)::int n from missions where id = '${m3}'`))[0].n === 0);
  await as(VW);
  check('A12 ... et par ses membres', (await q(`select count(*)::int n from missions where id = '${m3}'`))[0].n === 1);

  // attribution par le departement : la regle de capacite vendeur s applique
  await as(D);
  await fails('A13 le departement n attribue pas a un etudiant non eligible', `select assign_mission('${m4}', null, null, '${S3}')`, /éligible|indisponible/);

  // ================================================================== B. VIVIER : renommage, rappels, export CSV
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'approved', department = 'Informatique' where id in ('${S1}', '${S2}')`);
  await as(O);
  const fav = (await q(`select pool_lists_get() r`))[0].r.find((l) => l.name === 'Favoris').id;
  const l1 = (await q(`select pool_list_create('Developpeurs') id`))[0].id;
  await fails('B1 doublon de nom refuse (casse ignoree)', `select pool_list_create('developpeurs')`, /déjà ce nom/);
  check('B1 renommage par le proprietaire', (await q(`select pool_list_rename('${l1}', 'Devs web') r`))[0].r === 'Devs web');
  await fails('B1 renommage vers un nom existant refuse', `select pool_list_rename('${l1}', 'FAVORIS')`, /déjà ce nom/);
  await fails('B1 Favoris ne se renomme pas', `select pool_list_rename('${fav}', 'Autre')`, /Favoris ne peut pas/);
  await fails('B1 nom trop court refuse', `select pool_list_rename('${l1}', 'a')`, /au moins 2/);
  await as(VW);
  await fails('B2 un lecteur ne renomme pas', `select pool_list_rename('${l1}', 'Lecteur', '${O}')`, /Réservé au propriétaire/);
  await as(FI);
  await fails('B2 la finance n a aucun acces au vivier', `select pool_list_rename('${l1}', 'Finance', '${O}')`, /Accès refusé/);
  await as(A2);
  await fails('B2 une autre organisation ne renomme pas', `select pool_list_rename('${l1}', 'Autre', '${O}')`, /Accès refusé/);
  await as(O2);
  await fails('B2 une autre organisation ne renomme pas par son propre contexte', `select pool_list_rename('${l1}', 'Autre')`, /Liste introuvable/);
  await as(null, 'anon');
  await fails('B2 anonyme refuse', `select pool_list_rename('${l1}', 'Anon')`, /permission denied/);
  await as(AD);
  check('B2 un administrateur d equipe renomme', (await q(`select pool_list_rename('${l1}', 'Developpeurs', '${O}') r`))[0].r === 'Developpeurs');

  await as(O);
  await q(`select pool_list_add('${l1}', '${S1}', 'Bon profil', null)`);
  await q(`select pool_list_add('${l1}', '${S2}', '', null)`);
  await q(`select pool_talent_set('${S1}', 'favori', array['=cmd','react'], null)`);
  await q(`select pool_note_add('${S1}', 'Note interne secrete', null)`);
  await q(`select pool_contact_log('${S1}', 'appel', 'Premier echange', null, null)`);
  // le talent partage ses competences avec les organisations ; S2 ne partage rien
  await as(S1);
  await q(`select talent_passport_share_set('competences', 'organisations')`);
  await db.exec('reset role');
  await db.exec(`insert into talent_skills (owner_id, domain, skill, level) values ('${S1}', 'Informatique', '=SUM(A1)', 'avance'), ('${S1}', 'Informatique', 'Flutter', 'expert'), ('${S2}', 'Informatique', 'Secret', 'expert')`);
  await as(O);
  const ex = (await q(`select pool_export(null, null) r`))[0].r;
  check('B3 export : fichier CSV nomme et compte', /^vivier-talents-\d{8}\.csv$/.test(ex.filename) && ex.count === 2, J([ex.filename, ex.count]));
  check('B3 export : competences partagees presentes, formule neutralisee', ex.csv.includes('Flutter') && ex.csv.includes(`"'=SUM(A1), Flutter"`) && !/;"=/.test(ex.csv), ex.csv);
  check('B3 export : competences non partagees absentes', !ex.csv.includes('Secret'));
  check('B3 export : ni e-mail ni telephone ni note interne', !ex.csv.includes('@t.cm') && !ex.csv.includes('69013') && !ex.csv.includes('Note interne secrete') && !ex.csv.includes('Bon profil'));
  check('B3 export : nom complet seulement si partage (sinon nom masque)', !ex.csv.includes('Bob Talent') && !ex.csv.includes('Alice Talent'), ex.csv);
  check('B3 export : etiquette a formule neutralisee', ex.csv.includes(`'=cmd`) , ex.csv);
  check('B3 export : un dernier contact est restitue', /\d{4}-\d{2}-\d{2}/.test(ex.csv));
  check('B3 export : tracé dans le journal d audit', (await asRoot(`select count(*)::int n from audit_log where action = 'Export CSV du vivier de talents'`))[0].n === 1);
  await as(O);
  check('B3 export d une liste precise', (await q(`select pool_export('${fav}', null) r`))[0].r.count === 0);
  await fails('B3 liste d une autre organisation refusee', `select pool_export('${l1}', '${O2}')`, /Accès refusé|Liste introuvable/);
  await as(AD);
  check('B3 un administrateur d equipe exporte', (await q(`select pool_export(null, '${O}') r`))[0].r.count === 2);
  await as(VW);
  await fails('B3 un lecteur n exporte pas', `select pool_export(null, '${O}')`, /Réservé au propriétaire/);
  await as(FI);
  await fails('B3 la finance n exporte pas', `select pool_export(null, '${O}')`, /Accès refusé/);
  await as(A2);
  await fails('B3 une autre organisation n exporte pas le vivier d Orange', `select pool_export(null, '${O}')`, /Accès refusé/);
  await as(S1);
  await fails('B3 un talent n exporte pas', `select pool_export(null, null)`, /Réservé aux organisations|permission/);
  await as(null, 'anon');
  await fails('B3 anonyme refuse', `select pool_export(null, null)`, /permission denied/);
  await as(O2);
  check('B3 une autre organisation exporte son vivier vide, sans fuite', (await q(`select pool_export(null, null) r`))[0].r.count === 0);

  // un talent retiré de l annuaire disparait de l export, ses notes ne sont plus lues, puis reviennent
  await as(S2);
  await q(`select talent_visibility_set(false)`);
  await as(O);
  check('B4 talent masque : exclu de l export', (await q(`select pool_export(null, null) r`))[0].r.count === 1);
  await fails('B4 talent masque : notes non lues', `select pool_notes_get('${S2}', null)`, /introuvable/);
  check('B4 talent visible : notes lues par l organisation', (await q(`select pool_notes_get('${S1}', null) r`))[0].r.length === 1);
  await as(S1);
  await fails('B4 un talent ne lit pas les notes de l organisation', `select pool_notes_get('${S1}', '${O}')`, /Accès refusé|Réservé|permission/);
  check('B4 tables de notes fermees au talent', await (async () => { try { await q(`select * from talent_pool_notes`); return false; } catch (e) { return /permission denied/.test(e.message); } })());
  await as(S2);
  await q(`select talent_visibility_set(true)`);
  await as(O);
  check('B4 talent redevenu visible : de nouveau exporte', (await q(`select pool_export(null, null) r`))[0].r.count === 2);

  // rappels : une seule notification, auteur autorise, talent listable
  await as(AD);
  const rm1 = (await q(`select pool_reminder_set('${S1}', current_date, 'Rappeler Alice', '${O}') id`))[0].id;
  const rm2 = (await q(`select pool_reminder_set('${S2}', current_date, 'Rappeler Bob', '${O}') id`))[0].id;
  const n1 = (await q(`select pool_reminders_dispatch('${O}') n`))[0].n;
  const n2 = (await q(`select pool_reminders_dispatch('${O}') n`))[0].n;
  check('B5 rappels : notifies une seule fois', n1 === 2 && n2 === 0, J([n1, n2]));
  check('B5 rappels : une notification par rappel pour l auteur', await notifs(AD, 'Rappel vivier de talents') === 2);
  await as(VW);
  await fails('B5 un lecteur ne supprime pas un rappel', `select pool_reminder_delete('${rm1}', '${O}')`, /Réservé au propriétaire/);
  await as(A2);
  await fails('B5 une autre organisation ne supprime pas un rappel', `select pool_reminder_delete('${rm1}', '${O}')`, /Accès refusé/);
  await as(O2);
  await fails('B5 ... ni par son propre contexte', `select pool_reminder_delete('${rm1}')`, /Rappel introuvable/);
  await as(AD);
  await q(`select pool_reminder_delete('${rm2}', '${O}')`);
  await fails('B5 rejeu de la suppression refuse', `select pool_reminder_delete('${rm2}', '${O}')`, /Rappel introuvable/);
  // balayage planifie : un auteur retire de l equipe ou un talent masque ne declenchent rien
  await as(AD);
  const rm4 = (await q(`select pool_reminder_set('${S1}', current_date, 'Balayage', '${O}') id`))[0].id;
  await as(S1);
  await q(`select talent_visibility_set(false)`);
  await asRoot(`select pool_reminders_sweep() n`);
  check('B6 balayage : talent masque, pas de notification', (await asRoot(`select notified_at from talent_pool_reminders where id = '${rm4}'`))[0].notified_at === null);
  await as(S1);
  await q(`select talent_visibility_set(true)`);
  await as(AD);
  await asRoot(`update company_members set status = 'removed' where owner_id = '${O}' and user_id = '${AD}'`).catch(() => null);
  const sw1 = (await asRoot(`select pool_reminders_sweep() n`))[0].n;
  const stn = (await asRoot(`select notified_at from talent_pool_reminders where id = '${rm4}'`))[0].notified_at;
  check('B6 balayage : auteur sorti de l equipe (ou encore actif) coherent', (sw1 === 0 && stn === null) || (sw1 === 1 && stn !== null), J([sw1, stn]));
  await asRoot(`update company_members set status = 'active' where owner_id = '${O}' and user_id = '${AD}'`);
  const sw2 = (await asRoot(`select pool_reminders_sweep() n`))[0].n;
  const sw3 = (await asRoot(`select pool_reminders_sweep() n`))[0].n;
  check('B6 balayage : une seule notification puis plus rien', sw3 === 0 && (sw1 + sw2) <= 1, J([sw1, sw2, sw3]));
  await as(S1);
  await fails('B6 le balayage n est pas appelable par un utilisateur', `select pool_reminders_sweep()`, /permission denied/);
  await as(null, 'anon');
  await fails('B6 le balayage n est pas appelable par l anonyme', `select pool_reminders_sweep()`, /permission denied/);

  // ================================================================== C. CONTACTS : statut, reponse, delai
  await db.exec('reset role');
  await db.exec(`insert into talent_visibility_settings (user_id, public_ranking, show_full_name, shared_sections) values ('${S1}', true, false, array['rank']), ('${S2}', true, false, array['rank'])`);
  await as(AD);
  const c1 = (await q(`select discovery_contact_request('${S1}', 'interview', 'Entretien jeudi a 10h chez Orange', '${O}') r`))[0].r.id;
  const c2 = (await q(`select discovery_contact_request('${S2}', 'job_offer', 'Poste de developpeur junior', '${O}') r`))[0].r.id;
  check('C1 la demande est rattachee a l organisation et en statut envoye', (await asRoot(`select count(*)::int n from talent_contacts where id in ('${c1}', '${c2}') and org_id = '${O}' and status = 'sent' and expires_at > now() + interval '13 days'`))[0].n === 2);
  await as(VW);
  await fails('C1 un lecteur n envoie pas de demande', `select discovery_contact_request('${S1}', 'contact', '', '${O}')`, /Réservé au propriétaire/);
  await as(A2);
  await fails('C1 une autre organisation n envoie pas au nom d Orange', `select discovery_contact_request('${S1}', 'contact', '', '${O}')`, /Accès refusé/);
  await as(S1);
  const mine = (await q(`select my_talent_contact_requests() r`))[0].r;
  check('C2 le talent voit sa demande avec statut et echeance', mine.length === 1 && mine[0].status === 'sent' && mine[0].can_respond === true && mine[0].expires_at, J(mine));
  check('C2 le talent marque la demande comme vue', (await q(`select talent_contact_seen('${c1}') r`))[0].r === 'seen');
  check('C2 marquer vu est idempotent', (await q(`select talent_contact_seen('${c1}') r`))[0].r === 'seen');
  await fails('C2 un talent ne marque pas la demande d un autre', `select talent_contact_seen('${c2}')`, /Demande introuvable/);
  await fails('C2 un talent ne repond pas a la demande d un autre', `select talent_contact_respond('${c2}', 'accepted', '')`, /Demande introuvable/);
  await fails('C2 decision inconnue refusee', `select talent_contact_respond('${c1}', 'peut-etre', '')`, /Accepter ou Décliner/);
  check('C2 le talent peut ecrire a la table ? non (lecture seule)', await (async () => { try { await q(`update talent_contacts set status = 'accepted' where id = '${c1}'`); return (await asRoot(`select status from talent_contacts where id = '${c1}'`))[0].status === 'seen'; } catch (e) { return /permission denied/.test(e.message); } })());
  await as(S1);
  check('C3 le talent accepte avec un message', (await q(`select talent_contact_respond('${c1}', 'accepted', 'Je suis disponible jeudi') r`))[0].r === 'accepted');
  await fails('C3 rejeu : deja repondu', `select talent_contact_respond('${c1}', 'declined', '')`, /déjà répondu/);
  check('C3 l expediteur est prevenu une seule fois', await notifs(AD, 'Demande acceptée') === 1);
  await as(S2);
  check('C3 un autre talent decline', (await q(`select talent_contact_respond('${c2}', 'declined', '')`))[0].talent_contact_respond === 'declined');
  check('C3 un talent ne voit pas les demandes d un autre', (await q(`select my_talent_contact_requests() r`))[0].r.length === 1);

  // suivi cote organisation
  await as(VW);
  const suivi = (await q(`select pool_contact_requests_get('${O}', null) r`))[0].r;
  check('C4 un lecteur lit le suivi : statuts, reponse, delai', suivi.items.length === 2 && suivi.stats.total === 2 && suivi.stats.accepted === 1 && suivi.stats.declined === 1 && suivi.stats.pending === 0
    && suivi.items.some((i) => i.status === 'accepted' && i.response === 'Je suis disponible jeudi' && i.delay_hours !== null) && suivi.stats.avg_delay_hours !== null, J(suivi));
  check('C4 filtre par statut', (await q(`select pool_contact_requests_get('${O}', 'declined') r`))[0].r.items.length === 1);
  await fails('C4 statut inconnu refuse', `select pool_contact_requests_get('${O}', 'zzz')`, /Statut inconnu/);
  await as(FI);
  await fails('C4 la finance n a pas acces au suivi', `select pool_contact_requests_get('${O}', null)`, /Accès refusé/);
  await as(A2);
  await fails('C4 une autre organisation ne lit pas le suivi', `select pool_contact_requests_get('${O}', null)`, /Accès refusé/);
  await as(O2);
  check('C4 une autre organisation ne voit que ses propres demandes (aucune)', (await q(`select pool_contact_requests_get(null, null) r`))[0].r.items.length === 0);
  await as(S1);
  await fails('C4 un talent n accede pas au suivi des organisations', `select pool_contact_requests_get('${O}', null)`, /Accès refusé|Réservé/);
  await as(null, 'anon');
  await fails('C4 anonyme refuse', `select pool_contact_requests_get('${O}', null)`, /permission denied/);
  await fails('C4 anonyme : reponse refusee', `select talent_contact_respond('${c1}', 'accepted', '')`, /permission denied/);
  await as(O);
  await q(`select pool_list_add('${l1}', '${S1}', '', null)`).catch(() => null);
  const hist = (await q(`select pool_contacts_get('${S1}', null) r`))[0].r;
  check('C5 l historique du vivier porte le statut de la demande', hist.some((h) => h.source === 'plateforme' && h.status === 'accepted' && h.response === 'Je suis disponible jeudi'), J(hist));

  // expiration : echeance depassee => expiree (lecture) puis balayage unique
  await as(AD);
  const c3 = (await q(`select discovery_contact_request('${S2}', 'contact', 'Nouvel echange', '${O}') r`))[0].r.id;
  await asRoot(`update talent_contacts set expires_at = now() - interval '1 hour', created_at = created_at - interval '2 days' where id = '${c3}'`);
  await as(S2);
  check('C6 echeance depassee : lue comme expiree, reponse impossible', (await q(`select my_talent_contact_requests() r`))[0].r.find((r) => r.id === c3).status === 'expired');
  await fails('C6 repondre a une demande expiree refuse', `select talent_contact_respond('${c3}', 'accepted', '')`, /expiré/);
  await as(AD);
  check('C6 le suivi compte l expiree', (await q(`select pool_contact_requests_get('${O}', 'expired') r`))[0].r.items.length === 1);
  const e1 = (await asRoot(`select contact_requests_expire() n`))[0].n;
  const e2 = (await asRoot(`select contact_requests_expire() n`))[0].n;
  check('C6 balayage : une seule passe, une seule notification', e1 === 1 && e2 === 0 && await notifs(AD, 'Demande restée sans réponse') === 1, J([e1, e2]));
  await as(S1);
  await fails('C6 le balayage n est pas appelable par un utilisateur', `select contact_requests_expire()`, /permission denied/);
  // talent masque : sort du suivi
  await as(S1);
  await q(`select talent_visibility_set(false)`);
  await as(VW);
  check('C7 talent masque : absent du suivi', (await q(`select pool_contact_requests_get('${O}', null) r`))[0].r.items.every((i) => i.student !== S1));
  await as(S1);
  await q(`select talent_visibility_set(true)`);

  // ================================================================== D. MULTI-ORGANISATIONS
  await as(S1);
  await q(`select propose_on_mission('${m4}', 60000, 7, 'Je peux le faire') id`);
  await as(AD);
  const d_c4 = (await q(`select discovery_contact_request('${S2}', 'contact', 'Un dernier echange', '${O}') r`))[0].r.id;
  const d_orgsOf = async (uid) => { await as(uid); return (await q(`select my_organizations() r`))[0].r; };
  const d_own = await d_orgsOf(O);
  check('D1 le proprietaire voit sa propre organisation, role proprietaire', d_own.length === 1 && d_own[0].is_own === true && d_own[0].role === 'owner' && d_own[0].can_manage === true && d_own[0].verified === true, J(d_own));
  const expRem = (await asRoot(`select count(*)::int n from talent_pool_reminders where org_id = '${O}' and status = 'ouvert' and due_on <= current_date`))[0].n;
  check('D1 pastilles du proprietaire : proposition, rappels, demande sans reponse', d_own[0].pending_proposals === 1 && d_own[0].due_reminders === expRem && expRem >= 1 && d_own[0].pending_contacts === 1, J(d_own[0]));
  const d_multi = await d_orgsOf(M2);
  const oRg = d_multi.find((o) => o.owner_id === O), oRg2 = d_multi.find((o) => o.owner_id === O2);
  check('D2 un membre de deux organisations les voit toutes les deux avec le bon role', d_multi.length === 2 && oRg.role === 'viewer' && oRg2.role === 'admin' && !oRg.is_own, J(d_multi));
  check('D2 droits propres a chaque organisation', oRg.can_manage === false && oRg.can_pool_write === false && oRg.can_pool_read === true && oRg2.can_manage === true && oRg2.can_pool_write === true);
  check('D2 pastilles propres a chaque organisation (pas de melange)', oRg.pending_proposals === 1 && oRg2.pending_proposals === 0 && oRg2.pending_contacts === 0 && oRg2.due_reminders === 0, J(d_multi));
  const d_fin = await d_orgsOf(FI);
  check('D3 la finance ne voit aucune pastille de vivier ni de proposition', d_fin.length === 1 && d_fin[0].role === 'finance' && d_fin[0].can_pay === true && d_fin[0].can_pool_read === false && d_fin[0].pending_proposals === null && d_fin[0].due_reminders === null && d_fin[0].pending_contacts === null, J(d_fin));
  const d_tiers = await d_orgsOf(X);
  check('D4 un client sans organisation ne voit rien', d_tiers.length === 0, J(d_tiers));
  check('D4 un talent ne voit rien', (await d_orgsOf(S1)).length === 0);
  await db.exec('reset role');
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${O}', '${X}', 'admin', 'invited')`);
  const d_inv = await d_orgsOf(X);
  check('D5 invitation en attente : visible sans droit ni chiffre', d_inv.length === 1 && d_inv[0].status === 'invited' && d_inv[0].can_manage === false && d_inv[0].can_pool_read === false && d_inv[0].pending_proposals === null && d_inv[0].pending_contacts === null, J(d_inv));
  await as(X);
  await fails('D5 invitee : pas d acces au vivier avant d accepter', `select pool_lists_get('${O}')`, /Accès refusé/);
  await as(null);
  await fails('D6 sans session : refuse', `select my_organizations()`, /Connexion requise/);
  await as(null, 'anon');
  await fails('D6 anonyme : refuse', `select my_organizations()`, /permission denied/);
  // un membre retire de l equipe ne voit plus l organisation active ni ses chiffres
  await db.exec('reset role');
  await db.exec(`update company_members set status = 'invited' where owner_id = '${O}' and user_id = '${M2}'`);
  const d_apres = await d_orgsOf(M2);
  check('D7 membre repasse en attente : plus de droits ni de pastilles sur cette organisation', d_apres.find((o) => o.owner_id === O).can_pool_read === false && d_apres.find((o) => o.owner_id === O).pending_contacts === null);
  await as(M2);
  await fails('D7 ... et l acces au vivier est refuse', `select pool_lists_get('${O}')`, /Accès refusé/);
  await db.exec('reset role');
  await db.exec(`update company_members set status = 'active' where owner_id = '${O}' and user_id = '${M2}'; delete from company_members where owner_id = '${O}' and user_id = '${X}'`);

  // PARTS-MARKER

  {
    // rejeu des migrations H13 ORGS : sans erreur ni effet de bord
    await db.exec('reset role');
    const before = (await q(`select (select count(*) from missions) a, (select count(*) from mission_reviews) b, (select count(*) from notifications) c`))[0];
    const files = fs.readdirSync(path.join(here, '..', '..', 'migrations')).filter((f) => /^2026112806\d{4}_h13_orgs/.test(f)).sort();
    for (const f of files) { try { await db.exec(fs.readFileSync(path.join(here, '..', '..', 'migrations', f), 'utf8')); check('Z rejeu ' + f, true); } catch (e) { check('Z rejeu ' + f, false, e.message); } }
    const after = (await q(`select (select count(*) from missions) a, (select count(*) from mission_reviews) b, (select count(*) from notifications) c`))[0];
    check('Z rejeu : aucune donnee modifiee', J(before) === J(after), J([before, after]));
    console.log(`\n${ok}/${ok + ko}`);
  }
}
