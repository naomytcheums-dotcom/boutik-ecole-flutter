// Scénario PGlite du lot H13.1 SHOPS (20261129030000 / 20261129030100 / 20261129030200 : multi-boutiques).
// Cas autorisés ET refusés : plusieurs boutiques par propriétaire éligible (limite shops.max_per_owner réglable, fermées non comptées), création / identité visuelle / images dans le
// stockage existant / activation-désactivation, boutique active persistée côté serveur (my_shops, my_shops_overview, bascule sans reconnexion), annonces rattachées à la BONNE boutique
// (création, déplacement, refus d'une boutique étrangère, flash / pack / campagne), variantes qui suivent l'annonce, promotions et produits mis en avant par boutique, commande
// multi-boutiques (lignes et responsabilités séparées), statistiques sans mélange, équipe (manager / staff / viewer : droits strictement bornés, seul le propriétaire gère les membres),
// isolation et RLS (autre propriétaire, anonyme, lecture publique limitée), rejeu des migrations sans effet.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_shops.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-00000013${String(n).padStart(4, '0')}`;
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r).slice(0, 400)); return r; } catch (e) { check(name, false, e.message); return null; } };
  const qs = async (sql) => { const prev = cur; await sup(); try { return await q(sql); } finally { if (prev) await as(prev.uid, prev.role); } };
  // lecture ou écriture directe qui ne doit rien révéler / modifier (zéro ligne, ou refus)
  const noRows = async (name, sql) => { try { const r = await q(sql); check(name, r.length === 0, `${r.length} ligne(s)`); } catch (e) { check(name, /permission denied|row-level security/i.test(e.message), e.message); } };
  const DENY = /permission denied|Connexion requise|introuvable|Réservé|réservé|Droits insuffisants|row-level security|violates/i;

  await sup();
  await db.exec('grant all on storage.objects to authenticated');
  // 1 vendeur A ; 2 vendeur B ; 3 acheteur ; 4 manager ; 5 staff ; 6 viewer ; 7 administrateur ; 8 étudiant NON éligible ; 9 client sans lien ; 10 organisation
  const roles = { 1: 'student', 2: 'student', 3: 'client', 4: 'client', 5: 'client', 6: 'client', 7: 'admin', 8: 'student', 9: 'client', 10: 'company' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h131s${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte H131 ${n}','${r}','h131s${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69131' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
  }
  for (const n of [1, 2]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${U(n)}'`);
  await db.exec(`update profiles set phone_verified = false where id = '${U(8)}'`);
  const url = (n, f) => `https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/${U(n)}/boutique/${f}`;
  const shopSave = (o) => `select shop_save('${JSON.stringify(o).replace(/'/g, "''")}'::jsonb) r`;
  const base = (name, extra = {}) => ({ create: true, name, description: 'Boutique de test H13.1', logo_url: url(1, 'logo.png'), categories: ['mode'], ...extra });
  const settingMax = async (v) => qs(`insert into platform_settings (key, value) values ('shops.max_per_owner', '${v}'::jsonb) on conflict (key) do update set value = excluded.value`);

  // ============================================================ 1. création de plusieurs boutiques, limite, éligibilité
  await as(U(1));
  let S1, S2, S3, S4, S5;
  await works('A : crée la boutique Alpha (devient la boutique active)', shopSave(base('Alpha H131', { slug: 'alpha-h131', color_primary: '#0F7A52' })), (r) => { S1 = r[0].r.id; return r[0].r.owner_id === U(1) && r[0].r.status === 'draft'; });
  await works('A : crée une SECONDE boutique (Beta)', shopSave(base('Beta H131', { slug: 'beta-h131' })), (r) => { S2 = r[0].r.id; return r[0].r.id !== S1; });
  await works('A : crée une TROISIÈME boutique (Gamma)', shopSave(base('Gamma H131', { slug: 'gamma-h131' })), (r) => { S3 = r[0].r.id; return true; });
  await fails('A : une QUATRIÈME dépasse la limite par défaut (3)', shopSave(base('Delta H131', { slug: 'delta-h131' })), /Limite atteinte : 3 boutique/);
  await fails('A : adresse publique déjà prise refusée (la limite passe après)', shopSave({ id: S3, slug: 'beta-h131' }), /adresse publique|Boutique gamma|déjà prise|modification/i);
  check('A possède 3 boutiques en base', Number((await qs(`select count(*) c from shops where owner_id = '${U(1)}'`))[0].c) === 3);
  await as(U(2));
  await fails('B : un nom déjà pris par une boutique de A est refusé', shopSave(base('alpha h131', { slug: 'alpha-bis-h131', logo_url: url(2, 'logo.png') })), /nom de boutique est déjà pris/);
  await works('B : crée sa propre boutique (propriétaires distincts, aucune limite croisée)', shopSave(base('Boutique B H131', { slug: 'boutique-b-h131', logo_url: url(2, 'logo.png') })), (r) => { S4 = r[0].r.id; return r[0].r.owner_id === U(2); });
  await as(U(9));
  await fails('client : création de boutique refusée (règle existante : étudiant vendeur)', shopSave(base('Client H131', { slug: 'client-h131' })), /étudiants|Réservé|vendre|vérifi/i);
  await as(U(8));
  await fails('étudiant non éligible (téléphone non vérifié) : création refusée', shopSave(base('Non eligible H131', { slug: 'non-eligible-h131' })), /téléphone|vérif|vendre/i);
  await as(U(10));
  await fails('organisation : création refusée (règle existante inchangée : étudiants-vendeurs)', shopSave(base('Org H131', { slug: 'org-h131' })), /étudiants|Réservé|vendre|vérifi/i);
  await as(null, 'anon');
  await fails('anonyme : shop_save refusé', shopSave(base('Anon H131', { slug: 'anon-h131' })), DENY);
  await fails('anonyme : my_shops refusé', `select my_shops()`, DENY);
  await as(U(1));
  // limite réglable (non financière) : fermée = non comptée ; valeur modifiable par l'administration
  await works('A : ferme la boutique Gamma (une boutique fermée ne compte plus)', `select shop_close('${S3}') r`, (r) => r[0].r === 'closed');
  await works('A : peut de nouveau créer (2 ouvertes + 1 fermée)', shopSave(base('Delta H131', { slug: 'delta-h131' })), (r) => { S5 = r[0].r.id; return true; });
  await fails('A : rouvrir Gamma dépasserait la limite', `select shop_submit('${S3}')`, /Limite atteinte/);
  await as(U(7));
  await works('administration : règle la limite à 5 (setting_set)', `select setting_set('shops.max_per_owner', '5'::jsonb)`);
  await as(U(1));
  await works('A : la limite relevée autorise la réouverture de Gamma', `select shop_submit('${S3}') r`, (r) => r[0].r === 'pending');
  await settingMax('"abc"');
  check('valeur invalide : retour à la limite par défaut (3)', Number((await qs(`select shops_max_per_owner() n`))[0].n) === 3);
  await settingMax('1');
  await fails('limite à 1 : nouvelle boutique refusée', shopSave(base('Epsilon H131', { slug: 'epsilon-h131' })), /Limite atteinte : 1 boutique/);
  await settingMax('5');

  // ============================================================ 2. identité visuelle, images, activation
  await works('A : modifie nom, description, couleur et bannière de la boutique Beta', shopSave({ id: S2, description: 'Nouvelle description Beta', banner_url: url(1, 'banniere.png'), color_primary: '#B83280', color_secondary: '#0B6BCB' }),
    (r) => r[0].r.banner_url === url(1, 'banniere.png') && r[0].r.color_primary === '#B83280' && r[0].r.name === 'Beta H131');
  check('la modification de Beta ne touche pas Alpha', (await qs(`select color_primary, description from shops where id = '${S1}'`))[0].color_primary === '#0F7A52');
  await fails('A : logo hors stockage de la plateforme refusé', shopSave({ id: S2, logo_url: 'https://exemple.com/logo.png' }), /Logo/);
  await fails('A : couleur invalide refusée', shopSave({ id: S2, color_primary: 'rouge' }), /check|violates|couleur/i);
  await fails('A : identifiant de boutique invalide refusé', shopSave({ id: 'pas-un-uuid' }), /Identifiant de boutique invalide/);
  await as(U(2));
  await fails('B : modifier une boutique de A refusé', shopSave({ id: S2, description: 'Piratage' }), /Boutique introuvable/);
  await fails('B : fermer la boutique de A refusé', `select shop_close('${S1}')`, /Fermeture impossible/);
  await fails('B : soumettre la boutique de A refusé', `select shop_submit('${S1}')`, /Boutique introuvable/);
  check('la boutique de A est intacte', (await qs(`select description from shops where id = '${S2}'`))[0].description === 'Nouvelle description Beta');
  // images : dépôt dans son propre dossier du compartiment existant, jamais dans celui d'un autre
  await as(U(1));
  await works('A : téléverse le logo dans son dossier (compartiment listing-images)', `insert into storage.objects (bucket_id, name, owner) values ('listing-images', '${U(1)}/boutique/logo.png', '${U(1)}') returning id`);
  await fails('A : dépôt dans le dossier d\'un autre refusé', `insert into storage.objects (bucket_id, name, owner) values ('listing-images', '${U(2)}/boutique/x.png', '${U(1)}')`, /row-level security|permission denied|violates/i);
  // validation par l'équipe puis désactivation / réactivation d'UNE boutique
  await as(U(2));
  await works('B : soumet sa boutique', `select shop_submit('${S4}') r`, (r) => r[0].r === 'pending');
  await as(U(1));
  await works('A : soumet Alpha à validation', `select shop_submit('${S1}') r`, (r) => r[0].r === 'pending');
  await works('A : soumet Beta à validation', `select shop_submit('${S2}') r`, (r) => r[0].r === 'pending');
  await as(U(7));
  await works('équipe : valide Alpha', `select shop_decide('${S1}', 'approve') r`, (r) => r[0].r === 'active');
  await works('équipe : valide Beta', `select shop_decide('${S2}', 'approve') r`, (r) => r[0].r === 'active');
  await works('équipe : valide la boutique de B', `select shop_decide('${S4}', 'approve') r`, (r) => r[0].r === 'active');
  await as(null, 'anon');
  await works('anonyme : voit la fiche publique de Beta (données publiques seulement)', `select shop_public('beta-h131') r`, (r) => r[0].r.found === true && r[0].r.shop.name === 'Beta H131' && r[0].r.members === undefined && !('promo_codes' in r[0].r));
  await as(U(2));
  await fails('B : désactiver la boutique de A refusé', `select shop_set_enabled('${S1}', false)`, /Boutique introuvable/);
  await as(U(1));
  await works('A : désactive Beta seule', `select shop_set_enabled('${S2}', false) r`, (r) => r[0].r === 'paused');
  check('Alpha reste active, Beta désactivée', (await qs(`select string_agg(status, ',' order by slug) s from shops where id in ('${S1}','${S2}')`))[0].s === 'active,paused');
  await as(null, 'anon');
  await works('anonyme : la boutique désactivée disparaît de la vitrine', `select shop_public('beta-h131') r`, (r) => r[0].r.found === false);
  await as(U(1));
  await works('A : réactive Beta', `select shop_set_enabled('${S2}', true) r`, (r) => r[0].r === 'active');

  // ============================================================ 3. boutique active (persistance serveur, bascule sans reconnexion)
  await works('A : my_shops liste ses boutiques avec compteurs réels', `select my_shops() r`, (r) => r[0].r.length === 4 && r[0].r.every((s) => s.role === 'owner' && s.listings && 'pending_orders' in s && 'stock_units' in s));
  await works('A : Delta (dernière créée) est la boutique active', `select my_shop() r`, (r) => r[0].r.id === S5 && r[0].r.my_role === 'owner');
  await works('A : bascule sur Beta', `select shop_set_active('${S2}') r`, (r) => r[0].r.active_shop_id === S2);
  check('boutique active enregistrée en base (shop_active)', (await qs(`select shop_id from shop_active where user_id = '${U(1)}'`))[0].shop_id === S2);
  await works('A : my_shop suit la boutique active', `select my_shop() r`, (r) => r[0].r.id === S2);
  await works('A : my_shops marque Beta comme active', `select my_shops() r`, (r) => r[0].r.filter((s) => s.is_active).length === 1 && r[0].r.find((s) => s.is_active).id === S2);
  await as(U(2));
  await fails('B : activer la boutique de A refusé', `select shop_set_active('${S1}')`, /Boutique introuvable/);
  await as(U(1));
  await works('A : bascule sur Alpha', `select shop_set_active('${S1}') r`, (r) => r[0].r.active_shop_id === S1);

  // ============================================================ 4. annonces rattachées à la bonne boutique, déplacement, variantes
  const mk = async (seller, title, o = {}) => (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) values ('${seller}', '${title}', 'Design', '${o.category ?? 'Mode'}', ${o.price ?? 10000}, ${o.stock ?? 20}, '${o.status ?? 'approved'}', '{${url(1, 'photo.jpg')}}', ${o.shop ? `'${o.shop}'` : 'null'}) returning id`))[0].id;
  const L1 = await mk(U(1), 'Robe Alpha H131', { price: 10000, stock: 20, shop: S1 });
  const L2 = await mk(U(1), 'Sac Beta H131', { price: 6000, stock: 20, shop: S2 });
  const L2b = await mk(U(1), 'Sac Beta bis H131', { price: 7000, stock: 20, shop: S2 });
  const LB = await mk(U(2), 'Article B H131', { price: 4000, stock: 20, shop: S4 });
  const shopOf = async (id) => (await qs(`select shop_id from listings where id = '${id}'`))[0].shop_id;
  await works('A : une annonce créée sans boutique rejoint sa boutique ACTIVE (Alpha)', `insert into listings (title, department, category, price, stock, status, images) values ('Nouvelle H131', 'Design', 'Mode', 5000, 5, 'draft', '{${url(1, 'p.jpg')}}') returning shop_id`, (r) => r[0].shop_id === S1);
  await works('A : une annonce créée avec la boutique Beta y est rattachée', `insert into listings (title, department, category, price, stock, status, images, shop_id) values ('Autre H131', 'Design', 'Mode', 5000, 5, 'draft', '{${url(1, 'p.jpg')}}', '${S2}') returning shop_id`, (r) => r[0].shop_id === S2);
  await fails('A : annonce rattachée à la boutique de B refusée', `insert into listings (title, department, category, price, stock, status, images, shop_id) values ('Vol H131', 'Design', 'Mode', 5000, 5, 'draft', '{${url(1, 'p.jpg')}}', '${S4}')`, /n'appartient pas au vendeur/);
  await fails('A : déplacer sa propre annonce vers la boutique de B refusé', `select listing_move_shop('${L1}', '${S4}')`, /Boutique introuvable/);
  await as(U(2));
  await fails('B : déplacer l\'annonce de A refusé', `select listing_move_shop('${L1}', '${S4}')`, /Annonce introuvable/);
  await noRows('B : modifier directement la boutique d\'une annonce de A (RLS) sans effet', `update listings set shop_id = '${S4}' where id = '${L1}' returning id`);
  check('l\'annonce de A n\'a pas changé de boutique', (await shopOf(L1)) === S1);
  // variantes : suivent l'annonce
  let vM;
  await as(U(1));
  await works('A : variante M sur l\'annonce Alpha (stock 7)', `select variant_save('${L1}', 'M', '{"taille":"M"}'::jsonb, 'H131-M', 7, 1) r`, (r) => { vM = r[0].r.id; return true; });
  // vente flash / pack / campagne attachés à Alpha, puis conflit de déplacement
  await works('A (boutique Alpha) : campagne « mise en avant » avec L1', `select campaign_save('Vitrine Alpha', 'Produits mis en avant', null, array['${L1}']::uuid[], null, null, '${S1}') r`);
  await works('A : déplace L1 vers Beta (campagne d\'Alpha sans effet de bord ailleurs)', `select listing_move_shop('${L1}', '${S2}') r`, (r) => r[0].r.moved === true && r[0].r.removed_from_campaigns === 1 && r[0].r.shop_id === S2);
  check('L1 appartient maintenant à Beta', (await shopOf(L1)) === S2);
  check('la campagne d\'Alpha ne contient plus L1', (await qs(`select cardinality(listing_ids) n from shop_campaigns where shop_id = '${S1}'`))[0].n === 0);
  check('la variante a suivi l\'annonce (stock et variantes intacts)', (await qs(`select count(*)::int c, sum(stock)::int s from listing_variants where listing_id = '${L1}'`))[0].s === 7);
  await works('A : déplacer vers la même boutique ne change rien', `select listing_move_shop('${L1}', '${S2}') r`, (r) => r[0].r.moved === false);
  await works('A : ramène L1 dans Alpha', `select listing_move_shop('${L1}', '${S1}') r`, (r) => r[0].r.moved === true);
  await works('A : vente flash sur L1 (boutique Alpha)', `select flash_save('${L1}', 8000, 5, now() - interval '1 hour', now() + interval '2 days', '${S1}') r`);
  await fails('A : déplacer L1 avec une vente flash en cours refusé', `select listing_move_shop('${L1}', '${S2}')`, /vente flash/);
  check('L1 est restée dans Alpha', (await shopOf(L1)) === S1);
  await works('A (Beta) : pack de deux produits de Beta', `select pack_save('Pack Beta', 'Deux sacs', 12000, '[{"listing":"${L2}","qty":1},{"listing":"${L2b}","qty":1}]'::jsonb, '${S2}') r`);
  await fails('A : déplacer un produit d\'un pack actif refusé', `select listing_move_shop('${L2}', '${S1}')`, /pack actif/);

  // ============================================================ 5. promotions et événements par boutique
  await works('A : code promo ALPHA10 pour Alpha (p_shop)', `select promo_save('ALPHA10', 'percent', 10, 0, null, null, true, false, '${S1}') r`);
  await works('A : code promo BETA5 pour Beta (p_shop)', `select promo_save('BETA5', 'percent', 5, 0, null, null, true, false, '${S2}') r`);
  await works('A : code sans p_shop = boutique ACTIVE (Alpha)', `select promo_save('ACTIVE15', 'percent', 15) r`);
  check('chaque code est rattaché à sa boutique', JSON.stringify((await qs(`select code, shop_id from promo_codes where code in ('ALPHA10','BETA5','ACTIVE15') order by code`)).map((x) => [x.code, x.shop_id === S1 ? 'S1' : x.shop_id === S2 ? 'S2' : '?'])) === JSON.stringify([['ACTIVE15', 'S1'], ['ALPHA10', 'S1'], ['BETA5', 'S2']]));
  await works('A : my_promotions(Alpha) ne montre que ses codes et sa vente flash', `select my_promotions('${S1}') r`, (r) => r[0].r.codes.map((c) => c.code).sort().join() === 'ACTIVE15,ALPHA10' && r[0].r.flash.length === 1 && r[0].r.packs.length === 0);
  await works('A : my_promotions(Beta) ne montre que son code et son pack', `select my_promotions('${S2}') r`, (r) => r[0].r.codes.map((c) => c.code).join() === 'BETA5' && r[0].r.packs.length === 1 && r[0].r.flash.length === 0);
  await fails('A : vente flash d\'un produit de Beta au nom d\'Alpha refusée', `select flash_save('${L2}', 3000, 2, now(), now() + interval '1 day', '${S1}')`, /Produit introuvable dans votre boutique/);
  await fails('A : campagne d\'Alpha avec un produit de Beta refusée', `select campaign_save('Mélange', null, null, array['${L2}']::uuid[], null, null, '${S1}')`, /Produit hors de votre boutique/);
  await fails('A : pack d\'Alpha avec des produits de Beta refusé', `select pack_save('Pack mélangé', null, 5000, '[{"listing":"${L2}","qty":1},{"listing":"${L2b}","qty":1}]'::jsonb, '${S1}')`, /produit approuvé de votre boutique/);
  await as(U(2));
  await fails('B : code promo au nom de la boutique de A refusé', `select promo_save('PIRATE10', 'percent', 10, 0, null, null, true, false, '${S1}')`, /Boutique introuvable/);
  await works('B : son propre code promo fonctionne', `select promo_save('BCODE10', 'percent', 10, 0, null, null, true, false, '${S4}') r`);
  const codeA = (await qs(`select id from promo_codes where code = 'ALPHA10'`))[0].id;
  await fails('B : désactiver le code de A refusé', `select promo_toggle('${codeA}', false)`, /Code promo introuvable/);
  await fails('B : my_promotions(boutique de A) refusé', `select my_promotions('${S1}')`, /Boutique introuvable/);
  await noRows('B : lecture directe des codes de A (RLS) : aucune ligne', `select * from promo_codes where shop_id = '${S1}'`);
  await as(U(1));
  await works('A : désactive son code ALPHA10', `select promo_toggle('${codeA}', false) r`, (r) => r[0].r === false);

  // ============================================================ 6. commande multi-boutiques (une commande, trois boutiques, deux vendeurs)
  await as(U(3));
  const buyOrder = async (its, key) => (await q(`select marketplace_checkout('${JSON.stringify(its)}'::jsonb, false, 'Mobile Money', null, null, '${key}') r`))[0].r;
  let ord;
  try { ord = await buyOrder([{ id: L1, qty: 2, variant_id: vM }, { id: L2, qty: 1 }, { id: LB, qty: 1 }], 'h131-order-0001'); check('acheteur : panier de 3 boutiques (A-Alpha, A-Beta, B) accepté', !!ord.number); } catch (e) { check('acheteur : panier de 3 boutiques accepté', false, e.message); throw e; }
  const lines = await qs(`select ol.title, ol.shop_id, ol.qty, ol.unit_price, ol.fulfillment from order_lines ol join orders o on o.id = ol.order_id where o.number = '${ord.number}' order by ol.title`);
  check('chaque ligne porte la boutique de son annonce (Alpha / Beta / B)', lines.length === 3 && lines.find((l) => l.title.startsWith('Robe')).shop_id === S1 && lines.find((l) => l.title.startsWith('Sac Beta')).shop_id === S2 && lines.find((l) => l.title.startsWith('Article')).shop_id === S4);
  await as(U(3));
  await works('acheteur : my_order_split sépare les trois boutiques', `select my_order_split('${ord.number}') r`, (r) => r[0].r.length === 3 && r[0].r.map((g) => g.shop_id).sort().join() === [S1, S2, S4].sort().join());
  await qs(`update orders set paid = true where number = '${ord.number}'`);
  const l1Price = Number(lines.find((l) => l.title.startsWith('Robe')).unit_price);
  await as(U(1));
  await works('A (Alpha) : ne voit que les lignes d\'Alpha', `select number, total, nlines, shop_id from seller_orders('${S1}')`, (r) => r.length === 1 && r[0].nlines === 1 && Number(r[0].total) === l1Price * 2 && r[0].shop_id === S1);
  await works('A (Beta) : ne voit que les lignes de Beta', `select number, total, nlines, shop_id from seller_orders('${S2}')`, (r) => r.length === 1 && r[0].nlines === 1 && Number(r[0].total) === 6000 && r[0].shop_id === S2);
  await works('A sans p_shop : suit la boutique active (Alpha)', `select number, total from seller_orders()`, (r) => r.length === 1 && Number(r[0].total) === l1Price * 2);
  await fails('A : lire les commandes de la boutique de B refusé', `select * from seller_orders('${S4}')`, /Boutique introuvable/);
  await works('A (Alpha) : accepte SEULEMENT les lignes d\'Alpha', `select set_seller_order_status('${ord.number}', 1, '${S1}') r`, (r) => r[0].r === 1);
  const fl = async () => Object.fromEntries((await qs(`select ol.title, ol.fulfillment f from order_lines ol join orders o on o.id = ol.order_id where o.number = '${ord.number}'`)).map((x) => [x.title.split(' ')[0] + x.title.split(' ')[1], x.f]));
  let f = await fl();
  check('seule la boutique Alpha a avancé (Beta et B inchangées)', f.RobeAlpha === 1 && f.SacBeta === 0 && f.ArticleB === 0, JSON.stringify(f));
  await works('A (Beta) : la préparation de Beta est indépendante (statut 1 puis 2)', `select set_seller_order_status('${ord.number}', 1, '${S2}') r`, (r) => r[0].r === 1);
  await works('A (Beta) : étape 2', `select set_seller_order_status('${ord.number}', 2, '${S2}') r`, (r) => r[0].r === 2);
  f = await fl();
  check('Alpha à 1, Beta à 2, B à 0', f.RobeAlpha === 1 && f.SacBeta === 2 && f.ArticleB === 0, JSON.stringify(f));
  await fails('A : étape sautée dans Alpha refusée', `select set_seller_order_status('${ord.number}', 3, '${S1}')`, /dans l'ordre/);
  await as(U(2));
  await fails('B : agir sur les lignes d\'Alpha refusé', `select set_seller_order_status('${ord.number}', 2, '${S1}')`, /Boutique introuvable/);
  await works('B : ne voit que sa ligne', `select number, total, nlines from seller_orders()`, (r) => r.length === 1 && Number(r[0].total) === 4000 && r[0].nlines === 1);
  await works('B : peut préparer sa ligne (sans p_shop : comportement d\'origine)', `select set_seller_order_status('${ord.number}', 1) r`, (r) => r[0].r === 1);
  f = await fl();
  check('les lignes de A n\'ont pas bougé quand B a agi', f.RobeAlpha === 1 && f.SacBeta === 2 && f.ArticleB === 1, JSON.stringify(f));
  await as(U(9));
  await fails('client tiers : seller_orders refusé (aucune boutique)', `select * from seller_orders('${S1}')`, /Boutique introuvable/);
  await noRows('client tiers : lecture directe des lignes de commande (RLS) : aucune ligne', `select * from order_lines where shop_id = '${S1}'`);

  // ============================================================ 7. statistiques sans mélange
  await as(U(1));
  await works('A : seller_overview(Alpha) = ventes d\'Alpha uniquement', `select seller_overview(30, '${S1}') r`, (r) => r[0].r.shop_id === S1 && r[0].r.revenue === l1Price * 2 && r[0].r.units === 2 && r[0].r.orders === 1 && r[0].r.pending_orders === 1);
  await works('A : seller_overview(Beta) = ventes de Beta uniquement', `select seller_overview(30, '${S2}') r`, (r) => r[0].r.revenue === 6000 && r[0].r.units === 1);
  await works('A : seller_overview sans p_shop = boutique active (Alpha), jamais la somme', `select seller_overview() r`, (r) => r[0].r.shop_id === S1 && r[0].r.revenue === l1Price * 2);
  await works('A : produits listés par boutique (Alpha ne liste pas les produits de Beta)', `select seller_overview(30, '${S1}') r`, (r) => r[0].r.products.every((p) => p.shop_id === S1) && !r[0].r.products.some((p) => p.title.startsWith('Sac Beta')));
  await works('A : shop_dashboard(Alpha) / (Beta) séparés', `select shop_dashboard(30, '${S1}') a, shop_dashboard(30, '${S2}') b`, (r) => r[0].a.revenue === l1Price * 2 && r[0].b.revenue === 6000 && r[0].a.shop_id === S1 && r[0].b.shop_id === S2);
  await works('A : my_shops_overview agrège SES boutiques (chiffre d\'affaires = somme, sans la boutique de B)', `select my_shops_overview() r`,
    (r) => r[0].r.totals.revenue_30d === l1Price * 2 + 6000 && r[0].r.totals.shops === 4 && r[0].r.shops.every((s) => s.owner_id === U(1)) && r[0].r.max === 5 && r[0].r.can_create === true);
  await works('A : my_shops donne des compteurs par boutique (commandes en attente Alpha = 1, Beta = 1)', `select my_shops() r`, (r) => r[0].r.find((s) => s.id === S1).pending_orders === 1 && r[0].r.find((s) => s.id === S2).pending_orders === 1 && r[0].r.find((s) => s.id === S1).revenue_30d === l1Price * 2);
  await fails('A : statistiques de la boutique de B refusées', `select seller_overview(30, '${S4}')`, /Boutique introuvable/);
  await as(U(2));
  await works('B : my_shops_overview ne contient que sa boutique', `select my_shops_overview() r`, (r) => r[0].r.totals.shops === 1 && r[0].r.totals.revenue_30d === 4000);
  await works('B : ses statistiques ne contiennent pas les ventes de A', `select seller_overview() r`, (r) => r[0].r.revenue === 4000);
  await as(U(3));
  await works('acheteur : peut noter Alpha (achat réel dans Alpha)', `select can_review_shop('${S1}') r`, (r) => r[0].r === true);
  await as(U(1));
  // la boutique sœur ne confère pas l'avis : l'acheteur a aussi acheté dans Beta, créons Delta (aucun achat)
  await as(U(3));
  await works('acheteur : ne peut pas noter Delta (aucun achat dans cette boutique, même propriétaire)', `select can_review_shop('${S5}') r`, (r) => r[0].r === false);

  // ============================================================ 8. équipe de boutique : droits bornés
  await as(U(1));
  await works('A : ajoute le manager (par identifiant)', `select shop_member_set('${S1}', '${U(4)}', 'manager') r`, (r) => r[0].r.role === 'manager');
  await works('A : ajoute le préparateur (par e-mail)', `select shop_member_set('${S1}', null, 'staff', 'h131s5@t.cm') r`, (r) => r[0].r.user_id === U(5));
  await works('A : ajoute le lecteur', `select shop_member_set('${S1}', '${U(6)}', 'viewer') r`, (r) => r[0].r.role === 'viewer');
  await fails('A : rôle inconnu refusé', `select shop_member_set('${S1}', '${U(9)}', 'admin')`, /Rôle inconnu/);
  await fails('A : ajouter le propriétaire lui-même refusé', `select shop_member_set('${S1}', '${U(1)}', 'viewer')`, /propriétaire n'est pas un membre/);
  await fails('A : utilisateur inexistant refusé', `select shop_member_set('${S1}', null, 'viewer', 'inconnu@t.cm')`, /Utilisateur introuvable/);
  await works('A : liste les membres', `select shop_members_list('${S1}') r`, (r) => r[0].r.length === 3);
  // viewer
  await as(U(6));
  await works('lecteur : voit ses boutiques avec son rôle', `select my_shops() r`, (r) => r[0].r.length === 1 && r[0].r[0].id === S1 && r[0].r[0].role === 'viewer' && r[0].r[0].members === null);
  await works('lecteur : boutique active par défaut = Alpha (sans reconnexion)', `select my_shop() r`, (r) => r[0].r.id === S1 && r[0].r.my_role === 'viewer');
  await works('lecteur : voit les commandes de la boutique', `select number, total from seller_orders('${S1}')`, (r) => r.length === 1 && Number(r[0].total) === l1Price * 2);
  await works('lecteur : voit les statistiques de la boutique', `select seller_overview(30, '${S1}') r`, (r) => r[0].r.revenue === l1Price * 2);
  await works('lecteur : voit produits et stock', `select shop_listings('${S1}') r`, (r) => r[0].r.listings.length >= 1 && r[0].r.listings.every((l) => l.shop_id === S1));
  await fails('lecteur : préparer une commande refusé', `select set_seller_order_status('${ord.number}', 2, '${S1}')`, /Boutique introuvable/);
  await fails('lecteur : créer un code promo refusé', `select promo_save('LECTEUR10', 'percent', 10, 0, null, null, true, false, '${S1}')`, /Boutique introuvable/);
  await fails('lecteur : modifier la boutique refusé', shopSave({ id: S1, description: 'Modif lecteur' }), /Boutique introuvable/);
  await fails('lecteur : lire les commandes d\'une autre boutique de A refusé', `select * from seller_orders('${S2}')`, /Boutique introuvable/);
  await fails('lecteur : gérer les membres refusé', `select shop_member_set('${S1}', '${U(9)}', 'viewer')`, /propriétaire/);
  await fails('lecteur : liste des membres refusée', `select shop_members_list('${S1}')`, /Boutique introuvable/);
  await fails('lecteur : déplacer une annonce refusé', `select listing_move_shop('${L1}', '${S2}')`, /Annonce introuvable/);
  // staff
  await as(U(5));
  await works('préparateur : fait avancer les lignes de la boutique (étape 2)', `select set_seller_order_status('${ord.number}', 2, '${S1}') r`, (r) => r[0].r === 2);
  f = await fl();
  check('le préparateur n\'a touché que les lignes d\'Alpha', f.RobeAlpha === 2 && f.SacBeta === 2 && f.ArticleB === 1, JSON.stringify(f));
  await fails('préparateur : créer un code promo refusé (au-delà de son rôle)', `select promo_save('STAFF10', 'percent', 10, 0, null, null, true, false, '${S1}')`, /Boutique introuvable/);
  await fails('préparateur : modifier la boutique refusé', shopSave({ id: S1, description: 'Modif staff' }), /Boutique introuvable/);
  await fails('préparateur : agir sur une autre boutique de A refusé', `select set_seller_order_status('${ord.number}', 3, '${S2}')`, /Boutique introuvable/);
  await fails('préparateur : retirer un membre refusé', `select shop_member_remove('${S1}', '${U(6)}')`, /propriétaire/);
  // manager
  await as(U(4));
  await works('manager : crée un code promo pour la boutique', `select promo_save('MANAGER10', 'percent', 10, 0, null, null, true, false, '${S1}') r`);
  check('le code du manager appartient à Alpha', (await qs(`select shop_id from promo_codes where code = 'MANAGER10'`))[0].shop_id === S1);
  await works('manager : crée une campagne (produits mis en avant)', `select campaign_save('Mise en avant manager', null, null, array['${L1}']::uuid[], null, null, '${S1}') r`);
  await works('manager : modifie l\'identité visuelle (description, couleur)', shopSave({ id: S1, description: 'Description par le manager', color_secondary: '#8A5A2B' }), (r) => r[0].r.description === 'Description par le manager');
  await works('manager : voit les commandes', `select number from seller_orders('${S1}')`, (r) => r.length === 1);
  await works('manager : une demande de changement d\'adresse publique est sans effet (boutique active)', shopSave({ id: S1, slug: 'alpha-nouveau' }), (r) => r[0].r.slug === 'alpha-h131');
  check('l\'adresse publique d\'Alpha n\'a pas changé', (await qs(`select slug from shops where id = '${S1}'`))[0].slug === 'alpha-h131');
  await fails('manager : désactiver la boutique refusé (propriétaire seul)', `select shop_set_enabled('${S1}', false)`, /Boutique introuvable/);
  await fails('manager : fermer la boutique refusé', `select shop_close('${S1}')`, /Fermeture impossible/);
  await fails('manager : gérer les membres refusé', `select shop_member_set('${S1}', '${U(9)}', 'manager')`, /propriétaire/);
  await fails('manager : promotions d\'une autre boutique de A refusées', `select promo_save('MANAGER20', 'percent', 10, 0, null, null, true, false, '${S2}')`, /Boutique introuvable/);
  await fails('manager : se faire passer propriétaire (changer de propriétaire) impossible : listing_move_shop refusé', `select listing_move_shop('${L1}', '${S2}')`, /Annonce introuvable/);
  await noRows('manager : écriture directe dans shop_members (RLS) refusée', `insert into shop_members (shop_id, user_id, role) values ('${S1}', '${U(9)}', 'manager') returning *`);
  await works('manager : change sa boutique active sans reconnexion (Alpha, seule boutique accessible)', `select shop_set_active('${S1}') r`, (r) => r[0].r.active_shop_id === S1);
  // étranger
  await as(U(9));
  await fails('tiers : liste des membres refusée', `select shop_members_list('${S1}')`, /Boutique introuvable/);
  await fails('tiers : ajout de membre refusé', `select shop_member_set('${S1}', '${U(9)}', 'manager')`, /Boutique introuvable/);
  await fails('tiers : produits et stock refusés', `select shop_listings('${S1}')`, /Boutique introuvable/);
  await noRows('tiers : lecture directe de shop_members (RLS) : aucune ligne', `select * from shop_members`);
  await works('tiers : my_shops vide (aucun compteur d\'autrui)', `select my_shops() r`, (r) => r[0].r.length === 0);
  await as(U(2));
  await fails('B : ajouter un membre à la boutique de A refusé', `select shop_member_set('${S1}', '${U(9)}', 'viewer')`, /Boutique introuvable/);
  // retrait / départ / suspension
  await as(U(6));
  await works('lecteur : peut quitter l\'équipe (se retirer lui-même)', `select shop_member_remove('${S1}', '${U(6)}') r`, (r) => r[0].r === true);
  await fails('lecteur parti : plus d\'accès aux commandes', `select * from seller_orders('${S1}')`, /Boutique introuvable/);
  await as(U(1));
  await works('A : retire le préparateur', `select shop_member_remove('${S1}', '${U(5)}') r`, (r) => r[0].r === true);
  await as(U(5));
  await fails('préparateur retiré : préparer refusé', `select set_seller_order_status('${ord.number}', 3, '${S1}')`, /Boutique introuvable/);
  await qs(`update profiles set suspended = true where id = '${U(4)}'`);
  await as(U(4));
  await fails('manager suspendu : plus d\'accès', `select promo_save('SUSPEND10', 'percent', 10, 0, null, null, true, false, '${S1}')`, /Boutique introuvable|suspendu/i);
  await qs(`update profiles set suspended = false where id = '${U(4)}'`);

  // ============================================================ 9. écritures directes et anonyme
  await as(U(1));
  await fails('A : écriture directe du statut d\'une boutique refusée', `update shops set status = 'active', name = 'Hack' where id = '${S3}'`, /Utilisez les fonctions|permission denied/);
  await fails('A : écriture directe de shop_active refusée', `update shop_active set shop_id = '${S4}' where user_id = '${U(1)}'`, /permission denied/);
  await as(null, 'anon');
  await fails('anonyme : my_shops_overview refusé', `select my_shops_overview()`, DENY);
  await fails('anonyme : shop_member_set refusé', `select shop_member_set('${S1}', '${U(9)}', 'viewer')`, DENY);
  await fails('anonyme : listing_move_shop refusé', `select listing_move_shop('${L1}', '${S2}')`, DENY);
  await fails('anonyme : seller_orders refusé', `select * from seller_orders('${S1}')`, DENY);
  await fails('anonyme : shop_members illisible', `select * from shop_members`, /permission denied/);
  await fails('anonyme : promo_codes illisible', `select * from promo_codes`, /permission denied/);
  await works('anonyme : ne voit que les boutiques actives (Gamma en attente et Delta brouillon invisibles)', `select count(*)::int n from shops where status <> 'active'`, (r) => r[0].n === 0);
  await as(U(2));
  await works('B : ne voit pas les brouillons de A (RLS)', `select count(*)::int n from shops where owner_id = '${U(1)}' and status <> 'active'`, (r) => r[0].n === 0);

  // ============================================================ 10. rejeu des migrations sans effet de bord
  await sup();
  const before = (await q(`select (select count(*) from shops) s, (select count(*) from shop_members) m, (select count(*) from shop_active) ss, (select count(*) from promo_codes) p, (select count(*) from order_lines) ol`))[0];
  const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations');
  for (const f of fs.readdirSync(dir).filter((x) => x.startsWith('202611290301') || x.startsWith('202611290302') || x.startsWith('20261129030000'))) {
    try { await db.exec(fs.readFileSync(path.join(dir, f), 'utf8')); check(`rejeu de ${f} sans erreur`, true); } catch (e) { check(`rejeu de ${f} sans erreur`, false, e.message); }
  }
  const after = (await q(`select (select count(*) from shops) s, (select count(*) from shop_members) m, (select count(*) from shop_active) ss, (select count(*) from promo_codes) p, (select count(*) from order_lines) ol`))[0];
  check('le rejeu ne modifie aucune donnée', JSON.stringify(before) === JSON.stringify(after), JSON.stringify([before, after]));
  check('le rejeu garde la limite réglée (5)', Number((await q(`select shops_max_per_owner() n`))[0].n) === 5);
  await as(U(1));
  await works('après rejeu : my_shops et statistiques inchangées', `select my_shops() r, seller_overview(30, '${S1}') o`, (r) => r[0].r.length === 4 && r[0].o.revenue === l1Price * 2);

  console.log(`h131_shops : ${ok} OK, ${ko} KO`);
}
