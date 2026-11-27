// H13.1 lot ACTORS - parcours VISITEUR -> CLIENT sur la base PGlite rejouee (schema + toutes les migrations), en vrais appels avec jwt claims par acteur
// et garde db_pre_request simulee. Aucun paiement n'est confirme : il n'existe aucune fonction serveur de confirmation « de test » (payment_set_status est l'outil reel de la
// finance), la commande reste donc EN ATTENTE de paiement et c'est cet etat honnete qui est verifie.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_parcours_visiteur_client.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 1);
  const { U, as, anon, sup, q, qs, rows, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  await db.exec('grant all on storage.objects to authenticated');

  // ---------------------------------------------------------------- fixtures : un vendeur (etudiant verifie) avec boutique active et annonces
  const SELL = await user(1, 'Awa Vendeuse', 'student', `update profiles set phone='691310001', phone_verified=true, certification='approved' where id='${U(1)}'`);
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${SELL}', 'student_card', 'c.pdf', '${SELL}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  const SHOP = U(900);
  await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('${SHOP}', '${SELL}', 'Boutique Awa Parcours', 'boutique-awa-parcours', 'active')`);
  const mk = async (title, price, stock, status = 'approved', cat = 'Maison') => (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) values ('${SELL}', '${title}', 'Design', '${cat}', ${price}, ${stock}, '${status}', '{photo.jpg}', '${SHOP}') returning id`))[0].id;
  const LAMP = await mk('Lampe Parcours Client', 12000, 5);
  const SAC = await mk('Sac Parcours Client', 8000, 2);
  const PEND = await mk('Annonce en attente de moderation', 3000, 3, 'pending');
  await sup();

  // ---------------------------------------------------------------- 1. visiteur anonyme : decouverte et recherche publiques
  await anon();
  const s1 = await works('V1 anonyme : recherche publique de la marketplace', `select marketplace_search('Lampe') r`, (r) => JSON.stringify(r[0].r).includes('Lampe Parcours Client'));
  const sAll = JSON.stringify((await q(`select marketplace_search(null) r`))[0].r);
  check('V2 anonyme : une annonce en attente de moderation n\'est jamais proposee', !sAll.includes('Annonce en attente de moderation'));
  check('V3 anonyme : le catalogue public montre les annonces approuvees', sAll.includes('Sac Parcours Client'));
  await works('V4 anonyme : fiche boutique publique', `select shop_public('boutique-awa-parcours') r`, (r) => JSON.stringify(r[0].r).includes('Boutique Awa Parcours'));
  await works('V5 anonyme : classement national lisible (liste vide honnete)', `select top100_national() r`);
  await works('V6 anonyme : vitrine des projets publics', `select public_projects() r`);
  await works('V7 anonyme : filtre par prix maximum', `select marketplace_search(null, null, null, null, 9000) r`, (r) => { const t = JSON.stringify(r[0].r); return t.includes('Sac Parcours Client') && !t.includes('Lampe Parcours Client'); });
  await fails('V8 anonyme : panier verifie par le serveur refuse', `select cart_check('[]'::jsonb)`, /permission denied|Connexion requise/i);
  await fails('V9 anonyme : commande refusee', `select marketplace_checkout('[{"id":"${LAMP}","qty":1}]'::jsonb, false, 'Mobile Money')`, /permission denied|Connexion requise/i);
  await fails('V10 anonyme : suivi de commande refuse', `select order_tracking('#BE-2026-0001')`, /permission denied|Connexion requise/i);
  await fails('V11 anonyme : conversation refusee', `select start_conversation('${LAMP}', 'Bonjour')`, /permission denied|Connexion requise/i);
  await fails('V12 anonyme : notifications refusees', `select mark_notifications_read()`, /permission denied|Connexion requise/i);
  await works('V13 anonyme : aucun profil lisible (RLS)', `select id from profiles`, (r) => r.length === 0);
  await noEffect('V14 anonyme : ecriture directe dans les annonces sans effet', `update listings set price = 1 returning id`);
  await fails('V15 anonyme : inscription directe d\'un profil refusee', `insert into profiles (id, name, role) values ('${U(77)}', 'Intrus', 'client')`, /permission denied|row-level security|foreign key/i);

  // ---------------------------------------------------------------- 2. inscription : compte d'authentification (service Auth) puis profil cree par l'utilisateur
  await sup();
  for (const n of [10, 11, 12, 13]) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h131-1-${n}@t.cm')`);
  await as(U(10));
  await works('I1 inscription : le profil client est cree par le nouvel utilisateur', `insert into profiles (id, name, email, role) values ('${U(10)}', 'Cora Cliente', 'h131-1-10@t.cm', 'client') returning role`, (r) => r[0].role === 'client');
  await as(U(11));
  await fails('I2 inscription : un profil administrateur ne peut pas etre cree par soi-meme', `insert into profiles (id, name, email, role) values ('${U(11)}', 'Pirate', 'h131-1-11@t.cm', 'admin')`, /row-level security|violates/i);
  await fails('I3 inscription : un profil de departement ne peut pas etre cree par soi-meme', `insert into profiles (id, name, email, role) values ('${U(11)}', 'Pirate', 'h131-1-11@t.cm', 'dept')`, /row-level security|violates/i);
  await fails('I4 inscription : le profil d\'un AUTRE utilisateur ne peut pas etre cree', `insert into profiles (id, name, email, role) values ('${U(12)}', 'Usurpe', 'h131-1-12@t.cm', 'client')`, /row-level security|violates/i);
  await works('I5 inscription : second client (compte neuf)', `insert into profiles (id, name, email, role) values ('${U(11)}', 'Denis Client', 'h131-1-11@t.cm', 'client') returning id`);
  await as(U(12));
  await works('I6 inscription : troisieme compte (client sans rien)', `insert into profiles (id, name, email, role) values ('${U(12)}', 'Eve Cliente', 'h131-1-12@t.cm', 'client') returning id`);
  await as(U(10));
  await fails('I7 le client ne peut pas se promouvoir administrateur', `update profiles set role = 'admin' where id = '${U(10)}'`, /rôle|role|autoris|permission|interdit|modifi/i);
  await works('I8 le client lit son propre profil', `select name, role from profiles where id = '${U(10)}'`, (r) => r.length === 1 && r[0].role === 'client');
  await works('I9 le client ne lit que son profil (pas celui des autres)', `select id from profiles`, (r) => r.length === 1 && r[0].id === U(10));
  await works('I10 espace client lisible', `select my_client_space() r`);

  // ---------------------------------------------------------------- 3. panier -> commande (stock reel)
  await as(U(10));
  await works('P1 panier : cart_check valide les lignes', `select cart_check('[{"id":"${LAMP}","qty":2}]'::jsonb) r`);
  await fails('P2 commande d\'une annonce en attente de moderation refusee', `select marketplace_checkout('[{"id":"${PEND}","qty":1}]'::jsonb, false, 'Mobile Money')`, /introuvable|indisponible|approuv|Annonce|Stock|Article/i);
  await fails('P3 quantite superieure au stock refusee', `select marketplace_checkout('[{"id":"${SAC}","qty":9}]'::jsonb, false, 'Mobile Money')`, /Stock|Quantité/i);
  check('P3b stock inchange apres refus', (await qs(`select stock from listings where id = '${SAC}'`))[0].stock === 2);
  const o1 = (await works('P4 commande : 2 lampes + 1 sac (Mobile Money)', `select marketplace_checkout('[{"id":"${LAMP}","qty":2},{"id":"${SAC}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h131-client-0001') r`, (r) => r[0].r.subtotal === 32000))?.[0]?.r;
  const num = o1?.number;
  check('P5 le stock est decremente une seule fois (lampe 3, sac 1)', (await qs(`select (select stock from listings where id='${LAMP}') l, (select stock from listings where id='${SAC}') s`))[0].l === 3);
  await works('P6 double envoi (meme cle) : meme commande, pas de seconde reservation', `select marketplace_checkout('[{"id":"${LAMP}","qty":2},{"id":"${SAC}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h131-client-0001') r`, (r) => r[0].r.number === num);
  check('P7 stock inchange apres le double envoi', (await qs(`select stock from listings where id='${LAMP}'`))[0].stock === 3);
  check('P8 un seul enregistrement de commande', Number((await qs(`select count(*) c from orders where buyer_id='${U(10)}'`))[0].c) === 1);
  const o2 = (await works('P9 prix envoye par le client ignore', `select marketplace_checkout('[{"id":"${SAC}","qty":1,"price":1,"unit_price":1}]'::jsonb, false, 'Mobile Money') r`, (r) => r[0].r.subtotal === 8000))?.[0]?.r;

  // ---------------------------------------------------------------- 4. paiement : jamais confirme par le client, jamais simule
  const st = (await qs(`select paid, cancelled, status from orders where number = '${num}'`))[0];
  check('PAY1 la commande est en attente de paiement (paid = false)', st.paid === false && st.cancelled === false, JSON.stringify(st));
  await noEffect('PAY2 le client ne peut pas marquer sa commande payee (ecriture directe)', `update orders set paid = true where number = '${num}' returning id`);
  await fails('PAY3 le client ne peut pas valider un paiement (finance reservee)', `select payment_set_status('${U(500)}', 'confirmed')`, /Action non autorisée|réservé|Réservé|exige la permission|permission denied/i);
  await fails('PAY4 le client ne confirme pas une commande Mobile Money comme paiement a la livraison', `select confirm_cod_order('${num}')`, /livraison|Commande|non|refus|introuvable/i);
  check('PAY5 apres ces tentatives la commande est toujours impayee', (await qs(`select paid from orders where number = '${num}'`))[0].paid === false);
  await as(SELL);
  await works('PAY6 le vendeur ne voit pas une commande impayee', `select * from seller_orders()`, (r) => !r.some((x) => x.number === num));

  // ---------------------------------------------------------------- 5. historique et suivi
  await as(U(10));
  await works('H1 le client voit sa commande dans son historique', `select number, paid from orders order by created_at`, (r) => r.length === 2 && r.some((x) => x.number === num));
  await works('H2 suivi de commande : etapes lisibles', `select order_tracking('${num}') r`, (r) => r[0].r != null);
  await works('H3 lignes de la commande lisibles', `select title, qty from order_lines order by title`, (r) => r.length === 3);
  await as(U(11));
  await works('H4 un autre client ne voit aucune commande', `select number from orders`, (r) => r.length === 0);
  await works('H5 un autre client ne voit aucune ligne de commande', `select id from order_lines`, (r) => r.length === 0);
  await fails('H6 un autre client ne suit pas la commande d\'autrui', `select order_tracking('${num}')`, /introuvable|Commande|accès|autoris/i);
  await fails('H7 un autre client n\'annule pas la commande d\'autrui', `select cancel_order('${num}')`, /introuvable|Commande|autoris/i);
  await as(U(10));
  await works('H8 le client annule sa commande impayee (stock restitue)', `select cancel_order('${o2.number}') r`);
  check('H9 stock du sac restitue apres annulation', (await qs(`select stock from listings where id='${SAC}'`))[0].stock === 1);
  await fails('H10 annulation deja faite : refusee', `select cancel_order('${o2.number}')`, /déjà|annul|Commande/i);

  // ---------------------------------------------------------------- 6. messages
  await as(U(10));
  const conv = (await works('M1 le client ouvre une conversation avec le vendeur sur une annonce', `select start_conversation('${LAMP}', 'Bonjour, la lampe est-elle disponible ?') r`))?.[0]?.r;
  await works('M2 le client envoie un second message', `insert into messages (conversation_id, sender_id, body) values ('${conv}', '${U(10)}', 'Merci de repondre') returning id`);
  await fails('M3 le client ne peut pas ecrire au nom d\'un autre', `insert into messages (conversation_id, sender_id, body) values ('${conv}', '${SELL}', 'usurpation')`, /row-level security|violates|permission/i);
  await as(SELL);
  await works('M4 le vendeur voit la conversation et 2 non lus', `select unread from my_conversations()`, (r) => r.length === 1 && Number(r[0].unread) === 2);
  await works('M5 le vendeur repond', `insert into messages (conversation_id, sender_id, body) values ('${conv}', '${SELL}', 'Oui, 3 en stock') returning id`);
  await works('M6 le vendeur marque la conversation comme lue', `select mark_conversation_read('${conv}')`);
  await works('M7 plus aucun message non lu cote vendeur', `select unread from my_conversations()`, (r) => Number(r[0].unread) === 0);
  await as(U(11));
  await works('M8 un tiers ne voit aucune conversation', `select id from my_conversations()`, (r) => r.length === 0);
  await works('M9 un tiers ne lit aucun message', `select id from messages`, (r) => r.length === 0);
  await fails('M10 un tiers ne peut pas ecrire dans la conversation', `insert into messages (conversation_id, sender_id, body) values ('${conv}', '${U(11)}', 'intrus')`, /row-level security|violates|permission/i);
  try { await q(`select mark_conversation_read('${conv}')`); } catch { /* refus accepte */ }
  check('M11 un tiers ne devient pas participant en marquant la conversation comme lue', Number((await qs(`select count(*) c from conversation_participants where conversation_id = '${conv}' and user_id = '${U(11)}'`))[0].c) === 0);
  await as(U(10));
  await works('M12 le client voit la reponse du vendeur et 1 non lu', `select unread from my_conversations()`, (r) => Number(r[0].unread) === 1);

  // ---------------------------------------------------------------- 7. notifications
  await qs(`select notify_user('${U(10)}', 'order', 'Commande enregistree', 'Votre commande ${num} attend le paiement', '{}'::jsonb)`);
  await qs(`select notify_user('${U(11)}', 'order', 'Notification privee de Denis', 'SECRETNOTIF-DENIS', '{}'::jsonb)`);
  await as(U(10));
  const nts = (await works('N1 le client lit ses notifications (aucune de Denis)', `select id, title, body, read_at from notifications order by created_at`, (r) => r.length >= 1 && !JSON.stringify(r).includes('SECRETNOTIF-DENIS')))?.[0];
  await as(U(11));
  const denis = (await q(`select id from notifications`));
  await as(U(10));
  try { await q(`select mark_notification_read('${denis[0]?.id}')`); check('N2 marquer la notification d\'un autre : refuse ou sans effet', true); } catch (e) { check('N2 marquer la notification d\'un autre : refuse ou sans effet', DENY.test(e.message), e.message); }
  await as(U(11));
  check('N2b la notification de Denis est restee non lue', (await q(`select read_at from notifications where id='${denis[0]?.id}'`))[0].read_at === null);
  await as(U(10));
  await works('N3 le client marque tout comme lu', `select mark_notifications_read()`);
  await works('N4 plus aucune notification non lue', `select count(*) c from notifications where read_at is null`, (r) => Number(r[0].c) === 0);
  await noEffect('N5 le client ne peut pas supprimer la notification d\'un autre', `delete from notifications where user_id = '${U(11)}' returning id`);
  await works('N6 compteurs de non lus', `select unread_counts() r`);

  // ---------------------------------------------------------------- 8. preferences et profil
  await as(U(10));
  await works('PR1 preference : desactiver les notifications de commandes (in-app)', `select set_notification_preference('inapp', 'cat:orders', false)`);
  await works('PR2 preference enregistree', `select enabled from notification_preferences where channel = 'inapp' and kind = 'cat:orders'`, (r) => r.length === 1 && r[0].enabled === false);
  await fails('PR3 SMS refuse tant que le numero n\'est pas verifie', `select set_notification_preference('sms', '*', true)`, /Vérifiez d'abord votre numéro/);
  await works('PR4 confidentialite du profil', `select profile_privacy_set('private', false) r`);
  await works('PR5 le client modifie sa ville et sa bio', `update profiles set city = 'Yaoundé', bio = 'Bio du parcours' where id = '${U(10)}' returning city`, (r) => r[0].city === 'Yaoundé');
  await works('PR6 le client enregistre son telephone une fois', `select profile_set_phone('691310099')`);
  await fails('PR7 le telephone ne se remplace pas', `select profile_set_phone('691310098')`, /numéro|déjà|remplac|modif|Vérif/i);
  await fails('PR8 le client ne s\'attribue pas la certification', `update profiles set certification = 'approved' where id = '${U(10)}'`, /certif|permission|autoris|modifi/i);
  await fails('PR9 le client ne se retire pas une suspension / ne change pas son statut', `update profiles set suspended = true where id = '${U(10)}'`, /suspen|permission|autoris|modifi|protég/i);
  await noEffect('PR10 le client ne modifie pas le profil d\'un autre', `update profiles set name = 'Piratage' where id = '${U(11)}' returning id`);
  await works('PR11 favoris : ajout d\'une annonce', `insert into favorites (user_id, listing_id) values ('${U(10)}', '${LAMP}') returning listing_id`);
  await fails('PR12 favoris : au nom d\'un autre refuse', `insert into favorites (user_id, listing_id) values ('${U(11)}', '${LAMP}')`, /row-level security|violates/i);
  await as(U(11));
  await works('PR13 les favoris d\'un autre client sont invisibles', `select * from favorites`, (r) => r.length === 0);
  await as(U(10));
  await fails('PR14 un client n\'accede pas aux fonctions d\'organisation (decouverte de talents)', `select discovery_search()`, DENY);
  await fails('PR15 un client n\'accede pas a la console d\'administration', `select admin_orders(10)`, DENY);

  // ---------------------------------------------------------------- 9. garde de requete (db_pre_request) : compte suspendu, double authentification
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${U(12)}'`);
  await as(U(12));
  await fails('G1 compte suspendu : commande refusee par la garde', `select marketplace_checkout('[{"id":"${LAMP}","qty":1}]'::jsonb, false, 'Mobile Money')`, /Compte suspendu/);
  await fails('G2 compte suspendu : ecriture directe (favori) refusee par la garde', `insert into favorites (user_id, listing_id) values ('${U(12)}', '${LAMP}')`, /Compte suspendu/);
  try { const r = await q(`select id from profiles`); check('G3 compte suspendu : la lecture ne renvoie que son propre profil', r.length === 1 && r[0].id === U(12)); } catch (e) { check('G3 compte suspendu : lecture refusee par la garde de session (lot SESSIONS)', /Compte suspendu/.test(e.message), e.message); }
  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${U(11)}', 'verified')`);
  await as(U(11), 'authenticated', 'aal1');
  await fails('G4 double authentification activee : commande refusee en session aal1', `select marketplace_checkout('[{"id":"${LAMP}","qty":1}]'::jsonb, false, 'Mobile Money')`, /double authentification/);
  await works('G5 double authentification : lecture du catalogue toujours possible en aal1', `select marketplace_search('Lampe') r`);
  await as(U(11), 'authenticated', 'aal2');
  await works('G6 session aal2 : la commande passe', `select marketplace_checkout('[{"id":"${LAMP}","qty":1}]'::jsonb, false, 'Mobile Money') r`, (r) => r[0].r.subtotal === 12000);

  await b.replayMigrations();
  await as(U(10));
  await works('R1 apres rejeu : l\'historique du client est intact', `select number from orders`, (r) => r.length === 2);

  b.summary('h131_parcours_visiteur_client');
}





