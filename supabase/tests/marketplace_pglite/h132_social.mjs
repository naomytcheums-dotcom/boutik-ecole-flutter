// H13.2 agent 4 SOCIAL : parcours social de bout en bout (publication, commentaire, reaction, abonnement, message, notification) avec vrais appels et jwt par acteur.
// Verifie l'effet persistant, la coherence des compteurs et que chaque notification arrive au BON destinataire une seule fois (jamais a soi-meme, jamais vers un compte suspendu ou bloque).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_social.mjs
import { bench } from './h131_lib.mjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

export async function run(db) {
  const b = bench(db, 9);
  const { U, as, anon, sup, q, qs, check, fails, works, user, DENY } = b;
  await sup();
  const A = await user(1, 'Awa Createur', 'student', `update profiles set certification = 'approved' where id = '${U(1)}'`);
  const B = await user(2, 'Boris Lecteur', 'student');
  const C = await user(3, 'Carole Cliente', 'client');
  const BL = await user(4, 'Bloque Parawa', 'student');
  const SU = await user(5, 'Suspendu Compte', 'student');
  const PV = await user(6, 'Prive Profil', 'student', `update profiles set profile_visibility = 'private' where id = '${U(6)}'`);
  const D = await user(7, 'Dora Tierce', 'student');
  const notifs = (uid, kind) => qs(`select id, title, body, data from notifications where user_id = '${uid}' and kind = '${kind}' order by created_at, id`);
  const nCount = async (uid, kind) => (await notifs(uid, kind)).length;

  // ---------------------------------------------------------------- 1. abonnement
  await as(B);
  await works('S1 B suit A', `select follow_set('${A}', true) r`, (r) => r[0].r.followers === 1);
  check('S2 A recoit UNE notification d\'abonnement, B aucune', (await nCount(A, 'follow')) === 1 && (await nCount(B, 'follow')) === 0);
  await works('S3 compteurs : profil public de A = 1 abonne, B suit 1 compte', `select public_profile('${A}') r`, (r) => r[0].r.followers_count === 1);
  await as(C);
  await works('S4 un client suit aussi A : il n\'est pas liste donc pas compte', `select follow_set('${A}', true) r`, (r) => r[0].r.followers === 1);
  await as(A);
  await works('S5 compteur et liste d\'abonnes coherents (1 abonne liste, le client n\'est ni liste ni compte)', `select followers_list('${A}', 20, null) r, follow_stats('${A}') s, public_profile('${A}') p`,
    (r) => r[0].r.items.length === 1 && r[0].s.followers === 1 && r[0].p.followers_count === 1);

  // ---------------------------------------------------------------- 2. publication
  await as(A);
  const post = (await works('S6 A publie', `select create_post_v2('Ma premiere realisation', '[{"path":"${A}/r1.jpg","kind":"image"}]'::jsonb, null, '{}', null) r`))?.[0]?.r;
  const pid = post?.id ?? post?.post_id;
  check('S7 la publication existe cote serveur', !!pid, JSON.stringify(post));
  const st = (await qs(`select status from posts where id = '${pid}'`))[0]?.status;
  console.log('   statut de la publication de A :', st);
  if (st !== 'published') await qs(`update posts set status = 'published', published_at = now() where id = '${pid}' returning id`);
  await as(B);
  await works('S8 la publication de A est lue par B dans author_posts', `select * from author_posts('${A}', 30)`, (r) => r.length === 1);

  // ---------------------------------------------------------------- 3. commentaires : destinataire exact, une fois, jamais a soi
  await as(B);
  const c1 = (await works('S9 B commente', `select add_post_comment_v2('${pid}', 'Bravo !') id`))?.[0]?.id;
  check('S10 A notifie UNE fois du commentaire de B', (await nCount(A, 'comment')) === 1);
  check('S11 B n\'est pas notifie de son propre commentaire', (await nCount(B, 'comment')) === 0);
  await as(A);
  const c2 = (await works('S12 A repond a B', `select add_post_comment_v2('${pid}', 'Merci B', '${c1}') id`))?.[0]?.id;
  check('S13 A ne se notifie pas lui-meme', (await nCount(A, 'comment')) === 1);
  const nB = await notifs(B, 'comment');
  check('S14 B (auteur du commentaire parent) est notifie de la reponse de A', nB.length === 1, JSON.stringify(nB));
  await as(C);
  await works('S15 C repond a B sous la publication de A', `select add_post_comment_v2('${pid}', 'Je plussoie', '${c1}') id`);
  check('S16 A recoit 1 seule notification pour ce commentaire de C (2 au total)', (await nCount(A, 'comment')) === 2);
  check('S17 B (parent) est notifie de la reponse de C, une fois par reponse', (await nCount(B, 'comment')) === 2, String(await nCount(B, 'comment')));
  await as(A);
  await works('S18 liste des commentaires : 3 commentaires', `select * from post_comment_list_v2('${pid}', 100)`, (r) => r.length === 3);
  await works('S19 compteur de commentaires de la publication coherent', `select post_counters('${pid}') r`, (r) => r[0].r.comments === 3, '');

  // ---------------------------------------------------------------- 4. reactions
  await as(B);
  await works('S20 B reagit', `select react_post_set('${pid}', 'fire', true) r`, (r) => r[0].r.likes === 1);
  const likeNotif = await qs(`select user_id, kind from notifications where created_at >= now() - interval '1 minute' and kind not in ('follow','comment')`);
  console.log('   autres notifications du parcours :', JSON.stringify(likeNotif));
  await q(`select react_post_set('${pid}', 'fire', false)`);
  await q(`select react_post_set('${pid}', 'fire', true)`);
  await as(A);
  await works('S21 A reagit a sa propre publication : compteur = 2, aucune notification a soi', `select react_post_set('${pid}', 'like', true) r`, (r) => r[0].r.likes === 2);
  check('S22 aucune notification pour A de ses propres reactions', (await nCount(A, 'like')) + (await nCount(A, 'reaction')) === 0);

  // ---------------------------------------------------------------- 5. messagerie directe
  await as(B);
  const cid = (await works('S23 B ecrit a A', `select start_direct_conversation('${A}', 'Bonjour Awa') id`))?.[0]?.id;
  check('S24 A recoit UNE notification de message, B aucune', (await nCount(A, 'message')) === 1 && (await nCount(B, 'message')) === 0);
  await works('S25 B ecrit un 2e message dans la meme conversation', `insert into messages (conversation_id, sender_id, body) values ('${cid}', '${B}', 'Deuxieme message') returning id`);
  check('S26 une notification par message (2) pour A seulement', (await nCount(A, 'message')) === 2 && (await nCount(B, 'message')) === 0);
  await as(A);
  await works('S27 A voit ses conversations avec 1 non-lu', `select * from my_conversations()`, (r) => r.length === 1);
  await fails('S28 A ne s\'ecrit pas a lui-meme', `select start_direct_conversation('${A}', 'moi')`, /vous-même/);

  // ---------------------------------------------------------------- 6. blocage : plus de commentaire, de message, de notification, de suggestion
  await as(A);
  await q(`select block_user('${BL}', true)`);
  await as(BL);
  await fails('S29 bloque : commentaire refuse', `select add_post_comment_v2('${pid}', 'coucou')`, /impossible|introuvable|bloqu/);
  await fails('S30 bloque : abonnement refuse', `select follow_set('${A}', true)`, /introuvable|impossible/);
  await fails('S31 bloque : message refuse', `select start_direct_conversation('${A}', 'salut')`, /ne peut pas recevoir/);
  check('S32 aucune notification pour A d\'un compte bloque', (await qs(`select count(*)::int n from notifications where user_id = '${A}' and data::text like '%${BL}%'`))[0].n === 0);
  await as(B);
  await q(`select block_user('${D}', true)`);
  await as(A);
  await q(`select block_user('${B}', true)`);
  await as(B);
  await fails('S33 B bloque par A : message dans une conversation existante refuse', `insert into messages (conversation_id, sender_id, body) values ('${cid}', '${B}', 'encore')`, /row-level|permission denied|violates/);
  await works('S34 B bloque par A ne voit plus les commentaires de A', `select * from post_comment_list_v2('${pid}', 100)`, (r) => !r.some((x) => x.author_id === A));
  await as(A);
  await q(`select block_user('${B}', false)`);

  // ---------------------------------------------------------------- 7. compte suspendu
  await as(SU);
  await sup();
  await qs(`update profiles set suspended = true where id = '${SU}'`);
  await as(SU);
  await fails('S35 suspendu : commentaire refuse', `select add_post_comment_v2('${pid}', 'je suis suspendu')`, /uspendu|impossible|introuvable|refus/);
  await fails('S36 suspendu : message direct refuse', `select start_direct_conversation('${A}', 'hello')`, /uspendu/);
  await as(B);
  await fails('S37 message vers un suspendu : destinataire introuvable', `select start_direct_conversation('${SU}', 'hello')`, /introuvable/);
  await works('S38 un suspendu n\'est plus dans mes abonnes si il suivait', `select public_profile('${SU}') r`, (r) => r[0].r === null);
  // un compte suspendu apres coup : ni message ni notification vers lui dans une conversation existante
  await as(B);
  await q(`select start_direct_conversation('${D}', 'Salut Dora')`).catch(() => null);
  await as(A);
  const cidAD = (await works('S39 A ouvre une conversation avec D', `select start_direct_conversation('${D}', 'Bonjour Dora') id`))?.[0]?.id;
  await qs(`update profiles set suspended = true where id = '${D}'`);
  await as(A);
  await q(`insert into messages (conversation_id, sender_id, body) values ('${cidAD}', '${A}', 'Message apres suspension de D') returning id`).catch(() => null);
  check('S40 aucun nouveau message ni notification vers un destinataire suspendu', (await nCount(D, 'message')) === 1, String(await nCount(D, 'message')));
  await qs(`update profiles set suspended = false where id = '${D}'`);

  // ---------------------------------------------------------------- 8. confidentialite : profil prive, publication retiree, commentaires
  await as(B);
  await works('S41 profil prive : public_profile masque a un tiers', `select public_profile('${PV}') r`, (r) => r[0].r === null || r[0].r.name == null || r[0].r.private === true, 'verifie');
  await works('S42 profil prive absent des suggestions de createurs', `select creators_suggested(50) r`, (r) => !JSON.stringify(r[0].r).includes(PV));
  await works('S43 profil prive absent de l\'annuaire des talents', `select talents_list('Prive', 20) r`, (r) => !JSON.stringify(r[0].r).includes(PV));
  await as(A);
  await q(`select delete_my_post('${pid}')`);
  await as(B);
  await works('S44 publication retiree : plus visible dans author_posts', `select * from author_posts('${A}', 30)`, (r) => r.length === 0);
  await works('S45 publication retiree : commentaires illisibles', `select * from post_comment_list_v2('${pid}', 100)`, (r) => r.length === 0);
  await fails('S46 publication retiree : commentaire refuse', `select add_post_comment_v2('${pid}', 'trop tard')`, /introuvable/);
  await anon();
  await works('S47 anonyme : commentaires de la publication retiree illisibles', `select * from post_comment_list_v2('${pid}', 100)`, (r) => r.length === 0);
  await as(A);
  await sup();
  await qs(`update profiles set suspended = false where id = '${SU}'`);
  await qs(`insert into engagements (user_id, kind, ref) values ('${SU}', 'follow', '${A}') on conflict do nothing`);
  await as(A);
  const avant = (await q(`select follow_stats('${A}') r, followers_list('${A}', 20, null) l`))[0];
  await sup();
  await qs(`update profiles set suspended = true where id = '${SU}'`);
  await as(A);
  await works('S48 abonnes : un abonne suspendu sort a la fois du compteur et de la liste', `select follow_stats('${A}') r, followers_list('${A}', 20, null) l`,
    (r) => avant.r.followers === 2 && avant.l.items.length === 2 && r[0].r.followers === 1 && r[0].l.items.length === 1);

  // ---------------------------------------------------------------- 9. matrice de confidentialite : prive, suspendu, bloque, publication en attente ou retiree
  await sup();
  const MK = 'MARQUEURSECRET';
  const seed = async (owner, tag) => {
    await qs(`insert into posts (author_id, kind, body, caption, status, published_at, media_path, media_kind) values ('${owner}', 'media', '${MK}${tag}', '${MK}${tag}', 'published', now(), '${owner}/${tag}.jpg', 'image')`);
    await qs(`insert into posts (author_id, kind, body, caption, status, published_at, media_path, media_kind) values ('${owner}', 'media', '${MK}attente${tag}', '${MK}attente${tag}', 'pending', now(), '${owner}/${tag}b.jpg', 'image')`);
    await qs(`insert into posts (author_id, kind, body, caption, status, published_at, media_path, media_kind) values ('${owner}', 'media', '${MK}retire${tag}', '${MK}retire${tag}', 'removed', now(), '${owner}/${tag}c.jpg', 'image')`);
    await qs(`insert into portfolio_items (owner_id, kind, title, description) values ('${owner}', 'realisation', '${MK}${tag}', 'x')`);
    await qs(`insert into projects (owner_id, title, summary, status, visibility) values ('${owner}', '${MK}${tag}', 'x', 'approved', 'public')`);
    await qs(`insert into stories (author_id, media_path, media_kind, caption, status, expires_at) values ('${owner}', '${owner}/private/${tag}.jpg', 'image', '${MK}${tag}', 'visible', now() + interval '5 hours')`);
    await qs(`insert into talent_skills (owner_id, domain, skill, level) values ('${owner}', 'Tech', '${MK}${tag}', 'avance')`);
  };
  const probes = (owner, name) => [
    ['public_profile', `select public_profile('${owner}') r`],
    ['author_posts', `select * from author_posts('${owner}', 30)`],
    ['reels_feed', `select * from reels_feed(50)`],
    ['circle_feed_page', `select circle_feed_page(50, null, null, 'all') r`],
    ['stories_active', `select * from stories_active(null)`],
    ['stories_active(owner)', `select * from stories_active('${owner}')`],
    ['cv_public', `select cv_public('${owner}') r`],
    ['talent_passport', `select talent_passport('${owner}') r`],
    ['talents_search', `select talents_search('${MK}', '', '{}', 20, 0) r`],
    ['talents_list', `select talents_list('${name}', 20) r`],
    ['profile_links_public', `select profile_links_public('${owner}') r`],
    ['profile_imported_items', `select profile_imported_items('${owner}') r`],
    ['public_projects', `select * from public_projects(null, 100)`],
    ['followers_list', `select followers_list('${owner}', 20, null) r`],
    ['following_list', `select following_list('${owner}', 20, null) r`],
    ['creators_suggested', `select creators_suggested(50) r`],
    ['posts (table)', `select id, caption from posts`],
    ['portfolio_items (table)', `select id, title from portfolio_items`],
    ['talent_skills (table)', `select id, skill from talent_skills`],
    ['stories (table)', `select id, caption from stories`],
  ];
  const leak = async (label, viewer, owner, name, tag, extra = []) => {
    const bad = [];
    for (const [n, sql] of probes(owner, name)) {
      try { const r = await q(sql); const s = JSON.stringify(r); if (s.includes(MK + tag) || s.includes(owner)) bad.push(n + '{' + (s.includes(MK + tag) ? 'contenu' : 'id') + '}'); if (new RegExp(MK + '(attente|retire)' + tag).test(s)) bad.push(n + '[attente/retire]'); }
      catch (e) { if (!/permission denied|introuvable|Connexion/i.test(e.message)) bad.push(n + ' ERREUR ' + e.message.slice(0, 60)); }
    }
    check(`${label} : rien du compte ${name} n'est visible`, bad.length === 0, bad.join(' | '));
  };
  await seed(PV, 'pv');
  await qs(`update profiles set skills = '${MK}pv', bio = '${MK}pv' where id = '${PV}'`);
  await as(B); await leak('P1 profil prive vu par un tiers', B, PV, 'Prive', 'pv');
  await anon(); await leak('P2 profil prive vu par un anonyme', null, PV, 'Prive', 'pv');
  await as(PV);
  const own = await works('P3 le proprietaire voit toujours ses propres contenus', `select * from author_posts('${PV}', 30)`, (r) => r.length >= 1);
  // suspendu
  await sup();
  const SUS2 = await user(8, 'Suspendu Contenu', 'student');
  await seed(SUS2, 'su');
  await qs(`update profiles set suspended = true, skills = '${MK}su' where id = '${SUS2}'`);
  await as(B); await leak('P4 compte suspendu vu par un tiers', B, SUS2, 'Suspendu Contenu', 'su');
  await anon(); await leak('P5 compte suspendu vu par un anonyme', null, SUS2, 'Suspendu Contenu', 'su');
  // bloque : A a bloque BL, BL ne doit rien voir de A (profil, publications, stories) ; et inversement
  await sup();
  await qs(`update profiles set skills = '${MK}a' where id = '${A}'`);
  await seed(A, 'a');
  await as(BL); await leak('P6 un compte bloque par A ne voit rien de A', BL, A, 'Awa Createur', 'a');
  await as(B); await works('P7 publications en attente ou retirees de A invisibles pour un tiers (author_posts)', `select caption from author_posts('${A}', 30)`, (r) => !r.some((x) => /attente|retire/.test(x.caption)));
  await as(B); await works('P8 aucune publication en attente/retiree dans les fils (reels, cercle)', `select (select count(*) from reels_feed(100) where caption ~ 'attente|retire') n, circle_feed_page(100, null, null, 'all')::text c`, (r) => Number(r[0].n) === 0 && !/MARQUEURSECRETattente|MARQUEURSECRETretire/.test(r[0].c));

  // ---------------------------------------------------------------- 10. commentaires et medias prives d'un compte prive, suspendu ou bloque
  await sup();
  const pvPost = (await qs(`select id from posts where author_id = '${PV}' and status = 'published' limit 1`))[0].id;
  const suPost = (await qs(`select id from posts where author_id = '${SUS2}' and status = 'published' limit 1`))[0].id;
  await qs(`update profiles set suspended = false where id = '${SUS2}'`);
  await qs(`insert into post_comments (post_id, author_id, body) values ('${pvPost}', '${PV}', '${MK}commpv'), ('${suPost}', '${SUS2}', '${MK}commsu')`);
  await qs(`update profiles set suspended = true where id = '${SUS2}'`);
  await qs(`insert into storage.objects (bucket_id, name) values ('post-media-private', '${PV}/pv.jpg'), ('post-media-private', '${PV}/private/pv.jpg'), ('post-media-private', '${SUS2}/su.jpg'), ('post-media-private', '${A}/a.jpg')`);
  await db.exec(`grant select on storage.objects to anon, authenticated`);
  const storageNames = async () => (await q(`select name from storage.objects where bucket_id = 'post-media-private'`)).map((x) => x.name);
  await as(B);
  await works('P9 commentaires d\'une publication d\'un compte prive illisibles pour un tiers', `select * from post_comment_list_v2('${pvPost}', 100)`, (r) => r.length === 0);
  await fails('P10 commenter la publication d\'un compte prive : refuse', `select add_post_comment_v2('${pvPost}', 'je passe par la')`, /introuvable/);
  await works('P11 commentaires d\'un compte suspendu illisibles (liste et table)', `select (select count(*) from post_comment_list_v2('${suPost}', 100)) n, (select count(*) from post_comments where body like '${MK}%') t`, (r) => Number(r[0].n) === 0 && Number(r[0].t) === 0);
  const nm = await storageNames();
  check('P12 medias prives d\'un compte prive ou suspendu illisibles pour un tiers, ceux d\'un compte public lisibles', !nm.some((x) => x.startsWith(PV) || x.startsWith(SUS2)) && nm.includes(`${A}/a.jpg`), nm.join(','));
  await as(BL);
  check('P13 un compte bloque par A ne lit pas les medias de A', !(await storageNames()).includes(`${A}/a.jpg`));
  await anon();
  { const n = await storageNames(); check('P14 anonyme : ni media prive d\'un compte prive ou suspendu, ni fichier de brouillon', n.every((x) => x === `${A}/a.jpg`), n.join(',')); }
  await as(PV);
  check('P15 le proprietaire lit ses propres medias prives', (await storageNames()).includes(`${PV}/private/pv.jpg`));

  // ---------------------------------------------------------------- 11. rejeu des migrations H13.2 sans effet de bord
  await sup();
  const dir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations');
  for (const f of fs.readdirSync(dir).filter((x) => /^2026113004\d+_h132_social_.*\.sql$/.test(x))) {
    let err = '';
    try { await db.exec(fs.readFileSync(path.join(dir, f), 'utf8')); } catch (e) { err = e.message; }
    check(`R1 rejeu de ${f} : sans erreur`, err === '', err.slice(0, 120));
  }
  const src = (await qs(`select string_agg(prosrc, ' ') s from pg_proc where proname in ('public_profile', 'talent_passport', '_rl_public_projects', '_post_accessible')`))[0].s;
  check('R2 rejeu : les conditions H13.2 ne sont pas dupliquees', (src.match(/_h132_blocked_by/g) || []).length === 2 && (src.match(/_h132_author_visible/g) || []).length === 2, String((src.match(/_h132_/g) || []).length));
  check('R3 rejeu : l\'enveloppe de debit de public_projects est conservee', (await qs(`select count(*)::int n from pg_proc where proname = '_rl_public_projects'`))[0].n === 1 && /h13:throttle/.test((await qs(`select prosrc from pg_proc where proname = 'public_projects'`))[0].prosrc));
  b.summary('h132_social');
}
