// Scénario PGlite du lot H13 SOCIAL : garde-fous (débit, blocage, cohérence j'aime/réaction, pas de résurrection), modification de publication et de commentaire,
// abonnements, fil paginé par curseur, profils créateurs (onglets, épinglage, visites agrégées), modération des commentaires, droits de lecture des médias, statistiques créateur.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h13_social.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  let cur = { uid: null, role: 'authenticated' };
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sudo = async (sql) => { const save = cur; await as(null, null); try { try { return await q(sql); } catch (e) { if (!/multiple commands/.test(e.message)) throw e; await db.exec(sql); return []; } } finally { await as(save.uid, save.role); } };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const one = async (sql) => (await q(sql))[0];
  const ADM = U(60), A = U(61), B = U(62), C = U(63), D = U(64), DEP = U(65), SUP = U(66), ORG = U(67), DEP2 = U(68), E = U(69), F = U(70);

  await db.exec('reset role');
  const roles = { 60: 'admin', 61: 'student', 62: 'student', 63: 'client', 64: 'student', 65: 'dept', 66: 'support', 67: 'company', 68: 'dept', 69: 'student', 70: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    const dep = n === '68' ? 'Droit' : 'Génie informatique';
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h13s${n}@t.cm'); insert into profiles(id,name,role,email,department,institution,created_at) values ('${U(n)}','Membre H13 ${n}','${r}','h13s${n}@t.cm','${dep}','IUT test', now() - interval '5 days')`);
  }
  await db.exec(`update profiles set certification = 'approved' where id = '${A}'`);
  const I1 = '00000000-0000-0000-0000-00000000c131', DX = '00000000-0000-0000-0000-00000000c1b1', DY = '00000000-0000-0000-0000-00000000c1b2';
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test H13', 'verified'); insert into departments (id, institution_id, name, status) values ('${DX}', '${I1}', 'Génie informatique', 'verified'), ('${DY}', '${I1}', 'Droit', 'verified')`);
  await db.exec(`update profiles set institution_id = '${I1}', department_id = '${DX}' where id in ('${A}', '${B}', '${C}', '${D}', '${E}', '${F}', '${DEP}'); update profiles set institution_id = '${I1}', department_id = '${DY}' where id = '${DEP2}'`);
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${DEP}', '${DX}'), ('${DEP2}', '${DY}')`);
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${SUP}', 'security', array['security.moderation', 'security.reports']) on conflict (user_id, team_code) do update set permissions = excluded.permissions`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${ORG}', 'Orange Cameroun', 'approved')`);
  const mkPost = async (author, body, extra = {}) => (await sudo(`insert into posts (author_id, kind, body, caption, status, published_at, community_id, repost_of) values ('${author}', 'text', $$${body}$$, $$${body}$$, '${extra.status ?? 'published'}', ${extra.at ?? 'now()'}, ${extra.community ? `'${extra.community}'` : 'null'}, ${extra.repost ? `'${extra.repost}'` : 'null'}) returning id`))[0].id;

  // ================================================================ 1. abonnements
  const fol = (u, on = true) => `select follow_set('${u}', ${on}) r`;
  await as(null, 'anon');
  await fails('abonnement : anonyme refusé', fol(A), /permission denied/);
  check('suivi : un anonyme lit les compteurs d\'un profil public', (await one(`select follow_stats('${A}') r`)).r.followers === 0);
  await as(B);
  await fails('abonnement : auto-abonnement refusé', fol(B), /propre compte/);
  await fails('abonnement : compte inexistant refusé', fol(U(99)), /introuvable/);
  await fails('abonnement : écriture directe d\'un auto-abonnement refusée (déclencheur)', `insert into engagements (user_id, kind, ref) values ('${B}', 'follow', '${B}')`, /propre compte|row-level|permission denied/);
  await sudo(`update profiles set suspended = true where id = '${D}'`);
  await fails('abonnement : compte suspendu refusé', fol(D), /introuvable/);
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${A}', '${E}'), ('${F}', '${A}')`);
  await as(E);
  await fails('abonnement : bloqué par la cible refusé', fol(A), /introuvable|impossible/);
  await as(F);
  await fails('abonnement : cible bloquée par moi refusé', fol(A), /introuvable|impossible/);
  await as(D);
  await fails('abonnement : abonné suspendu refusé', fol(A), /suspendu/);
  await sudo(`update profiles set suspended = false where id = '${D}'`);
  await as(B);
  const f1 = (await one(fol(A))).r;
  check('abonnement : B suit A, compteurs à jour', f1.following === true && f1.changed === true && f1.followers === 1, JSON.stringify(f1));
  check('abonnement : rejeu idempotent (aucun changement)', (await one(fol(A))).r.changed === false && (await one(fol(A))).r.followers === 1);
  check('abonnement : follow_stats montre i_follow', (await one(`select follow_stats('${A}') r`)).r.i_follow === true);
  check('notification « Nouvel abonné » : une fois', (await sudo(`select count(*)::int n from notifications where user_id = '${A}' and kind = 'follow'`))[0].n === 1);
  const un = (await one(fol(A, false))).r;
  check('désabonnement : compteur retombe à 0', un.following === false && un.changed === true && un.followers === 0, JSON.stringify(un));
  check('désabonnement : rejeu sans effet', (await one(fol(A, false))).r.changed === false);
  await q(fol(A));
  check('réabonnement : aucune nouvelle notification (défaut corrigé)', (await sudo(`select count(*)::int n from notifications where user_id = '${A}' and kind = 'follow'`))[0].n === 1);
  await as(C);
  await q(fol(A));
  await sudo(`update profiles set suspended = true where id = '${C}'`);
  await as(F);
  check('compteurs publics : un abonné suspendu n\'est plus compté', (await one(`select public_profile('${A}') r`)).r.followers_count === 1);
  await sudo(`update profiles set suspended = false where id = '${C}'`);
  await sudo(`alter table engagements disable trigger trg_h13_follow_guard; insert into engagements (user_id, kind, ref) values ('${A}', 'follow', '${A}'); alter table engagements enable trigger trg_h13_follow_guard`);
  check('compteurs publics : l\'auto-abonnement historique n\'est pas compté', (await one(`select public_profile('${A}') r`)).r.followers_count === 2, JSON.stringify((await one(`select public_profile('${A}') r`)).r));
  await sudo(`update profiles set suspended = true where id = '${D}'`);
  check('isolation : un suspendu n\'a plus de profil public', (await one(`select public_profile('${D}') r`)).r === null);

  await sudo(`delete from user_blocks where blocker_id = '${F}' and blocked_id = '${A}'`);
  // ================================================================ 2. publications, garde-fous
  const pA1 = await mkPost(A, 'Premiere publication de A');
  const pA2 = await mkPost(A, 'Deuxieme publication de A');
  await as(E);
  await fails('blocage : j\'aime sur l\'auteur qui m\'a bloqué refusé', `select toggle_post_like('${pA1}')`, /impossible|introuvable/);
  await fails('blocage : réaction refusée', `select react_post_set('${pA1}', 'fire', true)`, /impossible|introuvable/);
  await fails('blocage : partage refusé', `select record_post_share('${pA1}')`, /impossible|introuvable/);
  await fails('blocage : enregistrement refusé', `select toggle_post_save('${pA1}')`, /impossible|introuvable/);
  await fails('blocage : commentaire refusé', `select add_post_comment_v2('${pA1}', 'coucou')`, /impossible|introuvable|bloqu/);
  await as(null, 'anon');
  await fails('réaction : anonyme refusé', `select react_post_set('${pA1}', 'like', true)`, /permission denied/);
  check('compteurs : lisibles par un anonyme', (await one(`select post_counters('${pA1}') r`)).r.likes === 0);
  await as(B);
  const r1 = (await one(`select react_post_set('${pA1}', 'fire', true) r`)).r;
  check('réaction : posée, j\'aime synchronisé', r1.reacted && r1.likes === 1 && (await sudo(`select count(*)::int n from post_likes where post_id = '${pA1}' and user_id = '${B}'`))[0].n === 1, JSON.stringify(r1));
  check('réaction : rejeu identique sans changement', (await one(`select react_post_set('${pA1}', 'fire', true) r`)).r.likes === 1);
  await fails('réaction : type inconnu refusé', `select react_post_set('${pA1}', 'zzz', true)`, /Réaction invalide/);
  const r2 = (await one(`select react_post_set('${pA1}', 'fire', false) r`)).r;
  check('réaction retirée : j\'aime retiré aussi', !r2.reacted && r2.likes === 0 && (await sudo(`select count(*)::int n from post_reactions where post_id = '${pA1}'`))[0].n === 0, JSON.stringify(r2));
  await q(`select toggle_post_like('${pA2}')`);
  check('j\'aime sans réaction : la réaction « like » est créée (défaut corrigé)', (await sudo(`select kind from post_reactions where post_id = '${pA2}' and user_id = '${B}'`))[0]?.kind === 'like');
  await q(`select toggle_post_like('${pA2}')`);
  check('j\'aime retiré : la réaction disparaît (défaut corrigé)', (await sudo(`select count(*)::int n from post_reactions where post_id = '${pA2}'`))[0].n === 0);
  const cnt = (await one(`select post_counters('${pA1}') r`)).r;
  check('compteurs : cohérents avec le fil', cnt.likes === 0 && cnt.mine.liked === false);
  const pPend = await mkPost(A, 'En attente', { status: 'pending' });
  check('compteurs : publication non publiée = null', (await one(`select post_counters('${pPend}') r`)).r === null);
  await fails('réaction : publication non publiée introuvable', `select react_post_set('${pPend}', 'like', true)`, /introuvable/);

  // limite de débit par heure
  await sudo(`update platform_settings set value = '3'::jsonb where key = 'social.rate.posts_per_hour'; update platform_settings set value = '2'::jsonb where key = 'social.rate.comments_per_hour'; update platform_settings set value = '2'::jsonb where key = 'social.rate.reports_per_hour'`);
  await as(B);
  for (let i = 1; i <= 3; i++) await q(`select create_post_v2('Texte rapide ${i}', '[]'::jsonb, null, '{}', null, null)`);
  await fails('débit : la 4e publication de l\'heure est refusée', `select create_post_v2('Texte rapide 4', '[]'::jsonb, null, '{}', null, null)`, /Limite atteinte/);
  await as(C);
  check('débit : isolation, un autre compte publie encore', !!(await one(`select create_post_v2('Texte de C', '[]'::jsonb, null, '{}', null, null) r`)).r);
  await as(B);
  await q(`select add_post_comment_v2('${pA1}', 'Commentaire 1')`);
  const cB2 = (await one(`select add_post_comment_v2('${pA1}', 'Commentaire 2') id`)).id;
  await fails('débit : le 3e commentaire de l\'heure est refusé', `select add_post_comment_v2('${pA1}', 'Commentaire 3')`, /Limite atteinte/);
  await sudo(`update platform_settings set value = '"abc"'::jsonb where key = 'social.rate.comments_per_hour'`);
  check('débit : valeur invalide → défaut 120 (pas de blocage)', !!(await one(`select add_post_comment_v2('${pA1}', 'Commentaire 3') id`)).id);
  await sudo(`update platform_settings set value = '120'::jsonb where key = 'social.rate.comments_per_hour'; update platform_settings set value = '30'::jsonb where key = 'social.rate.posts_per_hour'`);

  // modification d'un commentaire
  await as(C);
  await fails('commentaire : modification par un autre refusée', `select edit_post_comment('${cB2}', 'piraté')`, /introuvable/);
  await as(null, 'anon');
  await fails('commentaire : anonyme refusé', `select edit_post_comment('${cB2}', 'x')`, /permission denied/);
  await as(B);
  const ec = (await one(`select edit_post_comment('${cB2}', 'Commentaire corrigé') r`)).r;
  check('commentaire : l\'auteur modifie', ec.edited && ec.body === 'Commentaire corrigé' && (await sudo(`select edited_at is not null e from post_comments where id = '${cB2}'`))[0].e);
  await fails('commentaire : trop long refusé (non tronqué)', `select edit_post_comment('${cB2}', '${'x'.repeat(501)}')`, /500 caract/);
  await fails('commentaire : vide refusé', `select edit_post_comment('${cB2}', '   ')`, /Écrivez/);
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${A}', '${B}')`);
  await fails('commentaire : modification refusée après blocage par l\'auteur de la publication', `select edit_post_comment('${cB2}', 'encore')`, /impossible|introuvable/);
  await sudo(`delete from user_blocks where blocker_id = '${A}' and blocked_id = '${B}'`);

  // modification d'une publication
  await as(B);
  const pB = (await sudo(`select id from posts where author_id = '${B}' order by created_at limit 1`))[0].id;
  await sudo(`update posts set status = 'published', published_at = now() where id = '${pB}'`);
  const e1 = (await one(`select edit_my_post('${pB}', 'Texte modifié', 'https://exemple.cm/x', array['Tag', 'tag', 'Autre']) r`)).r;
  check('publication : modification d\'un compte non certifié → nouvelle validation', e1.edited && e1.status === 'pending', JSON.stringify(e1));
  check('publication : contenu, lien, étiquettes dédupliquées, edited_at', (await sudo(`select (body = 'Texte modifié' and link_url = 'https://exemple.cm/x' and cardinality(tags) = 2 and edited_at is not null) ok from posts where id = '${pB}'`))[0].ok);
  await fails('publication : lien invalide refusé', `select edit_my_post('${pB}', 'x', 'javascript:alert(1)')`, /Lien invalide/);
  await fails('publication : trop longue refusée (non tronquée)', `select edit_my_post('${pB}', '${'x'.repeat(2001)}')`, /2000 caract/);
  await fails('publication : texte vide sans lien refusé', `select edit_my_post('${pB}', '')`, /Écrivez/);
  await fails('publication : 11 étiquettes refusées', `select edit_my_post('${pB}', 'x', null, array['a','b','c','d','e','f','g','h','i','j','k'])`, /10 étiquettes/);
  await as(C);
  await fails('publication : modification par un autre refusée', `select edit_my_post('${pB}', 'piraté')`, /introuvable/);
  await as(null, 'anon');
  await fails('publication : anonyme refusé', `select edit_my_post('${pB}', 'x')`, /permission denied/);
  await as(A);
  const e2 = (await one(`select edit_my_post('${pA1}', 'Première publication corrigée') r`)).r;
  check('publication : un compte certifié reste publié', e2.status === 'published');
  await sudo(`update posts set status = 'hidden' where id = '${pA2}'`);
  await fails('publication : masquée par la modération → modification refusée', `select edit_my_post('${pA2}', 'x')`, /masquée/);
  await sudo(`update posts set status = 'published' where id = '${pA2}'`);

  // pas de résurrection
  await as(A);
  const pX = await mkPost(A, 'À retirer');
  await q(`select delete_my_post('${pX}')`);
  await as(SUP);
  await fails('retrait par l\'auteur : la modération ne le remet pas en ligne (défaut corrigé)', `select moderate_post('${pX}', true, 'ok')`, /retirée par son auteur/);
  await fails('retrait par l\'auteur : ni masqué', `select moderate_post('${pX}', false, 'motif valable')`, /retirée par son auteur/);
  check('retrait par l\'auteur : reste retiré', (await sudo(`select status from posts where id = '${pX}'`))[0].status === 'removed');

  // ================================================================ 3. fil paginé
  await sudo(`delete from posts where status = 'published' and author_id not in ('${A}')`);
  const feedIds = [];
  for (let i = 0; i < 5; i++) feedIds.push(await mkPost(A, `Fil ${i}`, { at: `now() - interval '${i + 1} hours'` }));
  await mkPost(B, 'Fil de B', { at: `now() - interval '30 minutes'` });
  await sudo(`update profiles set suspended = false where id = '${D}'`);
  const pSusp = await mkPost(D, 'Fil de D suspendu', { at: `now() - interval '20 minutes'` });
  await sudo(`update profiles set suspended = true where id = '${D}'`);
  await mkPost(E, 'Fil de E bloqué par A', { at: `now() - interval '10 minutes'` });
  const com = (await sudo(`insert into communities (name, privacy, status, owner_id) values ('Club H13', 'invite', 'active', '${A}') returning id`))[0].id;
  await mkPost(A, 'Secret de communauté', { community: com });
  const page = async (lim, at, id, scope = 'all') => (await q(`select * from circle_feed_page(${lim}, ${at ? `'${at}'` : 'null'}, ${id ? `'${id}'` : 'null'}, '${scope}')`));
  await as(F);
  const all = await page(60);
  const allCap = all.map(r => r.caption);
  check('fil : ni communauté, ni suspendu, ni retiré', !allCap.includes('Secret de communauté') && !allCap.includes('Fil de D suspendu') && !allCap.includes('À retirer'));
  const seen = []; let cursor = null, pages = 0;
  while (pages < 20) {
    const r = await page(3, cursor?.at, cursor?.id);
    if (!r.length) break;
    seen.push(...r.map(x => x.id)); const last = r[r.length - 1]; cursor = { at: new Date(last.published_at).toISOString(), id: last.id }; pages++;
    if (pages === 1) await mkPost(A, 'Arrivée entre deux pages', { at: 'now()' });
  }
  check('pagination : sans doublon et dans l\'ordre du fil (nouvel arrivant exclu des pages suivantes)', new Set(seen).size === seen.length && seen.length === all.length, `${seen.length}/${all.length}`);
  const ordered = all.map(r => new Date(r.published_at).getTime());
  check('pagination : ordre décroissant', ordered.every((t, i) => i === 0 || ordered[i - 1] >= t));
  await fails('pagination : curseur incomplet refusé', `select * from circle_feed_page(5, null, '${feedIds[0]}')`, /Curseur invalide/);
  await fails('pagination : fil inconnu refusé', `select * from circle_feed_page(5, null, null, 'tout')`, /Fil inconnu/);
  check('pagination : limite bornée à 60', (await page(500)).length <= 60);
  await as(B);
  check('onglet Abonnements : seulement les auteurs suivis', (await page(60, null, null, 'following')).every(r => r.author_id === A) && (await page(60, null, null, 'following')).length > 0);
  await as(null, 'anon');
  check('anonyme : fil public lisible', (await page(5)).length === 5);
  check('anonyme : onglet Abonnements vide', (await page(5, null, null, 'following')).length === 0);
  await as(E);
  check('blocage : l\'auteur qui m\'a bloqué est absent du fil', !(await page(60)).some(r => r.author_id === A));
  await as(A);
  check('blocage : et inversement', !(await page(60)).some(r => r.author_id === E));

  // ================================================================ 4. profils créateurs
  await as(F);
  const tabs = (await one(`select creator_profile_tabs('${A}') r`)).r;
  check('onglets : comptage réel des publications, 0 pour les autres (état vide honnête)', tabs.tabs.publications >= 6 && tabs.tabs.lives === 0 && tabs.tabs.projets === 0 && tabs.tabs.produits === 0 && tabs.tabs.reposts === 0 && tabs.tabs.clips === 0, JSON.stringify(tabs));
  check('onglets : un compte inexistant → null', (await one(`select creator_profile_tabs('${U(99)}') r`)).r === null);
  await sudo(`insert into projects (owner_id, title, status, visibility) values ('${A}', 'Projet public', 'approved', 'public'), ('${A}', 'Projet privé', 'approved', 'private'), ('${A}', 'Projet brouillon', 'draft', 'public')`);
  await sudo(`insert into listings (seller_id, title, department, price, status) values ('${A}', 'Produit approuvé', 'Génie informatique', 5000, 'approved'), ('${A}', 'Produit en attente', 'Génie informatique', 5000, 'pending')`);
  const lv = (await sudo(`insert into lives (host_id, title, status, started_at, visibilite, live_type) values ('${A}', 'Live public', 'ended', now() - interval '3 hours', 'public', 'public') returning id`))[0].id;
  await sudo(`insert into lives (host_id, title, status, started_at, visibilite, live_type) values ('${A}', 'Live privé', 'ended', now() - interval '4 hours', 'prive', 'prive')`);
  const rp = await mkPost(F, 'Republication de F', { repost: feedIds[0] });
  await mkPost(A, 'Republication par A', { repost: (await sudo(`select id from posts where body = 'Fil de B'`))[0].id });
  const t2 = (await one(`select creator_profile_tabs('${A}') r`)).r.tabs;
  check('onglets : projets approuvés publics seulement', t2.projets === 1, JSON.stringify(t2));
  check('onglets : produits approuvés seulement', t2.produits === 1);
  check('onglets : lives publics seulement pour un tiers', t2.lives === 1);
  check('onglets : reposts dont l\'original est visible', t2.reposts === 1);
  await as(A);
  const t3 = (await one(`select creator_profile_tabs('${A}') r`)).r.tabs;
  check('onglets : le propriétaire voit aussi ses lives privés et projets privés', t3.lives === 2 && t3.projets === 2, JSON.stringify(t3));
  await as(null, 'anon');
  check('onglets : un anonyme lit les onglets d\'un profil public', (await one(`select creator_profile_tabs('${A}') r`)).r.tabs.publications >= 6);
  await sudo(`update profiles set profile_visibility = 'private' where id = '${B}'`);
  check('confidentialité : profil non visible → null pour un tiers', (await one(`select creator_profile_tabs('${B}') r`)).r === null, JSON.stringify(await sudo(`select profile_visibility, suspended from profiles where id = '${B}'`)));
  await as(F);
  check('confidentialité : et pour un tiers connecté', (await one(`select creator_tab_items('${B}', 'publications') r`)).r === null);
  await sudo(`update profiles set profile_visibility = 'public' where id = '${B}'`);
  await as(E);
  check('blocage : onglets du créateur qui m\'a bloqué → null', (await one(`select creator_profile_tabs('${A}') r`)).r === null);
  await as(F);
  await fails('onglet inconnu refusé', `select creator_tab_items('${A}', 'zzz')`, /Onglet inconnu/);
  const pg1 = (await one(`select creator_tab_items('${A}', 'publications', 3) r`)).r;
  check('liste d\'onglet : page 1 avec curseur suivant', pg1.items.length === 3 && !!pg1.next, JSON.stringify(pg1.next));
  const pg2 = (await one(`select creator_tab_items('${A}', 'publications', 3, '${pg1.next.before_at}', '${pg1.next.before_id}') r`)).r;
  const ids1 = pg1.items.map(i => i.id), ids2 = pg2.items.map(i => i.id);
  check('liste d\'onglet : page 2 sans doublon', ids2.length > 0 && ids2.every(i => !ids1.includes(i)));

  // épinglage
  await as(F);
  await fails('épinglage : le profil d\'un autre ne s\'épingle pas', `select creator_pin_set('publications', '${feedIds[0]}', true)`, /introuvable|non publié/);
  await as(null, 'anon');
  await fails('épinglage : anonyme refusé', `select creator_pin_set('publications', '${feedIds[0]}', true)`, /permission denied/);
  await as(A);
  for (const i of [0, 1, 2]) await q(`select creator_pin_set('publications', '${feedIds[i]}', true)`);
  await fails('épinglage : 4e élément refusé', `select creator_pin_set('publications', '${feedIds[3]}', true)`, /Trois éléments/);
  const rep = (await one(`select creator_pin_set('publications', '${feedIds[1]}', true) r`)).r;
  check('épinglage : rejeu idempotent', rep.changed === false && rep.count === 3);
  await fails('épinglage : élément en attente refusé', `select creator_pin_set('publications', '${pPend}', true)`, /non publié|introuvable/);
  await fails('épinglage : élément d\'un autre onglet refusé', `select creator_pin_set('produits', '${feedIds[3]}', true)`, /non publié|introuvable/);
  check('épinglage : onglet indépendant (un live)', (await one(`select creator_pin_set('lives', '${lv}', true) r`)).r.count === 1);
  await as(F);
  const pinned = (await one(`select creator_tab_items('${A}', 'publications', 20) r`)).r.items;
  check('épinglés : en tête de la liste, visibles de tous', pinned.slice(0, 3).every(i => i.pinned) && pinned.slice(3).every(i => !i.pinned) && pinned.length >= 6, JSON.stringify(pinned.map(i => i.pinned)));
  check('épinglés : creator_pins_list expose les 3 identifiants', (await one(`select creator_pins_list('${A}') r`)).r.publications.length === 3);
  check('épinglés : isolation, un tiers ne lit aucune ligne de la table brute', (await one(`select count(*)::int n from creator_pins`)).n === 0);
  await as(A);
  await q(`select delete_my_post('${feedIds[2]}')`);
  const pl = (await one(`select creator_pins_list('${A}') r`)).r;
  check('épinglés : une publication retirée disparaît des épinglés', pl.publications.length === 2 && !pl.publications.includes(feedIds[2]));
  check('épinglage : place libérée → nouvel épinglage possible', (await one(`select creator_pin_set('publications', '${feedIds[3]}', true) r`)).r.count === 3);
  const un1 = (await one(`select creator_pin_set('publications', '${feedIds[3]}', false) r`)).r;
  check('désépinglage : effectif, rejeu sans effet', un1.count === 2 && (await one(`select creator_pin_set('publications', '${feedIds[3]}', false) r`)).r.changed === false);

  // visites : agrégats seulement
  await as(null, 'anon');
  await fails('visite : anonyme refusé', `select profile_visit_record('${A}')`, /permission denied/);
  await as(F);
  check('visite : enregistrée une fois par jour', (await one(`select profile_visit_record('${A}') r`)).r === true && (await one(`select profile_visit_record('${A}') r`)).r === false);
  await as(B);
  check('visite : un autre visiteur compte', (await one(`select profile_visit_record('${A}') r`)).r === true);
  check('visite : son propre profil ne compte pas', (await one(`select profile_visit_record('${B}') r`)).r === false);
  await as(E);
  check('visite : bloqué → non enregistrée', (await one(`select profile_visit_record('${A}') r`)).r === false);
  await fails('visite : la table brute n\'est lisible par personne', `select count(*) from profile_visits`, /permission denied/);
  await as(A);
  const vs = (await one(`select creator_visit_stats(30) r`)).r;
  check('visites : agrégat pour le propriétaire, sans identité', vs.visits === 2 && vs.identities === false && !/visitor/.test(JSON.stringify(vs)), JSON.stringify(vs));
  await as(F);
  check('visites : le tiers voit ses propres compteurs (0), jamais ceux d\'autrui', (await one(`select creator_visit_stats(30) r`)).r.visits === 0);

  // ================================================================ 5. modération des commentaires
  await as(A);
  const pm = await mkPost(A, 'Publication à commentaires');
  const cm1 = (await sudo(`insert into post_comments (post_id, author_id, body) values ('${pm}', '${B}', 'Commentaire litigieux') returning id`))[0].id;
  const cm2 = (await sudo(`insert into post_comments (post_id, author_id, body) values ('${pm}', '${C}', 'Commentaire correct') returning id`))[0].id;
  await as(F);
  await q(`select report_comment('${cm1}', 'Insultes')`);
  await as(E);
  await q(`select report_comment('${cm1}', 'Harcèlement')`);
  await q(`select report_comment('${cm2}', 'Doute')`);
  await fails('signalement : limite horaire par compte (3e refusé)', `select report_comment('${cm2}', 'encore')`, /Limite atteinte|déjà/);
  await as(B);
  await fails('modération : un utilisateur ordinaire refusé', `select comment_report_decide(gen_random_uuid(), true, 'motif')`, /Réservé/);
  await fails('modération : résumé réservé', `select social_moderation_summary()`, /Réservé/);
  await as(null, 'anon');
  await fails('modération : anonyme refusé', `select comment_report_decide(gen_random_uuid(), true, 'motif')`, /permission denied/);
  const rep1 = (await sudo(`select id from comment_reports where comment_id = '${cm1}' order by created_at limit 1`))[0].id;
  const rep2 = (await sudo(`select id from comment_reports where comment_id = '${cm2}' limit 1`))[0].id;
  await as(DEP2);
  await fails('isolation : un autre département ne décide pas', `select comment_report_decide('${rep1}', true, 'motif valable')`, /introuvable/);
  await as(SUP);
  await fails('masquage : motif obligatoire', `select comment_report_decide('${rep1}', true, '')`, /Motif obligatoire/);
  const sum = (await one(`select social_moderation_summary() r`)).r;
  check('résumé de la file : compteurs réels', sum.comments_reported === 2 && sum.posts_pending >= 1, JSON.stringify(sum));
  check('masquage : décidé', (await one(`select comment_report_decide('${rep1}', true, 'Propos injurieux') r`)).r === 'masque');
  check('masquage : commentaire masqué, TOUS les signalements fermés', (await sudo(`select status from post_comments where id = '${cm1}'`))[0].status === 'hidden' && (await sudo(`select count(*)::int n from comment_reports where comment_id = '${cm1}' and status = 'open'`))[0].n === 0);
  check('masquage : les deux signalants et l\'auteur sont notifiés', (await sudo(`select count(*)::int n from notifications where kind = 'moderation' and user_id in ('${F}', '${E}', '${B}') and data->>'comment' = '${cm1}'`))[0].n === 3);
  check('masquage : décision journalisée', (await sudo(`select count(*)::int n from audit_log where target = '${cm1}' and category = 'Modération'`))[0].n === 1);
  check('rejeu : déjà traité, ni notification ni audit en double', (await one(`select comment_report_decide('${rep1}', true, 'Propos injurieux') r`)).r === 'deja_traite'
    && (await sudo(`select count(*)::int n from notifications where kind = 'moderation' and data->>'comment' = '${cm1}'`))[0].n === 3
    && (await sudo(`select count(*)::int n from audit_log where target = '${cm1}'`))[0].n === 1);
  await as(DEP);
  check('classement : le département concerné classe un signalement', (await one(`select comment_report_decide('${rep2}', false, null) r`)).r === 'classe' && (await sudo(`select status from post_comments where id = '${cm2}'`))[0].status === 'visible');

  // ================================================================ 6. médias et droits de lecture
  const mPub = await mkPost(A, 'Photo publique');
  const mPend = await mkPost(A, 'Photo en attente', { status: 'pending' });
  const mHid = await mkPost(A, 'Photo masquée', { status: 'hidden' });
  const mCom = await mkPost(A, 'Photo de communauté privée', { community: com });
  const pm_ = async (post, p, kind = 'image') => sudo(`insert into post_media (post_id, path, kind, pos) values ('${post}', '${p}', '${kind}', 0)`);
  await pm_(mPub, `${A}/pub.jpg`); await pm_(mPend, `${A}/pend.jpg`); await pm_(mHid, `${A}/hid.jpg`); await pm_(mCom, `${A}/com.jpg`);
  const rd = async (p) => (await one(`select _post_media_readable('${p}') r`)).r;
  await as(F);
  check('médias : publication publiée lisible par un tiers', await rd(`${A}/pub.jpg`) === true);
  check('médias : en attente / masquée / communauté privée non lisibles par un tiers', !(await rd(`${A}/pend.jpg`)) && !(await rd(`${A}/hid.jpg`)) && !(await rd(`${A}/com.jpg`)));
  check('médias : fichier non référencé lisible (compatibilité)', await rd(`${F}/libre.jpg`) === true);
  await as(A);
  check('médias : le propriétaire lit les siens', (await rd(`${A}/pend.jpg`)) && (await rd(`${A}/com.jpg`)));
  await as(SUP);
  check('médias : la modération lit tout', (await rd(`${A}/hid.jpg`)) && (await rd(`${A}/pend.jpg`)));
  await as(null, 'anon');
  check('médias : anonyme : public oui, privé non', (await rd(`${A}/pub.jpg`)) && !(await rd(`${A}/hid.jpg`)));
  await sudo(`insert into community_members (community_id, user_id, status) values ('${com}', '${F}', 'active')`);
  await as(F);
  check('médias : un membre lit le fichier de la communauté privée', await rd(`${A}/com.jpg`) === true);
  await as(A);
  await sudo(`insert into post_media (post_id, path, kind, pos) values ('${mPub}', '${A}/ok.png', 'image', 1)`);
  check('post_media : fichier valide accepté', true);
  await sudo(`select 1`);
  const attempt = async (name, p, kind, re) => { try { await sudo(`insert into post_media (post_id, path, kind, pos) values ('${mPub}', '${p}', '${kind}', 9)`); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await attempt('post_media : extension non acceptée refusée', `${A}/virus.exe`, 'image', /non accepté/);
  await attempt('post_media : vidéo déclarée image refusée', `${A}/clip.mp4`, 'image', /ne correspond pas/);
  await sudo(`insert into storage.objects (bucket_id, name, metadata) values ('post-media', '${A}/gros.jpg', '{"size": 60000000, "mimetype": "image/jpeg"}'::jsonb), ('post-media', '${A}/faux.jpg', '{"size": 1000, "mimetype": "video/mp4"}'::jsonb)`);
  await attempt('post_media : plus de 50 Mo refusé', `${A}/gros.jpg`, 'image', /50 Mo/);
  await attempt('post_media : type MIME incohérent refusé', `${A}/faux.jpg`, 'image', /ne correspond pas/);

  // ================================================================ 7. statistiques créateur
  const sPost = await mkPost(A, 'Stat publiée');
  const sHid = await mkPost(A, 'Stat masquée', { status: 'hidden' });
  await sudo(`insert into post_views (post_id, viewer_id) values ('${sPost}', '${B}'), ('${sPost}', '${C}'), ('${sHid}', '${B}'), ('${sHid}', '${F}')`);
  await sudo(`insert into post_likes (post_id, user_id) values ('${sPost}', '${B}'), ('${sHid}', '${B}') on conflict do nothing`);
  await as(A);
  const an = (await one(`select creator_analytics(30) r`)).r;
  check('statistiques : les publications masquées ne comptent plus (défaut corrigé)', an.views.period === 2 && an.engagement.likes >= 1 && !an.top_posts.some(t => t.id === sHid), JSON.stringify(an.views) + JSON.stringify(an.engagement));
  check('statistiques : abonnés sans suspendus ni auto-abonnement', an.followers.total === 2, JSON.stringify(an.followers));
  check('statistiques : même contrat JSON', ['days', 'posts', 'views', 'engagement', 'followers', 'lives', 'gifts', 'top_posts', 'unavailable'].every(k => k in an));
  await as(B);
  check('statistiques : isolation, B ne voit pas les vues de A', (await one(`select creator_analytics(30) r`)).r.views.period === 0);
  await as(null, 'anon');
  await fails('statistiques : anonyme refusé', `select creator_analytics(30)`, /permission denied/);

  // ================================================================ 8. suggestions
  await as(F);
  const sg = (await one(`select creators_suggested(10) r`)).r;
  const sgIds = sg.map(x => x.id);
  check('suggestions : créateurs avec publication, sans soi-même, sans bloqué, sans suspendu', sgIds.includes(A) && !sgIds.includes(F) && !sgIds.includes(D), JSON.stringify(sgIds));
  await as(E);
  check('suggestions : un créateur qui m\'a bloqué n\'est pas proposé', !(await one(`select creators_suggested(10) r`)).r.some(x => x.id === A));
  await as(F);
  check('suggestions : uniquement des données publiques', sg.every(x => Object.keys(x).sort().join() === 'avatar_url,certified,followers_count,id,mutual_count,name,posts_count,reason'));
  await as(B);
  check('suggestions : un compte déjà suivi n\'est pas proposé', !(await one(`select creators_suggested(10) r`)).r.some(x => x.id === A));
  await as(null, 'anon');
  check('suggestions : lisibles en anonyme', (await one(`select creators_suggested(5) r`)).r.some(x => x.id === A));

  // ================================================================ 9. rejeu des migrations
  const before = JSON.stringify({
    f: await sudo(`select count(*)::int n from engagements`), n: await sudo(`select count(*)::int n from notifications`),
    p: await sudo(`select count(*)::int n from creator_pins`), s: await sudo(`select value from platform_settings where key = 'social.rate.posts_per_hour'`) });
  await as(null, null);
  let replay = true, err = '';
  for (const f of fs.readdirSync(path.join(repo, 'migrations')).filter(x => /^202611280500\d\d_h13_social/.test(x)).sort()) {
    try { await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); } catch (e) { replay = false; err = f + ': ' + e.message; }
  }
  check('rejeu : les 6 migrations se rejouent sans erreur', replay, err);
  const after = JSON.stringify({
    f: await sudo(`select count(*)::int n from engagements`), n: await sudo(`select count(*)::int n from notifications`),
    p: await sudo(`select count(*)::int n from creator_pins`), s: await sudo(`select value from platform_settings where key = 'social.rate.posts_per_hour'`) });
  check('rejeu : aucune donnée modifiée, réglage conservé', before === after, before + ' / ' + after);

  console.log(`\nh13_social : ${ok} OK, ${ko} ECHEC`);
}
