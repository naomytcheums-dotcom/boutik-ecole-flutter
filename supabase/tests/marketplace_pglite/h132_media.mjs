// Scénario PGlite H13.2 · MÉDIAS : inventaire par objet de « post-media » et confirmation vérifiée (SHA-256) de la bascule.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_media.mjs   (compter les lignes ECHEC / ERREUR)
// Reproduit la forme de l'état de production lu par le chef : 17 objets = 13 publics, 1 en attente de validation, 1 histoire expirée, 2 orphelins.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000132${String(n).padStart(2, '0')}`;
  let cur = { uid: null, role: 'authenticated' };
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '${role === 'service_role' ? 'service_role' : 'authenticated'}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sudo = async (sql) => { const save = cur; await as(null, null); try { try { return await q(sql); } catch (e) { if (!/multiple commands/.test(e.message)) throw e; await db.exec(sql); return []; } } finally { await as(save.uid, save.role); } };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const one = async (sql) => (await q(sql))[0];
  const A = U(1), B = U(2);
  const SHA = 'a'.repeat(64);

  await db.exec('reset role');
  for (const [n, r] of [[1, 'student'], [2, 'client']]) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h132m${n}@t.cm'); insert into profiles(id,name,role,email,created_at) values ('${U(n)}','Membre H132 ${n}','${r}','h132m${n}@t.cm', now() - interval '5 days')`);
  const obj = (bucket, name, size, mime = 'image/jpeg', created = `now() - interval '3 days'`) => sudo(`insert into storage.objects (bucket_id, name, metadata, created_at) values ('${bucket}', '${name}', '{"size": ${size}, "mimetype": "${mime}"}'::jsonb, ${created})`);
  const mkPost = async (status, body) => (await sudo(`insert into posts (author_id, kind, body, caption, status, published_at) values ('${A}', 'text', $$${body}$$, $$${body}$$, '${status}', now()) returning id`))[0].id;

  // 13 publics : 10 médias de publications publiées, 1 couverture de profil, 1 couverture d'organisation (profiles.cover_path), 1 couverture de live non testée ici -> 3e média de publication
  for (let i = 0; i < 11; i++) { const pub = await mkPost('published', 'Publication publiée ' + i); const p = `${A}/pub${i}.${i % 2 ? 'mp4' : 'jpg'}`; await obj('post-media', p, 1000 + i, i % 2 ? 'video/mp4' : 'image/jpeg'); await sudo(`insert into post_media (post_id, path, kind, pos) values ('${pub}', '${p}', '${i % 2 ? 'video' : 'image'}', 0)`); }
  await obj('post-media', `${A}/cover.jpg`, 500); await sudo(`update profiles set cover_path = '${A}/cover.jpg' where id = '${A}'`);
  await obj('post-media', `${A}/cover2.png`, 600, 'image/png'); const pub2 = await mkPost('published', 'Publication couverture'); await sudo(`insert into post_media (post_id, path, kind, pos) values ('${pub2}', '${A}/cover2.png', 'image', 0)`);
  // 1 en attente de validation
  const pend = await mkPost('pending', 'Publication en attente');
  await obj('post-media', `${A}/pend.jpg`, 700); await sudo(`insert into post_media (post_id, path, kind, pos) values ('${pend}', '${A}/pend.jpg', 'image', 0)`);
  // 1 histoire expirée
  await obj('post-media', `${A}/story.jpg`, 800);
  await sudo(`insert into stories (author_id, media_path, media_kind) values ('${A}', '${A}/story.jpg', 'image')`);
  await sudo(`update stories set expires_at = now() - interval '2 hours' where media_path = '${A}/story.jpg'`);
  // 2 orphelins (jamais rattachés)
  await obj('post-media', `${A}/orphan1.jpg`, 900); await obj('post-media', `${A}/orphan2.png`, 910, 'image/png');
  const total = (await sudo(`select count(*)::int n from storage.objects where bucket_id = 'post-media'`))[0].n;
  check('fixture : 17 objets dans post-media', total === 17, String(total));
  const svc = async () => as(null, 'service_role');

  // ---- droits
  for (const [who, uid, role] of [['client', B, 'authenticated'], ['etudiant', A, 'authenticated'], ['anonyme', null, 'anon']]) {
    await as(uid, role);
    await fails(`droits : ${who} ne lit pas l inventaire`, `select * from media_inventory_objects()`, /permission denied/);
    await fails(`droits : ${who} ne lit pas les compartiments`, `select media_inventory_buckets()`, /permission denied/);
    await fails(`droits : ${who} ne confirme pas`, `select media_migrate_confirm_checked('${A}/story.jpg', '${SHA}', 800)`, /permission denied/);
  }

  // ---- inventaire par objet
  await svc();
  const inv = await q(`select * from media_inventory_objects(null, 1000)`);
  const by = (k) => inv.filter((r) => r.state === k);
  check('inventaire : 17 objets, 13 publics, 1 en attente, 1 restreint (histoire expirée), 2 non rattachés', inv.length === 17 && by('public').length === 13 && by('pending').length === 1 && by('restricted').length === 1 && by('unreferenced').length === 2,
    JSON.stringify(inv.reduce((a, r) => (a[r.state] = (a[r.state] || 0) + 1, a), {})));
  const story = inv.find((r) => r.path === `${A}/story.jpg`);
  check('inventaire : histoire expirée = restricted / story / story_expired, taille et type conservés', story.state === 'restricted' && story.reference_kind === 'story' && story.reason === 'story_expired' && story.reversible === false && Number(story.size_bytes) === 800 && story.mimetype === 'image/jpeg', JSON.stringify(story));
  const orph = inv.find((r) => r.path === `${A}/orphan2.png`);
  check('inventaire : orphelin = unreferenced / none / orphan, type png', orph.state === 'unreferenced' && orph.reference_kind === 'none' && orph.reason === 'orphan' && orph.mimetype === 'image/png');
  check('inventaire : couverture de profil identifiée', inv.find((r) => r.path === `${A}/cover.jpg`).reference_kind === 'profile_cover');
  check('inventaire : vidéo de publication identifiée', inv.find((r) => r.path === `${A}/pub1.mp4`).mimetype === 'video/mp4' && inv.find((r) => r.path === `${A}/pub1.mp4`).reference_kind === 'post_media');
  check('inventaire : aucune copie privée ni bascule au départ', inv.every((r) => r.in_private === false && r.migration_status === null));
  check('inventaire : les contenus publics n ont aucun motif de restriction', by('public').every((r) => r.reason === null));
  const p1 = await q(`select path from media_inventory_objects(null, 5)`), p2 = await q(`select path from media_inventory_objects('${p1[4].path}', 5)`);
  check('inventaire : pagination par nom sans doublon ni trou', p1.length === 5 && p2.length === 5 && p2[0].path > p1[4].path && new Set([...p1, ...p2].map((r) => r.path)).size === 10);
  const bk = (await one(`select media_inventory_buckets() b`)).b;
  const bm = bk.find((b) => b.bucket === 'post-media');
  check('compartiments : post-media = 17 objets, octets cumules, public', bm.objects === 17 && Number(bm.bytes) > 15000 && bm.public === true, JSON.stringify(bm));
  check('compartiments : post-media-private existe, prive, vide', (() => { const x = bk.find((b) => b.bucket === 'post-media-private'); return x && x.public === false && x.objects === 0; })());

  // ---- confirmation vérifiée
  await svc();
  const before = total;
  const queue = await q(`select * from media_migrate_private_batch(50, true)`);
  check('file : histoire expirée et 2 orphelins (orphelins de plus de 24 h)', queue.length === 3, JSON.stringify(queue.map((r) => r.reason)));
  await fails('confirmation : empreinte invalide refusée', `select media_migrate_confirm_checked('${A}/story.jpg', 'xyz', 800)`, /Empreinte SHA-256 invalide/);
  await fails('confirmation : empreinte NULL refusée', `select media_migrate_confirm_checked('${A}/story.jpg', null, 800)`, /Empreinte SHA-256 invalide/);
  await fails('confirmation : empreinte en majuscules refusée (forme canonique)', `select media_migrate_confirm_checked('${A}/story.jpg', '${SHA.toUpperCase()}', 800)`, /Empreinte SHA-256 invalide/);
  check('confirmation sans copie : missing_destination, aucune référence modifiée', (await one(`select media_migrate_confirm_checked('${A}/story.jpg', '${SHA}', 800) r`)).r === 'missing_destination');
  await sudo(`insert into storage.objects (bucket_id, name, metadata) values ('post-media-private', '${A}/story.jpg', '{"size": 801, "mimetype": "image/jpeg"}'::jsonb)`);
  await svc();
  check('confirmation : taille de la copie differente -> failed', (await one(`select media_migrate_confirm_checked('${A}/story.jpg', '${SHA}', 800) r`)).r === 'failed');
  check('confirmation echouee : aucune empreinte enregistree, statut failed', (await sudo(`select status, sha256 from media_migration where path = '${A}/story.jpg'`))[0].status === 'failed');
  await sudo(`update storage.objects set metadata = '{"size": 800, "mimetype": "image/jpeg"}'::jsonb where bucket_id = 'post-media-private' and name = '${A}/story.jpg'`);
  await svc();
  check('confirmation : copie identique -> verified', (await one(`select media_migrate_confirm_checked('${A}/story.jpg', '${SHA}', 800) r`)).r === 'verified');
  const m = (await sudo(`select status, sha256, verified_size, old_delete_marked_at is not null marked from media_migration where path = '${A}/story.jpg'`))[0];
  check('confirmation : empreinte et taille enregistrees, ancien fichier seulement marque', m.status === 'verified' && m.sha256 === SHA && Number(m.verified_size) === 800 && m.marked === true);
  const inv2 = (await q(`select in_private, migration_status from media_inventory_objects(null, 1000) where path = '${A}/story.jpg'`))[0];
  check('inventaire apres bascule : copie privee presente et statut verified', inv2.in_private === true && inv2.migration_status === 'verified');
  check('RIEN n a ete supprime de post-media', (await sudo(`select count(*)::int n from storage.objects where bucket_id = 'post-media'`))[0].n === before);
  check('les 13 contenus publics et l attente de validation ne sont jamais en file', (await sudo(`select count(*)::int n from media_migration where path in (select path from post_media where post_id in (select id from posts where status in ('published', 'pending')))`))[0].n === 0);

  // ---- rejeu
  const mig = fs.readFileSync(path.join(repo, 'migrations', '20261130060200_h132_media_inventaire_verifie.sql'), 'utf8');
  await db.exec('reset role');
  let rej = true; try { await db.exec(mig); await db.exec(mig); } catch (e) { rej = false; console.log(e.message); }
  check('migration rejouee deux fois sans erreur', rej);
  await svc();
  check('apres rejeu : empreinte conservee', (await sudo(`select sha256 from media_migration where path = '${A}/story.jpg'`))[0].sha256 === SHA);
  console.log(`h132_media : ${ok} OK, ${ko} ECHEC`);
}
