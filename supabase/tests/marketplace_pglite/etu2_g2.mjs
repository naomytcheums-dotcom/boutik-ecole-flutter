// Scénario PGlite du lot G2 (annonces, modération, suspension, prix, stock) : migration 20261119020000.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./etu2_g2.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const IMG = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/l/photo.png';
  const LOGO = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/boutique/logo.png';

  await db.exec('reset role');
  // 61 vendeur A, 62 vendeur B, 63 client, 64 admin, 65 dept Genie, 66 dept Gestion, 67 entreprise
  const roles = { 61: 'student', 62: 'student', 63: 'client', 64: 'admin', 65: 'dept', 66: 'dept', 67: 'company' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','g2${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte ${n}','${r}','g2${n}@t.cm')`);
  }
  await db.exec(`update profiles set certification = 'approved' where id in ('${U(61)}', '${U(62)}');
                 update profiles set department = 'Genie' where id in ('${U(61)}', '${U(65)}'); update profiles set department = 'Gestion' where id = '${U(66)}'`);
  // H2 : département des vendeurs par identifiant, comptes Département rattachés à UN département
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000f201', 'IUT G2', 'verified');
    insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000f2a1', '00000000-0000-0000-0000-00000000f201', 'Genie', 'verified'), ('00000000-0000-0000-0000-00000000f2a2', '00000000-0000-0000-0000-00000000f201', 'Gestion', 'verified');
    update profiles set department_id = '00000000-0000-0000-0000-00000000f2a1', institution_id = '00000000-0000-0000-0000-00000000f201' where id in ('${U(61)}', '${U(62)}');
    insert into department_accounts (user_id, department_id) values ('${U(65)}', '00000000-0000-0000-0000-00000000f2a1'), ('${U(66)}', '00000000-0000-0000-0000-00000000f2a2')`);

  // --- photo obligatoire pour un produit envoyé en validation
  await as(U(61));
  await fails('produit en validation sans photo refusé (création)', `insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(61)}', 'Lampe sans photo', 'Genie', 'Maison', 5000, 3, 'pending')`, /au moins une photo/);
  const L1 = (await q(`insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(61)}', 'Lampe G2', 'Genie', 'Maison', 5000, 10, 'draft') returning id`))[0].id;
  await fails('brouillon sans photo : envoi en validation refusé', `update listings set status = 'pending' where id = '${L1}'`, /au moins une photo/);
  await q(`update listings set images = array['${IMG}'] where id = '${L1}'`);
  check('brouillon avec photo : envoi en validation accepté', (await q(`update listings set status = 'pending' where id = '${L1}' returning id`)).length === 1);
  check('service en validation sans photo accepté', (await q(`insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(61)}', 'Aide G2', 'Genie', 'Services', 0, 999, 'pending') returning id`)).length === 1);
  await fails('doublon de titre (espaces multiples) refusé', `insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(61)}', '  lampe   g2 ', 'Genie', 'Maison', 5000, 1, 'draft')`, /listings_titre_unique|duplicate/);

  // --- brouillons privés
  const D1 = (await q(`insert into listings (seller_id, title, department, category, price, stock, status) values ('${U(61)}', 'Brouillon prive', 'Genie', 'Maison', 4000, 1, 'draft') returning id`))[0].id;
  check('le vendeur voit son brouillon', (await q(`select 1 from listings where id = '${D1}'`)).length === 1);
  await as(U(62)); check('un autre vendeur ne voit pas le brouillon', (await q(`select 1 from listings where id = '${D1}'`)).length === 0);
  await as(U(65)); check('le département ne voit pas le brouillon', (await q(`select 1 from listings where id = '${D1}'`)).length === 0);
  await as(null, 'anon'); check('un visiteur ne voit pas le brouillon', (await q(`select 1 from listings where id = '${D1}'`)).length === 0);
  await as(U(64)); check('l\'administrateur voit le brouillon', (await q(`select 1 from listings where id = '${D1}'`)).length === 1);

  // --- file de validation et périmètre
  await as(U(65));
  const qd = (await q(`select listing_review_queue() r`))[0].r;
  const it = qd.find((x) => x.id === L1);
  check('file : le responsable du département voit l\'annonce avec vendeur, description et photo', !!it && it.seller_name === 'Compte 61' && it.images.length === 1 && it.status === 'pending');
  check('file : les brouillons n\'y figurent pas', !qd.some((x) => x.id === D1));
  await as(U(66));
  check('file : un autre département ne la voit pas', !(await q(`select listing_review_queue() r`))[0].r.some((x) => x.id === L1));
  check('autre département : validation impossible (l\'annonce lui est invisible, H2)', (await q(`update listings set status = 'approved' where id = '${L1}' returning id`)).length === 0);
  await as(U(63)); await fails('client : file refusée', `select listing_review_queue()`, /Réservé/);
  await as(U(67)); await fails('entreprise : file refusée', `select listing_review_queue()`, /Réservé/);
  await as(null, 'anon'); await fails('anonyme : file refusée', `select listing_review_queue()`, /(Réservé|permission)/);
  await as(U(61)); await fails('vendeur : file refusée', `select listing_review_queue()`, /Réservé/);

  // --- décisions du valideur
  await as(U(65));
  await fails('refus sans motif refusé', `update listings set status = 'rejected' where id = '${L1}'`, /motif/);
  await fails('refus avec motif trop court refusé', `update listings set status = 'rejected', review_note = 'non' where id = '${L1}'`, /motif/);
  await fails('le responsable ne modifie pas le prix d\'un vendeur', `update listings set price = 100 where id = '${L1}'`, /ne modifie que le statut/);
  check('le responsable ne publie pas un brouillon (invisible pour lui)', (await q(`update listings set status = 'approved' where id = '${D1}' returning id`)).length === 0);
  check('refus avec motif accepté', (await q(`update listings set status = 'rejected', review_note = 'Photo floue, merci de la remplacer' where id = '${L1}' returning id`)).length === 1);
  await db.exec('reset role');
  const nrej = await q(`select body from notifications where user_id = '${U(61)}' and title = 'Annonce refusée'`);
  check('le vendeur est notifié du refus avec le motif', nrej.length === 1 && /Photo floue/.test(nrej[0].body));
  await as(U(61));
  const own = (await q(`select status, review_note from listings where id = '${L1}'`))[0];
  check('le vendeur lit le motif du refus', own.status === 'rejected' && /Photo floue/.test(own.review_note));
  await as(U(65));
  check('validation (refusée -> validée) acceptée', (await q(`update listings set status = 'approved', review_note = null where id = '${L1}' returning id`)).length === 1);
  await as(null, 'anon');
  check('visiteur : l\'annonce validée est visible', (await q(`select 1 from listings where id = '${L1}'`)).length === 1);
  await as(U(63));
  check('client : l\'annonce validée est visible', (await q(`select 1 from listings where id = '${L1}'`)).length === 1);
  await as(U(67)); check('entreprise : ne peut pas décider (0 ligne)', (await q(`update listings set status = 'rejected', review_note = 'pas son rôle ici' where id = '${L1}' returning id`)).length === 0);
  await as(U(63)); check('client : ne peut pas décider (0 ligne)', (await q(`update listings set status = 'rejected', review_note = 'pas son rôle ici' where id = '${L1}' returning id`)).length === 0);
  await db.exec('reset role');
  check('entreprise / client : statut inchangé', (await q(`select status from listings where id = '${L1}'`))[0].status === 'approved');

  // --- modification d'une annonce validée : retour en modération, notification, invisible du public
  await as(U(61));
  await q(`update listings set price = 6000, stock = 8 where id = '${L1}'`);
  check('prix et stock modifiés : l\'annonce reste validée', (await q(`select status from listings where id = '${L1}'`))[0].status === 'approved');
  await q(`update listings set title = 'Lampe G2 bois' where id = '${L1}'`);
  check('titre modifié : retour en validation', (await q(`select status from listings where id = '${L1}'`))[0].status === 'pending');
  check('le vendeur est prévenu du retrait de la vente', (await q(`select count(*)::int n from notifications where user_id = '${U(61)}' and title = 'Annonce renvoyée en validation'`))[0].n === 1);
  await as(null, 'anon'); check('visiteur : l\'annonce modifiée n\'est plus visible', (await q(`select 1 from listings where id = '${L1}'`)).length === 0);
  await as(U(63)); check('client : l\'annonce modifiée n\'est plus visible', (await q(`select 1 from listings where id = '${L1}'`)).length === 0);
  await as(U(65)); await q(`update listings set status = 'approved' where id = '${L1}'`);
  await as(U(61));
  await fails('retirer la dernière photo d\'une annonce validée refusé', `update listings set images = '{}' where id = '${L1}'`, /au moins une photo/);

  // --- boutique, vente flash, pack, stock
  const created = (await q(`select shop_save('{"name":"Atelier G2","description":"Des objets utiles","logo_url":"${LOGO}","categories":["Maison"],"city":"Douala"}'::jsonb) s`))[0].s;
  await q(`select shop_submit()`);
  await as(U(64)); await q(`select shop_decide('${created.id}', 'approve')`);
  await as(U(61));
  const L2 = (await q(`insert into listings (seller_id, title, department, category, price, stock, status, images) values ('${U(61)}', 'Sac G2', 'Genie', 'Mode', 3000, 20, 'draft', array['${IMG}']) returning id`))[0].id;
  await q(`update listings set status = 'pending' where id = '${L2}'`);
  await as(U(65)); await q(`update listings set status = 'approved' where id = '${L2}'`);
  await as(U(61));
  const now = new Date(), later = new Date(now.getTime() + 6 * 3600e3);
  const fl = (await q(`select flash_save('${L2}', 2000, 5, '${new Date(now.getTime() - 60e3).toISOString()}', '${later.toISOString()}') id`))[0].id;
  const pk = (await q(`select pack_save('Duo G2', 'Lampe et sac', 8000, '[{"listing":"${L1}","qty":1},{"listing":"${L2}","qty":1}]'::jsonb) id`))[0].id;
  await q(`update listings set price_before = 4000 where id = '${L2}'`);
  await as(U(63));
  const ord = (await q(`select marketplace_checkout('[{"id":"${L2}","qty":2}]'::jsonb, false, 'Mobile Money', null, null, 'cle-g2-000001') r`))[0].r;
  await db.exec('reset role');
  const s1 = (await q(`select (select stock from listings where id = '${L2}') st, (select sold from flash_sales where id = '${fl}') sold`))[0];
  check('commande : stock décrémenté et vente flash comptée', s1.st === 18 && s1.sold === 2, JSON.stringify(s1));
  await as(U(63)); await q(`select cancel_order('${ord.number}')`);
  await db.exec('reset role');
  const s2 = (await q(`select (select stock from listings where id = '${L2}') st, (select sold from flash_sales where id = '${fl}') sold`))[0];
  check('annulation : stock rendu ET unités flash rendues', s2.st === 20 && s2.sold === 0, JSON.stringify(s2));
  await fails('stock jamais négatif', `update listings set stock = stock - 99 where id = '${L2}'`, /listings_stock_check/);
  // la baisse de prix sous le prix flash annule la vente flash, efface le prix barré et désactive le pack sans remise
  await as(U(61));
  await q(`update listings set price = 1500 where id = '${L2}'`);
  await db.exec('reset role');
  const s3 = (await q(`select (select cancelled from flash_sales where id = '${fl}') c, (select price_before from listings where id = '${L2}') pb, (select active from shop_packs where id = '${pk}') pa`))[0];
  check('baisse de prix : vente flash annulée', s3.c === true);
  check('baisse de prix : prix avant promotion inférieur au nouveau prix conservé tel quel', s3.pb === 4000, JSON.stringify(s3));
  check('baisse de prix : pack sans remise réelle désactivé', s3.pa === false);
  await q(`update listings set price_before = 2000 where id = '${L2}'`);
  await q(`update listings set price = 2500 where id = '${L2}'`);
  await db.exec('reset role');
  check('hausse de prix au-dessus du prix avant promotion : celui-ci est effacé (pas d\'erreur de contrainte)', (await q(`select price_before from listings where id = '${L2}'`))[0].price_before === null);
  check('baisse de prix : le vendeur est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${U(61)}' and title = 'Promotion désactivée'`))[0].n >= 1);

  // --- vendeur suspendu : annonces et boutique masquées puis rétablies
  await as(U(64));
  await q(`select admin_set_account('${U(61)}', 'student', true)`);
  await as(null, 'anon');
  check('vendeur suspendu : ses annonces disparaissent du public', (await q(`select 1 from listings where id in ('${L1}', '${L2}')`)).length === 0);
  await db.exec('reset role');
  check('vendeur suspendu : boutique en statut suspendu', (await q(`select status from shops where id = '${created.id}'`))[0].status === 'suspended');
  const hp = await q(`select search from (select marketplace_search(null, null, null, null, null, 'popular', null, 50, 0) search) z`);
  check('vendeur suspendu : absent de la recherche publique', !JSON.stringify(hp[0].search).includes('Sac G2'));
  await as(U(63));
  await fails('vendeur suspendu : commande refusée', `select marketplace_checkout('[{"id":"${L2}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-g2-000002')`, /indisponible/);
  await as(U(61)); await fails('vendeur suspendu : ne modifie plus rien', `update listings set stock = 5 where id = '${L2}'`, /Compte suspendu/);
  await as(U(64));
  await q(`select admin_set_account('${U(61)}', 'student', false)`);
  await as(null, 'anon');
  check('levée de suspension : annonces rétablies', (await q(`select 1 from listings where id in ('${L1}', '${L2}')`)).length === 2);
  await db.exec('reset role');
  check('levée de suspension : boutique active', (await q(`select status from shops where id = '${created.id}'`))[0].status === 'active');
  check('levée de suspension : plus de retenue en base', (await q(`select count(*)::int n from g2_suspension_holds`))[0].n === 0);
  // une annonce en attente d'un vendeur suspendu ne peut pas être validée
  await as(U(61)); await q(`update listings set title = 'Sac G2 cuir' where id = '${L2}'`);
  await as(U(64)); await q(`select admin_set_account('${U(61)}', 'student', true)`);
  await as(U(65)); await fails('validation pour un vendeur suspendu refusée', `update listings set status = 'approved' where id = '${L2}'`, /suspendu/);
  await as(U(64)); await q(`select admin_set_account('${U(61)}', 'student', false)`);
  // un vendeur dont le rôle devient « client » n'est plus vendeur : annonces masquées
  await as(U(62));
  const L3 = (await q(`insert into listings (seller_id, title, department, category, price, stock, status, images) values ('${U(62)}', 'Table G2', 'Genie', 'Maison', 9000, 2, 'draft', array['${IMG}']) returning id`))[0].id;
  await q(`update listings set status = 'pending' where id = '${L3}'`);
  await as(U(65)); await q(`update listings set status = 'approved' where id = '${L3}'`);
  await as(U(64)); await q(`select admin_set_account('${U(62)}', 'client', false)`);
  await as(null, 'anon'); check('vendeur devenu client : annonce masquée', (await q(`select 1 from listings where id = '${L3}'`)).length === 0);
  await as(U(64)); await q(`select admin_set_account('${U(62)}', 'student', false)`);
  await as(null, 'anon'); check('vendeur redevenu étudiant : annonce rétablie', (await q(`select 1 from listings where id = '${L3}'`)).length === 1);

  // --- isolation : le vendeur B ne voit ni ne modifie les annonces du vendeur A
  await as(U(62));
  check('vendeur B : ne lit pas l\'annonce en attente du vendeur A', (await q(`select 1 from listings where id = '${L2}'`)).length === 0);
  check('vendeur B : ne modifie pas l\'annonce de A (0 ligne)', (await q(`update listings set stock = 1 where id = '${L1}' returning id`)).length === 0);
  await db.exec('reset role');
  console.log(`\n${ok} OK, ${ko} ECHEC`);
  if (ko) process.exitCode = 1;
}

