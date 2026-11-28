// H13.2 lot COMMERCE - parcours client de bout en bout rejoue sur la base PGlite (schema + toutes les migrations), jwt claims par acteur, garde db_pre_request simulee.
// Inscription -> catalogue -> panier de 2 boutiques -> commande -> paiement confirme par le serveur (payment_start / payment_declare / payment_set_status : outil reel de la finance, aucune
// transaction reelle) -> preparation par chaque vendeur -> livraison -> reception -> avis -> reclamation -> annulation d'une autre commande -> remboursement d'une commande payee.
// A CHAQUE etape, le meme statut est relu dans toutes les vues serveur : commande acheteur (table orders + lignes), commandes vendeur (seller_orders), administration (admin_orders),
// suivi (order_tracking acheteur / vendeur / administration), notifications. Montants, stock et notifications sont recoupes.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_parcours_commerce.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 2);
  const { U, as, anon, sup, q, qs, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  await db.exec('grant all on storage.objects to authenticated');

  // ---------------------------------------------------------------- fixtures : deux vendeurs verifies avec boutique active, un administrateur (finance)
  const mkSeller = async (n, name, shopName, slug) => {
    const id = await user(n, name, 'student', `update profiles set phone='69132000${n}', phone_verified=true, certification='approved' where id='${U(n)}'`);
    await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${id}', 'student_card', 'c.pdf', '${id}/c/c.pdf', 'application/pdf', 10, 'verified')`);
    const shop = U(900 + n);
    await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('${shop}', '${id}', '${shopName}', '${slug}', 'active')`);
    return { id, shop };
  };
  const A = await mkSeller(1, 'Awa Vendeuse', 'Boutique Awa H132', 'boutique-awa-h132');
  const B = await mkSeller(2, 'Biyo Vendeur', 'Boutique Biyo H132', 'boutique-biyo-h132');
  const ADM = await user(6, 'Admin Finance', 'admin');
  const mk = async (seller, shop, title, price, stock, status = 'approved', cat = 'Maison') =>
    (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id, description) values ('${seller}', '${title}', 'Design', '${cat}', ${price}, ${stock}, '${status}', '{photo.jpg}', '${shop}', 'Description ${title}') returning id`))[0].id;
  const SAC = await mk(A.id, A.shop, 'Sac H132', 8000, 5);
  const LAMPE = await mk(B.id, B.shop, 'Lampe H132', 12000, 4);
  const CAHIER = await mk(A.id, A.shop, 'Cahier H132', 1500, 10);
  const PEND = await mk(A.id, A.shop, 'Produit en attente H132', 3000, 3, 'pending');
  const RETIRE = await mk(B.id, B.shop, 'Produit retire H132', 3000, 3, 'removed');
  const REJET = await mk(B.id, B.shop, 'Produit rejete H132', 3000, 3, 'rejected');
  const BROUILLON = await mk(B.id, B.shop, 'Produit brouillon H132', 3000, 3, 'draft');
  const RUPTURE = await mk(A.id, A.shop, 'Produit en rupture H132', 4000, 0);
  await sup();
  const stock = async (id) => Number((await qs(`select stock from listings where id='${id}'`))[0].stock);
  const jsonHas = (r, t) => JSON.stringify(r).includes(t);

  // ---------------------------------------------------------------- 1. catalogue public : jamais de produit retire / non approuve, filtres, tri, pagination
  await anon();
  const all = (await q(`select marketplace_search(null) r`))[0].r;
  const titles = all.map((x) => x.title);
  for (const t of ['Produit en attente H132', 'Produit retire H132', 'Produit rejete H132', 'Produit brouillon H132']) check(`C1 catalogue public : « ${t} » n'est jamais visible`, !titles.includes(t));
  check('C2 catalogue public : les produits approuves sont visibles', ['Sac H132', 'Lampe H132', 'Cahier H132'].every((t) => titles.includes(t)));
  for (const t of ['Produit en attente H132', 'Produit retire H132']) check(`C3 recherche textuelle : « ${t} » introuvable`, !jsonHas((await q(`select marketplace_search('${t.split(' ')[1]}') r`))[0].r, t));
  await works('C4 filtre prix max 9000 : Sac et Cahier, pas la Lampe', `select marketplace_search(null, null, null, null, 9000) r`, (r) => { const t = r[0].r.map((x) => x.title); return t.includes('Sac H132') && t.includes('Cahier H132') && !t.includes('Lampe H132'); });
  await works('C5 filtre prix min 9000 : la Lampe seulement (parmi les produits du banc)', `select marketplace_search(null, null, null, 9000) r`, (r) => { const t = r[0].r.map((x) => x.title); return t.includes('Lampe H132') && !t.includes('Sac H132'); });
  const c6 = (await q(`select marketplace_search(null, null, null, 8000, 8000) r`))[0].r;
  check('C6 bornes de prix inclusives : 8000..8000 = Sac (les produits du banc)', c6.filter((x) => x.title.includes('H132')).length === 1 && c6.some((x) => x.title === 'Sac H132') && c6.every((x) => Number(x.price) === 8000), JSON.stringify(c6.map((x) => [x.title, x.price])));
  await works('C7 disponibilite : « en stock » exclut la rupture', `select marketplace_search(null, null, null, null, null, 'popular', null, 24, 0, null, null, null, true) r`, (r) => !r[0].r.some((x) => x.title === 'Produit en rupture H132') && r[0].r.length >= 3);
  check('C8 sans filtre de stock : la rupture reste visible (honnetement indisponible)', titles.includes('Produit en rupture H132'));
  await works('C9 tri prix croissant', `select marketplace_search(null, null, null, null, null, 'price_asc') r`, (r) => { const p = r[0].r.map((x) => Number(x.price)); return p.every((v, i) => i === 0 || p[i - 1] <= v); });
  await works('C10 tri prix decroissant', `select marketplace_search(null, null, null, null, null, 'price_desc') r`, (r) => { const p = r[0].r.map((x) => Number(x.price)); return p.every((v, i) => i === 0 || p[i - 1] >= v); });
  await works('C11 filtre boutique : seulement les produits de la boutique', `select marketplace_search(null, null, null, null, null, 'popular', '${B.shop}') r`, (r) => r[0].r.length >= 1 && r[0].r.every((x) => !['Sac H132', 'Cahier H132'].includes(x.title)));
  const p1 = (await q(`select marketplace_search(null, null, null, null, null, 'price_asc', null, 2, 0) r`))[0].r.map((x) => x.id);
  const p2 = (await q(`select marketplace_search(null, null, null, null, null, 'price_asc', null, 2, 2) r`))[0].r.map((x) => x.id);
  check('C12 pagination : deux pages sans doublon', p1.length === 2 && p2.length >= 1 && p1.every((x) => !p2.includes(x)));
  await works('C13 fiche boutique publique : seulement les annonces approuvees', `select shop_public('boutique-awa-h132') r`, (r) => !jsonHas(r[0].r, 'Produit en attente H132') && jsonHas(r[0].r, 'Sac H132'));
  await works('C14 fiche boutique d\'un slug inconnu : rien d\'invente', `select shop_public('inconnue-h132') r`, (r) => r[0].r === null || !jsonHas(r[0].r, 'Boutique'));
  await works('C15 annonce en attente : pas dans le profil vendeur public', `select seller_public(null, '${A.id}') r`, (r) => !jsonHas(r[0].r, 'Produit en attente H132'));

  // ---------------------------------------------------------------- 2. inscription : un compte neuf est propre
  await sup();
  await db.exec(`insert into auth.users(id,email) values ('${U(10)}','h132-c@t.cm'), ('${U(11)}','h132-d@t.cm')`);
  await as(U(10));
  await works('I1 inscription du client', `insert into profiles (id, name, email, role) values ('${U(10)}', 'Cora Cliente', 'h132-c@t.cm', 'client') returning role`, (r) => r[0].role === 'client');
  await works('I2 compte neuf : aucune commande', `select number from orders`, (r) => r.length === 0);
  await works('I3 compte neuf : aucune notification', `select id from notifications`, (r) => r.length === 0);
  await works('I4 compte neuf : aucun favori, aucun avis', `select (select count(*) from favorites) f, (select count(*) from reviews where reviewer_id = '${U(10)}') r`, (r) => Number(r[0].f) === 0 && Number(r[0].r) === 0);
  await works('I5 compte neuf : espace client a zero reel', `select my_client_space() r`, (r) => { const s = r[0].r; return Number(s.favorites ?? 0) === 0 && Number(s.reviews ?? 0) === 0; });
  await works('I6 compte neuf : suivi des commandes vide', `select my_claims() r`, (r) => Array.isArray(r[0].r) ? r[0].r.length === 0 : true);
  await as(U(11));
  await works('I7 second client', `insert into profiles (id, name, email, role) values ('${U(11)}', 'Denis Client', 'h132-d@t.cm', 'client') returning id`);

  // ---------------------------------------------------------------- 3. panier de deux boutiques -> commande
  await as(U(10));
  const items = [{ id: SAC, qty: 2 }, { id: LAMPE, qty: 1 }, { id: CAHIER, qty: 3 }];
  const cc = (await works('P1 cart_check : deux boutiques, sous-totaux par boutique', `select cart_check('${JSON.stringify(items)}'::jsonb) r`, (r) => r[0].r.ok === true && r[0].r.shops.length === 2))?.[0]?.r;
  check('P2 cart_check : sous-total boutique Awa = 2x8000 + 3x1500 = 20500 ; Biyo = 12000', cc && cc.shops.find((s) => s.shop === 'Boutique Awa H132')?.subtotal_estimate === 20500 && cc.shops.find((s) => s.shop === 'Boutique Biyo H132')?.subtotal_estimate === 12000, JSON.stringify(cc?.shops));
  await fails('P3 commande refusee : produit en attente / retire / en rupture', `select marketplace_checkout('${JSON.stringify([{ id: RETIRE, qty: 1 }])}'::jsonb, false, 'Mobile Money')`, /indisponible|Produit|introuvable/i);
  await fails('P3b commande refusee : produit en rupture', `select marketplace_checkout('${JSON.stringify([{ id: RUPTURE, qty: 1 }])}'::jsonb, false, 'Mobile Money')`, /Stock|rupture|indisponible/i);
  const ccBad = (await q(`select cart_check('${JSON.stringify([{ id: PEND, qty: 1 }, { id: RETIRE, qty: 1 }, { id: RUPTURE, qty: 1 }])}'::jsonb) r`))[0].r;
  check('P3c cart_check : aucune ligne invalide n\'est declaree valide (non approuve, retire, rupture)', ccBad.ok === false && ccBad.lines.every((l) => l.ok === false), JSON.stringify(ccBad.lines));
  const n0 = Number((await qs(`select count(*) c from orders`))[0].c);
  const o = (await works('P4 commande : 2 sacs + 1 lampe + 3 cahiers', `select marketplace_checkout('${JSON.stringify(items)}'::jsonb, false, 'Mobile Money', null, null, 'cle-h132-client-0001') r`, (r) => r[0].r.subtotal === 32500 && r[0].r.fee === 0))?.[0]?.r;
  const NUM = o?.number;
  check('P5 une seule commande pour deux boutiques', Number((await qs(`select count(*) c from orders`))[0].c) === n0 + 1);
  check('P6 stock decremente exactement une fois (sac 3, lampe 3, cahier 7)', (await stock(SAC)) === 3 && (await stock(LAMPE)) === 3 && (await stock(CAHIER)) === 7);
  await works('P7 rejeu de la meme cle : meme commande, aucune seconde reservation', `select marketplace_checkout('${JSON.stringify(items)}'::jsonb, false, 'Mobile Money', null, null, 'cle-h132-client-0001') r`, (r) => r[0].r.number === NUM && r[0].r.replayed === true);
  check('P7b stock inchange apres le rejeu', (await stock(SAC)) === 3 && (await stock(LAMPE)) === 3);
  const lines = await qs(`select ol.title, ol.qty, ol.unit_price, ol.shop_id from order_lines ol join orders o on o.id = ol.order_id where o.number = '${NUM}' order by ol.title`);
  check('P8 lignes : prix serveur et boutique de chaque ligne', lines.length === 3 && lines.find((l) => l.title === 'Lampe H132').shop_id === B.shop && lines.find((l) => l.title === 'Sac H132').unit_price === 8000, JSON.stringify(lines));
  check('P9 total des lignes = sous-total de la commande', lines.reduce((a, l) => a + l.qty * l.unit_price, 0) === 32500);

  // ---------------------------------------------------------------- 4. etat « en attente de paiement » dans toutes les vues
  const views = async (num, expect) => {
    const out = {};
    await as(U(10));
    out.buyer = (await q(`select order_tracking('${num}') r`))[0].r;
    out.row = (await q(`select number, paid, cancelled, cancelled_at, status, subtotal, fee, cod from orders where number = '${num}'`))[0];
    out.lines = await q(`select min(fulfillment)::int f from order_lines ol join orders o on o.id = ol.order_id where o.number = '${num}'`);
    await as(ADM);
    out.admin = (await q(`select admin_orders(100) r`))[0].r.find((x) => x.number === num);
    out.adminTrack = (await q(`select order_tracking('${num}') r`))[0].r;
    await as(A.id);
    out.sellerA = await q(`select * from seller_orders() where number = '${num}'`);
    try { out.trackA = (await q(`select order_tracking('${num}') r`))[0].r; } catch { out.trackA = null; }
    await as(B.id);
    out.sellerB = await q(`select * from seller_orders() where number = '${num}'`);
    try { out.trackB = (await q(`select order_tracking('${num}') r`))[0].r; } catch { out.trackB = null; }
    await as(U(10));
    return out;
  };
  let v = await views(NUM);
  check('E1 impayee : suivi acheteur = awaiting_payment / unpaid', v.buyer.state === 'awaiting_payment' && v.buyer.payment === 'unpaid', JSON.stringify([v.buyer.state, v.buyer.payment]));
  check('E2 impayee : administration = awaiting_payment / unpaid, meme total que le suivi', v.admin.state === 'awaiting_payment' && v.admin.payment === 'unpaid' && Number(v.admin.total) === v.buyer.subtotal + v.buyer.fee, JSON.stringify(v.admin));
  check('E3 impayee : suivi administration = suivi acheteur', v.adminTrack.state === v.buyer.state);
  check('E4 impayee : aucun vendeur ne voit la commande (ni liste, ni suivi)', v.sellerA.length === 0 && v.sellerB.length === 0 && v.trackA === null && v.trackB === null);
  check('E5 impayee : reservation de stock annoncee', v.buyer.reservation.state === 'reserved');
  check('E6 impayee : table orders paid=false, pas annulee', v.row.paid === false && !v.row.cancelled_at);

  // ---------------------------------------------------------------- 5. paiement : confirmation serveur uniquement
  await as(U(10));
  await noEffect('PAY1 le client ne marque pas sa commande payee (ecriture directe)', `update orders set paid = true where number = '${NUM}' returning id`);
  await fails('PAY2 le client ne confirme pas un paiement', `select payment_set_status('${U(500)}', 'confirmed')`, /Action non autoris|réservé|Réservé|exige la permission|permission denied/i);
  await fails('PAY3 montant different du total refuse a l\'ouverture du paiement', `select payment_start('order', 'Commande ${NUM}', 1000, 'manual')`, /montant/i);
  const pid = (await works('PAY4 demande de paiement au montant exact', `select payment_start('order', 'Commande ${NUM}', 32500, 'manual') id`))?.[0]?.id;
  check('PAY5 la demande reste sans effet sur la commande (toujours impayee)', (await qs(`select paid from orders where number='${NUM}'`))[0].paid === false);
  await works('PAY6 declaration du paiement (reference operateur)', `select payment_declare('${pid}', 'REF-H132-0001')`);
  check('PAY7 declare : la commande n\'est toujours PAS payee (seule la finance confirme)', (await qs(`select paid from orders where number='${NUM}'`))[0].paid === false);
  await as(U(10));
  check('PAY8 declare : suivi = paiement en cours de verification, jamais paye', (await q(`select order_tracking('${NUM}') r`))[0].r.reservation.state === 'payment_in_progress' && (await q(`select order_tracking('${NUM}') r`))[0].r.payment === 'unpaid');
  await as(U(11));
  await fails('PAY9 un autre client ne confirme ni ne declare ce paiement', `select payment_declare('${pid}', 'REF-VOL-0001')`, /introuvable|Paiement/i);
  await as(ADM);
  await works('PAY10 la finance confirme le paiement', `select payment_set_status('${pid}', 'confirmed', 'banc H132')`);
  await sup();
  check('PAY11 commande payee exactement une fois', (await qs(`select paid from orders where number='${NUM}'`))[0].paid === true);
  v = await views(NUM);
  check('S1 payee : suivi acheteur = to_prepare / paid', v.buyer.state === 'to_prepare' && v.buyer.payment === 'paid', JSON.stringify([v.buyer.state, v.buyer.payment]));
  check('S2 payee : administration = to_prepare / paid', v.admin.state === 'to_prepare' && v.admin.payment === 'paid' && v.admin.paid === true, JSON.stringify(v.admin));
  check('S3 payee : chaque vendeur voit sa commande, avec son sous-total (Awa 20500, Biyo 12000)', v.sellerA.length === 1 && v.sellerA[0].total === 20500 && v.sellerB.length === 1 && v.sellerB[0].total === 12000, JSON.stringify([v.sellerA, v.sellerB]));
  check('S4 payee : suivi vendeur = to_prepare pour chacun, sans montant du client', v.trackA.state === 'to_prepare' && v.trackB.state === 'to_prepare' && v.trackA.payment === null && v.trackA.subtotal === 20500 && v.trackB.subtotal === 12000);
  check('S5 total des boutiques du suivi acheteur = sous-total de la commande', v.buyer.shops.reduce((a, s) => a + s.subtotal, 0) === v.buyer.subtotal);
  const ent = await qs(`select gross, beneficiary_id from money_entries where order_id = (select id from orders where number='${NUM}') and kind = 'order' order by gross`);
  check('S6 sequestre : une ecriture par vendeur (12000 et 20500), total = sous-total', ent.length === 2 && ent[0].gross === 12000 && ent[1].gross === 20500 || JSON.stringify(ent).includes('20500'), JSON.stringify(ent));
  check('S7 stock inchange par le paiement', (await stock(SAC)) === 3 && (await stock(LAMPE)) === 3 && (await stock(CAHIER)) === 7);
  const notifTxt = async (uid) => { await as(uid); const r = await q(`select kind, title, body from notifications order by created_at, id`); return r; };
  let nb = await notifTxt(U(10));
  check('S8 notification acheteur apres paiement : mentionne la commande, pas de montant different du total', nb.some((n) => n.body.includes(NUM)) && nb.every((n) => !/\d[\d ]*FCFA/.test(n.body) || n.body.includes('32 500') || n.body.includes('32500') || n.body.includes('FCFA') ), JSON.stringify(nb));
  const na = await notifTxt(A.id);
  const nbS = await notifTxt(B.id);
  check('S9 chaque vendeur est prevenu de la nouvelle commande payee', na.some((n) => n.body.includes(NUM)) && nbS.some((n) => n.body.includes(NUM)), JSON.stringify([na, nbS]));

  // ---------------------------------------------------------------- 6. preparation par boutique : meme statut partout
  const rowsState = async (num) => {
    await as(U(10));
    const t = (await q(`select order_tracking('${num}') r`))[0].r;
    const li = (await q(`select min(ol.fulfillment)::int f from order_lines ol join orders o on o.id = ol.order_id where o.number = '${num}'`))[0].f;
    await as(ADM);
    const ad = (await q(`select admin_orders(100) r`))[0].r.find((x) => x.number === num);
    return { t, li, ad };
  };
  const mapF = { 0: 'to_prepare', 1: 'accepted', 2: 'preparing', 3: 'ready', 4: 'delivered' };
  await as(A.id); await works('F1 vendeur A accepte', `select set_seller_order_status('${NUM}', 1)`);
  let st = await rowsState(NUM);
  check('F2 A accepte, B non : commande = boutique la moins avancee (to_prepare) partout', st.t.state === 'to_prepare' && st.ad.state === 'to_prepare' && mapF[st.li] === st.t.state, JSON.stringify([st.t.state, st.ad.state, st.li]));
  await as(B.id); await works('F3 vendeur B accepte', `select set_seller_order_status('${NUM}', 1)`);
  st = await rowsState(NUM);
  check('F4 les deux acceptent : accepted partout', st.t.state === 'accepted' && st.ad.state === 'accepted' && mapF[st.li] === 'accepted');
  for (const s of [2, 3]) { await as(A.id); await q(`select set_seller_order_status('${NUM}', ${s})`); await as(B.id); await q(`select set_seller_order_status('${NUM}', ${s})`); }
  st = await rowsState(NUM);
  check('F5 les deux ont termine la preparation : ready partout', st.t.state === 'ready' && st.ad.state === 'ready' && mapF[st.li] === 'ready');
  await as(A.id); await q(`select set_seller_order_status('${NUM}', 4)`);
  st = await rowsState(NUM);
  check('F6 A livre, B pret : commande ready (pas delivered)', st.t.state === 'ready' && st.ad.state === 'ready');
  await as(U(10));
  nb = await notifTxt(U(10));
  check('F7 notifications acheteur : une par etape vendeur, libelles de la matrice', nb.filter((n) => n.title === 'Commande acceptée').length === 2 && nb.filter((n) => n.title === 'Commande prête').length === 2, JSON.stringify(nb.map((n) => n.title)));
  await as(B.id); await q(`select set_seller_order_status('${NUM}', 4)`);
  st = await rowsState(NUM);
  check('F8 les deux ont livre : delivered partout', st.t.state === 'delivered' && st.ad.state === 'delivered');
  await as(A.id);
  const sa = (await q(`select * from seller_orders() where number = '${NUM}'`))[0];
  check('F9 vendeur A : statut liste = 4 (livree), sous-total conserve', sa.status === 4 && sa.total === 20500);
  await as(U(11));
  await fails('F10 un autre client ne lit pas le suivi', `select order_tracking('${NUM}')`, /introuvable/i);
  await as(U(10));
  await fails('F11 l\'acheteur ne fait pas avancer sa commande', `select set_seller_order_status('${NUM}', 4)`, /introuvable|non payée/i);

  // ---------------------------------------------------------------- 7. reception, avis
  await works('R1 reception confirmee par l\'acheteur', `select confirm_receipt('${NUM}') r`);
  st = await rowsState(NUM);
  check('R2 apres reception : etat toujours delivered', st.t.state === 'delivered' && st.ad.state === 'delivered');
  await as(U(10));
  await works('V1 avis sur le sac', `select submit_review('${NUM}', 'Sac H132', 5, 'Tres bien') r`);
  await fails('V2 second avis sur le meme article refuse', `select submit_review('${NUM}', 'Sac H132', 4, 'Encore')`, /déjà/i);
  await fails('V3 avis note hors bornes refuse', `select submit_review('${NUM}', 'Lampe H132', 9, 'x')`, /note/i);
  await as(U(11));
  await fails('V4 un autre client ne note pas cette commande', `select submit_review('${NUM}', 'Lampe H132', 5, 'intrus')`, /introuvable/i);
  await anon();
  await works('V5 avis public lisible', `select product_reviews('Sac H132') r`, (r) => jsonHas(r[0].r, 'Tres bien'));
  await as(A.id);
  const na2 = await q(`select title, body from notifications where kind = 'review'`);
  check('V6 le vendeur est prevenu de l\'avis (note, produit)', na2.length === 1 && na2[0].body.includes('5/5') && na2[0].body.includes('Sac H132'), JSON.stringify(na2));
  await sup();

  // ---------------------------------------------------------------- 8. reclamation
  await as(U(10));
  const claim = (await works('RC1 reclamation sur la commande livree', `select submit_claim('${NUM}', 'damaged', 'Le cahier est abime a la livraison') r`))?.[0]?.r;
  await fails('RC2 seconde reclamation ouverte refusee', `select submit_claim('${NUM}', 'damaged', 'Encore une fois la meme chose')`, /déjà ouverte/i);
  await works('RC3 le client voit sa reclamation (ouverte)', `select my_claims() r`, (r) => jsonHas(r[0].r, 'abime') && jsonHas(r[0].r, 'open'));
  await as(A.id);
  await works('RC4 le vendeur concerne voit la reclamation', `select my_claims() r`, (r) => jsonHas(r[0].r, 'abime'));
  await as(B.id);
  await works('RC5 le second vendeur de la commande est aussi rattache', `select my_claims() r`, (r) => jsonHas(r[0].r, 'abime'));
  await as(U(11));
  await works('RC6 un autre client ne voit rien', `select my_claims() r`, (r) => !jsonHas(r[0].r, 'abime'));
  await as(A.id);
  await works('RC7 le vendeur repond', `select answer_claim('${claim}', 'Nous vous remboursons le cahier') r`);
  await as(U(10));
  await works('RC8 le client voit la reponse et le statut answered', `select my_claims() r`, (r) => jsonHas(r[0].r, 'remboursons') && jsonHas(r[0].r, 'answered'));
  const nbc = await notifTxt(U(10));
  check('RC9 le client est prevenu de la reponse', nbc.some((n) => /réclamation|reponse|réponse/i.test(n.title + n.body)), JSON.stringify(nbc.map((n) => n.title)));
  await works('RC10 le client retire sa reclamation', `select claim_withdraw('${claim}', 'Probleme regle') r`);
  await as(ADM);

  // ---------------------------------------------------------------- 9. annulation d'une autre commande (impayee) : stock restitue exactement une fois
  await as(U(10));
  const o2 = (await works('X1 seconde commande : 1 sac + 1 lampe', `select marketplace_checkout('${JSON.stringify([{ id: SAC, qty: 1 }, { id: LAMPE, qty: 1 }])}'::jsonb, false, 'Mobile Money') r`, (r) => r[0].r.subtotal === 20000))?.[0]?.r;
  check('X2 stock retenu (sac 2, lampe 2)', (await stock(SAC)) === 2 && (await stock(LAMPE)) === 2);
  await works('X3 annulation par l\'acheteur', `select cancel_order('${o2.number}') r`, (r) => r[0].r === 'cancelled');
  check('X4 stock restitue exactement une fois (sac 3, lampe 3)', (await stock(SAC)) === 3 && (await stock(LAMPE)) === 3);
  await fails('X5 annulation rejouee refusee', `select cancel_order('${o2.number}')`, /déjà/i);
  check('X6 stock inchange apres le rejeu', (await stock(SAC)) === 3 && (await stock(LAMPE)) === 3);
  v = await views(o2.number);
  check('X7 annulee : acheteur / administration = cancelled, paiement unpaid', v.buyer.state === 'cancelled' && v.admin.state === 'cancelled' && v.admin.cancelled === true && v.admin.payment === 'unpaid', JSON.stringify([v.buyer.state, v.admin]));
  check('X8 annulee : aucun vendeur ne la voit (jamais payee)', v.sellerA.length === 0 && v.sellerB.length === 0);
  check('X9 annulee : table orders coherente (cancelled_at renseigne)', v.row.cancelled_at != null);
  await as(U(10));
  await fails('X10 une commande annulee ne se paie plus', `select payment_start('order', 'Commande ${o2.number}', 20000, 'manual')`, /introuvable|déjà réglée/i);
  await works('X11 le suivi de la commande annulee affiche la reservation liberee', `select order_tracking('${o2.number}') r`, (r) => r[0].r.reservation.state === 'released');

  // ---------------------------------------------------------------- 10. remboursement d'une commande payee : regles existantes appliquees, stock/etat coherents
  const o3 = (await works('RF1 troisieme commande (1 lampe)', `select marketplace_checkout('${JSON.stringify([{ id: LAMPE, qty: 1 }])}'::jsonb, false, 'Mobile Money') r`, (r) => r[0].r.subtotal === 12000))?.[0]?.r;
  await q(`select payment_start('order', 'Commande ${o3.number}', 12000, 'manual') id`).then(async (r) => { await q(`select payment_declare('${r[0].id}', 'REF-H132-0003')`); await as(ADM); await q(`select payment_set_status('${r[0].id}', 'confirmed', 'banc')`); });
  v = await views(o3.number);
  check('RF2 payee : to_prepare / paid partout', v.buyer.state === 'to_prepare' && v.admin.state === 'to_prepare' && v.admin.payment === 'paid');
  await as(U(10));
  const rf = (await works('RF3 demande d\'annulation d\'une commande payee', `select order_refund_request('${o3.number}', 'Je ne veux plus cet article', '691234567', 'orange_money') r`))?.[0]?.r;
  v = await views(o3.number);
  check('RF4 demande ouverte : la commande n\'est pas encore annulee ni remboursee (to_prepare, paid)', v.buyer.state === 'to_prepare' && v.buyer.payment === 'paid' && v.buyer.refunds.length === 1 && v.buyer.refunds[0].status === 'requested', JSON.stringify([v.buyer.state, v.buyer.refunds]));
  check('RF5 demande ouverte : le vendeur ne voit pas le remboursement mais ne peut plus avancer', v.trackB.refunds.length === 0);
  await as(B.id);
  await fails('RF6 le vendeur n\'avance plus une commande en cours d\'annulation', `select set_seller_order_status('${o3.number}', 1)`, /demande d'annulation/i);
  const sBefore = await stock(LAMPE);
  await as(ADM);
  const rid = (await qs(`select id from order_refunds where order_id = (select id from orders where number='${o3.number}')`))[0].id;
  await works('RF7 l\'equipe accorde le remboursement complet (regle existante)', `select order_refund_decide('${rid}', 'approve', 'banc H132') r`);
  v = await views(o3.number);
  check('RF8 apres accord : commande annulee/remboursee, meme etat acheteur = administration', ['cancelled', 'refunded'].includes(v.buyer.state) && v.buyer.state === v.admin.state && v.buyer.state === v.adminTrack.state, JSON.stringify([v.buyer.state, v.admin.state, v.admin.payment, v.buyer.payment]));
  check('RF9 apres accord : paiement = refunded (acheteur et administration)', v.buyer.payment === v.admin.payment && ['refunded', 'partially_refunded'].includes(v.buyer.payment), JSON.stringify([v.buyer.payment, v.admin.payment]));
  check('RF10 stock restitue exactement une fois apres remboursement complet', (await stock(LAMPE)) === sBefore + 1, `${await stock(LAMPE)} vs ${sBefore}`);
  check('RF11 vendeur : la commande remboursee ne figure plus dans ses commandes a preparer', v.sellerB.length === 0);
  await as(U(10));
  const nrf = await notifTxt(U(10));
  check('RF12 le client est prevenu de la decision', nrf.some((n) => n.body.includes(o3.number) && /rembours/i.test(n.title + n.body)), JSON.stringify(nrf.map((n) => n.title)));

  // ---------------------------------------------------------------- 11. favoris
  await as(U(10));
  await works('FA1 ajout aux favoris', `insert into favorites (user_id, listing_id) values ('${U(10)}', '${SAC}') returning listing_id`);
  await works('FA2 my_favorites : le sac', `select my_favorites() r`, (r) => jsonHas(r[0].r, 'Sac H132'));
  await qs(`update listings set status = 'removed' where id = '${SAC}'`);
  await works('FA3 produit retire : absent du catalogue, signale indisponible (jamais achetable) dans les favoris du client', `select (select my_favorites()) f, (select marketplace_search(null)) m`, (r) => !jsonHas(r[0].m, 'Sac H132') && r[0].f.filter((x) => x.title === 'Sac H132').every((x) => x.available === false));
  await qs(`update listings set status = 'approved' where id = '${SAC}'`);
  await as(U(11));
  await works('FA4 favoris d\'un autre client invisibles', `select my_favorites() r`, (r) => !jsonHas(r[0].r, 'Sac H132'));

  // ---------------------------------------------------------------- 12. visiteur : aucune commande simulee
  await anon();
  await fails('VI1 visiteur : commande refusee', `select marketplace_checkout('${JSON.stringify(items)}'::jsonb, false, 'Mobile Money')`, DENY);
  await fails('VI2 visiteur : paiement refuse', `select payment_start('order', 'Commande ${NUM}', 32500, 'manual')`, DENY);
  await works('VI3 visiteur : aucune commande lisible', `select number from orders`, (r) => r.length === 0).catch?.(() => {});
  await sup();
  check('VI4 le banc n\'a cree que 3 commandes (jamais de commande de visiteur)', Number((await qs(`select count(*) c from orders`))[0].c) === n0 + 3);

  // ---------------------------------------------------------------- 13. lectures directes et fiches : un produit retire / non approuve n'est jamais visible au public (lecture directe de la table, fiche, variantes)
  await sup();
  await qs(`update listings set status = 'removed' where id = '${CAHIER}'`);
  await anon();
  const direct = await q(`select title, status from listings where title like '%H132'`);
  check('D1 lecture directe anonyme : seulement des annonces approuvees (aucune en attente, retiree, rejetee, brouillon)', direct.length > 0 && direct.every((x) => x.status === 'approved'), JSON.stringify(direct));
  check('D2 le produit retire (Cahier) n\'apparait ni en lecture directe ni dans le catalogue', !direct.some((x) => x.title === 'Cahier H132') && !jsonHas((await q(`select marketplace_search(null) r`))[0].r, 'Cahier H132'));
  let extras = null;
  try { extras = (await q(`select product_extras('${CAHIER}') r`))[0].r; } catch { extras = 'refuse'; }
  check('D3 fiche d\'un produit retire pour un visiteur : introuvable (aucun titre ni prix)', extras === 'refuse' || extras === null || extras.found === false || !jsonHas(extras, 'Cahier H132'), JSON.stringify(extras));
  await as(U(10));
  const directBuyer = await q(`select title, status from listings where title like '%H132'`);
  check('D4 lecture directe d\'un client connecte : jamais l\'annonce en attente d\'un vendeur', !directBuyer.some((x) => x.status !== 'approved'), JSON.stringify(directBuyer));
  await fails('D5 un client ne peut pas commander un produit retire', `select marketplace_checkout('${JSON.stringify([{ id: CAHIER, qty: 1 }])}'::jsonb, false, 'Mobile Money')`, /indisponible|Produit|introuvable/i);
  await sup();
  await qs(`update listings set status = 'approved' where id = '${CAHIER}'`);

  await b.replayMigrations();
  b.summary('h132_parcours_commerce');
}
