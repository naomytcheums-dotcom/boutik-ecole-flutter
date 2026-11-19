// Scénario PGlite du lot F4 : page publique d'entreprise, achats B2B (facturation) et négociation de devis.
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000f40${String(n).padStart(2, '0')}`;
  const E = U(1), D = U(2), R = U(3), P = U(4), S = U(5), C = U(6), M = U(7), SUS = U(8), A = U(9), F = U(10), V = U(11), X = U(12), PRV = U(13), O = U(14);
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  const users = [[E, 'Orange Cameroun', 'company'], [D, 'Brouillon SARL', 'company'], [R, 'Refusee SA', 'company'], [P, 'Pending SA', 'company'], [S, 'Sara Etudiante', 'student'], [C, 'Carl Client', 'client'],
    [M, 'Mod Admin', 'admin'], [SUS, 'Suspendue SA', 'company'], [A, 'Alice Admin', 'client'], [F, 'Fabrice Finance', 'student'], [V, 'Vero Lectrice', 'client'], [X, 'Xavier Externe', 'client'],
    [PRV, 'Paul Prestataire', 'student'], [O, 'Ong Organisation', 'other']];
  for (const [id, nm, role] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name, registration_number, review_note, description)
    values ('${E}', 'Orange Cameroun', 'approved', 'Telecoms', 'Douala', '699000111', 'Mme N', 'RC/DLA/2020/B/1', 'note interne', 'Operateur'),
           ('${D}', 'Brouillon SARL', 'draft', 'Tech', 'Yaounde', '698', 'M D', 'RC1', null, 'Brouillon'),
           ('${R}', 'Refusee SA', 'rejected', 'Tech', 'Yaounde', '697', 'M R', 'RC2', 'Pieces illisibles', 'Refusee'),
           ('${P}', 'Pending SA', 'pending', 'Tech', 'Yaounde', '696', 'M P', 'RC3', null, 'En attente'),
           ('${SUS}', 'Suspendue SA', 'approved', 'Tech', 'Douala', '695', 'M S', 'RC4', null, 'Suspendue'),
           ('${O}', 'Ong Organisation', 'approved', 'Social', 'Douala', '694', 'M O', 'RC5', null, 'ONG')`);
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await db.exec(`insert into opportunities (poster_id, org_name, kind, title, status, deadline) values
      ('${E}', 'Orange Cameroun', 'stage', 'Stage developpeur', 'published', null),
      ('${E}', 'Orange Cameroun', 'emploi', 'Offre expiree', 'published', current_date - 3),
      ('${E}', 'Orange Cameroun', 'emploi', 'Brouillon cache', 'pending', null)`);
  await db.exec(`insert into contest_announcements (poster_id, title, organizer, kind, official_url, status) values
      ('${E}', 'Defi Orange', 'Orange', 'contest', 'https://orange.cm/defi', 'published'),
      ('${E}', 'Defi en attente', 'Orange', 'contest', 'https://orange.cm/defi2', 'pending')`);
  await db.exec(`insert into missions (number, client_id, kind, title, description, total, status) values
      ('M-F4-1', '${E}', 'besoin', 'Site web', 'Refonte du site', 0, 'published'),
      ('M-F4-2', '${E}', 'besoin', 'Brouillon besoin', 'x', 0, 'draft'),
      ('M-F4-3', '${E}', 'besoin', 'Besoin attribue', 'y', 0, 'assigned'),
      ('M-F4-4', '${E}', 'mission', 'Brief departement', 'z', 0, 'published')`);
  await db.exec(`insert into opportunity_applications (opportunity_id, applicant_id, status) select id, '${S}', 'hired' from opportunities where title = 'Stage developpeur'`);

  // ============================================================ A. page publique
  await as(S);
  const pub = (await q(`select company_public('${E}') r`))[0].r;
  check('page : fiche approuvee visible d un etudiant', pub.company_name === 'Orange Cameroun' && pub.verified === true && pub.sector === 'Telecoms' && pub.mine === false && pub.status === null);
  check('page : jamais RCCM, telephone, interlocuteur, note de refus', ['registration_number', 'phone', 'contact_name', 'review_note', 'tax_id', 'billing_address', 'billing_email'].every((k) => pub[k] === undefined));
  check('page : seules les offres publiees et non expirees', pub.offers.length === 1 && pub.offers[0].title === 'Stage developpeur' && pub.offers_open === 1);
  check('page : seuls les defis publies', pub.contests.length === 1 && pub.contests[0].title === 'Defi Orange' && pub.contests_open === 1);
  check('page : seuls les besoins publies (ni brouillon, ni attribue, ni brief de departement)', pub.needs.length === 1 && pub.needs[0].title === 'Site web' && pub.needs_open === 1);
  check('page : recrutes reels', pub.recruits === 1);
  for (const [who, name] of [[D, 'brouillon'], [R, 'refusee'], [P, 'en attente'], [SUS, 'titulaire suspendu']]) {
    check(`page : fiche ${name} invisible des autres (company_public)`, (await q(`select company_public('${who}') r`))[0].r === null);
    check(`page : fiche ${name} invisible des autres (company_profile_view)`, (await q(`select company_profile_view('${who}') r`))[0].r === null);
  }
  check('page : fiche inexistante = meme reponse que fiche cachee', (await q(`select company_public('${U(99)}') r`))[0].r === null);
  const view = (await q(`select company_profile_view('${E}') r`))[0].r;
  check('vue : meme contenu pour un connecte', view.company_name === 'Orange Cameroun' && view.registration_number === undefined);
  check('page : organisation (role other) approuvee visible', (await q(`select company_public('${O}') r`))[0].r.company_name === 'Ong Organisation');
  await as(D);
  const mineD = (await q(`select company_profile_view() r`))[0].r;
  check('page : le proprietaire voit sa fiche brouillon avec son statut', mineD.company_name === 'Brouillon SARL' && mineD.mine === true && mineD.status === 'draft');
  await as(R);
  check('page : le proprietaire voit le statut refuse mais pas la note', (await q(`select company_public('${R}') r`))[0].r.status === 'rejected' && (await q(`select company_public('${R}') r`))[0].r.review_note === undefined);
  await as(M);
  check('page : l administrateur voit une fiche en attente avec son statut', (await q(`select company_public('${P}') r`))[0].r.status === 'pending');
  await as(null, 'anon');
  const anonPub = (await q(`select company_public('${E}') r`))[0].r;
  check('visiteur : fiche approuvee visible sans liste de besoins', anonPub.company_name === 'Orange Cameroun' && anonPub.needs === null && anonPub.needs_open === null && anonPub.offers.length === 1);
  check('visiteur : fiche brouillon invisible', (await q(`select company_public('${D}') r`))[0].r === null);
  await fails('visiteur : company_profile_view reservee aux connectes', `select company_profile_view('${E}')`, /permission denied/);

  // ============================================================ B. achats B2B
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'approved', phone_verified = true where id = '${PRV}'`);
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${E}', 'entreprise', 'active', now(), now() + interval '30 days')`);
  await as(E);
  await q(`select company_invite('Alice@t.cm', 'admin')`);
  await q(`select company_invite('Fabrice@t.cm', 'finance')`);
  await q(`select company_invite('Vero@t.cm', 'viewer')`);
  for (const w of [A, F, V]) { await as(w); await q(`select company_member_respond('${E}', true)`); }
  await db.exec('reset role');
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${PRV}','Creation de logo','Design','Services',20000,99,'approved','{}')`);
  const logo = (await q(`select id from listings where title='Creation de logo'`))[0].id;

  await as(V);
  await fails('facturation : un lecteur ne la lit pas', `select company_billing_get('${E}')`, /Réservé/);
  await fails('facturation : un lecteur ne la modifie pas', `select company_billing_set('{"tax_id":"M1"}'::jsonb, '${E}')`, /Réservé/);
  await as(X);
  await fails('facturation : un tiers n y a pas acces', `select company_billing_get('${E}')`, /Accès refusé/);
  await fails('facturation : un tiers ne la modifie pas', `select company_billing_set('{"tax_id":"M1"}'::jsonb, '${E}')`, /Accès refusé/);
  await as(E);
  await fails('facturation : NIU invalide', `select company_billing_set('{"tax_id":"M1;drop"}'::jsonb)`, /NIU invalide/);
  await fails('facturation : e-mail invalide', `select company_billing_set('{"billing_email":"pas-un-mail"}'::jsonb)`, /e-mail de facturation invalide/);
  await fails('facturation : adresse trop longue', `select company_billing_set(jsonb_build_object('billing_address', repeat('a', 201)))`, /Adresse trop longue/);
  const set = (await q(`select company_billing_set('{"tax_id":"M0123456789","billing_address":"Rue 1.2, Bonanjo","billing_city":"Douala","billing_email":"Compta@Orange.cm"}'::jsonb) r`))[0].r;
  check('facturation : le proprietaire enregistre son identite', set.tax_id === 'M0123456789' && set.email === 'compta@orange.cm' && set.company_name === 'Orange Cameroun' && set.address === 'Rue 1.2, Bonanjo');
  await as(F);
  check('facturation : la finance la lit', (await q(`select company_billing_get('${E}') r`))[0].r.tax_id === 'M0123456789');
  const pubAfter = (await q(`select company_public('${E}') r`))[0].r;
  check('facturation : jamais publique', pubAfter.tax_id === undefined && pubAfter.billing_address === undefined);

  // commande d'un compte Entreprise : rattachee automatiquement a sa fiche
  await as(E);
  const qE = (await q(`select request_quote_offer('${logo}', 'Un logo pour notre agence', 15000, '2 semaines') id`))[0].id;
  await as(PRV);
  await q(`select answer_quote('${qE}', 18000, 5, 'Trois propositions')`);
  await as(E);
  await q(`select decide_quote('${qE}', true)`);
  const oE = (await q(`select quote_checkout('${qE}') r`))[0].r;
  check('achat B2B : commande creee au prix du devis', oE.subtotal === 18000);
  const bE = (await q(`select order_billing_get('${oE.number}') r`))[0].r;
  check('achat B2B : un compte entreprise est facture au nom de l entreprise', bE && bE.company_name === 'Orange Cameroun' && bE.tax_id === 'M0123456789' && bE.registration_number === 'RC/DLA/2020/B/1' && bE.city === 'Douala');
  check('achat B2B : l identite de facturation ne contient ni telephone ni interlocuteur', bE.phone === undefined && bE.contact_name === undefined);
  // la commande d'un client ordinaire n'est pas rattachee
  await as(C);
  const qC = (await q(`select request_quote_offer('${logo}', 'Un logo pour moi seul', 15000, 'vite') id`))[0].id;
  await as(PRV);
  await q(`select answer_quote('${qC}', 17000, 4, 'ok')`);
  await as(C);
  await q(`select decide_quote('${qC}', true)`);
  const oC = (await q(`select quote_checkout('${qC}') r`))[0].r;
  check('client : sa facture reste personnelle (aucune identite entreprise)', (await q(`select order_billing_get('${oC.number}') r`))[0].r === null);
  // un membre finance n'est PAS facture a l'entreprise sans l'avoir choisi
  await as(F);
  const qF1 = (await q(`select request_quote_offer('${logo}', 'Logo pour mon usage perso', 15000, 'vite') id`))[0].id;
  await as(PRV);
  await q(`select answer_quote('${qF1}', 16000, 3, 'ok')`);
  await as(F);
  await q(`select decide_quote('${qF1}', true)`);
  const oF1 = (await q(`select quote_checkout('${qF1}') r`))[0].r;
  check('membre finance : sans choix, achat personnel (non rattache)', (await q(`select order_billing_get('${oF1.number}') r`))[0].r === null);
  await as(V);
  await fails('achat au nom de l entreprise : refuse a un lecteur', `select company_billing_context_set('${E}')`, /Seuls le propriétaire/);
  await as(X);
  await fails('achat au nom de l entreprise : refuse a un tiers', `select company_billing_context_set('${E}')`, /Seuls le propriétaire/);
  await as(F);
  check('achat au nom de l entreprise : la finance le choisit', (await q(`select company_billing_context_set('${E}') r`))[0].r === E);
  check('achat au nom de l entreprise : contexte lu', (await q(`select company_billing_context_get() r`))[0].r.owner_id === E);
  // second devis (nouvelle demande apres la premiere acceptee)
  await db.exec('reset role');
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${PRV}','Affiche publicitaire','Design','Services',9000,99,'approved','{}')`);
  const aff = (await q(`select id from listings where title='Affiche publicitaire'`))[0].id;
  await as(F);
  const qF2 = (await q(`select request_quote_offer('${aff}', 'Affiche pour le salon de l entreprise', 9000, 'vite') id`))[0].id;
  await as(PRV);
  await q(`select answer_quote('${qF2}', 9500, 2, 'ok')`);
  await as(F);
  await q(`select decide_quote('${qF2}', true)`);
  const oF2 = (await q(`select quote_checkout('${qF2}') r`))[0].r;
  const bF2 = (await q(`select order_billing_get('${oF2.number}') r`))[0].r;
  check('membre finance : achat au nom de l entreprise rattache a la fiche', bF2 && bF2.company_name === 'Orange Cameroun' && bF2.tax_id === 'M0123456789');
  await as(E);
  check('equipe : le proprietaire lit la facturation d une commande de la finance', (await q(`select order_billing_get('${oF2.number}') r`))[0].r.company_name === 'Orange Cameroun');
  await as(V);
  check('equipe : un lecteur ne lit pas la facturation d une commande de l entreprise', (await q(`select order_billing_get('${oF2.number}') r`))[0].r === null);
  await as(X);
  check('tiers : aucune facturation de l entreprise', (await q(`select order_billing_get('${oF2.number}') r`))[0].r === null && (await q(`select order_billing_get('${oE.number}') r`))[0].r === null);
  // liste « Achats de l'entreprise »
  await as(E);
  const lE = (await q(`select company_orders_list() r`))[0].r;
  check('achats : le proprietaire voit les commandes de l entreprise (les siennes et celles de la finance)', lE.length === 2 && lE.some((o) => o.number === oE.number) && lE.some((o) => o.number === oF2.number));
  check('achats : etat, total, facture, articles reels', lE.every((o) => o.state === 'pending' && o.invoice_number.startsWith('FA-') && o.total > 0 && o.items.length === 1));
  check('achats : jamais la commande personnelle de la finance ni celle d un client', !lE.some((o) => o.number === oF1.number || o.number === oC.number));
  await as(F);
  check('achats : la finance voit la liste', (await q(`select company_orders_list('${E}') r`))[0].r.length === 2);
  await as(A);
  check('achats : un administrateur voit la liste', (await q(`select company_orders_list('${E}') r`))[0].r.length === 2);
  await as(V);
  await fails('achats : un lecteur n a pas acces', `select company_orders_list('${E}')`, /Réservé/);
  await as(X);
  await fails('achats : un tiers n a pas acces', `select company_orders_list('${E}')`, /Accès refusé/);
  await as(C);
  check('achats : un client sans entreprise obtient une liste vide', (await q(`select company_orders_list() r`))[0].r.length === 0);
  // facture : identite rafraichie tant que non payee, figee ensuite
  await as(E);
  await q(`select company_billing_set('{"tax_id":"M9999999999","billing_address":"Nouvelle adresse"}'::jsonb)`);
  check('facture : identite a jour tant que la commande n est pas payee', (await q(`select order_billing_get('${oE.number}') r`))[0].r.tax_id === 'M9999999999');
  await db.exec('reset role');
  await db.exec(`select set_config('app.internal','1',false)`);
  await db.exec(`update orders set paid = true where number = '${oE.number}'`);
  await as(E);
  await q(`select company_billing_set('{"tax_id":"M1111111111"}'::jsonb)`);
  check('facture : identite figee une fois la commande payee', (await q(`select order_billing_get('${oE.number}') r`))[0].r.tax_id === 'M9999999999');
  check('achats : commande payee', (await q(`select company_orders_list() r`))[0].r.find((o) => o.number === oE.number).state === 'paid');
  await as(F);
  check('achat au nom de l entreprise : retour a l achat personnel', (await q(`select company_billing_context_set(null) r`))[0].r === null);
  // un membre retire perd le droit meme avec un contexte enregistre
  await as(E);
  await q(`select company_member_remove('${F}', '${E}')`);
  await db.exec('reset role');
  await db.exec(`insert into company_billing_context (user_id, owner_id) values ('${F}', '${E}') on conflict (user_id) do update set owner_id = excluded.owner_id`);
  await as(F);
  check('membre retire : le contexte enregistre ne donne plus rien', (await q(`select company_billing_context_get() r`))[0].r === null);

  // ============================================================ C. negociation de devis
  await db.exec('reset role');
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${PRV}','Montage video','Audiovisuel','Services',30000,99,'approved','{}')`);
  const vid = (await q(`select id from listings where title='Montage video'`))[0].id;
  await as(C);
  const qid = (await q(`select request_quote_offer('${vid}', 'Un montage video pour notre evenement', 40000, '3 semaines') id`))[0].id;
  let t = (await q(`select quote_thread('${qid}') r`))[0].r;
  check('devis : le fil commence par la demande', t.messages.length === 1 && t.messages[0].kind === 'event' && /Demande de devis/.test(t.messages[0].body) && t.my_role === 'requester');
  check('devis : actions du demandeur avant devis', t.can.write === true && t.can.accept === false && t.can.cancel === true && t.can.revise === false);
  await as(X);
  await fails('devis : un tiers ne lit pas le fil', `select quote_thread('${qid}')`, /introuvable/);
  await fails('devis : un tiers n ecrit pas', `select quote_message_send('${qid}', 'coucou')`, /introuvable/);
  await as(C);
  await fails('devis : message vide refuse', `select quote_message_send('${qid}', '   ')`, /Message vide/);
  await fails('devis : message trop long refuse', `select quote_message_send('${qid}', repeat('a', 1001))`, /trop long/);
  await q(`select quote_message_send('${qid}', 'Pouvez-vous faire un geste sur le prix ?')`);
  await as(PRV);
  check('devis : le prestataire est notifie (type quote, avec le devis)', (await q(`select count(*)::int n from notifications where user_id='${PRV}' and kind='quote' and data->>'quote_id' = '${qid}' and title = 'Nouveau message sur un devis'`))[0].n === 1);
  t = (await q(`select quote_thread('${qid}') r`))[0].r;
  check('devis : le prestataire lit le fil et peut reviser', t.my_role === 'provider' && t.messages.length === 2 && t.messages[1].kind === 'message' && t.messages[1].mine === false && t.can.revise === true && t.can.reject === true);
  await q(`select answer_quote('${qid}', 38000, 10, 'Premier devis')`);
  await q(`select quote_message_send('${qid}', 'Je peux descendre a 35000 si livraison en 3 semaines')`);
  await q(`select answer_quote('${qid}', 35000, 15, 'Contre-proposition')`);
  t = (await q(`select quote_thread('${qid}') r`))[0].r;
  const ev = t.messages.filter((m) => m.kind === 'event').map((m) => m.body);
  check('devis : devis et contre-proposition consignes dans le fil (prix et delai)', ev.some((b) => /Devis du prestataire : 38 000 FCFA en 10 jour/.test(b)) && ev.some((b) => /Contre-proposition du prestataire : 35 000 FCFA en 15 jour/.test(b)));
  await as(C);
  t = (await q(`select quote_thread('${qid}') r`))[0].r;
  check('devis : le demandeur peut accepter ou refuser le devis recu', t.can.accept === true && t.can.decline === true && t.quote.quote_amount === 35000);
  check('devis : le demandeur est notifie du devis (notification existante)', (await q(`select count(*)::int n from notifications where user_id='${C}' and kind='quote' and title='Devis reçu' and data->>'quote_id' = '${qid}'`))[0].n === 2);
  await as(M);
  t = (await q(`select quote_thread('${qid}') r`))[0].r;
  check('devis : l administration lit le fil sans pouvoir ecrire', t.my_role === 'staff' && t.can.write === false && t.messages.length >= 4);
  await fails('devis : l administration n ecrit pas dans le fil', `select quote_message_send('${qid}', 'moderation')`, /introuvable/);
  await as(C);
  await q(`select decide_quote('${qid}', true, 35000)`);
  t = (await q(`select quote_thread('${qid}') r`))[0].r;
  check('devis : acceptation consignee, fil encore ouvert, plus d action de decision', t.messages.some((m) => /Devis accepté par le demandeur : 35 000 FCFA/.test(m.body)) && t.can.write === true && t.can.accept === false && t.can.cancel === false);
  await q(`select quote_message_send('${qid}', 'Merci, on passe commande')`);
  // limite de debit par devis (12 par heure et par expediteur)
  await db.exec('reset role');
  await db.exec(`delete from messages where sender_id = '${C}'`);
  let n = (await q(`select count(*)::int n from quote_messages where quote_id='${qid}' and sender_id='${C}' and kind='message'`))[0].n;
  await as(C);
  for (let i = n; i < 12; i++) await q(`select quote_message_send('${qid}', 'message ${i}')`);
  await fails('devis : plafond de messages par heure', `select quote_message_send('${qid}', 'un de trop')`, /Trop de messages/);
  // demande annulee : fil clos
  await db.exec('reset role');
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${PRV}','Photos produit','Photo','Services',12000,99,'approved','{}')`);
  const ph = (await q(`select id from listings where title='Photos produit'`))[0].id;
  await as(C);
  const q2 = (await q(`select request_quote_offer('${ph}', 'Photos de vingt produits', 12000, 'vite') id`))[0].id;
  await q(`select cancel_quote('${q2}')`);
  t = (await q(`select quote_thread('${q2}') r`))[0].r;
  check('devis annule : evenement consigne, plus d ecriture', t.messages.some((m) => /Demande annulée/.test(m.body)) && t.can.write === false && t.can.cancel === false);
  await fails('devis annule : message refuse', `select quote_message_send('${q2}', 'encore ?')`, /clôturée/);
  // demande declinee par le prestataire
  await as(X);
  const q3 = (await q(`select request_quote_offer('${ph}', 'Photos de trente produits', 12000, 'vite') id`))[0].id;
  await as(PRV);
  await q(`select decline_quote('${q3}', 'Agenda complet')`);
  await as(X);
  t = (await q(`select quote_thread('${q3}') r`))[0].r;
  check('devis decline : motif consigne dans le fil', t.messages.some((m) => /déclinée par le prestataire : Agenda complet/.test(m.body)) && t.can.write === false);
  // compte suspendu
  await as(M);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${PRV}'`);
  await as(C);
  const q4 = (await q(`select quote_thread('${qid}') r`))[0].r;
  check('devis : lecture du fil toujours possible', q4.messages.length > 3);
  await db.exec('reset role');
  await db.exec(`delete from quote_messages where quote_id='${qid}' and kind='message' and sender_id='${C}'`);
  await as(C);
  await fails('devis : interlocuteur suspendu injoignable', `select quote_message_send('${qid}', 'Allo ?')`, /plus joignable/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${PRV}'; update profiles set suspended = true where id = '${C}'`);
  await as(C);
  await fails('devis : expediteur suspendu refuse', `select quote_message_send('${qid}', 'Allo ?')`, /suspendu/);
  // visiteur
  await as(null, 'anon');
  await fails('devis : visiteur sans acces au fil', `select quote_thread('${qid}')`, /permission denied/);
  await fails('devis : visiteur sans acces aux messages', `select quote_message_send('${qid}', 'x')`, /permission denied/);
  await fails('achats : visiteur sans acces', `select company_orders_list()`, /permission denied/);
  await db.exec('reset role');
  console.log(`\nent_f4: ${ok}/${ok + ko}`);
}
