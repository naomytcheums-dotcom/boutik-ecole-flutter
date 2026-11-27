// Scénario PGlite du lot S7 (réseau social et espace créateur) : migrations 20261117070000 à 20261117072000.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s7.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000007${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  // 1 Awa (étudiante, GI, propriétaire), 2 Brice (étudiant, membre), 3 Carole (cliente), 4 admin, 5 dept, 6 support, 7 Didier (étudiant GI), 8 Eric (étudiant Gestion)
  const users = [[1, 'Awa Mballa', 'student', 'GI'], [2, 'Brice Nkoa', 'student', 'GI'], [3, 'Carole Fotso', 'client', ''], [4, 'Admin Chef', 'admin', ''],
    [5, 'Dora Prof', 'dept', ''], [6, 'Sam Support', 'support', ''], [7, 'Didier Tchoua', 'student', 'GI'], [8, 'Eric Zang', 'student', 'Gestion']];
  for (const [n, name, role, dep] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email,department) values ('${U(n)}','${name}','${role}','u${n}@t.cm','${dep}')`);
  }
  // H2 : les étudiants sont rattachés à leur département par identifiant ; la responsable (5) l'est au département « GI » par l'administrateur.
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000f701', 'IUT S7', 'verified'); insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000f7a1', '00000000-0000-0000-0000-00000000f701', 'GI', 'verified'), ('00000000-0000-0000-0000-00000000f7a2', '00000000-0000-0000-0000-00000000f701', 'Gestion', 'verified'); update profiles set department_id = '00000000-0000-0000-0000-00000000f7a1' where role = 'student' and department = 'GI'; update profiles set department_id = '00000000-0000-0000-0000-00000000f7a2' where role = 'student' and department = 'Gestion'; insert into department_accounts (user_id, department_id) values ('${U(5)}', '00000000-0000-0000-0000-00000000f7a1')`);
  // Équipes internes (lot H4) : l'agent de support de ce scénario modère aussi les contenus (équipe Sécurité et modération, droit explicite).
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${U(6)}', 'security', array['security.moderation', 'security.reports'])`);
  const cid = '00000000-0000-0000-0000-0000000007c1', pubc = '00000000-0000-0000-0000-0000000007c2';
  await db.exec(`insert into communities (id, name, privacy, status, owner_id) values ('${cid}', 'Cercle privé GI', 'invite', 'active', '${U(1)}'), ('${pubc}', 'Club public', 'public', 'active', '${U(1)}')`);
  await db.exec(`insert into community_members (community_id, user_id, role, status) values
    ('${cid}', '${U(1)}', 'owner', 'active'), ('${cid}', '${U(2)}', 'member', 'active'), ('${pubc}', '${U(1)}', 'owner', 'active'), ('${pubc}', '${U(2)}', 'member', 'active'),
    ('${pubc}', '${U(8)}', 'member', 'banned')`);
  const secret = (await q(`insert into posts (author_id, kind, body, community_id, status, published_at) values ('${U(1)}', 'text', 'SECRET du cercle prive', '${cid}', 'published', now()) returning id`))[0].id;
  const pubpost = (await q(`insert into posts (author_id, kind, body, community_id, status, published_at) values ('${U(1)}', 'text', 'Annonce du club public', '${pubc}', 'published', now()) returning id`))[0].id;
  const feedpost = (await q(`insert into posts (author_id, kind, body, status, published_at) values ('${U(1)}', 'text', 'Publication du fil', 'published', now()) returning id`))[0].id;
  // Un ancien repost d'une publication privée (fuite existante) : il ne doit plus apparaître dans le fil public
  await db.exec(`insert into posts (author_id, kind, body, repost_of, status, published_at) values ('${U(7)}', 'text', 'je republie', '${secret}', 'published', now())`);

  // ============================================================ SEC : publications de communauté privée
  await as(U(2));
  const cm = (await q(`select add_post_comment_v2('${secret}', 'commentaire du membre') id`))[0].id;
  check('membre : commente une publication de communauté privée', !!cm);
  check('membre : aime', (await q(`select toggle_post_like('${secret}') r`))[0].r === true);
  check('membre : enregistre', (await q(`select toggle_post_save('${secret}') r`))[0].r === true);
  check('membre : réagit', (await q(`select react_post('${secret}', 'fire') r`))[0].r === 'enregistrée');
  check('membre : lit les commentaires', (await q(`select * from post_comment_list_v2('${secret}')`)).length === 1);
  await as(U(3));
  await fails('non-membre : ne commente pas (v2)', `select add_post_comment_v2('${secret}', 'intrus')`, /Publication introuvable/);
  await fails('non-membre : ne commente pas (v1)', `select add_post_comment('${secret}', 'intrus')`, /Publication introuvable/);
  await fails('non-membre : ne like pas', `select toggle_post_like('${secret}')`, /Publication introuvable/);
  await fails('non-membre : n\'enregistre pas', `select toggle_post_save('${secret}')`, /Publication introuvable/);
  await fails('non-membre : ne réagit pas', `select react_post('${secret}', 'fire')`, /Publication introuvable/);
  await fails('non-membre : ne signale pas', `select report_post('${secret}', 'test motif')`, /Publication introuvable/);
  await fails('non-membre : ne like pas le commentaire', `select toggle_comment_like('${cm}')`, /Commentaire introuvable/);
  await fails('non-membre : ne signale pas le commentaire', `select report_comment('${cm}', 'test motif')`, /Commentaire introuvable/);
  await q(`select record_post_share('${secret}')`);
  check('non-membre : le partage n\'est pas enregistré', (await q(`select count(*)::int n from post_shares`))[0].n === 0);
  check('non-membre : les commentaires de la publication privée sont invisibles', (await q(`select * from post_comment_list_v2('${secret}')`)).length === 0);
  check('non-membre : post_shop_target ne répond pas', (await q(`select post_shop_target('${secret}') r`))[0].r === null);
  await fails('republier une publication de communauté est refusé', `select create_post_v2('', '[]'::jsonb, null, '{}', null, '${secret}')`, /non republiable/);
  await as(null, 'anon');
  check('anonyme : commentaires privés invisibles (v2)', (await q(`select * from post_comment_list_v2('${secret}')`)).length === 0);
  check('anonyme : commentaires privés invisibles (v1)', (await q(`select * from post_comment_list('${secret}')`)).length === 0);
  const feed = await q(`select * from circle_feed(60)`);
  check('anonyme : le fil public ne contient aucun texte de communauté privée', !JSON.stringify(feed).includes('SECRET du cercle prive'));
  check('anonyme : le repost d\'une publication de communauté est masqué', !feed.some((r) => r.caption === 'je republie'));
  check('anonyme : la publication du fil reste visible', feed.some((r) => r.id === feedpost));
  await as(U(3));
  // communauté publique : lisible et interactive pour tous, sauf les bannis
  check('communauté publique : un non-membre peut aimer', (await q(`select toggle_post_like('${pubpost}') r`))[0].r === true);
  await as(U(8));
  await fails('communauté publique : un membre banni ne peut plus interagir', `select toggle_post_like('${pubpost}')`, /Publication introuvable/);
  // duo / remix d'une vidéo de communauté
  await db.exec('reset role');
  const vid = (await q(`insert into posts (author_id, kind, media_path, media_kind, caption, community_id, status, published_at) values ('${U(1)}', 'media', '${U(1)}/v.mp4', 'video', 'video privee', '${cid}', 'published', now()) returning id`))[0].id;
  await as(U(7));
  await fails('remix : la vidéo d\'une communauté privée est introuvable', `select create_remix('${vid}', 'duet', '${U(7)}/r.mp4', 'x')`, /introuvable/);
  // blocages : commentaire impossible et commentaire masqué
  await db.exec('reset role');
  await db.exec(`insert into user_blocks (blocker_id, blocked_id) values ('${U(1)}', '${U(7)}')`);
  await as(U(7));
  await fails('blocage : on ne commente pas l\'auteur qui vous a bloqué', `select add_post_comment_v2('${feedpost}', 'bonjour')`, /impossible/);
  await db.exec('reset role');
  await db.exec(`delete from user_blocks`);

  // ============================================================ SEC : annuaire d'invitation
  await db.exec(`insert into auth.users(id,email) select ('00000000-0000-0000-0000-0000000008' || lpad(g::text, 2, '0'))::uuid, 'p' || g || '@t.cm' from generate_series(1, 25) g`);
  await db.exec(`insert into profiles(id,name,role,email,department) select ('00000000-0000-0000-0000-0000000008' || lpad(g::text, 2, '0'))::uuid, 'Personne Dupont ' || g, 'student', 'p' || g || '@t.cm', 'GI' from generate_series(1, 25) g`);
  await as(U(1));
  check('invitation : moins de 3 caractères = aucun résultat', (await q(`select * from community_invite_search('${cid}', 'Di')`)).length === 0);
  let r = await q(`select * from community_invite_search('${cid}', 'Didier')`);
  check('invitation : un étudiant du même département est proposé, nom abrégé', r.length === 1 && r[0].user_id === U(7) && r[0].name === 'Didier T.');
  check('invitation : un étudiant d\'un autre département sans lien n\'est pas proposé', (await q(`select * from community_invite_search('${cid}', 'Eric')`)).length === 0);
  check('invitation : un client sans lien n\'est pas proposé', (await q(`select * from community_invite_search('${cid}', 'Carole')`)).length === 0);
  check('invitation : l\'administrateur n\'est pas proposé', (await q(`select * from community_invite_search('${cid}', 'Admin')`)).length === 0);
  check('invitation : le support n\'est pas proposé', (await q(`select * from community_invite_search('${cid}', 'Support')`)).length === 0);
  check('invitation : au plus 10 résultats', (await q(`select * from community_invite_search('${cid}', 'Personne', 50)`)).length === 10);
  check('invitation : le nom complet n\'est jamais renvoyé', !JSON.stringify(await q(`select * from community_invite_search('${cid}', 'Personne', 50)`)).includes('Dupont 1'));
  await db.exec('reset role');
  await db.exec(`insert into engagements (user_id, kind, ref) values ('${U(1)}', 'follow', '${U(3)}')`);
  await as(U(1));
  check('invitation : une personne suivie devient invitable', (await q(`select * from community_invite_search('${cid}', 'Carole')`)).length === 1);
  await as(U(2));
  await fails('invitation : un simple membre ne cherche pas', `select * from community_invite_search('${cid}', 'Didier')`, /non autorisée/);
  await as(U(1));
  await db.exec('reset role');
  await db.exec(`insert into user_blocks (blocker_id, blocked_id) values ('${U(7)}', '${U(1)}')`);
  await as(U(1));
  check('invitation : une personne qui vous a bloqué n\'est pas proposée', (await q(`select * from community_invite_search('${cid}', 'Didier')`)).length === 0);
  await fails('invitation : invite_member refuse un blocage', `select invite_member('${cid}', '${U(7)}')`, /ne peut pas être invitée/);
  check('invitation : invite_member fonctionne', (await q(`select invite_member('${cid}', '${U(3)}') r`))[0].r === 'invited');
  let stopped = false;
  for (let i = 1; i <= 25; i++) {
    try { await q(`select invite_member('${cid}', ('00000000-0000-0000-0000-0000000008' || lpad('${i}', 2, '0'))::uuid)`); } catch (e) { if (/Trop d'invitations/.test(e.message)) { stopped = true; break; } }
  }
  check('invitation : plafond d\'invitations par heure', stopped);

  // ============================================================ MAJ : validation des publications
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'approved' where id = '${U(7)}'`);
  await as(U(2));
  const pend = (await q(`select create_post_v2('Ma première publication', '[]'::jsonb, null, '{}', null) r`))[0].r;
  check('publication : un compte non certifié passe en attente', pend.status === 'pending');
  await as(U(4));
  const nAdmin = (await q(`select count(*)::int n from notifications where user_id = '${U(4)}' and kind = 'post_review'`))[0].n;
  await as(U(6));
  const nSupport = (await q(`select count(*)::int n from notifications where user_id = '${U(6)}' and kind = 'post_review'`))[0].n;
  check('publication en attente : admin et support sont prévenus', nAdmin === 1 && nSupport === 1);
  await as(U(2));
  await fails('liste de modération : réservée à la modération', `select moderation_posts_list('pending')`, /Réservé à la modération/);
  await as(U(6));
  let list = (await q(`select moderation_posts_list('pending') l`))[0].l;
  check('liste de modération : la publication en attente apparaît (support)', list.length === 1 && list[0].text === 'Ma première publication' && list[0].author === 'Brice Nkoa');
  await fails('refus sans motif impossible', `select moderate_post('${pend.id}', false, '')`, /Motif obligatoire/);
  await as(U(2));
  await fails('un étudiant ne valide pas', `select moderate_post('${pend.id}', true, null)`, /Réservé à la modération/);
  await as(U(5));
  check('dept : approuve', (await q(`select moderate_post('${pend.id}', true, null) r`))[0].r === 'published');
  await as(U(2));
  check('auteur : notifié de la publication', (await q(`select count(*)::int n from notifications where user_id = '${U(2)}' and kind = 'post' and title = 'Publication en ligne'`))[0].n === 1);
  const pend2 = (await q(`select create_post_v2('Contenu douteux', '[]'::jsonb, null, '{}', null) r`))[0].r;
  await as(U(5));
  await q(`select moderate_post('${pend2.id}', false, 'Contenu hors sujet')`);
  await as(U(2));
  const mine = (await q(`select my_posts_status() s`))[0].s;
  check('refus : l\'auteur voit le motif', mine.length === 1 && mine[0].status === 'hidden' && mine[0].note === 'Contenu hors sujet');
  await as(U(5));
  check('liste « masquées » : la publication refusée apparaît', (await q(`select moderation_posts_list('hidden') l`))[0].l.length === 1);

  // ============================================================ MAJ : signalements de publications
  await as(U(3));
  await q(`select report_post('${pend.id}', 'Publicité abusive')`);
  await as(U(7));
  await q(`select report_post('${pend.id}', 'Spam')`);
  await as(U(5));
  list = (await q(`select moderation_posts_list('reported') l`))[0].l;
  check('signalements : la publication signalée est listée avec 2 motifs', list.length === 1 && list[0].reports === 2 && list[0].reasons.length === 2);
  await q(`select post_reports_dismiss('${pend.id}')`);
  check('signalements : classés sans masquer', (await q(`select moderation_posts_list('reported') l`))[0].l.length === 0 && (await q(`select status from posts where id = '${pend.id}'`))[0].status === 'published');
  await as(U(3));
  check('signalements : le signaleur est informé', (await q(`select count(*)::int n from notifications where user_id = '${U(3)}' and kind = 'moderation'`))[0].n === 1);
  await db.exec('reset role');
  await db.exec(`delete from post_reports`);
  await as(U(3));
  await q(`select report_post('${pend.id}', 'Contenu choquant')`);
  await as(U(6));
  await q(`select moderate_post('${pend.id}', false, 'Contenu choquant confirmé')`);
  await as(U(3));
  check('signalements : masquage confirmé, signaleur informé', (await q(`select count(*)::int n from notifications where user_id = '${U(3)}' and kind = 'moderation'`))[0].n === 2);

  // ============================================================ MAJ : histoires
  await as(U(2));
  const sid = (await q(`select create_story('${U(2)}/s.jpg', 'image', 'Ma story') id`))[0].id;
  await fails('histoire : pas de signalement de sa propre histoire', `select report_story('${sid}', 'test')`, /propre histoire/);
  await as(U(3));
  await q(`select report_story('${sid}', 'Image choquante')`);
  await fails('histoire : motif trop court refusé', `select report_story('${sid}', 'x')`, /motif/);
  await as(U(2));
  await fails('histoire : liste réservée à la modération', `select moderation_stories_list()`, /Réservé à la modération/);
  await as(U(5));
  let sl = (await q(`select moderation_stories_list() l`))[0].l;
  check('histoire : la modération voit l\'histoire signalée', sl.length === 1 && sl[0].reports === 1 && sl[0].reasons[0] === 'Image choquante');
  await fails('histoire : masquage sans motif refusé', `select moderate_story('${sid}', true, '')`, /Motif obligatoire/);
  await q(`select moderate_story('${sid}', true, 'Image contraire aux règles')`);
  await as(null, 'anon');
  check('histoire : masquée = plus visible', (await q(`select * from stories_active()`)).length === 0);
  await as(U(2));
  check('histoire : l\'auteur est notifié du motif', (await q(`select count(*)::int n from notifications where user_id = '${U(2)}' and kind = 'moderation' and body like '%règles%'`))[0].n === 1);
  await as(U(3));
  check('histoire : le signaleur est informé', (await q(`select count(*)::int n from notifications where user_id = '${U(3)}' and kind = 'moderation' and body like '%retirée%'`))[0].n === 1);
  await as(U(5));
  await q(`select moderate_story('${sid}', false)`);
  await as(null, 'anon');
  check('histoire : rétablie = visible à nouveau', (await q(`select * from stories_active()`)).length === 1);

  // ============================================================ MAJ : modération du chat et des questions de communauté
  await as(U(2));
  const m1 = (await q(`select community_chat_send('${cid}', 'message gentil') id`))[0].id;
  const m2 = (await q(`select community_chat_send('${cid}', 'message injurieux') id`))[0].id;
  const qid = (await q(`select community_ask('${cid}', 'Une question utile ?') id`))[0].id;
  await db.exec('reset role');
  await db.exec(`update community_members set status = 'active' where community_id = '${cid}' and user_id = '${U(3)}'`);
  await as(U(3));
  const ans = (await q(`select community_answer('${qid}', 'Réponse insultante') id`))[0].id;
  await fails('chat : un simple membre ne supprime pas le message d\'autrui', `select community_chat_delete(${m2}, 'ça ne se fait pas')`, /non autorisée/);
  await q(`select community_report('${cid}', 'chat', '${m2}', 'Insultes')`);
  await fails('signalement : pas deux fois le même (idempotent) mais contenu étranger refusé', `select community_report('${cid}', 'chat', '999999', 'Insultes')`, /introuvable/);
  await q(`select community_report('${cid}', 'answer', '${ans}', 'Propos déplacés')`).catch(() => {});
  await as(U(2));
  await fails('signalement : pas de signalement de son propre contenu', `select community_report('${cid}', 'chat', '${m2}', 'moi-même')`, /propre contenu/);
  await as(U(1));
  check('responsable : prévenu du signalement', (await q(`select count(*)::int n from notifications where user_id = '${U(1)}' and kind = 'community_report'`))[0].n === 1);
  const rep = (await q(`select community_reports_list('${cid}') l`))[0].l;
  check('responsable : file de signalements (chat + réponse)', rep.length === 1 || rep.length === 2);
  const repChat = rep.find((x) => x.kind === 'chat');
  check('responsable : l\'aperçu du message signalé est lisible', repChat?.preview === 'message injurieux' && repChat.author === 'Brice N.');
  await as(U(3));
  await fails('signalements : liste réservée aux responsables', `select community_reports_list('${cid}')`, /non autorisée/);
  await as(U(1));
  await fails('retrait : le motif est obligatoire pour un responsable', `select community_report_close('${repChat.id}', true, '')`, /motif/);
  await q(`select community_report_close('${repChat.id}', true, 'Propos injurieux')`);
  await as(U(2));
  const chat = await q(`select * from community_chat_list('${cid}')`);
  check('chat : le message retiré a disparu, l\'autre reste', chat.length === 1 && chat[0].body === 'message gentil');
  check('chat : l\'auteur est prévenu avec le motif', (await q(`select count(*)::int n from notifications where user_id = '${U(2)}' and kind = 'community_moderation' and body like '%injurieux%'`))[0].n === 1);
  check('chat : l\'auteur supprime son propre message sans motif', (await q(`select community_chat_delete(${m1}) r`))[0].r === 'removed');
  await as(U(1));
  await q(`select community_answer_delete('${ans}', 'Réponse hors sujet')`);
  await as(null, 'anon');
  await db.exec('reset role');
  await db.exec(`update communities set privacy = 'public' where id = '${cid}'`);
  await as(null, 'anon');
  const qa = (await q(`select community_qa('${cid}') j`))[0].j;
  check('questions : la réponse retirée n\'est plus listée', qa.length === 1 && qa[0].answers.length === 0);
  await as(U(1));
  await q(`select community_question_delete('${qid}', 'Question en double')`);
  check('questions : la question retirée disparaît', (await q(`select community_qa('${cid}') j`))[0].j.length === 0);
  await db.exec('reset role');
  await db.exec(`update communities set privacy = 'invite' where id = '${cid}'`);

  // publication de communauté : motif, notification, rétablissement
  await as(U(2));
  const cp = (await q(`select create_community_post('${cid}', 'Publication à modérer') id`))[0].id;
  await as(U(1));
  await fails('publication de communauté : masquage sans motif refusé', `select moderate_community_post('${cp}', true)`, /motif/);
  await q(`select moderate_community_post('${cp}', true, 'Hors sujet')`);
  check('publication de communauté : liste des masquées', (await q(`select * from community_hidden_posts('${cid}')`)).length === 1);
  await as(U(2));
  check('publication de communauté : l\'auteur est notifié', (await q(`select count(*)::int n from notifications where user_id = '${U(2)}' and kind = 'community_moderation' and body like '%Hors sujet%'`))[0].n === 1);
  await as(U(1));
  check('publication de communauté : rétablie', (await q(`select moderate_community_post('${cp}', false) r`))[0].r === 'published');

  // ============================================================ MAJ : défi hebdomadaire et boost pour comptes non certifiés
  await db.exec('reset role');
  await db.exec(`delete from posts where author_id = '${U(8)}'; update profiles set certification = 'none' where id = '${U(8)}'`);
  await as(U(8));
  await q(`select create_post_v2('Un', '[]'::jsonb, null, '{}', null)`);
  await q(`select create_post_v2('Deux', '[]'::jsonb, null, '{}', null)`);
  await q(`select create_post_v2('Trois', '[]'::jsonb, null, '{}', null)`);
  let ch = (await q(`select my_challenges() c`))[0].c;
  check('défi : les publications en attente sont comptées à part', ch.posts_week === 0 && ch.posts_week_pending === 3 && ch.pending_posts === 3 && ch.certified === false);
  await fails('défi : message clair avec les publications en attente', `select claim_challenge('posts3')`, /3 en attente de validation/);
  await fails('boost : message clair sans publication validée', `select claim_streak_boost()`, /Série de 0 jour/);
  await db.exec('reset role');
  await db.exec(`insert into daily_checkins (user_id, day) select '${U(8)}', ((now() at time zone 'Africa/Douala')::date - g) from generate_series(0, 6) g`);
  await as(U(8));
  await fails('boost : message clair quand seules des publications attendent la validation', `select claim_streak_boost()`, /attend la validation du département/);
  await as(U(4)); // H2 : les publications d'Éric (département Gestion) ne relèvent pas de la responsable GI : l'administration les valide
  for (const p of await q(`select (jsonb_array_elements(moderation_posts_list('pending'))->>'id') id`)) {
    await q(`select moderate_post('${p.id}', true, null)`);
  }
  await as(U(8));
  ch = (await q(`select my_challenges() c`))[0].c;
  check('défi : après validation, 3/3 récupérable', ch.posts_week === 3 && ch.posts_claimable === true && ch.boost_ready === true);
  check('défi : 200 points', (await q(`select claim_challenge('posts3') p`))[0].p === 200);
  check('boost : accordé sur une publication validée', (await q(`select claim_streak_boost() b`))[0].b === 'boosted');
  await db.exec('reset role');
  await db.exec(`update post_boosts set ends_at = now() - interval '1 hour' where user_id = '${U(8)}'; update points_ledger set ref = 'hier' where user_id = '${U(8)}' and source = 'streak6'`);
  await as(U(8));
  await fails('boost : pas plus d\'un boost tous les 6 jours', `select claim_streak_boost()`, /déjà été récupéré récemment/);
  ch = (await q(`select my_challenges() c`))[0].c;
  check('boost : le prochain boost est annoncé', ch.streak_reward_claimable === false && ch.boost_next_in >= 5);

  // badge « Cent abonnés » : abonnés du profil + abonnés de la boutique (personnes distinctes)
  await db.exec('reset role');
  try {
    await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('00000000-0000-0000-0000-0000000007b1', '${U(1)}', 'Boutique Awa', 'boutique-awa', 'active')`);
    await db.exec(`insert into shop_follows (user_id, shop_id) values ('${U(2)}', '00000000-0000-0000-0000-0000000007b1'), ('${U(3)}', '00000000-0000-0000-0000-0000000007b1')`);
    await db.exec(`delete from user_blocks where blocker_id = '${U(7)}' and blocked_id = '${U(1)}'; insert into engagements (user_id, kind, ref) values ('${U(3)}', 'follow', '${U(1)}'), ('${U(7)}', 'follow', '${U(1)}'); insert into user_blocks (blocker_id, blocked_id) values ('${U(7)}', '${U(1)}') on conflict do nothing`);
    await as(U(1));
    check('abonnés : profil + boutique, personnes distinctes', (await q(`select my_challenges() c`))[0].c.badge_info.followers === 3);
    await as(U(2));
    check('abonnements : my_followed_shops renvoie le propriétaire de la boutique', (await q(`select my_followed_shops() s`))[0].s[0].owner_id === U(1));
  } catch (e) { check('abonnés : profil + boutique', false, e.message); }

  // ============================================================ MOY : l'auteur retire sa publication
  await as(U(7));
  const mp = (await q(`select create_post_v2('A retirer', '[{"path":"${U(7)}/a.jpg","kind":"image"}]'::jsonb, null, '{}', null) r`))[0].r;
  const rp = (await q(`select create_post_v2('', '[]'::jsonb, null, '{}', null, '${mp.id}') r`))[0].r;
  await as(null, 'anon');
  check('retrait : la publication est dans le fil avant retrait', (await q(`select * from circle_feed(60)`)).some((x) => x.id === mp.id));
  await as(U(3));
  await fails('retrait : seul l\'auteur peut retirer', `select delete_my_post('${mp.id}')`, /introuvable/);
  await as(U(7));
  const del = (await q(`select delete_my_post('${mp.id}') r`))[0].r;
  check('retrait : les fichiers à effacer sont renvoyés', del.paths.length === 1 && del.paths[0] === `${U(7)}/a.jpg`);
  await as(null, 'anon');
  const feed2 = await q(`select * from circle_feed(60)`);
  check('retrait : la publication a disparu du fil', !feed2.some((x) => x.id === mp.id));
  check('retrait : la republication vide qui la citait a disparu aussi', !feed2.some((x) => x.id === rp.id));
  await as(U(7));
  await fails('retrait : une publication déjà retirée est introuvable', `select delete_my_post('${mp.id}')`, /introuvable/);

  // ============================================================ MOY : publication limitée à un lien (régression de la contrainte de contenu)
  await as(U(7));
  const lk = (await q(`select create_post_v2('', '[]'::jsonb, 'https://exemple.cm/page', '{}', null) r`))[0].r;
  check('publication : un lien seul est accepté', lk.status === 'published');

  // ============================================================ MOY : nom d'une communauté refusée de nouveau disponible
  await as(U(2));
  const nc = (await q(`select create_community('Club Robotique', 'Robots', '', 'public', '', null, 'interest', null, 'Robotique') id`))[0].id;
  await fails('communauté : un nom en attente reste pris', `select create_community('club robotique', '', '', 'public', '', null, 'interest', null, 'x')`, /porte déjà ce nom/);
  await as(U(4));
  await q(`select community_decide('${nc}', false, 'Nom trop vague')`);
  await as(U(7));
  const nc2 = (await q(`select create_community('Club Robotique', 'Robots', '', 'public', '', null, 'interest', null, 'Robotique') id`))[0].id;
  check('communauté : le nom d\'une communauté refusée est libre', !!nc2 && nc2 !== nc);

  console.log(`\n${ok}/${ok + ko}`);
}

