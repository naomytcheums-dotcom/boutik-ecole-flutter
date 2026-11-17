// Scénario PGlite du lot G6 (profil social et contenu de l'étudiant) — migrations 20261119060000 à 20261119069900.
// Un test PGlite prouve la logique SQL, pas la production.
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000006${String(n).padStart(5, '0')}`;
  let cur = [null, 'authenticated'];
  const as = async (uid, role = 'authenticated') => { cur = [uid, role]; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const one = async (sql) => (await q(sql))[0].r;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const rd = async (sql) => { const c = cur; await db.exec('reset role'); const r = (await db.query(sql)).rows[0]?.r; await as(...c); return r; };
  const works = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, false, e.message); } };

  // STU Alice (étudiante), PUB étudiant public, MEM profil « membres », PRI profil privé, SUS suspendu, BLK bloqué par Alice, CLI client, CMP entreprise, DEP dept, ADM admin, STU2 autre étudiant
  const STU = U(1), PUB = U(2), MEM = U(3), PRI = U(4), SUS = U(5), BLK = U(6), CLI = U(7), CMP = U(8), DEP = U(9), ADM = U(10), STU2 = U(11);
  await db.exec('reset role');
  const mk = async (id, nm, role, extra = '') => {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.toLowerCase().replace(/ /g, '')}@t.cm')`);
    await db.exec(`insert into profiles(id,name,role,email,department) values ('${id}','${nm}','${role}','${nm.toLowerCase().replace(/ /g, '')}@t.cm','Génie')`);
    if (extra) await db.exec(`update profiles set ${extra} where id = '${id}'`);
  };
  await mk(STU, 'Alice Dupont', 'student'); await mk(PUB, 'Paul Public', 'student'); await mk(MEM, 'Marc Membre', 'student', `profile_visibility = 'members'`);
  await mk(PRI, 'Patrick Prive', 'student', `profile_visibility = 'private'`); await mk(SUS, 'Sam Suspendu', 'student'); await mk(BLK, 'Bruno Bloque', 'student');
  await mk(CLI, 'Claire Client', 'client'); await mk(CMP, 'Cam Entreprise', 'company'); await mk(DEP, 'Daniel Dept', 'dept'); await mk(ADM, 'Admin Root', 'admin'); await mk(STU2, 'Eve Etudiante', 'student');
  const post = async (id, author, caption) => db.exec(`insert into posts (id, author_id, kind, media_path, media_kind, caption, status, published_at) values ('${id}', '${author}', 'media', '${author}/p.jpg', 'image', '${caption}', 'published', now())`);
  const P = (n) => `00000000-0000-0000-0000-0000006a${String(n).padStart(4, '0')}`;
  await post(P(1), PUB, 'pub'); await post(P(2), MEM, 'mem'); await post(P(3), PRI, 'pri'); await post(P(4), SUS, 'sus'); await post(P(5), BLK, 'blk'); await post(P(6), STU, 'moi');
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await db.exec(`insert into user_blocks (blocker_id, blocked_id) values ('${STU}', '${BLK}')`);
  const ids = async (sql) => (await q(sql)).map((r) => r.caption ?? r.author ?? r.id).sort().join();

  // ================================================================ 1. S2-85 : profile_visible respecté (fil Reels, fil du cercle, profil public)
  await as(null, 'anon');
  check('reels_feed anonyme : seul le profil public (ni membres, ni privé, ni suspendu)', (await ids(`select caption from reels_feed(50)`)).split(',').sort().join() === 'blk,moi,pub');
  check('circle_feed anonyme : idem', (await ids(`select caption from circle_feed(50)`)).split(',').sort().join() === 'blk,moi,pub');
  await as(CLI);
  check('reels_feed client connecté : profil « membres » visible, privé et suspendu non', (await ids(`select caption from reels_feed(50)`)) === 'blk,mem,moi,pub');
  await as(STU);
  check('reels_feed : la personne bloquée n\'apparaît plus (blocage réel)', (await ids(`select caption from reels_feed(50)`)) === 'mem,moi,pub');
  check('circle_feed : la personne bloquée n\'apparaît plus', (await ids(`select caption from circle_feed(50)`)) === 'mem,moi,pub');
  await as(PRI);
  check('reels_feed : le titulaire d\'un profil privé voit sa propre publication', (await ids(`select caption from reels_feed(50)`)).includes('pri'));
  await as(DEP);
  check('reels_feed : le département (rôle connecté) ne lit pas le profil privé', (await ids(`select caption from reels_feed(50)`)) === 'blk,mem,moi,pub');
  await as(ADM);
  check('reels_feed : l\'administration voit le profil privé mais pas le suspendu', (await ids(`select caption from reels_feed(50)`)) === 'blk,mem,moi,pri,pub');
  await as(null, 'anon');
  check('author_posts : profil membres masqué à un visiteur', (await q(`select id from author_posts('${MEM}')`)).length === 0);
  check('author_posts : profil privé masqué à un visiteur', (await q(`select id from author_posts('${PRI}')`)).length === 0);
  check('author_posts : compte suspendu vide', (await q(`select id from author_posts('${SUS}')`)).length === 0);
  check('author_posts : profil public lisible par un visiteur', (await q(`select id from author_posts('${PUB}')`)).length === 1);
  await as(CLI);
  check('author_posts : profil membres lisible par un compte connecté', (await q(`select id from author_posts('${MEM}')`)).length === 1);
  check('author_posts : profil privé toujours masqué à un client', (await q(`select id from author_posts('${PRI}')`)).length === 0);
  await as(PRI);
  check('author_posts : le titulaire lit ses propres publications', (await q(`select id from author_posts('${PRI}')`)).length === 1);
  await as(STU);
  check('author_posts : une personne bloquée n\'est plus listée', (await q(`select id from author_posts('${BLK}')`)).length === 0);
  await as(DEP);
  check('author_posts : le département ne lit pas un profil privé', (await q(`select id from author_posts('${PRI}')`)).length === 0);
  await as(ADM);
  check('author_posts : l\'administration lit un profil privé', (await q(`select id from author_posts('${PRI}')`)).length === 1);

  // ================================================================ S2-85 : user_level, community_levels, top_helpers
  await db.exec('reset role');
  await db.exec(`insert into point_events (user_id, kind, points, ref) values ('${PUB}', 'answer', 100, 'a'), ('${MEM}', 'answer', 90, 'b'), ('${PRI}', 'answer', 80, 'c'), ('${SUS}', 'answer', 70, 'd'), ('${STU}', 'answer', 60, 'e')`);
  await as(null, 'anon');
  check('user_level anonyme : profil public lisible', (await one(`select user_level('${PUB}') r`))?.total === 100);
  check('user_level anonyme : profil membres masqué (null)', (await one(`select user_level('${MEM}') r`)) === null);
  check('user_level anonyme : profil privé masqué', (await one(`select user_level('${PRI}') r`)) === null);
  check('user_level anonyme : compte suspendu masqué', (await one(`select user_level('${SUS}') r`)) === null);
  await as(CLI);
  check('user_level connecté : profil membres lisible', (await one(`select user_level('${MEM}') r`))?.total === 90);
  check('user_level connecté : profil privé masqué', (await one(`select user_level('${PRI}') r`)) === null);
  await as(PRI);
  check('user_level : le titulaire lit son propre niveau', (await one(`select user_level('${PRI}') r`))?.total === 80);
  await as(ADM);
  check('user_level : l\'administration lit un profil privé', (await one(`select user_level('${PRI}') r`))?.total === 80);
  await as(null, 'anon');
  let top = await one(`select top_helpers(20) r`);
  check('top_helpers anonyme : seulement les profils publics non suspendus', top.map((x) => x.user_id).sort().join() === [PUB, STU].sort().join(), JSON.stringify(top));
  check('top_helpers : noms abrégés', top.every((x) => /\w+ \w\.$/.test(x.name) || /^\w+$/.test(x.name)), JSON.stringify(top.map((x) => x.name)));
  await as(CLI);
  top = await one(`select top_helpers(20) r`);
  check('top_helpers connecté : profil membres inclus, privé et suspendu exclus', top.map((x) => x.user_id).sort().join() === [MEM, PUB, STU].sort().join(), JSON.stringify(top));
  await as(PRI);
  top = await one(`select top_helpers(20) r`);
  check('top_helpers : le titulaire privé se voit lui-même', top.some((x) => x.user_id === PRI));

  // ================================================================ 2. Histoires : blocage, visibilité, noms, faux succès
  await db.exec('reset role');
  const S = (n) => `00000000-0000-0000-0000-0000006b${String(n).padStart(4, '0')}`;
  const story = async (id, author, sticker = 'null') => db.exec(`insert into stories (id, author_id, media_path, media_kind, caption, sticker, expires_at) values ('${id}', '${author}', '${author}/s.jpg', 'image', 'c', ${sticker === 'null' ? 'null' : `'${sticker}'::jsonb`}, now() + interval '1 day')`);
  await story(S(1), PUB); await story(S(2), PRI); await story(S(3), BLK); await story(S(4), STU, '{"type":"question","text":"Une question ?"}'); await story(S(5), PUB, '{"type":"question","text":"Q2 ?"}');
  await story(S(6), MEM);
  await as(null, 'anon');
  check('stories_active anonyme : profils publics seulement', (await q(`select id from stories_active()`)).map((r) => r.id).sort().join() === [S(1), S(3), S(4), S(5)].sort().join());
  await as(STU);
  check('stories_active : bloqué et privé absents, membres présent', (await q(`select id from stories_active()`)).map((r) => r.id).sort().join() === [S(1), S(4), S(5), S(6)].sort().join());
  await fails('answer_story : l\'histoire d\'une personne bloquée est refusée', `select answer_story('${S(3)}', null, 'salut')`, /n'accepte pas/);
  await as(STU2);
  await works('answer_story : réponse autorisée sur une histoire publique', `select answer_story('${S(4)}', null, 'Je suis Eve Etudiante')`);
  await as(CLI);
  await works('answer_story : un client peut répondre', `select answer_story('${S(4)}', null, 'Bonjour')`);
  await as(STU);
  const res = await one(`select story_results('${S(4)}') r`);
  check('story_results : noms des répondants abrégés (pas de nom complet)', res.answers.length === 2 && res.answers.every((a) => /^\w+ \w\.$/.test(a.name)), JSON.stringify(res));
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${STU2}'`);
  await as(STU);
  check('story_results : réponse d\'un compte suspendu non listée', (await one(`select story_results('${S(4)}') r`)).answers.length === 1);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${STU2}'`);
  await as(SUS);
  await fails('answer_story : compte suspendu refusé', `select answer_story('${S(5)}', null, 'x')`, /suspendu/);
  await as(DEP);
  await fails('hide_story : histoire inconnue = erreur (plus de faux succès)', `select hide_story('00000000-0000-0000-0000-0000006bffff')`, /introuvable/);
  check('hide_story : le département masque une histoire réelle', (await one(`select hide_story('${S(1)}') r`)) === 'masquée');
  await as(STU);
  await fails('hide_story : un étudiant ne masque pas l\'histoire d\'autrui', `select hide_story('${S(5)}')`, /non autorisée/);
  check('hide_story : l\'auteur supprime sa propre histoire', (await one(`select hide_story('${S(4)}') r`)) === 'supprimée');

  // ================================================================ 3. Commentaires : compteur cohérent avec la liste, faux succès
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${SUS}'`);
  await db.exec(`insert into post_comments (post_id, author_id, body) values ('${P(1)}', '${PUB}', 'c1'), ('${P(1)}', '${BLK}', 'bloque'), ('${P(1)}', '${SUS}', 'suspendu'), ('${P(1)}', '${STU2}', 'c4')`);
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await as(STU);
  const cnt = (await q(`select comments from reels_feed(50) where id = '${P(1)}'`))[0].comments;
  const lst = (await q(`select id from post_comment_list_v2('${P(1)}')`)).length;
  check('compteur de commentaires = commentaires listés (bloqué et suspendu exclus)', cnt === 2 && lst === 2, `${cnt} / ${lst}`);
  await as(CLI);
  check('compteur de commentaires pour un autre lecteur (bloqué inclus, suspendu exclu)', (await q(`select comments from circle_feed(50) where id = '${P(1)}'`))[0].comments === 3);
  await as(DEP);
  await fails('delete_post_comment : commentaire inconnu = erreur', `select delete_post_comment('00000000-0000-0000-0000-0000006cffff')`, /introuvable/);
  const cid = (await q(`select id from post_comments where body = 'c4'`))[0].id;
  check('delete_post_comment : le département masque un vrai commentaire', (await one(`select delete_post_comment('${cid}') r`)) === 'masqué');
  await as(CLI);
  await fails('delete_post_comment : un client ne masque pas', `select delete_post_comment('${cid}')`, /non autorisée/);

  // ================================================================ 4. Signalement et blocage réels
  await as(STU);
  await fails('report_post : motif trop court', `select report_post('${P(1)}', 'x')`, /motif/);
  await fails('report_post : sa propre publication', `select report_post('${P(6)}', 'spam abusif')`, /propre publication/);
  check('report_post : signalement enregistré', (await one(`select report_post('${P(1)}', 'contenu choquant') r`)) === 'reported');
  check('report_post : le signalement existe en base', (await rd(`select count(*)::int r from post_reports where post_id = '${P(1)}'`)) === 1);
  check('report_post : le département est prévenu', (await rd(`select count(*)::int r from notifications where user_id = '${DEP}' and kind = 'report'`)) === 1);
  await as(SUS);
  await fails('report_post : compte suspendu refusé', `select report_post('${P(1)}', 'contenu choquant')`, /suspendu/);
  await as(STU);
  await fails('block_user : soi-même', `select block_user('${STU}', true)`, /propre compte/);
  await fails('block_user : personne inconnue (message clair)', `select block_user('00000000-0000-0000-0000-0000006dffff', true)`, /introuvable/);
  await works('block_user : blocage réel', `select block_user('${PUB}', true)`);
  check('block_user : la publication disparaît des Reels', !(await ids(`select caption from reels_feed(50)`)).includes('pub'));
  await works('block_user : déblocage', `select block_user('${PUB}', false)`);
  check('block_user : déblocage rétablit les publications', (await ids(`select caption from reels_feed(50)`)).includes('pub'));
  await as(null, 'anon');
  await fails('block_user : anonyme refusé', `select block_user('${PUB}', true)`, /permission denied|Connexion/);

  // ================================================================ 5. Comptes suspendus : aucune écriture
  await as(SUS);
  await fails('create_post_v2 : compte suspendu', `select create_post_v2('texte', '[]'::jsonb, null, '{}', null, null)`, /suspendu/);
  await fails('create_story : compte suspendu', `select create_story('${SUS}/a.jpg', 'image', 'x', 24, null)`, /suspendu/);
  await fails('portfolio_save : compte suspendu', `select portfolio_save(null, 'link', 'Mon site', '', '', '', 'https://exemple.cm', null, false)`, /suspendu/);
  await fails('project_save_full : compte suspendu', `select project_save_full(null, 'projet', 'Projet suspendu', 'x', 'Génie', '{}'::jsonb, '[]'::jsonb, 'public', false)`, /Réservé|suspendu/);
  await db.exec('reset role');
  await fails('trigger : projet inséré pour un suspendu refusé', `insert into projects (owner_id, title, status) values ('${SUS}', 'Fantôme', 'draft')`, /suspendu/);
  await fails('trigger : élément de portfolio d\'un suspendu refusé', `insert into portfolio_items (owner_id, kind, title) values ('${SUS}', 'link', 'Fantôme')`, /suspendu/);

  // ================================================================ 6. Portfolio : lecture selon visibilité et suspension
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${SUS}'`);
  await as(PUB); await works('portfolio_save : étudiant public', `select portfolio_save(null, 'link', 'Mon site', 'desc', 'web', '2026', 'https://exemple.cm', null, true)`);
  await as(SUS); await works('portfolio_save : compte non suspendu', `select portfolio_save(null, 'link', 'Site de Sam', 'desc', 'web', '2026', 'https://sam.cm', null, false)`);
  await db.exec('reset role'); await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await as(null, 'anon');
  check('portfolio : un visiteur lit le portfolio public', (await q(`select id from portfolio_items where owner_id = '${PUB}'`)).length === 1);
  check('portfolio : le portfolio d\'un compte suspendu est masqué', (await q(`select id from portfolio_items where owner_id = '${SUS}'`)).length === 0);
  await as(SUS);
  check('portfolio : le titulaire suspendu relit encore ses éléments', (await q(`select id from portfolio_items where owner_id = '${SUS}'`)).length === 1);
  await fails('portfolio_save : modification refusée à un suspendu', `select portfolio_save('${(await rd(`select id r from portfolio_items where owner_id = '${SUS}'`))}', 'link', 'Nouveau', '', '', '', 'https://sam.cm', null, false)`, /suspendu/);

  // ================================================================ 7. Projets : visibilité publique, annuaire, blocage
  await db.exec('reset role');
  const PR = '00000000-0000-0000-0000-0000006e0001', PR2 = '00000000-0000-0000-0000-0000006e0002';
  await db.exec(`update profiles set suspended = false where id = '${SUS}'`);
  await db.exec(`insert into projects (id, owner_id, title, summary, status, visibility, details) values ('${PR}', '${PUB}', 'Projet public', 'résumé', 'approved', 'public', '{"contact_email":"x@y.cm","domain":"web"}'), ('${PR2}', '${SUS}', 'Projet suspendu', 'résumé', 'approved', 'public', '{}')`);
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await as(null, 'anon');
  check('public_projects : le projet du compte suspendu n\'est pas listé', (await one(`select jsonb_array_length(public_projects()) r`)) === 1);
  check('public_project_get : visiteur, projet suspendu = null', (await one(`select public_project_get('${PR2}') r`)) === null);
  check('public_project_get : visiteur, projet public, contact retiré', (await one(`select public_project_get('${PR}') r`)).details.contact_email === undefined);
  await as(SUS);
  check('public_project_get : le porteur suspendu relit son projet', (await one(`select public_project_get('${PR2}') r`)) !== null);
  await as(STU);
  await works('project_upvote_toggle : soutien', `select project_upvote_toggle('${PR}')`);
  check('project_upvote_toggle : un second appel retire (pas de doublon)', (await one(`select project_upvote_toggle('${PR}') r`)) === false);
  await db.exec('reset role');
  await db.exec(`update profiles set directory_listed = false where id = '${STU2}'`);
  await as(STU);
  check('project_member_search : hors annuaire exclu', (await one(`select jsonb_array_length(project_member_search('Eve')) r`)) === 0);
  check('project_member_search : un profil privé est exclu même listé', (await one(`select jsonb_array_length(project_member_search('Patrick')) r`)) === 0);
  check('project_member_search : un étudiant public est trouvé', (await one(`select jsonb_array_length(project_member_search('Paul')) r`)) === 1);
  check('project_member_search : la personne bloquée est exclue', (await one(`select jsonb_array_length(project_member_search('Bruno')) r`)) === 0);
  await as(CLI);
  await fails('project_member_search : client refusé', `select project_member_search('Paul')`, /Réservé/);
  await as(STU);
  await db.exec('reset role');
  const PR3 = '00000000-0000-0000-0000-0000006e0003', PR4 = '00000000-0000-0000-0000-0000006e0004';
  await db.exec(`insert into projects (id, owner_id, title, summary, status, visibility) values ('${PR3}', '${STU}', 'Brouillon secret', 'x', 'draft', 'private'), ('${PR4}', '${STU}', 'Public mais en examen', 'x', 'submitted', 'public')`);
  await as(null, 'anon');
  check('public_project_get : un visiteur ne lit pas un brouillon privé', (await one(`select public_project_get('${PR3}') r`)) === null);
  check('public_project_get : un visiteur ne lit pas un projet en cours d\'examen', (await one(`select public_project_get('${PR4}') r`)) === null);
  await as(CLI);
  check('public_project_get : un client ne lit pas un brouillon', (await one(`select public_project_get('${PR3}') r`)) === null);
  await as(STU);
  check('public_project_get : le porteur lit son brouillon', (await one(`select public_project_get('${PR3}') r`)) !== null);
  await as(DEP);
  check('public_project_get : le département lit un projet en examen', (await one(`select public_project_get('${PR4}') r`)) !== null);
  await as(STU);
  await fails('project_member_invite : personne bloquée refusée', `select project_member_invite('${PR3}', '${BLK}', 'dev')`, /ne peut pas/);

  // ================================================================ 8. Concours : énumération, clôture, dépôt
  await db.exec('reset role');
  const C = '00000000-0000-0000-0000-0000006f0001', T = '00000000-0000-0000-0000-0000006f0101';
  await db.exec(`insert into contests (id, title, description, places, status, reg_close_at, submit_close_at) values ('${C}', 'Hackathon G6', 'description du concours assez longue', 10, 'published', now() + interval '3 days', now() + interval '6 days')`);
  await db.exec(`insert into contest_teams (id, contest_id, name, captain_id, rules_accepted_at) values ('${T}', '${C}', 'Equipe Alpha', '${STU}', now()); insert into contest_members (team_id, user_id, status) values ('${T}', '${STU}', 'captain')`);
  await as(STU);
  check('invite_contest_member : adresse inconnue = même réponse', (await one(`select invite_contest_member('${T}', 'inconnu@nulle-part.cm') r`)) === 'invited');
  check('invite_contest_member : adresse inconnue = aucune invitation créée', (await rd(`select count(*)::int r from contest_members where team_id = '${T}'`)) === 1);
  check('invite_contest_member : adresse réelle = même réponse', (await one(`select invite_contest_member('${T}', 'eveetudiante@t.cm') r`)) === 'invited');
  check('invite_contest_member : l\'invitation réelle existe', (await rd(`select count(*)::int r from contest_members where team_id = '${T}' and user_id = '${STU2}' and status = 'invited'`)) === 1);
  check('invite_contest_member : un client (adresse non étudiante) = même réponse, rien créé', (await one(`select invite_contest_member('${T}', 'claireclient@t.cm') r`)) === 'invited' && (await rd(`select count(*)::int r from contest_members where user_id = '${CLI}'`)) === 0);
  check('invite_contest_member : la personne bloquée n\'est pas invitée', (await one(`select invite_contest_member('${T}', 'brunobloque@t.cm') r`)) === 'invited' && (await rd(`select count(*)::int r from contest_members where user_id = '${BLK}'`)) === 0);
  await fails('invite_contest_member : adresse mal formée', `select invite_contest_member('${T}', 'pasunemail')`, /invalide/);
  await as(PUB);
  await fails('invite_contest_member : seul le capitaine invite', `select invite_contest_member('${T}', 'eveetudiante@t.cm')`, /capitaine/);
  await as(STU2);
  await db.exec('reset role'); await db.exec(`update contests set reg_close_at = now() - interval '1 hour' where id = '${C}'`); await as(STU2);
  await fails('answer_contest_invite : acceptation après clôture des inscriptions refusée', `select answer_contest_invite('${T}', true)`, /closes/);
  await db.exec('reset role'); await db.exec(`update contests set reg_close_at = now() + interval '2 days' where id = '${C}'`); await as(STU2);
  check('answer_contest_invite : acceptation dans les délais', (await one(`select answer_contest_invite('${T}', true) r`)) === 'member');
  await as(STU);
  await fails('submit_contest_project : fichier hors du dossier du capitaine refusé', `select submit_contest_project('${T}', 'Projet A', '${'d'.repeat(40)}', null, null, '${PUB}/deck.pdf', true, false)`, /Fichier de présentation/);
  await fails('submit_contest_project : description trop courte (message clair)', `select submit_contest_project('${T}', 'Projet A', 'court', null, null, null, true, false)`, /Description/);
  await fails('submit_contest_project : lien non http(s)', `select submit_contest_project('${T}', 'Projet A', '${'d'.repeat(40)}', 'javascript:alert(1)', null, null, true, false)`, /liens/);
  await works('submit_contest_project : brouillon valide', `select submit_contest_project('${T}', 'Projet A', '${'d'.repeat(40)}', 'https://demo.exemple.cm', null, '${STU}/deck.pdf', true, false)`);
  await works('submit_contest_project : dépôt final', `select submit_contest_project('${T}', 'Projet A', '${'d'.repeat(40)}', 'https://demo.exemple.cm', null, '${STU}/deck.pdf', true, true)`);
  await fails('submit_contest_project : plus de modification après dépôt', `select submit_contest_project('${T}', 'Projet B', '${'d'.repeat(40)}', null, null, null, true, true)`, /déjà soumis/);
  await as(PUB);
  await fails('submit_contest_project : un non-capitaine ne dépose pas', `select submit_contest_project('${T}', 'Projet B', '${'d'.repeat(40)}', null, null, null, true, true)`, /capitaine/);
  await as(null, 'anon');
  await fails('submit_contest_project : anonyme refusé', `select submit_contest_project('${T}', 'Projet B', '${'d'.repeat(40)}', null, null, null, true, true)`, /permission denied|Connexion/);

  // ================================================================ 9. Compétences et réussites : suspendus
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${SUS}'`);
  await db.exec(`insert into skill_offers (author_id, kind, title, description, swap_for, status) values ('${PUB}', 'offer', 'Cours Flutter', 'desc', '', 'open'), ('${SUS}', 'offer', 'Cours fantôme', 'desc', '', 'open')`);
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await as(CLI);
  check('skills_list : l\'offre d\'un compte suspendu n\'est pas listée', (await one(`select jsonb_array_length(skills_list()) r`)) === 1);

  // ================================================================ 10. Défis : réalisations d'un suspendu
  await db.exec('reset role');
  const CH = '00000000-0000-0000-0000-0000006f0201', E1 = '00000000-0000-0000-0000-0000006f0301', E2 = '00000000-0000-0000-0000-0000006f0302';
  await db.exec(`insert into weekly_challenges (id, title, description, kind, ends_at) values ('${CH}', 'Défi test', 'd', 'design', now() + interval '2 days')`);
  await db.exec(`update profiles set suspended = false where id = '${SUS}'`);
  await db.exec(`insert into challenge_entries (id, challenge_id, author_id, title) values ('${E1}', '${CH}', '${PUB}', 'Ma réalisation'), ('${E2}', '${CH}', '${SUS}', 'Réalisation fantôme')`);
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await as(STU);
  check('challenges_list : la réalisation d\'un compte suspendu n\'est pas listée', (await one(`select challenges_list() r`)).find((c) => c.id === CH).entries.length === 1);
  await fails('challenge_vote : voter pour un compte suspendu est refusé', `select challenge_vote('${E2}')`, /introuvable/);
  await works('challenge_vote : vote autorisé pour une réalisation active', `select challenge_vote('${E1}')`);
  await works('challenge_vote : revoter ne crée pas de doublon', `select challenge_vote('${E1}')`);
  check('challenge_vote : un seul vote en base', (await rd(`select count(*)::int r from challenge_votes where challenge_id = '${CH}' and user_id = '${STU}'`)) === 1);
  await as(PUB);
  await fails('challenge_vote : sa propre réalisation refusée', `select challenge_vote('${E1}')`, /propre réalisation/);
  await as(null, 'anon');
  await fails('challenge_vote : anonyme refusé', `select challenge_vote('${E1}')`, /permission denied|Connexion/);

  // ================================================================ 11. Communautés : adhésion, départ, décision, bannissement
  await db.exec('reset role');
  const CP = '00000000-0000-0000-0000-0000006c0001', CA = '00000000-0000-0000-0000-0000006c0002', CI = '00000000-0000-0000-0000-0000006c0003';
  await db.exec(`insert into communities (id, name, description, category, rules, privacy, owner_id, status) values
    ('${CP}', 'Com publique', '', '', '', 'public', '${STU}', 'active'), ('${CA}', 'Com approbation', '', '', '', 'approval', '${STU}', 'active'), ('${CI}', 'Com invitation', '', '', '', 'invite', '${STU}', 'active')`);
  await db.exec(`insert into community_members (community_id, user_id, role, status) values ('${CP}', '${STU}', 'owner', 'active'), ('${CA}', '${STU}', 'owner', 'active'), ('${CI}', '${STU}', 'owner', 'active')`);
  await as(SUS);
  await fails('join_community : un compte suspendu ne rejoint pas', `select join_community('${CP}')`, /suspendu/);
  await as(PUB);
  check('join_community : un étudiant rejoint une communauté publique', (await one(`select join_community('${CP}') r`)) === 'joined');
  check('join_community : sur approbation = en attente', (await one(`select join_community('${CA}') r`)) === 'pending');
  await fails('join_community : sur invitation seulement refusé', `select join_community('${CI}')`, /invitation/);
  await as(CLI);
  check('join_community : un client rejoint (comportement inchangé)', (await one(`select join_community('${CP}') r`)) === 'joined');
  await as(null, 'anon');
  await fails('join_community : anonyme refusé', `select join_community('${CP}')`, /permission denied|Connexion/);
  await as(STU2);
  await fails('leave_community : quitter sans être lié est refusé (plus de faux succès)', `select leave_community('${CP}')`, /pas lié/);
  await as(STU);
  await fails('leave_community : le propriétaire ne quitte pas', `select leave_community('${CP}')`, /propriétaire/);
  await as(PUB);
  check('leave_community : un membre quitte', (await one(`select leave_community('${CP}') r`)) === 'left');
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${PUB}'`);
  await as(STU);
  await fails('decide_join_request : accepter un compte suspendu est refusé', `select decide_join_request('${CA}', '${PUB}', true)`, /suspendu/);
  check('decide_join_request : refuser reste possible', (await one(`select decide_join_request('${CA}', '${PUB}', false) r`)) === 'rejected');
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${PUB}'`);
  await as(PUB);
  await works('join_community : nouvelle demande', `select join_community('${CA}')`);
  await as(STU);
  check('decide_join_request : le propriétaire accepte', (await one(`select decide_join_request('${CA}', '${PUB}', true) r`)) === 'accepted');
  await as(CLI);
  await fails('decide_join_request : un client ne décide pas', `select decide_join_request('${CA}', '${PUB}', true)`, /non autorisée|Aucune/);
  await as(PUB);
  await fails('ban_member : un simple membre ne bannit pas', `select ban_member('${CA}', '${STU2}')`, /non autorisée/);
  await as(STU);
  await fails('ban_member : profil inexistant refusé proprement', `select ban_member('${CA}', '00000000-0000-0000-0000-0000006cffff')`, /Profil introuvable/);
  await fails('ban_member : pas d\'auto-bannissement', `select ban_member('${CA}', '${STU}')`, /vous bannir/);
  check('ban_member : le propriétaire bannit un membre', (await one(`select ban_member('${CA}', '${PUB}') r`)) === 'banned');
  await as(PUB);
  await fails('join_community : un banni ne revient pas', `select join_community('${CA}')`, /Accès refusé/);
  await fails('leave_community : un banni ne peut pas effacer son bannissement', `select leave_community('${CA}')`, /Accès refusé/);
  await as(null, 'anon');
  await fails('ban_member : anonyme refusé', `select ban_member('${CA}', '${PUB}')`, /permission denied|Connexion/);

  console.log(`\n${ok}/${ok + ko}`);
}
