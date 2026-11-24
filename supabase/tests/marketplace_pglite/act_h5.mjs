// Scénario PGlite du lot H5 (20261120050000_h5_parcours_continu_vendeur.sql) : parcours visiteur -> client continu, capacité vendeur, espace personnel.
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000050${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const cap = async (n) => { await as(U(n)); const r = (await q(`select my_seller_capability() c`))[0].c; await db.exec('reset role'); return r; };

  await db.exec('reset role');
  const roles = { 1: 'client', 2: 'student', 3: 'student', 4: 'student', 5: 'student', 6: 'company', 7: 'other', 8: 'dept', 9: 'admin', 10: 'student', 11: 'student', 12: 'support', 13: 'finance', 14: 'direction' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h5${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte H5 ${n}','${r}','h5${n}@t.cm')`);
  }
  // 2 : étudiant sans aucune vérification ; 3 : pièce validée seulement ; 4 : pièce validée + téléphone vérifié ; 5 : certifié + téléphone vérifié ;
  // 10 : certifié sans téléphone vérifié ; 11 : pièce + téléphone vérifiés mais suspendu
  const verifyDoc = (n) => db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await verifyDoc(3); await verifyDoc(4); await verifyDoc(11);
  await db.exec(`update profiles set certification = 'approved' where id in ('${U(5)}', '${U(10)}')`);
  await db.exec(`update profiles set phone = '690500004', phone_verified = true where id = '${U(4)}'`);
  await db.exec(`update profiles set phone = '690500005', phone_verified = true where id = '${U(5)}'`);
  await db.exec(`update profiles set phone = '690500011', phone_verified = true, suspended = true where id = '${U(11)}'`);
  // les profils des autres rôles ont un téléphone vérifié : seul le rôle doit les exclure
  for (const n of [1, 6, 7, 8, 9, 12, 13, 14]) await db.exec(`update profiles set phone = '69050${String(n).padStart(4, '0')}', phone_verified = true where id = '${U(n)}'`);

  // ---- visiteur (anonyme) : aucune fonction de l'espace connecté
  await as(null, 'anon');
  for (const f of ['my_seller_capability()', 'my_client_space()', 'my_reviews()', "review_delete('product', gen_random_uuid())"]) {
    await fails(`visiteur : ${f.split('(')[0]} refusé`, `select ${f}`, /permission denied/);
  }
  await db.exec('reset role');

  // ---- capacité vendeur : conditions par acteur
  let c = await cap(2);
  check('capacité : étudiant non vérifié -> non, conditions manquantes listées', c.can_sell === false && c.missing.includes('student_verified') && c.missing.includes('phone_verified') && !c.missing.includes('student'));
  c = await cap(3);
  check('capacité : étudiant vérifié sans téléphone vérifié -> non', c.can_sell === false && JSON.stringify(c.missing) === '["phone_verified"]');
  c = await cap(4);
  check('capacité : étudiant vérifié (pièce) + téléphone vérifié -> oui', c.can_sell === true && c.missing.length === 0 && c.role === 'student');
  check('capacité : pièce validée sans certification -> peut vendre mais pas publier', c.can_publish === false);
  c = await cap(5);
  check('capacité : étudiant certifié + téléphone vérifié -> oui et peut publier', c.can_sell === true && c.can_publish === true);
  c = await cap(10);
  check('capacité : certifié sans téléphone vérifié -> non', c.can_sell === false && c.missing.includes('phone_verified'));
  c = await cap(11);
  check('capacité : compte suspendu -> non', c.can_sell === false && c.missing.includes('not_suspended') && c.can_publish === false);
  for (const [n, r] of [[1, 'client'], [6, 'company'], [7, 'other'], [8, 'dept'], [9, 'admin'], [12, 'support'], [13, 'finance'], [14, 'direction']]) {
    c = await cap(n);
    check(`capacité : ${r} -> non (le vendeur n'est pas un compte)`, c.can_sell === false && c.role === r && c.missing.includes('student'));
  }
  c = await cap(4);
  check('capacité : chaque condition est décrite (clé, libellé, état)', c.conditions.length === 4 && c.conditions.every((x) => x.key && x.label && typeof x.ok === 'boolean'));

  // ---- création de boutique : seuls les rôles qui peuvent vendre
  const shopOf = (nom) => `select shop_save('{"name":"${nom}","description":"Objets utiles","categories":["Maison"]}'::jsonb) s`;
  const shop = shopOf('Atelier H5');
  for (const [n, r] of [[1, 'client'], [6, 'company'], [7, 'other'], [8, 'dept'], [9, 'admin'], [12, 'support'], [13, 'finance'], [14, 'direction']]) {
    await as(U(n));
    await fails(`boutique : ${r} ne peut pas créer de boutique`, shop, /réservée aux étudiants/);
    await db.exec('reset role');
  }
  check('boutique : aucune boutique créée pour un client', (await q(`select count(*)::int n from shops where owner_id = '${U(1)}'`))[0].n === 0);
  await as(U(4));
  const created = (await q(shop))[0].s;
  check('boutique : un étudiant vérifié crée sa boutique (brouillon)', created.status === 'draft');
  await db.exec('reset role');
  await as(U(11));
  await fails('boutique : un compte suspendu ne crée rien', shop, /Compte inactif|réservée aux étudiants|suspendu/);
  await db.exec('reset role');

  // ---- espace personnel du client : compteurs et avis réels, propres à la personne
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values ('00000000-0000-0000-0000-0000000050e1', '${U(4)}', 'Lampe H5', 'Genie', 5000, 'approved')`);
  await db.exec(`insert into orders (id, number, buyer_id, subtotal, fee, method, paid) values ('00000000-0000-0000-0000-0000000050d1', '#BE-2026-5001', '${U(1)}', 5000, 0, 'mobile_money', true)`);
  await db.exec(`insert into reviews (id, order_id, listing_id, reviewer_id, rating, comment) values ('00000000-0000-0000-0000-0000000050f1', '00000000-0000-0000-0000-0000000050d1', '00000000-0000-0000-0000-0000000050e1', '${U(1)}', 4, 'Bien')`);
  await db.exec(`insert into favorites (user_id, listing_id) values ('${U(1)}', '00000000-0000-0000-0000-0000000050e1')`);
  await db.exec(`insert into addresses (user_id, recipient, phone, city, line) values ('${U(1)}', 'Awa', '690000000', 'Douala', 'Rue 1')`);
  await as(U(1));
  const sp = (await q(`select my_client_space() s`))[0].s;
  check('espace client : compteurs réels', sp.favorites === 1 && sp.addresses === 1 && sp.reviews === 1 && sp.disputes_open === 0 && sp.claims_open === 0, JSON.stringify(sp));
  const mine = (await q(`select my_reviews() r`))[0].r;
  check('mes avis : l\'avis de l\'article est listé avec la commande', mine.length === 1 && mine[0].kind === 'product' && mine[0].title === 'Lampe H5' && mine[0].order_number === '#BE-2026-5001');
  await db.exec('reset role');
  await as(U(2));
  check('espace client : un autre compte ne voit pas ces données', (await q(`select my_reviews() r`))[0].r.length === 0 && (await q(`select my_client_space() s`))[0].s.favorites === 0);
  await fails('mes avis : on ne retire pas l\'avis d\'un autre', `select review_delete('product', '00000000-0000-0000-0000-0000000050f1')`, /Avis introuvable/);
  await db.exec('reset role');
  await as(U(1));
  await fails('mes avis : type inconnu refusé', `select review_delete('autre', '00000000-0000-0000-0000-0000000050f1')`, /Type d'avis inconnu/);
  check('mes avis : l\'auteur retire son avis', (await q(`select review_delete('product', '00000000-0000-0000-0000-0000000050f1') r`))[0].r === 'deleted');
  check('mes avis : la liste est vide après retrait', (await q(`select my_reviews() r`))[0].r.length === 0);
  await db.exec('reset role');

  // ---- compte suspendu : plus aucune écriture de l'espace personnel
  await as(U(11));
  await fails('mes avis : un compte suspendu ne retire rien', `select review_delete('shop', gen_random_uuid())`, /Compte inactif/);
  await db.exec('reset role');

  // ---- gardes serveur : l'anonyme n'exécute aucune fonction de l'espace connecté
  const connected = ['marketplace_checkout', 'cancel_order', 'submit_review', 'submit_claim', 'my_disputes', 'my_favorites', 'save_address', 'request_seller_payout', 'my_student_status',
    'profile_set_phone', 'submit_shop_review', 'shop_save', 'shop_submit', 'my_claims', 'payment_start', 'dispute_open', 'toggle_follow_shop', 'my_followed_shops'];
  const exposed = await q(`select distinct p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any(array[${connected.map((x) => `'${x}'`).join(',')}]) and has_function_privilege('anon', p.oid, 'execute')`);
  check('serveur : aucune fonction connectée n\'est exécutable par l\'anonyme', exposed.length === 0, JSON.stringify(exposed));
  const present = await q(`select distinct p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = any(array[${connected.map((x) => `'${x}'`).join(',')}])`);
  check('serveur : les fonctions connectées contrôlées existent', present.length >= connected.length - 2, String(present.length));

  // Le périmètre public de l'anonyme est une liste fermée : toute nouvelle fonction publique doit être ajoutée ici en connaissance de cause.
  const allowed = new Set(`active_auto_promo ann_detail ann_wins_list anns_list author_posts author_shop_slug campaigns_overview chat_file_allowed circle_feed communities_list community_events_list
    community_feed community_images community_levels community_qa company_public current_role_name delivery_quote department_detail departments_list duels_list enforce_mfa_on_sensitive events_between
    events_upcoming flash_sales_active institutions_search is_community_member is_contest_staff is_mission_participant is_participant is_platform_staff iut_projects kiosk_heartbeat kiosk_pair_issue
    kiosk_pair_revoke kiosk_pair_status listing_rating listings_other_institutions live_get lives_agenda lives_now marketplace_search marketplace_shops mate_categories_list mentor_detail mentor_stories
    mentors_list momo_normalize normalize_msisdn notification_category offer_type_of opp_detail opp_hired_list opps_list platform_impact point_level post_comment_list post_comment_list_v2
    post_shop_target product_detail product_extras product_reviews profile_imported_items profile_in_directory profile_links_public profile_visible promo_preview provider_card public_profile
    public_project_get public_projects public_sellers recommended_offers record_view reels_feed seller_public shared_cv shop_public showcase_listings skills_list stories_active suggest_districts
    talent_passport top_helpers trending_products user_level verify_certificate victories_list wish_get wishes_market
    passport_token_verify project_proof_verify qr_resolve_public verify_certificate_public`.split(/\s+/));
  const anon = await q(`select distinct p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute') and p.prorettype <> 'trigger'::regtype
      and p.proname not like '\\_%' and p.proname not like 'pg%' and p.proname not like 'gen\\_%' and p.proname not in ('fips_mode', 'armor', 'dearmor', 'crypt', 'decrypt', 'decrypt_iv', 'digest', 'encrypt', 'encrypt_iv', 'hmac')`);
  // Une fonction publique ajoutée plus tard (hors liste) doit au moins être en lecture seule.
  const extra = anon.filter((r) => !allowed.has(r.proname) && /\b(insert\s+into|update\s+\w+\s+set|delete\s+from)\b/i.test(r.prosrc)).map((r) => r.proname);
  check('serveur : toute fonction publique de l\'anonyme hors liste attendue est en lecture seule', extra.length === 0, extra.join(', '));
  check('serveur : les fonctions publiques écrivant pour l\'anonyme sont les seules attendues (bornes, certificats, vues, vérification publique : compteur de débit et de vues de jeton)',
    anon.filter((r) => /\b(insert\s+into|update\s+\w+\s+set|delete\s+from)\b/i.test(r.prosrc)).map((r) => r.proname).every((n) => ['ann_detail', 'record_view', 'verify_certificate', 'kiosk_heartbeat', 'kiosk_pair_issue', 'kiosk_pair_revoke', 'passport_token_verify', 'project_proof_verify', 'qr_resolve_public', 'verify_certificate_public'].includes(n)));

  console.log(`act_h5: ${ok} OK, ${ko} KO`);
}
