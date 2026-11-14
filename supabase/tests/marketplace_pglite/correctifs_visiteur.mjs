// Scénario PGlite des correctifs du profil Visiteur (migration 20261114004100).
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./correctifs_visiteur.mjs
let ok = 0, ko = 0;
export async function run(db) {
  // « reset role » seul revient aussi à l'éditeur SQL (aucun utilisateur connecté), comme les autres scénarios.
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  const roles = { 11: 'student', 12: 'student', 13: 'client', 14: 'finance', 15: 'dept', 16: 'admin', 17: 'company' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Profil Complet ${n}','${r}','u${n}@t.cm')`);
  }

  // 1. projets : un projet privé n'est pas servi aux visiteurs
  await db.exec(`insert into projects (id, owner_id, kind, title, summary, status, visibility) values
    ('00000000-0000-0000-0000-0000000000a1', '${U(11)}', 'projet', 'Projet public', 'x', 'approved', 'public'),
    ('00000000-0000-0000-0000-0000000000a2', '${U(11)}', 'projet', 'Projet prive', 'x', 'approved', 'private')`);
  await as(null, 'anon');
  const pr = (await q(`select iut_projects(null, 40, 'best') r`))[0].r;
  check('iut_projects : le projet public est servi', pr.some((p) => p.title === 'Projet public'));
  check('iut_projects : le projet privé est masqué', !pr.some((p) => p.title === 'Projet prive'));

  // 2. soumission d'un projet : le département et l'administration sont prévenus
  await as(U(12));
  const pid = (await q(`select project_save_full(null, 'projet', 'Ma serre connectee', 'Une description suffisamment longue pour publier ce projet.', 'Genie', '{"domain":"agri","problem":"Arrosage manuel","solution":"Capteurs et pompe","progress":"prototype","contact_email":"a@b.cm"}'::jsonb, '[]'::jsonb, 'public', true) id`))[0].id;
  await db.exec('reset role');
  const n1 = await q(`select user_id from notifications where title = 'Projet à examiner' and body = 'Ma serre connectee'`);
  check('projet soumis : dept et admin notifiés', n1.length === 2 && n1.some((r) => r.user_id === U(15)) && n1.some((r) => r.user_id === U(16)), JSON.stringify(n1));

  // 3. publications : review_note, mentions j'aime et boosts ne sont plus lisibles en direct
  await db.exec(`insert into posts (id, author_id, media_path, media_kind, status, review_note) values ('00000000-0000-0000-0000-0000000000b1', '${U(11)}', '${U(11)}/a.jpg', 'image', 'published', 'note interne')`);
  await as(null, 'anon');
  await fails('posts : review_note illisible pour anon', `select review_note from posts`, /permission denied/);
  check('posts : colonnes publiques lisibles pour anon', (await q(`select id, status, media_path from posts`)).length === 1);
  await fails('post_likes : illisible pour anon', `select * from post_likes`, /permission denied/);
  await as(U(13));
  await fails('posts : review_note illisible pour un connecté', `select review_note from posts`, /permission denied/);

  // 4. compteurs de vues : seul un compte connecté compte, une fois par jour
  await db.exec('reset role');
  await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('00000000-0000-0000-0000-0000000000c1', '${U(11)}', 'Boutique test', 'boutique-test', 'active')`);
  await as(null, 'anon');
  await q(`select record_view('shop', '00000000-0000-0000-0000-0000000000c1')`);
  await as(U(13));
  await q(`select record_view('shop', '00000000-0000-0000-0000-0000000000c1')`);
  await q(`select record_view('shop', '00000000-0000-0000-0000-0000000000c1')`);
  await db.exec('reset role');
  const v = await q(`select coalesce(sum(views), 0)::int v from shop_views where shop_id = '00000000-0000-0000-0000-0000000000c1'`);
  check('record_view : visiteur ignoré, connecté compté une seule fois par jour', v[0].v === 1, JSON.stringify(v));

  // 5. appareils
  await db.exec(`insert into device_tokens (token, user_id, platform) values ('${'t'.repeat(30)}', '${U(13)}', 'web')`);
  await as(U(13));
  check('unregister_all_devices : retire les jetons du compte', (await q(`select unregister_all_devices() n`))[0].n === 1);
  await as(null, 'anon');
  await fails('unregister_all_devices : refusé aux visiteurs', `select unregister_all_devices()`, /permission denied|Connexion requise/);

  // 6. parrainage : le code est enregistré et accepté par claim_referral
  await as(U(11));
  const code = (await q(`select my_referral_code() c`))[0].c;
  check('parrainage : code de 8 caractères', /^[A-Z2-9]{8}$/.test(code), code);
  check('parrainage : le code est stable', (await q(`select my_referral_code() c`))[0].c === code);
  await db.exec('reset role');
  check('parrainage : le code est enregistré', (await q(`select 1 from referral_codes where code = '${code}'`)).length === 1);
  await as(U(13));
  let claimed = null;
  try { claimed = (await q(`select claim_referral('${code}') r`))[0].r; } catch (e) { claimed = 'ERR ' + e.message; }
  check('parrainage : un filleul peut saisir le code', !/inconnu/.test(String(claimed)), String(claimed));

  // 7. paiement manuel d'une commande : déclaration, vérification, commande payée
  await db.exec('reset role');
  await db.exec(`insert into orders (id, number, buyer_id, subtotal, fee, method) values ('00000000-0000-0000-0000-0000000000d1', '#BE-2026-9001', '${U(13)}', 10000, 500, 'mobile_money')`);
  await as(U(13));
  const tx = (await q(`select payment_start('order', 'Commande #BE-2026-9001', 10500, 'manual') id`))[0].id;
  await q(`select payment_declare('${tx}', 'MP260101.1234')`);
  await db.exec('reset role');
  const nf = await q(`select user_id from notifications where title = 'Paiement à vérifier'`);
  check('paiement : finance et admin prévenus de la déclaration', nf.length === 2, JSON.stringify(nf));
  await as(U(13));
  await fails('paiement : le payeur ne confirme pas lui-même', `select payment_set_status('${tx}', 'confirmed')`, /Action non autorisée/);
  await fails('paiement : liste à vérifier réservée à la finance', `select payments_to_verify()`, /Action non autorisée/);
  await as(U(14));
  check('paiement : la finance voit le paiement à vérifier', (await q(`select payments_to_verify() r`))[0].r.length === 1);
  await q(`select payment_set_status('${tx}', 'confirmed')`);
  await db.exec('reset role');
  check('paiement : la confirmation marque la commande payée', (await q(`select paid, status from orders where number = '#BE-2026-9001'`))[0].paid === true);
  await as(U(13));
  const tx2 = (await q(`select payment_start('order', 'Commande #BE-2026-9001', 100, 'manual') id`))[0].id;
  await q(`select payment_declare('${tx2}', 'MP260101.9999')`);
  await as(U(14));
  await fails('paiement : un montant insuffisant ne confirme pas la commande', `select payment_set_status('${tx2}', 'confirmed')`, /Montant inférieur|déjà/);

  // 8. forfaits entreprise : nouvelle signature (plan, entreprise visée)
  await as(U(17));
  await fails('forfait : entreprise non vérifiée', `select company_subscription_request('pro', null)`, /vérifier|introuvable/);

  // 9. avis publics par titre
  await db.exec('reset role');
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values ('00000000-0000-0000-0000-0000000000e1', '${U(11)}', 'Lampe test', 'Genie', 5000, 'approved')`);
  await db.exec(`insert into reviews (order_id, listing_id, reviewer_id, rating, comment) values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', '${U(13)}', 5, 'Très bien')`);
  await as(null, 'anon');
  const rv = (await q(`select product_reviews('Lampe test') r`))[0].r;
  check('product_reviews : lisible par un visiteur, par titre', rv.length === 1 && rv[0].rating === 5);
  check('product_reviews : un autre titre ne renvoie rien', (await q(`select product_reviews('Autre') r`))[0].r.length === 0);

  // 10. offres : le rôle client n'en dépose plus
  await as(U(13));
  await fails('opp_save : refusé au rôle client', `select opp_save('Org', 'stage', '', 'Titre', '', 'online', '', 'unpaid', null, '', null, '{}', 'Une description assez longue', '{}', '', '', '', '{}', '', true, '', false)`, /Réservé|company|forfait|Accès/i);

  // 11. duels : nom d'affichage abrégé
  await db.exec('reset role');
  const dl = (await q(`select duels_list() r`))[0].r;
  check('duels_list : fonctionne', Array.isArray(dl));

  // 12. annonces : la note de modération n'est lue que par l'auteur et l'équipe ; les vues sont comptées une fois par compte
  await db.exec(`insert into contest_announcements (id, poster_id, title, organizer, kind, status, review_note, official_url) values ('00000000-0000-0000-0000-0000000000f1', '${U(17)}', 'Concours test', 'Organisateur', 'contest', 'published', 'note interne de modération', 'https://exemple.cm')`);
  await as(null, 'anon');
  const a1 = (await q(`select ann_detail('00000000-0000-0000-0000-0000000000f1') r`))[0].r;
  check('ann_detail : la note de modération est masquée pour un visiteur', a1.review_note === null || a1.review_note === undefined);
  await as(U(13));
  await q(`select ann_detail('00000000-0000-0000-0000-0000000000f1')`);
  await q(`select ann_detail('00000000-0000-0000-0000-0000000000f1')`);
  await as(U(17));
  const a2 = (await q(`select ann_detail('00000000-0000-0000-0000-0000000000f1') r`))[0].r;
  check('ann_detail : l\'auteur lit la note', a2.review_note === 'note interne de modération');
  await db.exec('reset role');
  check('ann_detail : une vue par compte et par jour', (await q(`select views from contest_announcements where id = '00000000-0000-0000-0000-0000000000f1'`))[0].views === 1);

  console.log(`\n${ok}/${ok + ko}`);
}
