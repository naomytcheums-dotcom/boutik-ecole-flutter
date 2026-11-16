// Scénario PGlite du lot S4 « devis-missions » (migrations 20261117045000 et 20261117045100) : devis côté prestataire, missions, preuves, accord de paiement, documents.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_devis.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const notifs = async (uid, title) => { await db.exec('reset role'); return (await q(`select count(*)::int n from notifications where user_id = '${uid}' and title = '${title}'`))[0].n; };

  await db.exec('reset role');
  // 11 client, 12 prestataire A, 17 autre talent, 13 département, 14 admin, 18 talent à la fois client et prestataire, 19 acheteur
  const roles = { 11: 'student', 12: 'student', 13: 'dept', 14: 'admin', 17: 'student', 18: 'student', 19: 'client' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Profil Complet ${n}','${r}','u${n}@t.cm')`);
  }
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values
    ('${U(12)}','Creation de logo','Design','Services',20000,99,'approved','{}'),
    ('${U(12)}','Lampe en bois','Genie civil','Maison',25000,5,'approved','{a,b,c}')`);
  const logo = (await q(`select id from listings where title='Creation de logo'`))[0].id;

  // ====================================================== DEVIS
  // S4-40 : décliner
  await as(U(11));
  const q1 = (await q(`select request_quote_offer('${logo}', 'Un logo pour ma boutique de jus', 15000, '2 semaines') id`))[0].id;
  await as(U(17));
  await fails('S4-40 : un tiers ne décline pas', `select decline_quote('${q1}', 'non')`, /introuvable/);
  await as(U(11));
  await fails('S4-40 : le demandeur ne décline pas (il annule)', `select decline_quote('${q1}', 'non')`, /introuvable/);
  await as(U(12));
  check('S4-40 : le prestataire décline', (await q(`select decline_quote('${q1}', 'Je suis indisponible ce mois-ci') r`))[0].r === 'rejected');
  check('S4-40 : statut et motif enregistrés', (await q(`select status, decline_reason from quote_requests where id='${q1}'`)).some((r) => r.status === 'rejected' && /indisponible/.test(r.decline_reason)));
  check('S4-40 : le demandeur est notifié', (await notifs(U(11), 'Demande de devis déclinée')) === 1);
  await as(U(12));
  await fails('S4-40 : déjà clôturée', `select decline_quote('${q1}', null)`, /déjà clôturée/);
  await fails('S4-40 : on ne répond plus à une demande déclinée', `select answer_quote('${q1}', 10000, 3, '')`, /déjà clôturée/);
  await as(U(11));
  const q2 = (await q(`select request_quote_offer('${logo}', 'Nouvelle demande de logo apres refus', 15000, '') id`))[0].id;
  check('S4-40 : le demandeur peut redemander après un refus', !!q2);

  // S4-42 : bornes, révisions, validité, expiration
  await as(U(12));
  await fails('S4-42 : montant nul refusé', `select answer_quote('${q2}', 0, 3, '')`, /entre 1 et 100 000 000/);
  await fails('S4-42 : montant au-delà de 100 000 000 refusé côté serveur', `select answer_quote('${q2}', 100000001, 3, '')`, /entre 1 et 100 000 000/);
  await fails('S4-42 : délai hors bornes refusé', `select answer_quote('${q2}', 10000, 400, '')`, /délai de 1 à 365/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${U(12)}'`);
  await as(U(12));
  await fails('S4-42 : prestataire suspendu refusé', `select answer_quote('${q2}', 10000, 3, '')`, /suspendu/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${U(12)}'`);
  await db.exec(`update listings set status = 'pending' where id = '${logo}'`);
  await as(U(12));
  await fails('S4-42 : annonce dépubliée refusée', `select answer_quote('${q2}', 10000, 3, '')`, /plus publiée/);
  await db.exec('reset role');
  await db.exec(`update listings set status = 'approved' where id = '${logo}'`);
  await as(U(12));
  check('S4-42 : réponse valide', (await q(`select answer_quote('${q2}', 18000, 5, 'Trois pistes') r`))[0].r === 'quoted');
  const v = (await q(`select valid_until > now() + interval '13 days' and valid_until < now() + interval '15 days' as okv, answers from quote_requests where id='${q2}'`))[0];
  check('S4-42 : validité de 14 jours et compteur de réponses', v.okv === true && v.answers === 1, JSON.stringify(v));
  for (let i = 2; i <= 5; i++) await q(`select answer_quote('${q2}', ${18000 + i}, 5, '')`);
  await fails('S4-42 : sixième modification refusée', `select answer_quote('${q2}', 19000, 5, '')`, /cinq fois/);
  await db.exec('reset role');
  await db.exec(`update quote_requests set valid_until = now() - interval '1 day' where id = '${q2}'`);
  await as(U(11));
  await fails('S4-42 : devis expiré non acceptable', `select decide_quote('${q2}', true, 18005)`, /a expiré/);
  await db.exec('reset role');
  await db.exec(`insert into quote_requests (listing_id, requester_id, provider_id, brief, status, created_at) values ('${logo}', '${U(17)}', '${U(12)}', 'Demande sans réponse depuis longtemps', 'requested', now() - interval '31 days')`);
  const nExp = (await q(`select expire_quotes() n`))[0].n;
  check('S4-42 : expire_quotes clôture le devis périmé et la demande sans réponse', nExp === 2, String(nExp));
  check('S4-42 : statuts expirés', (await q(`select count(*)::int n from quote_requests where status = 'expired'`))[0].n === 2);
  check('S4-42 : demandeur et prestataire notifiés', (await notifs(U(11), 'Devis expiré')) === 1 && (await notifs(U(12), 'Devis expiré')) === 2);
  await as(U(12));
  await fails('S4-42 : expire_quotes réservée au cron', `select expire_quotes()`, /permission|denied/);
  await as(U(11));
  await fails('S4-42 : devis expiré, acceptation refusée', `select decide_quote('${q2}', true, null)`, /a expiré/);
  const q3 = (await q(`select request_quote_offer('${logo}', 'Troisième demande de logo propre', 15000, '') id`))[0].id;
  await as(U(12));
  await q(`select answer_quote('${q3}', 16000, 4, 'Valable')`);
  await as(U(11));
  check('S4-42 : devis valide accepté', (await q(`select decide_quote('${q3}', true, 16000) r`))[0].r === 'accepted');

  // S4-41 : contact lié au devis
  await as(U(12));
  const cid = (await q(`select quote_contact('${q3}', 'Pouvez-vous préciser les couleurs souhaitées ?') id`))[0].id;
  check('S4-41 : le prestataire écrit au demandeur', !!cid);
  await as(U(11));
  const cid2 = (await q(`select quote_contact('${q3}', 'Bleu et blanc.') id`))[0].id;
  check('S4-41 : même conversation pour la réponse', cid2 === cid);
  check('S4-41 : deux messages dans la conversation', (await q(`select count(*)::int n from messages where conversation_id = '${cid}'`))[0].n === 2);
  await as(U(17));
  await fails('S4-41 : un tiers ne peut pas écrire', `select quote_contact('${q3}', 'Bonjour')`, /introuvable/);
  await as(U(12));
  await fails('S4-41 : message vide refusé', `select quote_contact('${q3}', '  ')`, /vide/);
  await db.exec('reset role');
  await db.exec(`insert into user_blocks (blocker_id, blocked_id) values ('${U(11)}', '${U(12)}')`);
  await as(U(12));
  await fails('S4-41 : blocage respecté (chat_guard)', `select quote_contact('${q3}', 'Encore un message')`, /ne peut pas recevoir/);
  await db.exec('reset role');
  await db.exec(`delete from user_blocks`);
  await db.exec(`update quote_requests set status = 'cancelled' where id = '${q1}'`);
  await as(U(12));
  await fails('S4-41 : demande annulée, pas de contact', `select quote_contact('${q1}', 'Bonjour')`, /annulée/);

  // S4-44/46/47 : my_quotes
  await as(U(11));
  const ord = (await q(`select quote_checkout('${q3}') r`))[0].r;
  await as(U(12));
  const mq = (await q(`select my_quotes() r`))[0].r;
  const row = mq.find((x) => x.id === q3);
  check('S4-44 : le prestataire voit la commande née du devis et son état', row && row.order_number === ord.number && row.order_state === 'pending', JSON.stringify(row));
  check('S4-46 : demandeur nommé en abrégé', row && row.requester_name === 'Profil C.' && row.valid_until != null);
  await as(U(17));
  check('S4-46 : un tiers ne voit pas ce devis', !(await q(`select my_quotes() r`))[0].r.some((x) => x.id === q3));

  // ====================================================== MISSIONS
  const need = (uid, t, bmin, bmax) => q(`select save_mission(null, '${t}', 'Un besoin décrit avec plus de vingt caractères', ${bmin}, ${bmax}, '2027-01-31', true, 'besoin') id`);
  await as(U(11));
  const M1 = (await need(U(11), 'Mission un', 50000, 100000))[0].id;
  const M2 = (await need(U(11), 'Mission deux', 'null', 'null'))[0].id;
  await as(U(12));
  const P12 = (await q(`select propose_on_mission('${M1}', 90000, 12, 'Équipe A') id`))[0].id;
  await as(U(17));
  const P17 = (await q(`select propose_on_mission('${M1}', 80000, 10, 'Équipe B') id`))[0].id;
  // S4-117/S4-114 : besoins ouverts
  const on = (await q(`select open_needs() r`))[0].r;
  const m1o = on.find((x) => x.id === M1);
  check('S4-114 : besoin ouvert avec description et sans identifiant client', m1o && /vingt caractères/.test(m1o.description) && !('client_id' in m1o) && m1o.my_status === 'submitted', JSON.stringify(m1o));
  await as(U(11));
  check('S4-117 : son propre besoin n est pas dans open_needs', (await q(`select jsonb_array_length((select jsonb_agg(e) from jsonb_array_elements(open_needs()) e where e->>'id' = '${M1}')) n`))[0].n === null);
  await as(U(19));
  await fails('S4-117 : un client (non talent) ne lit pas les besoins ouverts', `select open_needs()`, /Réservé aux talents/);

  // S4-95 : attribution
  await as(U(12));
  await fails('S4-95 : un talent n attribue pas', `select assign_mission('${M1}', null, '${P12}', null)`, /Réservé/);
  await as(U(13));
  await fails('S4-95 : choix obligatoire quand plusieurs propositions', `select assign_mission('${M1}')`, /Choisissez la proposition/);
  check('S4-95 : attribution d une proposition', (await q(`select assign_mission('${M1}', null, '${P12}', null) r`))[0].r === 'assigned');
  await db.exec('reset role');
  const st = (await q(`select (select status from missions where id='${M1}') ms, (select status from mission_proposals where id='${P12}') p12, (select status from mission_proposals where id='${P17}') p17,
    (select count(*)::int from mission_milestones where mission_id='${M1}') jal, (select assigned_team from missions where id='${M1}') team,
    (select invoice_number from mission_agreements where mission_id='${M1}') inv, (select amount from mission_agreements where mission_id='${M1}') amt`))[0];
  check('S4-95 : mission attribuée, proposition acceptée, autre déclinée', st.ms === 'assigned' && st.p12 === 'accepted' && st.p17 === 'declined', JSON.stringify(st));
  check('S4-95 : trois jalons et accord numéroté', st.jal === 3 && /^MI-\d{4}-\d{5}$/.test(st.inv) && st.amt === 90000 && st.team === 'Profil C.', JSON.stringify(st));
  check('S4-95 : le talent retenu est notifié', (await notifs(U(12), 'Mission attribuée')) === 1);
  check('S4-115 : le talent non retenu est notifié', (await notifs(U(17), 'Proposition non retenue')) === 1);
  check('S4-95 : le client est notifié', (await notifs(U(11), 'Besoin attribué')) === 1);
  await as(U(13));
  await fails('S4-95 : déjà attribué', `select assign_mission('${M1}', null, '${P12}', null)`, /pas attribuable/);
  await fails('S4-95 : besoin sans budget et sans proposition', `select assign_mission('${M2}', null, null, '${U(12)}')`, /pas de budget/);
  const M3 = (await (async () => { await as(U(11)); return need(U(11), 'Mission trois', 40000, 60000); })())[0].id;
  await as(U(13));
  await fails('S4-95 : le demandeur ne peut pas être le prestataire', `select assign_mission('${M3}', null, null, '${U(11)}')`, /propre besoin/);
  await fails('S4-95 : un client non talent ne peut pas être choisi', `select assign_mission('${M3}', null, null, '${U(19)}')`, /introuvable ou indisponible/);
  check('S4-95 : attribution directe à un talent (proposition créée)', (await q(`select assign_mission('${M3}', 'Équipe Design', null, '${U(12)}') r`))[0].r === 'assigned');
  await db.exec('reset role');
  const d3 = (await q(`select (select count(*)::int from mission_milestones where mission_id='${M3}') jal, (select amount from mission_proposals where mission_id='${M3}' and author_id='${U(12)}' and status='accepted') amt, (select assigned_team from missions where id='${M3}') team`))[0];
  check('S4-95 : attribution directe : jalons, montant du budget max, équipe saisie', d3.jal === 3 && d3.amt === 60000 && d3.team === 'Équipe Design', JSON.stringify(d3));

  // S4-98 / S4-100 : preuve et ordre
  await as(U(12));
  await fails('S4-98 : livraison sans preuve refusée', `select submit_milestone('${M1}', 1::smallint)`, /Joignez une preuve/);
  await fails('S4-98 : preuve trop courte refusée', `select submit_milestone('${M1}', 1::smallint, 'ok', '{}')`, /Joignez une preuve/);
  await fails('S4-100 : jalons dans l ordre', `select submit_milestone('${M1}', 2::smallint, 'Livraison du deuxième jalon complète', '{}')`, /précédent/);
  await as(U(17));
  await fails('S4-98 : seul le prestataire retenu livre', `select submit_milestone('${M1}', 1::smallint, 'Livraison du premier jalon complète', '{}')`, /introuvable/);
  await db.exec('reset role');
  await db.exec(`insert into storage.objects (bucket_id, name, owner_id) values ('project-files', '${U(12)}/mission/maquette.png', '${U(12)}'), ('project-files', '${U(17)}/mission/autre.png', '${U(17)}')`);
  await as(U(12));
  const f1 = (await q(`select register_file('mission', '${M1}', '${U(12)}/mission/maquette.png', 'maquette.png', 'image/png', 12345) id`))[0].id;
  await as(U(17));
  await fails('S4-98 : fichier hors dossier refusé', `select register_file('mission', '${M1}', '${U(17)}/mission/autre.png', 'autre.png', 'image/png', 100)`, /Dossier introuvable/);
  await as(U(12));
  check('S4-98 : livraison avec texte et photo', (await q(`select submit_milestone('${M1}', 1::smallint, 'Moodboard et trois pistes de logo livrés', array['${f1}']::uuid[]) r`))[0].r === 'submitted');
  await fails('S4-98 : déjà livré', `select submit_milestone('${M1}', 1::smallint, 'Livraison du premier jalon complète', '{}')`, /déjà livré/);
  await db.exec('reset role');
  const pj = (await q(`select proof_note, proof_files, submitted_at is not null as sa from mission_milestones where mission_id='${M1}' and position = 1`))[0];
  check('S4-98 : preuve enregistrée (texte, fichier, date)', /Moodboard/.test(pj.proof_note) && pj.proof_files.length === 1 && pj.proof_files[0] === f1 && pj.sa);
  check('S4-98 : le client est notifié du jalon livré', (await notifs(U(11), 'Jalon livré')) === 1);
  await as(U(11));
  const needs = (await q(`select my_needs() r`))[0].r;
  const jm = needs.find((x) => x.id === M1).milestones[0];
  check('S4-98 : le client voit la preuve avant de valider', /Moodboard/.test(jm.proof_note) && jm.proof_files.length === 1 && jm.proof_files[0].name === 'maquette.png', JSON.stringify(jm));
  await fails('S4-92 : paiement déclaré seulement après validation', `select milestone_pay_declare('${M1}', 1::smallint, 'Orange Money', 'OM123')`, /jalon validé/);
  await q(`select decide_milestone('${M1}', 1::smallint, true, '')`);
  await fails('S4-92 : moyen de paiement obligatoire', `select milestone_pay_declare('${M1}', 1::smallint, '', '')`, /moyen de paiement/);
  await as(U(17));
  await fails('S4-92 : un tiers ne déclare pas', `select milestone_pay_declare('${M1}', 1::smallint, 'Orange Money', 'OM123')`, /introuvable/);
  await as(U(11));
  check('S4-92 : le client déclare le paiement du jalon', (await q(`select milestone_pay_declare('${M1}', 1::smallint, 'Orange Money', 'OM123') r`))[0].r === 'declared');
  check('S4-92 : le prestataire est notifié', (await notifs(U(12), 'Paiement déclaré')) === 1);
  await as(U(11));
  await fails('S4-92 : le client ne confirme pas à la place du prestataire', `select milestone_pay_confirm('${M1}', 1::smallint, true)`, /introuvable/);
  await as(U(12));
  await fails('S4-92 : rien à confirmer sur un autre jalon', `select milestone_pay_confirm('${M1}', 2::smallint, true)`, /Aucun paiement déclaré/);
  check('S4-92 : le prestataire signale un paiement non reçu', (await q(`select milestone_pay_confirm('${M1}', 1::smallint, false) r`))[0].r === 'unpaid');
  await as(U(11));
  await q(`select milestone_pay_declare('${M1}', 1::smallint, 'MTN MoMo', 'MM789')`);
  await as(U(12));
  check('S4-92 : le prestataire confirme la réception', (await q(`select milestone_pay_confirm('${M1}', 1::smallint, true) r`))[0].r === 'confirmed');
  await as(U(11));
  await fails('S4-92 : paiement confirmé, plus de déclaration', `select milestone_pay_declare('${M1}', 1::smallint, 'MTN MoMo', 'MM790')`, /déjà confirmé/);
  check('S4-92 : le client est notifié de la confirmation', (await notifs(U(11), 'Paiement confirmé')) === 1);

  // jalons 2 et 3, clôture, facture
  await as(U(12));
  await q(`select submit_milestone('${M1}', 2::smallint, 'Propositions détaillées livrées au client', '{}')`);
  await as(U(11));
  await q(`select decide_milestone('${M1}', 2::smallint, false, 'Merci de reprendre la palette')`);
  await as(U(12));
  check('S4-98 : jalon à corriger redélivrable', (await q(`select submit_milestone('${M1}', 2::smallint, 'Palette reprise et validée en interne', '{}') r`))[0].r === 'submitted');
  await as(U(11));
  await q(`select decide_milestone('${M1}', 2::smallint, true, '')`);
  await as(U(12));
  await q(`select submit_milestone('${M1}', 3::smallint, 'Livraison finale : fichiers sources et guide', '{}')`);
  await as(U(11));
  await fails('S4-120 : pas de clôture avant la fin', `select mission_close('${M1}')`, /tous les jalons/);
  await q(`select decide_milestone('${M1}', 3::smallint, true, '')`);
  check('S4-120 : mission livrée', (await q(`select status from missions where id='${M1}'`))[0].status === 'delivered');
  await as(U(12));
  await fails('S4-120 : seul le client clôture', `select mission_close('${M1}')`, /introuvable/);
  await as(U(11));
  check('S4-120 : le client clôture la mission', (await q(`select mission_close('${M1}') r`))[0].r === 'closed');
  check('S4-120 : le prestataire est prévenu', (await notifs(U(12), 'Mission clôturée')) === 1);
  await as(U(11));
  const invC = (await q(`select mission_invoice('${M1}') r`))[0].r;
  check('S4-92 : facture de mission côté client (nom du client, montants)', invC.number === st.inv && invC.client_name === 'Profil C.' && invC.agreed_amount === 90000 && invC.confirmed_amount === 27000 && invC.validated_amount === 90000, JSON.stringify(invC));
  await as(U(12));
  const invP = (await q(`select mission_invoice('${M1}') r`))[0].r;
  check('S4-92 : facture côté prestataire sans identité du client', /non communiquée/.test(invP.client_name) && invP.provider_name === 'Profil C.' && /ne bloque ni ne verse/.test(invP.notice), JSON.stringify(invP));
  await as(U(17));
  await fails('S4-92 : facture invisible pour un tiers', `select mission_invoice('${M1}')`, /introuvable/);

  // S4-89 : un talent à la fois client et prestataire voit ses deux missions
  await as(U(18));
  const M4 = (await need(U(18), 'Besoin du talent dix-huit', 20000, 30000))[0].id;
  await as(U(11));
  const M5 = (await need(U(11), 'Mission cinq', 10000, 15000))[0].id;
  await as(U(18));
  const P18 = (await q(`select propose_on_mission('${M5}', 14000, 5, 'Je prends') id`))[0].id;
  await as(U(11));
  await q(`select decide_proposal('${P18}', true)`);
  await as(U(18));
  const mm = (await q(`select my_missions() r`))[0].r;
  const asClient = mm.find((x) => x.id === M4), asProvider = mm.find((x) => x.id === M5);
  check('S4-89 : my_missions renvoie la mission du client ET celle du prestataire', asClient && asClient.role === 'client' && asProvider && asProvider.role === 'provider', JSON.stringify(mm.map((x) => [x.id, x.role])));
  check('S4-89 : le prestataire ne voit pas l identité du client', asProvider.counterpart === null && asProvider.milestones.length === 3);
  await as(U(11));
  const mc = (await q(`select my_missions() r`))[0].r.find((x) => x.id === M5);
  check('S4-89 : le client voit le nom du prestataire', mc.role === 'client' && mc.counterpart === 'Profil C.' && mc.agreement.invoice_number.startsWith('MI-'));

  // S4-99 : propositions et retrait
  await as(U(17));
  const mp = (await q(`select my_proposals() r`))[0].r;
  check('S4-99 : mes propositions avec le titre et l état', mp.some((p) => p.mission_id === M1 && p.status === 'declined' && p.title === 'Mission un'), JSON.stringify(mp));
  await as(U(11));
  const M6 = (await need(U(11), 'Mission six', 10000, 20000))[0].id;
  await as(U(17));
  const P6 = (await q(`select propose_on_mission('${M6}', 15000, 7, 'Ma proposition') id`))[0].id;
  await as(U(12));
  await fails('S4-99 : on ne retire pas la proposition d autrui', `select withdraw_proposal('${P6}')`, /introuvable/);
  await as(U(17));
  check('S4-99 : retrait d une proposition en attente', (await q(`select withdraw_proposal('${P6}') r`))[0].r === 'withdrawn');
  check('S4-99 : le client est prévenu du retrait', (await notifs(U(11), 'Proposition retirée')) === 1);
  await as(U(17));
  await fails('S4-99 : proposition déjà traitée', `select withdraw_proposal('${P6}')`, /déjà traitée/);
  check('S4-99 : on peut proposer de nouveau après un retrait', (await q(`select propose_on_mission('${M6}', 16000, 7, '') id`)).length === 1);

  // S4-103 : dossier de mission
  await as(U(12));
  await db.exec('reset role');
  await db.exec(`insert into user_blocks (blocker_id, blocked_id) values ('${U(18)}', '${U(11)}')`);
  await as(U(11));
  await fails('S4-103 : un client bloqué par le prestataire ne peut plus écrire', `select send_mission_message('${M5}', 'Bonjour', null)`, /ne peut pas recevoir/);
  await db.exec('reset role');
  await db.exec(`delete from user_blocks`);
  await as(U(11));
  check('S4-103 : sans blocage, le message passe', (await q(`select send_mission_message('${M5}', 'Merci pour le travail', null) id`)).length === 1);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${U(11)}'`);
  await as(U(11));
  await fails('S4-103 : compte suspendu refusé', `select send_mission_message('${M5}', 'Encore', null)`, /suspendu/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${U(11)}'`);

  // S4-106 : relance après 7 jours
  await as(U(18));
  await q(`select submit_milestone('${M5}', 1::smallint, 'Premier jalon de la mission cinq livré', '{}')`);
  await db.exec('reset role');
  await db.exec(`update mission_milestones set submitted_at = now() - interval '8 days' where mission_id = '${M5}' and position = 1`);
  check('S4-106 : remind_milestones relance une fois', (await q(`select remind_milestones() n`))[0].n === 1 && (await q(`select remind_milestones() n`))[0].n === 0);
  check('S4-106 : client et prestataire informés', (await notifs(U(11), 'Jalon en attente de votre décision')) === 1 && (await notifs(U(18), 'Relance envoyée au client')) === 1);

  // S4-73 : relevé de ventes
  await db.exec(`select set_config('app.internal','1',false)`);
  await db.exec(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, cod) values ('#BE-S-1', '${U(19)}', 25000, 0, 'Mobile Money', 0, true, false, false), ('#BE-S-2', '${U(19)}', 25000, 0, 'Mobile Money', 0, true, false, false)`);
  const lamp = (await q(`select id from listings where title='Lampe en bois'`))[0].id;
  await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty, fulfillment) select id, '${lamp}', 'Lampe en bois', 25000, 1, 2 from orders where number in ('#BE-S-1', '#BE-S-2')`);
  await db.exec(`update orders set cancelled_at = now(), cancelled = true where number = '#BE-S-2'`);
  await db.exec(`select set_config('app.internal','',false)`);
  await as(U(12));
  const stm = (await q(`select seller_statement(null, null) r`))[0].r;
  check('S4-73 : relevé : ventes payées non annulées, montant brut', stm.sales.length === 1 && stm.sales[0].number === '#BE-S-1' && stm.sales[0].total === 25000, JSON.stringify(stm.sales));
  check('S4-73 : relevé : missions réglées confirmées', stm.missions.length === 1 && stm.missions[0].amount === 27000 && stm.missions[0].title === 'Mission un', JSON.stringify(stm.missions));
  await as(U(17));
  const stm2 = (await q(`select seller_statement(null, null) r`))[0].r;
  check('S4-73 : relevé : rien pour un autre vendeur', stm2.sales.length === 0 && stm2.missions.length === 0);
  await fails('S4-73 : période inversée refusée', `select seller_statement(current_date, current_date - 5)`, /Période invalide/);
  await fails('S4-73 : période trop longue refusée', `select seller_statement(current_date - 800, current_date)`, /trop longue/);
  await as(null, 'anon');
  await fails('anonyme : my_missions refusé', `select my_missions()`, /permission|denied/);
  await fails('anonyme : seller_statement refusé', `select seller_statement(null, null)`, /permission|denied/);

  // ====================================================== S4-121 et SQL1G2-1 : répartition de l'argent d'une commande
  await db.exec('reset role');
  for (const n of [41, 42]) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Vendeur ${n}','student','u${n}@t.cm')`);
  await as(U(41));
  await q(`select shop_save('{"name":"Boutique Quarante","description":"Bois","logo_url":"https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/boutique/logo.png","categories":["Maison"]}'::jsonb) s`);
  await q(`select shop_submit()`);
  await as(U(14));
  await q(`select shop_decide((select id from shops where owner_id = '${U(41)}'), 'approve')`);
  await db.exec('reset role');
  await db.exec(`insert into listings(seller_id,title,department,category,price,stock,status,images) values
    ('${U(41)}','Lampe boutique A','Génie civil','Maison',100000,9,'approved','{a,b,c}'),
    ('${U(42)}','Sac vendeur B','Design','Mode',100000,9,'approved','{}'),
    (null,'Livre plateforme','Design','Livres',5000,9,'approved','{}')`);
  const lA = (await q(`select id, shop_id from listings where title = 'Lampe boutique A'`))[0], lB = (await q(`select id from listings where title = 'Sac vendeur B'`))[0].id;
  check('promo : l annonce de A est rattachée à sa boutique, pas celle de B', lA.shop_id !== null && (await q(`select shop_id from listings where id = '${lB}'`))[0].shop_id === null);
  await as(U(41));
  await q(`select promo_save('A90', 'percent', 90)`);
  await as(U(19));
  const oPromo = (await q(`select marketplace_checkout('[{"id":"${lA.id}","qty":1},{"id":"${lB}","qty":1}]'::jsonb, false, 'Mobile Money', null, 'A90', 'cle-promo-0001') o`))[0].o;
  check('promo boutique : remise de 90 000 sur le panier de 200 000', oPromo.discount === 90000 && oPromo.subtotal === 110000, JSON.stringify(oPromo));
  await db.exec('reset role');
  check('promo boutique : la boutique du code est mémorisée sur la commande', (await q(`select promo_shop_id from orders where number = '${oPromo.number}'`))[0].promo_shop_id === lA.shop_id);
  await db.exec(`update orders set paid = true where number = '${oPromo.number}'`);
  const eA = (await q(`select gross, beneficiary_amount b, institution_amount i, platform_amount p from money_entries where order_id = (select id from orders where number = '${oPromo.number}') and beneficiary_id = '${U(41)}' and kind = 'order'`))[0];
  const eB = (await q(`select gross, beneficiary_amount b, institution_amount i, platform_amount p from money_entries where order_id = (select id from orders where number = '${oPromo.number}') and beneficiary_id = '${U(42)}' and kind = 'order'`))[0];
  check('SQL1G2-1 : le vendeur de la boutique porte seul la remise (100 000 - 90 000 = 10 000, 70/20/10)', eA && eA.gross === 10000 && eA.b === 7000 && eA.i === 2000 && eA.p === 1000, JSON.stringify(eA));
  check('SQL1G2-1 : le vendeur B garde 100 000 brut, 70/20/10 inchangé', eB && eB.gross === 100000 && eB.b === 70000 && eB.i === 20000 && eB.p === 10000, JSON.stringify(eB));
  // promotion de la plateforme : répartie sur tout le panier comme avant
  await as(U(14));
  await q(`select promo_save('PLAT10', 'percent', 10, 0, null, null, true, true)`);
  await as(U(19));
  const oPlat = (await q(`select marketplace_checkout('[{"id":"${lA.id}","qty":1},{"id":"${lB}","qty":1}]'::jsonb, false, 'Mobile Money', null, 'PLAT10', 'cle-promo-0002') o`))[0].o;
  await db.exec('reset role');
  check('promo plateforme : aucune boutique mémorisée', (await q(`select promo_shop_id from orders where number = '${oPlat.number}'`))[0].promo_shop_id === null && oPlat.discount === 20000);
  await db.exec(`update orders set paid = true where number = '${oPlat.number}'`);
  const pl = await q(`select beneficiary_id, gross from money_entries where order_id = (select id from orders where number = '${oPlat.number}') and kind = 'order' order by beneficiary_id`);
  check('promo plateforme : chaque vendeur supporte 10 % au prorata (90 000 chacun)', pl.length === 2 && pl.every((r) => r.gross === 90000), JSON.stringify(pl));

  // frais de livraison rattachés aux vendeurs
  await db.exec(`insert into delivery_zones (seller_id, to_city, fee) values ('${U(41)}', 'Douala', 1000), ('${U(42)}', 'Douala', 2000)`);
  await db.exec(`select set_config('app.internal','1',false)`);
  const mkOrder = async (num, fee, cod, lines) => {
    await db.exec(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, cod, delivery_address) values ('${num}', '${U(19)}', 0, ${fee}, 'Mobile Money', 0, false, true, ${cod}, '{"city":"Douala","line":"Rue 1"}'::jsonb)`);
    for (const [lid, price] of lines) await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty, fulfillment) select id, '${lid}', 'x', ${price}, 1, 0 from orders where number = '${num}'`);
  };
  await mkOrder('#BE-D-1', 3000, false, [[lA.id, 100000], [lB, 100000]]);
  await mkOrder('#BE-D-2', 4500, false, [[lA.id, 100000], [lB, 100000]]);
  await mkOrder('#BE-D-3', 3000, true, [[lA.id, 100000], [lB, 100000]]);
  const lPf = (await q(`select id from listings where title = 'Livre plateforme'`))[0].id;
  await db.exec(`insert into delivery_zones (seller_id, to_city, fee) values (null, 'Douala', 1500)`);
  await mkOrder('#BE-D-4', 1500, false, [[lPf, 5000]]);
  await db.exec(`select set_config('app.internal','',false)`);
  for (const n of ['#BE-D-1', '#BE-D-2', '#BE-D-3', '#BE-D-4']) await db.exec(`update orders set paid = true where number = '${n}'`);
  const dl = async (n) => q(`select beneficiary_id, gross, beneficiary_amount b, institution_amount i, platform_amount p, status from money_entries where order_id = (select id from orders where number = '${n}') and kind = 'delivery' order by gross`);
  const d1 = await dl('#BE-D-1');
  check('S4-121 : frais 3 000 répartis selon les tarifs des vendeurs (1 000 / 2 000), 100 % au vendeur', d1.length === 2 && d1[0].gross === 1000 && d1[0].beneficiary_id === U(41) && d1[1].gross === 2000 && d1[1].beneficiary_id === U(42) && d1.every((r) => r.b === r.gross && r.i === 0 && r.p === 0), JSON.stringify(d1));
  const d2 = await dl('#BE-D-2');
  check('S4-121 : frais différents des tarifs : répartis au prorata, somme exacte (1 500 / 3 000)', d2.length === 2 && d2[0].gross + d2[1].gross === 4500 && d2[0].gross === 1500, JSON.stringify(d2));
  check('S4-121 : paiement à la livraison : aucune ligne de livraison', (await dl('#BE-D-3')).length === 0);
  const d4 = await dl('#BE-D-4');
  check('S4-121 : la plateforme qui livre encaisse les frais (ligne plateforme libérée)', d4.length === 1 && d4[0].beneficiary_id === null && d4[0].p === 1500 && d4[0].status === 'released', JSON.stringify(d4));
  check('S4-121 : la ligne de livraison du vendeur est sous séquestre comme la vente', d1.every((r) => r.status === 'held'));
  await db.exec(`update orders set paid = true where number = '#BE-D-1'`);
  check('S4-121 : rejouer le paiement ne duplique rien', (await dl('#BE-D-1')).length === 2);
  const tot = (await q(`select sum(gross)::int s from money_entries where order_id = (select id from orders where number = '#BE-D-1')`))[0].s;
  check('S4-121 : encaissé (articles + livraison) = réparti', tot === 203000, String(tot));

  await db.exec('reset role');
  console.log(`\n${ok} OK, ${ko} ECHEC`);
}
