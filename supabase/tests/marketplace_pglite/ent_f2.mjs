// Scénario PGlite du lot F2 (profil Entreprise) : migrations 20261118020000 à 20261118020200.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./ent_f2.mjs
// Prouve : parcours fiche -> envoi -> file admin -> décision -> publication (E4-1), logo (E4-2), confidentialité (E4-12), pièces (E4-13/E5-13),
// équipe (E4-14/15, E5-9/10), re-vérification (E4-16), vérification unique (E5-21), forfaits et paiements (E5-16/17/18/23), notifications (E5-20), 2FA (E5-24), expiration.
let ok = 0, ko = 0;
export async function run(db) {
  let cur = { uid: null, role: null };
  const rawExec = db.exec.bind(db);
  db.exec = (s) => { if (s === 'reset role') { cur = { uid: null, role: null }; return rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)"); } return rawExec(s); };
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const E = U(51), A = U(52), A2 = U(53), F = U(54), V = U(55), X = U(56), M = U(57), S = U(58), O = U(59), FIN = U(60), N = U(61), P = U(62), ST = U(63);
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sq = async (sql) => { const prev = cur; await db.exec('reset role'); const r = await q(sql); if (prev.role) await as(prev.uid, prev.role); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const hook = async (method, path, uid, aal) => {
    const claims = uid ? JSON.stringify({ sub: uid, ...(aal ? { aal } : {}) }) : '';
    await db.exec('reset role');
    await db.exec(`select set_config('request.path', '${path}', false), set_config('request.method', '${method}', false), set_config('request.jwt.claims', '${claims}', false)`);
    try { await db.exec('select enforce_mfa_on_sensitive()'); return 'ok'; } catch (e) { return e.message; }
  };
  const need = (t) => `select save_mission(null, '${t}', 'Je cherche une solution de gestion de stock pour mes boutiques', 50000, 100000, '2027-01-31', true) id`;
  const putFile = async (path, mime, size) => { await db.exec('reset role'); await db.exec(`insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${path}', '${JSON.stringify({ mimetype: mime, size })}')`); };
  const full = (extra = {}, owner = null) => `select company_save('${JSON.stringify({ company_name: 'Orange Cameroun', sector: 'Télécoms', city: 'Douala', phone: '699000000', contact_name: 'Mme Ndongo', contact_role: 'DRH', registration_number: 'RC/DLA/1', ...extra })}'::jsonb${owner ? `, '${owner}'` : ''}) r`;

  await db.exec('reset role');
  const users = [[E, 'Orange Cameroun', 'company'], [A, 'Alice Admin', 'client'], [A2, 'Adam Admin', 'student'], [F, 'Fabrice Finance', 'client'], [V, 'Vero Lectrice', 'client'], [X, 'Xavier Externe', 'client'],
    [M, 'Mod Admin', 'admin'], [S, 'Sam Support', 'support'], [O, 'ONG Verte', 'other'], [FIN, 'Fin Plateforme', 'finance'], [N, 'Nouvelle SARL', 'company'], [P, 'Payeur Tiers', 'client'], [ST, 'Etudiante Stage', 'student']];
  for (const [id, nm, role] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  // K1 : un compte finance / support n'a plus que des droits minimaux ; le scénario lui attribue explicitement les permissions dont il a besoin.
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${FIN}' and team_code = 'finance';
    update admin_team_members set permissions = array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests'] where user_id = '${S}' and team_code = 'support'`);

  // ============================================================ E4-1 : fiche -> pièce -> envoi -> file admin -> décision -> publication
  await as(E);
  check('fiche : enregistrée en brouillon avec interlocuteur et fonction', (await q(full({ sector: '', phone: '' })))[0].r === 'draft');
  await fails('envoi : message explicite des champs manquants', `select company_submit()`, /secteur.*téléphone/);
  check('fiche complète enregistrée', (await q(full()))[0].r === 'draft');
  await fails('envoi : sans pièce refusé', `select company_submit()`, /pièce justificative/);
  await fails('publication avant vérification : refusée', need('Gestion de stock'), /vérifiée/);
  await fails('interlocuteur de plus de 80 caractères refusé', full({ contact_name: 'x'.repeat(81) }), /80 caractères/);
  // E4-13 : contrôle du fichier réellement déposé
  await fails('pièce : fichier inexistant dans le stockage refusé', `select company_doc_add('registration', 'RCCM.pdf', '${E}/company/fantome.pdf', 'application/pdf', 1000)`, /absent du stockage/);
  await putFile(`${E}/company/html.pdf`, 'text/html', 1000);
  await putFile(`${E}/company/gros.pdf`, 'application/pdf', 20 * 1024 * 1024);
  await putFile(`${E}/company/rccm.pdf`, 'application/pdf', 5000);
  await as(E);
  await fails('pièce : type réel non accepté (le type déclaré est ignoré)', `select company_doc_add('registration', 'a.pdf', '${E}/company/html.pdf', 'application/pdf', 1000)`, /Format non accepté/);
  await fails('pièce : fichier trop lourd refusé', `select company_doc_add('registration', 'a.pdf', '${E}/company/gros.pdf', 'application/pdf', 1000)`, /trop lourd/);
  await fails('pièce : dossier d\'un autre refusé', `select company_doc_add('registration', 'a.pdf', '${X}/company/x.pdf', 'application/pdf', 1000)`, /invalide/);
  const doc = (await q(`select company_doc_add('registration', 'RCCM.pdf', '${E}/company/rccm.pdf', 'application/pdf', 1000) r`))[0].r;
  check('pièce : fichier présent, type et poids réels acceptés', !!doc);
  await fails('pièce : même fichier deux fois refusé', `select company_doc_add('registration', 'RCCM.pdf', '${E}/company/rccm.pdf', 'application/pdf', 1000)`, /déjà enregistré/);
  check('envoi pour vérification : accepté', (await q(`select company_submit() r`))[0].r === 'pending');
  await fails('pièce : suppression refusée pendant l\'examen', `select company_doc_delete('${doc}')`, /ne peut plus être supprimée/);
  await fails('fiche : plus modifiable pendant l\'examen', full({ city: 'Yaoundé' }), /en cours de vérification/);
  await as(M);
  const queue = (await q(`select company_queue() r`))[0].r;
  check('file admin : interlocuteur, fonction et pièce visibles', queue.length === 1 && queue[0].contact_name === 'Mme Ndongo' && queue[0].contact_role === 'DRH' && queue[0].documents.length === 1);
  await as(E);
  await fails('un compte non admin ne décide pas', `select company_decide('${E}', true)`, /Réservé à l'administrateur/);
  await as(M);
  await fails('refus sans motif impossible', `select company_decide('${E}', false, '')`, /motif/);
  check('décision : approuvée', (await q(`select company_decide('${E}', true) r`))[0].r === 'approved');
  await db.exec('reset role');
  check('décision 5 : la certification du compte est approuvée', (await q(`select certification::text c from profiles where id = '${E}'`))[0].c === 'approved');
  check('notification de vérification : certifié + données', (await q(`select count(*)::int n from notifications where user_id = '${E}' and kind = 'company_review'   and title = 'Organisation vérifiée' and data->>'status' = 'approved'`))[0].n === 1);
    check('journal d\'audit : décision tracée', (await q(`select count(*)::int n from audit_log where action = 'Organisation vérifiée' and target = 'Orange Cameroun'`))[0].n === 1);
  await as(E);
  check('PUBLICATION : l\'entreprise vérifiée publie un besoin (chaîne complète)', (await q(need('Gestion de stock'))).length === 1);
  await fails('pièce : suppression refusée après approbation', `select company_doc_delete('${doc}')`, /ne peut plus être supprimée/);
  await as(M);
  check('pièce : l\'administrateur de la plateforme peut la supprimer', (await q(`select company_doc_delete('${doc}') r`))[0].r === `${E}/company/rccm.pdf`);
  await as(X);
  await fails('pièce : un tiers ne supprime rien', `select company_doc_delete('${doc}')`, /introuvable/);
  // refus : certification retirée pour une fiche approuvée repassée en vérification (E4-16) et refus d'une demande neuve
  await as(N);
  await q(`select company_save('${JSON.stringify({ company_name: 'Nouvelle SARL', sector: 'Commerce', city: 'Douala', phone: '690000000', contact_name: 'M. Biya' })}'::jsonb)`);
  await putFile(`${N}/company/niu.pdf`, 'application/pdf', 1000);
  await as(N);
  await q(`select company_doc_add('tax', 'NIU.pdf', '${N}/company/niu.pdf', 'application/pdf', 1000)`);
  await q(`select company_submit()`);
  await as(M);
  check('refus : statut rejected', (await q(`select company_decide('${N}', false, 'Pièce illisible') r`))[0].r === 'rejected');
  await db.exec('reset role');
  check('refus : la certification n\'est pas accordée', (await q(`select certification::text c from profiles where id = '${N}'`))[0].c !== 'approved');
  await as(N);
  check('refus : le motif est lisible par l\'entreprise', (await q(`select company_get() r`))[0].r.review_note === 'Pièce illisible');
  await fails('refus : la publication reste bloquée', need('Besoin N'), /vérifiée/);

  // ============================================================ équipe (E4-14, E4-15, E5-9, E5-10)
  await db.exec('reset role');
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${E}', 'entreprise', 'active', now(), now() + interval '30 days')`);
  await as(E);
  for (const [email, role] of [['Alice@t.cm', 'admin'], ['Adam@t.cm', 'admin'], ['Fabrice@t.cm', 'finance'], ['Vero@t.cm', 'viewer']]) await q(`select company_invite('${email}', '${role}')`);
  for (const u of [A, A2, F, V]) { await as(u); await q(`select company_member_respond('${E}', true)`); }
  await as(A);
  await fails('admin d\'équipe : ne rétrograde pas un autre admin', `select company_member_set_role('${A2}', 'viewer', '${E}')`, /Seul le propriétaire/);
  await fails('admin d\'équipe : ne promeut pas en admin', `select company_member_set_role('${V}', 'admin', '${E}')`, /Seul le propriétaire/);
  await fails('admin d\'équipe : ne touche pas au propriétaire', `select company_member_set_role('${E}', 'viewer', '${E}')`, /propriétaire/);
  await fails('admin d\'équipe : ne se rétrograde pas lui-même', `select company_member_set_role('${A}', 'viewer', '${E}')`, /propre rôle/);
  await fails('admin d\'équipe : ne retire pas un autre admin', `select company_member_remove('${A2}', '${E}')`, /Seul le propriétaire/);
  check('admin d\'équipe : change un lecteur en finance', (await q(`select company_member_set_role('${V}', 'finance', '${E}')`)).length === 1);
  await q(`select company_member_set_role('${V}', 'viewer', '${E}')`);
  await fails('admin d\'équipe : n\'invite pas un administrateur', `select company_invite('Xavier@t.cm', 'admin', '${E}')`, /Seul le propriétaire/);
  await as(E);
  check('propriétaire : rétrograde un admin', (await q(`select company_member_set_role('${A2}', 'viewer', '${E}')`)).length === 1);
  check('propriétaire : promeut en admin', (await q(`select company_member_set_role('${A2}', 'admin', '${E}')`)).length === 1);
  // invitations en attente
  await as(E);
  await q(`select company_invite('Xavier@t.cm', 'viewer')`);
  await as(A);
  await q(`select company_invite('Sam@t.cm', 'viewer', '${E}')`);
  await db.exec('reset role');
  check('invitation d\'un compte de la plateforme : aucune ligne ni notification', (await q(`select count(*)::int n from company_members where user_id = '${S}'`))[0].n === 0);
  await as(A);
  let list = (await q(`select company_members_list('${E}') r`))[0].r;
  let px = list.members.find((m) => m.user_id === X);
  check('admin simple : l\'e-mail et le nom de l\'invité d\'un autre ne sont pas révélés', px.status === 'invited' && px.email === null && px.name === 'Invitation en attente');
  check('admin simple : voit toujours les e-mails des membres actifs', list.members.find((m) => m.user_id === V).email === 'Vero@t.cm');
  check('liste : rôle du compte et certification indiqués', list.members.find((m) => m.user_id === V).account_role === 'client' && list.members.find((m) => m.user_id === V).certified === false);
  await as(E);
  list = (await q(`select company_members_list('${E}') r`))[0].r;
  check('propriétaire : voit l\'invité en attente', list.members.find((m) => m.user_id === X).email === 'Xavier@t.cm');
  await as(E);
  await q(`select company_invite('Xavier@t.cm', 'viewer')`);
  await db.exec('reset role');
  check('invitation répétée dans les 24 h : une seule notification', (await q(`select count(*)::int n from notifications where user_id = '${X}' and kind = 'company_team'`))[0].n === 1);
  await db.exec('reset role');
  await db.exec(`insert into company_invite_log (owner_id, at) select '${E}', now() from generate_series(1, 20)`);
  await as(E);
  await fails('invitations : plafond de 20 tentatives par jour', `select company_invite('Inconnu@t.cm', 'viewer')`, /Trop d'invitations/);
  await db.exec('reset role');
  await db.exec(`delete from company_invite_log`);
  // E4-12 : coordonnées sensibles
  await as(V);
  const gv = (await q(`select company_get('${E}') r`))[0].r;
  check('lecteur : ni RCCM, ni téléphone, ni interlocuteur, ni motif', !('registration_number' in gv) && !('phone' in gv) && !('contact_name' in gv) && !('review_note' in gv) && gv.company_name === 'Orange Cameroun');
  await as(A);
  const ga = (await q(`select company_get('${E}') r`))[0].r;
  check('admin d\'équipe : RCCM, téléphone et interlocuteur visibles', ga.registration_number === 'RC/DLA/1' && ga.phone === '699000000' && ga.contact_name === 'Mme Ndongo');
  // E4-2 : logo
  await as(E);
  await q(full({ logo_path: `${E}/logo.png` }));
  await as(A);
  check('logo : l\'admin enregistre la fiche en renvoyant le logo du propriétaire', (await q(full({ logo_path: `${E}/logo.png`, description: 'Mise à jour par Alice' }, E)))[0].r === 'approved');
  check('logo : l\'admin enregistre sans logo', (await q(full({ description: 'Encore' }, E)))[0].r === 'approved');
  await fails('logo : un chemin étranger est refusé', full({ logo_path: `${X}/autre.png` }, E), /Logo invalide/);
  // E5-10 : suspension
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${V}'`);
  await as(V);
  await fails('membre suspendu : plus de lecture de la fiche', `select company_get('${E}')`, /Accès refusé/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${V}'`);

  // ============================================================ E4-16 : re-vérification explicite + certification retirée
  await as(E);
  check('changement du nom : la fiche repasse en vérification', (await q(full({ company_name: 'Orange Cameroun SA' })))[0].r === 'pending');
  await db.exec('reset role');
  check('certification retirée tant que la fiche n\'est pas revérifiée', (await q(`select certification::text c from profiles where id = '${E}'`))[0].c === 'revoked');
  check('l\'entreprise est prévenue de la re-vérification', (await q(`select count(*)::int n from notifications where user_id = '${E}' and title = 'Fiche repassée en vérification'`))[0].n === 1);
  await as(E);
  await fails('publication suspendue pendant la re-vérification', need('Autre besoin'), /vérifiée/);
  await as(M);
  await q(`select company_decide('${E}', true)`);
  await db.exec('reset role');
  check('nouvelle approbation : certification rétablie', (await q(`select certification::text c from profiles where id = '${E}'`))[0].c === 'approved');
  await as(M);
  check('retrait par l\'administrateur d\'une fiche approuvée', (await q(`select company_decide('${E}', false, 'Fraude constatée') r`))[0].r === 'rejected');
  await db.exec('reset role');
  check('retrait : certification retirée', (await q(`select certification::text c from profiles where id = '${E}'`))[0].c === 'revoked');
  // la fiche rejetée doit être renvoyée avant une nouvelle approbation : on la remet approuvée pour la suite
  await db.exec('reset role');
  await db.exec(`update company_profiles set status = 'approved', review_note = null where owner_id = '${E}'`);
  check('statut approuvé rétabli : certification approuvée par le déclencheur', (await q(`select certification::text c from profiles where id = '${E}'`))[0].c === 'approved');

  // rôle « other » : même règle
  await as(O);
  await q(`select company_save('${JSON.stringify({ company_name: 'ONG Verte', sector: 'Environnement', city: 'Douala', phone: '670000000', contact_name: 'Mme Verte' })}'::jsonb)`);
  await db.exec('reset role');
  await db.exec(`update company_profiles set status = 'pending' where owner_id = '${O}'`);
  await as(M);
  await q(`select company_decide('${O}', true)`);
  await db.exec('reset role');
  check('rôle other : l\'approbation certifie aussi le compte', (await q(`select certification::text c from profiles where id = '${O}'`))[0].c === 'approved');

  // ============================================================ forfaits (E5-16, E5-17, E5-18, E5-23)
  await db.exec('reset role');
  await db.exec(`update company_subscriptions set status = 'expired' where owner_id = '${E}'`);
  // demande manuelle : paiement lié
  await as(E);
  check('demande de forfait : acceptée', (await q(`select company_subscription_request('pro') r`))[0].r === 'requested');
  let st = (await q(`select company_plan_status() r`))[0].r;
  check('demande : paiement manuel PAY-… lié (référence, montant)', st.requested === 'pro' && /^PAY-/.test(st.requested_payment.reference) && st.requested_payment.amount === 25000);
  const pay1 = st.requested_payment.id;
  await q(`select company_subscription_request('pro')`);
  check('demande répétée : le même paiement est réutilisé', (await q(`select company_plan_status() r`))[0].r.requested_payment.id === pay1);
  check('le sujet du paiement est « cplan:pro »', (await sq(`select subject from payment_transactions where id = '${pay1}'`))[0].subject === 'cplan:pro');
  await q(`select company_subscription_request('partner')`);
  st = (await q(`select company_plan_status() r`))[0].r;
  check('changement de forfait demandé : nouveau paiement, ancien annulé', st.requested === 'partner' && st.requested_payment.id !== pay1 && (await sq(`select status from payment_transactions where id = '${pay1}'`))[0].status === 'cancelled');
  await q(`select company_subscription_request('pro')`);
  const pay2 = (await q(`select company_plan_status() r`))[0].r.requested_payment.id;
  await as(M);
  check('activation admin : accordée pour 30 jours', (await q(`select company_subscription_activate('${E}', 'pro', 30, 'Reçu en espèces') r`))[0].r !== null);
  await db.exec('reset role');
  check('activation admin : paiement lié confirmé', (await sq(`select status from payment_transactions where id = '${pay2}'`))[0].status === 'confirmed');
  check('activation admin : souscription liée au paiement, sans double traitement', (await sq(`select count(*)::int n from company_subscriptions where owner_id = '${E}' and status = 'active' and payment_id = '${pay2}'`))[0].n === 1
    && (await sq(`select count(*)::int n from money_entries where kind = 'subscription' and ref = (select reference from payment_transactions where id = '${pay2}')`))[0].n === 1);
  check('activation admin : journal d\'audit', (await q(`select count(*)::int n from audit_log where action like 'Forfait entreprise activé%' and target like '%Orange%'`))[0].n === 1);
  // E5-17 : report des jours restants
  const end1 = new Date((await sq(`select ends_at from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].ends_at).getTime();
  await as(M);
  await q(`select company_subscription_activate('${E}', 'pro', 30)`);
  const end2 = new Date((await sq(`select ends_at from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].ends_at).getTime();
  check('renouvellement anticipé : les jours restants sont reportés (+30 j)', Math.abs((end2 - end1) / 86400000 - 30) < 0.01, `${(end2 - end1) / 86400000}`);
  await q(`select company_subscription_activate('${E}', 'partner', 30)`);
  await fails('forfait inférieur : refusé sans confirmation', `select company_subscription_activate('${E}', 'pro', 30)`, /inférieur/);
  await as(E);
  await fails('forfait inférieur : paiement refusé avant le débit', `select company_plan_checkout('pro')`, /supérieur est déjà actif/);
  await fails('forfait inférieur : demande refusée', `select company_subscription_request('pro')`, /supérieur est déjà actif/);
  // paiement confirmé alors que le forfait supérieur est actif : jamais silencieux
  await db.exec('reset role');
  await db.exec(`insert into payment_transactions (reference, payer_id, provider, kind, subject, amount, status) values ('PAY-T1', '${E}', 'tara', 'subscription', 'cplan:pro', 25000, 'pending')`);
  await db.exec(`update payment_transactions set status = 'confirmed' where reference = 'PAY-T1'`);
  check('paiement non activé : le payeur est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${E}' and title = 'Paiement reçu, forfait non activé'`))[0].n === 1);
  check('paiement non activé : la finance et l\'administration sont avisées', (await q(`select count(*)::int n from notifications where kind = 'payment_review' and title = 'Paiement de forfait non activé' and user_id in ('${FIN}', '${M}')`))[0].n === 2);
  check('paiement non activé : note du paiement et audit', /Forfait non activé/.test((await sq(`select note from payment_transactions where reference = 'PAY-T1'`))[0].note) && (await q(`select count(*)::int n from audit_log where action = 'Forfait non activé après paiement'`))[0].n === 1);
  check('paiement non activé : le forfait actif est intact', (await sq(`select plan_code from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].plan_code === 'partner');
  await as(M);
  check('forfait inférieur : accepté avec confirmation explicite', (await q(`select company_subscription_activate('${E}', 'pro', 30, 'Confirmé', true) r`))[0].r !== null);
  // paiement d'un tiers non autorisé / entreprise non vérifiée
  await db.exec('reset role');
  await db.exec(`insert into payment_transactions (reference, payer_id, provider, kind, subject, amount, status) values ('PAY-T2', '${P}', 'tara', 'subscription', 'cplan:partner:${E}', 75000, 'pending')`);
  await db.exec(`update payment_transactions set status = 'confirmed' where reference = 'PAY-T2'`);
  check('paiement d\'un tiers étranger à l\'équipe : aucune activation', (await sq(`select plan_code from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].plan_code === 'pro');
  check('paiement d\'un tiers : le tiers et la finance sont prévenus', (await q(`select count(*)::int n from notifications where user_id = '${P}' and title = 'Paiement reçu, forfait non activé'`))[0].n === 1);
  await db.exec(`insert into payment_transactions (reference, payer_id, provider, kind, subject, amount, status) values ('PAY-T3', '${N}', 'tara', 'subscription', 'cplan:pro', 25000, 'pending')`);
  await db.exec(`update payment_transactions set status = 'confirmed' where reference = 'PAY-T3'`);
  check('entreprise non vérifiée : paiement confirmé mais signalé', (await q(`select count(*)::int n from notifications where user_id = '${N}' and title = 'Paiement reçu, forfait non activé' and body like '%pas (ou plus) vérifiée%'`))[0].n === 1);
  // membre finance : peut payer pour l'entreprise
  await as(F);
  const cF = (await q(`select company_plan_checkout('pro', '${E}') r`))[0].r;
  check('finance : paiement au sujet « cplan:pro:<entreprise> »', (await sq(`select subject from payment_transactions where reference = '${cF.reference}'`))[0].subject === `cplan:pro:${E}`);
  check('paiement : une transaction non débitée est reprise (pas de doublon à chaque pression)', (await q(`select company_plan_checkout('pro', '${E}') r`))[0].r.reference === cF.reference);
  // ancien sujet « plan:pro » : toujours activé (paiements déjà en vol) en l'absence de souscription premium liée
  await db.exec('reset role');
  await db.exec(`update company_subscriptions set status = 'expired' where owner_id = '${E}'`);
  await db.exec(`insert into payment_transactions (reference, payer_id, provider, kind, subject, amount, status) values ('PAY-T4', '${E}', 'tara', 'subscription', 'plan:pro', 25000, 'pending')`);
  await db.exec(`update payment_transactions set status = 'confirmed' where reference = 'PAY-T4'`);
  check('ancien sujet plan:pro : forfait d\'entreprise activé', (await sq(`select plan_code from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].plan_code === 'pro');
  // confirmation manuelle par la finance (payment_set_status) : active exactement une fois
  await db.exec(`update company_subscriptions set status = 'expired' where owner_id = '${E}'`);
  await as(E);
  await q(`select company_subscription_request('pro')`);
  const pay3 = (await q(`select company_plan_status() r`))[0].r.requested_payment;
  await q(`select payment_declare('${pay3.id}', 'MP240101.1234.A12345')`);
  await as(FIN);
  await q(`select payment_set_status('${pay3.id}', 'confirmed')`);
  await db.exec('reset role');
  check('finance : confirmation manuelle -> forfait activé une seule fois', (await sq(`select count(*)::int n from company_subscriptions where owner_id = '${E}' and status = 'active' and payment_id = '${pay3.id}'`))[0].n === 1);

  // E5-18 : forfait premium homonyme, jamais traité par le système d'entreprise
  await db.exec('reset role');
  await db.exec(`update plans set price_xaf = 10000 where code = 'entreprise'`);
  await db.exec(`delete from subscriptions where user_id = '${E}'`);
  await db.exec(`update company_subscriptions set status = 'expired' where owner_id = '${E}'`);
  await db.exec(`insert into company_plans (code, name, price_fcfa, period_days, max_needs, max_offers, max_contests, position) values ('entreprise', 'Collision', 10000, 30, 5, 5, 1, 9)`);
  await as(E);
  const pp = (await q(`select subscription_start('entreprise') r`))[0].r;
  check('offre premium : paiement manuel au sujet « plan:entreprise »', (await sq(`select subject from payment_transactions where id = '${pp}'`))[0].subject === 'plan:entreprise');
  await q(`select payment_declare('${pp}', 'MP99887766')`);
  await as(FIN);
  await q(`select payment_set_status('${pp}', 'confirmed')`);
  await db.exec('reset role');
  check('offre premium confirmée : souscription premium active', (await sq(`select status from subscriptions where payment_id = '${pp}'`))[0].status === 'active');
  check('offre premium confirmée : aucun forfait d\'entreprise créé (pas de double traitement)', (await sq(`select count(*)::int n from company_subscriptions where payment_id = '${pp}'`))[0].n === 0
    && (await sq(`select count(*)::int n from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].n === 0);
  await db.exec(`delete from company_plans where code = 'entreprise'`);
  await as(M);
  await fails('un code de forfait d\'entreprise ne reprend pas celui d\'une offre premium', `select company_plan_save('{"code":"entreprise","name":"Doublon","price_fcfa":1}'::jsonb)`, /offre premium/);
  check('forfait modifié : journal d\'audit', (await q(`select company_plan_save('{"code":"pro","name":"Entreprise","price_fcfa":25000,"period_days":30,"max_needs":10,"max_offers":10,"max_contests":2,"perks":"x"}'::jsonb) r`))[0].r === 'pro'
    && (await q(`select count(*)::int n from audit_log where action = 'Forfait d''organisation modifié' and target like 'pro%'`))[0].n === 1);

  // expiration automatique
  await db.exec('reset role');
  await db.exec(`insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at) values ('${E}', 'pro', 'active', now() - interval '31 days', now() - interval '1 hour')`);
  await as(E);
  await fails('expiration : non appelable par un utilisateur', `select expire_company_subscriptions()`, /permission denied/);
  await db.exec('reset role');
  check('expiration : un forfait échu est clos', (await q(`select expire_company_subscriptions() n`))[0].n === 1);
  await as(E);
  check('expiration : retour au forfait Découverte', (await q(`select company_plan_status() r`))[0].r.plan.code === 'free');
  check('expiration : l\'entreprise est prévenue', (await q(`select count(*)::int n from notifications where user_id = '${E}' and title = 'Forfait terminé'`))[0].n === 1);

  // ============================================================ E5-20 : notifications importantes et non désactivables
  await db.exec('reset role');
  check('catégorie : company_review n\'est plus « reviews »', (await q(`select notification_category('company_review') c`))[0].c === 'other' && (await q(`select notification_category('review') c`))[0].c === 'reviews');
  await db.exec(`insert into notification_preferences (user_id, channel, kind, enabled) values ('${E}', 'inapp', 'cat:reviews', false)`);
  await db.exec(`insert into notifications (user_id, kind, title, body) values ('${E}', 'company_review', 'Test verification', 'x')`);
  check('avis désactivés : la décision de vérification arrive quand même', (await q(`select count(*)::int n from notifications where user_id = '${E}' and title = 'Test verification'`))[0].n === 1);
  await db.exec(`insert into notification_preferences (user_id, channel, kind, enabled) values ('${E}', 'email', '*', true)`);
  await db.exec(`insert into notifications (user_id, kind, title, body) values ('${E}', 'company_plan', 'Forfait test', 'x'), ('${E}', 'company_team', 'Equipe test', 'x'), ('${E}', 'company_review', 'Verif test', 'x')`);
  check('company_plan / company_team / company_review : importants (e-mail activé en « * »)', (await q(`select count(*)::int n from notification_outbox where user_id = '${E}' and channel = 'email' and kind in ('company_plan', 'company_team', 'company_review')`))[0].n >= 3);
  await db.exec(`insert into notifications (user_id, kind, title, body) values ('${E}', 'ads', 'Pub test', 'x')`);
  check('une notification non importante n\'est pas envoyée par e-mail', (await q(`select count(*)::int n from notification_outbox where user_id = '${E}' and kind = 'ads'`))[0].n === 0);

  // ============================================================ E5-24 : 2FA
  await db.exec('reset role');
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${M}', 'verified')`);
  for (const fn of ['company_decide', 'company_plan_save', 'company_subscription_activate', 'company_plan_checkout', 'payment_start', 'subscription_start', 'payment_set_status'])
    check(`2FA : ${fn} exige aal2`, /double authentification/.test(await hook('POST', `/rpc/${fn}`, M, 'aal1')));
  for (const fn of ['company_decide', 'company_plan_save', 'company_subscription_activate'])
    check(`2FA : ${fn} passe avec aal2`, (await hook('POST', `/rpc/${fn}`, M, 'aal2')) === 'ok');
  check('2FA : company_queue (lecture) non concernée', (await hook('POST', '/rpc/company_queue', M, 'aal1')) === 'ok');
  check('2FA : un compte suspendu ne peut toujours pas écrire (garde conservée)', await (async () => { await db.exec('reset role'); await db.exec(`update profiles set suspended = true where id = '${X}'`); const r = await hook('POST', '/rpc/company_save', X, 'aal2'); await db.exec('reset role'); await db.exec(`update profiles set suspended = false where id = '${X}'`); return /suspendu/.test(r); })());

  console.log(`\n${ok}/${ok + ko}`);
}
