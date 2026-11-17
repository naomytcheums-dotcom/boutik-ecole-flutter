// Lot G1 (étudiant, finalisation) : migration 20261119010000 (suppression de compte gelée tant que de l'argent est en jeu, état de vérification lisible).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./etu2_g1.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated', aal = null) => {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '${uid && aal ? JSON.stringify({ sub: uid, aal }) : ''}', false)`);
    if (role) await db.exec(`set role ${role}`);
  };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await as(null, null);
  // 61 étudiant sans argent · 62 étudiant avec argent gardé · 63 étudiant avec solde · 64 client · 65 dept · 66 admin · 67 company · 68 étudiant (devis, contenus) · 69 étudiant solde sous le minimum
  const roles = { 61: 'student', 62: 'student', 63: 'student', 64: 'client', 65: 'dept', 66: 'admin', 67: 'company', 68: 'student', 69: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','g1_${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','g1_${n}@t.cm')`);
  }
  const entry = (n, status, amt) => db.exec(`insert into money_entries (kind, ref, gross, beneficiary_id, beneficiary_amount, institution_amount, platform_amount, status)
    values ('other', 'G1-${n}', ${amt}, '${U(n)}', ${amt}, 0, 0, '${status}')`);
  await entry(62, 'held', 7000);
  await entry(63, 'released', 5000);
  await entry(69, 'released', 500);

  // --- demande refusée tant que de l'argent est en jeu
  await as(U(62));
  await fails('séquestre : la demande est refusée (argent gardé)', `select request_account_deletion('je pars')`, /gardés en séquestre/);
  await as(U(63));
  await fails('solde : la demande est refusée (solde à retirer)', `select request_account_deletion('je pars')`, /solde disponible à retirer/);
  await as(U(69));
  await fails('solde sous le minimum : refusé avec la marche à suivre', `select request_account_deletion('je pars')`, /contactez le support/);
  await as(U(61));
  check('sans argent ni commande : la demande est enregistrée', (await q(`select request_account_deletion('je pars') r`))[0].r.status === 'pending');
  check('ma demande : non bloquée', (await q(`select my_account_deletion() r`))[0].r.blocked === false);
  await as(U(64));
  check('client sans argent : la demande est enregistrée', (await q(`select request_account_deletion() r`))[0].r.status === 'pending');
  await as(U(67));
  check('entreprise sans argent : la demande est enregistrée', (await q(`select request_account_deletion() r`))[0].r.status === 'pending');
  await as(U(65));
  await fails('équipe : dept refusé', `select request_account_deletion()`, /équipe/);
  await as(U(66), 'authenticated', 'aal2');
  await fails('équipe : admin refusé', `select request_account_deletion()`, /équipe/);
  await as(null, 'anon');
  await fails('anonyme : refusé', `select request_account_deletion()`, /permission denied|Connexion requise/);
  await fails('anonyme : _account_blockers inaccessible', `select _account_blockers('${U(62)}')`, /permission denied/);
  await as(U(61));
  await fails('un utilisateur ne lit pas les blockers d\'un autre', `select _account_blockers('${U(62)}')`, /permission denied/);

  // --- gel : l'argent arrive APRÈS la demande ; l'exécution attend
  await db.exec('reset role');
  await entry(61, 'held', 3000);
  await db.exec(`update account_deletion_requests set scheduled_for = now() - interval '1 day'`);
  await as(U(61));
  const mine = (await q(`select my_account_deletion() r`))[0].r;
  check('ma demande : bloquée avec la raison', mine.blocked === true && /séquestre/.test(mine.blocked_reason), JSON.stringify(mine));
  await as(U(65));
  await fails('dept : ne lance pas le traitement', `select admin_process_account_deletions()`, /Réservé à l'administrateur/);
  await fails('dept : ne lit pas la file', `select account_deletions_pending()`, /non autorisée/);
  await as(U(66), 'authenticated', 'aal2');
  const ap = (await q(`select account_deletions_pending() r`))[0].r;
  check('file d\'équipe : la demande bloquée est signalée', ap.find((x) => x.user_id === U(61))?.blocked === true && ap.find((x) => x.user_id === U(64))?.blocked === false, JSON.stringify(ap));
  let pr = (await q(`select admin_process_account_deletions() r`))[0].r;
  check('exécution gelée : le compte avec argent en séquestre est épargné, les autres sont anonymisés', pr.processed === 2 && pr.blocked.length === 1 && pr.blocked[0] === U(61), JSON.stringify(pr));
  await db.exec('reset role');
  check('compte gelé : profil intact', (await q(`select name, suspended from profiles where id = '${U(61)}'`))[0].name === 'Personne 61');
  check('compte gelé : demande toujours en attente avec motif', (await q(`select status, blocked_reason from account_deletion_requests where user_id = '${U(61)}'`))[0].blocked_reason?.includes('séquestre') === true);
  check('compte gelé : la personne est prévenue', (await q(`select count(*)::int n from notifications where user_id = '${U(61)}' and title = 'Suppression de compte en attente'`))[0].n === 1);
  await as(U(66), 'authenticated', 'aal2');
  await q(`select admin_process_account_deletions()`);
  await db.exec('reset role');
  check('compte gelé : une seule notification par semaine', (await q(`select count(*)::int n from notifications where user_id = '${U(61)}' and title = 'Suppression de compte en attente'`))[0].n === 1);
  check('client et entreprise : anonymisés', (await q(`select count(*)::int n from profiles where id in ('${U(64)}','${U(67)}') and name = 'Compte supprimé' and suspended`))[0].n === 2);

  // --- l'argent est débloqué puis retiré : l'exécution passe, l'argent reste comptabilisé
  await db.exec(`delete from money_entries where beneficiary_id = '${U(61)}'`);
  await db.exec(`insert into listings (id, seller_id, title, department, price, status, stock) values ('00000000-0000-0000-0000-00000000c161', '${U(61)}', 'Lampe G1', 'Genie', 5000, 'approved', 3)`);
  await as(U(66), 'authenticated', 'aal2');
  pr = (await q(`select admin_process_account_deletions() r`))[0].r;
  await db.exec('reset role');
  check('argent réglé : le compte est anonymisé', pr.processed === 1 && (await q(`select name from profiles where id = '${U(61)}'`))[0].name === 'Compte supprimé', JSON.stringify(pr));
  check('annonce retirée', (await q(`select status from listings where id = '00000000-0000-0000-0000-00000000c161'`))[0].status === 'removed');

  // --- devis ouverts clos et contenus personnels retirés
  await db.exec(`insert into listings (id, seller_id, title, department, price, status, stock) values ('00000000-0000-0000-0000-00000000c168', '${U(68)}', 'Service G1', 'Genie', 5000, 'approved', 3)`);
  await db.exec(`insert into quote_requests (listing_id, requester_id, provider_id, brief, status) values ('00000000-0000-0000-0000-00000000c168', '${U(64)}', '${U(68)}', 'Un devis pour un site web complet', 'requested')`);
  await db.exec(`insert into stories (author_id, media_path, media_kind) values ('${U(68)}', 'stories/g1.jpg', 'image');
    insert into portfolio_items (owner_id, kind, title) values ('${U(68)}', 'link', 'Mon site G1')`);
  await as(U(68));
  check('étudiant avec devis ouvert : la demande est enregistrée', (await q(`select request_account_deletion() r`))[0].r.status === 'pending');
  await db.exec(`reset role; update account_deletion_requests set scheduled_for = now() - interval '1 day' where user_id = '${U(68)}'`);
  await as(U(66), 'authenticated', 'aal2');
  await q(`select admin_process_account_deletions()`);
  await db.exec('reset role');
  check('devis ouvert clos à l\'anonymisation', (await q(`select status from quote_requests where provider_id = '${U(68)}'`))[0].status === 'declined');

  check('histoires et portfolio personnels retirés', (await q(`select (select count(*) from stories where author_id = '${U(68)}')::int + (select count(*) from portfolio_items where owner_id = '${U(68)}')::int n`))[0].n === 0);

  // --- état de vérification lisible
  await db.exec(`reset role; update profiles set suspended = true where id = '${U(63)}'`);
  await as(U(63));
  const sus = (await q(`select my_student_status() s`))[0].s;
  check('statut : étudiant suspendu, ne peut pas demander la certification', sus.suspended === true && sus.can_request_certification === false && sus.verified === false, JSON.stringify(sus));
  await as(null, null);
  await db.exec(`update profiles set suspended = false where id = '${U(63)}'`);
  await as(U(63));
  const st = (await q(`select my_student_status() s`))[0].s;
  check('statut : téléphone, département, suspension exposés', st.has_phone === false && st.phone_verified === false && st.has_department === false && st.suspended === false && st.verified === false && Array.isArray(st.rejected_documents), JSON.stringify(st));
  await as(null, 'anon');
  await fails('statut : anonyme refusé', `select my_student_status()`, /permission denied|Connexion requise/);

  await db.exec('reset role');
  console.log(`\netu2_g1: ${ok} OK, ${ko} KO`);
}
