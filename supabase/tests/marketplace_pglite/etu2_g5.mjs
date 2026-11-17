// Scénario PGlite de 20261119050000_g5_notifications_etudiant.sql (lot G5 : notifications et interactions de l'étudiant-vendeur).
//   Copie : robocopy ...\supabase C:\tmp\fixroot2\G5\supabase /E /XD functions ; puis depuis tests\marketplace_pglite : node replay.mjs all ./etu2_g5.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, false, e.message); } };

  const STU = U(61), STU2 = U(62), CLI = U(63), COA = U(64), COU = U(65), DEP = U(66), ADM = U(67), SUS = U(68), CLI2 = U(69);
  await db.exec('reset role');
  const mk = async (id, nm, role, extra = '') => {
    await db.exec(`insert into auth.users(id,email) values ('${id}','u${id.slice(-2)}@t.cm')`);
    await db.exec(`insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','u${id.slice(-2)}@t.cm')`);
    if (extra) await db.exec(`update profiles set ${extra} where id = '${id}'`);
  };
  await mk(STU, 'Alice Dupont', 'student', `skills = 'Flutter', department = 'Génie', phone = '677000061'`);
  await mk(STU2, 'Bob Martin', 'student', `skills = 'Flutter', department = 'Génie', phone = '677000062'`);
  await mk(CLI, 'Claire Client', 'client'); await mk(CLI2, 'Cyril Client', 'client');
  await mk(COA, 'Orange Cameroun', 'company'); await mk(COU, 'Faux Entrepreneur', 'company');
  await mk(DEP, 'Daniel Dept', 'dept'); await mk(ADM, 'Admin Root', 'admin'); await mk(SUS, 'Suspendu Student', 'student', 'suspended = true');
  await db.exec(`insert into company_profiles(owner_id, company_name, status) values ('${COA}', 'Orange Cameroun', 'approved'), ('${COU}', 'Faux Entrepreneur SARL', 'pending')`);
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) select id, 'student_card', 'c', id || '/c.pdf', 'application/pdf', 10, 'verified' from profiles where id in ('${STU}', '${STU2}')`);
  await db.exec(`insert into cv_links(token, owner_id, consent_at) values ('${'a'.repeat(32)}', '${STU}', now())`);
  const nbNotifs = async (uid, kind) => Number((await q(`select count(*) c from notifications where user_id = '${uid}' and kind = '${kind}'`))[0].c);
  const ins = (uid, kind, title, body) => db.exec(`insert into notifications (user_id, kind, title, body, data) values ('${uid}', '${kind}', '${title}', '${body}', '{}')`);

  // --- 1. Types importants : non désactivables par la catégorie
  await as(STU);
  await q(`select set_notification_preference('inapp', 'cat:orders', false)`);
  await q(`select set_notification_preference('inapp', 'cat:reviews', false)`);
  await db.exec('reset role');
  await ins(STU, 'order', 'Nouvelle commande', 'Commande C1 à préparer.');
  await ins(STU, 'money', 'Argent débloqué', '1000 FCFA disponibles.');
  await ins(STU, 'payout', 'Versement prévu', '5000 FCFA vous seront versés.');
  await ins(STU, 'claim', 'Réclamation', 'Message');
  await ins(STU, 'refund', 'Annulation', 'Commande annulée');
  await ins(STU, 'review', 'Nouvel avis', '5/5');
  check('catégorie « commandes » coupée : une commande simple est filtrée', (await nbNotifs(STU, 'order')) === 0);
  check('catégorie « commandes » coupée : argent, retrait, réclamation et remboursement arrivent', (await nbNotifs(STU, 'money')) === 1 && (await nbNotifs(STU, 'payout')) === 1 && (await nbNotifs(STU, 'claim')) === 1 && (await nbNotifs(STU, 'refund')) === 1);
  check('catégorie « avis » coupée : un avis est encore filtré (comportement conservé)', (await nbNotifs(STU, 'review')) === 0);
  await as(STU2);
  await q(`select set_notification_preference('inapp', 'cat:orders', false)`);
  await db.exec('reset role');
  await ins(STU2, 'order', 'Nouvelle commande', 'x');
  check('un autre compte garde le filtrage des commandes simples', (await nbNotifs(STU2, 'order')) === 0);
  await as(STU2);
  await q(`select set_notification_preference('inapp', 'cat:orders', true)`);
  await db.exec('reset role');

  // --- 2. SMS / WhatsApp : numéro vérifié seulement
  await as(STU);
  await fails('SMS : refusé tant que le numéro n\'est pas vérifié', `select set_notification_preference('sms', '*', true)`, /Vérifiez d'abord votre numéro/);
  await fails('WhatsApp : refusé tant que le numéro n\'est pas vérifié', `select set_notification_preference('whatsapp', '*', true)`, /Vérifiez d'abord votre numéro/);
  await fails('numéro WhatsApp non vérifié refusé', `select set_whatsapp_number('+237699999999')`, /numéro de téléphone vérifié/);
  await db.exec('reset role');
  await db.exec(`insert into notification_preferences (user_id, channel, kind, enabled) values ('${STU}', 'sms', '*', true), ('${STU}', 'whatsapp', '*', true), ('${STU}', 'email', '*', true)`);
  await db.exec(`select set_config('app.phone_verify_rpc', '1', false)`);
  await ins(STU, 'payout', 'Versement', 'x');
  check('téléphone non vérifié : aucun SMS ni WhatsApp en file (même avec un consentement ancien)', Number((await q(`select count(*) c from notification_outbox where user_id = '${STU}' and channel in ('sms','whatsapp')`))[0].c) === 0);
  check('téléphone non vérifié : l\'e-mail part toujours', Number((await q(`select count(*) c from notification_outbox where user_id = '${STU}' and channel = 'email'`))[0].c) >= 1);
  await db.exec(`update profiles set phone_verified = true where id = '${STU}'`);
  await db.exec(`select set_config('app.phone_verify_rpc', '', false)`);
  check('téléphone vérifié (banc)', (await q(`select phone_verified from profiles where id = '${STU}'`))[0].phone_verified === true);
  await as(STU);
  await fails('WhatsApp : un autre numéro que le numéro vérifié est refusé', `select set_whatsapp_number('+237699999999')`, /numéro de téléphone vérifié/);
  await works('WhatsApp : le numéro vérifié est accepté', `select set_whatsapp_number('677000061')`);
  await works('SMS : activable avec un numéro vérifié', `select set_notification_preference('sms', '*', true)`);
  await db.exec('reset role');
  await ins(STU, 'claim', 'Réclamation', 'Bonjour');
  const sms = await q(`select to_address from notification_outbox where user_id = '${STU}' and channel = 'sms' order by id desc limit 1`);
  const wa = await q(`select to_address from notification_outbox where user_id = '${STU}' and channel = 'whatsapp' order by id desc limit 1`);
  check('SMS : envoyé vers le numéro vérifié', sms.length === 1 && sms[0].to_address === '+237677000061', JSON.stringify(sms));
  check('WhatsApp : envoyé vers le numéro vérifié', wa.length === 1 && wa[0].to_address === '+237677000061', JSON.stringify(wa));

  // --- 3. Plafond quotidien
  await as(STU);
  await q(`select set_notification_preference('inapp', 'cat:orders', true)`);
  await db.exec('reset role');
  for (let i = 0; i < 8; i++) await ins(STU, 'quote', `Devis ${i}`, 'x');
  const smsN = Number((await q(`select count(*) c from notification_outbox where user_id = '${STU}' and channel = 'sms' and kind = 'quote'`))[0].c);
  const total = Number((await q(`select count(*) c from notification_outbox where user_id = '${STU}' and channel = 'sms'`))[0].c);
  check('plafond : au plus 5 SMS par 24 h', total === 5 && smsN === 5 - (total - smsN), `total=${total} quote=${smsN}`);
  await ins(STU, 'security', 'Double authentification désactivée', 'x');
  await ins(STU, 'money', 'Argent débloqué', 'x');
  check('plafond : sécurité et argent passent toujours', Number((await q(`select count(*) c from notification_outbox where user_id = '${STU}' and channel = 'sms' and kind in ('security','money')`))[0].c) === 2);
  check('plafond : toutes ces notifications restent dans l\'application', (await nbNotifs(STU, 'quote')) === 8);

  // --- 4. Texte sortant sans coordonnées
  await ins(STU, 'money', 'Retrait', 'Versé sur MTN 677 12 34 56 ou contact@exemple.cm ; commande 20261117-0012, 150000 FCFA, tel +237 699 88 77 66.');
  const o = (await q(`select body from notification_outbox where user_id = '${STU}' and channel = 'email' and kind = 'money' order by id desc limit 1`))[0];
  check('sortant : numéros et e-mails masqués', o && !/677 12|contact@|699 88/.test(o.body) && (o.body.match(/\[numéro masqué\]/g) || []).length === 2 && /\[e-mail masqué\]/.test(o.body), o?.body);
  check('sortant : numéro de commande et montant conservés', /20261117-0012/.test(o.body) && /150000 FCFA/.test(o.body), o?.body);
  check('dans l\'application : le texte reste entier', /contact@exemple\.cm/.test((await q(`select body from notifications where user_id = '${STU}' and kind = 'money' order by created_at desc, id desc limit 1`))[0].body));

  // --- 5. Interactions : blocages respectés
  await as(COA);
  await works('entreprise approuvée : contact d\'un talent visible', `select talent_contact_request('${STU}', 'contact', 'Bonjour') r`);
  await as(CLI);
  await works('client : contact d\'un talent', `select talent_contact_request('${STU}', 'contact', 'Bonjour client') r`);
  await as(COU);
  await fails('entreprise non approuvée : toujours refusée', `select talent_contact_request('${STU}', 'contact', 'x') r`, /vérifiée par l'administrateur/);
  await as(STU);
  await q(`select block_user('${COA}', true)`);
  await as(COA);
  await fails('entreprise bloquée : plus de demande de contact', `select talent_contact_request('${STU}', 'internship_offer', 'Stage de six mois chez nous') r`, /Talent introuvable/);
  await as(CLI2);
  await works('un autre client non bloqué contacte toujours', `select talent_contact_request('${STU}', 'contact', 'Bonjour') r`);
  await as(STU);
  await q(`select block_user('${COA}', false)`);
  await as(COA);
  await works('déblocage : la demande repasse', `select talent_contact_request('${STU}', 'internship_offer', 'Stage de six mois chez nous') r`);
  await as(STU);
  await q(`select block_user('${COA}', true)`);
  await db.exec('reset role');
  const OPP = '00000000-0000-0000-0000-0000000000a1';
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status) values ('${OPP}', '${COA}', 'Orange Cameroun', 'stage', 'Stage dev', 'published')`);
  await as(COA);
  await fails('invitation à postuler : entreprise bloquée refusée', `select opp_invite('${OPP}', '${STU}', 'Venez') r`, /Étudiant introuvable/);
  await as(STU);
  await q(`select block_user('${COA}', false)`);
  await as(COA);
  await works('invitation à postuler : possible une fois débloquée', `select opp_invite('${OPP}', '${STU}', 'Venez') r`);
  await as(STU);
  await works('l\'étudiant voit l\'invitation reçue', `select opp_my_invites() r`);

  await db.exec('reset role');
  const LST = '00000000-0000-0000-0000-0000000000b1';
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values ('${LST}', '${STU}', 'Lampe', 'Génie', 5000, 'approved')`);
  await as(STU);
  await q(`select block_user('${CLI}', true)`);
  await as(CLI);
  await fails('question produit : client bloqué refusé', `select ask_question('${LST}', 'Est-elle encore disponible ?') r`, /Produit introuvable/);
  await as(CLI2);
  await works('question produit : un autre client la pose', `select ask_question('${LST}', 'Est-elle encore disponible ?') r`);
  await as(STU);
  await fails('question produit : le vendeur ne se pose pas de question', `select ask_question('${LST}', 'Ma propre question ?') r`, /propre produit/);
  await as(null, 'anon');
  await fails('question produit : un anonyme est refusé', `select ask_question('${LST}', 'Est-elle encore disponible ?') r`, /Connexion requise|permission denied/);
  await as(ADM);
  await works('administrateur : peut contacter un talent', `select talent_contact_request('${STU}', 'contact', 'Admin') r`);
  await as(DEP);
  await works('département : peut contacter un talent', `select talent_contact_request('${STU}', 'contact', 'Dept') r`);

  await db.exec('reset role');
  console.log(`\n${ok} OK, ${ko} ECHEC`);
  if (ko) process.exitCode = 1;
}
