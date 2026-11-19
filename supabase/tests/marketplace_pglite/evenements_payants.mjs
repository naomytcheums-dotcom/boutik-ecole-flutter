// Scénario PGlite de la migration 20261116100000 (événements payants) : réservation, reprise, expiration, confirmation, reçu, refus.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./evenements_payants.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const E = (n) => `00000000-0000-0000-0000-00000000ee${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const tx = async (id) => (await q(`select * from payment_transactions where id = '${id}'`))[0];
  const reg = async (ev, user) => (await q(`select * from event_registrations where event_id = '${ev}' and user_id = '${user}'`))[0];
  const evState = async (user, ev) => { await as(user); return (await q(`select e from jsonb_array_elements(events_upcoming(50)) e where e->>'id' = '${ev}'`))[0]?.e; };

  await db.exec('reset role');
  const roles = { 31: 'student', 32: 'student', 33: 'student', 34: 'student', 35: 'finance', 36: 'student', 37: 'dept' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','e${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','e${n}@t.cm')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${U(36)}'`);
  // K1 : droits minimaux par défaut ; la finance du scénario reçoit explicitement ses permissions.
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${U(35)}' and team_code = 'finance'`);
  const ins = (n, title, price, cap, when = `now() + interval '10 days'`) => db.exec(
    `insert into events (id, title, kind, starts_at, place, price, capacity, status, created_by) values ('${E(n)}', '${title}', 'atelier', ${when}, 'Salle B2', ${price}, ${cap}, 'published', '${U(37)}')`);
  await ins(1, 'Atelier payant', 5000, 2);
  await ins(2, 'Atelier gratuit', 0, null);
  await ins(3, 'Salon à une place', 3000, 1);
  await ins(4, 'Conférence passée', 2000, null, `now() - interval '1 day'`);
  await ins(5, 'Salon tardif', 1500, 1);

  // --- inscription simple
  await as(U(31));
  await fails('event_register : événement payant redirigé vers le paiement', `select event_register('${E(1)}')`, /payant.*Payer et s'inscrire/);
  check('event_register : événement gratuit inchangé', (await q(`select event_register('${E(2)}') r`))[0].r === 'registered');
  check('event_register : gratuit déjà inscrit', (await q(`select event_register('${E(2)}') r`))[0].r === 'already');
  await fails('event_checkout : événement gratuit refusé', `select event_checkout('${E(2)}')`, /gratuit/);
  await fails('event_checkout : événement passé refusé', `select event_checkout('${E(4)}')`, /terminé/);
  await fails('event_checkout : événement inconnu', `select event_checkout('${E(99)}')`, /introuvable/);
  await fails('event_checkout : prestataire invalide', `select event_checkout('${E(1)}', 'dikalo')`, /invalide/);
  await fails('event_checkout : le prix n\'est pas un paramètre', `select event_checkout('${E(1)}', 'tara', 1)`, /does not exist|n'existe pas|function/);

  // --- réservation
  const c1 = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  check('event_checkout : montant lu en base', c1.amount === 5000 && c1.provider === 'tara' && c1.status === 'created' && c1.resumed === false, JSON.stringify(c1));
  let t = await tx(c1.id);
  check('event_checkout : transaction event/evt:<id>/tara', t.kind === 'event' && t.subject === `evt:${E(1)}` && t.provider === 'tara' && t.amount === 5000 && t.payer_id === U(31));
  let g = await reg(E(1), U(31));
  check('event_checkout : place réservée en attente avec expiration', g.status === 'pending_payment' && g.payment_id === c1.id && g.amount_due === 5000 && new Date(g.hold_expires_at) > new Date());
  let st = await evState(U(31), E(1));
  check('état : en attente, pas encore inscrit, place retenue', st.my_status === 'pending_payment' && st.mine === false && st.registered === 0 && st.held === 1 && st.payment_status === 'created', JSON.stringify(st));
  st = await evState(U(32), E(1));
  check('état : les autres voient la place retenue', st.held === 1 && st.my_status === null && st.mine === false);
  await as(U(31));
  const c1b = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  check('event_checkout : la réservation active est reprise (même transaction)', c1b.id === c1.id && c1b.resumed === true);
  check('event_checkout : une seule réservation et une seule transaction', (await q(`select count(*)::int n from payment_transactions where kind = 'event' and payer_id = '${U(31)}'`))[0].n === 1);
  // --- changement de mode : la transaction non aboutie est annulée, une nouvelle est créée
  const c1m = (await q(`select event_checkout('${E(1)}', 'manual') r`))[0].r;
  check('event_checkout : passage au paiement manuel', c1m.id !== c1.id && c1m.provider === 'manual' && c1m.resumed === false);
  check('event_checkout : ancienne transaction annulée', (await tx(c1.id)).status === 'cancelled');
  check('event_checkout : la réservation suit la nouvelle transaction', (await reg(E(1), U(31))).payment_id === c1m.id);

  // --- refus
  await as(U(36));
  await fails('event_checkout : compte suspendu refusé', `select event_checkout('${E(1)}')`, /suspendu/);
  await as(null, 'anon');
  await fails('event_checkout : anonyme refusé', `select event_checkout('${E(1)}')`, /permission denied/);
  await as(U(31));
  await fails('event_checkout : fonctions internes inaccessibles', `select expire_event_holds()`, /permission denied/);
  await fails('internes : _event_drop_hold inaccessible', `select _event_drop_hold('${E(1)}', '${U(31)}', 'x')`, /permission denied/);
  await fails('internes : _event_taken inaccessible', `select _event_taken('${E(1)}')`, /permission denied/);
  await fails('internes : on_event_paid inaccessible', `select on_event_paid()`, /permission denied/);
  await fails('event_receipts : écriture directe refusée', `insert into event_receipts (number, payment_id, user_id, title, amount, reference) values ('X', '${c1m.id}', '${U(31)}', 't', 1, 'r')`, /permission denied/);

  // --- le payeur ne se confirme pas lui-même
  await fails('payeur : payment_set_status refusé', `select payment_set_status('${c1m.id}', 'confirmed')`, /Action non autorisée/);
  await fails('payeur : update direct de la transaction refusé', `update payment_transactions set status = 'confirmed' where id = '${c1m.id}'`, /permission denied/);
  await fails('payeur : update direct de son inscription refusé', `update event_registrations set status = 'confirmed' where event_id = '${E(1)}'`, /permission denied/);
  await fails('payeur : insertion directe d\'une inscription refusée', `insert into event_registrations (event_id, user_id) values ('${E(3)}', '${U(31)}')`, /permission denied/);
  check('payeur : toujours en attente', (await reg(E(1), U(31))).status === 'pending_payment' && (await evState(U(31), E(1))).mine === false);
  await as(U(32));
  await fails('autre personne : ne confirme pas non plus', `select payment_set_status('${c1m.id}', 'confirmed')`, /Action non autorisée/);

  // --- paiement manuel déclaré puis confirmé par la finance
  await as(U(31));
  await q(`select payment_declare('${c1m.id}', 'MOMO-123456')`);
  check('paiement déclaré : en attente de vérification', (await tx(c1m.id)).status === 'pending');
  await db.exec('reset role');
  await db.exec(`update event_registrations set hold_expires_at = now() - interval '1 hour' where event_id = '${E(1)}'`);
  check('expiration : un paiement en vérification garde sa place', (await q(`select expire_event_holds() n`))[0].n === 0 && (await reg(E(1), U(31))) !== undefined);
  await as(U(31));
  await fails('event_unregister : paiement en cours de vérification', `select event_unregister('${E(1)}')`, /en cours de vérification/);
  const again = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  check('event_checkout : reprise d\'un paiement déclaré sans doublon', again.id === c1m.id && again.status === 'pending');

  await as(U(35));
  await q(`select payment_set_status('${c1m.id}', 'confirmed')`);
  await db.exec('reset role');
  g = await reg(E(1), U(31));
  check('confirmation : inscription validée', g.status === 'confirmed' && g.hold_expires_at === null && g.payment_id === c1m.id);
  const rc = await q(`select * from event_receipts where payment_id = '${c1m.id}'`);
  check('confirmation : reçu logique créé', rc.length === 1 && rc[0].amount === 5000 && rc[0].user_id === U(31) && /^REC-EV-\d+$/.test(rc[0].number) && rc[0].reference === (await tx(c1m.id)).reference);
  check('confirmation : l\'inscrit est notifié', (await q(`select 1 from notifications where user_id = '${U(31)}' and title = 'Inscription confirmée' and body like '%reçu REC-EV-%'`)).length === 1);
  check('confirmation : l\'organisateur est notifié', (await q(`select 1 from notifications where user_id = '${U(37)}' and title = 'Nouvelle inscription payée'`)).length === 1);
  st = await evState(U(31), E(1));
  check('état : inscrit(e), place comptée', st.mine === true && st.my_status === 'confirmed' && st.registered === 1 && st.held === 0, JSON.stringify(st));
  await as(U(31));
  check('my_event_receipts : le reçu est listé', (await q(`select my_event_receipts() r`))[0].r.length === 1);
  await as(U(32));
  check('my_event_receipts : pas celui des autres', (await q(`select my_event_receipts() r`))[0].r.length === 0);
  check('event_receipts : invisible pour un tiers', (await q(`select 1 from event_receipts`)).length === 0);
  await as(U(35));
  await fails('confirmation : jamais deux fois', `select payment_set_status('${c1m.id}', 'confirmed')`, /déjà confirmé/);
  await as(U(31));
  await fails('event_checkout : déjà inscrit refusé', `select event_checkout('${E(1)}')`, /déjà inscrit/);
  check('event_register : déjà inscrit', (await q(`select event_register('${E(1)}') r`))[0].r === 'already');
  await fails('event_unregister : inscription payée non supprimable', `select event_unregister('${E(1)}')`, /Inscription payée/);
  check('event_unregister : l\'inscription payée est conservée', (await reg(E(1), U(31))).status === 'confirmed');

  // --- expiration (Tara) : la place est libérée et la transaction annulée
  await as(U(32));
  const c2 = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  await as(U(33));
  await fails('capacité : la place retenue compte (2 places, 1 inscrit, 1 retenue)', `select event_checkout('${E(1)}')`, /Plus de places/);
  await fails('capacité : event_register payant toujours refusé', `select event_register('${E(1)}')`, /payant/);
  await db.exec('reset role');
  await db.exec(`update event_registrations set hold_expires_at = now() - interval '1 minute' where event_id = '${E(1)}' and user_id = '${U(32)}'`);
  st = await evState(U(33), E(1));
  check('expiration : une réservation échue ne retient plus la place même avant le nettoyage', st.held === 0, JSON.stringify(st));
  await db.exec('reset role');
  check('expiration : expire_event_holds libère 1 réservation', (await q(`select expire_event_holds() n`))[0].n === 1);
  check('expiration : inscription supprimée', (await reg(E(1), U(32))) === undefined);
  t = await tx(c2.id);
  check('expiration : transaction annulée', t.status === 'cancelled', t.status);
  check('expiration : la personne est prévenue', (await q(`select 1 from notifications where user_id = '${U(32)}' and title = 'Réservation expirée'`)).length === 1);
  check('expiration : idempotente', (await q(`select expire_event_holds() n`))[0].n === 0);
  await as(U(33));
  const c3 = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  check('capacité : la place libérée peut être réservée par une autre personne', c3.amount === 5000 && !c3.resumed);

  // --- réservation libérée par la personne
  await q(`select event_unregister('${E(1)}')`);
  check('event_unregister : réservation non payée libérée', (await reg(E(1), U(33))) === undefined && (await tx(c3.id)).status === 'cancelled');

  // --- Tara : échec puis réessai sur la même réservation
  const c4 = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  await db.exec('reset role');
  await db.exec(`update payment_transactions set status = 'failed' where id = '${c4.id}'`);
  await as(U(33));
  check('état : paiement échoué visible', (await evState(U(33), E(1))).payment_status === 'failed');
  const c4b = (await q(`select event_checkout('${E(1)}') r`))[0].r;
  check('event_checkout : un paiement échoué se réessaie sur la même transaction', c4b.id === c4.id && c4b.resumed === true && c4b.status === 'failed');
  // confirmation par le fournisseur (webhook : accès serveur) depuis « failed »
  await db.exec('reset role');
  await db.exec(`update payment_transactions set status = 'confirmed', decided_at = now() where id = '${c4.id}'`);
  check('webhook : inscription validée à la confirmation', (await reg(E(1), U(33))).status === 'confirmed');
  check('webhook : reçu créé', (await q(`select 1 from event_receipts where payment_id = '${c4.id}'`)).length === 1);
  await as(U(34));
  await fails('capacité : événement complet (2 inscrits)', `select event_checkout('${E(1)}')`, /Plus de places/);

  // --- salon à une place : paiement tardif sur une réservation expirée
  await as(U(31));
  const s1 = (await q(`select event_checkout('${E(3)}') r`))[0].r;
  await as(U(32));
  await fails('capacité : salon à une place retenu', `select event_checkout('${E(3)}')`, /Plus de places/);
  await db.exec('reset role');
  await db.exec(`update event_registrations set hold_expires_at = now() - interval '5 minutes' where event_id = '${E(3)}'`);
  await q(`select expire_event_holds()`);
  await as(U(32));
  const s2 = (await q(`select event_checkout('${E(3)}') r`))[0].r;
  await db.exec('reset role');
  await db.exec(`update payment_transactions set status = 'confirmed' where id = '${s2.id}'`);
  check('place unique : la deuxième personne est inscrite', (await reg(E(3), U(32))).status === 'confirmed');
  // paiement tardif de la première personne (annulé puis confirmé par la finance) : plus de place -> remboursement signalé
  await as(U(35));
  await q(`select payment_set_status('${s1.id}', 'confirmed', 'paiement tardif')`);
  await db.exec('reset role');
  check('paiement tardif : pas d\'inscription au-delà de la capacité', (await reg(E(3), U(31))) === undefined);
  check('paiement tardif : la personne est prévenue', (await q(`select 1 from notifications where user_id = '${U(31)}' and title = 'Paiement reçu, inscription impossible'`)).length === 1);
  check('paiement tardif : la finance doit rembourser', (await q(`select 1 from notifications where user_id = '${U(35)}' and title = 'Remboursement à traiter'`)).length === 1);
  check('paiement tardif : aucun reçu', (await q(`select 1 from event_receipts where payment_id = '${s1.id}'`)).length === 0);

  // --- paiement tardif quand la place est encore libre
  await as(U(34));
  const l1 = (await q(`select event_checkout('${E(5)}') r`))[0].r;
  await db.exec('reset role');
  await db.exec(`update event_registrations set hold_expires_at = now() - interval '5 minutes' where event_id = '${E(5)}'`);
  await q(`select expire_event_holds()`);
  await as(U(35));
  await q(`select payment_set_status('${l1.id}', 'confirmed')`);
  await db.exec('reset role');
  check('paiement tardif : place encore libre, inscription validée', (await reg(E(5), U(34)))?.status === 'confirmed');

  // --- rappels : seulement les inscriptions confirmées
  await db.exec('reset role');
  await db.exec(`update events set starts_at = now() + interval '12 hours' where id in ('${E(2)}', '${E(3)}')`);
  check('rappels : seules les inscriptions confirmées sont rappelées (gratuit + salon payé)', (await q(`select send_event_reminders() n`))[0].n === 2);
  await as(null, 'anon');
  check('events_upcoming : lisible sans connexion', (await q(`select jsonb_array_length(events_upcoming(50)) n`))[0].n >= 3);
  const anon = (await q(`select e from jsonb_array_elements(events_upcoming(50)) e where e->>'id' = '${E(1)}'`))[0].e;
  check('events_upcoming : anonyme sans état personnel', anon.my_status === null && anon.mine === false && anon.price === 5000);

  console.log(`\n${ok}/${ok + ko}`);
  if (ko) process.exitCode = 1;
}
