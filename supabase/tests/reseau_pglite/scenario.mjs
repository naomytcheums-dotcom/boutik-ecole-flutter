// Scénario SQL du réseau social et des Lives (voir README.md). Attendu : aucune ligne « ECHEC ».
let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql, params) => (await db.query(sql, params)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role, cert] of [[A, 'Awa Atelier', 'student', 'approved'], [B, 'Paul Student', 'student', 'none'], [C, 'Cora Client', 'client', 'none'], [M, 'Mod Admin', 'admin', 'none']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,certification) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm','${cert}')`);
  }

  // ---------------------------------------------------------------- publications
  await as(A);
  const media = JSON.stringify([1, 2, 3, 4, 5].map(i => ({ path: `${A}/p${i}.jpg`, kind: 'image', w: 1200, h: 800 + i })));
  let r = (await q(`select create_post_v2('Cinq photos de l atelier', '${media}'::jsonb, null, '{atelier}', null) r`))[0].r;
  check('publication de 5 images (certifié : publiée)', r.status === 'published');
  const p5 = r.id;
  let feed = await q(`select * from circle_feed(30)`);
  const f5 = feed.find(x => x.id === p5);
  check('fil : 5 médias dans l ordre, badge certifié', f5 && f5.media.length === 5 && f5.media[4].path.endsWith('p5.jpg') && f5.author_verified === true, JSON.stringify(f5?.media?.length));
  r = (await q(`select create_post_v2('Texte seul avec lien', '[]'::jsonb, 'https://exemple.cm/page', '{}', null) r`))[0].r;
  feed = await q(`select * from circle_feed(30)`);
  check('publication texte + lien', feed.some(x => x.id === r.id && x.kind === 'text' && x.link_url === 'https://exemple.cm/page' && x.caption === 'Texte seul avec lien'));
  await fails('lien non http refusé', `select create_post_v2('x', '[]'::jsonb, 'javascript:alert(1)', '{}', null)`, /Lien invalide/);
  await fails('publication vide refusée', `select create_post_v2('', '[]'::jsonb, null, '{}', null)`, /Écrivez/);
  await fails('média hors de son dossier refusé', `select create_post_v2('x', '[{"path":"${B}/x.jpg","kind":"image"}]'::jsonb, null, '{}', null)`, /Média invalide/);
  await as(B);
  r = (await q(`select create_post_v2('Je republie', '[]'::jsonb, null, '{}', null, '${p5}') r`))[0].r;
  check('étudiant non certifié : republication en attente de validation', r.status === 'pending');
  await as(M);
  await q(`select moderate_post('${r.id}', true, 'ok')`);
  await as(C);
  feed = await q(`select * from circle_feed(30)`);
  const rp = feed.find(x => x.id === r.id);
  check('republication : post d origine intégré, non certifié', rp && rp.repost_id === p5 && rp.repost_author === 'Awa A.' && rp.author_verified === false);
  check('compteur de republications de l origine', feed.find(x => x.id === p5).reposts === 1);

  // ---------------------------------------------------------------- commentaires
  await as(C);
  const c1 = (await q(`select add_post_comment_v2('${p5}', 'Magnifique !') id`))[0].id;
  const c2 = (await q(`select add_post_comment_v2('${p5}', 'Merci', '${c1}') id`))[0].id;
  await as(A);
  const c3 = (await q(`select add_post_comment_v2('${p5}', 'Avec plaisir', '${c2}') id`))[0].id;
  let list = await q(`select * from post_comment_list_v2('${p5}')`);
  check('réponse à une réponse rattachée au commentaire racine', list.find(x => x.id === c3).parent_id === c1);
  check('badge certifié dans les commentaires', list.find(x => x.id === c3).author_verified === true && list.find(x => x.id === c1).author_verified === false);
  await fails('commentaire vide sans pièce jointe refusé', `select add_post_comment_v2('${p5}', '   ')`, /Écrivez/);
  const c4 = (await q(`select add_post_comment_v2('${p5}', '', null, '${A}/c.jpg', 'image') id`))[0].id;
  list = await q(`select * from post_comment_list_v2('${p5}')`);
  check('commentaire avec pièce jointe seule', list.find(x => x.id === c4).attachment_path.endsWith('c.jpg'));
  await fails('pièce jointe hors de son dossier refusée', `select add_post_comment_v2('${p5}', 'x', null, '${B}/c.jpg', 'image')`, /Pièce jointe invalide/);
  check('j aime commentaire (ajout)', (await q(`select toggle_comment_like('${c1}') v`))[0].v === true);
  check('j aime commentaire (retrait)', (await q(`select toggle_comment_like('${c1}') v`))[0].v === false);
  await q(`select toggle_comment_like('${c1}')`);
  list = await q(`select * from post_comment_list_v2('${p5}')`);
  check('compteur et état aimé du commentaire', list.find(x => x.id === c1).likes === 1 && list.find(x => x.id === c1).liked === true);

  // ---------------------------------------------------------------- histoires
  await as(A);
  await q(`select create_story('${A}/s1.jpg', 'image', 'Atelier')`);
  await fails('histoire hors de son dossier refusée', `select create_story('${B}/s.jpg', 'image')`, /Média invalide/);
  await as(null, 'anon');
  let st = await q(`select * from stories_active(null)`);
  check('histoires actives lisibles, badge certifié', st.length === 1 && st[0].author_verified === true && st[0].seen === false);
  await db.exec(`reset role; update stories set expires_at = now() - interval '1 minute'`);
  await as(null, 'anon');
  check('histoire expirée disparue', (await q(`select * from stories_active(null)`)).length === 0);

  // ---------------------------------------------------------------- lives
  await as(C);
  await fails('un client ne peut pas créer de live', `select create_live('Mon live', '', null)`, /réservés/);
  await as(A);
  const lid = (await q(`select create_live('Atelier lampe', 'Fabrication en direct', null) id`))[0].id;
  await fails('titre trop court refusé', `select create_live('ab')`, /titre/);
  await db.exec(`reset role; insert into engagements(user_id,kind,ref,status) values ('${B}','follow','${A}','active')`);
  await as(A);
  await as(B);
  await fails('un autre ne peut pas démarrer mon live', `select start_live('${lid}')`, /introuvable/);
  await fails('rejoindre un live non démarré refusé', `select join_live('${lid}')`, /pas en direct/);
  await as(A);
  const room = (await q(`select start_live('${lid}') room`))[0].room;
  check('démarrage : salle attribuée', /^live-/.test(room));
  await db.exec('reset role');
  const notifs = await q(`select count(*)::int n from notifications where user_id='${B}' and kind='live'`);
  check('abonné notifié du démarrage', notifs[0].n === 1, JSON.stringify(notifs));
  await as(A);
  await fails('second live simultané refusé', `select start_live((select create_live('Autre live', '', null)))`, /déjà un live/);
  await as(B);
  check('rejoindre : 1 spectateur', (await q(`select (join_live('${lid}'))->>'viewers' v`))[0].v === '1');
  await as(C);
  check('rejoindre : 2 spectateurs', (await q(`select (join_live('${lid}'))->>'viewers' v`))[0].v === '2');
  await q(`select post_live_message('${lid}', 'Bonjour !')`);
  await q(`select react_live('${lid}', 'heart')`);
  await fails('réaction inconnue refusée', `select react_live('${lid}', 'poison')`, /inconnue/);
  await fails('message vide refusé', `select post_live_message('${lid}', '  ')`, /1 à 300/);
  await as(null, 'anon');
  const msgs = await q(`select kind, body from live_messages where live_id='${lid}' order by id`);
  check('messages lisibles par tous (système, chat, réaction)', msgs.map(m => m.kind).join() === 'system,chat,reaction', msgs.map(m => m.kind).join());
  check('lives_now : live en direct, 2 spectateurs, hôte certifié', (await q(`select * from lives_now(10)`)).some(l => l.id === lid && l.viewer_count === 2 && l.host_verified === true));
  await as(C);
  await q(`select leave_live('${lid}')`);
  check('départ : 1 spectateur', (await q(`select viewer_count from lives where id='${lid}'`))[0].viewer_count === 1);
  await q(`select report_live('${lid}', null, 'Propos déplacés')`);
  await q(`select report_live('${lid}', null, 'Propos déplacés')`);
  await db.exec('reset role');
  check('signalement enregistré une seule fois', (await q(`select count(*)::int n from live_reports`))[0].n === 1);

  // ---------------------------------------------------------------- crédits et cadeaux
  await as(B);
  await fails('cadeau sans crédits refusé', `select send_gift('${lid}', 'rose', 1, 'cle-b-00000001')`, /insuffisants/);
  await fails('ajout de crédits interdit aux utilisateurs', `select grant_credits('${B}', 1000, 'pay-1')`, /permission|denied/i);
  await db.exec(`reset role; set role service_role`);
  let g = (await q(`select grant_credits('${B}', 1000, 'pay-001') g`))[0].g;
  check('recharge serveur : +1000', g.added === true && Number(g.balance) === 1000);
  g = (await q(`select grant_credits('${B}', 1000, 'pay-001') g`))[0].g;
  check('même paiement rejoué : aucun double crédit', g.added === false && Number(g.balance) === 1000);
  await as(B);
  check('solde réel affiché', Number((await q(`select (my_wallet())->>'balance' b`))[0].b) === 1000);
  let s1 = (await q(`select send_gift('${lid}', 'coeur', 3, 'cle-b-00000002') s`))[0].s;
  check('envoi : 30 crédits débités', s1.duplicate === false && Number(s1.balance) === 970 && Number(s1.credits) === 30);
  s1 = (await q(`select send_gift('${lid}', 'coeur', 3, 'cle-b-00000002') s`))[0].s;
  check('même clé rejouée : pas de double débit', s1.duplicate === true && Number(s1.balance) === 970);
  await fails('quantité hors limites refusée', `select send_gift('${lid}', 'rose', 0, 'cle-b-00000003')`, /Quantité/);
  await fails('cadeau inconnu refusé', `select send_gift('${lid}', 'bombe', 1, 'cle-b-00000004')`, /indisponible/);
  await fails('solde insuffisant refusé', `select send_gift('${lid}', 'trophee', 10, 'cle-b-00000005')`, /insuffisants/);
  check('solde inchangé après refus', Number((await q(`select (my_wallet())->>'balance' b`))[0].b) === 970);
  await as(A);
  await fails('cadeau à soi-même refusé', `select send_gift('${lid}', 'rose', 1, 'cle-a-00000001')`, /vous offrir/);
  const dash = (await q(`select creator_dashboard() d`))[0].d;
  check('tableau créateur : 70 % de 30 = 21, commission 9, retrait indisponible', Number(dash.creator_credits) === 21 && Number(dash.platform_credits) === 9 && dash.payout_available === false && Number(dash.gifts_received) === 3, JSON.stringify(dash));
  const hist = await q(`select * from my_gift_history('received')`);
  check('historique reçus', hist.length === 1 && hist[0].gift_code === 'coeur' && Number(hist[0].credits) === 30);
  await as(B);
  check('historique envoyés', (await q(`select * from my_gift_history('sent')`)).length === 1);
  await db.exec('reset role');
  check('cohérence : créateur 21 + commission 9 = 30 débités', Number((await q(`select sum(creator_credits+platform_credits) s from gift_sends`))[0].s) === 30);
  check('cadeau visible dans le chat', (await q(`select count(*)::int n from live_messages where kind='gift'`))[0].n === 1);
  await as(A);
  await q(`select moderate_live_viewer('${lid}', '${C}')`);
  await as(C);
  await fails('spectateur banni : message refusé', `select post_live_message('${lid}', 'encore')`, /plus écrire/);
  await fails('spectateur banni : ne peut plus rejoindre', `select join_live('${lid}')`, /ne pouvez pas/);
  await as(A);
  check('fin du live', (await q(`select end_live('${lid}') s`))[0].s === 'ended');
  await as(B);
  await fails('cadeau après la fin refusé', `select send_gift('${lid}', 'rose', 1, 'cle-b-00000009')`, /pas en direct/);
  console.log(`\n${ok} OK, ${ko} ECHEC`);
}
