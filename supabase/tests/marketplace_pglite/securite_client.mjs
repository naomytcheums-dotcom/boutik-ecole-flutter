// Scénario PGlite des migrations 20261115000100 (sécurité) et 20261115000200 (commandes et paiements) du profil Client.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./securite_client.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  const roles = { 21: 'client', 22: 'client', 23: 'student', 24: 'admin', 25: 'company', 26: 'finance', 27: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','s${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','s${n}@t.cm')`);
  }

  // --- messagerie
  await db.exec(`insert into user_blocks (blocker_id, blocked_id) values ('${U(23)}', '${U(21)}')`);
  await as(U(21));
  await fails('messagerie : un compte bloqué ne contourne plus le blocage', `select start_direct_conversation('${U(23)}', 'bonjour')`, /ne peut pas recevoir vos messages/);
  check('messagerie : conversation normale', (await q(`select start_direct_conversation('${U(22)}', 'salut') c`)).length === 1);
  check('is_blocked_between : ne révèle pas les blocages d\'autrui', (await q(`select is_blocked_between('${U(23)}', '${U(25)}') b`))[0].b === false);
  await as(U(23));
  check('is_blocked_between : visible pour les deux personnes concernées', (await q(`select is_blocked_between('${U(23)}', '${U(21)}') b`))[0].b === true);
  await as(U(22));
  let cid = (await q(`select start_direct_conversation('${U(25)}', 'x') c`))[0].c;
  let blocked = false;
  for (let i = 0; i < 25; i++) { try { await q(`select start_direct_conversation('${U(25)}', 'message ${i}')`); } catch (e) { if (/Trop de messages/.test(e.message)) { blocked = true; break; } } }
  check('messagerie : plafond de messages par minute', blocked);

  // --- profils publics
  await db.exec('reset role');
  // K2 : le vendeur 23 est éligible (pièce d'étudiant validée, téléphone vérifié)
  await db.exec(`update profiles set phone_verified = true where id = '${U(23)}'; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(23)}', 'student_card', 'c.pdf', '${U(23)}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values ('00000000-0000-0000-0000-0000000000e1', '${U(23)}', 'Lampe test', 'Genie', 5000, 'approved')`);
  await as(null, 'anon');
  check('public_profile : le profil d\'un étudiant reste public', (await q(`select public_profile('${U(23)}') p`))[0].p?.id === U(23));
  check('public_profile : un client n\'est pas listé', (await q(`select public_profile('${U(21)}') p`))[0].p === null);
  check('public_profile : un compte administrateur n\'est pas listé', (await q(`select public_profile('${U(24)}') p`))[0].p === null);
  check('seller_public : un nom sans annonce n\'est plus un annuaire', (await q(`select seller_public('Personne 21') r`))[0].r.found === false);
  check('seller_public : un identifiant sans annonce est introuvable', (await q(`select seller_public(null, '${U(21)}') r`))[0].r.found === false);
  check('seller_public : un vrai vendeur reste trouvé', (await q(`select seller_public('Personne 23') r`))[0].r.id === U(23));

  // --- profiles
  await as(U(21));
  await fails('profiles : le rôle ne se modifie pas', `update profiles set role = 'admin' where id = '${U(21)}'`, /permission denied|réservée à l'administrateur/);
  await fails('profiles : l\'e-mail ne se modifie pas directement', `update profiles set email = 'x@y.cm' where id = '${U(21)}'`, /permission denied/);
  check('profiles : le nom se modifie', (await q(`update profiles set name = 'Nouveau nom', bio = 'ma bio' where id = '${U(21)}' returning id`)).length === 1);
  await fails('profiles : longueur bornée', `update profiles set bio = repeat('x', 3000) where id = '${U(21)}'`, /profiles_longueurs_check/);
  await q(`select profile_set_phone('690000001')`);
  check('profile_set_phone : numéro enregistré', (await q(`select phone from profiles where id = '${U(21)}'`))[0].phone === '690000001');
  await fails('profile_set_phone : un second numéro est refusé', `select profile_set_phone('690000002')`, /contactez le support/);
  await db.exec('reset role');
  await db.exec(`select phone_verify_apply('${U(21)}', '690000001')`);
  await as(U(22));
  await fails('profile_set_phone : numéro déjà utilisé', `select profile_set_phone('+237690000001')`, /déjà utilisé/);
  await fails('profile_set_phone : numéro invalide', `select profile_set_phone('12345')`, /invalide/);

  // --- projets, étapes, compétences
  await db.exec('reset role');
  await db.exec(`insert into projects (id, owner_id, kind, title, summary, status, visibility, details) values
    ('00000000-0000-0000-0000-0000000000a1', '${U(23)}', 'projet', 'Projet validé', 'x', 'approved', 'public', '{"contact_email":"a@b.cm"}')`);
  await as(U(21));
  check('projects : un client ne lit plus la table des autres', (await q(`select id from projects`)).length === 0);
  await as(U(23));
  check('projects : le porteur lit son projet', (await q(`select id from projects`)).length === 1);
  await as(U(21));
  check('public_projects : le catalogue reste lisible sans contacts', (await q(`select public_projects() r`))[0].r[0].details.contact_email === undefined);

  // --- mentors et communautés éphémères
  await as(U(21));
  await fails('mentor_save : refusé à un client', `select mentor_save('IUT', '2025', array['Dev'], 'bio')`, /Réservé aux étudiants/);
  await as(U(23));
  check('mentor_save : autorisé à un étudiant', (await q(`select mentor_save('IUT', '2025', array['Dev'], 'bio') r`)).length === 1);
  const eph = (await q(`select create_ephemeral_community('Révision examen', 'x', 3, 'public') id`))[0].id;
  check('communauté éphémère : en attente de validation', (await q(`select status from communities where id = '${eph}'`))[0].status === 'pending');

  // --- publish_due_posts
  await as(U(21));
  await fails('publish_due_posts : plus exécutable par un utilisateur', `select publish_due_posts()`, /permission denied/);

  // --- file de notifications
  await db.exec('reset role');
  const key = (await q(`select value from internal_secrets where name = 'dispatch_key'`))[0].value;
  check('clé interne générée', key.length >= 32);
  await db.exec('reset role');
  check('dispatch_key_check : bonne clé', (await q(`select dispatch_key_check('${key}') r`))[0].r === true);
  check('dispatch_key_check : mauvaise clé', (await q(`select dispatch_key_check('abc') r`))[0].r === false);
  await as(U(21));
  await fails('internal_secrets : illisible par un utilisateur', `select * from internal_secrets`, /permission denied/);
  await fails('dispatch_claim : non appelable par un utilisateur', `select * from dispatch_claim(10, array['sms'])`, /permission denied/);
  await db.exec('reset role');
  await db.exec(`insert into notification_outbox (user_id, channel, kind, title) values ('${U(21)}', 'sms', 'order', 't1'), ('${U(21)}', 'sms', 'order', 't2')`);
  const c1 = await q(`select * from dispatch_claim(1, array['sms'])`);
  const c2 = await q(`select * from dispatch_claim(5, array['sms'])`);
  check('dispatch_claim : prise en charge atomique sans doublon', c1.length === 1 && c2.length === 1 && c1[0].id !== c2[0].id && c1[0].status === 'sending');

  // --- limitation des connexions par téléphone et révocation des sessions
  await as(U(21));
  await fails('auth_throttle : non appelable par un utilisateur', `select auth_throttle_check('login:600000000')`, /permission denied/);
  await fails('auth_revoke_sessions : non appelable par un utilisateur', `select auth_revoke_sessions('${U(21)}')`, /permission denied/);
  await as(null, 'service_role');
  for (let i = 0; i < 3; i++) await q(`select auth_throttle_hit('login:600000000')`);
  check('auth_throttle : sous le plafond', (await q(`select auth_throttle_check('login:600000000', 15, 4) r`))[0].r === true);
  await q(`select auth_throttle_hit('login:600000000')`);
  check('auth_throttle : plafond atteint', (await q(`select auth_throttle_check('login:600000000', 15, 4) r`))[0].r === false);
  await q(`select auth_throttle_clear('login:600000000')`);
  check('auth_throttle : remise à zéro après une connexion réussie', (await q(`select auth_throttle_check('login:600000000', 15, 4) r`))[0].r === true);
  await db.exec('reset role');
  await db.exec(`insert into auth.sessions (user_id) values ('${U(21)}'), ('${U(22)}')`);
  await as(null, 'service_role');
  await q(`select auth_revoke_sessions('${U(21)}')`);
  await db.exec('reset role');
  check('auth_revoke_sessions : seules les sessions du compte visé sont fermées', (await q(`select user_id from auth.sessions`)).every((r) => r.user_id === U(22)));

  // --- commandes
  await db.exec('reset role');
  await db.exec(`update listings set stock = 10 where id = '00000000-0000-0000-0000-0000000000e1'`);
  await as(U(22));
  const items = `'[{"id":"00000000-0000-0000-0000-0000000000e1","qty":2}]'::jsonb`;
  const r1 = (await q(`select marketplace_checkout(${items}, false, 'Mobile Money', null, null, 'cle-idem-0001') r`))[0].r;
  check('checkout : commande créée', r1.replayed === false && r1.subtotal === 10000);
  const r2 = (await q(`select marketplace_checkout(${items}, false, 'Mobile Money', null, null, 'cle-idem-0001') r`))[0].r;
  check('checkout : rejeu idempotent d\'une commande active', r2.replayed === true && r2.number === r1.number);
  await q(`select cancel_order('${r1.number}')`);
  const r3 = (await q(`select marketplace_checkout(${items}, false, 'Mobile Money', null, null, 'cle-idem-0001') r`))[0].r;
  check('checkout : un nouvel essai après annulation crée une nouvelle commande', r3.replayed === false && r3.number !== r1.number);
  await db.exec('reset role');
  check('stock restitué à l\'annulation puis reservé à nouveau', (await q(`select stock from listings where id = '00000000-0000-0000-0000-0000000000e1'`))[0].stock === 8);
  await db.exec(`update orders set reference = 'PAY-EXT-1' where number = '${r3.number}'`);
  await as(U(22));
  await fails('cancel_order : refusé tant qu\'un paiement est en cours', `select cancel_order('${r3.number}')`, /paiement est en cours/);
  await db.exec('reset role');
  await db.exec(`update orders set reference = null where number = '${r3.number}'`);
  // promo automatique non applicable : ignorée
  await db.exec(`insert into promo_codes (code, kind, value, min_amount, auto_apply, active, starts_at) values ('AUTO10', 'percent', 10, 999999, true, true, now() - interval '1 day')`);
  await as(U(22));
  const r4 = (await q(`select marketplace_checkout(${items}, false, 'Mobile Money', null, 'AUTO10', null) r`))[0].r;
  check('checkout : une promotion automatique inapplicable n\'empêche plus la commande', r4.discount === 0 && r4.subtotal === 10000);
  // anciennes fonctions
  const r5 = (await q(`select create_order(${items}, false, 'Mobile Money') r`))[0].r;
  check('create_order (ancienne) passe par le même contrôle', typeof r5.number === 'string');
  await db.exec('reset role');
  await db.exec(`update listings set seller_id = '${U(22)}' where id = '00000000-0000-0000-0000-0000000000e1'`);
  await as(U(22));
  await fails('create_order (ancienne) : plus d\'achat de son propre produit', `select create_order(${items}, false, 'Mobile Money')`, /propre produit/);
  await db.exec('reset role');
  await db.exec(`update listings set seller_id = '${U(23)}' where id = '00000000-0000-0000-0000-0000000000e1'`);
  // expiration
  await db.exec(`update orders set created_at = now() - interval '3 hours' where number in ('${r3.number}')`);
  check('expiration : les commandes impayées anciennes sont annulées', (await q(`select expire_unpaid_orders() n`))[0].n >= 1);
  check('expiration : la commande est bien annulée', (await q(`select cancelled_at is not null c from orders where number = '${r3.number}'`))[0].c === true);
  // payment_start
  await db.exec(`update orders set cancelled_at = null where number = '${r4.number}'`);
  await as(U(22));
  await fails('payment_start : montant différent du total refusé', `select payment_start('order', 'Commande ${r4.number}', 5, 'manual')`, /total de la commande/);
  const t1 = (await q(`select payment_start('order', 'Commande ${r4.number}', ${r4.subtotal + r4.fee}, 'manual') id`))[0].id;
  const t2 = (await q(`select payment_start('order', 'Commande ${r4.number}', ${r4.subtotal + r4.fee}, 'manual') id`))[0].id;
  check('payment_start : demande non dupliquée', t1 === t2);

  console.log(`\n${ok}/${ok + ko}`);
}
