// Scénario PGlite du lot H13.1 SOCIAL-LISTES : listes d'abonnés / d'abonnements paginées par curseur, confidentialité des listes, suggestions de créateurs à suivre.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_social_listes.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let ok = 0, ko = 0;
export async function run(db) {
  const W = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
  let cur = { uid: null, role: 'authenticated' };
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sudo = async (sql) => { const save = cur; await as(null, null); try { try { return await q(sql); } catch (e) { if (!/multiple commands/.test(e.message)) throw e; await db.exec(sql); return []; } } finally { await as(save.uid, save.role); } };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const one = async (sql) => (await q(sql))[0];

  const P = W(1), F = [2, 3, 4, 5, 6, 7, 8].map(W), SUS = W(9), DEL = W(10), BLK = W(11), BLK2 = W(12), PRIV = W(13), CLI = W(14), V = W(15), HID = W(16), PRV = W(17), MEM = W(18),
    G = [19, 20, 21].map(W), GSUS = W(22), GBLK = W(23), CLIV = W(24), NEW = W(25), OTHER = W(26);
  const accounts = [[P, 'student', 'Pascal Createur'], ...F.map((f, i) => [f, 'student', `Abonne${i + 1} Famille${i + 1}`]), [SUS, 'student', 'Suspendu Compte'], [DEL, 'student', 'Supprime Compte'], [BLK, 'student', 'Bloque Parmoi'], [BLK2, 'student', 'Bloque Parcreateur'],
    [PRIV, 'student', 'Prive Abonne'], [CLI, 'client', 'Client Abonne'], [V, 'student', 'Viewer Famille'], [HID, 'student', 'Cache Listes'], [PRV, 'student', 'Profil Prive'], [MEM, 'student', 'Membres Seulement'],
    ...G.map((g, i) => [g, 'student', `Suivi${i + 1} Famille${i + 1}`]), [GSUS, 'student', 'Suivi Suspendu'], [GBLK, 'student', 'Suivi Bloque'], [CLIV, 'client', 'Client Lecteur'], [NEW, 'student', 'Nouveau Venu'], [OTHER, 'student', 'Autre Personne']];
  await db.exec('reset role');
  for (const [id, r, name] of accounts) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${id.slice(-6)}@h131.cm'); insert into profiles(id,name,role,email,phone,created_at) values ('${id}','${name}','${r}','${id.slice(-6)}@h131.cm','+23760${id.slice(-7)}', now() - interval '9 days')`);
  }
  const mkPost = async (author, body, at = 'now()') => (await sudo(`insert into posts (author_id, kind, body, caption, status, published_at) values ('${author}', 'text', $$${body}$$, $$${body}$$, 'published', ${at}) returning id`))[0].id;
  for (const id of [P, ...F, G[0], HID, PRV, MEM]) await mkPost(id, `Publication de ${id}`);
  await sudo(`update profiles set avatar_url = 'avatars/p.png' where id = '${F[0]}'`);

  // abonnés de P : F1..F7 (du plus ancien au plus récent), plus des comptes à exclure
  const follow = (u, target, minutes, status = 'active') => sudo(`insert into engagements (user_id, kind, ref, status, created_at, updated_at) values ('${u}', 'follow', '${target}', '${status}', now() - interval '${minutes} minutes', now() - interval '${minutes} minutes')`);
  for (let i = 0; i < F.length; i++) await follow(F[i], P, 100 - i * 10);
  await follow(SUS, P, 50); await follow(DEL, P, 51); await follow(BLK, P, 52); await follow(BLK2, P, 53); await follow(PRIV, P, 54); await follow(CLI, P, 55); await follow(V, P, 56);
  await follow(OTHER, P, 57, 'cancelled');
  await sudo(`insert into engagements (user_id, kind, ref, status) values ('${OTHER}', 'stock_alert', '${P}', 'active') on conflict do nothing`);
  await sudo(`update profiles set suspended = true where id = '${SUS}'; update profiles set suspended = true, name = 'Compte supprimé', email = null, phone = null where id = '${DEL}'`);
  await sudo(`update profiles set profile_visibility = 'private' where id in ('${PRIV}', '${PRV}'); update profiles set profile_visibility = 'members' where id = '${MEM}'; update profiles set follow_lists_public = false where id = '${HID}'`);
  // abonnements de P : G1..G3 + comptes à exclure + cible non-compte
  await follow(P, G[0], 30); await follow(P, G[1], 20); await follow(P, G[2], 10); await follow(P, GSUS, 5); await follow(P, GBLK, 4); await sudo(`alter table engagements disable trigger trg_h13_follow_guard; insert into engagements (user_id, kind, ref) values ('${P}', 'follow', '${P}'); alter table engagements enable trigger trg_h13_follow_guard`); await follow(P, 'company:89', 2);
  await sudo(`update profiles set suspended = true where id = '${GSUS}'`);
  // abonnés de HID, PRV, MEM
  await follow(F[0], HID, 10); await follow(F[0], PRV, 10); await follow(F[0], MEM, 10);
  // liens de « je le suis » : V suit F1 et F3
  await follow(V, F[0], 5); await follow(V, F[2], 5);
  // blocages
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${V}', '${BLK}'), ('${P}', '${BLK2}'), ('${P}', '${GBLK}')`);

  const L = (fn, u, limit = 20, cursor = null) => one(`select ${fn}('${u}', ${limit}, ${cursor ? `'${JSON.stringify(cursor)}'::jsonb` : 'null'}) r`).then((x) => x.r);
  const all = async (fn, u, limit) => { const items = []; let cursor = null, pages = 0; do { const r = await L(fn, u, limit, cursor); items.push(...r.items); cursor = r.next; pages++; } while (cursor && pages < 30); return { items, pages }; };
  const ids = (r) => r.items.map((x) => x.id);

  // ================================================================ 1. anonyme
  await as(null, 'anon');
  let r = await L('followers_list', P);
  check('anonyme : abonnés d\'un profil public lisibles', r.allowed === true && r.items.length > 0, JSON.stringify(r));
  check('anonyme : aucun abonné suspendu, supprimé, privé ou sans profil public', !ids(r).some((i) => [SUS, DEL, PRIV, CLI].includes(i)), ids(r).join());
  check('anonyme : noms abrégés seulement', r.items.every((x) => !/Famille/.test(x.name)) && r.items.some((x) => /^Abonne1 F\.$/.test(x.name)), JSON.stringify(r.items.map((x) => x.name)));
  check('anonyme : aucune donnée privée (clés exactes, ni e-mail ni téléphone)', r.items.every((x) => Object.keys(x).sort().join() === 'avatar_url,certified,i_follow,id,is_me,name,role') && !/@h131\.cm|\+23760/.test(JSON.stringify(r)));
  check('anonyme : « je le suis » toujours faux', r.items.every((x) => x.i_follow === false && x.is_me === false));
  r = await L('followers_list', PRV);
  check('anonyme : profil privé refusé (« unavailable »)', r.allowed === false && r.reason === 'unavailable' && r.items.length === 0, JSON.stringify(r));
  r = await L('followers_list', MEM);
  check('anonyme : profil réservé aux membres refusé', r.allowed === false && r.reason === 'unavailable');
  r = await L('following_list', HID);
  check('anonyme : listes masquées par leur propriétaire refusées (« lists_hidden »)', r.allowed === false && r.reason === 'lists_hidden' && r.items.length === 0, JSON.stringify(r));
  await fails('anonyme : réglage des listes refusé', `select follow_lists_privacy_set(false)`, /permission denied/);
  check('anonyme : compte inexistant => indisponible, sans erreur', (await L('followers_list', W(9999))).reason === 'unavailable');
  r = await one(`select followers_list(null, 20, null) r`).then((x) => x.r);
  check('anonyme : identifiant nul => indisponible', r.allowed === false && r.reason === 'unavailable');

  // ================================================================ 2. pagination par curseur
  await as(V);
  const pg = await all('followers_list', P, 3);
  check('pagination : toutes les pages sans doublon', new Set(ids(pg)).size === pg.items.length, ids(pg).join());
  check('pagination : ensemble exact (exclus : suspendu, supprimé, bloqué par moi, bloqué par le créateur, privé, client, désabonné, autre type)',
    JSON.stringify([...ids(pg)].sort()) === JSON.stringify([...F, V].sort()), ids(pg).join());
  check('pagination : plusieurs pages (3 par page)', pg.pages === 3, `pages=${pg.pages}`);
  const dates = await sudo(`select user_id, created_at from engagements where kind = 'follow' and ref = '${P}' and status = 'active' and user_id in (${ids(pg).map((i) => `'${i}'`).join()})`);
  const parDate = Object.fromEntries(dates.map((d) => [d.user_id, new Date(d.created_at).getTime()]));
  check('pagination : ordre strictement décroissant', ids(pg).every((id, i, a) => i === 0 || parDate[a[i - 1]] > parDate[id]), ids(pg).join());
  const p1 = await L('followers_list', P, 3);
  check('pagination : page pleine => curseur', p1.items.length === 3 && p1.next && p1.next.at && p1.next.id);
  await follow(NEW, P, 0);
  const p2 = await L('followers_list', P, 3, p1.next);
  check('pagination : un abonné ajouté entre deux pages ne crée aucun doublon', !ids(p2).includes(NEW) && !ids(p2).some((i) => ids(p1).includes(i)), ids(p2).join());
  const derniere = await all('followers_list', P, 3);
  check('pagination : dernière page sans curseur', (await L('followers_list', P, 50)).next === null);
  check('pagination : un nouvel abonné apparaît en tête à la relecture', ids(derniere)[0] === NEW);
  await sudo(`delete from engagements where user_id = '${NEW}' and kind = 'follow'`);
  await fails('pagination : curseur invalide refusé', `select followers_list('${P}', 3, '{"at":"x","id":"y"}'::jsonb)`, /Curseur invalide/);
  await fails('pagination : curseur incomplet refusé', `select followers_list('${P}', 3, '{"at":"2026-01-01T00:00:00Z"}'::jsonb)`, /Curseur invalide/);
  check('pagination : limite bornée (0 => 1 ligne, 1000 => 50 au plus)', (await L('followers_list', P, 0)).items.length === 1 && (await L('followers_list', P, 1000)).items.length <= 50);
  check('pagination : sans limite fournie, 20 par défaut', (await one(`select followers_list('${P}') r`)).r.allowed === true);

  // ================================================================ 3. contenu des lignes pour un viewer connecté
  r = await L('followers_list', P, 50);
  const byId = Object.fromEntries(r.items.map((x) => [x.id, x]));
  check('viewer : « je le suis » vrai pour F1 et F3 seulement', byId[F[0]].i_follow === true && byId[F[2]].i_follow === true && r.items.filter((x) => x.i_follow).length === 2, JSON.stringify(r.items.filter((x) => x.i_follow).map((x) => x.id)));
  check('viewer : sa propre ligne est marquée is_me', byId[V].is_me === true && r.items.filter((x) => x.is_me).length === 1);
  check('viewer : bloqué par moi absent, bloqué par le créateur absent', !byId[BLK] && !byId[BLK2]);
  check('viewer : nom complet d\'un abonné pour un membre connecté (comme le profil public)', byId[F[0]].name === 'Abonne1 Famille1' && byId[F[0]].avatar_url === 'avatars/p.png', JSON.stringify(byId[F[0]]));
  check('viewer : compte privé absent pour un tiers', !byId[PRIV]);
  const fg = await all('following_list', P, 2);
  check('abonnements : ensemble exact (suspendu, bloqué, soi-même, cible non-compte exclus)', JSON.stringify(ids(fg).sort()) === JSON.stringify([...G].sort()) && new Set(ids(fg)).size === ids(fg).length, ids(fg).join());
  check('abonnements : plusieurs pages', fg.pages === 2, `pages=${fg.pages}`);
  check('abonnements : ordre du plus récent au plus ancien', JSON.stringify(ids(fg)) === JSON.stringify([G[2], G[1], G[0]]), ids(fg).join());
  r = await L('followers_list', MEM);
  check('membres seulement : un membre connecté voit la liste', r.allowed === true && ids(r).includes(F[0]), JSON.stringify(r));
  r = await L('followers_list', PRV);
  check('profil privé : liste refusée à un tiers', r.allowed === false && r.reason === 'unavailable' && r.items.length === 0);
  r = await L('followers_list', HID);
  check('listes masquées : refusées à un tiers', r.allowed === false && r.reason === 'lists_hidden');
  r = await L('following_list', HID);
  check('listes masquées : « abonnements » aussi', r.allowed === false && r.reason === 'lists_hidden');
  r = await L('followers_list', SUS);
  check('compte suspendu : listes indisponibles', r.allowed === false && r.reason === 'unavailable');
  r = await L('followers_list', DEL);
  check('compte supprimé (anonymisé) : listes indisponibles', r.allowed === false && r.reason === 'unavailable');
  r = await L('followers_list', CLI);
  check('compte client (sans profil public) : listes indisponibles', r.allowed === false && r.reason === 'unavailable');
  r = await L('followers_list', BLK);
  check('compte que j\'ai bloqué : listes indisponibles', r.allowed === false && r.reason === 'unavailable');
  await as(BLK2);
  r = await L('followers_list', P);
  check('créateur qui m\'a bloqué : listes indisponibles', r.allowed === false && r.reason === 'unavailable' && r.items.length === 0);
  await as(CLIV);
  r = await L('followers_list', P);
  check('client connecté : lit les abonnés d\'un profil public', r.allowed === true && r.items.length === F.length + 2, String(r.items.length));

  // ================================================================ 4. propriétaire
  await as(PRIV);
  r = await L('followers_list', PRIV);
  check('propriétaire d\'un profil privé : voit ses propres listes', r.allowed === true && r.own === true);
  r = await L('followers_list', P);
  check('abonné au profil privé : se voit lui-même dans la liste d\'un tiers (is_me)', r.allowed === true && r.items.some((x) => x.id === PRIV && x.is_me), JSON.stringify(r.items.map((x) => x.id)));
  await as(PRV);
  r = await L('followers_list', PRV);
  check('propriétaire d\'un profil privé : ses abonnés', r.allowed === true && r.own === true && ids(r).includes(F[0]));
  await as(HID);
  r = await L('followers_list', HID);
  check('propriétaire : voit ses listes masquées, réglage public = false', r.allowed === true && r.own === true && r.lists_public === false && ids(r).includes(F[0]), JSON.stringify(r));
  check('réglage : lecture', (await one(`select follow_lists_privacy_get() r`)).r.public === false);
  await as(V);
  check('réglage : écriture directe de la colonne refusée', await q(`update profiles set follow_lists_public = false where id = '${V}'`).then(() => false, () => true));
  check('réglage : rôle authentifié, jamais sur le compte d\'un autre (via RPC)', (await one(`select follow_lists_privacy_set(false) r`)).r.public === false);
  check('réglage : V ne modifie pas le compte de HID', (await sudo(`select follow_lists_public from profiles where id = '${HID}'`))[0].follow_lists_public === false && (await sudo(`select follow_lists_public from profiles where id = '${OTHER}'`))[0].follow_lists_public === true);
  r = await L('followers_list', V);
  check('réglage : V masque ses listes, il les voit toujours', r.allowed === true && r.own === true && r.lists_public === false);
  await as(OTHER);
  r = await L('followers_list', V);
  check('réglage : un tiers voit « listes masquées » pour V', r.allowed === false && r.reason === 'lists_hidden');
  await as(V);
  await q(`select follow_lists_privacy_set(true)`);
  await as(OTHER);
  r = await L('followers_list', V);
  check('réglage : réactivation => liste de nouveau visible', r.allowed === true);
  await fails('réglage : valeur nulle refusée', `select follow_lists_privacy_set(null)`, /Réglage inconnu/);
  await sudo(`update profiles set suspended = true where id = '${OTHER}'`);
  await fails('réglage : compte suspendu refusé', `select follow_lists_privacy_set(false)`, /suspendu|indisponible/);
  await sudo(`update profiles set suspended = false where id = '${OTHER}'`);
  await as(HID);
  await q(`select follow_lists_privacy_set(true)`);
  await as(V);
  r = await L('followers_list', HID);
  check('réglage : HID republie ses listes, V les lit', r.allowed === true && ids(r).includes(F[0]));

  // ================================================================ 5. blocages et désabonnements en direct
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${V}', '${F[1]}')`);
  r = await L('followers_list', P, 50);
  check('blocage en direct : l\'abonné bloqué disparaît de la liste', !ids(r).includes(F[1]));
  await sudo(`delete from user_blocks where blocker_id = '${V}' and blocked_id = '${F[1]}'`);
  await q(`select follow_set('${F[1]}', true)`);
  r = await L('following_list', V, 50);
  check('abonnements de V : P, F1, F3 et F2 après abonnement', JSON.stringify(ids(r).sort()) === JSON.stringify([P, F[0], F[1], F[2]].sort()), ids(r).join());
  check('abonnements de V : tous marqués « je le suis »', r.items.every((x) => x.i_follow));
  await q(`select follow_set('${F[1]}', false)`);
  await q(`select follow_set('${F[1]}', false)`);
  r = await L('following_list', V, 50);
  check('désabonnement idempotent : disparaît des abonnements, sans erreur au rejeu', !ids(r).includes(F[1]));
  r = await L('followers_list', F[1], 50);
  check('abonnés de F2 : V n\'y est plus', !ids(r).includes(V));
  await sudo(`update engagements set status = 'cancelled' where user_id = '${F[6]}' and kind = 'follow' and ref = '${P}'`);
  r = await all('followers_list', P, 50);
  check('désabonné : retiré des abonnés', !ids(r).includes(F[6]));
  await sudo(`update engagements set status = 'active' where user_id = '${F[6]}' and kind = 'follow' and ref = '${P}'`);

  // ================================================================ 6. rejeu de la migration
  const mig = fs.readFileSync(path.join(repo, 'migrations', '20261129050000_h131_social_listes.sql'), 'utf8');
  const avant = JSON.stringify((await all('followers_list', P, 3)).items);
  await sudo(mig);
  await sudo(mig);
  const apres = JSON.stringify((await all('followers_list', P, 3)).items);
  check('rejeu : migration réappliquée deux fois sans effet de bord', avant === apres);
  check('rejeu : colonne unique, défaut true', (await sudo(`select count(*)::int n from information_schema.columns where table_name = 'profiles' and column_name = 'follow_lists_public'`))[0].n === 1 && (await sudo(`select follow_lists_public from profiles where id = '${P}'`))[0].follow_lists_public === true);
  check('droits : fonctions internes non exécutables par un membre', await q(`select _h131_follow_list('${P}', 'followers', 5, null)`).then(() => false, () => true));
  check('droits : _h131_blocked non exécutable par un membre', await q(`select _h131_blocked('${P}', '${V}')`).then(() => false, () => true));

  // ================================================================ 7. suggestions de créateurs à suivre
  const S = W(100), CA = W(101), CB = W(102), CC = W(103), CD = W(104), CE = W(105), CF = W(106), CG = W(107), CH = W(108), CI = W(109), CJ = W(110), CK = W(111), CL = W(112), X = W(113), CM = W(114), CN = W(115), CO = W(116);
  const I1 = W(9001), I2 = W(9002), DX = W(9101), DY = W(9102), DZ = W(9103), COM = W(9201);
  await as(null, null);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT suggestions', 'verified'), ('${I2}', 'Autre école', 'verified'); insert into departments (id, institution_id, name, status) values ('${DX}', '${I1}', 'Informatique', 'verified'), ('${DY}', '${I1}', 'Droit', 'verified'), ('${DZ}', '${I2}', 'Lettres', 'verified')`);
  const mk = async (id, role, name, extra = '') => { await db.exec(`insert into auth.users(id,email) values ('${id}','${id.slice(-6)}@h131s.cm'); insert into profiles(id,name,role,email,created_at) values ('${id}','${name}','${role}','${id.slice(-6)}@h131s.cm', now() - interval '9 days')`); if (extra) await db.exec(`update profiles set ${extra} where id = '${id}'`); };
  await mk(S, 'student', 'Sophie Lectrice', `institution_id = '${I1}', department_id = '${DX}', skills = 'Python, Design, Excel'`);
  await mk(CA, 'student', 'Camille Departement', `institution_id = '${I1}', department_id = '${DX}'`);
  await mk(CB, 'student', 'Cedric Etablissement', `institution_id = '${I1}', department_id = '${DY}'`);
  await mk(CC, 'student', 'Carine Communs', `institution_id = '${I2}', department_id = '${DZ}'`);
  await mk(CD, 'student', 'Chloe Communaute', `institution_id = '${I2}', department_id = '${DZ}'`);
  await mk(CE, 'student', 'Cyril Populaire', `institution_id = '${I2}', department_id = '${DZ}'`);
  await mk(CF, 'student', 'Cora SansPublication');
  await mk(CG, 'student', 'Cyrille Bloque', `institution_id = '${I1}', department_id = '${DX}'`);
  await mk(CH, 'student', 'Chantal Privee', `institution_id = '${I1}', department_id = '${DX}', profile_visibility = 'private'`);
  await mk(CI, 'student', 'Clara Deja', `institution_id = '${I1}', department_id = '${DX}'`);
  await mk(CJ, 'student', 'Cesar Suspendu', `institution_id = '${I1}', department_id = '${DX}'`);
  await mk(CK, 'student', 'Claude HorsAnnuaire', `institution_id = '${I1}', department_id = '${DX}', directory_listed = false`);
  await mk(CL, 'client', 'Cleo Cliente');
  await mk(X, 'student', 'Xavier Intermediaire', `institution_id = '${I2}', department_id = '${DZ}', follow_lists_public = false`);
  await mk(CM, 'student', 'Camille Cachee', `institution_id = '${I2}', department_id = '${DZ}'`);
  await mk(CN, 'student', 'Cecile Competence', `institution_id = '${I2}', department_id = '${DZ}', skills = 'design, comptabilité'`);
  await mk(CO, 'company', 'Entreprise Pro', `institution_id = '${I2}'`);
  await sudo(`  insert into communities (id, name, description, owner_id) values ('${COM}', 'Communauté H131', 'Test', '${CD}')`);
    await sudo(`insert into community_members (community_id, user_id, status) values ('${COM}', '${S}', 'active'), ('${COM}', '${CD}', 'active')`);
    for (const id of [CA, CB, CC, CD, CG, CH, CI, CJ, CK, CM, CN, CO]) await mkPost(id, `Publication ${id}`);
  await sudo(`update profiles set suspended = true where id = '${CJ}'`);
  await mkPost(CE, 'Ancienne publication', `now() - interval '90 days'`);
  await mkPost(CL, 'Cliente'); // un client n'est jamais proposé
  // popularité : CE a 3 abonnés (anciens), CA 0
  for (const n of [W(120), W(121), W(122)]) { await mk(n, 'student', `Fan ${n.slice(-3)}`); await follow(n, CE, 500); }
  // CC : suivi par X, que S suit (X masque ses listes -> ne compte pas) ; CM idem ; un vrai intermédiaire public : CB suit CC
  const Y = W(130); await mk(Y, 'student', 'Yvan Intermediaire', `institution_id = '${I2}', department_id = '${DZ}'`);
  await follow(S, Y, 60); await follow(Y, CC, 60); await follow(S, X, 60); await follow(X, CM, 60);
  await follow(S, CI, 60);
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${CG}', '${S}')`);

  await as(S);
  const sg = (await one(`select creators_suggested(30) r`)).r;
  const sid = sg.map((x) => x.id);
  const by = Object.fromEntries(sg.map((x) => [x.id, x]));
  check('suggestions : soi-même exclu', !sid.includes(S));
  check('suggestions : compte déjà suivi exclu', !sid.includes(CI));
  check('suggestions : compte qui m\'a bloqué exclu', !sid.includes(CG));
  check('suggestions : profil privé, suspendu, hors annuaire, client et sans publication exclus', ![CH, CJ, CK, CL, CF].some((i) => sid.includes(i)), sid.join());
  check('suggestions : même département en tête', sid[0] === CA && by[CA].reason === 'meme_departement', JSON.stringify(sg.slice(0, 2)));
  check('suggestions : même établissement (autre département)', by[CB] && by[CB].reason === 'meme_etablissement' && sid.indexOf(CA) < sid.indexOf(CB));
  check('suggestions : abonnement en commun (via un intermédiaire public)', by[CC] && by[CC].reason === 'abonnements_communs' && by[CC].mutual_count === 1, JSON.stringify(by[CC]));
  check('suggestions : un intermédiaire aux listes masquées n\'est pas compté', by[CM] && by[CM].mutual_count === 0 && by[CM].reason !== 'abonnements_communs', JSON.stringify(by[CM]));
  check('suggestions : communauté commune', by[CD] && by[CD].reason === 'communautes_communes', JSON.stringify(by[CD]));
  check('suggestions : compétences communes', by[CN] && by[CN].reason === 'competences_communes', JSON.stringify(by[CN]));
  check('suggestions : sans signal ni activité récente => « populaire »', by[CE] && by[CE].reason === 'populaire' && by[CE].followers_count === 3, JSON.stringify(by[CE]));
  check('suggestions : un signal personnel passe avant la simple popularité', sid.indexOf(CC) < sid.indexOf(CE) && sid.indexOf(CD) < sid.indexOf(CE));
  check('suggestions : organisation (company) possible avec publications, activité récente', by[CO] && by[CO].reason === 'actif_recemment', JSON.stringify(by[CO]));
  check('suggestions : aucune donnée privée', !/@h131s?\.cm|\+23760/.test(JSON.stringify(sg)) && sg.every((x) => Object.keys(x).sort().join() === 'avatar_url,certified,followers_count,id,mutual_count,name,posts_count,reason'), JSON.stringify(Object.keys(sg[0])));
  check('suggestions : noms abrégés (prénom + initiale)', by[CA].name === 'Camille D.');
  check('suggestions : limite bornée', (await one(`select creators_suggested(2) r`)).r.length === 2 && (await one(`select creators_suggested(0) r`)).r.length === 1);
  check('suggestions : aucun doublon', new Set(sid).size === sid.length);
  const apresSuivi = (await q(`select follow_set('${CA}', true) r`), (await one(`select creators_suggested(30) r`)).r.map((x) => x.id));
  check('suggestions : un créateur suivi disparaît aussitôt', !apresSuivi.includes(CA));
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${S}', '${CB}')`);
  check('suggestions : un compte que je bloque disparaît', !(await one(`select creators_suggested(30) r`)).r.some((x) => x.id === CB));
  await as(null, 'anon');
  const an = (await one(`select creators_suggested(30) r`)).r;
  check('suggestions anonyme : profils publics seulement, aucun signal personnel', an.length > 0 && an.every((x) => ['actif_recemment', 'populaire'].includes(x.reason) && x.mutual_count === 0) && !an.some((x) => [CH, CJ, CK, CL, CF].includes(x.id)), JSON.stringify(an.map((x) => x.reason)));
  check('suggestions anonyme : noms abrégés', an.every((x) => x.name.length > 0));
  await as(W(9990), 'authenticated');
  check('suggestions : un compte sans profil reçoit une liste (popularité) sans erreur', Array.isArray((await one(`select creators_suggested(5) r`)).r));
  await sudo(`delete from engagements where kind = 'follow'; delete from posts`);
  await as(S);
  check('suggestions : aucun créateur => liste vide honnête', (await one(`select creators_suggested(10) r`)).r.length === 0);

  console.log(`\n=== h131_social_listes : ${ok} OK / ${ko} ECHEC ===`);
}
