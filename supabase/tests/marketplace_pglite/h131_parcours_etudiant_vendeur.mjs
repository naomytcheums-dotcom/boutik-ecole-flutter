// H13.1 lot ACTORS - parcours ETUDIANT -> VENDEUR sur la base PGlite rejouee, en vrais appels avec jwt claims par acteur et garde db_pre_request simulee.
// Etapes : inscription, informations academiques, rattachement (affiliation) valide par SON departement, piece d'etudiant validee, portfolio, capacite de vente (seller_capable),
// boutique + annonce + variantes + stock, reception d'une commande et passage d'etat, talents / projets / contenus, notifications et messages.
// Le paiement n'est jamais simule : la commande de l'etape vendeur utilise le paiement a la LIVRAISON (confirme par l'acheteur lui-meme, aucun argent encaisse), car il n'existe
// aucune fonction serveur de confirmation de paiement « de test ».
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_parcours_etudiant_vendeur.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 2);
  const { U, as, anon, sup, q, qs, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  await db.exec('grant all on storage.objects to authenticated');

  const IMG = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/lampe.jpg';
  const I1 = U(800), D1 = U(801), D2 = U(802), P1 = U(803), P2 = U(804);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Etablissement Parcours', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I1}', 'Gestion', 'verified');
    insert into programs (id, institution_id, department_id, name, active) values ('${P1}', '${I1}', '${D1}', 'Licence Informatique', true), ('${P2}', '${I1}', '${D2}', 'Licence Gestion', true)`);
  const ADM = await user(1, 'Ada Admin', 'admin');
  const DH1 = await user(2, 'Chef Informatique', 'dept');
  const DH2 = await user(3, 'Chef Gestion', 'dept');
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${DH1}', '${D1}'), ('${DH2}', '${D2}');
    update profiles set institution_id='${I1}', department_id='${D1}', department='Informatique' where id='${DH1}';
    update profiles set institution_id='${I1}', department_id='${D2}', department='Gestion' where id='${DH2}'`);
  const BUY = await user(4, 'Cora Cliente', 'client');
  const RIV = await user(5, 'Rival Vendeur', 'student', `update profiles set phone='691320005', phone_verified=true, certification='approved', institution_id='${I1}', department_id='${D2}', department='Gestion' where id='${U(5)}'`);
  await db.exec(`insert into shops (owner_id, name, slug, status) values ('${RIV}', 'Boutique Rivale', 'boutique-rivale-p2', 'active');
    insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) select '${RIV}', 'Produit du rival RIVALMARK', 'Gestion', 'Maison', 4000, 9, 'approved', '{p.jpg}', id from shops where owner_id = '${RIV}'`);
  const ORG = await user(6, 'Org Recruteur', 'company');
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${ORG}', 'Recruteur Parcours', 'approved')`);
  await sup();

  // ---------------------------------------------------------------- 1. inscription et profil academique
  await db.exec(`insert into auth.users(id,email) values ('${U(10)}','h131-2-10@t.cm')`);
  const S = U(10);
  await as(S);
  await works('E1 inscription : profil etudiant cree par l\'utilisateur', `insert into profiles (id, name, email, role) values ('${S}', 'Awa Etudiante', 'h131-2-10@t.cm', 'student') returning role`, (r) => r[0].role === 'student');
  await works('E2 informations academiques (etablissement, departement, matricule, niveau)', `select profile_set_academic('${I1}', '${D1}', 'MAT-0131', 'L2') r`);
  await works('E3 capacite de vente : refusee tant que rien n\'est verifie', `select my_seller_capability() r`, (r) => r[0].r.can_sell === false && r[0].r.missing.includes('student_verified') && r[0].r.missing.includes('phone_verified'));
  await fails('E4 une annonce a publier est refusee tant que le statut etudiant n\'est pas verifie', `insert into listings (seller_id, title, department, category, price, stock, status, images) values ('${S}', 'Trop tot', 'Informatique', 'Maison', 5000, 3, 'pending', '{${IMG}}')`, /statut d.étudiant|téléphone|vérifi|certifi/i);
  await fails('E5 une boutique a publier est refusee tant que le compte n\'est pas eligible', `select shop_submit()`, /statut d.étudiant|téléphone|vérifi|Boutique|boutique|introuvable/i);
  await fails('E6 le telephone ne se declare pas « verifie » soi-meme', `update profiles set phone_verified = true where id = '${S}'`, /permission denied/i);
  await fails('E7 la certification ne s\'attribue pas soi-meme', `update profiles set certification = 'approved' where id = '${S}'`, /permission denied/i);

  // ---------------------------------------------------------------- 2. rattachement (affiliation) : valide par SON departement uniquement
  const aff = (await works('A1 demande de rattachement a une filiere', `select student_affiliation_request('${P1}', '2026') r`, (r) => r[0].r.id != null))?.[0]?.r.id;
  await works('A2 l\'etudiante voit sa demande en attente', `select my_student_affiliation() r`, (r) => r[0].r.current.status === 'pending');
  await fails('A3 insertion directe d\'un rattachement « verifie » refusee', `insert into student_affiliations (user_id, institution_id, program_id, promotion, status) values ('${S}', '${I1}', '${P1}', '2026', 'verified')`, /permission denied/i);
  await fails('A4 l\'etudiante ne decide pas sa propre demande', `select student_affiliation_decide('${aff}', 'verified', 'ok')`, DENY);
  await as(DH2);
  await works('A5 le responsable d\'un AUTRE departement ne voit pas la demande', `select student_affiliation_queue() r`, (r) => !r[0].r.some((x) => x.id === aff));
  await fails('A6 le responsable d\'un autre departement ne peut pas la decider', `select student_affiliation_decide('${aff}', 'verified', 'hors perimetre')`, DENY);
  await as(RIV);
  await fails('A7 un autre etudiant ne peut pas la decider', `select student_affiliation_decide('${aff}', 'verified', 'x')`, DENY);
  await as(DH1);
  await works('A8 le responsable du bon departement voit la demande', `select student_affiliation_queue() r`, (r) => r[0].r.some((x) => x.id === aff));
  await works('A9 le responsable du bon departement valide le rattachement', `select student_affiliation_decide('${aff}', 'verified', 'Inscrit en L2') r`);
  await as(S);
  await works('A10 l\'etudiante voit son rattachement valide', `select my_student_affiliation() r`, (r) => r[0].r.current.status === 'verified');
  await as(BUY);
  await fails('A11 un client ne demande pas de rattachement', `select student_affiliation_request('${P1}', '2026')`, /Réservé aux comptes étudiants/);

  // ---------------------------------------------------------------- 3. piece d'etudiant : validee par le departement, telephone verifie par le service OTP
  await sup();
  await db.exec(`insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${S}/student_card/carte.pdf', '{"mimetype":"application/pdf","size":1000}')`);
  await as(S);
  const doc = (await works('D1 l\'etudiante depose sa carte d\'etudiant', `select document_register('student_card', '${S}/student_card/carte.pdf', 'carte.pdf', 'application/pdf', 1000) id`))?.[0]?.id;
  await fails('D2 elle ne valide pas sa propre piece', `select document_decide('${doc}', 'verified')`, DENY);
  await as(DH2);
  await works('D3 le responsable d\'un autre departement ne voit pas la piece', `select documents_to_review() r`, (r) => r[0].r.length === 0);
  await fails('D4 ... et ne la decide pas', `select document_decide('${doc}', 'verified')`, DENY);
  await as(DH1);
  await works('D5 son responsable de departement valide la piece', `select document_decide('${doc}', 'verified') r`);
  await sup();
  check('D6 etudiante verifiee (is_verified_student)', (await qs(`select is_verified_student('${S}') v`))[0].v === true);
  await db.exec(`update profiles set phone = '691320010', phone_verified = true where id = '${S}'`);
  await as(S);
  await works('D7 capacite de vente : complete', `select my_seller_capability() r`, (r) => r[0].r.can_sell === true && r[0].r.can_receive_orders === true);

  // certification du compte (necessaire pour publier une annonce)
  await works('C1 demande de certification du compte', `select submit_certification_request('Etudiante en L2, je souhaite vendre mes realisations', 'https://exemple.cm/portfolio')`);
  await fails('C2 l\'etudiante ne se certifie pas elle-meme', `select decide_certification('${S}', 'approved', 'ok')`, DENY);
  await as(DH2);
  await fails('C3 le responsable d\'un autre departement ne la certifie pas', `select decide_certification('${S}', 'approved', 'hors perimetre')`, DENY);
  await as(DH1);
  await works('C4 son responsable de departement certifie le compte', `select decide_certification('${S}', 'approved', 'Inscrite en L2')`);
  await as(S);
  await works('C5 le compte est certifie', `select certification::text c from profiles where id = '${S}'`, (r) => r[0].c === 'approved');

  // ---------------------------------------------------------------- 4. portfolio
  const pf = (await works('PF1 portfolio : ajout d\'une realisation', `select portfolio_save(null, 'realisation', 'Application de gestion de stock', 'Projet de L2', 'Informatique', '2026-05-01', '', null, true) id`))?.[0]?.id;
  await works('PF2 portfolio : modification', `select portfolio_save('${pf}', 'realisation', 'Application de gestion de stock v2', 'Projet de L2', 'Informatique', '2026-05-01', '', null, true) id`);
  await works('PF3 portfolio : lecture de ses propres elements', `select id, title from portfolio_items`, (r) => r.length === 1 && r[0].title.endsWith('v2'));
  await as(RIV);
  await works('PF4 un autre etudiant ne lit pas ce portfolio (RLS ou visibilite)', `select id from portfolio_items where owner_id = '${S}' and not coalesce(featured, false)`, (r) => r.length === 0);
  await fails('PF5 un autre etudiant ne le modifie pas', `select portfolio_save('${pf}', 'realisation', 'Detourne', '', '', '', '', null, false)`, DENY);
  await fails('PF6 un autre etudiant ne le supprime pas', `select portfolio_delete('${pf}')`, DENY);
  await as(S);
  check('PF7 le portfolio est reste intact', (await qs(`select title from portfolio_items where id = '${pf}'`))[0].title.endsWith('v2'));

  // ---------------------------------------------------------------- 5. boutique + annonce + variantes + stock
  const LOGO = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/boutique/logo.png';
  await as(S);
  await works('B1 boutique : creation (brouillon)', `select shop_save('{"name":"Boutique Awa Etudiante","description":"Objets utiles","logo_url":"${LOGO}","categories":["Maison"]}'::jsonb) s`);
  await works('B2 boutique : soumission a la moderation', `select shop_submit() r`);
  await fails('B3 l\'etudiante ne valide pas sa propre boutique', `select shop_decide((select id from shops where owner_id = '${S}'), 'approve')`, DENY);
  await as(BUY);
  await fails('B4 un client ne valide pas une boutique', `select shop_decide((select id from shops where owner_id = '${S}'), 'approve')`, DENY);
  await as(ADM);
  await works('B5 l\'administrateur valide la boutique', `select shop_decide((select id from shops where owner_id = '${S}'), 'approve') r`);
  await as(S);
  const shopId = (await qs(`select id, status from shops where owner_id = '${S}'`))[0];
  check('B6 la boutique est active', shopId.status === 'active', JSON.stringify(shopId));
  const lst = (await works('B7 annonce : creation soumise a la moderation', `insert into listings (seller_id, title, department, category, price, stock, description, status, images, shop_id) values ('${S}', 'Lampe etudiante VENDEUR', 'Informatique', 'Maison', 15000, 4, 'Lampe en bois', 'pending', '{${IMG}}', '${shopId.id}') returning id`))?.[0]?.id;
  await anon();
  await works('B8 anonyme : l\'annonce en attente n\'est pas publique', `select marketplace_search('VENDEUR') r`, (r) => !JSON.stringify(r[0].r).includes('Lampe etudiante VENDEUR'));
  await as(S);
  try { await q(`update listings set status = 'approved' where id = '${lst}'`); } catch { /* refus accepte */ }
  check('B9b l\'annonce est toujours en attente apres l\'auto-validation tentee', (await qs(`select status from listings where id = '${lst}'`))[0].status === 'pending');
  await as(DH1);
  await works('B10 le responsable de son departement voit l\'annonce dans sa file', `select listing_review_queue() r`, (r) => JSON.stringify(r[0].r).includes('Lampe etudiante VENDEUR'));
  await as(DH2);
  await works('B11 le responsable d\'un autre departement ne la voit pas', `select listing_review_queue() r`, (r) => !JSON.stringify(r[0].r).includes('Lampe etudiante VENDEUR'));
  await noEffect('B12 ... et ne peut pas la valider (RLS)', `update listings set status = 'approved' where id = '${lst}' returning id`);
  await as(ADM);
  await works('B13 l\'administrateur valide l\'annonce', `update listings set status = 'approved' where id = '${lst}' returning id`, (r) => r.length === 1);
  await anon();
  await works('B14 anonyme : l\'annonce validee est publique', `select marketplace_search('VENDEUR') r`, (r) => JSON.stringify(r[0].r).includes('Lampe etudiante VENDEUR'));

  await as(S);
  let vS, vM;
  await works('V1 variante S (stock 3)', `select variant_upsert('${lst}', 'S', '{"taille":"S"}'::jsonb, 'LAMP-S', 3, 1) r`, (r) => { vS = r[0].r.id; return r[0].r.stock === 3; });
  await works('V2 variante M a prix propre 17000 (stock 2)', `select variant_upsert('${lst}', 'M', '{"taille":"M"}'::jsonb, 'LAMP-M', 2, 1, null, 17000) r`, (r) => { vM = r[0].r.id; return r[0].r.price === 17000; });
  await works('V3 reapprovisionnement de la variante S (+4)', `select variant_adjust('${vS}', null, 4, 'Reapprovisionnement') r`);
  await works('V4 la variante S a 7 en stock', `select stock from listing_variants where id = '${vS}'`, (r) => r[0].stock === 7);
  await as(RIV);
  await fails('V5 un autre vendeur ne modifie pas le stock de cette variante', `select variant_adjust('${vS}', 999, null, 'detournement')`, /introuvable/i);
  await fails('V6 un autre vendeur ne cree pas de variante sur cette annonce', `select variant_upsert('${lst}', 'XL', '{}'::jsonb, null, 1, 1)`, /introuvable/i);
  await as(BUY);
  await fails('V7 un client n\'ecrit pas le stock d\'une variante', `update listing_variants set stock = 500 where id = '${vS}'`, /permission denied/i);
  check('V8 le stock de la variante S est reste a 7', (await qs(`select stock from listing_variants where id = '${vS}'`))[0].stock === 7);

  // ---------------------------------------------------------------- 6. reception d'une commande et passage d'etat (paiement a la livraison)
  await as(BUY);
  const ord = (await works('O1 un client commande 2 variantes M (paiement a la livraison)', `select marketplace_checkout('[{"id":"${lst}","variant_id":"${vM}","qty":1}]'::jsonb, false, 'Paiement à la livraison') r`, (r) => r[0].r.subtotal === 17000))?.[0]?.r;
  await as(S);
  await works('O2 la vendeuse ne voit pas la commande tant qu\'elle n\'est pas confirmee', `select * from seller_orders()`, (r) => !r.some((x) => x.number === ord.number));
  await fails('O3 la vendeuse ne peut pas faire avancer une commande non confirmee', `select set_seller_order_status('${ord.number}', 1)`, /./);
  await as(BUY);
  await works('O4 l\'acheteur confirme sa commande (paiement a la livraison)', `select confirm_cod_order('${ord.number}') r`);
  await as(S);
  await works('O5 la vendeuse voit maintenant la commande', `select * from seller_orders()`, (r) => r.some((x) => x.number === ord.number));
  await as(RIV);
  await works('O6 un autre vendeur ne voit pas cette commande', `select * from seller_orders()`, (r) => !r.some((x) => x.number === ord.number));
  await fails('O7 un autre vendeur ne la fait pas avancer', `select set_seller_order_status('${ord.number}', 1)`, DENY);
  await as(BUY);
  await fails('O8 l\'acheteur ne se met pas lui-meme « expediee »', `select set_seller_order_status('${ord.number}', 2)`, DENY);
  await as(S);
  for (const st of [1, 2, 3]) await works(`O9.${st} la vendeuse passe la commande a l'etat ${st}`, `select set_seller_order_status('${ord.number}', ${st}) r`);
  await fails('O10 etape deja atteinte refusee', `select set_seller_order_status('${ord.number}', 2)`, /déjà atteint/);
  await as(BUY);
  await works('O11 l\'acheteur suit l\'avancement', `select order_tracking('${ord.number}') r`, (r) => r[0].r != null);
  await as(RIV);
  await fails('O12 un autre vendeur ne suit pas la commande', `select order_tracking('${ord.number}')`, /introuvable|autoris/i);
  check('O13 le stock de la variante M est decremente (1)', (await qs(`select stock from listing_variants where id = '${vM}'`))[0].stock === 1);

  // ---------------------------------------------------------------- 7. talents, projets, contenus
  await as(S);
  await works('T1 competence ajoutee au profil talent', `select skill_save(null, 'dev', 'Developpeur', 'Flutter', 'avance', 2, 'Applications mobiles', null) r`);
  await works('T2 tableau de bord talent lisible', `select my_talent_dashboard() r`);
  await works('T3 visibilite talent activee', `select talent_visibility_set(true) r`, (r) => r[0].r === true);
  const prj = (await works('T4 projet soumis a validation', `select project_save_full(null, 'projet', 'Ma serre connectee', 'Une description suffisamment longue pour publier ce projet.', 'Informatique', '{"domain":"agri","problem":"Arrosage manuel","solution":"Capteurs et pompe","progress":"prototype","contact_email":"a@b.cm"}'::jsonb, '[]'::jsonb, 'public', true) id`))?.[0]?.id;
  await fails('T5 l\'etudiante ne valide pas son propre projet', `select review_project('${prj}', true, '')`, DENY);
  await as(DH2);
  await fails('T6 le responsable d\'un autre departement ne valide pas ce projet', `select review_project('${prj}', true, '')`, /autre département|Réservé|Aucun projet|autoris/i);
  await as(DH1);
  await works('T7 le responsable du bon departement valide le projet', `select review_project('${prj}', true, '') r`, (r) => r[0].r === 'approved');
  await anon();
  await works('T8 anonyme : le projet valide est visible publiquement', `select public_projects() r`, (r) => JSON.stringify(r[0].r).includes('Ma serre connectee'));
  await as(S);
  const postR = (await works('T9 contenu : publication creee (en moderation)', `select create_post_v2('Premier contenu de l''etudiante', '[]'::jsonb, null, '{}', null, null) id`))?.[0]?.id;
  const post = postR?.id ?? postR;
  await as(DH1);
  await works('T10a son responsable de departement retire la publication', `select moderate_post('${post}', false, 'A reprendre') r`);
  await as(S);
  await works('T10b l\'etudiante voit toujours sa publication retiree', `select status from posts where id = '${post}'`, (r) => r.length === 1 && r[0].status !== 'published');
  await as(RIV);
  await works('T10 un autre etudiant ne voit pas une publication non publiee', `select id from posts where id = '${post}'`, (r) => r.length === 0);
  await fails('T11 un etudiant ne modere pas la publication d\'autrui', `select moderate_post('${post}', true, '')`, DENY);
  await as(DH1);
  await works('T12 le responsable de son departement la publie', `select moderate_post('${post}', true, '') r`, (r) => r[0].r === 'published');
  await as(RIV);
  await works('T13 elle est desormais visible des autres comptes', `select id from posts where id = '${post}'`, (r) => r.length === 1);
  await as(ORG);
  await works('T14 une organisation approuvee voit l\'etudiante verifiee dans l\'annuaire des talents', `select talents_list('') t`, (r) => JSON.stringify(r[0].t).includes(S));
  await as(BUY);
  await works('T15 un client ne voit l\'etudiante que sous un nom abrege (ni nom complet, ni e-mail, ni telephone)', `select talents_list('') t`, (r) => { const s = JSON.stringify(r[0].t); return !s.includes('Awa Etudiante') && !s.includes('h131-2-10') && !s.includes('691320010'); });
  await anon();
  await fails('T16 anonyme : l\'annuaire des talents est refuse', `select talents_list('')`, DENY);

  // ---------------------------------------------------------------- 8. notifications et messages
  await as(BUY);
  const conv = (await works('N1 un client contacte la vendeuse a propos de l\'annonce', `select start_conversation('${lst}', 'Bonjour, la lampe M est-elle livrable a Douala ?') r`))?.[0]?.r;
  await as(S);
  await works('N2 la vendeuse voit la conversation (1 non lu)', `select unread from my_conversations()`, (r) => r.length === 1 && Number(r[0].unread) === 1);
  await works('N3 la vendeuse repond', `insert into messages (conversation_id, sender_id, body) values ('${conv}', '${S}', 'Oui, sous 48 h') returning id`);
  await as(RIV);
  await works('N4 un autre vendeur ne voit aucune conversation', `select id from my_conversations()`, (r) => r.length === 0);
  await works('N5 ... ni aucun message', `select id from messages`, (r) => r.length === 0);
  await as(S);
  const nts = await works('N6 la vendeuse lit ses notifications (verification, commande...)', `select kind, title from notifications order by created_at`, (r) => ['order', 'shop', 'listing', 'verification', 'certification'].every((k) => r.some((n) => n.kind === k)));
  console.log('   notifications de la vendeuse :', JSON.stringify((nts ?? []).map((n) => n.kind + '/' + n.title)).slice(0, 400));
  await works('N7 la vendeuse marque tout comme lu', `select mark_notifications_read()`);
  await works('N8 plus de notification non lue', `select count(*) c from notifications where read_at is null`, (r) => Number(r[0].c) === 0);
  await as(RIV);
  await works('N9 les notifications de la vendeuse sont invisibles du rival', `select id from notifications where user_id = '${S}'`, (r) => r.length === 0);
  await as(S);
  await works('N10 preferences : notifications de commandes in-app desactivables', `select set_notification_preference('inapp', 'cat:orders', false)`);

  // ---------------------------------------------------------------- 9. acces refuses a l'etudiante (surfaces des autres acteurs)
  await as(S);
  await fails('X1 etudiante : pas de decouverte de talents (organisations)', `select discovery_search()`, DENY);
  await fails('X2 etudiante : pas de console d\'administration', `select admin_orders(10)`, DENY);
  await works('X3 etudiante : la file de validation des rattachements est vide pour elle', `select student_affiliation_queue() r`, (r) => r[0].r.length === 0);
  await noEffect('X5 etudiante : la boutique du rival ne change pas (RLS)', `update shops set name = 'Detournee' where owner_id = '${RIV}' returning id`);
  await noEffect('X6 etudiante : l\'annonce du rival ne change pas (RLS)', `update listings set price = 1 where seller_id = '${RIV}' returning id`);

  await b.replayMigrations();
  await as(S);
  await works('R1 apres rejeu : la vendeuse garde sa capacite et son stock', `select my_seller_capability() r`, (r) => r[0].r.can_sell === true);
  b.summary('h131_parcours_etudiant_vendeur');
}





