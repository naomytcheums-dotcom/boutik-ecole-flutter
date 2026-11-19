// Scénario PGlite du lot K2 (20261121020000_k2_eligibilite_vendeur.sql) : éligibilité vendeur imposée côté SERVEUR.
// Éligible = rôle étudiant + étudiant vérifié (pièce validée ou certification) + téléphone vérifié + compte non suspendu.
// Chaque opération de vente est appelée DIRECTEMENT (RPC ou écriture) par un compte éligible (accepté) et par chaque compte non éligible (refusé).
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000060${String(n).padStart(2, '0')}`;
  const L = (n) => `00000000-0000-0000-0000-0000000061${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sup = () => db.exec('reset role');
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const cap = async (n) => { await as(U(n)); const r = (await q(`select my_seller_capability() c`))[0].c; await sup(); return r; };
  const REFUS = /Réservé aux étudiants|réservée aux étudiants|statut d.étudiant|téléphone|suspendu|row-level security|non éligible|plus éligible|Vendeur indisponible|pause|ne prend plus|n.accepte plus|inactif/i;

  await sup();
  // 1 client ; 2 étudiant non vérifié ; 3 pièce validée sans téléphone vérifié ; 4 ÉLIGIBLE (pièce + téléphone) ; 5 ÉLIGIBLE certifié ; 6 organisation ; 7 département ; 8 administrateur ;
  // 9 suspendu (pièce + téléphone) ; 10 acheteur ; 11 support ; 12 finance ; 13 direction ; 14 ÉLIGIBLE (pause / reprise) ; 15 « other » historique
  const roles = { 1: 'client', 2: 'student', 3: 'student', 4: 'student', 5: 'student', 6: 'company', 7: 'dept', 8: 'admin', 9: 'student', 10: 'client', 11: 'support', 12: 'finance', 13: 'direction', 14: 'student', 15: 'other', 16: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','k2${n}@t.cm'); insert into profiles(id,name,role,email,department) values ('${U(n)}','Compte K2 ${n}','${r}','k2${n}@t.cm','Genie')`);
    await db.exec(`update profiles set phone = '69060${String(n).padStart(4, '0')}', phone_verified = true where id = '${U(n)}'`);
  }
  const verifyDoc = (n) => db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  for (const n of [3, 4, 9, 14]) await verifyDoc(n);
  await db.exec(`update profiles set certification = 'approved' where id = '${U(5)}'`);
  await db.exec(`update profiles set phone_verified = false where id in ('${U(2)}', '${U(3)}')`);
  await db.exec(`update profiles set suspended = true where id = '${U(9)}'`);
  await db.exec(`update profiles set certification = 'approved' where id = '${U(14)}'`);
  const NON_ELIGIBLES = [[1, 'client'], [2, 'étudiant non vérifié'], [3, 'téléphone non vérifié'], [6, 'organisation'], [7, 'département'], [8, 'administrateur'], [9, 'suspendu'], [11, 'support'], [12, 'finance'], [13, 'direction'], [15, 'ancien « other »']];
  const ELIGIBLES = [4, 5, 14];

  // ============================================================ 1. seller_capable : règle unique
  for (const n of ELIGIBLES) check(`seller_capable : compte ${n} éligible`, (await cap(n)).can_sell === true);
  for (const [n, nom] of NON_ELIGIBLES) check(`seller_capable : ${nom} non éligible`, (await cap(n)).can_sell === false);
  check('my_seller_capability reprend seller_capable pour tous les comptes', (await q(`select bool_and((_seller_capability(p.id)->>'can_sell')::boolean = seller_capable(p.id)) b from profiles p`))[0].b === true);
  await as(U(4));
  await fails('seller_capable : fonction interne, pas appelable par un compte connecté', `select seller_capable('${U(5)}')`, /permission denied/);
  await fails('seller_open : fonction interne', `select seller_open('${U(5)}')`, /permission denied/);
  await as(null, 'anon');
  await fails('anonyme : my_seller_capability refusé', `select my_seller_capability()`, /permission denied/);
  await fails('anonyme : seller_pause refusé', `select seller_pause()`, /permission denied/);
  await fails('anonyme : seller_resume refusé', `select seller_resume()`, /permission denied/);

  // ============================================================ 2. Annonces : création / modification directes
  const ins = (uid, status = 'draft', title = 'Annonce K2', cat = 'Maison') => `insert into listings (seller_id, title, department, category, price, stock, status) values ('${uid}', '${title}', 'Genie', '${cat}', 5000, 3, '${status}') returning id`;
  for (const [n, nom] of NON_ELIGIBLES) {
    await as(U(n));
    await fails(`annonce : ${nom} ne crée pas d'annonce (brouillon)`, ins(U(n)), REFUS);
  }
  for (const n of [4, 5]) {
    await as(U(n));
    await works(`annonce : étudiant éligible ${n} crée un brouillon`, ins(U(n), 'draft', `Brouillon ${n}`), (r) => r.length === 1);
  }
  await as(U(4));
  await fails('annonce : publication (en validation) refusée sans certification (règle existante conservée)', ins(U(4), 'pending', 'Sans certif K2', 'Services'), /certifi/i);
  await as(U(5));
  await works('annonce : un étudiant éligible et certifié envoie en validation', ins(U(5), 'pending', 'Validation K2', 'Services'), (r) => r.length === 1);
  await sup();
  // un vendeur qui n'est plus éligible : plus de modification ni de publication, mais il peut retirer ses annonces
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values
    ('${L(1)}', '${U(2)}', 'Annonce non vérifié', 'Genie', 'Maison', 5000, 5, 'approved', '{}'),
    ('${L(2)}', '${U(3)}', 'Annonce sans téléphone', 'Genie', 'Maison', 5000, 5, 'approved', '{}')`);
  for (const [n, id] of [[2, 1], [3, 2]]) {
    await as(U(n));
    await fails(`annonce : vendeur ${n} non éligible ne modifie plus son prix`, `update listings set price = 6000 where id = '${L(id)}'`, REFUS);
    await fails(`annonce : vendeur ${n} non éligible ne modifie plus son stock`, `update listings set stock = 9 where id = '${L(id)}'`, REFUS);
    await works(`annonce : vendeur ${n} non éligible peut retirer son annonce`, `update listings set status = 'removed' where id = '${L(id)}' returning id`, (r) => r.length === 1);
  }
  await as(U(3));
  await fails('annonce : un brouillon ne repart pas en validation sans éligibilité', `update listings set status = 'pending' where id = '${L(2)}'`, /Annonce supprimée|Transition/);
  // administrateur / département : pas d'annonce à leur nom, mais les produits de plateforme (sans vendeur) restent gérables
  await sup();
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status) values ('${L(4)}', null, 'Produit plateforme K2', 'Genie', 'Fournitures', 3000, 10, 'approved')`);
  await as(U(8));
  await works('annonce : l\'administrateur modifie un produit de la plateforme (sans vendeur)', `update listings set stock = 11 where id = '${L(4)}' returning id`, (r) => r.length === 1);
  await sup();
  // validation d'une annonce par un valideur : refusée si le vendeur n'est plus éligible
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values
    ('${L(5)}', '${U(3)}', 'A valider non eligible', 'Genie', 'Maison', 5000, 5, 'pending', '{}'),
    ('${L(6)}', '${U(4)}', 'A valider eligible', 'Genie', 'Maison', 5000, 5, 'pending', '{}')`);
  await as(U(8));
  await fails('annonce : validation refusée pour un vendeur non éligible', `update listings set status = 'approved' where id = '${L(5)}'`, /plus éligible/);
  await works('annonce : validation acceptée pour un vendeur éligible', `update listings set status = 'approved' where id = '${L(6)}' returning id`, (r) => r.length === 1);

  // ============================================================ 3. Boutique et dépendances
  const shopJson = (nom) => `select shop_save('{"name":"${nom}","description":"Objets utiles","categories":["Maison"]}'::jsonb) s`;
  for (const [n, nom] of NON_ELIGIBLES) {
    await as(U(n));
    await fails(`boutique : ${nom} ne crée pas de boutique`, shopJson('Boutique refusée ' + n), REFUS);
  }
  await as(U(4));
  await works('boutique : étudiant éligible crée sa boutique', shopJson('Atelier K2 quatre'), (r) => r[0].s.status === 'draft');
  await sup();
  // boutiques actives posées par l'équipe pour les vendeurs 4 (éligible), 14 (pause) et 3 (non éligible)
  await db.exec(`insert into shops (owner_id, slug, name, status, description, logo_url, categories) values
    ('${U(14)}', 'atelier-k2-pause', 'Atelier K2 pause', 'active', 'x', 'https://x.supabase.co/storage/v1/object/public/a/b.png', '{Maison}'),
    ('${U(3)}', 'atelier-k2-trois', 'Atelier K2 trois', 'active', 'x', 'https://x.supabase.co/storage/v1/object/public/a/b.png', '{Maison}')`);
  await db.exec(`update shops set status = 'active' where owner_id = '${U(4)}'`);
  // validation d'une boutique par un valideur : refusée si le propriétaire n'est pas éligible, acceptée sinon
  await db.exec(`insert into shops (owner_id, slug, name, status, description, logo_url, categories) values
    ('${U(16)}', 'atelier-k2-deux', 'Atelier K2 deux', 'pending', 'x', 'https://x.supabase.co/storage/v1/object/public/a/b.png', '{Maison}'),
    ('${U(5)}', 'atelier-k2-cinq', 'Atelier K2 cinq', 'pending', 'x', 'https://x.supabase.co/storage/v1/object/public/a/b.png', '{Maison}')`);
  await as(U(8));
  await fails('boutique : validation refusée pour un propriétaire non éligible', `select shop_decide((select id from shops where owner_id = '${U(16)}'), 'approve')`, /plus éligible/);
  await works('boutique : validation acceptée pour un propriétaire éligible', `select shop_decide((select id from shops where owner_id = '${U(5)}'), 'approve') r`, (r) => r[0].r === 'active');
  await sup();
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images, shop_id) values
    ('${L(7)}', '${U(4)}', 'Lampe K2 A', 'Genie', 'Maison', 8000, 20, 'approved', '{}', (select id from shops where owner_id = '${U(4)}')),
    ('${L(8)}', '${U(4)}', 'Lampe K2 B', 'Genie', 'Maison', 9000, 20, 'approved', '{}', (select id from shops where owner_id = '${U(4)}')),
    ('${L(9)}', '${U(3)}', 'Chaise K2 trois', 'Genie', 'Maison', 7000, 20, 'approved', '{}', (select id from shops where owner_id = '${U(3)}'))`);
  await as(U(4));
  await works('boutique : l\'éligible modifie sa boutique active', shopJson('Atelier K2 quatre bis'), (r) => r[0].s.name === 'Atelier K2 quatre bis');
  await works('promotions : code promo accepté pour l\'éligible', `select promo_save('K2PROMO', 'percent', 10, 0, null, null, true, false) id`, (r) => !!r[0].id);
  await works('promotions : vente flash acceptée pour l\'éligible', `select flash_save('${L(7)}', 6000, 5, now(), now() + interval '2 days') id`, (r) => !!r[0].id);
  await works('promotions : pack accepté pour l\'éligible', `select pack_save('Pack K2', 'Deux lampes', 12000, '[{"listing":"${L(7)}","qty":1},{"listing":"${L(8)}","qty":1}]'::jsonb) id`, (r) => !!r[0].id);
  await works('promotions : campagne de boutique acceptée pour l\'éligible', `select campaign_save('Campagne K2', 'Rentrée', null, array['${L(7)}']::uuid[], now(), now() + interval '3 days') id`, (r) => !!r[0].id);
  await works('livraison : zone de livraison acceptée pour l\'éligible', `select delivery_zone_save('Douala', 1500, null, false, null) id`, (r) => !!r[0].id);
  await works('réglages : seuil de stock accepté pour l\'éligible', `select seller_settings_set(10, true, true) r`);
  await sup();
  const own = async (n) => (await q(`select id from shops where owner_id = '${U(n)}'`))[0]?.id;
  // vendeur 3 : boutique active, mais plus éligible (téléphone non vérifié)
  await as(U(3));
  await fails('boutique : vendeur non éligible ne modifie plus sa boutique', shopJson('Atelier K2 trois bis'), REFUS);
  await fails('promotions : code promo refusé', `select promo_save('K2NOPE', 'percent', 10, 0, null, null, true, false)`, REFUS);
  await fails('promotions : vente flash refusée', `select flash_save('${L(9)}', 5000, 5, now(), now() + interval '2 days')`, REFUS);
  await fails('promotions : campagne refusée', `select campaign_save('Campagne refusée', 'x', null, array['${L(9)}']::uuid[], now(), now() + interval '3 days')`, REFUS);
  await fails('livraison : zone de livraison refusée', `select delivery_zone_save('Yaoundé', 2000, null, false, null)`, REFUS);
  await fails('réglages : réglages vendeur refusés', `select seller_settings_set(5, true, true)`, REFUS);
  await works('boutique : le vendeur non éligible peut fermer sa boutique', `select shop_close() r`, (r) => r[0].r === 'closed');
  await sup();
  for (const [n, nom] of [[1, 'client'], [6, 'organisation'], [7, 'département'], [8, 'administrateur']]) {
    await as(U(n));
    await fails(`promotions : ${nom} refusé (code promo)`, `select promo_save('K2X${n}', 'percent', 10, 0, null, null, true, false)`, /boutique|Réservé|introuvable|Action|plateforme|refus|permission|étudiants/i);
  }
  // une promotion existante peut toujours être désactivée par un vendeur devenu non éligible
  await sup();
  const promoId = (await q(`select id from promo_codes where code = 'K2PROMO'`))[0].id;
  await db.exec(`update profiles set phone_verified = false where id = '${U(4)}'`);
  await as(U(4));
  await works('promotions : un vendeur devenu non éligible désactive encore sa promotion', `select promo_toggle('${promoId}', false) r`, (r) => r[0].r === false);
  await fails('promotions : mais ne la réactive pas', `select promo_toggle('${promoId}', true)`, REFUS);
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(4)}'`);

  // ============================================================ 4. Services : devis côté prestataire
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values
    ('${L(10)}', '${U(4)}', 'Service K2 logo', 'Genie', 'Services', 20000, 1, 'approved', '{}'),
    ('${L(11)}', '${U(3)}', 'Service K2 sans telephone', 'Genie', 'Services', 20000, 1, 'approved', '{}')`);
  await as(U(10));
  const quoteOk = (await q(`select request_quote_offer('${L(10)}', 'Un logo pour mon association', 30000, '3 semaines') id`))[0].id;
  await fails('devis : nouvelle demande adressée à un prestataire non éligible refusée', `select request_quote_offer('${L(11)}', 'Un logo pour mon club de sport', 30000, '3 semaines')`, /ne prend plus de demandes|plus disponible|devis/i);
  await as(U(4));
  await works('devis : le prestataire éligible répond', `select answer_quote('${quoteOk}', 25000, 7, 'Avec deux retouches') r`, (r) => r[0].r === 'quoted');
  await sup();
  await db.exec(`update profiles set phone_verified = false where id = '${U(4)}'`);
  await as(U(4));
  await fails('devis : le prestataire devenu non éligible ne révise plus son devis', `select answer_quote('${quoteOk}', 24000, 7, 'Nouvelle offre')`, REFUS);
  await works('devis : mais il peut décliner la demande', `select decline_quote('${quoteOk}', 'Indisponible') r`, (r) => r[0].r === 'rejected');
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(4)}'`);
  // réponses refusées pour chaque acteur non éligible (demande posée par l'équipe)
  for (const [n, nom] of [[2, 'étudiant non vérifié'], [3, 'téléphone non vérifié'], [1, 'client'], [6, 'organisation'], [7, 'département'], [8, 'administrateur'], [9, 'suspendu']]) {
    await sup();
    const lid = n === 3 ? L(11) : L(10);
    const qid = (await q(`insert into quote_requests (listing_id, requester_id, provider_id, brief) values ('${lid}', '${U(10)}', '${U(n)}', 'Demande posée par la fixture K2 ${n}') returning id`))[0].id;
    await as(U(n));
    await fails(`devis : ${nom} ne répond pas à un devis`, `select answer_quote('${qid}', 20000, 5, 'x')`, /Demande introuvable|statut|téléphone|suspendu|Réservé|pause|Votre compte/i);
  }
  // devis déjà accepté : la commande née du devis est refusée si le prestataire n'est plus éligible
  await sup();
  const qAcc = (await q(`insert into quote_requests (listing_id, requester_id, provider_id, brief, status, quote_amount, quote_delay_days, valid_until) values ('${L(11)}', '${U(10)}', '${U(3)}', 'Devis accepté fixture K2', 'accepted', 20000, 5, now() + interval '5 days') returning id`))[0].id;
  await as(U(10));
  await fails('devis : commande au prix du devis refusée si le prestataire n\'est plus éligible', `select quote_checkout('${qAcc}')`, /Vendeur indisponible/);

  // ============================================================ 5. Nouvelles commandes
  const cart = (lid) => `[{"id":"${lid}","qty":1}]`;
  await as(U(10));
  const co = (await q(`select marketplace_checkout('${cart(L(7))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0001') r`))[0].r;
  check('commande : un acheteur commande chez un vendeur éligible', !!co.number, JSON.stringify(co));
  await sup();
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values ('${L(12)}', '${U(2)}', 'Objet vendeur non verifie', 'Genie', 'Maison', 5000, 5, 'approved', '{}'), ('${L(17)}', '${U(3)}', 'Objet vendeur sans telephone', 'Genie', 'Maison', 5000, 5, 'approved', '{}')`);
  await db.exec(`update profiles set suspended = false where id = '${U(9)}'`);
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values ('${L(13)}', '${U(9)}', 'Objet vendeur suspendu', 'Genie', 'Maison', 5000, 5, 'approved', '{}')`);
  await db.exec(`update profiles set suspended = true where id = '${U(9)}'`);
  await db.exec(`update listings set status = 'approved' where id = '${L(13)}'`);
  await as(U(10));
  await fails('commande : annonce d\'un vendeur dont le téléphone n\'est pas vérifié refusée', `select marketplace_checkout('${cart(L(17))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0002')`, /Vendeur indisponible/);
  await fails('commande : annonce d\'un étudiant non vérifié refusée', `select marketplace_checkout('${cart(L(12))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0003')`, /Vendeur indisponible/);
  await fails('commande : annonce d\'un vendeur suspendu refusée', `select marketplace_checkout('${cart(L(13))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0004')`, /Vendeur indisponible/);
  check('commande : le stock du vendeur refusé n\'a pas bougé', (await q(`select stock from listings where id = '${L(17)}'`))[0].stock === 5);
  await works('commande : un produit de la plateforme (sans vendeur) reste commandable', `select marketplace_checkout('${cart(L(4))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0005') r`, (r) => !!r[0].r.number);

  // ============================================================ 6. Commandes en cours : le vendeur devenu non éligible les termine
  await sup();
  const num = co.number;
  await db.exec(`update orders set paid = true, status = 1 where number = '${num}'`);
  await db.exec(`update profiles set phone_verified = false where id = '${U(4)}'`);
  await as(U(4));
  await works('commande en cours : le vendeur devenu non éligible continue de préparer (accepter)', `select set_seller_order_status('${num}', 1) r`, (r) => r[0].r === 1);
  await works('commande en cours : ... et de livrer', `select set_seller_order_status('${num}', 2) r`, (r) => r[0].r === 2);
  await as(U(10));
  await fails('nouvelle commande chez ce vendeur désormais refusée', `select marketplace_checkout('${cart(L(8))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0006')`, /Vendeur indisponible/);
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(4)}'`);
  // un compte qui n'est plus un étudiant (annonce héritée) ne traite pas les commandes ; compte suspendu : refus existant
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values ('${L(14)}', '${U(1)}', 'Annonce heritee client', 'Genie', 'Maison', 5000, 5, 'approved', '{}')`);
  await db.exec(`alter table order_lines disable trigger trg_k2_order_line_seller`);
  const oid = (await q(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid) values ('#BE-2026-6901', '${U(10)}', 5000, 0, 'Mobile Money', 0, true) returning id`))[0].id;
  await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${L(14)}', 'Annonce heritee client', 5000, 1)`);
  await db.exec(`alter table order_lines enable trigger trg_k2_order_line_seller`);
  await as(U(1));
  await fails('commande héritée : un client ne la fait pas avancer', `select set_seller_order_status('#BE-2026-6901', 1)`, /Réservé aux étudiants/);
  await sup();
  await db.exec(`update orders set pickup_code = '123456' where number = '#BE-2026-6901'`);
  await as(U(1));
  await fails('commande héritée : un client ne confirme pas de remise', `select seller_confirm_handover('#BE-2026-6901', '123456')`, /Réservé aux étudiants/);
  for (const [n, nom] of [[6, 'organisation'], [7, 'département'], [11, 'support'], [12, 'finance'], [13, 'direction']]) {
    await as(U(n));
    await fails(`commande : ${nom} ne traite pas la commande d'un autre vendeur`, `select set_seller_order_status('${num}', 3)`, /introuvable|non payée|Réservé/);
  }

  // ============================================================ 7. Retraits
  await sup();
  await db.exec(`insert into payment_methods (owner_id, provider, phone) values ('${U(4)}', 'orange_money', '690000001')`);
  await db.exec(`update payment_methods set created_at = now() - interval '3 days' where owner_id = '${U(4)}'`);
  await as(U(4));
  await fails('retrait : un vendeur éligible passe la garde d\'éligibilité (refus ensuite pour solde insuffisant)', `select request_seller_payout(5000, null, null)`, /solde disponible/);
  for (const [n, nom] of NON_ELIGIBLES) {
    await as(U(n));
    await fails(`retrait : ${nom} ne peut pas demander de retrait`, `select request_seller_payout(5000, null, null)`, /téléphone|statut d.étudiant|suspendu|réservés aux comptes étudiants|inactif/i);
  }
  // un retrait déjà demandé reste annulable et lisible par un vendeur devenu non éligible
  await sup();
  const bid = (await q(`insert into payout_batches (number, seller_id, amount, method, status, source) values ('RV-K2-1', '${U(3)}', 4000, 'Mobile Money', 'demande', 'seller') returning id`))[0].id;
  await as(U(3));
  await works('retrait : un vendeur devenu non éligible annule sa demande déjà déposée', `select payout_cancel_request('${bid}') r`, (r) => r[0].r === 'cancelled');
  await works('retrait : et lit toujours ses retraits', `select my_payouts() r`, (r) => Array.isArray(r[0].r.rows) && r[0].r.rows.length === 1);

  // ============================================================ 8. Pause / reprise
  await sup();
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images, shop_id) values
    ('${L(15)}', '${U(14)}', 'Sac K2 pause', 'Genie', 'Maison', 6000, 9, 'approved', '{}', (select id from shops where owner_id = '${U(14)}')),
    ('${L(16)}', '${U(14)}', 'Sac K2 attente', 'Genie', 'Maison', 6000, 9, 'pending', '{}', (select id from shops where owner_id = '${U(14)}'))`);
  for (const [n, nom] of [[1, 'client'], [6, 'organisation'], [7, 'département'], [8, 'administrateur'], [9, 'suspendu'], [11, 'support'], [12, 'finance'], [13, 'direction'], [15, 'ancien « other »']]) {
    await as(U(n));
    await fails(`pause : ${nom} ne peut pas mettre de boutique en pause`, `select seller_pause()`, /Réservé aux étudiants/);
  }
  await as(U(14));
  await works('reprise : sans pause, rien à reprendre (réponse sans effet)', `select seller_resume() r`, (r) => r[0].r === 'not_paused');
  await as(U(10));
  await works('pause : avant la pause, l\'annonce se commande', `select marketplace_checkout('${cart(L(15))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0010') r`, (r) => !!r[0].r.number);
  await as(U(14));
  await works('pause : un étudiant éligible met sa boutique en pause', `select seller_pause('Examens') r`, (r) => r[0].r === 'paused');
  await works('pause : une seconde demande est sans effet', `select seller_pause() r`, (r) => r[0].r === 'already_paused');
  await sup();
  check('pause : annonce publiée masquée (brouillon)', (await q(`select status from listings where id = '${L(15)}'`))[0].status === 'draft');
  check('pause : boutique en statut « paused »', (await q(`select status from shops where owner_id = '${U(14)}'`))[0].status === 'paused');
  check('pause : l\'annonce en validation n\'est pas touchée', (await q(`select status from listings where id = '${L(16)}'`))[0].status === 'pending');
  check('pause : la capacité indique la pause', (await cap(14)).paused === true && (await cap(14)).can_sell === true && (await cap(14)).can_receive_orders === false);
  await as(U(10));
  check('pause : invisible pour un acheteur', (await q(`select count(*)::int n from listings where id = '${L(15)}'`))[0].n === 0);
  await as(U(10));
  await fails('pause : aucune nouvelle commande', `select marketplace_checkout('${cart(L(15))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0011')`, /Vendeur indisponible|Produit indisponible|Boutique indisponible/);
  await as(U(10), null);
  await fails('pause : aucune nouvelle demande de devis adressée à ce prestataire', `insert into quote_requests (listing_id, requester_id, provider_id, brief) values ('${L(15)}', '${U(10)}', '${U(14)}', 'Demande pendant la pause du prestataire')`, /n.accepte plus de demandes/);
  await as(U(14));
  await fails('pause : aucune nouvelle publication', ins(U(14), 'pending', 'Publication en pause', 'Services'), /pause/);
  await fails('pause : ni promotion', `select promo_save('K2PAUSE', 'percent', 10, 0, null, null, true, false)`, /pause|doit être active/);
  await as(U(8));
  await fails('pause : un valideur ne publie pas l\'annonce d\'un vendeur en pause', `update listings set status = 'approved' where id = '${L(16)}'`, /pause/);
  await sup();
  // la commande déjà passée avant la pause se poursuit
  const pnum = (await q(`select number from orders where idem_key = 'k2-key-0010'`))[0].number;
  await db.exec(`update orders set paid = true, status = 1 where number = '${pnum}'`);
  await as(U(14));
  await works('pause : la commande en cours se poursuit', `select set_seller_order_status('${pnum}', 1) r`, (r) => r[0].r === 1);
  // reprise : exige la capacité complète
  await sup();
  await db.exec(`update profiles set phone_verified = false where id = '${U(14)}'`);
  await as(U(14));
  await fails('reprise : refusée tant que le téléphone n\'est pas vérifié', `select seller_resume()`, /téléphone/);
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(14)}'`);
  await as(U(14));
  await works('reprise : acceptée avec la capacité complète', `select seller_resume() r`, (r) => r[0].r === 'resumed');
  await sup();
  check('reprise : annonce rétablie telle quelle (publiée)', (await q(`select status, review_note from listings where id = '${L(15)}'`))[0].status === 'approved');
  check('reprise : boutique de nouveau active', (await q(`select status from shops where owner_id = '${U(14)}'`))[0].status === 'active');
  check('reprise : plus de pause ni de réserve', (await q(`select (select count(*)::int from seller_pauses where user_id = '${U(14)}') a, (select count(*)::int from k2_pause_holds where owner_id = '${U(14)}') b`))[0].a === 0);
  await as(U(10));
  await works('reprise : de nouveau commandable', `select marketplace_checkout('${cart(L(15))}'::jsonb, false, 'Mobile Money', null, null, 'k2-key-0012') r`, (r) => !!r[0].r.number);
  // suspension puis levée : une annonce masquée par la pause ne revient pas toute seule
  await as(U(14));
  await q(`select seller_pause()`);
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${U(14)}'`);
  await db.exec(`update profiles set suspended = false where id = '${U(14)}'`);
  check('pause : la levée d\'une suspension ne rouvre pas une boutique en pause', (await q(`select status from listings where id = '${L(15)}'`))[0].status === 'draft' && (await q(`select status from shops where owner_id = '${U(14)}'`))[0].status === 'paused');
  await as(U(14));
  await q(`select seller_resume()`);
  await sup();
  check('reprise après suspension : tout est rétabli', (await q(`select status from listings where id = '${L(15)}'`))[0].status === 'approved');

  // ============================================================ 9. Les autres acteurs ne gagnent aucun pouvoir
  check('aucun administrateur, département, client ou organisation n\'est vendeur éligible', (await q(`select count(*)::int n from profiles where role::text not in ('student') and seller_capable(id)`))[0].n === 0);
  check('un étudiant suspendu n\'est jamais éligible', (await q(`select count(*)::int n from profiles where coalesce(suspended, false) and seller_capable(id)`))[0].n === 0);
  console.log(`\nK2 : ${ok} OK, ${ko} ECHEC`);
}
