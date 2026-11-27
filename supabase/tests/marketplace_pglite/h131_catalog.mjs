// Scénario PGlite du lot H13.1 CATALOGUE (variantes : image, prix, panier, commande). Aucune migration nouvelle : il prouve la chaîne serveur utilisée par
// l'application (stockage listing-images -> variant_upsert / variant_details_save -> listing_variants_public -> cart_check -> marketplace_checkout -> seller_orders / order_tracking) :
//  - dépôt dans le stockage réservé au propriétaire (dossier <vendeur>/<annonce>/variante-<horodatage>.<ext>), limites du compartiment (5 Mo, jpeg/png/webp), anonyme refusé ;
//  - chemin d'image d'un autre vendeur refusé (variant_upsert, variant_details_save), annulation atomique d'un upsert dont l'image est refusée ;
//  - remplacement et retrait d'image : le propriétaire seul peut supprimer l'ancien fichier (aucune orpheline laissée par l'application), lecture publique ;
//  - prix de la variante utilisé par cart_check et par la commande (le client n'envoie jamais de prix), variante inactive / épuisée / d'une autre annonce refusée,
//    deux variantes d'une même annonce dans une commande, rejeu d'une commande (clé d'idempotence), commande impayée invisible du vendeur puis visible une fois payée ;
//  - rejeu des migrations H13 sans effet.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_catalog.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000131${String(n).padStart(2, '0')}`;
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const qs = async (sql) => { const prev = cur; await sup(); try { return await q(sql); } finally { if (prev) await as(prev.uid, prev.role); } };

  await sup();
  await db.exec('grant all on storage.objects to authenticated; grant select on storage.objects to anon');
  const roles = { 1: 'student', 2: 'student', 3: 'client', 4: 'client' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h131c${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte H131 ${n}','${r}','h131c${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69131' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
  }
  for (const n of [1, 2]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${U(n)}'`);
  await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('00000000-0000-0000-0000-0000000131a1', '${U(1)}', 'Boutique Awa H131', 'boutique-awa-h131', 'active'), ('00000000-0000-0000-0000-0000000131b1', '${U(2)}', 'Boutique Biyo H131', 'boutique-biyo-h131', 'active')`);
  const SA = '00000000-0000-0000-0000-0000000131a1', SB = '00000000-0000-0000-0000-0000000131b1';
  const mk = async (seller, title, price, stock, shop) => (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) values ('${seller}', '${title}', 'Design', 'Maison', ${price}, ${stock}, 'approved', '{photo.jpg}', '${shop}') returning id`))[0].id;
  const LA = await mk(U(1), 'Robe H131', 8000, 40, SA);
  const LB = await mk(U(2), 'Sac H131', 12000, 10, SB);
  const items = (lid, vid, qty = 1, extra = {}) => ({ id: lid, qty, ...(vid ? { variant_id: vid } : {}), ...extra });
  const buy = (uid, its, key = null) => async () => { await as(uid); return q(`select marketplace_checkout('${JSON.stringify(its)}'::jsonb, false, 'Mobile Money', null, null, ${key ? `'${key}'` : 'null'}) r`); };
  const nOrders = async () => Number((await qs(`select count(*) c from orders`))[0].c);
  const lineOf = async (num) => qs(`select ol.unit_price, ol.qty, ol.variant_id from order_lines ol join orders o on o.id = ol.order_id where o.number = '${num}' order by ol.unit_price`);
  const stamp = () => String(Date.now() * 1000 + Math.floor(Math.random() * 1000));
  const imgA = (ext = 'jpg') => `${U(1)}/${LA}/variante-${stamp()}.${ext}`;

  // ============================================================ 1. stockage : propriétaire seul, limites du compartiment
  const bucket = (await qs(`select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'listing-images'`))[0];
  check('compartiment listing-images : lecture publique, 5 Mo, jpeg/png/webp seulement', bucket.public === true && Number(bucket.file_size_limit) === 5242880 && [...bucket.allowed_mime_types].sort().join() === 'image/jpeg,image/png,image/webp', JSON.stringify(bucket));
  const p1 = imgA('jpg');
  await as(U(1));
  await works('vendeur A : dépôt dans <vendeur>/<annonce>/variante-….jpg autorisé', `insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${p1}', '${U(1)}') returning name`, (r) => r.length === 1);
  await fails('vendeur A : dépôt dans le dossier du vendeur B refusé', `insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${U(2)}/${LB}/variante-1.jpg', '${U(1)}')`, /row-level security/i);
  await as(U(3));
  await fails('acheteur : dépôt dans le dossier d\'un vendeur refusé', `insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${U(1)}/${LA}/variante-2.jpg', '${U(3)}')`, /row-level security/i);
  await as(null, 'anon');
  await fails('anonyme : dépôt refusé', `insert into storage.objects (bucket_id, name) values ('listing-images', 'x/y/variante-3.jpg')`, /permission denied|row-level security/i);
  await works('anonyme : lecture publique du fichier déposé', `select name from storage.objects where bucket_id = 'listing-images' and name = '${p1}'`, (r) => r.length === 1);

  // ============================================================ 2. variantes : création avec image, association à la bonne variante
  let vS, vM, vL;
  await as(U(1));
  await works('vendeur A : variante S sans image ni prix propre', `select variant_upsert('${LA}', 'S', '{"taille":"S"}'::jsonb, null, 10, 2) r`, (r) => { vS = r[0].r.id; return r[0].r.image === null && r[0].r.price === null; });
  await works('vendeur A : variante M avec image (son dossier) et prix propre 9500 en une transaction', `select variant_upsert('${LA}', 'M', '{"taille":"M"}'::jsonb, null, 10, 2, null, 9500, false, '${p1}') r`, (r) => { vM = r[0].r.id; return r[0].r.image === p1 && r[0].r.price === 9500; });
  check('l\'image est associée à la variante M seulement (S sans image)', (await qs(`select (select image from listing_variants where id = '${vS}') s, (select image from listing_variants where id = '${vM}') m`)).every((x) => x.s === null && x.m === p1));
  await works('vendeur A : variante L épuisée', `select variant_upsert('${LA}', 'L', '{}'::jsonb, null, 0, 1) r`, (r) => { vL = r[0].r.id; return true; });

  // chemin d'un autre vendeur / invalide : refus, rien n'est créé (transaction unique)
  const nVar = async () => Number((await qs(`select count(*) c from listing_variants`))[0].c);
  const n0 = await nVar();
  const pB = `${U(2)}/${LB}/variante-9.jpg`;
  await qs(`insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${pB}', '${U(2)}')`);
  await as(U(1));
  await fails('vendeur A : image du dossier du vendeur B refusée (variant_upsert)', `select variant_upsert('${LA}', 'XL', '{}'::jsonb, null, 3, 1, null, null, false, '${pB}')`, /Image invalide/);
  check('upsert refusé : aucune variante XL créée (annulation atomique)', (await nVar()) === n0);
  await fails('vendeur A : image du vendeur B refusée (variant_details_save)', `select variant_details_save('${vM}', null, false, '${pB}')`, /Image invalide/);
  await fails('chemin hors format refusé (pas de dossier annonce imbriqué excessif)', `select variant_details_save('${vM}', null, false, '${U(1)}/a/b/c/d.jpg')`, /Image invalide/);
  await fails('extension svg refusée', `select variant_details_save('${vM}', null, false, '${U(1)}/${LA}/variante-1.svg')`, /Image invalide/);
  await fails('fichier jamais déposé refusé', `select variant_details_save('${vM}', null, false, '${U(1)}/${LA}/variante-absente.png')`, /Image introuvable/);
  await as(U(2));
  await fails('vendeur B : image de la variante de A refusée (annonce d\'autrui)', `select variant_details_save('${vM}', null, false, '${pB}')`, /Annonce introuvable/);
  await as(U(3));
  await fails('acheteur : image d\'une variante refusée', `select variant_details_save('${vM}', null, false, '${p1}')`, /Annonce introuvable|Réservé aux étudiants/);
  await fails('acheteur : écriture directe de l\'image refusée', `update listing_variants set image = '${p1}' where id = '${vM}'`, /permission denied/i);

  // ============================================================ 3. remplacement et retrait : le propriétaire supprime l'ancien fichier, personne d'autre
  const p2 = imgA('png');
  await as(U(1));
  await q(`insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${p2}', '${U(1)}')`);
  await works('remplacement : la variante M pointe vers la nouvelle image', `select variant_details_save('${vM}', null, false, '${p2}') r`, (r) => r[0].r.image === p2 && r[0].r.price === 9500);
  await as(U(2));
  await works('vendeur B : suppression de l\'ancien fichier de A sans effet (aucune ligne)', `delete from storage.objects where bucket_id = 'listing-images' and name = '${p1}' returning name`, (r) => r.length === 0);
  await as(U(1));
  await works('vendeur A : suppression de l\'ancien fichier (aucune orpheline)', `delete from storage.objects where bucket_id = 'listing-images' and name = '${p1}' returning name`, (r) => r.length === 1);
  check('aucune variante ne référence plus l\'ancien fichier', (await qs(`select count(*) c from listing_variants where image = '${p1}'`))[0].c == 0);
  check('aucun fichier variante du vendeur A n\'est orphelin (chaque fichier est référencé)', (await qs(`select count(*) c from storage.objects o where o.bucket_id = 'listing-images' and o.name like '${U(1)}/%' and not exists (select 1 from listing_variants v where v.image = o.name)`))[0].c == 0);
  await works('retrait : p_clear_image vide l\'image', `select variant_details_save('${vM}', null, false, null, true) r`, (r) => r[0].r.image === null);
  await fails('image et retrait ensemble refusés', `select variant_details_save('${vM}', null, false, '${p2}', true)`, /pas les deux/);
  await works('vendeur A : suppression du fichier retiré', `delete from storage.objects where bucket_id = 'listing-images' and name = '${p2}' returning name`, (r) => r.length === 1);
  await q(`insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${p1}', '${U(1)}')`);
  await q(`select variant_details_save('${vM}', null, false, '${p1}')`);
  await as(null, 'anon');
  await works('acheteur anonyme : la lecture publique des variantes donne image, prix propre et prix effectif, jamais le stock exact', `select listing_variants_public('${LA}') r`,
    (r) => { const m = r[0].r.find((v) => v.label === 'M'), s = r[0].r.find((v) => v.label === 'S'); return m.image === p1 && m.price === 9500 && m.effective_price === 9500 && s.image === null && s.price === null && s.effective_price === 8000 && m.stock === undefined && s.stock === undefined; });

  // ============================================================ 4. panier : cart_check lit le prix de la variante, nomme les lignes refusées
  await as(U(3));
  const ck = (await q(`select cart_check('${JSON.stringify([items(LA, vM, 2), items(LA, vS, 1)])}'::jsonb) r`))[0].r;
  check('cart_check : prix unitaire de M = 9500 (variante), de S = 8000 (annonce), boutique nommée', ck.ok === true && ck.lines[0].unit_price === 9500 && ck.lines[1].unit_price === 8000 && ck.lines[0].shop === 'Boutique Awa H131', JSON.stringify(ck));
  const ck2 = (await q(`select cart_check('${JSON.stringify([items(LA, vM, 11), items(LA, vL, 1), items(LB, vS, 1)])}'::jsonb) r`))[0].r;
  check('cart_check : stock insuffisant -> out_of_stock avec la quantité disponible (10), nom de la variante', ck2.ok === false && ck2.lines[0].code === 'out_of_stock' && ck2.lines[0].available === 10 && /M/.test(ck2.lines[0].message), JSON.stringify(ck2.lines[0]));
  check('cart_check : variante épuisée refusée (L)', ck2.lines[1].ok === false && ck2.lines[1].code === 'out_of_stock' && ck2.lines[1].available === 0, JSON.stringify(ck2.lines[1]));
  check('cart_check : variante d\'une autre annonce refusée (variant_unavailable)', ck2.lines[2].ok === false && ck2.lines[2].code === 'variant_unavailable', JSON.stringify(ck2.lines[2]));
  const ck3 = (await q(`select cart_check('${JSON.stringify([items(LA, null, 1)])}'::jsonb) r`))[0].r;
  check('cart_check : annonce à variantes sans variant_id -> variant_required', ck3.ok === false && ck3.lines[0].code === 'variant_required', JSON.stringify(ck3.lines[0]));

  // ============================================================ 5. commande : prix de la variante, jamais le prix du client
  const nBefore = await nOrders();
  const o1 = (await buy(U(3), [items(LA, vM, 2), items(LA, vS, 1)])())[0].r;
  const l1 = await lineOf(o1.number);
  check('commande : deux variantes d\'une même annonce = deux lignes (S 8000, M 9500 x2)', l1.length === 2 && l1[0].unit_price === 8000 && l1[1].unit_price === 9500 && l1[1].qty === 2 && l1[1].variant_id === vM, JSON.stringify(l1));
  check('commande : sous-total = 2 x 9500 + 8000 = 27000 (prix de la variante)', o1.subtotal === 27000, JSON.stringify(o1));
  const o2 = (await buy(U(3), [items(LA, vM, 1, { price: 1, unit_price: 1 })])())[0].r;
  check('un prix envoyé par le client est ignoré (M = 9500)', o2.subtotal === 9500, JSON.stringify(o2));
  await as(U(1));
  await q(`select variant_details_save('${vM}', 7000)`);
  check('prix modifié : la commande passée garde son prix (27000)', (await qs(`select subtotal from orders where number = '${o1.number}'`))[0].subtotal === 27000);
  const o3 = (await buy(U(4), [items(LA, vM, 1)])())[0].r;
  check('prix modifié : la nouvelle commande suit le nouveau prix (7000)', o3.subtotal === 7000, JSON.stringify(o3));
  await as(U(1));
  await q(`select variant_details_save('${vM}', 9500)`);
  await as(U(3));
  await fails('variante épuisée refusée à la commande', `select marketplace_checkout('${JSON.stringify([items(LA, vL, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_out_of_stock/);
  await fails('quantité au-delà du stock refusée à la commande', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 50)])}'::jsonb, false, 'Mobile Money')`, /variant_out_of_stock|Quantité invalide|Stock insuffisant/);
  await fails('variante d\'une autre annonce refusée à la commande', `select marketplace_checkout('${JSON.stringify([items(LB, vM, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_unavailable/);
  await as(U(1));
  await q(`select variant_set_active('${vS}', false)`);
  await as(U(3));
  await fails('variante inactive refusée à la commande', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_unavailable/);
  const ck4 = (await q(`select cart_check('${JSON.stringify([items(LA, vS, 1)])}'::jsonb) r`))[0].r;
  check('variante inactive : cart_check la refuse (variant_unavailable)', ck4.ok === false && ck4.lines[0].code === 'variant_unavailable', JSON.stringify(ck4.lines[0]));
  await as(null, 'anon');
  await works('variante inactive : absente de la lecture publique', `select listing_variants_public('${LA}') r`, (r) => !r[0].r.some((v) => v.label === 'S'));
  await as(U(1));
  await q(`select variant_set_active('${vS}', true)`);

  // rejeu : même clé d'idempotence = même commande
  const nKey0 = await nOrders();
  const k1 = (await buy(U(4), [items(LA, vM, 1)], 'h131-cle-0001')())[0].r;
  const k2 = (await buy(U(4), [items(LA, vM, 1)], 'h131-cle-0001')())[0].r;
  check('rejeu (même clé) : même numéro, marqué rejoué, une seule commande créée', k1.number === k2.number && k2.replayed === true && (await nOrders()) === nKey0 + 1, JSON.stringify([k1, k2]));
  check('rejeu : stock de M décrémenté une seule fois', Number((await qs(`select stock from listing_variants where id = '${vM}'`))[0].stock) === 10 - 2 - 1 - 1 - 1, String((await qs(`select stock from listing_variants where id = '${vM}'`))[0].stock));

  // ============================================================ 6. cohérence commande impayée -> payée : vendeur, suivi acheteur
  await as(U(1));
  const so0 = (await q(`select * from seller_orders()`));
  check('vendeur : une commande impayée n\'est pas présentée comme à préparer', !so0.some((x) => x.number === o1.number), JSON.stringify(so0.map((x) => x.number)));
  await as(U(3));
  const t0 = (await q(`select order_tracking('${o1.number}') r`))[0].r;
  check('suivi acheteur : commande impayée = état d\'attente de paiement, pas « confirmée »', t0.paid === false && t0.payment === 'unpaid' && t0.state === 'awaiting_payment', JSON.stringify([t0.state, t0.payment]));
  await qs(`update orders set paid = true where number = '${o1.number}'`);
  await as(U(1));
  const so1 = (await q(`select * from seller_orders()`));
  check('vendeur : une fois payée, la commande apparaît', so1.some((x) => x.number === o1.number), JSON.stringify(so1.map((x) => x.number)));
  await as(U(3));
  const t1 = (await q(`select order_tracking('${o1.number}') r`))[0].r;
  check('suivi acheteur : payée seulement après le paiement serveur', t1.paid === true && t1.payment === 'paid' && t1.state !== 'awaiting_payment', JSON.stringify([t1.state, t1.payment]));
  await as(U(4));
  await fails('autre acheteur : suivi de la commande d\'autrui refusé', `select order_tracking('${o1.number}')`, /introuvable|non autorisée/i);

  // ============================================================ 7. rejeu des migrations H13 : aucun effet
  const snap = async () => JSON.stringify(await qs(`select (select count(*) from orders) o, (select count(*) from order_lines) l, (select count(*) from listing_variants) v, (select coalesce(sum(stock),0) from listing_variants) s, (select count(*) from storage.objects) f`));
  const s0 = await snap();
  const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  for (const f of fs.readdirSync(path.join(repo, 'migrations')).filter((x) => x.startsWith('2026112803') && x.includes('h13'))) {
    try { await sup(); await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); check(`rejeu de ${f} sans erreur`, true); } catch (e) { check(`rejeu de ${f} sans erreur`, false, e.message); }
  }
  check('rejeu : aucune donnée modifiée', (await snap()) === s0);
  await as(U(3));
  await works('après rejeu : la commande fonctionne (prix de la variante)', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 1)])}'::jsonb, false, 'Mobile Money') r`, (r) => r[0].r.subtotal === 9500);

  await sup();
  console.log(`\nH13.1 CATALOGUE : ${ok} OK / ${ko} ECHEC`);
}
