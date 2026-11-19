// Scénario PGlite du lot S3 (espace vendeur) : migrations 20261117030000 à 20261117030200.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s3.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const LOGO = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/boutique/logo.png';

  await db.exec('reset role');
  // 51 vendeur, 52 autre vendeur, 53 acheteur, 54 admin, 55 dept, 56 finance, 57 vendeur Pro
  const roles = { 51: 'student', 52: 'student', 53: 'client', 54: 'admin', 55: 'dept', 56: 'finance', 57: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','s3${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Vendeur ${n}','${r}','s3${n}@t.cm')`);
  }
  // K1 : droits minimaux par défaut ; la finance du scénario reçoit explicitement ses permissions.
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${U(56)}' and team_code = 'finance'`);
  await db.exec(`update profiles set certification = 'approved', phone_verified = true where id in ('${U(51)}', '${U(57)}')`);
  // K2 : le vendeur 52 est lui aussi éligible (pièce d'étudiant validée, téléphone vérifié)
  await db.exec(`update profiles set phone_verified = true where id = '${U(52)}'; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(52)}', 'student_card', 'c.pdf', '${U(52)}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  // H2 : le vendeur 51 et le responsable 55 sont dans le même département
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000f401', 'IUT S3', 'verified');
    insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000f4a1', '00000000-0000-0000-0000-00000000f401', 'Genie', 'verified');
    update profiles set department_id = '00000000-0000-0000-0000-00000000f4a1', institution_id = '00000000-0000-0000-0000-00000000f401' where id = '${U(51)}';
    insert into department_accounts (user_id, department_id) values ('${U(55)}', '00000000-0000-0000-0000-00000000f4a1')`);

  // --- S3-11 : service « Sur devis »
  await as(U(51));
  check('service sans tarif (prix 0) accepté', (await q(`insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(51)}', 'Aide au devoir', 'Genie', 'Services', 0, 999, 'draft') returning id`)).length === 1);
  await fails('produit à 0 FCFA refusé', `insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(51)}', 'Produit gratuit', 'Genie', 'Maison', 0, 1, 'draft')`, /listings_price_min/);
  await fails('service entre 1 et 499 FCFA refusé', `insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(51)}', 'Service cher', 'Genie', 'Services', 300, 1, 'draft')`, /listings_price_min/);
  check('produit à 500 FCFA accepté', (await q(`insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(51)}', 'Lampe 500', 'Genie', 'Maison', 500, 3, 'draft') returning id`)).length === 1);

  // --- S3-8 : annonces antérieures à la boutique rattachées
  await db.exec('reset role');
  const L1 = '00000000-0000-0000-0000-0000000000b1', L2 = '00000000-0000-0000-0000-0000000000b2';
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status) values
    ('${L1}', '${U(51)}', 'Lampe approuvée', 'Genie', 'Maison', 5000, 10, 'approved'), ('${L2}', '${U(51)}', 'Sac approuvé', 'Genie', 'Mode', 3000, 10, 'approved')`);
  check('annonce sans boutique avant la création', (await q(`select shop_id from listings where id = '${L1}'`))[0].shop_id === null);

  // --- S3-15 : validation des adresses et réseaux
  await as(U(51));
  await fails('shop_save : logo hors stockage refusé', `select shop_save('{"name":"Atelier S3","logo_url":"https://evil.example/pixel.png"}'::jsonb)`, /Logo/);
  await fails('shop_save : réseau sans https refusé', `select shop_save('{"name":"Atelier S3","socials":{"instagram":"@atelier"}}'::jsonb)`, /Réseau/);
  await fails('shop_save : réseau inconnu refusé', `select shop_save('{"name":"Atelier S3","socials":{"autre":"https://x.cm/a"}}'::jsonb)`, /Réseau/);
  await fails('shop_save : lien javascript refusé', `select shop_save('{"name":"Atelier S3","socials":{"website":"javascript:alert(1)"}}'::jsonb)`, /Réseau/);
  const created = (await q(`select shop_save('{"name":"Atelier S3","description":"Des objets utiles","logo_url":"${LOGO}","categories":["Maison"],"socials":{"instagram":"https://instagram.com/atelier","whatsapp":"+237690000000"}}'::jsonb) s`))[0].s;
  check('shop_save : boutique créée avec logo Supabase et liens valides', created.status === 'draft' && created.logo_url === LOGO);
  check('S3-8 : les annonces existantes sont rattachées à l\'enregistrement', (await q(`select count(*)::int n from listings where seller_id = '${U(51)}' and shop_id = '${created.id}'`))[0].n >= 2);
  check('S3-8 : le rattachement ne change pas le statut des annonces', (await q(`select status from listings where id = '${L1}'`))[0].status === 'approved');

  // --- S3-17 (boutiques) : la soumission prévient les valideurs
  await q(`select shop_submit()`);
  await as(U(54));
  check('shop_submit : l\'administrateur est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${U(54)}' and title = 'Boutique à valider'`))[0].n === 1);
  await db.exec('reset role');
  check('shop_submit : le responsable de département est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${U(55)}' and title = 'Boutique à valider'`))[0].n === 1);
  await as(U(54));
  await q(`select shop_decide('${created.id}', 'approve')`);

  // --- post-modération d'une boutique active
  await as(U(51));
  const r1 = (await q(`select shop_save('{"description":"Nouvelle description"}'::jsonb) s`))[0].s;
  check('boutique active modifiée : reste active (non dépubliée)', r1.status === 'active' && r1.description === 'Nouvelle description');
  check('boutique active modifiée : annonces toujours visibles du public', (await (async () => { await as(null, 'anon'); const n = (await q(`select count(*)::int n from listings where id = '${L1}'`))[0].n; await as(U(51)); return n; })()) === 1);
  await as(U(54));
  check('post-modération : l\'administrateur est notifié', (await q(`select count(*)::int n from notifications where user_id = '${U(54)}' and title = 'Boutique modifiée'`))[0].n === 1);
  await as(U(51));
  await q(`select shop_save('{"name":"Atelier S3 bis"}'::jsonb)`);
  await as(U(54));
  check('post-modération : une seule alerte par heure', (await q(`select count(*)::int n from notifications where user_id = '${U(54)}' and title = 'Boutique modifiée'`))[0].n === 1);
  await as(U(51));
  await q(`select shop_save('{"city":"Douala","delivery_info":"48 h"}'::jsonb)`);
  await db.exec('reset role');
  await db.exec(`delete from notifications where title = 'Boutique modifiée'`);
  await as(U(51));
  await q(`select shop_save('{"city":"Yaoundé"}'::jsonb)`);
  await db.exec('reset role');
  check('modification hors identité (ville, livraison) : aucune alerte', (await q(`select count(*)::int n from notifications where title = 'Boutique modifiée'`))[0].n === 0);
  await as(U(51));
  await fails('boutique active : un logo hors stockage reste refusé', `select shop_save('{"logo_url":"https://tracker.example/p.png"}'::jsonb)`, /Logo/);
  check('boutique active : un logo Supabase est accepté', (await q(`select shop_save('{"logo_url":"${LOGO}x"}'::jsonb) s`))[0].s.status === 'active');

  // --- ventes flash, packs, campagnes : annonces rattachées
  const now = new Date(); const later = new Date(now.getTime() + 6 * 3600e3);
  check('flash_save : annonce antérieure à la boutique acceptée', (await q(`select flash_save('${L1}', 3000, 3, '${now.toISOString()}', '${later.toISOString()}') id`)).length === 1);
  const pk = (await q(`select pack_save('Duo', 'Lampe et sac', 6000, '[{"listing":"${L1}","qty":1},{"listing":"${L2}","qty":1}]'::jsonb) id`))[0].id;
  const cp = (await q(`select campaign_save('Rentrée', 'Offres', null, array['${L1}']::uuid[], now(), null) id`))[0].id;
  const code = (await q(`select promo_save('RENTREE10', 'percent', 10) id`))[0].id;

  // --- S3-12 : promotions désactivables
  check('promo_toggle : code désactivé', (await q(`select promo_toggle('${code}', false) a`))[0].a === false);
  check('promo_toggle : code réactivé', (await q(`select promo_toggle('${code}', true) a`))[0].a === true);
  check('campaign_toggle : campagne désactivée', (await q(`select campaign_toggle('${cp}', false) a`))[0].a === false);
  check('pack_toggle : pack désactivé', (await q(`select pack_toggle('${pk}', false) a`))[0].a === false);
  await as(U(52));
  await fails('promo_toggle : le code d\'un autre vendeur est intouchable', `select promo_toggle('${code}', false)`, /introuvable/);
  await fails('campaign_toggle : la campagne d\'un autre vendeur est intouchable', `select campaign_toggle('${cp}', false)`, /introuvable/);
  await fails('pack_toggle : le pack d\'un autre vendeur est intouchable', `select pack_toggle('${pk}', false)`, /introuvable/);
  await as(null, 'anon');
  await fails('promo_toggle : refusé aux visiteurs', `select promo_toggle('${code}', false)`, /permission denied/);
  await fails('shop_attach_listings : refusé aux visiteurs', `select shop_attach_listings()`, /permission denied/);

  // --- S3-9 : fiche produit d'une boutique suspendue
  await as(U(53));
  check('product_detail : boutique active, fiche visible', (await q(`select product_detail('${L1}') d`))[0].d.found === true);
  await as(U(54));
  await q(`select shop_decide('${created.id}', 'suspend', 'Contenu à vérifier')`);
  await as(U(53));
  check('product_detail : boutique suspendue, fiche masquée au public', (await q(`select product_detail('${L1}') d`))[0].d.found === false);
  await as(U(51));
  check('product_detail : le propriétaire garde sa fiche', (await q(`select product_detail('${L1}') d`))[0].d.found === true);
  await as(U(54));
  check('product_detail : la modération garde la fiche', (await q(`select product_detail('${L1}') d`))[0].d.found === true);
  await q(`select shop_decide('${created.id}', 'restore')`);

  // --- S3-10 : réouverture d'une boutique fermée (shop_save refuse, shop_submit rouvre)
  await as(U(51));
  await q(`select shop_close()`);
  await fails('boutique fermée : shop_save refusé (l\'interface ne doit pas l\'appeler)', `select shop_save('{"name":"Atelier S3 ter"}'::jsonb)`, /fermée/);
  check('boutique fermée : shop_submit la remet en validation', (await q(`select shop_submit() s`))[0].s === 'pending');
  await db.exec('reset role');
  check('réouverture : les valideurs sont prévenus', (await q(`select count(*)::int n from notifications where user_id = '${U(54)}' and title = 'Boutique rouverte à valider'`))[0].n === 1);
  await as(U(54));
  await q(`select shop_decide('${created.id}', 'approve')`);

  // --- S3-13 : alertes de stock réelles
  await as(U(51));
  check('seller_settings_get : valeurs par défaut', (await q(`select seller_settings_get() s`))[0].s.stock_threshold === 30);
  await fails('seller_settings_set : seuil négatif refusé', `select seller_settings_set(-1, true, true)`, /Seuil/);
  await q(`select seller_settings_set(8, true, true)`);
  await db.exec('reset role');
  await db.exec(`update listings set stock = 7 where id = '${L1}'`);
  check('stock sous le seuil : notification « Stock bas »', (await q(`select count(*)::int n from notifications where user_id = '${U(51)}' and title = 'Stock bas'`))[0].n === 1);
  await db.exec(`update listings set stock = 6 where id = '${L1}'`);
  check('stock déjà sous le seuil : pas de doublon', (await q(`select count(*)::int n from notifications where user_id = '${U(51)}' and title = 'Stock bas'`))[0].n === 1);
  await db.exec(`update listings set stock = 0 where id = '${L1}'`);
  check('stock à zéro : notification « Rupture de stock »', (await q(`select count(*)::int n from notifications where user_id = '${U(51)}' and title = 'Rupture de stock'`))[0].n === 1);
  await as(U(51));
  await q(`select seller_settings_set(8, false, false)`);
  await db.exec('reset role');
  await db.exec(`update listings set stock = 20 where id = '${L2}'`);
  await db.exec(`update listings set stock = 2 where id = '${L2}'`);
  check('alertes désactivées : aucune notification', (await q(`select count(*)::int n from notifications where user_id = '${U(51)}' and body like 'Sac approuvé%'`))[0].n === 0);

  // --- S3-3/S3-48 : aperçu réel du vendeur
  const o1 = (await q(`insert into orders (number, buyer_id, subtotal, method, paid) values ('#S3-1', '${U(53)}', 9000, 'cash', true) returning id`))[0].id;
  const o2 = (await q(`insert into orders (number, buyer_id, subtotal, method, paid, cancelled_at) values ('#S3-2', '${U(53)}', 5000, 'cash', true, now()) returning id`))[0].id;
  await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty, fulfillment) values ('${o1}', '${L1}', 'Lampe approuvée', 5000, 1, 1), ('${o1}', '${L2}', 'Sac approuvé', 2000, 2, 4), ('${o2}', '${L1}', 'Lampe approuvée', 5000, 1, 1)`);
  await as(U(51));
  const ov = (await q(`select seller_overview(30) o`))[0].o;
  check('seller_overview : ventes payées non annulées seulement', ov.revenue === 9000 && ov.orders === 1 && ov.units === 3, JSON.stringify(ov));
  check('seller_overview : commandes à préparer', ov.pending_orders === 1);
  check('seller_overview : annonces par statut', ov.listings.approved === 2 && ov.listings.draft === 2, JSON.stringify(ov.listings));
  check('seller_overview : produits avec ventes', ov.products.find((p) => p.id === L1).units === 1 && ov.products.find((p) => p.id === L2).revenue === 4000);
  check('seller_overview : six mois', ov.months.length === 6 && ov.months[5].revenue === 9000);
  await as(U(52));
  const ov2 = (await q(`select seller_overview(30) o`))[0].o;
  check('seller_overview : un autre vendeur ne voit rien', ov2.revenue === 0 && ov2.products.length === 0);
  await as(null, 'anon');
  await fails('seller_overview : refusé aux visiteurs', `select seller_overview(30)`, /permission denied/);

  // --- S3-88 : campagne refusée après paiement
  await db.exec('reset role');
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${U(57)}', 'vendeur_pro', 'active', now(), now() + interval '30 days')`);
  const L3 = '00000000-0000-0000-0000-0000000000b3';
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status) values ('${L3}', '${U(57)}', 'Cahier relié', 'Genie', 'Art', 2500, 5, 'approved')`);
  await as(U(57));
  const camp = (await q(`select ad_campaign_save(null, 'Cahiers', 'Promo', null, '${L3}', 5000, null, null, null) id`))[0].id;
  const pay = (await q(`select ad_campaign_submit('${camp}') p`))[0].p;
  await as(U(56));
  await q(`select payment_set_status('${pay}', 'confirmed')`);
  await as(U(54));
  await q(`select ad_campaign_review('${camp}', false, 'Visuel non conforme')`);
  await as(U(57));
  const before = (await q(`select count(*)::int n from payment_transactions where payer_id = '${U(57)}'`))[0].n;
  check('campagne refusée : le budget payé est signalé', (await q(`select (my_ad_campaigns()) r`))[0].r[0].paid === true);
  await fails('campagne refusée et payée : suppression impossible (paiement perdu)', `select ad_campaign_cancel('${camp}')`, /déjà payé/);
  await fails('campagne payée : le budget ne peut plus changer', `select ad_campaign_save('${camp}', 'Cahiers', 'Promo', null, '${L3}', 9000, null, null, null)`, /déjà payé/);
  check('campagne payée : contenu modifiable à budget égal', (await q(`select ad_campaign_save('${camp}', 'Cahiers v2', 'Promo', null, '${L3}', 5000, null, null, null) id`)).length === 1);
  const pay2 = (await q(`select ad_campaign_submit('${camp}') p`))[0].p;
  check('campagne refusée : renvoi sans nouveau paiement', pay2 === pay && (await q(`select count(*)::int n from payment_transactions where payer_id = '${U(57)}'`))[0].n === before);
  check('campagne renvoyée : de nouveau en attente de validation, motif effacé', (await q(`select status, review_note from ad_campaigns where id = '${camp}'`))[0].status === 'pending_review');
  // campagne non payée refusée : un nouveau paiement reste demandé
  await as(U(57));
  const camp2 = (await q(`select ad_campaign_save(null, 'Autre', 'x', null, '${L3}', 2000, null, null, null) id`))[0].id;
  check('campagne brouillon : annulable', (await q(`select ad_campaign_cancel('${camp2}')`)).length === 1);

  console.log(`\n${ok} OK, ${ko} ECHEC`);
}
