// Scénario PGlite du lot S5 (profil étudiant) : événements (création, modification, annulation, remboursements), économie circulaire,
// équipe de projet, campagnes (clôture, reversement, remboursement, jalons validés), notifications, SOS, appels…
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s5.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  let cur = [null, null];
  db.exec = (s) => { if (s === 'reset role') { cur = [null, null]; return rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)"); } return rawExec(s); };
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const E = (n) => `00000000-0000-0000-0000-00000000ee${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { cur = [uid, role]; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const qa = async (sql) => { const saved = cur; await db.exec('reset role'); const r = (await db.query(sql)).rows; cur = saved; await db.exec(`select set_config('request.jwt.claim.sub', '${cur[0] ?? ''}', false)`); if (cur[1]) await db.exec(`set role ${cur[1]}`); return r; };
  const notifs = async (user, kind, titleLike) => (await qa(`select * from notifications where user_id = '${user}' and kind = '${kind}' and title like '${titleLike}' order by created_at`));

  await db.exec('reset role');
  // 1 à 9 : étudiants ; 10 : dept ; 11 : admin ; 12 : finance ; 13 : client ; 14 : dept (autre organisateur)
  const roles = { 1: 'student', 2: 'student', 3: 'student', 4: 'student', 5: 'student', 6: 'student', 10: 'dept', 11: 'admin', 12: 'finance', 13: 'client', 14: 'dept' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','s5_${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','s5_${n}@t.cm')`);
  }

  // ============================================================ S5-49 / 52 / 51 / 50 / 56 : cycle de vie d'un événement
  const mk = (title, price = 0, cap = 'null', days = 10) => `select event_create('${title}', 'Description', 'atelier', now() + interval '${days} days', now() + interval '${days} days 2 hours', 'Salle B2', ${price}, ${cap}) id`;
  await as(U(1));
  await fails('event_create : un étudiant ne crée pas d\'événement', mk('Atelier étudiant'), /non autorisée/);
  await as(U(13));
  await fails('event_create : un client ne crée pas d\'événement', mk('Atelier client'), /non autorisée/);
  await as(U(10));
  await fails('event_create : titre trop court', mk('ab'), /Titre/);
  await fails('event_create : date passée refusée', `select event_create('Passé', '', 'atelier', now() - interval '1 day', null, '', 0, null)`, /futur/);
  await fails('event_create : fin avant début refusée', `select event_create('Fin avant', '', 'atelier', now() + interval '2 days', now() + interval '1 day', '', 0, null)`, /fin/);
  await fails('event_create : prix négatif refusé', mk('Prix négatif', -5), /Tarif/);
  await fails('event_create : capacité nulle refusée', mk('Capacité zéro', 0, '0'), /Capacité/);
  const evPaid = (await q(mk('Salon payant', 5000, '3')))[0].id;
  const evFree = (await q(mk('Atelier gratuit', 0, 'null', 12)))[0].id;
  const evB = (await q(`select event_create('Conférence B', '', 'conference', now() + interval '20 days', null, 'Amphi', 2000, 5) id`))[0].id;
  const row = (await qa(`select created_by, price, status from events where id = '${evPaid}'`))[0];
  check('event_create : organisateur enregistré, prix en FCFA, publié', row.created_by === U(10) && row.price === 5000 && row.status === 'published', JSON.stringify(row));

  // inscriptions : gratuit (U1, U2), payant confirmé (U3 par la finance), payant en attente (U4), réservation non payée (U5)
  await as(U(1)); await q(`select event_register('${evFree}')`);
  await as(U(2)); await q(`select event_register('${evFree}')`);
  await as(U(3)); const c3 = (await q(`select event_checkout('${evPaid}', 'manual') r`))[0].r;
  await as(U(4)); const c4 = (await q(`select event_checkout('${evPaid}', 'manual') r`))[0].r;
  await as(U(5)); await q(`select event_checkout('${evPaid}', 'manual') r`);
  await as(U(3)); await q(`select payment_declare('${c3.id}', 'MP123')`);
  await as(U(12)); await q(`select payment_set_status('${c3.id}', 'confirmed')`);
  await as(U(4)); await q(`select payment_declare('${c4.id}', 'MP456')`);
  check('événement payant : le paiement confirmé inscrit et notifie l\'organisateur (created_by renseigné)', (await notifs(U(10), 'event', 'Nouvelle inscription payée')).length === 1);

  // modification
  await as(U(14));
  await fails('event_update : un autre responsable ne modifie pas', `select event_update('${evPaid}', 'Salon payant', '', 'atelier', now() + interval '10 days', null, 'Salle B2', 5000, 3)`, /introuvable/);
  await as(U(1));
  await fails('event_update : un étudiant ne modifie pas', `select event_update('${evPaid}', 'Salon payant', '', 'atelier', now() + interval '10 days', null, 'Salle B2', 5000, 3)`, /non autorisée/);
  await as(U(10));
  await fails('event_update : tarif figé quand des inscriptions payées existent', `select event_update('${evPaid}', 'Salon payant', '', 'atelier', now() + interval '10 days', null, 'Salle B2', 6000, 3)`, /tarif/i);
  await fails('event_update : capacité sous les places prises refusée', `select event_update('${evPaid}', 'Salon payant', '', 'atelier', now() + interval '10 days', null, 'Salle B2', 5000, 1)`, /Capacité inférieure/);
  const before = (await notifs(U(3), 'event', 'Événement modifié')).length;
  const nUp = (await q(`select event_update('${evPaid}', 'Salon payant', 'Nouveau texte', 'atelier', now() + interval '11 days', null, 'Amphi 200', 5000, 3) n`))[0].n;
  check('event_update : date et lieu changés, inscrits (confirmé + réservation) prévenus', nUp === 3 && (await notifs(U(3), 'event', 'Événement modifié')).length === before + 1 && (await notifs(U(4), 'event', 'Événement modifié')).length === 1, String(nUp));
  check('event_update : colonnes mises à jour', (await qa(`select place, description from events where id = '${evPaid}'`))[0].place === 'Amphi 200');
  // un tarif peut changer tant qu'aucun paiement n'existe
  await q(`select event_update('${evB}', 'Conférence B', '', 'conference', now() + interval '20 days', null, 'Amphi', 2500, 5)`);
  check('event_update : tarif modifiable sans inscription payée', (await qa(`select price from events where id = '${evB}'`))[0].price === 2500);
  await as(U(11)); await q(`select event_update('${evB}', 'Conférence B', '', 'conference', now() + interval '21 days', null, 'Amphi', 2500, 5)`);
  check('event_update : l\'administration peut modifier l\'événement d\'un autre', true);

  // annulation
  await as(U(1));
  await fails('event_cancel : un étudiant ne peut pas annuler', `select event_cancel('${evPaid}', 'Raison valable')`, /non autorisée/);
  await as(U(14));
  await fails('event_cancel : un autre responsable ne peut pas annuler', `select event_cancel('${evPaid}', 'Raison valable')`, /introuvable/);
  await as(U(10));
  await fails('event_cancel : motif obligatoire', `select event_cancel('${evPaid}', 'x')`, /motif/);
  const nC = (await q(`select event_cancel('${evPaid}', 'Intervenant indisponible') n`))[0].n;
  check('event_cancel : 4 inscrits concernés', nC === 3, String(nC));
  const st = (await qa(`select status, cancel_reason from events where id = '${evPaid}'`))[0];
  check('event_cancel : événement annulé avec motif', st.status === 'cancelled' && st.cancel_reason === 'Intervenant indisponible');
  check('event_cancel : le payé est marqué à rembourser', (await qa(`select refund_status, status from event_registrations where event_id = '${evPaid}' and user_id = '${U(3)}'`))[0].refund_status === 'to_refund');
  check('event_cancel : le paiement déclaré en vérification est aussi à rembourser', (await qa(`select refund_status from event_registrations where event_id = '${evPaid}' and user_id = '${U(4)}'`))[0].refund_status === 'to_refund');
  check('event_cancel : la réservation non payée est libérée et la transaction annulée', (await qa(`select count(*)::int n from event_registrations where event_id = '${evPaid}' and user_id = '${U(5)}'`))[0].n === 0);
  check('event_cancel : inscrits prévenus', (await notifs(U(3), 'event', 'Événement annulé%')).length === 1 && (await notifs(U(5), 'event', 'Événement annulé')).length === 1);
  check('event_cancel : la finance est prévenue des remboursements', (await notifs(U(12), 'payment', 'Remboursements à traiter')).length === 1);
  await fails('event_cancel : double annulation refusée', `select event_cancel('${evPaid}', 'Encore une fois')`, /déjà annulé/);
  await fails('event_update : événement annulé non modifiable', `select event_update('${evPaid}', 'Salon', '', 'atelier', now() + interval '10 days', null, 'x', 5000, 3)`, /annulé/);
  await as(U(6));
  await fails('event_checkout : événement annulé non réservable', `select event_checkout('${evPaid}')`, /introuvable/);
  // paiement tardif sur un événement annulé : aucune inscription, remboursement signalé
  await as(U(12)); await q(`select payment_set_status('${c4.id}', 'confirmed')`);
  check('paiement tardif : pas d\'inscription confirmée sur un événement annulé', (await qa(`select status from event_registrations where event_id = '${evPaid}' and user_id = '${U(4)}'`))[0].status === 'cancelled');
  check('paiement tardif : remboursement signalé à la finance', (await qa(`select count(*)::int n from notifications where user_id = '${U(12)}' and title = 'Remboursement à traiter'`))[0].n >= 1);
  // remboursement
  await as(U(1));
  await fails('event_refund_done : refusé à un étudiant', `select event_refund_done('${evPaid}', '${U(3)}')`, /non autorisée/);
  await as(U(12));
  await q(`select event_refund_done('${evPaid}', '${U(3)}')`);
  check('event_refund_done : remboursé + inscrit prévenu', (await qa(`select refund_status from event_registrations where event_id = '${evPaid}' and user_id = '${U(3)}'`))[0].refund_status === 'refunded' && (await notifs(U(3), 'event', 'Remboursement effectué')).length === 1);
  await fails('event_refund_done : une seule fois', `select event_refund_done('${evPaid}', '${U(3)}')`, /Aucun remboursement/);
  // lectures
  await as(U(10));
  const man = (await q(`select events_managed() m`))[0].m;
  check('events_managed : l\'organisateur voit ses événements et le nombre de remboursements', man.length === 3 && man.some((x) => x.id === evPaid && x.status === 'cancelled'), JSON.stringify(man.map((x) => x.title)));
  await as(U(14));
  check('events_managed : un autre responsable ne voit pas ces événements', (await q(`select jsonb_array_length(events_managed()) n`))[0].n === 0);
  await as(U(1));
  await fails('events_managed : refusé à un étudiant', `select events_managed()`, /non autorisée/);
  await as(U(10));
  check('event_registrants : liste de l\'organisateur', (await q(`select jsonb_array_length(event_registrants('${evFree}')) n`))[0].n === 2);
  await as(U(1));
  await fails('event_registrants : refusé à un étudiant', `select event_registrants('${evFree}')`, /introuvable|non autorisée/);
  await as(U(3));
  const mine = (await q(`select my_event_registrations() r`))[0].r;
  check('my_event_registrations : inscription annulée visible avec son remboursement', mine.length === 1 && mine[0].event_status === 'cancelled' && mine[0].refund_status === 'refunded' && mine[0].receipt && /^REC-EV-/.test(mine[0].receipt), JSON.stringify(mine));
  await as(U(1));
  check('my_event_registrations : inscription gratuite listée', (await q(`select jsonb_array_length(my_event_registrations()) n`))[0].n === 1);
  await as(null, 'anon');
  await fails('my_event_registrations : anonyme refusé', `select my_event_registrations()`, /permission denied/);
  // S5-56 : compte suspendu
  await db.exec('reset role'); await db.exec(`update profiles set suspended = true where id = '${U(6)}'`);
  await as(U(6));
  await fails('event_register : compte suspendu refusé', `select event_register('${evFree}')`, /suspendu/);
  await db.exec('reset role'); await db.exec(`update profiles set suspended = false where id = '${U(6)}'`);
  // annulation d'un événement gratuit : inscrits prévenus
  await as(U(10)); await q(`select event_cancel('${evFree}', 'Salle indisponible')`);
  check('event_cancel : inscrits gratuits prévenus et ligne conservée', (await notifs(U(1), 'event', 'Événement annulé')).length === 1 && (await qa(`select status from event_registrations where event_id = '${evFree}' and user_id = '${U(1)}'`))[0].status === 'cancelled');
  await as(U(1)); await fails('event_register : événement annulé refusé', `select event_register('${evFree}')`, /introuvable/);

  // ============================================================ S5-65 / 66 / 69 / 70 / 71 / 74 : économie circulaire et impact
  await db.exec('reset role');
  const L = (n) => `00000000-0000-0000-0000-00000000a1${String(n).padStart(2, '0')}`;
  await db.exec(`update profiles set city = 'Douala' where id in ('${U(1)}', '${U(2)}', '${U(3)}'); update profiles set city = 'Bandjoun' where id = '${U(4)}'`);
  await db.exec(`insert into listings (id, seller_id, title, department, price, stock, status, recycled, recycled_kg) values
    ('${L(1)}', '${U(1)}', 'Lampe récup', 'GI', 1000, 10, 'approved', true, 1.5),
    ('${L(2)}', '${U(1)}', 'Sac neuf', 'GI', 5000, 10, 'approved', false, null),
    ('${L(3)}', '${U(2)}', 'Vase récup', 'GI', 2000, 10, 'approved', true, 2),
    ('${L(4)}', '${U(3)}', 'Pot', 'GI', 1500, 10, 'approved', false, null),
    ('${L(5)}', '${U(4)}', 'Plateau', 'GI', 1500, 10, 'approved', false, null)`);
  await db.exec(`insert into orders (id, number, buyer_id, subtotal, method, paid) values
    ('00000000-0000-0000-0000-0000000000b1', '#BE-2026-9001', '${U(13)}', 7000, 'manual', true),
    ('00000000-0000-0000-0000-0000000000b2', '#BE-2026-9002', '${U(1)}', 2000, 'manual', true),
    ('00000000-0000-0000-0000-0000000000b3', '#BE-2026-9003', '${U(13)}', 1500, 'manual', true),
    ('00000000-0000-0000-0000-0000000000b5', '#BE-2026-9005', '${U(13)}', 1500, 'manual', true)`);
  await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values
    ('00000000-0000-0000-0000-0000000000b1', '${L(1)}', 'Lampe récup', 1000, 2),
    ('00000000-0000-0000-0000-0000000000b1', '${L(2)}', 'Sac neuf', 5000, 1),
    ('00000000-0000-0000-0000-0000000000b2', '${L(1)}', 'Lampe récup', 1000, 2),
    ('00000000-0000-0000-0000-0000000000b3', '${L(3)}', 'Vase récup', 2000, 1),
    ('00000000-0000-0000-0000-0000000000b5', '${L(4)}', 'Pot', 1500, 1)`);
  await as(U(1));
  await fails('listings : un poids ne peut accompagner un produit non déclaré récupéré', `update listings set recycled = false, recycled_kg = 3 where id = '${L(2)}'`, /listings_recycled_decl_check|check/);
  await fails('listings : plus de 1 000 kg par article refusé', `update listings set recycled_kg = 5000 where id = '${L(1)}'`, /listings_recycled_decl_check|check/);
  await q(`update listings set recycled = true, recycled_kg = 2.5 where id = '${L(2)}'`);
  check('listings : le vendeur déclare ses matériaux récupérés et leur poids', (await qa(`select recycled, recycled_kg::float8 kg from listings where id = '${L(2)}'`))[0].kg === 2.5);
  await q(`update listings set recycled = false, recycled_kg = null where id = '${L(2)}'`);
  const imp = (await q(`select my_impact() r`))[0].r;
  check('my_impact : le vendeur voit ses ventes payées (commandes, clients, kg valorisés)', imp.seller.orders === 2 && imp.seller.sales === 9000 && imp.seller.clients === 2 && Number(imp.seller.recycled_kg) === 6 && imp.seller.listings === 2 && imp.seller.recycled_listings === 1, JSON.stringify(imp.seller));
  check('my_impact : ses propres achats ne comptent pas dans « étudiants soutenus »', imp.students_supported === 0 && imp.purchases === 0, JSON.stringify(imp));
  await as(U(13));
  const imp13 = (await q(`select my_impact() r`))[0].r;
  check('my_impact : acheteur = kg valorisés des produits déclarés (2 x 1,5 + 2)', imp13.purchases === 3 && Number(imp13.recycled_kg) === 5 && imp13.students_supported === 3, JSON.stringify(imp13));
  await as(null, 'anon');
  const pimp = (await q(`select platform_impact() r`))[0].r;
  check('platform_impact : kg valorisés = produits déclarés seulement', Number(pimp.recycled_kg) === 8, JSON.stringify(pimp));
  check('platform_impact : une ville de 3 étudiants est affichée', pimp.cities.some((c) => c.city === 'Douala' && c.students === 3), JSON.stringify(pimp.cities));
  await db.exec('reset role');
  await db.exec(`insert into orders (id, number, buyer_id, subtotal, method, paid) values ('00000000-0000-0000-0000-0000000000b4', '#BE-2026-9004', '${U(13)}', 1500, 'manual', true); insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('00000000-0000-0000-0000-0000000000b4', '${L(5)}', 'Plateau', 1500, 1)`);
  await as(null, 'anon');
  const pimp2 = (await q(`select platform_impact() r`))[0].r;
  check('platform_impact : une ville à un seul étudiant n\'est pas révélée', !pimp2.cities.some((c) => c.city === 'Bandjoun'), JSON.stringify(pimp2.cities));

  // ============================================================ S5-1 / 5 / 6 / 7 / 19 / 22 / 23 / 24 / 27 / 41 : projets et équipes
  await db.exec('reset role');
  await db.exec(`update profiles set department = 'Informatique' where id = '${U(10)}'; update profiles set department = 'Gestion' where id = '${U(14)}'`);
  const det = (extra = {}) => JSON.stringify({ domain: 'Agritech', problem: 'Les serres sont chères', solution: 'Une serre pilotée par capteurs', progress: 'prototype', contact_email: 'a@b.cm', ...extra }).replace(/'/g, "''");
  const save = (u, dept, extra = {}, publish = true, id = 'null', vis = 'public') => `select project_save_full(${id}, 'projet', 'Serre connectée ${u}', 'Une serre qui arrose toute seule grâce à des capteurs d''humidité.', '${dept}', '${det(extra)}'::jsonb, '[]'::jsonb, '${vis}', ${publish}) id`;
  await as(U(1));
  await fails('project_save_full : lien invalide refusé côté serveur', save(1, 'Informatique', { prototype_url: 'javascript:alert(1)' }), /Lien invalide/);
  await fails('project_save_full : financement non numérique refusé', save(1, 'Informatique', { funding_xaf: 'beaucoup' }), /financement/);
  const P1 = (await q(save(1, 'Informatique', { prototype_url: 'https://exemple.cm/demo', funding_xaf: '150000', evil: 'x' })))[0].id;
  const stored = (await qa(`select details from projects where id = '${P1}'`))[0].details;
  check('project_save_full : clés inconnues ignorées, liens et montant conservés', stored.evil === undefined && stored.prototype_url === 'https://exemple.cm/demo' && stored.funding_xaf === '150000', JSON.stringify(stored));
  check('S5-6 : seuls l\'administration et les responsables du département concerné sont prévenus', (await notifs(U(10), 'project', 'Projet à examiner')).length === 1 && (await notifs(U(11), 'project', 'Projet à examiner')).length === 1 && (await notifs(U(14), 'project', 'Projet à examiner')).length === 0);
  await as(U(14));
  await fails('review_project : un responsable d\'un autre département ne valide pas', `select review_project('${P1}', true, '')`, /autre département/);
  await as(U(10)); await q(`select review_project('${P1}', true, '')`);
  check('review_project : le responsable du département valide', (await qa(`select status from projects where id = '${P1}'`))[0].status === 'approved');
  await as(U(1));
  const P2 = (await q(save(1, 'Génie civil')))[0].id;
  await as(U(14)); await q(`select review_project('${P2}', true, '')`);
  check('review_project : sans responsable correspondant, tout responsable peut valider', (await qa(`select status from projects where id = '${P2}'`))[0].status === 'approved');

  // équipe
  await as(U(1));
  await q(`select project_member_invite('${P1}', '${U(2)}', 'Électronique')`);
  await q(`select project_member_invite('${P1}', '${U(3)}', 'Code')`);
  await fails('project_member_invite : invitation déjà en attente', `select project_member_invite('${P1}', '${U(2)}', 'Électronique')`, /déjà en attente/);
  await as(U(2)); await q(`select project_member_respond('${P1}', true)`);
  await as(U(3)); await q(`select project_member_respond('${P1}', false)`);
  await as(U(1));
  await fails('project_member_invite : ré-invitation d\'un refus bloquée 30 jours', `select project_member_invite('${P1}', '${U(3)}', 'Code')`, /30 jours/);
  await fails('project_member_invite : membre déjà accepté', `select project_member_invite('${P1}', '${U(2)}', '')`, /fait déjà partie/);
  await as(U(2));
  const mp = (await q(`select my_member_projects() r`))[0].r;
  check('S5-1 : le membre accepté retrouve le projet de l\'équipe', mp.length === 1 && mp[0].id === P1 && mp[0].owner && mp[0].role === 'Électronique', JSON.stringify(mp));
  await as(U(3));
  check('S5-1 : un invité qui a refusé ne voit pas le projet', (await q(`select jsonb_array_length(my_member_projects()) n`))[0].n === 0);
  await fails('add_project_step : un non-membre ne contribue pas', `select add_project_step('${P1}', 'Étape pirate', current_date)`, /introuvable/);
  await as(U(2));
  const st2 = (await q(`select add_project_step('${P1}', 'Câblage des capteurs', current_date) id`))[0].id;
  await as(U(1));
  const st1 = (await q(`select add_project_step('${P1}', 'Choix de la carte', current_date) id`))[0].id;
  await as(U(2));
  const steps = (await q(`select my_project_steps('${P1}') r`))[0].r;
  check('S5-1 : le membre lit et contribue au journal (étapes de tous, auteur nommé)', steps.length === 2 && steps.some((s) => s.author && s.mine === true) && steps.some((s) => s.mine === false), JSON.stringify(steps));
  await q(`select project_step_update(${st2}, 'Câblage terminé', current_date)`);
  await fails('project_step_update : un membre ne modifie pas l\'étape du porteur', `select project_step_update(${st1}, 'Modifié', current_date)`, /introuvable/);
  await as(U(1)); await q(`select project_step_update(${st2}, 'Câblage relu par le porteur', current_date)`);
  check('project_step_update : le porteur modifie toute étape', (await qa(`select title from project_steps where id = ${st2}`))[0].title === 'Câblage relu par le porteur');
  // fichiers
  await db.exec('reset role');
  await db.exec(`insert into storage.objects (bucket_id, name, owner_id) values ('project-files', '${U(2)}/plan.pdf', '${U(2)}'), ('project-files', '${U(3)}/autre.pdf', '${U(3)}')`);
  await as(U(2));
  const f2 = (await q(`select register_file('project', '${P1}', '${U(2)}/plan.pdf', 'plan.pdf', 'application/pdf', 1000) id`))[0].id;
  check('S5-1 : le membre dépose un fichier sur le projet', !!f2);
  await as(U(3));
  await fails('register_file : un non-membre ne dépose pas', `select register_file('project', '${P1}', '${U(3)}/autre.pdf', 'autre.pdf', 'application/pdf', 1000)`, /Projet introuvable/);
  await fails('project_files_list : un non-membre ne liste pas', `select project_files_list('${P1}')`, /introuvable/);
  await as(U(1));
  const fl = (await q(`select project_files_list('${P1}') r`))[0].r;
  check('project_files_list : le porteur voit le fichier du membre (auteur nommé)', fl.length === 1 && fl[0].author && fl[0].mine === false, JSON.stringify(fl));
  await as(U(2));
  check('project_files_list : le membre voit les fichiers du projet', (await q(`select jsonb_array_length(project_files_list('${P1}')) n`))[0].n === 1);
  await db.exec('reset role');
  await db.exec(`insert into files (owner_id, scope, ref, path, name, mime, size_bytes) select '${U(1)}', 'project', '${P1}', '${U(1)}/f' || g, 'f' || g || '.pdf', 'application/pdf', 100 from generate_series(1, 49) g`);
  await as(U(1));
  await db.exec('reset role'); await db.exec(`insert into storage.objects (bucket_id, name, owner_id) values ('project-files', '${U(1)}/dernier.pdf', '${U(1)}')`); await as(U(1));
  await fails('S5-27 : plafond de 50 fichiers par projet', `select register_file('project', '${P1}', '${U(1)}/dernier.pdf', 'dernier.pdf', 'application/pdf', 100)`, /Cinquante/);
  await q(`select project_file_remove('${f2}')`);
  check('project_file_remove : le porteur retire le fichier d\'un membre', (await qa(`select count(*)::int n from files where id = '${f2}'`))[0].n === 0);
  // sortie / retrait notifiés
  await as(U(2));
  await q(`select project_member_remove('${P1}', '${U(2)}')`);
  check('S5-1 : le membre quitte l\'équipe, le porteur est prévenu', (await notifs(U(1), 'project', 'Un membre a quitté%')).length === 1 && (await q(`select jsonb_array_length(my_member_projects()) n`))[0].n === 0);
  await fails('add_project_step : après sa sortie le membre ne contribue plus', `select add_project_step('${P1}', 'Encore une étape', current_date)`, /introuvable/);
  await as(U(1));
  await q(`select project_member_invite('${P1}', '${U(4)}', '')`); await as(U(4)); await q(`select project_member_respond('${P1}', true)`);
  await as(U(1)); await q(`select project_member_remove('${P1}', '${U(4)}')`);
  check('S5-24 : la personne retirée est prévenue', (await notifs(U(4), 'project', 'Retiré d%')).length === 1);
  // annuaire
  await as(U(1));
  check('S5-22 : moins de 3 lettres = aucun résultat', (await q(`select project_member_search('Pe') r`))[0].r.length === 0);
  check('S5-22 : recherche de 3 lettres', (await q(`select project_member_search('Per') r`))[0].r.length > 0);
  for (let i = 0; i < 29; i++) await q(`select project_member_search('Per')`);
  await fails('S5-22 : plus de 30 recherches par heure refusées', `select project_member_search('Per')`, /Trop de recherches/);
  // soutien
  await as(U(3)); await q(`select project_upvote_toggle('${P1}')`);
  check('S5-19 : le porteur est prévenu d\'un soutien', (await notifs(U(1), 'project', 'Nouveau soutien')).length === 1);
  await q(`select project_upvote_toggle('${P1}')`); await q(`select project_upvote_toggle('${P1}')`);
  check('S5-19 : un soutien repris ne renvoie pas de notification', (await notifs(U(1), 'project', 'Nouveau soutien')).length === 1);
  // modification d'un projet publié
  await as(U(1));
  await fails('S5-5 : un projet publié ne se modifie pas sans revalidation', save(1, 'Informatique', {}, false, `'${P1}'`), /revalidation|renvoyant/);
  await q(save(1, 'Informatique', { demo_url: 'https://exemple.cm/v2' }, true, `'${P1}'`));
  check('S5-5 / S5-41 : modification d\'un projet publié = revalidation, porteur et responsables prévenus', (await qa(`select status from projects where id = '${P1}'`))[0].status === 'submitted' && (await notifs(U(1), 'project', 'Projet renvoyé en validation')).length === 1 && (await notifs(U(10), 'project', 'Projet modifié à revalider')).length === 1 && (await notifs(U(14), 'project', 'Projet modifié à revalider')).length === 0);

  // ============================================================ S5-3 / 4 / 28 / 31 / 32 / 33 / 35 : campagnes de financement
  await db.exec('reset role');
  check('S5-4 : « campaign » n\'est plus une notification promotionnelle', (await qa(`select notification_category('campaign') c`))[0].c === 'other');
  const CAMP = `Une présentation de campagne suffisamment longue pour passer le contrôle.`;
  await as(U(1));
  const C1 = (await q(`select save_campaign(null, 'project', 'x', 50000, 7, '${CAMP}', '', true, '${P2}') id`))[0].id;
  await fails('S5-28 : une seule campagne active par projet', `select save_campaign(null, 'project', 'x', 60000, 7, '${CAMP}', '', true, '${P2}')`, /une seule campagne active/);
  check('save_campaign : responsables prévenus (aucun responsable du département => tous)', (await notifs(U(10), 'campaign', 'Campagne à examiner')).length === 1 && (await notifs(U(14), 'campaign', 'Campagne à examiner')).length === 1);
  await as(U(1));
  await fails('review_campaign : un étudiant ne valide pas', `select review_campaign('${C1}', true, '')`, /Réservé/);
  await as(U(14)); await q(`select review_campaign('${C1}', true, '')`);
  check('review_campaign : campagne ouverte, échéance fixée', (await qa(`select status, ends_at > now() ok from campaigns where id = '${C1}'`))[0].ok === true);
  // contributions
  const contrib = async (u, amount, declare, confirm) => {
    await as(U(u));
    const pid = (await q(`select campaign_contribute('${C1}', ${amount}) id`))[0].id;
    if (declare) await q(`select payment_declare('${pid}', 'MP-${u}')`);
    if (confirm) { await as(U(12)); await q(`select payment_set_status('${pid}', 'confirmed')`); }
    return pid;
  };
  const p2 = await contrib(2, 30000, true, true);
  const p3 = await contrib(3, 15000, true, true);
  const p4 = await contrib(4, 1000, false, false);
  const p5 = await contrib(5, 5000, true, false);
  check('S5-3 : le porteur est prévenu de chaque contribution confirmée', (await notifs(U(1), 'campaign', 'Nouvelle contribution')).length === 2);
  check('S5-3 : les contributions confirmées sont en séquestre au nom du porteur (70 %)', (await qa(`select sum(beneficiary_amount)::int s, count(*)::int n from money_entries where campaign_id = '${C1}' and status = 'held'`))[0].s === 31500);
  await as(U(1));
  const bk = (await q(`select campaign_backers('${C1}') r`))[0].r;
  check('S5-32 : le porteur voit ses contributeurs (confirmés et en vérification, sans les demandes non payées)', bk.length === 3 && bk.every((b) => b.name && b.amount > 0), JSON.stringify(bk));
  await as(U(2));
  await fails('S5-32 : un tiers ne voit pas les contributeurs', `select campaign_backers('${C1}')`, /introuvable/);
  await fails('S5-31 : une contribution confirmée ne s\'annule pas', `select campaign_contribution_cancel('${p2}')`, /déjà déclaré ou confirmé/);
  await as(U(4)); await q(`select campaign_contribution_cancel('${p4}')`);
  check('S5-31 : une contribution jamais déclarée est annulée avec sa demande de paiement', (await qa(`select count(*)::int n from campaign_contributions where payment_id = '${p4}'`))[0].n === 0 && (await qa(`select status from payment_transactions where id = '${p4}'`))[0].status === 'cancelled');
  // fantôme laissé > 24 h
  await as(U(6)); const p6 = (await q(`select campaign_contribute('${C1}', 2000) id`))[0].id;
  await db.exec('reset role'); await db.exec(`update campaign_contributions set created_at = now() - interval '2 days' where payment_id = '${p6}'`);
  // clôture : paiement déclaré récent = clôture différée
  await db.exec(`update campaigns set ends_at = now() - interval '1 minute' where id = '${C1}'`);
  check('clôture différée tant qu\'un paiement déclaré est en vérification', (await qa(`select campaign_close_due() n`))[0].n === 0 && (await qa(`select status from campaigns where id = '${C1}'`))[0].status === 'approved');
  check('S5-31 : la contribution fantôme de plus de 24 h est nettoyée par la clôture planifiée', (await qa(`select count(*)::int n from campaign_contributions where payment_id = '${p6}'`))[0].n === 0);
  await as(U(12)); await q(`select payment_set_status('${p5}', 'confirmed')`);
  await db.exec('reset role');
  check('campaign_close_due : une campagne échue dont l\'objectif est atteint est clôturée', (await qa(`select campaign_close_due() n`))[0].n === 1);
  const cl = (await qa(`select status, outcome from campaigns where id = '${C1}'`))[0];
  check('S5-3 : campagne financée (50 000 FCFA collectés)', cl.status === 'closed' && cl.outcome === 'funded', JSON.stringify(cl));
  check('S5-3 : le séquestre est débloqué sur le solde du porteur (70 % de 50 000)', (await qa(`select (money_wallet('${U(1)}')->>'available')::int a from (select 1) x`))[0].a === 35000);
  check('S5-3 : le porteur et les contributeurs sont prévenus de la réussite', (await notifs(U(1), 'campaign', 'Campagne réussie')).length === 1 && (await notifs(U(2), 'campaign', 'Campagne financée')).length === 1);
  await as(U(12));
  const po = (await q(`select payout_create('${U(1)}', 35000) id`))[0].id;
  check('S5-3 : la finance peut verser le solde du porteur (payout_create existant)', !!po);
  await as(U(2));
  await fails('campaign_contribute : campagne terminée refusée', `select campaign_contribute('${C1}', 1000)`, /introuvable|terminée/);
  await as(null, 'anon');
  const pub = (await q(`select campaigns_overview(false, '${C1}') r`))[0].r;
  check('S5-33 : une campagne clôturée reste lisible avec son résultat', pub.length === 1 && pub[0].outcome === 'funded' && pub[0].open === false && pub[0].raised === 50000, JSON.stringify(pub[0]));

  // campagne non financée : remboursement
  await db.exec('reset role');
  const P3 = '00000000-0000-0000-0000-0000000000c3';
  await db.exec(`insert into projects (id, owner_id, title, summary, department, status, visibility) values ('${P3}', '${U(2)}', 'Projet solaire', 'Un projet solaire de test', 'Informatique', 'approved', 'public')`);
  const C2 = '00000000-0000-0000-0000-0000000000d2';
  await db.exec(`insert into campaigns (id, owner_id, kind, project, project_id, goal, duration_days, presentation, status, ends_at) values ('${C2}', '${U(2)}', 'project', 'Projet solaire', '${P3}', 100000, 30, '${CAMP}', 'approved', now() + interval '10 days')`);
  await as(U(3)); const q3 = (await q(`select campaign_contribute('${C2}', 8000) id`))[0].id; await q(`select payment_declare('${q3}', 'MP-X')`);
  await as(U(12)); await q(`select payment_set_status('${q3}', 'confirmed')`);
  await db.exec('reset role'); await db.exec(`update campaigns set ends_at = now() - interval '1 minute' where id = '${C2}'`);
  check('campaign_close_due : campagne échue sans objectif', (await qa(`select campaign_close_due() n`))[0].n === 1);
  check('S5-3 : sans objectif, le séquestre est annulé et la contribution est à rembourser', (await qa(`select status from money_entries where campaign_id = '${C2}'`))[0].status === 'refunded' && (await qa(`select refund_status from campaign_contributions where payment_id = '${q3}'`))[0].refund_status === 'to_refund' && (await qa(`select outcome from campaigns where id = '${C2}'`))[0].outcome === 'unfunded');
  check('S5-3 : contributeur, porteur et finance sont prévenus', (await notifs(U(3), 'campaign', 'Campagne terminée : remboursement')).length === 1 && (await notifs(U(2), 'campaign', 'Campagne terminée sans%')).length === 1 && (await notifs(U(12), 'payment', 'Remboursements à traiter')).length >= 1);
  // paiement tardif sur une campagne non financée
  await db.exec('reset role');
  await db.exec(`insert into payment_transactions (id, reference, payer_id, provider, kind, subject, amount, status) values ('00000000-0000-0000-0000-0000000000e9', 'PAY-TARDIF-1', '${U(4)}', 'manual', 'campaign', 'Contribution : Projet solaire', 3000, 'pending');
                 insert into campaign_contributions (campaign_id, user_id, payment_id, amount) values ('${C2}', '${U(4)}', '00000000-0000-0000-0000-0000000000e9', 3000)`);
  await db.exec(`update payment_transactions set status = 'confirmed' where id = '00000000-0000-0000-0000-0000000000e9'`);
  check('paiement tardif sur campagne non financée : à rembourser, aucun séquestre', (await qa(`select refund_status from campaign_contributions where payment_id = '00000000-0000-0000-0000-0000000000e9'`))[0].refund_status === 'to_refund' && (await qa(`select count(*)::int n from money_entries where ref = 'PAY-TARDIF-1'`))[0].n === 0);
  const cid3 = (await qa(`select id from campaign_contributions where payment_id = '${q3}'`))[0].id;
  await as(U(3));
  await fails('campaign_refund_done : refusé à un contributeur', `select campaign_refund_done('${cid3}')`, /non autorisée/);
  await as(U(12)); await q(`select campaign_refund_done('${cid3}')`);
  check('campaign_refund_done : remboursement noté et contributeur prévenu', (await qa(`select refund_status from campaign_contributions where id = '${cid3}'`))[0].refund_status === 'refunded' && (await notifs(U(3), 'campaign', 'Remboursement effectué')).length === 1);
  await fails('campaign_refund_done : une seule fois', `select campaign_refund_done('${cid3}')`, /Aucun remboursement/);

  // jalons : déclarés avec preuve, validés par le département du projet
  await db.exec('reset role');
  const C3 = '00000000-0000-0000-0000-0000000000d3';
  await db.exec(`insert into campaigns (id, owner_id, kind, project, project_id, goal, duration_days, presentation, status, ends_at) values ('${C3}', '${U(5)}', 'project', 'Atelier réparation', (select id from projects where owner_id = '${U(1)}' and department = 'Informatique' limit 1), 40000, 30, '${CAMP}', 'approved', now() + interval '20 days')`);
  await as(U(5));
  const M1 = (await q(`select campaign_milestone_save('${C3}', null, 'Prototype livré', 10000, null) id`))[0].id;
  await fails('S5-35 : un jalon ne se déclare pas sans preuve', `select campaign_milestone_done('${M1}', true, 'ok')`, /preuve/);
  await fails('S5-35 : lien de preuve invalide', `select campaign_milestone_done('${M1}', true, 'Photos du prototype terminé', 'ftp://x')`, /Lien de preuve/);
  await q(`select campaign_milestone_done('${M1}', true, 'Photos du prototype terminé et testé', 'https://exemple.cm/photos')`);
  await as(null, 'anon');
  let ov = (await q(`select campaigns_overview(false, '${C3}') r`))[0].r[0];
  check('S5-35 : déclaré mais non validé = jamais affiché atteint au public, preuve masquée', ov.milestones[0].done === false && ov.milestones[0].declared === false && ov.milestones[0].proof === null, JSON.stringify(ov.milestones));
  await as(U(5));
  ov = (await q(`select campaigns_overview(true, '${C3}') r`))[0].r[0];
  check('S5-35 : le porteur voit sa déclaration en attente de validation', ov.milestones[0].declared === true && !!ov.milestones[0].proof);
  check('S5-35 : les responsables du département sont prévenus', (await notifs(U(10), 'campaign', 'Jalon à valider')).length === 1 && (await notifs(U(14), 'campaign', 'Jalon à valider')).length === 0);
  await fails('campaign_milestone_review : le porteur ne valide pas son jalon', `select campaign_milestone_review('${M1}', true, '')`, /Réservé/);
  await as(U(14));
  await fails('campaign_milestone_review : un autre département ne valide pas', `select campaign_milestone_review('${M1}', true, '')`, /autre département|Aucun jalon/);
  await as(U(10));
  check('campaign_milestones_to_review : liste du département', (await q(`select jsonb_array_length(campaign_milestones_to_review()) n`))[0].n === 1);
  await fails('campaign_milestone_review : refus sans motif', `select campaign_milestone_review('${M1}', false, '')`, /Motif/);
  await q(`select campaign_milestone_review('${M1}', true, 'Preuve vérifiée')`);
  await as(null, 'anon');
  ov = (await q(`select campaigns_overview(false, '${C3}') r`))[0].r[0];
  check('S5-35 : jalon validé = atteint publiquement, preuve visible', ov.milestones[0].done === true && !!ov.milestones[0].proof);
  await as(U(5));
  check('S5-35 : le porteur est prévenu de la validation', (await notifs(U(5), 'campaign', 'Jalon validé')).length === 1);
  await q(`select campaign_milestone_save('${C3}', '${M1}', 'Prototype livré (v2)', 10000, null)`);
  await as(null, 'anon');
  ov = (await q(`select campaigns_overview(false, '${C3}') r`))[0].r[0];
  check('S5-36 : un jalon modifié perd sa validation', ov.milestones[0].done === false);

  // ============================================================ S5-81 / 83 / 87 / 88 / 89 / 90 / 91 / 92 / 94 / 96 / 98 / 100 : innovations
  await db.exec('reset role');
  await db.exec(`update profiles set department = 'Informatique' where id in ('${U(1)}', '${U(2)}', '${U(13)}'); update profiles set department = '  informatique ' where id = '${U(3)}'; update profiles set department = 'Gestion' where id = '${U(4)}'`);
  await db.exec(`insert into points_ledger (user_id, source, ref, points) values ('${U(1)}', 'challenge:posts3', '2026-W45', 200), ('${U(1)}', 'streak6', '2026-11-01', 1)`);
  await as(U(1));
  let pts = (await q(`select my_points() r`))[0].r;
  check('S5-83 : les 200 points hebdomadaires du défi de publications ne comptent plus pour le niveau', pts.total === 1 && pts.level === 'none' && pts.bonus === 200, JSON.stringify(pts));
  check('S5-83 : top_helpers ignore ces points', (await q(`select top_helpers(10) r`))[0].r.every((x) => x.total <= 1));
  // SOS
  await as(U(13));
  await fails('S5-89 : un client ne lance pas de SOS', `select sos_create('Réseaux TP4', 'bloqué')`, /réservé aux étudiants/);
  await fails('S5-89 : un client ne lit pas les SOS', `select sos_list('filiere')`, /réservé aux étudiants/);
  await db.exec('reset role');
  await db.exec(`insert into notifications (user_id, kind, title, body) select '${U(2)}', 'sos', 'SOS Cours : ancien', 'x' from generate_series(1, 5)`);
  await as(U(1));
  const S1 = (await q(`select sos_create('Réseaux TP4', 'Je suis bloqué sur le routage') id`))[0].id;
  check('S5-90 : seuls les étudiants de la filière (casse et espaces ignorés) sont prévenus', (await notifs(U(3), 'sos', 'SOS Cours : Réseaux%')).length === 1 && (await notifs(U(13), 'sos', 'SOS Cours%')).length === 0 && (await notifs(U(4), 'sos', 'SOS Cours%')).length === 0);
  check('S5-90 : un destinataire déjà notifié 5 fois dans la journée ne reçoit plus de SOS', (await notifs(U(2), 'sos', 'SOS Cours : Réseaux%')).length === 0);
  await as(U(13));
  await fails('S5-89 : un client ne répond pas', `select sos_answer('${S1}', 'Je peux aider')`, /réservé aux étudiants/);
  await as(U(4));
  await fails('S5-89 : un étudiant d\'une autre filière ne répond pas', `select sos_answer('${S1}', 'Je peux aider')`, /filière/);
  await as(U(3));
  const A1 = (await q(`select sos_answer('${S1}', 'Regarde la table de routage') id`))[0].id;
  await q(`select sos_answer('${S1}', 'Deuxième indice')`); await q(`select sos_answer('${S1}', 'Troisième indice')`);
  await fails('S5-93 : trois réponses au plus par personne', `select sos_answer('${S1}', 'Quatrième')`, /Trois réponses/);
  await as(U(2));
  await fails('sos_solve : seul l\'auteur', `select sos_solve('${S1}', '${A1}')`, /introuvable/);
  await as(U(1));
  await q(`select sos_solve('${S1}', '${A1}')`);
  await fails('S5-88 : un SOS résolu ne peut plus être « résolu » une seconde fois', `select sos_solve('${S1}', '${A1}')`, /déjà résolu/);
  await as(U(2));
  await fails('S5-88 : plus de réponse sur un SOS résolu', `select sos_answer('${S1}', 'Trop tard')`, /déjà résolu|clos/);
  await as(U(1));
  const S2 = (await q(`select sos_create('Algo TD2', '') id`))[0].id;
  await as(U(3)); await fails('S5-92 : seul l\'auteur clôture son SOS', `select sos_close('${S2}')`, /introuvable/);
  await as(U(1)); await q(`select sos_close('${S2}')`);
  await as(U(3));
  check('S5-92 : un SOS clos disparaît de la liste de la filière', (await q(`select sos_list('filiere') r`))[0].r.every((s) => s.id !== S2));
  // défis
  await db.exec('reset role');
  check('S5-94 : un défi est créé automatiquement quand aucun n\'est actif', (await qa(`select challenge_auto_create() id`))[0].id !== null);
  check('S5-94 : pas de second défi tant qu\'un défi est actif', (await qa(`select challenge_auto_create() id`))[0].id === null);
  const CH = '00000000-0000-0000-0000-0000000000f1', E1 = '00000000-0000-0000-0000-0000000000f2', E2 = '00000000-0000-0000-0000-0000000000f3';
  await db.exec(`insert into weekly_challenges (id, title, description, kind, starts_at, ends_at) values ('${CH}', 'Défi terminé', '', 'code', now() - interval '9 days', now() - interval '1 day');
    insert into challenge_entries (id, challenge_id, author_id, title) values ('${E1}', '${CH}', '${U(2)}', 'Mon outil'), ('${E2}', '${CH}', '${U(3)}', 'Mon autre outil');
    insert into challenge_votes (challenge_id, user_id, entry_id) values ('${CH}', '${U(1)}', '${E1}'), ('${CH}', '${U(4)}', '${E1}'), ('${CH}', '${U(5)}', '${E2}')`);
  check('S5-96 : la tâche planifiée désigne le gagnant sans attendre l\'ouverture de l\'écran', (await qa(`select _challenges_settle() n`))[0].n === 1 && (await qa(`select winner_entry from weekly_challenges where id = '${CH}'`))[0].winner_entry === E1);
  check('S5-87 : le gagnant est prévenu (+50 points)', (await notifs(U(2), 'challenge', 'Défi remporté%')).length === 1);
  await as(U(1));
  check('challenges_list : toujours lisible, ne désigne pas deux fois le gagnant', (await q(`select jsonb_array_length(challenges_list()) n`))[0].n >= 2 && (await notifs(U(2), 'challenge', 'Défi remporté%')).length === 1);
  // victoires
  await db.exec('reset role');
  await db.exec(`update profiles set created_at = now() - interval '30 days' where id in ('${U(2)}', '${U(3)}', '${U(4)}', '${U(5)}', '${U(6)}'); update profiles set created_at = now() where id = '${U(13)}'`);
  await as(U(1));
  const V1 = (await q(`select victory_post('grade', 'J''ai eu 18/20 en réseaux') id`))[0].id;
  for (const u of [2, 3, 4]) { await as(U(u)); await q(`select victory_report('${V1}', 'faux')`); }
  await as(U(13)); await q(`select victory_report('${V1}', 'faux')`);
  await as(U(5)); await q(`select victory_report('${V1}', 'faux')`);
  check('S5-98 : trois signalements (dont un compte récent) ne masquent plus une réussite', (await qa(`select status from victories where id = '${V1}'`))[0].status === 'published');
  await as(U(6)); await q(`select victory_report('${V1}', 'faux')`);
  check('S5-98 : cinq signalements de comptes anciens masquent la réussite', (await qa(`select status from victories where id = '${V1}'`))[0].status === 'hidden');
  await as(U(1));
  const V2 = (await q(`select victory_post('internship', 'Stage obtenu chez Orange') id`))[0].id;
  await as(U(2)); await q(`select victory_cheer('${V2}')`); await q(`select victory_cheer('${V2}')`); await q(`select victory_cheer('${V2}')`);
  check('S5-100 : une félicitation reprise ne renvoie pas de notification', (await notifs(U(1), 'victory', 'Bravo !')).length === 1);
  // éphémère
  await as(U(1));
  const EC = (await q(`select create_ephemeral_community('Révision Réseaux', '', 7, 'public') id`))[0].id;
  const ec0 = (await qa(`select status, expires_at, ephemeral_days from communities where id = '${EC}'`))[0];
  check('S5-81 : une communauté éphémère en attente n\'a pas d\'échéance (elle ne peut pas expirer avant sa validation)', ec0.status === 'pending' && ec0.expires_at === null && ec0.ephemeral_days === 7, JSON.stringify(ec0));
  await as(U(11)); await q(`select community_decide('${EC}', true, '')`);
  const ec1 = (await qa(`select status, expires_at from communities where id = '${EC}'`))[0];
  check('S5-81 : la durée court à partir de la validation', ec1.status === 'active' && ec1.expires_at && Math.abs(new Date(ec1.expires_at) - (Date.now() + 7 * 86400000)) < 3600000, JSON.stringify(ec1));

  // ============================================================ S5-44 : accompagnement des projets
  await as(U(1));
  const PSUP = (await qa(`select id from projects where owner_id = '${U(1)}' and department = 'Informatique' limit 1`))[0].id;
  await fails('S5-44 : message trop court refusé', `select support_request_create('${PSUP}', 'mentor', 'aide')`, /10 à 1000/);
  await fails('S5-44 : type inconnu refusé', `select support_request_create('${PSUP}', 'magie', 'Je cherche un mentor en agritech')`, /inconnu/);
  const SR = (await q(`select support_request_create('${PSUP}', 'mentor', 'Je cherche un mentor en agritech pour valider mon prototype') id`))[0].id;
  await fails('S5-44 : une demande du même type déjà en cours est refusée', `select support_request_create('${PSUP}', 'mentor', 'Je cherche un mentor en agritech pour valider mon prototype')`, /déjà en cours/);
  check('S5-44 : les responsables du département sont prévenus (pas ceux des autres départements)', (await notifs(U(10), 'project', 'Demande d%accompagnement')).length === 1 && (await notifs(U(14), 'project', 'Demande d%accompagnement')).length === 0);
  await as(U(2));
  await fails('S5-44 : on ne demande pas pour le projet d\'un autre', `select support_request_create('${PSUP}', 'skills', 'Je voudrais de l''aide pour ce projet')`, /introuvable/);
  await as(U(1));
  check('my_support_requests : le porteur suit sa demande', (await q(`select my_support_requests() r`))[0].r[0].status === 'open');
  await as(U(14));
  check('support_requests_to_handle : un autre département ne voit pas la demande', (await q(`select jsonb_array_length(support_requests_to_handle()) n`))[0].n === 0);
  await fails('support_request_handle : un autre département ne traite pas', `select support_request_handle('${SR}', 'done', 'Réponse du département')`, /introuvable|autre département/);
  await as(U(1));
  await fails('support_request_handle : un étudiant ne traite pas', `select support_request_handle('${SR}', 'done', 'Réponse du département')`, /Réservé/);
  await as(U(10));
  check('support_requests_to_handle : le département voit la demande', (await q(`select jsonb_array_length(support_requests_to_handle()) n`))[0].n === 1);
  await fails('support_request_handle : réponse obligatoire pour clore', `select support_request_handle('${SR}', 'done', '')`, /Rédigez/);
  await q(`select support_request_handle('${SR}', 'in_progress', '')`);
  await q(`select support_request_handle('${SR}', 'done', 'Un mentor vous contactera cette semaine.')`);
  await as(U(1));
  const sr = (await q(`select my_support_requests() r`))[0].r[0];
  check('S5-44 : le porteur lit la réponse et est prévenu', sr.status === 'done' && /mentor/.test(sr.response) && (await notifs(U(1), 'project', 'Accompagnement : réponse')).length === 1, JSON.stringify(sr));

  // ===== SECTIONS SUIVANTES =====

  console.log(`\n${ok}/${ok + ko}`);
  if (ko) process.exitCode = 1;
}
