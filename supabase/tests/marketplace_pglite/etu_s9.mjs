// Scénario PGlite des migrations 20261117090000 (mode borne) et 20261117090100 (showroom, messagerie, favoris) — lot S9/S10 de l'étudiant.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s9.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const L = (n) => `00000000-0000-0000-0000-00000000e0${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  const roles = { 41: 'client', 42: 'student', 43: 'student', 44: 'admin' };
  const inst = { 42: 'IUT de Douala', 43: 'IUT de Bandjoun' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','e${n}@t.cm'); insert into profiles(id,name,role,email,institution,phone) values ('${U(n)}','Personne ${n}','${r}','e${n}@t.cm',${inst[n] ? `'${inst[n]}'` : 'null'},${n == 42 ? "'690000042'" : 'null'})`);
  }
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values
    ('${L(1)}', '${U(42)}', 'Lampe Douala', 'Genie', 5000, 'approved'),
    ('${L(2)}', '${U(43)}', 'Sac Bandjoun', 'Mode', 7000, 'approved'),
    ('${L(3)}', '${U(42)}', 'Brouillon', 'Genie', 1000, 'draft')`);

  // --- S9-40 / S9-38 : mode borne
  await as(U(41));
  await fails('borne : un client ne crée pas de jeton de borne', `select kiosk_provision('borne-2')`, /Réservé/);
  await as(U(42));
  await fails('borne : un étudiant ne crée pas de jeton de borne', `select kiosk_provision('borne-2')`, /Réservé/);
  await as(null, 'anon');
  await fails('borne : un visiteur ne crée pas de jeton de borne', `select kiosk_provision('borne-2')`, /Connexion requise|permission denied/);
  await as(U(44));
  const tok2 = (await q(`select kiosk_provision('borne-2') t`))[0].t;
  const tok1 = (await q(`select kiosk_provision('borne-1') t`))[0].t;
  check('borne : jeton long et renvoyé une fois', tok2.length >= 32 && tok1 !== tok2);
  await fails('borne : borne inconnue refusée', `select kiosk_provision('borne-99')`, /Borne inconnue/);
  await db.exec('reset role');
  check('borne : seule l\'empreinte est stockée', (await q(`select count(*)::int n from kiosk_devices where token_hash = '${tok2}'`))[0].n === 0);

  await as(null, 'anon');
  await fails('borne : battement refusé avec un mauvais jeton', `select kiosk_heartbeat('borne-2', 'faux')`, /non autorisée/);
  await fails('borne : le jeton d\'une borne ne vaut pas pour une autre', `select kiosk_heartbeat('borne-2', '${tok1}')`, /non autorisée/);
  await as(null, 'anon');
  check('borne : battement accepté sans compte', (await q(`select kiosk_heartbeat('borne-2', '${tok2}') t`))[0].t != null);
  await db.exec('reset role');
  check('borne : last_seen_at mesuré', (await q(`select last_seen_at is not null ok from kiosks where id = 'borne-2'`))[0].ok === true);
  check('borne : une borne sans battement reste inconnue', (await q(`select last_seen_at is null ok from kiosks where id = 'borne-3'`))[0].ok === true);
  await as(null, 'anon');
  await fails('borne : un visiteur ne lit pas les jetons', `select * from kiosk_devices`, /permission denied/);
  await fails('borne : un visiteur ne lit pas les codes d\'appariement', `select * from kiosk_pairings`, /permission denied/);

  // --- appariement borne → téléphone
  await as(null, 'anon');
  await fails('appariement : mauvais jeton refusé', `select kiosk_pair_issue('borne-2', 'faux', '${L(1)}')`, /non autorisée/);
  await fails('appariement : annonce non publiée refusée', `select kiosk_pair_issue('borne-2', '${tok2}', '${L(3)}')`, /introuvable/);
  await fails('appariement : durée invalide refusée', `select kiosk_pair_issue('borne-2', '${tok2}', '${L(1)}', 5)`, /Durée/);
  const p1 = (await q(`select kiosk_pair_issue('borne-2', '${tok2}', '${L(1)}') r`))[0].r;
  check('appariement : code émis sans compte', /^[A-Za-z0-9_-]{32}$/.test(p1.token) && p1.label === 'Lampe Douala', JSON.stringify(p1));
  check('appariement : état en attente', (await q(`select kiosk_pair_status('borne-2', '${tok2}', '${p1.token}') s`))[0].s === 'pending');
  await fails('appariement : un visiteur ne réclame pas un code', `select kiosk_pair_claim('${p1.token}')`, /Connexion requise|permission denied/);
  await as(U(42));
  const own = (await q(`select kiosk_pair_claim('${p1.token}') r`))[0].r;
  check('appariement : son propre produit est signalé et non consommé', own.valid === true && own.own === true);
  await as(U(41));
  const c1 = (await q(`select kiosk_pair_claim('${p1.token}') r`))[0].r;
  check('appariement : le téléphone du client obtient l\'annonce', c1.valid === true && c1.listing_id === L(1) && c1.own === false, JSON.stringify(c1));
  check('appariement : usage unique', (await q(`select kiosk_pair_claim('${p1.token}') r`))[0].r.reason === 'used');
  check('appariement : code inconnu', (await q(`select kiosk_pair_claim('${'x'.repeat(32)}') r`))[0].r.reason === 'unknown');
  await as(null, 'anon');
  check('appariement : la borne voit le code utilisé', (await q(`select kiosk_pair_status('borne-2', '${tok2}', '${p1.token}') s`))[0].s === 'used');
  const p2 = (await q(`select kiosk_pair_issue('borne-2', '${tok2}', '${L(2)}') r`))[0].r;
  const p3 = (await q(`select kiosk_pair_issue('borne-2', '${tok2}', '${L(1)}') r`))[0].r;
  check('appariement : un nouveau code révoque le précédent', (await q(`select kiosk_pair_status('borne-2', '${tok2}', '${p2.token}') s`))[0].s === 'revoked');
  await q(`select kiosk_pair_revoke('borne-2', '${tok2}', '${p3.token}')`);
  check('appariement : « Annuler » révoque le code', (await q(`select kiosk_pair_status('borne-2', '${tok2}', '${p3.token}') s`))[0].s === 'revoked');
  await as(U(41));
  check('appariement : un code révoqué est refusé au téléphone', (await q(`select kiosk_pair_claim('${p3.token}') r`))[0].r.reason === 'revoked');
  await db.exec('reset role');
  const p4 = (await (async () => { await as(null, 'anon'); return (await q(`select kiosk_pair_issue('borne-2', '${tok2}', '${L(2)}') r`))[0].r; })());
  await db.exec('reset role');
  await db.exec(`update kiosk_pairings set expires_at = now() - interval '1 second' where token = '${p4.token}'`);
  await as(U(41));
  check('appariement : un code expiré est refusé', (await q(`select kiosk_pair_claim('${p4.token}') r`))[0].r.reason === 'expired');
  await as(null, 'anon');
  check('appariement : un code d\'une autre borne est inconnu', (await q(`select kiosk_pair_status('borne-1', '${tok1}', '${p4.token}') s`))[0].s === 'unknown');
  await db.exec('reset role');
  await db.exec(`update kiosk_devices set token_hash = repeat('0', 64) where kiosk_id = 'borne-2'`);
  await as(null, 'anon');
  await fails('borne : jeton renouvelé, l\'ancien est refusé', `select kiosk_heartbeat('borne-2', '${tok2}')`, /non autorisée/);

  // --- S9-46 : showroom
  await as(U(42));
  const def = (await q(`select listings_other_institutions() r`))[0].r;
  check('showroom : par défaut, seuls les autres établissements', def.length === 1 && def[0].title === 'Sac Bandjoun', JSON.stringify(def));
  const all = (await q(`select listings_other_institutions(20, true) r`))[0].r;
  check('showroom : « tous » inclut son établissement et ses créations', all.length === 2 && all.some((x) => x.is_mine && x.title === 'Lampe Douala') && all.some((x) => !x.is_mine), JSON.stringify(all));
  check('showroom : le brouillon n\'apparaît jamais', !all.some((x) => x.title === 'Brouillon'));
  const page2 = (await q(`select listings_other_institutions(1, true, 1) r`))[0].r;
  check('showroom : pagination', page2.length === 1 && page2[0].id !== (await q(`select listings_other_institutions(1, true, 0) r`))[0].r[0].id);
  await as(null, 'anon');
  check('showroom : le visiteur voit tout, sans propriétaire', (await q(`select listings_other_institutions() r`))[0].r.length === 2);

  // --- S10-9 : auto-favoris
  await as(U(42));
  await fails('favoris : on ne met pas sa propre annonce en favoris', `insert into favorites (user_id, listing_id) values ('${U(42)}', '${L(1)}')`, /propre annonce/);
  await q(`insert into favorites (user_id, listing_id) values ('${U(42)}', '${L(2)}')`);
  check('favoris : l\'annonce d\'un autre reste possible', (await q(`select count(*)::int n from favorites where user_id = '${U(42)}'`))[0].n === 1);

  // --- S10-5 : cartes « Votre annonce »
  const mineCards = (await q(`select marketplace_search() r`))[0].r;
  check('catalogue : ma carte est marquée is_mine', mineCards.find((c) => c.id === L(1))?.is_mine === true && mineCards.find((c) => c.id === L(2))?.is_mine === false, JSON.stringify(mineCards.map((c) => [c.id, c.is_mine])));
  await as(U(41));
  check('catalogue : pour un autre compte, aucune carte n\'est à moi', (await q(`select marketplace_search() r`))[0].r.every((c) => c.is_mine === false));
  await as(null, 'anon');
  check('catalogue : visiteur, is_mine faux', (await q(`select marketplace_search() r`))[0].r.every((c) => c.is_mine === false));
  await as(U(42));

  // --- S9-3 : notifications de messages lues avec la conversation, sans double compte
  await as(U(41));
  const cid = (await q(`select start_direct_conversation('${U(42)}', 'Bonjour vendeur') c`))[0].c;
  await as(U(42));
  const before = (await q(`select unread_counts() u`))[0].u;
  check('cloche : le message n\'est pas compté deux fois', before.messages === 1 && before.notifications === 0, JSON.stringify(before));
  await q(`select mark_conversation_read('${cid}')`);
  const after = (await q(`select count(*)::int n from notifications where user_id = '${U(42)}' and kind = 'message' and read_at is null`))[0].n;
  check('messagerie : lire la conversation marque la notification lue', after === 0);
  check('messagerie : compteur de messages remis à zéro', (await q(`select unread_counts() u`))[0].u.messages === 0);
  await db.exec('reset role');
  await db.exec(`insert into notifications (user_id, kind, title, body) values ('${U(42)}', 'order', 'Nouvelle commande', 'x')`);
  await as(U(42));
  check('cloche : une vraie notification est comptée', (await q(`select unread_counts() u`))[0].u.notifications === 1);

  // --- S9-1 : WhatsApp saisi en 236 (notification_contacts) utilisé comme adresse d'envoi
  // Lot G5 : le numéro WhatsApp est le numéro de téléphone VÉRIFIÉ du compte ; un numéro non vérifié ou différent est refusé.
  await fails('canaux : WhatsApp refusé tant que le téléphone n\'est pas vérifié', `select set_whatsapp_number('+237 690 00 00 42')`, /vérifié/);
  await db.exec('reset role');
  await db.exec(`update profiles set phone_verified = true where id = '${U(42)}'`);
  await as(U(42));
  await fails('canaux : un autre numéro que le numéro vérifié est refusé', `select set_whatsapp_number('+237 677 00 00 42')`, /vérifié/);
  await q(`select set_whatsapp_number('+237 690 00 00 42')`);
  await q(`select set_notification_preference('whatsapp', '*', true)`);
  await db.exec('reset role');
  await db.exec(`insert into notifications (user_id, kind, title, body) values ('${U(42)}', 'order', 'Argent débloqué', 'y')`);
  const ob = await q(`select to_address from notification_outbox where user_id = '${U(42)}' and channel = 'whatsapp' order by id desc limit 1`);
  check('canaux : le WhatsApp part vers le numéro vérifié', ob.length === 1 && ob[0].to_address === '+237690000042', JSON.stringify(ob));
  await db.exec(`insert into auth.users(id,email) values ('${U(45)}','e45@t.cm'); insert into profiles(id,name,role,email,phone) values ('${U(45)}','Personne 45','student','e45@t.cm',null)`);
  await as(U(45));
  await fails('canaux : sans téléphone vérifié, le numéro saisi ne suffit plus', `select set_whatsapp_number('677 00 00 45')`, /vérifié/);
  await db.exec('reset role');
  await db.exec(`insert into notifications (user_id, kind, title, body) values ('${U(45)}', 'order', 'Nouvelle commande', 'z')`);
  const ob2 = await q(`select to_address from notification_outbox where user_id = '${U(45)}' and channel = 'whatsapp'`);
  check('canaux : sans téléphone vérifié, aucun WhatsApp en file', ob2.length === 0, JSON.stringify(ob2));

  console.log(`\nRésultat : ${ok} OK, ${ko} ECHEC`);
  if (ko) process.exitCode = 1;
}
