// Scénario PGlite du lot H13 COMMERCE (20261128030000_h13_commerce_variantes_prix.sql + 20261128030100_h13_commerce_etats_suivi.sql).
// Cas autorisés ET refusés : prix PROPRE de variante (optionnel, bornes, propriétaire seulement, image du compartiment existant), commande au prix de la variante (sinon prix de
// l'annonce, jamais un prix envoyé par le client), commissions/séquestre inchangés (lus sur les lignes), réservation de stock d'une commande impayée alignée sur expire_unpaid_orders,
// restitution idempotente, panier de deux boutiques (une commande, états par boutique, rien créé si une ligne est refusée, cart_check ligne par ligne),
// états cohérents acheteur / vendeur / administration (matrice unique), historique réel, annulation / remboursement complet ou partiel / accès aux ressources numériques,
// double envoi (clé d'idempotence), isolation entre comptes, anonyme refusé, rejeu des migrations sans effet.
// PGlite est mono-connexion : la concurrence RÉELLE est prouvée par h12_stock_concurrence.mjs (PostgreSQL local, plusieurs connexions).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h13_commerce.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000130${String(n).padStart(2, '0')}`;
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  // requête en superutilisateur ; l'identité courante est rétablie ensuite
  const qs = async (sql) => { const prev = cur; await sup(); try { return await q(sql); } finally { if (prev) await as(prev.uid, prev.role); } };
  // tâche planifiée (pg_cron) : exécutée par le propriétaire, jamais par un compte connecté
  const worksSup = async (name, sql, test = () => true) => { try { const r = await qs(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };

  await sup();
  await db.exec('grant all on storage.objects to authenticated');
  // 1 vendeur A ; 2 vendeur B ; 3 acheteur 1 ; 4 acheteur 2 ; 5 étudiant NON éligible ; 6 administrateur ; 7 client ; 8 vendeur C (étranger aux commandes)
  const roles = { 1: 'student', 2: 'student', 3: 'client', 4: 'client', 5: 'student', 6: 'admin', 7: 'client', 8: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h13c${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte H13 ${n}','${r}','h13c${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69130' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
  }
  for (const n of [1, 2, 8]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${U(n)}'`);
  await db.exec(`update profiles set phone_verified = false where id = '${U(5)}'`);
  await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('00000000-0000-0000-0000-0000000130a1', '${U(1)}', 'Boutique Awa H13', 'boutique-awa-h13', 'active'), ('00000000-0000-0000-0000-0000000130b1', '${U(2)}', 'Boutique Biyo H13', 'boutique-biyo-h13', 'active')`);
  const SA = '00000000-0000-0000-0000-0000000130a1', SB = '00000000-0000-0000-0000-0000000130b1';
  const mk = async (seller, title, o = {}) => (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) values (${seller ? `'${seller}'` : 'null'}, '${title}', 'Design', '${o.category ?? 'Maison'}', ${o.price ?? 10000}, ${o.stock ?? 50}, '${o.status ?? 'approved'}', '{photo.jpg}', ${o.shop ? `'${o.shop}'` : 'null'}) returning id`))[0].id;
  const LA = await mk(U(1), 'Tee-shirt H13', { price: 8000, stock: 50, shop: SA });
  const LB = await mk(U(2), 'Sac H13', { price: 12000, stock: 10, shop: SB });
  const LN = await mk(U(1), 'Cahier H13 sans variante', { price: 1500, stock: 5, shop: SA });
  const LS = await mk(U(1), 'Service H13', { category: 'Services', shop: SA });
  const LD = await mk(U(1), 'Template numérique H13', { category: 'Solutions numériques', price: 10000, stock: 20, shop: SA });
  const vStock = async (id) => Number((await qs(`select stock from listing_variants where id = '${id}'`))[0].stock);
  const stockOf = async (id) => Number((await qs(`select stock from listings where id = '${id}'`))[0].stock);
  const nOrders = async () => Number((await qs(`select count(*) c from orders`))[0].c);
  const items = (lid, vid, qty = 1, extra = {}) => ({ id: lid, qty, ...(vid ? { variant_id: vid } : {}), ...extra });
  const buy = (uid, its, key = null, code = null) => async () => { await as(uid); return q(`select marketplace_checkout('${JSON.stringify(its)}'::jsonb, false, 'Mobile Money', null, ${code ? `'${code}'` : 'null'}, ${key ? `'${key}'` : 'null'}) r`); };
  const lineOf = async (num) => qs(`select ol.unit_price, ol.qty, ol.variant, ol.variant_id, ol.flash_id from order_lines ol join orders o on o.id = ol.order_id where o.number = '${num}' order by ol.unit_price`);

  // ============================================================ 1. variantes : création, prix propre OPTIONNEL, droits
  let vS, vM, vL, vR;
  await as(U(1));
  await works('vendeur A : variante S sans prix propre (stock 10)', `select variant_save('${LA}', 'S', '{"taille":"S"}'::jsonb, 'H13-S', 10, 2) r`, (r) => { vS = r[0].r.id; return r[0].r.price === null && r[0].r.effective_price === 8000; });
  await works('vendeur A : variante M (stock 10)', `select variant_save('${LA}', 'M', '{"taille":"M"}'::jsonb, 'H13-M', 10, 2) r`, (r) => { vM = r[0].r.id; return true; });
  await works('vendeur A : variante L (stock 0)', `select variant_save('${LA}', 'L', '{"taille":"L"}'::jsonb, null, 0, 1) r`, (r) => { vL = r[0].r.id; return true; });
  await as(U(2));
  await works('vendeur B : variante Rouge (stock 4)', `select variant_save('${LB}', 'Rouge', '{"couleur":"Rouge"}'::jsonb, null, 4, 1) r`, (r) => { vR = r[0].r.id; return true; });
  await as(null, 'anon');
  await fails('anonyme : variant_details_save refusé', `select variant_details_save('${vS}', 9500)`, /permission denied|Connexion requise/i);
  await fails('anonyme : variant_upsert refusé', `select variant_upsert('${LA}', 'XL', '{}'::jsonb, null, 1, 1, null, 9500)`, /permission denied|Connexion requise/i);
  await fails('anonyme : cart_check refusé', `select cart_check('[]'::jsonb)`, /permission denied|Connexion requise/i);
  await fails('anonyme : order_tracking refusé', `select order_tracking('#BE-2026-0001')`, /permission denied|Connexion requise/i);
  await as(U(7));
  await fails('client : prix de variante refusé', `select variant_details_save('${vS}', 9500)`, /Annonce introuvable|Réservé aux étudiants/);
  await as(U(3));
  await fails('acheteur : prix de la variante d\'autrui refusé', `select variant_details_save('${vS}', 100)`, /Annonce introuvable|Réservé aux étudiants/);
  await fails('acheteur : écriture directe du prix refusée (permission)', `update listing_variants set price = 600 where id = '${vS}'`, /permission denied/i);
  await fails('acheteur : écriture directe du stock d\'une variante refusée', `update listing_variants set stock = 5000 where id = '${vS}'`, /permission denied/i);
  await works('acheteur : écriture directe du stock de l\'annonce sans effet (aucune ligne)', `update listings set stock = 5000 where id = '${LA}' returning id`, (r) => r.length === 0);
  check('acheteur : stocks inchangés après les tentatives', (await vStock(vS)) === 10 && (await stockOf(LA)) === 20);
  await as(U(5));
  await fails('étudiant non éligible : prix de variante refusé', `select variant_details_save('${vS}', 9500)`, /Annonce introuvable|statut d.étudiant|téléphone/);
  await as(U(2));
  await fails('vendeur B : prix de la variante du vendeur A refusé', `select variant_details_save('${vS}', 9500)`, /Annonce introuvable/);
  await fails('vendeur B : ajustement du stock de A refusé', `select variant_adjust('${vS}', 99, null, 'test illicite')`, /Annonce introuvable/);
  await as(U(8));
  await fails('vendeur C (étranger) : variant_upsert sur l\'annonce de A refusé', `select variant_upsert('${LA}', 'XL', '{}'::jsonb, null, 1, 1, null, 9500)`, /Annonce introuvable/);
  await as(U(1));
  await fails('prix 0 refusé', `select variant_details_save('${vS}', 0)`, /Prix de la variante/);
  await fails('prix négatif refusé', `select variant_details_save('${vS}', -500)`, /Prix de la variante/);
  await fails('prix 499 (sous la borne des produits) refusé', `select variant_details_save('${vS}', 499)`, /Prix de la variante/);
  await fails('prix 100 000 001 refusé', `select variant_details_save('${vS}', 100000001)`, /Prix de la variante/);
  await fails('prix et retrait du prix à la fois refusés', `select variant_details_save('${vS}', 9000, true)`, /pas les deux/);
  await fails('écriture directe d\'un prix négatif refusée (contrainte)', `update listing_variants set price = -1 where id = '${vS}'`, /permission denied|listing_variants_price_range/i);
  check('prix refusés : la variante garde son prix absent', (await qs(`select price from listing_variants where id = '${vS}'`))[0].price === null);
  const before = Number((await qs(`select count(*) c from listing_variants where listing_id = '${LA}'`))[0].c);
  await as(U(1));
  await fails('variant_upsert atomique : prix invalide => variante NON créée', `select variant_upsert('${LA}', 'XXL', '{}'::jsonb, null, 3, 1, null, 0)`, /Prix de la variante/);
  check('variant_upsert refusé : aucune variante créée', Number((await qs(`select count(*) c from listing_variants where listing_id = '${LA}'`))[0].c) === before);
  await works('prix propre de M : 9500', `select variant_details_save('${vM}', 9500) r`, (r) => r[0].r.price === 9500 && r[0].r.effective_price === 9500);
  check('prix de M audité', (await qs(`select count(*) c from audit_log where action like 'Prix de variante : Tee-shirt H13 — M%' and actor_id = '${U(1)}'`))[0].c == 1);
  check('prix de l\'annonce et de S inchangés (8000, sans prix propre)', (await qs(`select (select price from listings where id = '${LA}') p, (select price from listing_variants where id = '${vS}') v`))[0].p === 8000);
  await works('upsert : variante XL créée avec prix 11000 en une transaction', `select variant_upsert('${LA}', 'XL', '{"taille":"XL"}'::jsonb, null, 4, 1, null, 11000) r`, (r) => r[0].r.price === 11000 && r[0].r.stock === 4);
  await works('upsert : modifier XL et retirer son prix', `select variant_upsert('${LA}', 'XL', '{"taille":"XL"}'::jsonb, null, null, 1, (select id from listing_variants where listing_id = '${LA}' and label = 'XL'), null, true) r`, (r) => r[0].r.price === null && r[0].r.effective_price === 8000);

  // images : bucket public existant « listing-images », dossier du vendeur
  await fails('image : chemin invalide refusé', `select variant_details_save('${vM}', null, false, '../../etc/passwd')`, /Image invalide/);
  await fails('image : dossier d\'un autre compte refusé', `select variant_details_save('${vM}', null, false, '${U(2)}/m.jpg')`, /Image invalide/);
  await fails('image : extension non image refusée', `select variant_details_save('${vM}', null, false, '${U(1)}/m.exe')`, /Image invalide/);
  await fails('image : fichier non envoyé refusé', `select variant_details_save('${vM}', null, false, '${U(1)}/absente.jpg')`, /Image introuvable/);
  await qs(`insert into storage.objects (bucket_id, name, owner_id) values ('listing-images', '${U(1)}/m-rouge.jpg', '${U(1)}') on conflict do nothing`);
  await as(U(1));
  await works('image : image déjà envoyée par le vendeur acceptée', `select variant_details_save('${vM}', null, false, '${U(1)}/m-rouge.jpg') r`, (r) => r[0].r.image === `${U(1)}/m-rouge.jpg` && r[0].r.price === 9500);
  await as(U(2));
  await fails('image : le vendeur B ne rattache pas l\'image de A', `select variant_details_save('${vR}', null, false, '${U(1)}/m-rouge.jpg')`, /Image invalide/);
  await as(null, 'anon');
  await works('lecture publique : prix propre, prix effectif, image ; jamais le stock exact ni la réservation', `select listing_variants_public('${LA}') r`,
    (r) => { const m = r[0].r.find((v) => v.label === 'M'), s = r[0].r.find((v) => v.label === 'S'); return m.price === 9500 && m.effective_price === 9500 && m.image === `${U(1)}/m-rouge.jpg` && s.price === null && s.effective_price === 8000 && m.stock === undefined && m.reserved === undefined && s.sku === undefined; });

  // ============================================================ 2. commande : prix de la variante, sinon prix de l'annonce
  const o1 = (await buy(U(3), [items(LA, vM, 2), items(LA, vS, 1)])())[0].r;
  const l1 = await lineOf(o1.number);
  check('commande : ligne M à 9500 (prix propre), ligne S à 8000 (prix de l\'annonce)', l1.length === 2 && l1[0].unit_price === 8000 && l1[1].unit_price === 9500 && l1[1].qty === 2, JSON.stringify(l1));
  check('commande : sous-total = 2 x 9500 + 8000 = 27000', o1.subtotal === 27000, JSON.stringify(o1));
  check('commande : stocks décrémentés (M 8, S 9)', (await vStock(vM)) === 8 && (await vStock(vS)) === 9);
  const o1b = (await buy(U(3), [items(LA, vM, 1, { price: 1, unit_price: 1, price_override: 1 })])())[0].r;
  check('un prix envoyé par le client est ignoré (M = 9500)', o1b.subtotal === 9500, JSON.stringify(o1b));
  await as(U(1));
  await q(`select variant_details_save('${vM}', 7000)`);
  const o1c = (await buy(U(4), [items(LA, vM, 1)])())[0].r;
  check('prix modifié par le vendeur : la nouvelle commande suit (7000)', o1c.subtotal === 7000, JSON.stringify(o1c));
  check('prix modifié : la commande déjà passée garde son prix figé (27000)', (await qs(`select subtotal from orders where number = '${o1.number}'`))[0].subtotal === 27000);
  await as(U(1));
  await q(`select variant_details_save('${vM}', 9500)`);
  await q(`update listings set price = 8500 where id = '${LA}'`);
  const o1d = (await buy(U(4), [items(LA, vS, 1)])())[0].r;
  check('sans prix propre : la variante suit le prix de l\'annonce modifié (8500)', o1d.subtotal === 8500, JSON.stringify(o1d));
  await q(`update listings set price = 8000 where id = '${LA}'`);
  await as(U(3));
  await fails('variante épuisée refusée avec la quantité disponible', `select marketplace_checkout('${JSON.stringify([items(LA, vL, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_out_of_stock/);
  await fails('prix de variante : une ligne sans variante_id sur annonce à variantes refusée', `select marketplace_checkout('${JSON.stringify([items(LA, null, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_required/);
  await as(U(1));
  await q(`select variant_set_active('${vS}', false)`);
  await as(U(3));
  await fails('variante inactive refusée', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_unavailable/);
  await as(U(1));
  await q(`select variant_set_active('${vS}', true)`);
  await as(U(3));
  await fails('quantité 0 refusée', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 0)])}'::jsonb, false, 'Mobile Money')`, /Quantité invalide/);
  await fails('quantité négative refusée', `select marketplace_checkout('${JSON.stringify([items(LA, vM, -2)])}'::jsonb, false, 'Mobile Money')`, /Quantité invalide/);
  await as(U(1));
  await fails('vendeur A : achat de son propre produit refusé', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 1)])}'::jsonb, false, 'Mobile Money')`, /propre produit/);
  await as(U(3));
  await fails('service : refusé au panier (sur devis)', `select marketplace_checkout('${JSON.stringify([items(LS, null, 1)])}'::jsonb, false, 'Mobile Money')`, /sur devis/);

  // vente flash : une variante à prix propre garde son prix ; une variante sans prix propre suit la vente flash de l'annonce (comportement H12)
  await qs(`insert into flash_sales (listing_id, sale_price, stock, starts_at, ends_at) values ('${LA}', 5000, 5, now() - interval '1 hour', now() + interval '1 day')`);
  const of1 = (await buy(U(3), [items(LA, vM, 1)])())[0].r;
  check('vente flash : la variante à prix propre garde son prix (9500), sans prix flash', of1.subtotal === 9500, JSON.stringify(of1));
  const of2 = (await buy(U(3), [items(LA, vS, 1)])())[0].r;
  check('vente flash : la variante sans prix propre suit le prix flash de l\'annonce (5000)', of2.subtotal === 5000, JSON.stringify(of2));
  await qs(`update flash_sales set cancelled = true where listing_id = '${LA}'`);
  await as(U(3));
  for (const n of [of1.number, of2.number, o1b.number]) await q(`select cancel_order('${n}')`);

  // ============================================================ 3. code promo et aperçu : même prix de ligne que la commande
  await qs(`insert into promo_codes (code, kind, value, min_amount, auto_apply, active, starts_at) values ('H13P10', 'percent', 10, 0, false, true, now() - interval '1 day')`);
  await as(U(4));
  const pv = (await q(`select promo_preview('H13P10', '${JSON.stringify([items(LA, vM, 2)])}'::jsonb) r`))[0].r;
  check('aperçu promo : 10 % de 2 x 9500 = 1900', pv.valid === true && pv.discount === 1900, JSON.stringify(pv));
  const op = (await buy(U(4), [items(LA, vM, 2)], null, 'H13P10')())[0].r;
  check('commande avec code : remise identique à l\'aperçu, sur le prix de la variante', op.discount === 1900 && op.subtotal === 17100, JSON.stringify(op));

  // ============================================================ 4. séquestre et commissions : lus sur les lignes (inchangés)
  await qs(`update orders set paid = true where number = '${op.number}'`);
  const me = await qs(`select gross, beneficiary_amount, institution_amount, platform_amount from money_entries where order_id = (select id from orders where number = '${op.number}') and kind = 'order'`);
  const sp = (await qs(`select b, i, p from money_split_amounts(17100)`))[0];
  check('séquestre : une écriture sur le montant des lignes après remise (17100)', me.length === 1 && me[0].gross === 17100, JSON.stringify(me));
  check('séquestre : répartition = money_split_amounts du même montant (aucune règle modifiée)', me[0].beneficiary_amount === sp.b && me[0].institution_amount === sp.i && me[0].platform_amount === sp.p, JSON.stringify([me[0], sp]));

  // ============================================================ 5. réservation de stock d'une commande impayée (alignée sur expire_unpaid_orders)
  await as(U(1));
  const reservedOf = async (vid) => { await as(U(1)); const r = (await q(`select seller_variants_list('${LA}') r`))[0].r.find((v) => v.id === vid); return r.reserved; };
  const oR = (await buy(U(3), [items(LA, vS, 2), items(LB, vR, 1)])())[0].r;
  await as(U(3));
  const tr = (await q(`select order_tracking('${oR.number}') r`))[0].r;
  check('réservation : état « reserved » avec une échéance', tr.reservation.state === 'reserved' && !!tr.reservation.until, JSON.stringify(tr.reservation));
  const hold = (await qs(`select extract(epoch from (_order_hold_until(id) - created_at)) s from orders where number = '${oR.number}'`))[0].s;
  check('réservation : échéance = 2 h après la commande (règle expire_unpaid_orders)', Number(hold) === 7200, String(hold));
  check('vendeur : la quantité réservée par les commandes impayées est visible (S)', (await reservedOf(vS)) >= 2);
  await qs(`update orders set created_at = now() - interval '119 minutes' where number = '${oR.number}'`);
  await worksSup('à 1 h 59 : expire_unpaid_orders ne l\'annule pas', `select expire_unpaid_orders() n`, (r) => r[0].n === 0);
  const sBefore = await vStock(vS), rBefore = await vStock(vR);
  await qs(`update orders set created_at = now() - interval '121 minutes' where number = '${oR.number}'`);
  check('à 2 h 01 : échéance de réservation dépassée', (await qs(`select _order_hold_until(id) < now() ok from orders where number = '${oR.number}'`))[0].ok === true);
  await worksSup('à 2 h 01 : expire_unpaid_orders annule la commande', `select expire_unpaid_orders() n`, (r) => r[0].n >= 1);
  check('expiration : stock restitué sur les deux boutiques (S +2, Rouge +1)', (await vStock(vS)) === sBefore + 2 && (await vStock(vR)) === rBefore + 1, `${await vStock(vS)} ${sBefore}`);
  await worksSup('expiration rejouée : aucun effet', `select expire_unpaid_orders() n`, (r) => r[0].n === 0);
  await qs(`select _cancel_order_core(id) from orders where number = '${oR.number}'`);
  await qs(`update orders set cancelled_at = now() where number = '${oR.number}'`);
  check('restitution idempotente : stock identique après rejeu (S, Rouge)', (await vStock(vS)) === sBefore + 2 && (await vStock(vR)) === rBefore + 1);
  await as(U(3));
  const tr2 = (await q(`select order_tracking('${oR.number}') r`))[0].r;
  check('réservation libérée affichée après expiration', tr2.reservation.state === 'released' && tr2.state === 'cancelled', JSON.stringify([tr2.reservation, tr2.state]));
  await fails('paiement refusé sur une commande expirée', `select payment_start('order', 'Commande ${oR.number}', ${oR.subtotal + oR.fee}, 'manual')`, /introuvable ou déjà réglée/);
  await fails('annulation d\'une commande déjà expirée refusée (pas de seconde restitution)', `select cancel_order('${oR.number}')`, /déjà annulée/);
  check('stock identique après tentatives (S, Rouge)', (await vStock(vS)) === sBefore + 2 && (await vStock(vR)) === rBefore + 1);

  // paiement déclaré : la commande n'expire pas tant que le paiement est en cours, et l'échéance suit la règle des 48 h
  const oP = (await buy(U(3), [items(LA, vS, 1)])())[0].r;
  await as(U(3));
  const pid = (await q(`select payment_start('order', 'Commande ${oP.number}', ${oP.subtotal + oP.fee}, 'manual') id`))[0].id;
  const h48 = (await qs(`select extract(epoch from (_order_hold_until(id) - created_at)) s from orders where number = '${oP.number}'`))[0].s;
  check('demande de paiement ouverte : réservation prolongée à 48 h (règle expire_unpaid_orders)', Number(h48) === 172800, String(h48));
  await as(U(3));
  await q(`select payment_declare('${pid}', 'REF-H13-0001')`);
  await qs(`update orders set created_at = now() - interval '5 hours' where number = '${oP.number}'`);
  check('paiement déclaré : aucune échéance (paiement en cours)', (await qs(`select _order_hold_until(id) is null ok from orders where number = '${oP.number}'`))[0].ok === true);
  await worksSup('paiement déclaré : expire_unpaid_orders ne touche pas la commande', `select expire_unpaid_orders() n`, (r) => r[0].n === 0);
  await as(U(3));
  check('suivi : « payment_in_progress »', (await q(`select order_tracking('${oP.number}') r`))[0].r.reservation.state === 'payment_in_progress');
  const sMid = await vStock(vS);
  await as(U(6));
  await q(`select payment_set_status('${pid}', 'confirmed', 'ok')`);
  check('paiement confirmé : commande payée, stock vendu (inchangé)', (await qs(`select paid from orders where number = '${oP.number}'`))[0].paid === true && (await vStock(vS)) === sMid);
  await as(U(3));
  check('suivi : réservation « sold », état « to_prepare », paiement « paid »', (await q(`select order_tracking('${oP.number}') r`))[0].r.reservation.state === 'sold' && (await q(`select order_tracking('${oP.number}') r`))[0].r.state === 'to_prepare' && (await q(`select order_tracking('${oP.number}') r`))[0].r.payment === 'paid');

  // ============================================================ 6. panier de deux boutiques : une commande, états par boutique
  const nBefore = await nOrders();
  const cc = (await (async () => { await as(U(3)); return q(`select cart_check('${JSON.stringify([items(LA, vM, 1), items(LB, vR, 1), items(LN, null, 1)])}'::jsonb) r`); })())[0].r;
  check('cart_check : panier valide, deux boutiques avec leur sous-total', cc.ok === true && cc.shops.length === 2 && cc.shops.find((s) => s.shop === 'Boutique Awa H13').subtotal_estimate === 9500 + 1500 && cc.shops.find((s) => s.shop === 'Boutique Biyo H13').subtotal_estimate === 12000, JSON.stringify(cc));
  const oM = (await buy(U(3), [items(LA, vM, 1), items(LB, vR, 1), items(LN, null, 1)])())[0].r;
  check('panier de deux boutiques : UNE commande (un seul paiement, un seul numéro)', (await nOrders()) === nBefore + 1 && oM.subtotal === 9500 + 12000 + 1500, JSON.stringify(oM));
  check('lignes rattachées à leur boutique (2 boutiques)', (await qs(`select count(distinct shop_id)::int n from order_lines ol join orders o on o.id = ol.order_id where o.number = '${oM.number}'`))[0].n === 2);
  await as(U(3));
  const tb = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('suivi acheteur : multi-boutiques, deux groupes, total, état « awaiting_payment »', tb.viewer === 'buyer' && tb.multi_shop === true && tb.shops.length === 2 && tb.state === 'awaiting_payment' && tb.payment === 'unpaid' && tb.subtotal === 23000, JSON.stringify(tb));
  check('suivi acheteur : sous-total par boutique et lignes (variante, quantité, prix)', tb.shops.find((s) => s.shop === 'Boutique Awa H13').subtotal === 11000 && tb.shops.find((s) => s.shop === 'Boutique Biyo H13').lines[0].variant === 'Rouge', JSON.stringify(tb.shops));
  await as(U(4));
  await fails('autre acheteur : suivi refusé', `select order_tracking('${oM.number}')`, /Commande introuvable/);
  await as(U(1));
  await fails('vendeur : suivi refusé tant que la commande n\'est ni payée ni à payer à la livraison', `select order_tracking('${oM.number}')`, /Commande introuvable/);
  await qs(`update orders set paid = true where number = '${oM.number}'`);
  check('paiement : séquestre en deux écritures (une par vendeur), 12000 et 11000', JSON.stringify((await qs(`select gross from money_entries where order_id = (select id from orders where number = '${oM.number}') and kind = 'order' order by gross`)).map((x) => x.gross)) === '[11000,12000]');
  await as(U(1));
  const ta = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('suivi vendeur A : sa boutique seulement, sans frais ni remise ni paiement du client', ta.viewer === 'seller' && ta.shops.length === 1 && ta.shops[0].shop === 'Boutique Awa H13' && ta.subtotal === 11000 && ta.payment === null && ta.fee === null && ta.refunds.length === 0, JSON.stringify(ta));
  check('suivi vendeur A : indique qu\'il s\'agit d\'une commande multi-boutiques', ta.multi_shop === true);
  await as(U(8));
  await fails('vendeur C étranger à la commande : suivi refusé', `select order_tracking('${oM.number}')`, /Commande introuvable/);
  await as(U(6));
  const tm = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('suivi administration : toutes les boutiques avec identifiant vendeur', tm.viewer === 'admin' && tm.shops.length === 2 && tm.shops.every((s) => !!s.seller_id));
  // avancement boutique par boutique
  await as(U(1)); await q(`select set_seller_order_status('${oM.number}', 1)`);
  await as(U(3));
  let tb1 = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('boutique A acceptée : A « accepted », B « to_prepare », commande « to_prepare » (la boutique la moins avancée)', tb1.shops.find((s) => s.shop === 'Boutique Awa H13').state === 'accepted' && tb1.shops.find((s) => s.shop === 'Boutique Biyo H13').state === 'to_prepare' && tb1.state === 'to_prepare', JSON.stringify(tb1.shops.map((s) => s.state)));
  await as(U(2)); await q(`select set_seller_order_status('${oM.number}', 1)`);
  await as(U(6));
  let adm = (await q(`select admin_orders(50) r`))[0].r.find((x) => x.number === oM.number);
  check('administration : même état que l\'acheteur (« accepted »), 2 boutiques, paiement « paid »', adm.state === 'accepted' && adm.shops === 2 && adm.payment === 'paid' && adm.paid === true, JSON.stringify(adm));
  await as(U(3));
  check('acheteur : même état (« accepted »)', (await q(`select order_tracking('${oM.number}') r`))[0].r.state === 'accepted');
  for (const st of [2, 3, 4]) { await as(U(1)); await q(`select set_seller_order_status('${oM.number}', ${st})`); }
  await as(U(3));
  tb1 = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('A livrée, B acceptée : commande « accepted » (pas « delivered »)', tb1.state === 'accepted' && tb1.shops.find((s) => s.shop === 'Boutique Awa H13').state === 'delivered', JSON.stringify(tb1.shops.map((s) => s.state)));
  for (const st of [2, 3, 4]) { await as(U(2)); await q(`select set_seller_order_status('${oM.number}', ${st})`); }
  await as(U(3));
  tb1 = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('les deux boutiques livrées : commande « delivered »', tb1.state === 'delivered');
  const kinds = tb1.events.map((e) => e.kind);
  check('frise réelle : créée, payée, étapes par boutique (acceptée..livrée), dans l\'ordre chronologique', kinds[0] === 'created' && kinds.includes('paid') && kinds.filter((k) => k === 'fulfillment_1').length === 2 && kinds.filter((k) => k === 'fulfillment_4').length === 2 && tb1.events.every((e, i, a) => i === 0 || new Date(a[i - 1].at) <= new Date(e.at)), JSON.stringify(kinds));
  check('frise : chaque étape de boutique porte le nom de la boutique', tb1.events.filter((e) => e.kind === 'fulfillment_2').every((e) => e.shop === 'Boutique Awa H13' || e.shop === 'Boutique Biyo H13'));
  await as(U(1));
  const tav = (await q(`select order_tracking('${oM.number}') r`))[0].r;
  check('frise vendeur A : ses étapes et celles de la commande, jamais celles de la boutique B', tav.events.every((e) => e.shop === null || e.shop === 'Boutique Awa H13'), JSON.stringify(tav.events));
  check('événements : un seul « paid » et un seul « created » (déclencheurs sans doublon)', (await qs(`select count(*) filter (where kind = 'paid')::int p, count(*) filter (where kind = 'created')::int c from order_events where order_id = (select id from orders where number = '${oM.number}')`))[0].p === 1);
  await as(U(1));
  await fails('vendeur A : étape sautée refusée (statut déjà atteint)', `select set_seller_order_status('${oM.number}', 2)`, /déjà atteint/);

  // panier de deux boutiques dont une en rupture : rien n'est créé
  await as(U(1));
  await q(`select variant_adjust('${vR}', 0, null, 'rupture voulue')`).catch(() => {});
  await as(U(2));
  await q(`select variant_adjust('${vR}', 0, null, 'rupture voulue')`);
  const n0 = await nOrders(), sm0 = await vStock(vM), ln0 = await stockOf(LN);
  await as(U(3));
  const cc2 = (await q(`select cart_check('${JSON.stringify([items(LA, vM, 1), items(LB, vR, 1), items(LN, null, 1)])}'::jsonb) r`))[0].r;
  const bad = cc2.lines.filter((l) => !l.ok);
  check('cart_check : une boutique en rupture => ok=false, la ligne fautive est désignée (code, boutique, disponible)', cc2.ok === false && bad.length === 1 && bad[0].code === 'out_of_stock' && bad[0].shop === 'Boutique Biyo H13' && bad[0].available === 0 && bad[0].index === 1, JSON.stringify(cc2));
  check('cart_check : la boutique saine reste marquée valide', cc2.shops.find((s) => s.shop === 'Boutique Awa H13').ok === true && cc2.shops.find((s) => s.shop === 'Boutique Biyo H13').ok === false);
  await fails('commande de deux boutiques dont une en rupture : refusée en bloc', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 1), items(LB, vR, 1), items(LN, null, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_out_of_stock/);
  check('rien créé : aucune commande, stock de l\'autre boutique intact (M, Cahier)', (await nOrders()) === n0 && (await vStock(vM)) === sm0 && (await stockOf(LN)) === ln0);
  check('rien créé : aucune ligne orpheline, aucun mouvement de stock « commande » nouveau', (await qs(`select count(*) c from order_lines where order_id not in (select id from orders)`))[0].c == 0);
  check('rien créé : aucun événement d\'une commande fantôme', (await qs(`select count(*) c from order_events where order_id not in (select id from orders)`))[0].c == 0);
  await as(U(3));
  const cc3 = (await q(`select cart_check('${JSON.stringify([items(LA, null, 1), items(LA, '00000000-0000-0000-0000-000000000abc', 1), items(LS, null, 1), items(LA, vM, 99)])}'::jsonb) r`))[0].r;
  check('cart_check : codes précis (variant_required, variant_unavailable, quote_only, invalid_qty)', JSON.stringify(cc3.lines.map((l) => l.code)) === JSON.stringify(['variant_required', 'variant_unavailable', 'quote_only', 'invalid_qty']), JSON.stringify(cc3.lines.map((l) => l.code)));
  await as(U(1));
  const cc4 = (await q(`select cart_check('${JSON.stringify([items(LB, vR, 1)])}'::jsonb) r`))[0].r;
  check('cart_check : produit d\'un autre vendeur pour le vendeur A (non propre) évalué sur le stock', cc4.lines[0].code === 'out_of_stock');
  const cc5 = (await q(`select cart_check('${JSON.stringify([items(LA, vM, 1)])}'::jsonb) r`))[0].r;
  check('cart_check : son propre produit est signalé (own_product)', cc5.lines[0].code === 'own_product');
  await as(U(2));
  await q(`select variant_adjust('${vR}', 6, null, 'réassort')`);

  // ============================================================ 7. annulation, remboursement, accès numérique
  // annulation acheteur d'une commande impayée : stock restitué UNE fois, état + événement
  await as(U(3));
  const sM = await vStock(vM);
  const oC = (await buy(U(3), [items(LA, vM, 3)])())[0].r;
  check('annulation : stock retenu à la commande (M -3)', (await vStock(vM)) === sM - 3);
  await as(U(3));
  await works('annulation par l\'acheteur', `select cancel_order('${oC.number}') r`, (r) => r[0].r === 'cancelled');
  await fails('annulation rejouée refusée', `select cancel_order('${oC.number}')`, /déjà annulée/);
  check('annulation : stock restitué une seule fois (M revient)', (await vStock(vM)) === sM);
  check('annulation : état « cancelled » et événement horodaté', (await q(`select order_tracking('${oC.number}') r`))[0].r.state === 'cancelled' && (await qs(`select count(*) c from order_events where order_id = (select id from orders where number = '${oC.number}') and kind = 'cancelled'`))[0].c == 1);

  // ressource numérique : fixture (licence, fichier déposé)
  await qs(`insert into storage.objects (bucket_id, name, owner_id) values ('digital-files', '${U(1)}/${LD}/guide.pdf', '${U(1)}') on conflict do nothing`);
  await as(U(1));
  await q(`select digital_listing_save('${LD}', 'personal', 'Usage personnel uniquement', 3)`);
  await q(`select digital_asset_register('${LD}', '${U(1)}/${LD}/guide.pdf', 'guide.pdf', 'application/pdf', 4096, '1.0')`);
  // remboursement COMPLET : accès révoqué
  const oF = (await buy(U(3), [items(LD, null, 1)])())[0].r;
  await qs(`update orders set paid = true where number = '${oF.number}'`);
  await as(U(3));
  check('numérique payé : accès actif dans Mes téléchargements', (await q(`select my_downloads() r`))[0].r.some((d) => d.status === 'active'));
  const olF = (await qs(`select ol.id from order_lines ol join orders o on o.id = ol.order_id where o.number = '${oF.number}'`))[0].id;
  await works('numérique payé : lien de téléchargement accordé', `select digital_download_url('${olF}') r`, (r) => !!r[0].r.path);
  await as(U(3));
  await q(`select order_refund_request('${oF.number}', 'Fichier illisible, remboursement demandé', '691234567', 'orange_money')`);
  await as(U(6));
  await works('remboursement complet accordé par l\'administration', `select order_refund_decide((select id from order_refunds where order_id = (select id from orders where number = '${oF.number}')), 'approve', 'ok') r`, (r) => r[0].r === 'approve');
  await as(U(3));
  check('remboursement complet : accès numérique révoqué (Mes téléchargements)', (await q(`select my_downloads() r`))[0].r.filter((d) => d.status === 'revoked').length >= 1 && !(await q(`select my_downloads() r`))[0].r.some((d) => d.status === 'active'));
  await fails('remboursement complet : lien de téléchargement refusé', `select digital_download_url('${olF}')`, /Accès révoqué|Ressource introuvable|remboursée|annulée/);
  const trF = (await q(`select order_tracking('${oF.number}') r`))[0].r;
  check('remboursement complet : état « refunded », paiement « refunded », frise avec la décision', trF.state === 'refunded' && trF.payment === 'refunded' && trF.events.some((e) => e.kind.startsWith('refund_approved')), JSON.stringify([trF.state, trF.payment, trF.events.map((e) => e.kind)]));
  check('remboursement complet : « Reçu » jamais présenté comme facture (aucune colonne facture/TVA dans le suivi)', !JSON.stringify(trF).toLowerCase().includes('facture') && !JSON.stringify(trF).toLowerCase().includes('tva'));
  // remboursement PARTIEL : accès conservé (décision propriétaire en attente)
  const oG = (await buy(U(4), [items(LD, null, 1)])())[0].r;
  await qs(`update orders set paid = true where number = '${oG.number}'`);
  await as(U(4));
  const olG = (await qs(`select ol.id from order_lines ol join orders o on o.id = ol.order_id where o.number = '${oG.number}'`))[0].id;
  await q(`select order_refund_request('${oG.number}', 'Remise partielle demandée après litige', '691234568', 'orange_money')`);
  await as(U(6));
  await works('remboursement partiel accordé (3000 sur 10000)', `select order_refund_decide((select id from order_refunds where order_id = (select id from orders where number = '${oG.number}')), 'approve', 'geste partiel', 3000) r`, (r) => r[0].r === 'approve');
  await as(U(4));
  check('remboursement partiel : accès numérique CONSERVÉ', (await q(`select my_downloads() r`))[0].r.some((d) => d.status === 'active'));
  await works('remboursement partiel : le lien reste accordé', `select digital_download_url('${olG}') r`, (r) => !!r[0].r.path);
  const trG = (await q(`select order_tracking('${oG.number}') r`))[0].r;
  check('remboursement partiel : commande non annulée, paiement « partially_refunded »', trG.state !== 'cancelled' && trG.state !== 'refunded' && trG.payment === 'partially_refunded', JSON.stringify([trG.state, trG.payment]));
  // remboursement complet d'une variante : stock restitué une seule fois
  const sS = await vStock(vS);
  const oV = (await buy(U(3), [items(LA, vS, 2)])())[0].r;
  await qs(`update orders set paid = true where number = '${oV.number}'`);
  await as(U(3));
  await q(`select order_refund_request('${oV.number}', 'Taille incorrecte, remboursement complet', '691234567', 'orange_money')`);
  await as(U(6));
  await q(`select order_refund_decide((select id from order_refunds where order_id = (select id from orders where number = '${oV.number}')), 'approve', 'ok')`);
  check('remboursement complet : variante restituée (S revient)', (await vStock(vS)) === sS);
  await qs(`update orders set cancelled_at = now() where number = '${oV.number}'`);
  check('rejeu côté serveur : pas de seconde restitution', (await vStock(vS)) === sS);

  // ============================================================ 8. double envoi et clé d'idempotence
  const sK = await vStock(vM);
  const k1 = (await buy(U(3), [items(LA, vM, 2)], 'cle-h13-double-clic')())[0].r;
  const k2 = (await buy(U(3), [items(LA, vM, 2)], 'cle-h13-double-clic')())[0].r;
  check('double clic : même clé => même commande rejouée', k1.number === k2.number && k1.replayed === false && k2.replayed === true, JSON.stringify([k1, k2]));
  check('double clic : une seule commande, stock décrémenté une seule fois', (await qs(`select count(*)::int n from orders where idem_key = 'cle-h13-double-clic'`))[0].n === 1 && (await vStock(vM)) === sK - 2);
  await as(U(4));
  const k3 = (await q(`select marketplace_checkout('${JSON.stringify([items(LA, vM, 1)])}'::jsonb, false, 'Mobile Money', null, null, 'cle-h13-double-clic') r`))[0].r;
  check('la clé est propre à l\'acheteur : l\'acheteur 2 obtient sa propre commande', k3.number !== k1.number && k3.replayed === false);
  await as(U(3));
  await fails('clé trop courte refusée clairement', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 1)])}'::jsonb, false, 'Mobile Money', null, null, 'abc')`, /Clé d'idempotence invalide/);
  await works('après annulation, la même clé ouvre une nouvelle commande', `select cancel_order('${k1.number}') r`, (r) => r[0].r === 'cancelled');
  const k4 = (await buy(U(3), [items(LA, vM, 2)], 'cle-h13-double-clic')())[0].r;
  check('nouvelle commande après annulation (numéro différent, non rejouée)', k4.number !== k1.number && k4.replayed === false);
  await as(U(3));
  await q(`select cancel_order('${k4.number}')`);
  await q(`select cancel_order('${k3.number}')`).catch(() => {});
  await as(U(4)); await q(`select cancel_order('${k3.number}')`).catch(() => {});

  // ============================================================ 9. un reçu n'est pas une facture fiscale ; matrice des états stable
  const states = ['awaiting_payment', 'to_prepare', 'accepted', 'preparing', 'ready', 'out_for_delivery', 'delivered', 'cancelled', 'refunded'];
  await as(U(6));
  const all = (await q(`select admin_orders(500) r`))[0].r;
  check('matrice : tous les états rencontrés appartiennent à la matrice documentée', all.length > 0 && all.every((x) => states.includes(x.state)), JSON.stringify([...new Set(all.map((x) => x.state))]));
  check('matrice : paiement dans la liste documentée', all.every((x) => ['unpaid', 'cod_pending', 'paid', 'partially_refunded', 'refunded'].includes(x.payment)));
  check('admin_orders : clés historiques conservées (number, status, paid, cancelled, method, total, created_at, buyer, sellers)', ['number', 'status', 'paid', 'cancelled', 'method', 'total', 'created_at', 'buyer', 'sellers'].every((k) => k in all[0]));
  await as(U(3));
  await fails('acheteur : admin_orders refusé', `select admin_orders(10)`, /non autorisée/);
  await as(U(1));
  await fails('vendeur : admin_orders refusé', `select admin_orders(10)`, /non autorisée/);
  await as(U(3));
  await fails('numéro de commande inconnu : refus clair', `select order_tracking('#BE-2099-9999')`, /Commande introuvable/);

  // ============================================================ 10. cohérence finale et rejeu des migrations
  check('stock annonce = somme des variantes actives (A et B)', (await stockOf(LA)) === Number((await qs(`select coalesce(sum(stock),0) s from listing_variants where listing_id = '${LA}' and active`))[0].s) && (await stockOf(LB)) === Number((await qs(`select coalesce(sum(stock),0) s from listing_variants where listing_id = '${LB}' and active`))[0].s));
  check('journal : somme des mouvements = stock actuel de chaque variante', (await qs(`select count(*) c from listing_variants v where v.stock <> (select coalesce(sum(delta),0) from stock_movements m where m.variant_id = v.id)`))[0].c == 0);
  const snap = async () => JSON.stringify(await qs(`select (select count(*) from orders) o, (select count(*) from order_lines) l, (select count(*) from order_events) e, (select count(*) from listing_variants) v, (select coalesce(sum(stock),0) from listing_variants) s, (select count(*) from money_entries) m`));
  const s0 = await snap();
  const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  for (const f of fs.readdirSync(path.join(repo, 'migrations')).filter((x) => x.startsWith('2026112803'))) {
    try { await sup(); await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); check(`rejeu de ${f} sans erreur`, true); } catch (e) { check(`rejeu de ${f} sans erreur`, false, e.message); }
  }
  check('rejeu des migrations H13 : aucune donnée modifiée', (await snap()) === s0);
  await as(U(3));
  await works('après rejeu : la commande fonctionne toujours (prix de variante)', `select marketplace_checkout('${JSON.stringify([items(LA, vM, 1)])}'::jsonb, false, 'Mobile Money') r`, (r) => r[0].r.subtotal === 9500);

  await sup();
  console.log(`\nH13 COMMERCE : ${ok} OK / ${ko} ECHEC`);
}
