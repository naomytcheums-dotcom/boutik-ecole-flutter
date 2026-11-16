// Scénario PGlite de 20261117000100_securite_etudiant.sql (sécurité transversale du profil Étudiant-vendeur).
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_securite.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const hook = async (method, path, uid, aal) => {
    const claims = uid ? JSON.stringify({ sub: uid, ...(aal ? { aal } : {}) }) : '';
    await db.exec('reset role');
    await db.exec(`select set_config('request.path', '${path}', false), set_config('request.method', '${method}', false), set_config('request.jwt.claims', '${claims}', false)`);
    try { await db.exec('select enforce_mfa_on_sensitive()'); return 'ok'; } catch (e) { return e.message; }
  };

  await db.exec('reset role');
  const roles = { 41: 'student', 42: 'client', 43: 'admin', 44: 'company', 45: 'dept', 46: 'finance', 47: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','e${n}@t.cm'); insert into profiles(id,name,role,email,department,skills) values ('${U(n)}','Prénom${n} Nom${n}','${r}','e${n}@t.cm','Génie', 'soudure')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${U(47)}'`);

  // --- annonces : re-modération, colonnes figées, médias
  const L = '00000000-0000-0000-0000-0000000000f1';
  await db.exec(`insert into listings (id, seller_id, title, department, price, status, showcase) values ('${L}', '${U(41)}', 'Lampe', 'Génie', 5000, 'approved', false)`);
  await as(U(41));
  await q(`update listings set price = 4500, stock = 7 where id = '${L}'`);
  check('annonce approuvée : le prix et le stock restent libres', (await q(`select status, price from listings where id = '${L}'`))[0].status === 'approved');
  await q(`update listings set title = 'Lampe en bois', created_at = '2020-01-01', showcase = true where id = '${L}'`);
  const row = (await q(`select status, showcase, created_at from listings where id = '${L}'`))[0];
  check('annonce approuvée : un changement de titre repasse en modération', row.status === 'pending');
  check('annonce : showcase et created_at ne se modifient pas', row.showcase === false && new Date(row.created_at).getFullYear() > 2020);
  await db.exec('reset role');
  check('annonce modifiée : le département et l\'administrateur sont prévenus', (await q(`select user_id from notifications where kind = 'listing_review' order by user_id`)).map((r) => r.user_id).join() === [U(43), U(45)].join());
  await as(U(41));
  await fails('annonce : une photo externe est refusée', `update listings set image_url = 'http://evil.example/x.png' where id = '${L}'`, /téléversement/);
  await fails('annonce : une photo en tableau externe est refusée', `update listings set images = array['https://evil.example/a.png'] where id = '${L}'`, /téléversement/);
  await q(`update listings set image_url = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/a.png' where id = '${L}'`);
  check('annonce : une photo du stockage de l\'application est acceptée', true);
  await q(`insert into listings (seller_id, title, department, price, status, showcase) values ('${U(41)}', 'Neuve', 'Génie', 1000, 'draft', true)`);
  const n = (await q(`select status, showcase from listings where title = 'Neuve'`))[0];
  check('annonce créée : showcase imposé par le serveur', n.status === 'draft' && n.showcase === false);

  // --- lectures publiques
  await db.exec('reset role');
  await as(null, 'anon');
  await fails('wishes : plus de lecture directe pour un anonyme', `select * from wishes`, /permission denied/);
  await fails('lives : plus de lecture anonyme', `select * from lives`, /permission denied/);
  await fails('live_messages : plus de lecture anonyme', `select * from live_messages`, /permission denied/);
  await as(U(42));
  await fails('wishes : plus de lecture directe pour un compte connecté', `select review_note from wishes`, /permission denied/);
  check('wishes_market : la lecture par fonction reste possible', Array.isArray((await q(`select wishes_market('all', 10) r`))[0].r));
  check('lives : un compte connecté lit encore les lives', Array.isArray(await q(`select id from lives`)));

  // --- noms
  await as(null, 'anon');
  check('public_profile : un anonyme ne voit que « Prénom N. »', (await q(`select public_profile('${U(41)}') p`))[0].p?.name === 'Prénom41 N.');
  await as(U(42));
  check('public_profile : un compte connecté voit le nom', (await q(`select public_profile('${U(41)}') p`))[0].p?.name === 'Prénom41 Nom41');
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'approved' where id = '${U(41)}'`);
  await as(U(42));
  const tl = (await q(`select talents_list('', 10) r`))[0].r;
  check('talents_list : un client ne voit que « Prénom N. »', tl.length >= 1 && tl.every((t) => /\.$/.test(t.name)));
  await as(U(44));
  check('talents_list : une entreprise voit le nom complet (étudiant vérifié)', (await q(`select talents_list('', 10) r`))[0].r.some((t) => t.name === 'Prénom41 Nom41'));
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'none' where id = '${U(41)}'`);
  await as(U(44));
  check('talents_list : un étudiant non vérifié n\'est pas listé', !(await q(`select talents_list('', 10) r`))[0].r.some((t) => t.id === U(41)));
  await as(U(41));
  await q(`select start_direct_conversation('${U(42)}', 'bonjour')`);
  check('my_conversations : le nom complet de l\'interlocuteur n\'est plus exposé', (await q(`select other_name from my_conversations()`))[0].other_name === 'Prénom42 N.');

  // --- journal d'audit
  await q(`select log_audit('connexion', 'x', 'auth', 'Critique')`);
  await as(U(43));
  await q(`select log_audit('décision', 'x', 'admin', 'Critique')`);
  await db.exec('reset role');
  const au = await q(`select actor_id, level from audit_log order by id`);
  check('log_audit : un étudiant ne peut pas écrire un niveau critique', au[0].level === 'Normal' && au[0].actor_id === U(41));
  check('log_audit : l\'administrateur garde les niveaux sensibles', au[1].level === 'Critique');

  // --- comptes suspendus
  check('suspendu : une RPC d\'écriture est refusée', /Compte suspendu/.test(await hook('POST', '/rpc/shop_save', U(47))));
  check('suspendu : une écriture directe est refusée', /Compte suspendu/.test(await hook('PATCH', '/listings', U(47))));
  check('suspendu : un nom en suffixe est reconnu', /Compte suspendu/.test(await hook('POST', '/rpc/flash_save', U(47))));
  check('suspendu : la lecture reste possible', (await hook('GET', '/listings', U(47))) === 'ok');
  check('suspendu : une RPC de lecture reste possible', (await hook('POST', '/rpc/marketplace_search', U(47))) === 'ok');
  check('suspendu : le support reste joignable', (await hook('POST', '/rpc/support_ticket_create', U(47))) === 'ok');
  check('actif : une RPC d\'écriture passe', (await hook('POST', '/rpc/shop_save', U(41))) === 'ok');
  check('2FA : toujours appliquée aux opérations sensibles', /double authentification/.test(await (async () => { await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${U(41)}', 'verified')`); return hook('POST', '/rpc/payment_start', U(41), 'aal1'); })()));

  // --- MoMo
  await as(U(41));
  await fails('momo : un virement est refusé à un étudiant', `select momo_prepare_transfer('${U(41)}', '237690000000', 1000, 'x', 'cle-unique-1')`, /réservés à la finance/);

  // --- création de profil : l'e-mail est celui du compte
  await as(U(41));
  await fails('qr : un étudiant ne fabrique pas un QR certificat', `select qr_issue('certificate', 'BE-CERT-X')`, /réservé à l'équipe/);
  await fails('qr : un étudiant ne fabrique pas un QR événement', `select qr_issue('event', 'x')`, /réservé à l'équipe/);
  await fails('qr : le retrait d une commande qui n est pas la sienne est refusé', `select qr_issue('order_pickup', '#BE-2026-0001')`, /ne vous appartient pas/);
  check('qr : son propre QR de profil reste possible', (await q(`select qr_issue('profile', '${U(41)}') r`))[0].r.created === true);
  await as(U(43));
  check('qr : l equipe peut emettre un QR certificat', (await q(`select qr_issue('certificate', 'BE-CERT-X') r`))[0].r.created === true);
  await db.exec('reset role');
  await db.exec(`insert into auth.users(id,email) values ('${U(51)}','vrai@t.cm')`);
  await as(U(51));
  await q(`insert into profiles(id, name, role, email) values ('${U(51)}', 'Nouveau', 'student', 'victime@t.cm')`);
  await db.exec('reset role');
  check('profil créé : l\'e-mail est celui du compte, pas celui fourni', (await q(`select email from profiles where id = '${U(51)}'`))[0].email === 'vrai@t.cm');

  console.log(`etu_securite: ${ok} OK, ${ko} KO`);
}
