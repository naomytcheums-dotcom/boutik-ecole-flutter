// Scénario PGlite H13.1 · MÉDIAS : compartiment privé « post-media-private » (lecture/écriture/modification/suppression selon le compte), cibles signées,
// procédure de bascule (file, vérification, retour arrière, aucune suppression), rejeu des migrations.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_media.mjs
// Limite connue : PGlite n'a pas de serveur Storage. La règle « l'URL publique ne sert que les compartiments public = true » est celle de Supabase ; ici on prouve
// public = false + politiques de lecture de storage.objects (seul chemin d'accès des URL signées et de l'API authentifiée).
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  let cur = { uid: null, role: 'authenticated' };
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '${role === 'service_role' ? 'service_role' : 'authenticated'}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sudo = async (sql) => { const save = cur; await as(null, null); try { try { return await q(sql); } catch (e) { if (!/multiple commands/.test(e.message)) throw e; await db.exec(sql); return []; } } finally { await as(save.uid, save.role); } };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const one = async (sql) => (await q(sql))[0];
  const A = U(11), B = U(12), M = U(13), ADM = U(14), SUP = U(15), C = U(16);

  await db.exec('reset role');
  for (const [n, r] of [[11, 'student'], [12, 'student'], [13, 'student'], [14, 'admin'], [15, 'support'], [16, 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h131m${n}@t.cm'); insert into profiles(id,name,role,email,created_at) values ('${U(n)}','Membre H131 ${n}','${r}','h131m${n}@t.cm', now() - interval '5 days')`);
  }
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${SUP}', 'security', array['security.moderation', 'security.reports']) on conflict (user_id, team_code) do update set permissions = excluded.permissions`);
  await db.exec(`grant select, insert, update, delete on storage.objects to anon, authenticated; grant select, insert, update, delete on storage.buckets to anon, authenticated`);
  const closed = (await sudo(`insert into communities (name, privacy, status, owner_id) values ('Club fermé H131', 'invite', 'active', '${A}') returning id`))[0].id;
  await sudo(`insert into community_members (community_id, user_id, status) values ('${closed}', '${M}', 'active')`);
  const mkPost = async (author, body, extra = {}) => (await sudo(`insert into posts (author_id, kind, body, caption, status, published_at, community_id) values ('${author}', 'text', $$${body}$$, $$${body}$$, '${extra.status ?? 'published'}', now(), ${extra.community ? `'${extra.community}'` : 'null'}) returning id`))[0].id;
  const pm = (post, p) => sudo(`insert into post_media (post_id, path, kind, pos) values ('${post}', '${p}', 'image', 0)`);
  const obj = (bucket, name, size = 1000, extra = '') => sudo(`insert into storage.objects (bucket_id, name, metadata${extra ? ', created_at' : ''}) values ('${bucket}', '${name}', '{"size": ${size}, "mimetype": "image/jpeg"}'::jsonb${extra ? `, ${extra}` : ''})`);

  // ================================================================ 1. compartiments
  const bk = async (id) => (await sudo(`select public, file_size_limit, allowed_mime_types from storage.buckets where id = '${id}'`))[0];
  const bp = await bk('post-media-private'), bu = await bk('post-media');
  check('compartiment privé : public = false', bp && bp.public === false, JSON.stringify(bp));
  check('compartiment privé : même limite et mêmes types que post-media', bp.file_size_limit === bu.file_size_limit && JSON.stringify(bp.allowed_mime_types) === JSON.stringify(bu.allowed_mime_types));
  check('post-media reste public (anciennes URL des contenus publics inchangées)', bu.public === true);
  for (const id of ['avatars', 'listing-images', 'listing-videos']) check(`${id} : inchangé (public)`, (await bk(id))?.public === true);

  // ================================================================ 2. lecture du compartiment privé (RLS storage.objects)
  const pClosed = await mkPost(A, 'Publication de communauté fermée', { community: closed });
  const pOk = await mkPost(A, 'Publication publique');
  const pPend = await mkPost(A, 'Publication en attente', { status: 'pending' });
  await pm(pClosed, `${A}/private/closed.jpg`); await pm(pOk, `${A}/private/pubpost.jpg`); await pm(pPend, `${A}/private/pend.jpg`);
  await sudo(`insert into stories (author_id, media_path, media_kind) values ('${A}', '${A}/private/story.jpg', 'image'), ('${A}', '${A}/private/story_hidden.jpg', 'image')`);
  await sudo(`update stories set status = 'hidden' where media_path = '${A}/private/story_hidden.jpg'`);
  for (const n of ['closed', 'pubpost', 'pend', 'story', 'story_hidden', 'draft']) await obj('post-media-private', `${A}/private/${n}.jpg`);
  const seen = async () => (await q(`select name from storage.objects where bucket_id = 'post-media-private' order by name`)).map(r => r.name.split('/').pop().replace('.jpg', ''));
  await as(null, 'anon');
  check('lecture : un anonyme ne lit que l\'histoire active et la publication publique', JSON.stringify(await seen()) === JSON.stringify(['pubpost', 'story']), JSON.stringify(await seen()));
  await as(B);
  check('lecture : un tiers ne lit ni communauté fermée, ni en attente, ni histoire masquée, ni brouillon', JSON.stringify(await seen()) === JSON.stringify(['pubpost', 'story']), JSON.stringify(await seen()));
  await as(C);
  check('lecture : un autre compte (client) : idem', JSON.stringify(await seen()) === JSON.stringify(['pubpost', 'story']));
  await as(A);
  check('lecture : l\'auteur lit tous ses fichiers', (await seen()).length === 6);
  await as(M);
  check('lecture : un membre de la communauté fermée lit son média, pas le brouillon de l\'auteur', JSON.stringify(await seen()) === JSON.stringify(['closed', 'pubpost', 'story']), JSON.stringify(await seen()));
  await as(SUP);
  check('lecture : la modération lit tout', (await seen()).length === 6);
  await sudo(`insert into auth.users(id,email) values ('${U(17)}','h131m17@t.cm'); insert into profiles(id,name,role,email,created_at) values ('${U(17)}','Département H131','dept','h131m17@t.cm', now() - interval '5 days')`);
  await as(U(17));
  check('lecture : un compte Département ne lit ni communauté fermée, ni en attente, ni brouillon (isolation)', JSON.stringify(await seen()) === JSON.stringify(['pubpost', 'story']), JSON.stringify(await seen()));
  await sudo(`update stories set expires_at = now() - interval '1 hour' where media_path = '${A}/private/story.jpg'`);
  await as(B);
  check('histoire expirée : plus lisible par un tiers', !(await seen()).includes('story'));
  await as(null, 'anon');
  check('histoire expirée : plus lisible par un anonyme', !(await seen()).includes('story'));
  await as(A);
  check('histoire expirée : encore lisible par son auteur', (await seen()).includes('story'));
  await sudo(`update stories set expires_at = now() + interval '5 hours' where media_path = '${A}/private/story.jpg'`);
  await sudo(`insert into user_blocks (blocker_id, blocked_id) values ('${A}', '${B}')`);
  await as(B);
  check('histoire : un compte bloqué par l\'auteur ne la lit plus', !(await seen()).includes('story'));
  await sudo(`delete from user_blocks where blocker_id = '${A}' and blocked_id = '${B}'`);
  await sudo(`update communities set privacy = 'public' where id = '${closed}'`);
  await as(B);
  check('communauté devenue publique : son média redevient lisible', (await seen()).includes('closed'));
  await sudo(`update communities set privacy = 'invite' where id = '${closed}'`);
  await as(B);
  check('communauté refermée : de nouveau illisible pour un non-membre', !(await seen()).includes('closed'));

  // ================================================================ 3. écriture, modification, suppression
  await as(B);
  await fails('dépôt : refusé dans le dossier d\'un autre', `insert into storage.objects (bucket_id, name, metadata) values ('post-media-private', '${A}/private/intrus.jpg', '{}'::jsonb)`, /row-level|violates/);
  await q(`insert into storage.objects (bucket_id, name, metadata) values ('post-media-private', '${B}/private/mien.jpg', '{"size": 10}'::jsonb)`);
  check('dépôt : accepté dans son propre dossier', (await seen()).includes('mien'));
  check('modification : refusée sur le fichier d\'un autre (0 ligne)', (await q(`update storage.objects set metadata = '{"x":1}'::jsonb where bucket_id = 'post-media-private' and name = '${A}/private/closed.jpg' returning name`)).length === 0);
  check('modification : acceptée sur son fichier', (await q(`update storage.objects set metadata = '{"size": 11}'::jsonb where bucket_id = 'post-media-private' and name = '${B}/private/mien.jpg' returning name`)).length === 1);
  await fails('modification : impossible de déplacer son fichier dans le dossier d\'un autre', `update storage.objects set name = '${A}/private/vol.jpg' where bucket_id = 'post-media-private' and name = '${B}/private/mien.jpg'`, /row-level|violates/);
  check('suppression : refusée sur le fichier d\'un autre (0 ligne)', (await q(`delete from storage.objects where bucket_id = 'post-media-private' and name = '${A}/private/pubpost.jpg' returning name`)).length === 0);
  await as(M);
  check('suppression : un membre de la communauté ne supprime pas le fichier de l\'auteur', (await q(`delete from storage.objects where bucket_id = 'post-media-private' and name = '${A}/private/closed.jpg' returning name`)).length === 0);
  await as(SUP);
  check('suppression : la modération ne supprime pas via le stockage', (await q(`delete from storage.objects where bucket_id = 'post-media-private' and name = '${A}/private/closed.jpg' returning name`)).length === 0);
  await as(null, 'anon');
  await fails('anonyme : dépôt refusé', `insert into storage.objects (bucket_id, name, metadata) values ('post-media-private', '${A}/private/anon.jpg', '{}'::jsonb)`, /row-level|permission denied|violates/);
  check('anonyme : modification et suppression sans effet', (await q(`update storage.objects set metadata = '{}'::jsonb where bucket_id = 'post-media-private' returning name`)).length === 0 && (await q(`delete from storage.objects where bucket_id = 'post-media-private' returning name`)).length === 0);
  await as(B);
  check('suppression : acceptée sur son fichier', (await q(`delete from storage.objects where bucket_id = 'post-media-private' and name = '${B}/private/mien.jpg' returning name`)).length === 1);
  await as(A);
  check('suppression : le propriétaire supprime son fichier, les autres restent', (await q(`delete from storage.objects where bucket_id = 'post-media-private' and name = '${A}/private/draft.jpg' returning name`)).length === 1 && (await seen()).length === 5);
  check('modification : le propriétaire conserve son dossier', (await q(`update storage.objects set metadata = '{"size": 1000, "mimetype": "image/jpeg"}'::jsonb where bucket_id = 'post-media-private' and name = '${A}/private/closed.jpg' returning name`)).length === 1);

  // ================================================================ 4. cibles de lecture
  await as(B);
  check('cible : fichier du compartiment privé => signé', (await one(`select post_media_signed_target('${A}/private/pubpost.jpg') r`)).r.signed === true);
  check('cible : fichier public => non signé, compartiment post-media', (await one(`select post_media_signed_target('${A}/ancien.jpg') r`)).r.bucket === 'post-media');
  const tg = (await one(`select post_media_targets(array['${A}/private/pubpost.jpg', '${A}/ancien.jpg', '${A}/private/story.jpg']) r`)).r;
  check('cibles en lot : seuls les fichiers privés sont renvoyés', Object.keys(tg).length === 2 && tg[`${A}/private/pubpost.jpg`] === 'post-media-private' && !(`${A}/ancien.jpg` in tg), JSON.stringify(tg));
  await as(null, 'anon');
  check('cible : appelable par un anonyme (aucune donnée sensible)', (await one(`select post_media_targets(array['${A}/private/pubpost.jpg']) r`)).r[`${A}/private/pubpost.jpg`] === 'post-media-private');
  await fails('suivi de bascule : table inaccessible à un anonyme', `select * from media_migration`, /permission denied/);
  await as(B);
  await fails('suivi de bascule : table inaccessible à un utilisateur', `select * from media_migration`, /permission denied/);

  // ================================================================ 5. bascule des médias non publics de post-media
  const pRem = await mkPost(A, 'Retirée', { status: 'removed' }), pHid = await mkPost(A, 'Masquée', { status: 'hidden' });
  const pCom = await mkPost(A, 'Communauté fermée (ancien média)', { community: closed }), pPub = await mkPost(A, 'Publique (ancien média)');
  const pPend2 = await mkPost(A, 'En attente (ancien média)', { status: 'pending' }), pShared = await mkPost(A, 'Masquée mais couverture', { status: 'hidden' });
  const F = {
    pub: `${A}/pub.jpg`, rem: `${A}/rem.jpg`, hid: `${A}/hid.jpg`, com: `${A}/com.jpg`, pend: `${A}/pend2.jpg`, shared: `${A}/shared.jpg`,
    stExp: `${A}/st_exp.jpg`, stLive: `${A}/st_live.jpg`, orph: `${A}/orphelin.jpg`, orphOld: `${A}/orphelin_vieux.jpg`,
  };
  await pm(pPub, F.pub); await pm(pRem, F.rem); await pm(pHid, F.hid); await pm(pCom, F.com); await pm(pPend2, F.pend); await pm(pShared, F.shared);
  await sudo(`update profiles set cover_path = '${F.shared}' where id = '${A}'`);
  await sudo(`insert into stories (author_id, media_path, media_kind, expires_at) values ('${A}', '${F.stLive}', 'image', now() + interval '5 hours'), ('${A}', '${F.stExp}', 'image', now() + interval '1 hour')`);
  await sudo(`update stories set expires_at = now() - interval '2 hours' where media_path = '${F.stExp}'`);
  for (const n of ['pub', 'rem', 'hid', 'com', 'pend', 'shared', 'stExp', 'stLive', 'orph']) await obj('post-media', F[n]);
  await obj('post-media', F.orphOld, 1000, `now() - interval '3 days'`);
  const nPublic = async () => Number((await sudo(`select count(*)::int n from storage.objects where bucket_id = 'post-media'`))[0].n);
  const nPrivate = async () => Number((await sudo(`select count(*)::int n from storage.objects where bucket_id = 'post-media-private'`))[0].n);
  const pub0 = await nPublic(), priv0 = await nPrivate();
  const svc = async () => as(null, 'service_role');

  await as(B);
  await fails('bascule : un utilisateur ordinaire refusé', `select * from media_migrate_private_batch(10)`, /permission denied/);
  await fails('rapport : un utilisateur ordinaire refusé', `select media_migration_report()`, /permission denied/);
  await fails('confirmation : un utilisateur ordinaire refusé', `select media_migrate_confirm('${F.rem}')`, /permission denied/);
  await fails('retour arrière : un utilisateur ordinaire refusé', `select media_migrate_rollback('${F.rem}')`, /permission denied/);
  await fails('suppressions possibles : un utilisateur ordinaire refusé', `select * from media_old_deletion_candidates()`, /permission denied/);
  await as(null, 'anon');
  await fails('bascule : anonyme refusé', `select * from media_migrate_private_batch(10)`, /permission denied/);
  await as(SUP);
  await fails('bascule : le support (non administrateur) refusé', `select * from media_migrate_private_batch(10)`, /permission denied/);

  await svc();
  const rep0 = (await one(`select media_migration_report() r`)).r;
  check('rapport initial : états par contenu', rep0.public_content === 3 && rep0.pending_review === 1 && rep0.restricted === 4 && rep0.unreferenced === 2 && rep0.to_queue === 4 && rep0.verified === 0, JSON.stringify(rep0));
  check('rapport : fichiers restreints encore exposés par URL publique comptés', rep0.still_exposed_by_public_url === 4);
  const b1 = await q(`select * from media_migrate_private_batch(100)`);
  const names1 = b1.map(r => r.path).sort();
  check('bascule : file = retirée, masquée, communauté fermée, histoire expirée (ni public, ni en attente, ni partagé, ni orphelin récent)',
    JSON.stringify(names1) === JSON.stringify([F.com, F.hid, F.rem, F.stExp].sort()), JSON.stringify(names1));
  const reasons = Object.fromEntries(b1.map(r => [r.path, r.reason]));
  check('bascule : motifs', reasons[F.rem] === 'post_removed' && reasons[F.hid] === 'post_hidden' && reasons[F.com] === 'community_closed' && reasons[F.stExp] === 'story_expired', JSON.stringify(reasons));
  check('bascule : rien supprimé, rien copié par la base', await nPublic() === pub0 && await nPrivate() === priv0);
  const b2 = await q(`select * from media_migrate_private_batch(100)`);
  check('rejeu : même file, aucun doublon', b2.length === 4 && Number((await sudo(`select count(*)::int n from media_migration`))[0].n) === 4);
  check('bascule : limite respectée', (await q(`select * from media_migrate_private_batch(2)`)).length === 2);
  const b3 = await q(`select * from media_migrate_private_batch(100, true)`);
  check('orphelins : seul le brouillon de plus de 24 h est ajouté', b3.some(r => r.path === F.orphOld && r.reason === 'orphan') && !b3.some(r => r.path === F.orph));

  check('confirmation sans copie : fichier privé absent', (await one(`select media_migrate_confirm('${F.rem}') r`)).r === 'missing_destination');
  await fails('confirmation : fichier hors file refusé', `select media_migrate_confirm('${F.pub}')`, /absent de la file/);
  await obj('post-media-private', F.rem); await obj('post-media-private', F.hid, 999); await obj('post-media-private', F.com); await obj('post-media-private', F.stExp);
  check('confirmation : copie conforme => verified', (await one(`select media_migrate_confirm('${F.rem}') r`)).r === 'verified');
  check('confirmation : taille différente => failed (pas verified)', (await one(`select media_migrate_confirm('${F.hid}') r`)).r === 'failed');
  check('confirmation : rejeu idempotent', (await one(`select media_migrate_confirm('${F.rem}') r`)).r === 'verified');
  await q(`select media_migrate_confirm('${F.com}'), media_migrate_confirm('${F.stExp}')`);
  check('vérifié : post_media.storage_bucket mis à jour', (await sudo(`select storage_bucket b from post_media where path = '${F.rem}'`))[0].b === 'post-media-private' && (await sudo(`select storage_bucket b from post_media where path = '${F.hid}'`))[0].b === 'post-media');
  check('vérifié : l\'ancien fichier existe toujours (aucune suppression)', await nPublic() === pub0);
  check('vérifié : la cible renvoie le compartiment privé', (await sudo(`select post_media_signed_target('${F.rem}') r`))[0].r.signed === true && (await sudo(`select post_media_signed_target('${F.hid}') r`))[0].r.signed === false);
  const del = await q(`select * from media_old_deletion_candidates()`);
  check('suppressions possibles : seulement vérifié + non réversible (retirée, histoire expirée)', JSON.stringify(del.map(r => r.path).sort()) === JSON.stringify([F.rem, F.stExp].sort()), JSON.stringify(del));
  check('suppressions possibles : liste en lecture seule, fichiers intacts', await nPublic() === pub0);
  const delAll = await q(`select * from media_old_deletion_candidates(true)`);
  check('suppressions possibles (réversibles incluses) : + communauté fermée, sans le fichier en échec', delAll.length === 3 && delAll.some(r => r.path === F.com) && !delAll.some(r => r.path === F.hid));
  await sudo(`update communities set privacy = 'public' where id = '${closed}'`);
  await svc();
  check('contenu redevenu public : plus proposé à la suppression', !(await q(`select * from media_old_deletion_candidates(true)`)).some(r => r.path === F.com));
  await sudo(`update communities set privacy = 'invite' where id = '${closed}'`);
  await svc();
  const rep1 = (await one(`select media_migration_report() r`)).r;
  check('rapport après bascule : vérifiés, en échec, en file, privés, supprimables', rep1.verified === 3 && rep1.failed === 1 && rep1.private_bucket_objects === priv0 + 4 && rep1.old_deletable === 2, JSON.stringify(rep1));
  check('rapport : les 4 fichiers restent exposés tant que l\'ancien n\'est pas supprimé à la main', rep1.still_exposed_by_public_url === 4);

  // retour arrière
  check('retour arrière d\'un fichier : annulé', (await one(`select media_migrate_rollback('${F.com}') r`)).r.rolled_back === 1);
  check('retour arrière : cible de nouveau publique, fichier privé conservé', (await sudo(`select post_media_signed_target('${F.com}') r`))[0].r.signed === false && await nPrivate() === priv0 + 4);
  check('retour arrière : storage_bucket rétabli, marque de suppression retirée', (await sudo(`select storage_bucket b from post_media where path = '${F.com}'`))[0].b === 'post-media' && (await sudo(`select old_delete_marked_at d from media_migration where path = '${F.com}'`))[0].d === null);
  check('retour arrière : la file ne remet pas un fichier annulé', !(await q(`select * from media_migrate_private_batch(100)`)).some(r => r.path === F.com));
  await fails('confirmation : refusée après annulation', `select media_migrate_confirm('${F.com}')`, /annulée/);
  await sudo(`delete from storage.objects where bucket_id = 'post-media' and name = '${F.rem}'`);
  await svc();
  await fails('retour arrière : refusé si l\'ancien fichier a été supprimé à la main', `select media_migrate_rollback('${F.rem}')`, /Ancien fichier absent/);
  const all = (await one(`select media_migrate_rollback() r`)).r;
  check('retour arrière global : ignore ce qui ne peut pas revenir', all.skipped === 1 && all.rolled_back >= 2, JSON.stringify(all));
  await as(ADM);
  await fails('administrateur (compte applicatif) : refusé, seule la clé de service exécute la bascule', `select media_migration_report()`, /permission denied/);

  // ================================================================ 6. rejeu des migrations
  await db.exec('reset role');
  const before = JSON.stringify({ m: await q(`select path, status, reason from media_migration order by path`), b: await q(`select id, public from storage.buckets where id like 'post-media%' order by id`), n: await q(`select count(*)::int n from storage.objects`) });
  for (const f of fs.readdirSync(path.join(repo, 'migrations')).filter(f => /^202611290101\d\d_h131_media/.test(f)).sort()) await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8'));
  const after = JSON.stringify({ m: await q(`select path, status, reason from media_migration order by path`), b: await q(`select id, public from storage.buckets where id like 'post-media%' order by id`), n: await q(`select count(*)::int n from storage.objects`) });
  check('rejeu : les 3 migrations se rejouent sans effet de bord (suivi, compartiments, objets inchangés)', before === after);
  check('rejeu : les 4 politiques du compartiment privé existent une seule fois', Number((await q(`select count(*)::int n from pg_policies where schemaname = 'storage' and policyname like 'médias privés : %'`))[0].n) === 4);
  console.log(`\nh131_media : ${ok} OK, ${ko} ECHEC`);
}
