// Scénario PGlite du lot H12 STOCK (20261127200000_h12_stock_variantes.sql + 20261127200100_h12_stock_commande.sql) : stock par variante.
// Cas autorisés ET refusés : création / modification / désactivation / ajustement (audité) par le vendeur propriétaire seulement ; lecture publique sans stock exact ;
// commande (variante obligatoire, décrément atomique, refus variant_out_of_stock avec la quantité disponible, panier multi-lignes refusé en bloc) ;
// N achats successifs jusqu'à épuisement, dernier exemplaire ; restitution idempotente (annulation, expiration, remboursement, litige) ; journal des mouvements (avant/après) ;
// alertes de seuil une fois par franchissement ; annonce sans variante inchangée ; prix inchangés ; rejeu des migrations sans effet.
// PGlite est mono-connexion : la concurrence RÉELLE est prouvée par h12_stock_concurrence.mjs (PostgreSQL local, plusieurs connexions).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h12_stock.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000120${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const qs = async (sql) => { await sup(); return q(sql); };

  await sup();
  // 1 vendeur A ; 2 vendeur B ; 3 acheteur 1 ; 4 acheteur 2 ; 5 étudiant NON éligible ; 6 administrateur ; 7 client (tentative de vendre)
  const roles = { 1: 'student', 2: 'student', 3: 'client', 4: 'client', 5: 'student', 6: 'admin', 7: 'client' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h12s${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte H12 ${n}','${r}','h12s${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69120' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
  }
  for (const n of [1, 2]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${U(n)}'`);
  await db.exec(`update profiles set phone_verified = false where id = '${U(5)}'`);
  const mk = async (seller, title, o = {}) => (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images) values (${seller ? `'${seller}'` : 'null'}, '${title}', 'Design', '${o.category ?? 'Maison'}', ${o.price ?? 10000}, ${o.stock ?? 50}, '${o.status ?? 'approved'}', '{photo.jpg}') returning id`))[0].id;
  const LA = await mk(U(1), 'Tee-shirt H12', { price: 8000, stock: 50 });
  const LB = await mk(U(2), 'Sac H12', { price: 12000, stock: 10 });
  const LN = await mk(U(1), 'Cahier H12 sans variante', { price: 1500, stock: 3 });
  const LS = await mk(U(1), 'Service H12', { category: 'Services' });
  const LD = await mk(U(1), 'Brouillon H12', { status: 'draft', stock: 7 });
  const LP = await mk(null, 'Produit plateforme H12', { price: 5000, stock: 4 });
  const stockOf = async (id) => Number((await qs(`select stock from listings where id = '${id}'`))[0].stock);
  const vStock = async (id) => Number((await qs(`select stock from listing_variants where id = '${id}'`))[0].stock);
  const sumActive = async (lid) => Number((await qs(`select coalesce(sum(stock),0) s from listing_variants where listing_id = '${lid}' and active`))[0].s);
  const nOrders = async () => Number((await qs(`select count(*) c from orders`))[0].c);
  const buy = (uid, items) => async () => { await as(uid); return q(`select marketplace_checkout('${JSON.stringify(items)}'::jsonb, false, 'Mobile Money') r`); };
  const items = (lid, vid, qty = 1, extra = {}) => ({ id: lid, qty, ...(vid ? { variant_id: vid } : {}), ...extra });

  // ============================================================ 1. annonce SANS variante : comportement actuel inchangé
  await as(U(3));
  let r0 = (await q(`select marketplace_checkout('${JSON.stringify([items(LN, null, 1)])}'::jsonb, false, 'Mobile Money') r`))[0].r;
  check('sans variante : commande créée', !!r0.number && r0.subtotal === 1500, JSON.stringify(r0));
  check('sans variante : stock global décrémenté (2)', (await stockOf(LN)) === 2);
  check('sans variante : ligne sans variante', (await qs(`select count(*) c from order_lines ol join orders o on o.id = ol.order_id where o.number = '${r0.number}' and ol.variant_id is null`))[0].c == 1);
  await as(U(3));
  await fails('sans variante : au-delà du stock refusé (Stock insuffisant)', `select marketplace_checkout('${JSON.stringify([items(LN, null, 5)])}'::jsonb, false, 'Mobile Money')`, /Stock insuffisant/);
  await fails('sans variante : une variante_id inventée est refusée', `select marketplace_checkout('${JSON.stringify([items(LN, '00000000-0000-0000-0000-000000000abc', 1)])}'::jsonb, false, 'Mobile Money')`, /variant_unavailable/);
  await works('sans variante : annulation restitue le stock global', `select cancel_order('${r0.number}') r`, (r) => r[0].r === 'cancelled');
  check('sans variante : stock global restitué (3)', (await stockOf(LN)) === 3);
  await works('sans variante : l\'acheteur peut encore appeler la lecture publique (liste vide)', `select listing_variants_public('${LN}') r`, (r) => Array.isArray(r[0].r) && r[0].r.length === 0);

  // ============================================================ 2. création de variantes : droits
  await as(null, 'anon');
  await fails('anonyme : variant_save refusé', `select variant_save('${LA}', 'S')`, /permission denied|Connexion requise/i);
  await fails('anonyme : variant_adjust refusé', `select variant_adjust('${LA}', 1, null, 'test')`, /permission denied|Connexion requise/i);
  await fails('anonyme : seller_variants_list refusé', `select seller_variants_list('${LA}')`, /permission denied|Connexion requise/i);
  await as(U(7));
  await fails('client : variant_save refusé (réservé aux étudiants-vendeurs)', `select variant_save('${LA}', 'S')`, /Annonce introuvable|Réservé aux étudiants/);
  await as(U(3));
  await fails('acheteur : variant_save sur l\'annonce d\'autrui refusé', `select variant_save('${LA}', 'S')`, /Annonce introuvable|Réservé aux étudiants/);
  await as(U(5));
  await fails('étudiant non éligible : variant_save refusé', `select variant_save('${LA}', 'S')`, /Annonce introuvable|statut d.étudiant|téléphone/);
  await as(U(2));
  await fails('vendeur B : variant_save sur l\'annonce du vendeur A refusé', `select variant_save('${LA}', 'S')`, /Annonce introuvable/);
  await fails('vendeur B : seller_variants_list de l\'annonce de A refusé', `select seller_variants_list('${LA}')`, /Annonce introuvable/);
  await as(U(1));
  await fails('vendeur A : un service ne reçoit pas de variante', `select variant_save('${LS}', 'S')`, /Seul un produit a du stock/);
  await fails('vendeur A : libellé vide refusé', `select variant_save('${LA}', '   ')`, /libellé de la variante/);
  await fails('vendeur A : attributs invalides (pas un objet) refusés', `select variant_save('${LA}', 'S', '["a"]'::jsonb)`, /Attributs/);
  await fails('vendeur A : attribut non textuel refusé', `select variant_save('${LA}', 'S', '{"taille": 5}'::jsonb)`, /Attribut invalide/);
  await fails('vendeur A : SKU invalide refusé', `select variant_save('${LA}', 'S', '{}'::jsonb, 'sku avec espace')`, /SKU/);
  await fails('vendeur A : stock négatif refusé', `select variant_save('${LA}', 'S', '{}'::jsonb, null, -1)`, /Stock : un entier/);
  await fails('vendeur A : seuil négatif refusé', `select variant_save('${LA}', 'S', '{}'::jsonb, null, 1, -2)`, /Seuil/);

  // première variante : reprend le stock global (50) quand aucun stock n'est indiqué
  let vS, vM, vL;
  await works('vendeur A : première variante S (stock repris de l\'annonce = 50), SKU, attributs', `select variant_save('${LA}', 'S', '{"taille":"S","couleur":"Bleu"}'::jsonb, 'TS-S', null, 2) r`,
    (r) => { vS = r[0].r.id; return r[0].r.stock === 50 && r[0].r.sku === 'TS-S' && r[0].r.attributes.taille === 'S' && r[0].r.low_threshold === 2; });
  await works('vendeur A : ajustement exact S -> 5 (motif)', `select variant_adjust('${vS}', 5, null, 'comptage initial') r`, (r) => r[0].r.stock === 5);
  await works('vendeur A : variante M (stock 3, seuil 1)', `select variant_save('${LA}', 'M', '{"taille":"M"}'::jsonb, 'TS-M', 3, 1) r`, (r) => { vM = r[0].r.id; return r[0].r.stock === 3; });
  await works('vendeur A : variante L (stock 0)', `select variant_save('${LA}', 'L', '{"taille":"L"}'::jsonb, null, 0, 1) r`, (r) => { vL = r[0].r.id; return r[0].r.stock === 0; });
  check('stock de l\'annonce = somme des variantes actives (8)', (await stockOf(LA)) === 8 && (await sumActive(LA)) === 8);
  await as(U(1));
  await fails('vendeur A : libellé déjà pris (insensible à la casse) refusé', `select variant_save('${LA}', ' s ')`, /déjà une variante/);
  await fails('vendeur A : SKU déjà utilisé par une autre de ses variantes refusé', `select variant_save('${LA}', 'XL', '{}'::jsonb, 'ts-s', 1)`, /SKU est déjà utilisé/);
  await fails('vendeur A : même SKU sur une autre annonce du même vendeur refusé (unique par vendeur)', `select variant_save('${LD}', 'S', '{}'::jsonb, 'TS-S', 1)`, /SKU est déjà utilisé/);
  await as(U(2));
  let vB;
  await works('vendeur B : même SKU chez un autre vendeur autorisé (unique par vendeur)', `select variant_save('${LB}', 'Rouge', '{"couleur":"Rouge"}'::jsonb, 'TS-S', 4, 1) r`, (r) => { vB = r[0].r.id; return true; });
  await works('vendeur B : seconde variante pour la suite (Noir, 2)', `select variant_save('${LB}', 'Noir', '{}'::jsonb, null, 2, 1) r`, (r) => r[0].r.stock === 2);
  await fails('vendeur B : ne modifie pas la variante du vendeur A (variant_save avec p_id)', `select variant_save('${LA}', 'S2', '{}'::jsonb, null, null, 3, '${vS}')`, /Annonce introuvable/);
  await fails('vendeur B : n\'ajuste pas le stock d\'une variante du vendeur A', `select variant_adjust('${vS}', 99, null, 'piratage')`, /Annonce introuvable/);
  await fails('vendeur B : ne désactive pas la variante du vendeur A', `select variant_set_active('${vS}', false)`, /Annonce introuvable/);
  check('le stock de la variante de A est intact après les tentatives de B', (await vStock(vS)) === 5);

  // ============================================================ 3. cloisonnement : écriture directe fermée
  await as(U(3));
  await fails('acheteur : écriture directe dans listing_variants refusée', `update listing_variants set stock = 9999 where id = '${vS}'`, /permission denied/);
  await fails('acheteur : insertion directe refusée', `insert into listing_variants (listing_id, label, stock) values ('${LA}', 'X', 5)`, /permission denied/);
  await fails('acheteur : suppression directe refusée', `delete from listing_variants where id = '${vS}'`, /permission denied/);
  await works('acheteur : lecture directe de la table = 0 ligne (RLS : stock exact réservé au vendeur)', `select count(*)::int c from listing_variants`, (r) => r[0].c === 0);
  await works('acheteur : stock_movements invisibles', `select count(*)::int c from stock_movements where variant_id is not null`, (r) => r[0].c === 0);
  await works('acheteur : la mise à jour du stock global d\'une annonce d\'autrui ne touche aucune ligne', `update listings set stock = 999 where id = '${LA}' returning id`, (r) => r.length === 0);
  check('acheteur : le stock global de l\'annonce n\'a pas bougé', (await stockOf(LA)) === 8);
  await as(U(1));
  await works('vendeur A : lit ses variantes avec stock exact', `select seller_variants_list('${LA}') r`, (r) => r[0].r.length === 3 && r[0].r.find((v) => v.label === 'S').stock === 5);
  await fails('vendeur A : stock global verrouillé tant que des variantes sont actives', `update listings set stock = 999 where id = '${LA}'`, /se gère par variante/);
  await works('vendeur A : lecture directe de ses variantes autorisée', `select count(*)::int c from listing_variants`, (r) => r[0].c === 3);
  await as(U(2));
  await works('vendeur B : ne voit pas les variantes de A (RLS)', `select count(*)::int c from listing_variants where listing_id = '${LA}'`, (r) => r[0].c === 0);

  // ============================================================ 4. lecture publique : état sans stock exact
  await as(null, 'anon');
  await works('anonyme : variantes publiques (états, aucun stock exact)', `select listing_variants_public('${LA}') r`, (r) => {
    const l = r[0].r; const s = l.find((v) => v.label === 'S'); const m = l.find((v) => v.label === 'M'); const x = l.find((v) => v.label === 'L');
    return l.length === 3 && s.state === 'available' && m.state === 'available' && x.state === 'out' && !('stock' in s) && !('sku' in s) && !('left' in s) && !JSON.stringify(l).includes('"stock"');
  });
  await as(U(3));
  await works('acheteur : annonce en brouillon -> aucune variante publique', `select listing_variants_public('${LD}') r`, (r) => r[0].r.length === 0);
  await as(U(1));
  await works('vendeur A : variante basse -> « derniers exemplaires » avec le nombre restant (M : 3 > seuil 1 = disponible ; seuil relevé à 3 = bas)', `select variant_save('${LA}', 'M', '{"taille":"M"}'::jsonb, 'TS-M', null, 3, '${vM}') r`, (r) => r[0].r.stock === 3 && r[0].r.low_threshold === 3);
  await as(null, 'anon');
  await works('anonyme : M est « low » avec left = 3', `select listing_variants_public('${LA}') r`, (r) => { const m = r[0].r.find((v) => v.label === 'M'); return m.state === 'low' && m.left === 3; });
  await as(U(1));
  await as(U(1));
  await works('vendeur A : seuil de M remis à 1', `select variant_save('${LA}', 'M', '{"taille":"M"}'::jsonb, 'TS-M', null, 1, '${vM}') r`, (r) => r[0].r.low_threshold === 1);

  // ============================================================ 5. commande : variante, prix, refus
  await as(U(3));
  await fails('commande : variante obligatoire (variant_required)', `select marketplace_checkout('${JSON.stringify([items(LA, null, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_required/);
  await fails('commande : variante d\'une autre annonce refusée', `select marketplace_checkout('${JSON.stringify([items(LA, vB, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_unavailable/);
  await fails('commande : variante_id mal formé refusé (variant_required)', `select marketplace_checkout('${JSON.stringify([items(LA, 'pas-un-uuid', 1)])}'::jsonb, false, 'Mobile Money')`, /variant_required/);
  const nBefore = await nOrders();
  await as(U(3));
  const o1 = (await q(`select marketplace_checkout('${JSON.stringify([items(LA, vS, 2)])}'::jsonb, false, 'Mobile Money') r`))[0].r;
  check('commande S x2 : prix de l\'annonce inchangé (16 000 FCFA)', o1.subtotal === 16000 && o1.discount === 0, JSON.stringify(o1));
  check('commande S x2 : stock variante 5 -> 3', (await vStock(vS)) === 3);
  check('commande S x2 : stock annonce = somme (6)', (await stockOf(LA)) === 6 && (await sumActive(LA)) === 6);
  const ln1 = (await qs(`select ol.variant, ol.variant_id, ol.unit_price, ol.qty from order_lines ol join orders o on o.id = ol.order_id where o.number = '${o1.number}'`))[0];
  check('commande : la ligne référence la variante (id, libellé, prix unitaire de l\'annonce)', ln1.variant_id === vS && ln1.variant === 'S' && ln1.unit_price === 8000 && ln1.qty === 2, JSON.stringify(ln1));
  await as(U(3));
  await fails('refus : S demande 4, il en reste 3 -> variant_out_of_stock avec la quantité disponible', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 4)])}'::jsonb, false, 'Mobile Money')`, /variant_out_of_stock/);
  try { await q(`select marketplace_checkout('${JSON.stringify([items(LA, vS, 4)])}'::jsonb, false, 'Mobile Money')`); } catch (e) {
    check('refus : message lisible avec « 3 disponible(s) »', /3 disponible\(s\)/.test(e.message) && /Tee-shirt H12 — S/.test(e.message), e.message);
    check('refus : détail JSON (code, available, requested)', (() => { try { const d = JSON.parse(e.detail); return d.code === 'variant_out_of_stock' && d.available === 3 && d.requested === 4; } catch { return false; } })(), String(e.detail));
  }
  await fails('refus : variante épuisée (L = 0)', `select marketplace_checkout('${JSON.stringify([items(LA, vL, 1)])}'::jsonb, false, 'Mobile Money')`, /0 disponible\(s\).*variant_out_of_stock/);
  await fails('refus : quantité invalide (0)', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 0)])}'::jsonb, false, 'Mobile Money')`, /Quantité invalide/);
  await fails('refus : quantité invalide (21)', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 21)])}'::jsonb, false, 'Mobile Money')`, /Quantité invalide/);
  check('refus : aucun stock consommé par les refus', (await vStock(vS)) === 3 && (await vStock(vL)) === 0);
  await as(U(1));
  await fails('vendeur A : n\'achète pas sa propre variante', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 1)])}'::jsonb, false, 'Mobile Money')`, /propre produit/);

  // panier multi-lignes dont une ligne manque -> commande entièrement refusée
  const nMid = await nOrders();
  await as(U(3));
  await fails('panier multi-lignes : une ligne manque (M demande 9) -> commande entièrement refusée', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 1), items(LB, vB, 1), items(LA, vM, 9)])}'::jsonb, false, 'Mobile Money')`, /variant_out_of_stock/);
  check('panier refusé : aucune commande créée', (await nOrders()) === nMid);
  check('panier refusé : stocks intacts (S 3, M 3, Rouge 4)', (await vStock(vS)) === 3 && (await vStock(vM)) === 3 && (await vStock(vB)) === 4);
  check('panier refusé : annonces cohérentes', (await stockOf(LA)) === 6 && (await stockOf(LB)) === 6);
  await as(U(3));
  await fails('panier : ligne sans variante sur annonce à variantes, 2e ligne valide -> refusé en bloc', `select marketplace_checkout('${JSON.stringify([items(LB, vB, 1), items(LA, null, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_required/);
  check('panier refusé : stock de Rouge intact (4)', (await vStock(vB)) === 4);
  // panier multi-lignes valide, ordre inverse (verrou ordonné)
  const o2 = (await buy(U(3), [items(LB, vB, 1), items(LA, vM, 1), items(LN, null, 1)])())[0].r;
  check('panier multi-lignes valide (annonces dans un ordre quelconque, une sans variante)', !!o2.number && o2.subtotal === 12000 + 8000 + 1500, JSON.stringify(o2));
  check('panier valide : Rouge 3, M 2, cahier 2', (await vStock(vB)) === 3 && (await vStock(vM)) === 2 && (await stockOf(LN)) === 2);

  // ============================================================ 6. N achats successifs jusqu'à épuisement + dernier exemplaire
  const seq = [];
  for (let i = 0; i < 5; i++) {
    try { await buy(U(i % 2 === 0 ? 3 : 4), [items(LA, vM, 1)])(); seq.push('ok'); } catch (e) { seq.push(/variant_out_of_stock/.test(e.message) ? 'refus' : 'autre:' + e.message); }
  }
  check('M (2 restants) : 5 achats successifs -> 2 réussites puis 3 refus variant_out_of_stock', seq.join(',') === 'ok,ok,refus,refus,refus', seq.join(','));
  check('M épuisée : stock variante 0, jamais négatif', (await vStock(vM)) === 0);
  const lastU = (await buy(U(4), [items(LA, vS, 3)])())[0].r;
  check('dernier exemplaire : S (3 restants) achetés d\'un coup -> 0', !!lastU.number && (await vStock(vS)) === 0 && (await stockOf(LA)) === 0);
  await as(U(4));
  await fails('dernier exemplaire : plus rien à vendre (S épuisée)', `select marketplace_checkout('${JSON.stringify([items(LA, vS, 1)])}'::jsonb, false, 'Mobile Money')`, /0 disponible\(s\)/);
  await sup();
  try { await db.exec(`update listing_variants set stock = -1 where id = '${vS}'`); check('contrainte CHECK : stock négatif refusé en base', false, 'aurait du echouer'); } catch (e) { check('contrainte CHECK : stock négatif refusé en base', /check|violates/i.test(e.message), e.message); }

  // ============================================================ 7. restitution : annulation, idempotence, double annulation
  const sBefore = await vStock(vS);
  await as(U(4));
  await works('annulation de la commande du dernier exemplaire (S x3) -> restitution', `select cancel_order('${lastU.number}') r`, (r) => r[0].r === 'cancelled');
  check('restitution : S revient à 3 et l\'annonce à la somme', (await vStock(vS)) === sBefore + 3 && (await stockOf(LA)) === (await sumActive(LA)));
  await as(U(4));
  await fails('double annulation refusée (Commande déjà annulée)', `select cancel_order('${lastU.number}')`, /déjà annulée/);
  check('double annulation : stock inchangé (3)', (await vStock(vS)) === 3);
  await sup();
  await q(`select _cancel_order_core(id) from orders where number = '${lastU.number}'`);
  await q(`update orders set cancelled_at = now() where number = '${lastU.number}'`);
  check('annulation rejouée côté serveur (cœur d\'annulation, mise à jour directe) : une commande ne restitue qu\'une fois (3)', (await vStock(vS)) === 3);
  check('restitution : ligne marquée restituée', (await qs(`select count(*) c from order_lines ol join orders o on o.id = ol.order_id where o.number = '${lastU.number}' and ol.variant_restocked_at is not null`))[0].c == 1);
  // un deuxième cycle commande/annulation : stock exact
  const oC = (await buy(U(4), [items(LA, vS, 2)])())[0].r;
  check('nouveau cycle : S 3 -> 1', (await vStock(vS)) === 1);
  await as(U(4)); await q(`select cancel_order('${oC.number}')`);
  check('nouveau cycle : annulation -> S 3', (await vStock(vS)) === 3 && (await stockOf(LA)) === (await sumActive(LA)));

  // expiration d'une commande impayée (réservation expirante, flux actuel)
  const oE = (await buy(U(4), [items(LA, vS, 2), items(LB, vB, 1)])())[0].r;
  check('réservation : le stock est retenu à la commande (S 1, Rouge 2)', (await vStock(vS)) === 1 && (await vStock(vB)) === 2);
  await sup();
  await q(`update orders set created_at = now() - interval '3 hours' where number = '${oE.number}'`);
  await works('expiration : expire_unpaid_orders annule la commande impayée', `select expire_unpaid_orders() n`, (r) => r[0].n >= 1);
  check('expiration : stock restitué (S 3, Rouge 3), une seule fois', (await vStock(vS)) === 3 && (await vStock(vB)) === 3);
  await works('expiration rejouée : aucun effet', `select expire_unpaid_orders() n`, (r) => r[0].n === 0);
  check('expiration rejouée : stock inchangé', (await vStock(vS)) === 3 && (await vStock(vB)) === 3);

  // remboursement complet d'une commande payée
  const oR = (await buy(U(3), [items(LA, vS, 1)])())[0].r;
  await sup();
  await q(`update orders set paid = true where number = '${oR.number}'`);
  await as(U(3));
  let refundOk = true;
  try { await q(`select order_refund_request('${oR.number}', 'Produit non conforme à la description', '691234567', 'orange_money')`); } catch (e) { refundOk = false; check('remboursement : demande de l\'acheteur', false, e.message); }
  if (refundOk) {
    await as(U(6));
    await works('remboursement complet accepté par l\'administrateur', `select order_refund_decide((select id from order_refunds where order_id = (select id from orders where number = '${oR.number}')), 'approve', 'ok') r`, (r) => r[0].r === 'approve');
    check('remboursement complet : variante restituée (S 3)', (await vStock(vS)) === 3);
    check('remboursement complet : mouvement « remboursement » journalisé', (await qs(`select count(*) c from stock_movements where order_number = '${oR.number}' and reason = 'remboursement' and delta = 1`))[0].c == 1);
  }

  // litige (commande à payer à la livraison refusée) : chemin d'annulation interne de dispute_decide
  const oD = (await buy(U(3), [items(LA, vS, 1)])())[0].r;
  await sup(); await q(`update orders set method = 'Paiement à la livraison' where number = '${oD.number}'`);
  await as(U(3));
  let codOk = true;
  try { await q(`select confirm_cod_order('${oD.number}')`); } catch (e) { codOk = false; check('litige : confirmation à la livraison', false, e.message); }
  if (codOk) {
    let didDispute = true; let did;
    try { await as(U(1)); did = (await q(`select dispute_open('${oD.number}', 'Le client refuse de payer à la livraison') id`))[0].id; } catch (e) { didDispute = false; check('litige : ouverture par le vendeur', false, e.message); }
    if (didDispute) {
      await as(U(6));
      await works('litige : l\'administrateur annule la commande', `select dispute_decide('${did}', 'cancel', 'Refus de payer') r`, (r) => r[0].r === 'cancel');
      check('litige : variante restituée une seule fois (S 3, annonce = somme)', (await vStock(vS)) === 3 && (await stockOf(LA)) === (await sumActive(LA)), `${await vStock(vS)} ${await stockOf(LA)}`);
    }
  }

  // ============================================================ 8. journal des mouvements
  const mv = await qs(`select reason, delta, stock_before, stock_after, order_number from stock_movements where variant_id = '${vS}' order by id`);
  check('journal : mouvement initial (avant 0, après 50)', mv[0].reason === 'stock initial' && mv[0].stock_before === 0 && mv[0].stock_after === 50);
  check('journal : ajustement vendeur avec motif (50 -> 5)', mv.some((m) => m.reason === 'ajustement vendeur : comptage initial' && m.delta === -45 && m.stock_before === 50 && m.stock_after === 5));
  check('journal : mouvements de commande portent le numéro de commande', mv.some((m) => m.reason === 'commande' && m.order_number === o1.number && m.delta === -2));
  check('journal : annulations journalisées', mv.some((m) => m.reason === 'annulation' && m.order_number === lastU.number && m.delta === 3));
  check('journal : avant + delta = après pour chaque mouvement', mv.every((m) => m.stock_before + m.delta === m.stock_after));
  check('journal : somme des mouvements = stock actuel de chaque variante', (await qs(`select count(*) c from listing_variants v where v.stock <> (select coalesce(sum(delta),0) from stock_movements m where m.variant_id = v.id)`))[0].c == 0);
  check('journal : les mouvements de variantes ne sont pas dupliqués au niveau annonce', (await qs(`select count(*) c from stock_movements where listing_id = '${LA}' and variant_id is null and reason in ('commande','annulation')`))[0].c == 0);
  check('audit : l\'ajustement manuel est tracé', (await qs(`select count(*) c from audit_log where action like 'Stock ajusté : Tee-shirt H12 — S%' and actor_id = '${U(1)}'`))[0].c >= 1);

  // ============================================================ 9. ajustement manuel
  await as(U(1));
  await fails('ajustement : valeur et variation à la fois refusés', `select variant_adjust('${vS}', 5, 2, 'x y z')`, /soit le nouveau stock, soit la variation/);
  await fails('ajustement : ni valeur ni variation refusés', `select variant_adjust('${vS}', null, null, 'x y z')`, /soit le nouveau stock, soit la variation/);
  await fails('ajustement : motif obligatoire', `select variant_adjust('${vS}', 5, null, '')`, /motif/);
  await fails('ajustement : jamais de stock négatif (variation -10 sur 3)', `select variant_adjust('${vS}', null, -10, 'casse')`, /ne peut pas devenir négatif/);
  await fails('ajustement : valeur négative refusée', `select variant_adjust('${vS}', -1, null, 'casse')`, /ne peut pas devenir négatif/);
  await fails('ajustement : valeur trop grande refusée', `select variant_adjust('${vS}', 100001, null, 'trop')`, /Stock : un entier/);
  await works('ajustement : variation +4 (réassort) -> 7', `select variant_adjust('${vS}', null, 4, 'réassort fournisseur') r`, (r) => r[0].r.stock === 7);
  check('ajustement : l\'annonce suit (somme)', (await stockOf(LA)) === (await sumActive(LA)));

  // ============================================================ 10. alertes de seuil : une fois par franchissement
  const notifs = async (title) => Number((await qs(`select count(*) c from notifications where user_id = '${U(1)}' and title = '${title}' and data->>'variant' = '${vS}'`))[0].c);
  await works('alerte : S à 7, seuil 2 -> état ok (réarmé)', `select state from (select case when stock = 0 then 'out' when stock <= low_threshold then 'low' else 'ok' end state from listing_variants where id = '${vS}') x`, (r) => r[0].state === 'ok');
  const n0 = await notifs('Stock bas (variante)'), x0 = await notifs('Variante épuisée');
  await buy(U(3), [items(LA, vS, 4)])();  // 7 -> 3 : au-dessus du seuil
  check('alerte : 3 > seuil 2 : aucune notification', (await notifs('Stock bas (variante)')) === n0);
  await buy(U(3), [items(LA, vS, 1)])();  // 3 -> 2 : franchissement
  check('alerte : 2 <= seuil : UNE notification « Stock bas »', (await notifs('Stock bas (variante)')) === n0 + 1);
  await buy(U(3), [items(LA, vS, 1)])();  // 2 -> 1 : toujours bas
  check('alerte : toujours bas (1) : pas de nouvelle notification', (await notifs('Stock bas (variante)')) === n0 + 1);
  await buy(U(3), [items(LA, vS, 1)])();  // 1 -> 0 : épuisé
  check('alerte : épuisé : UNE notification « Variante épuisée »', (await notifs('Variante épuisée')) === x0 + 1 && (await notifs('Stock bas (variante)')) === n0 + 1);
  await as(U(1));
  await q(`select variant_adjust('${vS}', null, 1, 'retour')`);
  await buy(U(4), [items(LA, vS, 1)])();
  check('alerte : retour à 1 puis 0 : épuisé de nouveau notifié une fois (état amélioré puis dégradé)', (await notifs('Variante épuisée')) === x0 + 2 && (await notifs('Stock bas (variante)')) === n0 + 1);
  await as(U(1));
  await q(`select variant_adjust('${vS}', 20, null, 'gros réassort')`);   // réarmement silencieux (ok)
  await buy(U(4), [items(LA, vS, 18)])();                                 // 20 -> 2 : franchissement
  check('alerte : après réarmement, nouveau franchissement -> nouvelle notification « Stock bas »', (await notifs('Stock bas (variante)')) === n0 + 2);
  check('alerte : aucune alerte de stock au niveau de l\'annonce (pas de doublon)', (await qs(`select count(*) c from notifications where user_id = '${U(1)}' and title in ('Stock bas', 'Rupture de stock') and data->>'listing' = '${LA}'`))[0].c == 0);

  // ============================================================ 11. désactivation, réactivation, annonce sans variante active
  await as(U(1));
  await works('désactivation de la variante L', `select variant_set_active('${vL}', false) r`, (r) => r[0].r.active === false);
  await as(null, 'anon');
  await works('lecture publique : variante désactivée absente', `select listing_variants_public('${LA}') r`, (r) => !r[0].r.some((v) => v.label === 'L') && r[0].r.length === 2);
  await as(U(4));
  await fails('commande : variante désactivée refusée (variant_unavailable)', `select marketplace_checkout('${JSON.stringify([items(LA, vL, 1)])}'::jsonb, false, 'Mobile Money')`, /variant_unavailable/);
  check('désactivation : la somme exclut la variante désactivée', (await stockOf(LA)) === (await sumActive(LA)));
  await as(U(1));
  await works('réactivation de L', `select variant_set_active('${vL}', true) r`, (r) => r[0].r.active === true);
  // vendeur B : désactiver toutes les variantes -> l'annonce repasse au stock global (0)
  await as(U(2));
  const bl = (await q(`select seller_variants_list('${LB}') r`))[0].r;
  for (const v of bl) await q(`select variant_set_active('${v.id}', false)`);
  check('toutes les variantes désactivées : stock annonce = 0 (aucune vente fantôme)', (await stockOf(LB)) === 0);
  await works('toutes désactivées : le vendeur peut de nouveau fixer le stock global', `update listings set stock = 4 where id = '${LB}' returning stock`, (r) => r[0].stock === 4);
  await as(U(3));
  await works('annonce sans variante active : achat sur stock global (comportement actuel)', `select marketplace_checkout('${JSON.stringify([items(LB, null, 1)])}'::jsonb, false, 'Mobile Money') r`, (r) => !!r[0].r.number);
  check('annonce sans variante active : stock global 3', (await stockOf(LB)) === 3);

  // ============================================================ 12. création de variantes sur une annonce déjà réservée
  const oX = (await buy(U(3), [items(LN, null, 1)])())[0].r;
  await as(U(1));
  await fails('première variante refusée tant qu\'une commande impayée réserve du stock global', `select variant_save('${LN}', 'Bleu', '{}'::jsonb, null, 1, 1)`, /commandes non payées/);
  await as(U(3)); await q(`select cancel_order('${oX.number}')`); await q(`select cancel_order('${o2.number}')`);
  await as(U(1));
  await works('après annulation : première variante acceptée', `select variant_save('${LN}', 'Bleu', '{}'::jsonb, null, null, 1) r`, (r) => r[0].r.stock === 3);

  // ============================================================ 13. plafond de stock total, produit de la plateforme
  await as(U(1));
  let vBig;
  await works('plafond : une variante à 100 000', `select variant_save('${LD}', 'Big', '{}'::jsonb, null, 100000, 1) r`, (r) => { vBig = r[0].r.id; return true; });
  await fails('plafond : total de l\'annonce limité à 100 000', `select variant_save('${LD}', 'Big2', '{}'::jsonb, null, 1, 1)`, /limité à 100 000/);
  await as(U(1));
  await fails('produit de la plateforme : un vendeur n\'y touche pas', `select variant_save('${LP}', 'Z')`, /Annonce introuvable/);
  await as(U(6));
  let vP;
  await works('produit de la plateforme : l\'administrateur crée une variante', `select variant_save('${LP}', 'Standard', '{}'::jsonb, 'PF-1', null, 1) r`, (r) => { vP = r[0].r.id; return r[0].r.stock === 4; });
  await as(U(3));
  await works('produit de la plateforme : achat de la variante', `select marketplace_checkout('${JSON.stringify([items(LP, vP, 1)])}'::jsonb, false, 'Mobile Money') r`, (r) => !!r[0].r.number);
  check('produit de la plateforme : stock 3', (await vStock(vP)) === 3);

  // ============================================================ 14. cohérence globale et rejeu
  check('cohérence : pour chaque annonce à variantes actives, stock = somme (plafonnée)', (await qs(`select count(*) c from listings l where exists (select 1 from listing_variants v where v.listing_id = l.id and v.active) and l.stock <> least((select coalesce(sum(stock) filter (where active),0) from listing_variants v where v.listing_id = l.id), 100000)`))[0].c == 0);
  check('cohérence : aucun stock négatif (variantes et annonces)', (await qs(`select (select count(*) from listing_variants where stock < 0) + (select count(*) from listings where stock < 0) c`))[0].c == 0);
  const snap = JSON.stringify(await qs(`select id, stock, active from listing_variants order by id`));
  const snapL = JSON.stringify(await qs(`select id, stock from listings order by id`));
  const here = path.dirname(fileURLToPath(import.meta.url));
  for (const f of ['20261127200000_h12_stock_variantes.sql', '20261127200100_h12_stock_commande.sql']) {
    try { await db.exec(fs.readFileSync(path.join(here, '..', '..', 'migrations', f), 'utf8')); check(`rejeu de ${f} sans erreur`, true); } catch (e) { check(`rejeu de ${f} sans erreur`, false, e.message); }
  }
  check('rejeu : stocks des variantes et des annonces inchangés', JSON.stringify(await qs(`select id, stock, active from listing_variants order by id`)) === snap && JSON.stringify(await qs(`select id, stock from listings order by id`)) === snapL);
  await as(U(3));
  await works('rejeu : la fiche produit existante (product_detail) répond toujours', `select product_detail('${LA}') r`, (r) => r[0].r.found === true);

  await sup();
  console.log(`\nH12 STOCK : ${ok} OK, ${ko} ECHEC`);
}
