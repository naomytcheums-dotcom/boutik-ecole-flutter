// Scénario PGlite du lot S8 (migrations 20261117080000 à 20261117080200) : opportunités, candidatures, alertes, dossier, mentors.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s8.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const n = async (sql) => (await q(sql))[0].n;

  await db.exec('reset role');
  // 11 = étudiante IUT vérifiée, 12 = étudiante qui a PROPOSÉ « IUT Faux », 13 = étudiant texte libre « IUT », 14 = entreprise, 15 = admin, 16 = client,
  // 17 = étudiante sans filière, 18 = étudiante mentor (Université), 19 = étudiant demandeur de mentor
  const users = [[11, 'Awa Ndiaye', 'student', 'Génie informatique'], [12, 'Faustine Faux', 'student', 'Génie civil'], [13, 'Texte Libre', 'student', 'Génie civil'],
    [14, 'Orange Cameroun', 'company', ''], [15, 'Equipe Admin', 'admin', ''], [16, 'Client Test', 'client', ''], [17, 'Sans Filiere', 'student', ''],
    [18, 'Mentore Etudiante', 'student', 'Génie informatique'], [19, 'Demandeur Paul', 'student', 'Génie informatique']];
  for (const [id, nm, role, dept] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${U(id)}','u${id}@t.cm'); insert into profiles(id,name,role,email,department,skills,bio) values ('${U(id)}','${nm}','${role}','u${id}@t.cm','${dept}','Flutter, Canva','Je développe des applications mobiles')`);
  }
  await db.exec(`update profiles set institution = 'IUT de Douala' where id = '${U(13)}'`); // texte libre, sans référentiel
  await db.exec(`update profiles set certification = 'approved' where id in ('${U(12)}', '${U(13)}')`); // étudiants vérifiés (lot S1) : seul l'établissement les distingue
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${U(14)}', 'Orange Cameroun', 'approved'); insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at) values ('${U(14)}', 'partner', 'active', now(), now() + interval '30 days')`);
  // Le référentiel n'est plus prérempli par les migrations (décision du propriétaire, commit 90f48686) : le scénario crée ses deux établissements vérifiés.
  await db.exec(`insert into institutions (name, short_name, kind, city, status, source) values ('Institut universitaire de technologie de Douala', 'IUT Douala', 'institut', 'Douala', 'verified', 'fixture de test'), ('Université de Douala', 'UDo', 'universite_etat', 'Douala', 'verified', 'fixture de test') on conflict do nothing`);
  const iutId = (await q(`select id from institutions where name = 'Institut universitaire de technologie de Douala'`))[0].id;
  const uniId = (await q(`select id from institutions where name = 'Université de Douala'`))[0].id;

  // ============================================================ S8-1 : IUT sur référentiel vérifié
  await as(U(12));
  const fauxId = (await q(`select institution_propose('IUT Faux de Nulle Part', 'Douala', 'institut') id`))[0].id;
  await q(`select profile_set_academic('${fauxId}', null, 'MAT001', 'L1')`);
  check('S8-1 : l\'établissement proposé est recopié dans le profil (comportement attendu du référentiel)', (await q(`select institution i from profiles where id = '${U(12)}'`))[0].i === 'IUT Faux de Nulle Part');
  await as(U(11));
  await q(`select profile_set_academic('${iutId}', null, 'MAT002', 'L2')`);
  await db.exec(`reset role; update profiles set department = 'Génie informatique' where id = '${U(11)}'`);
  await as(U(11));
  await as(U(14));
  const post = (title, iut, extra = {}) => `select opp_save('Orange Cameroun', 'stage', 'academique', '${title}', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', current_date + 10, array['Flutter','Canva'], 'Description complete de l offre pour les etudiants', array['Developper des ecrans','Tester'], 'Etudiant motive', '${extra.dept ?? 'Génie informatique'}', 'Licence 2', array['Attestation'], '', true, 'Operateur', ${iut}) id`;
  const oIut = (await q(post('Stage reserve IUT', 'true')))[0].id;
  const oOpen = (await q(post('Stage ouvert', 'false')))[0].id;
  await as(U(15));
  await q(`select opp_decide('${oIut}', true, true)`);
  await q(`select opp_decide('${oOpen}', true, true)`);
  const lettre = 'Je suis tres motive(e) pour ce stage de developpement';
  await as(U(12));
  await fails('S8-1 : établissement proposé « IUT Faux » : candidature IUT refusée', `select opp_apply('${oIut}', '${lettre}')`, /réservée aux étudiants de l'IUT/);
  await as(U(13));
  await fails('S8-1 : texte libre « IUT de Douala » sans référentiel : refusé', `select opp_apply('${oIut}', '${lettre}')`, /réservée aux étudiants de l'IUT/);
  check('S8-1 : opps_recommended n\'expose pas l\'offre IUT à un non-IUT', !(await q(`select opps_recommended(20) r`))[0].r.some((o) => o.id === oIut));
  check('S8-1 : fiche : iut_eligible faux pour un non-IUT', (await q(`select opp_detail('${oIut}') r`))[0].r.iut_eligible === false);
  await as(U(12));
  await db.exec('reset role');
  await db.exec(`update institutions set status = 'verified' where id = '${fauxId}'`); // même vérifié, « IUT Faux » commence par IUT : accepté seulement si l'équipe l'a publié
  await as(U(12));
  check('S8-1 : un établissement IUT publié par l\'équipe est reconnu', (await q(`select opp_detail('${oIut}') r`))[0].r.iut_eligible === true);
  await db.exec('reset role');
  await db.exec(`update institutions set status = 'proposed' where id = '${fauxId}'`);
  await as(U(11));
  await fails('S8-1 : rattaché à l\'IUT du référentiel mais pas « étudiant vérifié » (lot S1) : refusé', `select opp_apply('${oIut}', '${lettre}')`, /réservée aux étudiants de l'IUT/);
  check('S8-1 : ... et l\'offre IUT ne lui est pas recommandée', !(await q(`select opps_recommended(20) r`))[0].r.some((o) => o.id === oIut));
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'approved' where id = '${U(11)}'`);
  await as(U(11));
  check('S8-1 : étudiant d\'un IUT vérifié : offre IUT recommandée', (await q(`select opps_recommended(20) r`))[0].r.some((o) => o.id === oIut));
  check('S8-1 : fiche : iut_eligible vrai pour un étudiant IUT vérifié', (await q(`select opp_detail('${oIut}') r`))[0].r.iut_eligible === true);
  const appId = (await q(`select opp_apply('${oIut}', '${lettre}') id`))[0].id;
  check('S8-1 : étudiant IUT vérifié : candidature acceptée', !!appId);
  await as(null, 'anon');
  check('S8-1 : visiteur : iut_eligible faux', (await q(`select opp_detail('${oIut}') r`))[0].r.iut_eligible === false);

  // ============================================================ S8-14 : retrait / nouvelle candidature
  await as(U(11));
  await q(`select opp_withdraw_application('${appId}')`);
  await db.exec('reset role');
  check('S8-14 : historique des retraits (table interne)', await n(`select count(*)::int n from opportunity_withdrawals where applicant_id = '${U(11)}' and opportunity_id = '${oIut}'`) === 1);
  check('S8-14 : le recruteur est prévenu du retrait', await n(`select count(*)::int n from notifications where user_id = '${U(14)}' and title = 'Candidature retirée'`) === 1);
  await as(U(11));
  await fails('S8-14 : repostuler immédiatement après un retrait est refusé', `select opp_apply('${oIut}', '${lettre}')`, /moins de 24 h/);
  await db.exec('reset role');
  await db.exec(`update opportunity_withdrawals set withdrawn_at = now() - interval '2 days'`);
  await as(U(11));
  const app2 = (await q(`select opp_apply('${oIut}', '${lettre}') id`))[0].id;
  check('S8-14 : après 24 h la candidature est de nouveau possible', !!app2);
  await q(`select opp_withdraw_application('${app2}')`);
  await db.exec('reset role');
  await db.exec(`insert into opportunity_withdrawals (opportunity_id, applicant_id, previous_status, withdrawn_at) values ('${oIut}', '${U(11)}', 'sent', now() - interval '3 days'), ('${oIut}', '${U(11)}', 'sent', now() - interval '3 days'); update opportunity_withdrawals set withdrawn_at = now() - interval '3 days'`);
  await as(U(11));
  await fails('S8-14 : trois retraits au plus par offre', `select opp_apply('${oIut}', '${lettre}')`, /trois fois/);
  const appOpen = (await q(`select opp_apply('${oOpen}', '${lettre}') id`))[0].id;

  // ============================================================ S8-2 : visibilité auprès des recruteurs
  await as(U(14));
  const sug = (await q(`select opp_suggested_students('${oOpen}', 30) r`))[0].r;
  check('S8-2 : par défaut l\'étudiante est proposable (comportement existant)', sug.some((s) => s.id === U(12)) || sug.some((s) => s.id === U(13)));
  await as(U(13));
  check('S8-2 : réglage lisible (vrai par défaut)', (await q(`select talent_visibility_get() r`))[0].r === true);
  await q(`select talent_visibility_set(false)`);
  check('S8-2 : réglage retiré', (await q(`select talent_visibility_get() r`))[0].r === false);
  await as(U(14));
  check('S8-2 : l\'étudiant qui s\'est retiré n\'est plus proposé', !(await q(`select opp_suggested_students('${oOpen}', 30) r`))[0].r.some((s) => s.id === U(13)));
  await fails('S8-2 : ni invitable', `select opp_invite('${oOpen}', '${U(13)}', 'Bonjour')`, /Étudiant introuvable/);
  await fails('S8-2 : ni contactable (demande de contact)', `select talent_contact_request('${U(13)}', 'contact', 'Bonjour')`, /Talent introuvable/);
  const sugBefore = (await q(`select opp_suggested_students('${oOpen}', 30) r`))[0].r;
  const inviteTarget = sugBefore.find((s) => s.id === U(12))?.id ?? sugBefore[0]?.id;
  check('S8-2 : un étudiant visible reste invitable', !!inviteTarget && (await q(`select opp_invite('${oOpen}', '${inviteTarget}', 'Venez postuler') r`))[0].r === 'invited');
  await as(inviteTarget);
  check('S8-2 : l\'étudiant invité est notifié', await n(`select count(*)::int n from notifications where user_id = '${inviteTarget}' and kind = 'opportunity_invite'`) === 1);
  const inv = (await q(`select opp_my_invites() r`))[0].r;
  check('S8-2 : « Propositions reçues » : l\'invitation est listée pour l\'étudiant', inv.length === 1 && inv[0].title === 'Stage ouvert' && inv[0].status === 'invited' && inv[0].open === true);
  await as(U(16));
  check('S8-2 : un autre compte ne voit pas ces invitations', (await q(`select opp_my_invites() r`))[0].r.length === 0);
  await as(U(13));
  await q(`select talent_visibility_set(true)`);
  await as(U(14));
  await fails('S8-2 : visible de nouveau : la demande de contact passe le contrôle de visibilité', `select talent_contact_request('${U(13)}', 'contact', 'Bonjour')`, /n'a pas publié son CV/);
  await as(null, 'anon');
  await fails('S8-2 : le réglage n\'est pas ouvert aux visiteurs', `select talent_visibility_set(false)`, /permission denied/);

  // ============================================================ S8-3 : partager mon recrutement
  await as(U(14));
  await q(`select opp_application_decide('${appOpen}', 'hired')`);
  await as(U(11));
  await fails('S8-3 : le partage exige une confirmation', `select opp_hire_publish('${appOpen}')`, /Confirmez le partage/);
  await fails('S8-3 : la confirmation doit être vraie', `select opp_hire_publish('${appOpen}', false)`, /Confirmez le partage/);
  await as(U(12));
  await fails('S8-3 : on ne partage pas la candidature d\'un autre', `select opp_hire_publish('${appOpen}', true)`, /Candidature introuvable/);
  await as(U(11));
  await q(`select opp_hire_publish('${appOpen}', true)`);
  await as(null, 'anon');
  let hired = (await q(`select opp_hired_list() r`))[0].r;
  check('S8-3 : un visiteur ne voit que le prénom (pas de nom complet)', hired.length === 1 && hired[0].name === 'Awa' && hired[0].org === 'Orange Cameroun');
  await as(U(12));
  hired = (await q(`select opp_hired_list() r`))[0].r;
  check('S8-3 : une personne connectée voit « Prénom N. »', hired[0].name === 'Awa N.');
  await fails('S8-3 : un tiers ne retire pas le partage d\'autrui', `select opp_hire_unpublish('${appOpen}')`, /Aucun partage à retirer/);
  await as(U(11));
  await q(`select opp_hire_unpublish('${appOpen}')`);
  await as(null, 'anon');
  check('S8-3 : le partage retiré disparaît de la liste', (await q(`select opp_hired_list() r`))[0].r.length === 0);
  await as(U(11));
  await fails('S8-3 : rien à retirer une deuxième fois', `select opp_hire_unpublish('${appOpen}')`, /Aucun partage à retirer/);
  check('S8-3 : la candidature n\'est plus marquée comme partagée', (await q(`select opp_my_applications() r`))[0].r.find((a) => a.id === appOpen).published === false);

  // ============================================================ S8-6 : un seul réglage « Offres compatibles »
  await as(U(17));
  await q(`select alert_prefs_set(true, true, true)`);
  let g = (await q(`select alert_prefs_get() r`))[0].r;
  check('S8-6 : sans filière, l\'alerte demandée n\'est pas active et le dit', g.offers === false && g.needs_department === true);
  await as(U(11));
  g = (await q(`select alert_prefs_get() r`))[0].r;
  check('S8-6 : sans alerte enregistrée, « Offres compatibles » n\'est pas affiché actif', g.offers === false && g.results === true && g.documents === true);
  await q(`select alert_prefs_set(true, true, true)`);
  check('S8-6 : écran 156 : l\'alerte de filière est créée (même donnée que /opportunites)', (await q(`select opp_my_alert() r`))[0].r === true && (await q(`select alert_prefs_get() r`))[0].r.offers === true);
  await q(`select opp_alert_set('Génie informatique', false)`);
  g = (await q(`select alert_prefs_get() r`))[0].r;
  check('S8-6 : /opportunites : désactiver éteint aussi le réglage de l\'écran 156', g.offers === false && (await q(`select opp_my_alert() r`))[0].r === false);
  await q(`select opp_alert_set('Génie informatique', true)`);
  check('S8-6 : /opportunites : activer rallume le réglage de l\'écran 156', (await q(`select alert_prefs_get() r`))[0].r.offers === true);
  await q(`select alert_prefs_set(false, true, true)`);
  check('S8-6 : écran 156 : désactiver supprime l\'alerte de filière', (await q(`select opp_my_alert() r`))[0].r === false);
  await q(`select alert_prefs_set(true, true, true)`);

  // ============================================================ S8-4 : e-mail / SMS / WhatsApp
  await db.exec('reset role');
  await db.exec(`update profiles set phone = '690000011', phone_verified = true where id = '${U(11)}'`);
  await as(U(11));
  await q(`select set_notification_preference('email', '*', true)`);
  await q(`select set_notification_preference('sms', '*', true)`);
  await q(`select set_notification_preference('whatsapp', '*', true)`);
  await as(U(14));
  const oNew = (await q(post('Nouvelle offre alerte', 'false')))[0].id;
  await as(U(15));
  await q(`select opp_decide('${oNew}', true, true)`);
  await db.exec('reset role');
  check('S8-4 : alerte d\'offre : notification créée', await n(`select count(*)::int n from notifications where user_id = '${U(11)}' and kind = 'opportunity_alert'`) === 1);
  const ob = await q(`select channel, to_address from notification_outbox where user_id = '${U(11)}' and kind = 'opportunity_alert' order by channel`);
  check('S8-4 : alerte d\'offre : partie par e-mail, SMS et WhatsApp (outbox)', ob.map((r) => r.channel).join() === 'email,sms,whatsapp' && ob.find((r) => r.channel === 'email').to_address === 'u11@t.cm' && ob.find((r) => r.channel === 'sms').to_address === '+237690000011', JSON.stringify(ob));
  await as(U(14));
  await q(`select opp_application_decide('${appOpen}', 'shortlisted')`);
  await db.exec('reset role');
  check('S8-4 : résultat de candidature : envoyé par e-mail, SMS et WhatsApp', await n(`select count(*)::int n from notification_outbox where user_id = '${U(11)}' and kind = 'opportunity_application' and channel in ('email','sms','whatsapp')`) === 3);
  await db.exec(`select notify_user('${U(11)}', 'type_non_important', 'Bonjour', 'Un type sans alerte', '{}'::jsonb)`);
  check('S8-4 : un type non important reste interne (aucun envoi par canal externe)', await n(`select count(*)::int n from notification_outbox where user_id = '${U(11)}' and kind = 'type_non_important'`) === 0);
  await as(U(11));
  await q(`select set_notification_preference('email', '*', false)`);
  await q(`select alert_prefs_set(true, false, true)`);
  await as(U(14));
  await q(`select opp_application_decide('${appOpen}', 'rejected')`);
  await db.exec('reset role');
  check('S8-4 : résultats désactivés : aucune notification de statut supplémentaire', await n(`select count(*)::int n from notifications where user_id = '${U(11)}' and kind = 'opportunity_application' and title = 'Candidature non retenue'`) === 0);
  await as(U(11));
  await q(`select set_notification_preference('sms', '*', false)`);
  await q(`select set_notification_preference('whatsapp', '*', false)`);
  await q(`select alert_prefs_set(true, true, true)`);
  await as(U(14));
  const oNew2 = (await q(post('Seconde offre alerte', 'false')))[0].id;
  await as(U(15));
  await q(`select opp_decide('${oNew2}', true, true)`);
  await db.exec('reset role');
  check('S8-4 : canaux désactivés : plus aucun envoi externe pour la nouvelle alerte', await n(`select count(*)::int n from notification_outbox o join notifications nn on nn.id = o.notification_id where o.user_id = '${U(11)}' and nn.body like '%Seconde offre%'`) === 0);

  // ============================================================ S8-5 : dossier
  await db.exec(`insert into storage.objects (bucket_id, name) values ('profile-documents', '${U(11)}/student_card/a.pdf'), ('profile-documents', '${U(11)}/cv/b.pdf')`);
  await as(U(11));
  const d1 = (await q(`select document_register('student_card', '${U(11)}/student_card/a.pdf', 'carte.pdf', 'application/pdf', 1000) id`))[0].id;
  const d2 = (await q(`select document_register('cv', '${U(11)}/cv/b.pdf', 'cv.pdf', 'application/pdf', 1000) id`))[0].id;
  await q(`select set_notification_preference('email', '*', true)`);
  await fails('S8-5 : un étudiant ne vérifie pas une pièce', `select document_review('${d1}', 'verified')`, /non autorisée/);
  await as(U(15));
  await q(`select document_review('${d1}', 'verified')`);
  await q(`select document_review('${d2}', 'rejected', 'Fichier illisible')`);
  await db.exec('reset role');
  const dn = await q(`select title, body, data from notifications where user_id = '${U(11)}' and kind = 'verification' and data ? 'document' order by created_at, title`);
  check('S8-5 : pièce validée : notification « Pièce validée » (portant document et status)', dn.some((x) => x.title === 'Pièce validée' && /Carte d'étudiant/.test(x.body) && x.data.status === 'verified'), JSON.stringify(dn));
  check('S8-5 : pièce refusée : notification avec le motif', dn.some((x) => x.title === 'Pièce refusée' && /Fichier illisible/.test(x.body)));
  check('S8-5 : la décision est aussi envoyée par e-mail (canal activé)', await n(`select count(*)::int n from notification_outbox where user_id = '${U(11)}' and kind = 'verification' and channel = 'email'`) === 2);
  await as(U(15));
  await q(`select document_review('${d1}', 'verified')`);
  await db.exec('reset role');
  check('S8-5 : revérifier avec le même statut ne renotifie pas', await n(`select count(*)::int n from notifications where user_id = '${U(11)}' and kind = 'verification' and title = 'Pièce validée'`) === 1);
  await as(U(11));
  await q(`select alert_prefs_set(true, true, false)`);
  await as(U(15));
  await q(`select document_review('${d2}', 'verified')`);
  await q(`select document_decide('${d1}', 'rejected', 'Photo floue, merci de renvoyer')`);
  await db.exec('reset role');
  check('S8-5 : alerte « Dossier » désactivée : aucune notification, même via document_decide (lot S1)', await n(`select count(*)::int n from notifications where user_id = '${U(11)}' and kind = 'verification' and data ? 'document'`) === 2);
  await as(U(11));
  await q(`select alert_prefs_set(true, true, true)`);
  await as(U(15));
  await q(`select document_decide('${d1}', 'verified')`);
  await db.exec('reset role');
  check('S8-5 : alerte « Dossier » réactivée : document_decide (lot S1) notifie de nouveau', await n(`select count(*)::int n from notifications where user_id = '${U(11)}' and kind = 'verification' and data ? 'document'`) === 3);
  await as(U(11));

  // ============================================================ S8-15 / S8-17 : mentors
  await as(U(18));
  await q(`select mentor_save('Eneo', 'Promo 2022', array['Flutter'], 'Je peux aider en mobile', 'available', true)`);
  check('S8-15 : un nouveau profil mentor sans preuve est « pending »', (await q(`select my_mentor() r`))[0].r.status === 'pending');
  await db.exec('reset role');
  check('S8-15 : l\'équipe est prévenue du profil à vérifier', await n(`select count(*)::int n from notifications where user_id = '${U(15)}' and kind = 'verification' and title = 'Profil mentor à vérifier'`) === 1);
  await as(U(19));
  check('S8-15 : un mentor non vérifié n\'est pas listé', (await q(`select mentors_list() r`))[0].r.length === 0);
  await as(null, 'anon');
  check('S8-15 : ni pour un visiteur', (await q(`select mentors_list() r`))[0].r.length === 0);
  await fails('S8-15 : sa fiche n\'est pas publique', `select mentor_detail('${U(18)}')`, /Mentor introuvable/);
  await as(U(19));
  await fails('S8-15 : on ne peut pas lui adresser de demande', `select mentor_request('${U(18)}', 'Flutter')`, /Mentor introuvable/);
  check('S8-15 : le match ne le propose pas', (await q(`select mentor_match('Flutter') r`))[0].r.length === 0);
  await as(U(18));
  check('S8-15 : la personne voit sa propre fiche en attente', (await q(`select mentor_detail('${U(18)}') r`))[0].r.status === 'pending');
  await fails('S8-15 : pas d\'histoire de réussite avant vérification', `select mentor_story_save('Mon parcours', 'Je raconte mon parcours depuis le début des études')`, /doit d'abord être vérifié/);
  await fails('S8-15 : un étudiant ne valide pas un mentor', `select mentor_validate('${U(18)}', true)`, /non autorisée/);
  await fails('S8-15 : un étudiant ne liste pas les profils en attente', `select mentors_pending()`, /non autorisée/);
  await as(U(15));
  check('S8-15 : l\'équipe liste les profils en attente', (await q(`select mentors_pending() r`))[0].r.some((m) => m.user_id === U(18)));
  await q(`select mentor_validate('${U(18)}', false, 'Profil incomplet')`);
  await as(U(19));
  check('S8-15 : un profil refusé n\'est pas listé', (await q(`select mentors_list() r`))[0].r.length === 0);
  await db.exec('reset role');
  check('S8-15 : la personne est prévenue du refus avec le motif', await n(`select count(*)::int n from notifications where user_id = '${U(18)}' and kind = 'mentor_profile' and body like '%Profil incomplet%'`) === 1);
  // preuve réelle : une pièce vérifiée par l'équipe publie automatiquement le profil
  await db.exec(`insert into storage.objects (bucket_id, name) values ('profile-documents', '${U(18)}/student_card/c.pdf')`);
  await as(U(18));
  await q(`select mentor_save('Eneo', 'Promo 2022', array['Flutter'], 'Je peux aider en mobile', 'available', true)`);
  check('S8-15 : un profil refusé modifié repasse en attente', (await q(`select my_mentor() r`))[0].r.status === 'pending');
  const d3 = (await q(`select document_register('student_card', '${U(18)}/student_card/c.pdf', 'carte.pdf', 'application/pdf', 1000) id`))[0].id;
  await as(U(15));
  await q(`select document_review('${d3}', 'verified')`);
  await as(U(19));
  const ml = (await q(`select mentors_list() r`))[0].r;
  check('S8-15 : pièce d\'étudiant vérifiée : le mentor est publié et listé', ml.length === 1 && ml[0].user_id === U(18) && ml[0].status === 'verified');
  await db.exec('reset role');
  check('S8-15 : la personne est prévenue de la publication', await n(`select count(*)::int n from notifications where user_id = '${U(18)}' and kind = 'mentor_profile' and title = 'Profil mentor validé'`) === 1);
  await as(U(18));
  check('S8-15 : mentor vérifié : histoire de réussite possible', !!(await q(`select mentor_story_save('Mon parcours', 'Je raconte mon parcours depuis le début des études') id`))[0].id);
  await as(null, 'anon');
  check('S8-15 : histoire visible du public après vérification', (await q(`select mentor_stories() r`))[0].r.length === 1);
  await as(U(19));
  // S8-17
  const rid = (await q(`select mentor_request('${U(18)}', 'Flutter', 'Aide svp') id`))[0].id;
  await as(U(18));
  await q(`select mentor_request_decide('${rid}', false)`);
  await as(U(19));
  await fails('S8-17 : nouvelle demande dans les 7 jours après un refus : refusée', `select mentor_request('${U(18)}', 'Flutter encore')`, /patientez 7 jours/);
  await db.exec('reset role');
  await db.exec(`update mentor_requests set decided_at = now() - interval '8 days'`);
  await as(U(19));
  const rid2 = (await q(`select mentor_request('${U(18)}', 'Flutter', 'Nouvelle demande') id`))[0].id;
  check('S8-17 : après 7 jours la demande est possible', !!rid2);
  await as(U(18));
  await q(`select mentor_save('Eneo', 'Promo 2022', array['Flutter'], 'Je peux aider en mobile', 'busy', true)`);
  await fails('S8-17 : un mentor « pas disponible » ne peut pas accepter', `select mentor_request_decide('${rid2}', true)`, /pas disponible/);
  await q(`select mentor_save('Eneo', 'Promo 2022', array['Flutter'], 'Je peux aider en mobile', 'available', true)`);
  check('S8-17 : disponible : acceptation possible', (await q(`select mentor_request_decide('${rid2}', true) r`))[0].r === 'accepted');
  await as(U(19));
  await q(`select mentor_review('${rid2}', 5, 'Très utile')`);
  await q(`select mentor_review('${rid2}', 4, 'Très utile, merci')`);
  await db.exec('reset role');
  check('S8-17 : l\'avis reste modifiable les 7 premiers jours', (await q(`select rating from mentor_reviews where request_id = '${rid2}'`))[0].rating === 4);
  await db.exec(`update mentor_reviews set created_at = now() - interval '10 days'`);
  await as(U(19));
  await fails('S8-17 : après 7 jours l\'avis n\'est plus modifiable', `select mentor_review('${rid2}', 1, 'Finalement non')`, /ne peut plus être modifié/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${U(19)}'`);
  await as(U(19));
  await fails('S8-17 : un compte suspendu ne peut plus demander de mentor', `select mentor_request('${U(18)}', 'Autre sujet')`, /suspendu/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${U(19)}'`);

  // ============================================================ S8-24 : un client ne publie pas d'offre
  await as(U(16));
  await fails('S8-24 : le rôle client ne publie pas d\'offre (SQL aligné sur Flutter)', post('Offre client', 'false'), /Réservé aux (entreprises|organisations)/);
  await as(U(11));
  await fails('S8-24 : ni l\'étudiant connecté', post('Offre étudiant', 'false'), /Réservé aux (entreprises|organisations)/);

  console.log(`\n${ok}/${ok + ko}`);
}
