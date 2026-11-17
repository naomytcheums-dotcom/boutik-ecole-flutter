// Lot G7 (profil Étudiant, 2e passe) : migration 20261119070000 — messagerie, candidatures, coéquipiers, mentors, vœux, salons vocaux.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./etu2_g7.mjs  (attendu : aucune ligne ECHEC)
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
  // 11 A étudiante, 12 B étudiante, 13 C étudiante, 14 E étudiant, 15 F mentor, 16 S étudiant (sera suspendu), 17 T étudiante, 18 K client,
  // 19 Co entreprise approuvée, 20 Cx entreprise non approuvée, 21 D dept, 22 M admin
  const users = [[11, 'Awa Ndiaye', 'student'], [12, 'Boris Etudiant', 'student'], [13, 'Cora Etudiante', 'student'], [14, 'Eric Etudiant', 'student'], [15, 'Fanta Mentore', 'student'],
    [16, 'Samuel Suspendu', 'student'], [17, 'Tina Etudiante', 'student'], [18, 'Kim Cliente', 'client'], [19, 'Orange Cameroun', 'company'], [20, 'Nouvelle Entreprise', 'company'],
    [21, 'Doua Dept', 'dept'], [22, 'Mod Admin', 'admin']];
  for (const [id, nm, role] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${U(id)}','u${id}@t.cm'); insert into profiles(id,name,role,email,department,skills,bio) values ('${U(id)}','${nm}','${role}','u${id}@t.cm','Génie informatique','Flutter, Canva','Je développe des applications mobiles')`);
  }
  await db.exec(`update profiles set certification = 'approved' where role = 'student'`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${U(19)}', 'Orange Cameroun', 'approved'), ('${U(20)}', 'Nouvelle Entreprise', 'pending');
    insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at) values ('${U(19)}', 'partner', 'active', now(), now() + interval '30 days')`);
  const suspend = async (id, on) => { await db.exec('reset role'); await db.exec(`update profiles set suspended = ${on} where id = '${U(id)}'`); };

  // ============================================================ 1. Messagerie : plafond serveur sur l'envoi direct
  await as(U(11));
  const cid = (await q(`select start_direct_conversation('${U(12)}', 'Salut Boris') id`))[0].id;
  for (let i = 0; i < 19; i++) await q(`insert into messages (conversation_id, sender_id, body) values ('${cid}', '${U(11)}', 'm${i}')`);
  await fails('G7-1 : le 21e message de la minute est refusé par le serveur (insertion directe)', `insert into messages (conversation_id, sender_id, body) values ('${cid}', '${U(11)}', 'spam')`, /Trop de messages/);
  await as(U(12));
  await q(`insert into messages (conversation_id, sender_id, body) values ('${cid}', '${U(12)}', 'Reponse de Boris')`);
  check('G7-1 : le plafond est par expéditeur : le destinataire peut répondre', (await n(`select count(*)::int n from messages where sender_id = '${U(12)}'`)) === 1);
  await as(U(22));
  const cidAdmin = (await q(`select start_direct_conversation('${U(13)}', 'Message de l equipe') id`))[0].id;
  await q(`insert into messages (conversation_id, sender_id, body) values ('${cidAdmin}', '${U(22)}', 'Deuxieme message')`);
  check('G7-1 : administration : envoi normal non gêné', (await n(`select count(*)::int n from messages where conversation_id = '${cidAdmin}'`)) === 2);
  await as(U(19));
  await q(`select start_direct_conversation('${U(13)}', 'Proposition de stage')`).catch(() => null);
  await as(null, 'anon');
  await fails('G7-1 : visiteur : aucun envoi', `insert into messages (conversation_id, sender_id, body) values ('${cid}', '${U(11)}', 'x')`, /permission|row-level/);
  await as(U(16));
  await suspend(16, true);
  await as(U(16));
  await fails('G7-1 : compte suspendu : message direct refusé', `select start_direct_conversation('${U(12)}', 'Bonjour')`, /suspendu/);
  await suspend(16, false);

  // ============================================================ 2. Candidatures
  await as(U(19));
  const post = (title) => `select opp_save('Orange Cameroun', 'stage', 'academique', '${title}', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', current_date + 10, array['Flutter','Canva'], 'Description complete de l offre pour les etudiants', array['Developper des ecrans','Tester'], 'Etudiant motive', 'Génie informatique', 'Licence 2', array['Attestation'], '', true, 'Operateur', false) id`;
  const oA = (await q(post('Stage Flutter')))[0].id;
  const oB = (await q(post('Stage Design')))[0].id;
  await as(U(22));
  await q(`select opp_decide('${oA}', true, true)`);
  await q(`select opp_decide('${oB}', true, true)`);
  const lettre = 'Je suis tres motivee pour ce stage de developpement';
  await as(U(11));
  const app = (await q(`select opp_apply('${oA}', '${lettre}') id`))[0].id;
  check('G7-2 : candidature acceptée', !!app);
  await fails('G7-2 : doublon refusé avec un message clair', `select opp_apply('${oA}', '${lettre}')`, /déjà postulé/);
  await as(U(16));
  await suspend(16, true);
  await as(U(16));
  await fails('G7-2 : compte suspendu : candidature refusée', `select opp_apply('${oB}', '${lettre}')`, /Compte suspendu/);
  await suspend(16, false);
  await as(U(19));
  await q(`select block_user('${U(12)}', true)`);
  await as(U(12));
  await fails('G7-2 : bloqué par l\'auteur : candidature refusée sans révéler le blocage', `select opp_apply('${oA}', '${lettre}')`, /n'accepte plus de candidatures/);
  await as(U(19));
  await q(`select block_user('${U(12)}', false)`);
  await as(U(12));
  check('G7-2 : débloqué : la candidature passe', !!(await q(`select opp_apply('${oA}', '${lettre}') id`))[0].id);
  await as(U(18));
  check('G7-2 : un client peut postuler (comportement conservé)', !!(await q(`select opp_apply('${oB}', '${lettre}') id`))[0].id);
  await as(null, 'anon');
  await fails('G7-2 : visiteur : candidature refusée', `select opp_apply('${oA}', '${lettre}')`, /permission|Connexion/);
  // plafond de 20 candidatures par jour
  await db.exec('reset role');
  await db.exec(`insert into opportunities select (jsonb_populate_record(null::opportunities, to_jsonb(o) || jsonb_build_object('id', gen_random_uuid()))).* from opportunities o, generate_series(1, 21) where o.id = '${oA}'`);
  const extra = (await q(`select id from opportunities where title = 'Stage Flutter' and id <> '${oA}' order by id`)).map((r) => r.id);
  await as(U(13));
  for (let i = 0; i < 20; i++) await q(`select opp_apply('${extra[i]}', '${lettre}')`);
  await fails('G7-2 : 21e candidature du jour refusée', `select opp_apply('${extra[20]}', '${lettre}')`, /Vingt candidatures/);

  // invitation : « Non merci »
  await as(U(19));
  await q(`select opp_invite('${oB}', '${U(14)}', 'Venez postuler')`);
  await as(U(14));
  await q(`select opp_invite_decline('${oB}')`);
  check('G7-2 : « Non merci » enregistré', (await q(`select opp_my_invite('${oB}') r`))[0].r.status === 'declined');
  await fails('G7-2 : refus répété : invitation déjà traitée', `select opp_invite_decline('${oB}')`, /introuvable|déjà traitée/);
  await as(U(13));
  await fails('G7-2 : sans invitation : introuvable', `select opp_invite_decline('${oB}')`, /introuvable|déjà traitée/);
  await as(null, 'anon');
  await fails('G7-2 : visiteur : refus d\'invitation interdit', `select opp_invite_decline('${oB}')`, /permission|Connexion/);

  // ============================================================ 3. Coéquipiers
  for (const id of [12, 13, 14, 16, 17]) { await as(U(id)); await q(`select mates_visibility_set(true)`); }
  await as(U(11));
  const i1 = (await q(`select teammate_invite('${U(12)}', 'Hackathon ?') id`))[0].id;
  check('G7-3 : invitation vers un étudiant consentant', !!i1);
  await fails('G7-3 : doublon en attente refusé', `select teammate_invite('${U(12)}', 'Encore')`, /déjà en attente/);
  await as(U(12));
  await fails('G7-3 : invitation croisée : répondre plutôt qu\'inviter', `select teammate_invite('${U(11)}', 'Moi aussi')`, /déjà invité/);
  await q(`select teammate_invite_decide('${i1}', false)`);
  await as(U(11));
  await fails('G7-3 : après un refus, 7 jours d\'attente', `select teammate_invite('${U(12)}', 'Reviens')`, /décliné votre dernière invitation/);
  // profil retiré de l'annuaire
  await db.exec('reset role');
  await db.exec(`update profiles set directory_listed = false where id = '${U(13)}'`);
  await as(U(11));
  await fails('G7-3 : profil retiré de l\'annuaire : invitation refusée', `select teammate_invite('${U(13)}', 'Salut')`, /pas dans l'annuaire/);
  await db.exec('reset role');
  await db.exec(`update profiles set directory_listed = true where id = '${U(13)}'`);
  // blocage
  await as(U(13));
  await q(`select block_user('${U(11)}', true)`);
  await as(U(11));
  await fails('G7-3 : blocage : invitation refusée', `select teammate_invite('${U(13)}', 'Salut')`, /ne peut pas recevoir/);
  await as(U(13));
  await q(`select block_user('${U(11)}', false)`);
  // acceptation, déjà coéquipiers, messages
  await as(U(11));
  const i2 = (await q(`select teammate_invite('${U(14)}', 'Equipe ?') id`))[0].id;
  await as(U(14));
  check('G7-3 : acceptation', (await q(`select teammate_invite_decide('${i2}', true) r`))[0].r === 'accepted');
  await as(U(11));
  await fails('G7-3 : déjà coéquipiers : pas de nouvelle invitation', `select teammate_invite('${U(14)}', 'Encore')`, /déjà coéquipiers/);
  check('G7-3 : message d\'équipe envoyé', !!(await q(`select teammate_message_send('${i2}', 'On se voit demain ?') id`))[0].id);
  await as(U(14));
  await q(`select block_user('${U(11)}', true)`);
  await fails('G7-3 : après blocage, l\'ancien coéquipier ne peut plus écrire', `select teammate_message_send('${i2}', 'Hello')`, /ne peut pas recevoir/);
  await as(U(11));
  await fails('G7-3 : ... et l\'autre sens non plus', `select teammate_message_send('${i2}', 'Hello')`, /ne peut pas recevoir/);
  await as(U(14));
  await q(`select block_user('${U(11)}', false)`);
  await suspend(14, true);
  await as(U(14));
  await fails('G7-3 : compte suspendu : message d\'équipe refusé', `select teammate_message_send('${i2}', 'Hello')`, /suspendu/);
  await suspend(14, false);
  // compte suspendu : réponse à une invitation et invitation
  await as(U(17));
  const i3 = (await q(`select teammate_invite('${U(16)}', 'Equipe ?') id`))[0].id;
  await suspend(16, true);
  await as(U(16));
  await fails('G7-3 : compte suspendu : réponse refusée', `select teammate_invite_decide('${i3}', true)`, /suspendu/);
  await fails('G7-3 : compte suspendu : invitation refusée', `select teammate_invite('${U(17)}', 'Salut')`, /réservées aux étudiants/);
  await suspend(16, false);
  // invitant suspendu : l'acceptation est refusée
  await as(U(13));
  const i4 = (await q(`select teammate_invite('${U(17)}', 'Equipe ?') id`))[0].id;
  await suspend(13, true);
  await as(U(17));
  await fails('G7-3 : invitant suspendu : acceptation refusée', `select teammate_invite_decide('${i4}', true)`, /n'est plus valable/);
  check('G7-3 : ... mais le refus reste possible', (await q(`select teammate_invite_decide('${i4}', false) r`))[0].r === 'declined');
  await suspend(13, false);
  await as(U(18));
  await fails('G7-3 : client : invitation refusée', `select teammate_invite('${U(12)}', 'Salut')`, /réservées aux étudiants/);
  await as(U(20));
  await fails('G7-3 : entreprise non approuvée : invitation refusée', `select teammate_invite('${U(12)}', 'Salut')`, /réservées aux étudiants/);
  await as(null, 'anon');
  await fails('G7-3 : visiteur : invitation refusée', `select teammate_invite('${U(12)}', 'Salut')`, /permission|Connexion/);
  await as(U(11));
  check('G7-3 : une seule invitation en attente par paire (index)', (await n(`select count(*)::int n from pg_indexes where indexname = 'teammate_invites_pending_uk'`)) === 1);

  // ============================================================ 4. Mentors
  await as(U(15));
  await q(`select mentor_save('Eneo', 'Promo 2022', array['Flutter'], 'Je peux aider en mobile', 'available', true)`);
  await db.exec('reset role');
  await db.exec(`update mentor_profiles set status = 'verified' where user_id = '${U(15)}'`);
  await as(U(11));
  const rq = (await q(`select mentor_request('${U(15)}', 'Flutter', 'Aide svp') id`))[0].id;
  check('G7-4 : demande à un mentor vérifié', !!rq);
  await db.exec('reset role');
  await db.exec(`update mentor_profiles set active = false where user_id = '${U(15)}'`);
  await as(U(15));
  await fails('G7-4 : profil mentor inactif : acceptation refusée', `select mentor_request_decide('${rq}', true)`, /actif et vérifié/);
  await db.exec('reset role');
  await db.exec(`update mentor_profiles set active = true where user_id = '${U(15)}'`);
  await as(U(15));
  check('G7-4 : profil actif et vérifié : acceptation', (await q(`select mentor_request_decide('${rq}', true) r`))[0].r === 'accepted');
  await q(`select mentor_story_save('Mon parcours', 'Je raconte mon parcours depuis mes etudes jusqu au premier emploi', 'Eneo')`);
  check('G7-4 : histoire d\'un mentor vérifié listée', (await q(`select mentor_stories(10) r`))[0].r.length === 1);
  await as(U(13));
  const rq2 = (await q(`select mentor_request('${U(15)}', 'Flutter', 'Moi aussi') id`))[0].id;
  await as(U(15));
  await q(`select block_user('${U(14)}', true)`);
  await as(U(14));
  await fails('G7-4 : bloqué par le mentor : demande refusée', `select mentor_request('${U(15)}', 'Flutter', 'Aide')`, /Mentor introuvable/);
  await as(U(15));
  await q(`select block_user('${U(14)}', false)`);
  // avis par un compte suspendu
  await as(U(11));
  await suspend(11, true);
  await as(U(11));
  await fails('G7-4 : compte suspendu : avis refusé', `select mentor_review('${rq}', 5, 'Super')`, /Compte suspendu/);
  await suspend(11, false);
  await as(U(11));
  await q(`select mentor_review('${rq}', 5, 'Super')`);
  await db.exec('reset role');
  check('G7-4 : avis publié', (await n(`select count(*)::int n from mentor_reviews`)) === 1);
  // mentor suspendu : plus joignable
  await suspend(15, true);
  await as(U(12));
  await fails('G7-4 : mentor suspendu : demande refusée', `select mentor_request('${U(15)}', 'Flutter', 'Aide')`, /Mentor introuvable/);
  await fails('G7-4 : mentor suspendu : fiche introuvable', `select mentor_detail('${U(15)}')`, /Mentor introuvable/);
  check('G7-4 : mentor suspendu : histoires masquées', (await q(`select mentor_stories(10) r`))[0].r.length === 0);
  await as(U(15));
  await fails('G7-4 : mentor suspendu : histoire refusée', `select mentor_story_save('Autre histoire', 'Je raconte une autre histoire assez longue pour passer', 'Eneo')`, /Compte suspendu/);
  await fails('G7-4 : mentor suspendu : décision refusée', `select mentor_request_decide('${rq2}', true)`, /Compte suspendu/);
  await suspend(15, false);
  await as(U(22));
  check('G7-4 : l\'administration voit toujours la fiche', (await q(`select mentor_detail('${U(15)}') r`))[0].r.user_id === U(15));
  await as(null, 'anon');
  check('G7-4 : visiteur : fiche d\'un mentor vérifié', (await q(`select mentor_detail('${U(15)}') r`))[0].r.user_id === U(15));
  await fails('G7-4 : visiteur : demande refusée', `select mentor_request('${U(15)}', 'Flutter', 'Aide')`, /permission|Connexion/);

  // ============================================================ 5. Vœux
  await db.exec('reset role');
  const W = (n2) => `00000000-0000-0000-0000-0000000000f${n2}`;
  await db.exec(`insert into wishes (id, author_id, title, description, price, threshold, duration_days, status, opened_at) values
    ('${W(1)}', '${U(14)}', 'Sac connecte', 'Un sac solaire', 15000, 5, 10, 'approved', now() - interval '1 day'),
    ('${W(2)}', '${U(14)}', 'Campagne finie', 'Ancien voeu', 9000, 5, 10, 'approved', now() - interval '20 days'),
    ('${W(3)}', '${U(16)}', 'Voeu du suspendu', 'Voeu', 9000, 5, 10, 'approved', now() - interval '1 day');
    insert into wish_preorders (wish_id, user_id, created_at) values ('${W(2)}', '${U(11)}', now() - interval '15 days')`);
  await as(U(11));
  check('G7-5 : précommande sur un vœu ouvert', (await q(`select wish_preorder('${W(1)}', true) r`))[0].r.mine === true);
  check('G7-5 : retrait possible tant que la campagne est ouverte', (await q(`select wish_preorder('${W(1)}', false) r`))[0].r.mine === false);
  await fails('G7-5 : campagne close : la précommande ne se retire plus', `select wish_preorder('${W(2)}', false)`, /closes/);
  await db.exec('reset role');
  check('G7-5 : précommande conservée en base', (await n(`select count(*)::int n from wish_preorders where wish_id = '${W(2)}'`)) === 1);
  await suspend(16, true);
  await as(U(12));
  await fails('G7-5 : vœu d\'un auteur suspendu : précommande refusée', `select wish_preorder('${W(3)}', true)`, /pas ouvert/);
  check('G7-5 : vœu d\'un auteur suspendu : absent du marché', !(await q(`select wishes_market('all', 50) r`))[0].r.some((w) => w.id === W(3)));
  check('G7-5 : vœu d\'un auteur actif : présent au marché', (await q(`select wishes_market('all', 50) r`))[0].r.some((w) => w.id === W(1)));
  await suspend(16, false);
  await suspend(12, true);
  await as(U(12));
  await fails('G7-5 : compte suspendu : précommande refusée', `select wish_preorder('${W(1)}', true)`, /Compte suspendu/);
  await suspend(12, false);
  await as(U(14));
  await fails('G7-5 : auteur : précommande de son propre vœu refusée', `select wish_preorder('${W(1)}', true)`, /propre vœu/);
  await as(null, 'anon');
  check('G7-5 : visiteur : marché lisible', (await q(`select wishes_market('all', 50) r`))[0].r.length >= 1);
  await fails('G7-5 : visiteur : précommande refusée', `select wish_preorder('${W(1)}', true)`, /permission|Connexion/);

  // ============================================================ 6. Salons vocaux
  await as(U(11));
  const com = (await q(`select create_community('Dev Flutter','Entraide autour de Flutter','','public','',null,'interest',null,'Flutter') id`))[0].id;
  await as(U(22));
  await q(`select community_decide('${com}', true)`);
  for (const id of [12, 16]) { await as(U(id)); await q(`select join_community('${com}')`); }
  await as(U(12));
  const room = (await q(`select study_room_create('${com}', 'Revision reseaux', 'TP') id`))[0].id;
  await suspend(16, true);
  await as(U(16));
  await fails('G7-6 : compte suspendu : entrée refusée', `select study_room_enter('${room}')`, /Compte suspendu/);
  await fails('G7-6 : compte suspendu : création refusée', `select study_room_create('${com}', 'Salon pirate')`, /Compte suspendu/);
  await suspend(16, false);
  await as(U(13));
  await fails('G7-6 : non-membre : entrée refusée', `select study_room_enter('${room}')`, /membres/);
  await as(U(12));
  await q(`select study_room_close('${room}')`);
  for (const t of ['Maths', 'Algo', 'Reseaux2']) { const r = (await q(`select study_room_create('${com}', '${t}') id`))[0].id; await q(`select study_room_close('${r}')`); }
  await fails('G7-6 : quatre salons par heure au plus', `select study_room_create('${com}', 'Cinquieme')`, /Quatre salons par heure/);
  await as(U(11));
  check('G7-6 : un autre membre garde sa liberté de créer un salon', !!(await q(`select study_room_create('${com}', 'Salon de Awa') id`))[0].id);
  await as(null, 'anon');
  await fails('G7-6 : visiteur : entrée refusée', `select study_room_enter('${room}')`, /permission|Connexion/);

  console.log(`\nG7 : ${ok} OK, ${ko} ECHEC`);
}
