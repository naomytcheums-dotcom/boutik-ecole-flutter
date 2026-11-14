// Scénario PGlite de la migration 20261114004200 (suite des correctifs du profil Visiteur).
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./correctifs_visiteur_suite.mjs
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
  const roles = { 11: 'student', 12: 'student', 13: 'client', 14: 'dept', 15: 'student', 16: 'admin' };
  const names = { 11: 'Awa Tchoua', 12: 'Awa Tchoua', 13: 'Client Lambda', 14: 'Chef Dept', 15: 'Brice Ndoumbe', 16: 'Admin Global' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${names[n]}','${r}','u${n}@t.cm')`);
  }

  // 1. comptes suspendus
  await db.exec(`insert into posts (id, author_id, media_path, media_kind, status) values ('00000000-0000-0000-0000-0000000000b1', '${U(15)}', '${U(15)}/a.jpg', 'image', 'published')`);
  await as(U(13));
  check('compte actif : peut aimer une publication', (await q(`select toggle_post_like('00000000-0000-0000-0000-0000000000b1') r`)).length === 1);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id in ('${U(13)}', '${U(14)}', '${U(11)}')`);
  check('current_role_name : nul pour un compte suspendu', (await (async () => { await as(U(14)); return (await q(`select current_role_name() r`))[0].r; })()) === null);
  await fails('compte suspendu : ne publie pas (message exact)', `select create_post_v2('texte', '[]'::jsonb, null, '{}', null, null)`, /Compte suspendu : publication impossible/);
  await as(U(11));
  await fails('compte suspendu : pas d\'histoire (message exact)', `select create_story('${U(11)}/s.jpg', 'image', 'x')`, /Compte suspendu : publication des histoires impossible/);
  await db.exec('reset role');
  await db.exec(`insert into posts (id, author_id, media_path, media_kind, status) values ('00000000-0000-0000-0000-0000000000b2', '${U(15)}', '${U(15)}/b.jpg', 'image', 'published')`);
  await as(U(13));
  await fails('compte suspendu : pas de mention j\'aime (écriture sans rôle bloquée)', `select toggle_post_like('00000000-0000-0000-0000-0000000000b2')`, /Compte suspendu/);
  await fails('compte suspendu : pas de commentaire', `select add_post_comment_v2('00000000-0000-0000-0000-0000000000b1', 'bonjour', null, null)`, /Compte suspendu/);
  await as(U(14));
  await fails('responsable suspendu : perd ses droits de département (jeton encore valide)', `select review_project('00000000-0000-0000-0000-0000000000a1', true, null)`, /Réservé au département|Aucun projet/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id in ('${U(13)}', '${U(14)}', '${U(11)}')`);
  await as(U(14));
  check('responsable réactivé : rôle de nouveau reconnu', (await q(`select current_role_name()::text r`))[0].r === 'dept');

  // 2. rappels : la lecture n'écrit plus, la tâche planifiée envoie
  await db.exec('reset role');
  await db.exec(`insert into contest_announcements (id, poster_id, title, organizer, kind, status, official_url, deadline) values
    ('00000000-0000-0000-0000-0000000000f1', '${U(16)}', 'Concours rappel', 'Organisateur', 'contest', 'published', 'https://exemple.cm', current_date + 1)`);
  await db.exec(`insert into contest_ann_reminders (announcement_id, user_id) values ('00000000-0000-0000-0000-0000000000f1', '${U(13)}')`);
  await as(U(13));
  await q(`select anns_list() r`);
  await db.exec('reset role');
  check('anns_list : aucune notification créée par la lecture', (await q(`select 1 from notifications where kind = 'contest_reminder'`)).length === 0);
  check('send_due_reminders : envoie le rappel', (await q(`select send_due_reminders() n`))[0].n === 1);
  check('send_due_reminders : une seule fois', (await q(`select send_due_reminders() n`))[0].n === 0);
  check('rappel reçu par la bonne personne', (await q(`select user_id from notifications where kind = 'contest_reminder'`))[0].user_id === U(13));
  await as(U(13));
  await fails('send_due_reminders : non appelable par un utilisateur', `select send_due_reminders()`, /permission denied/);
  await as(null, 'anon');
  check('opps_list : lisible par un visiteur', Array.isArray((await q(`select opps_list() r`))[0].r));

  // 3. vendeurs : homonymes signalés, profil par identifiant, noms abrégés
  await db.exec('reset role');
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values
    ('00000000-0000-0000-0000-0000000000e1', '${U(11)}', 'Lampe Awa un', 'Genie', 5000, 'approved'),
    ('00000000-0000-0000-0000-0000000000e2', '${U(12)}', 'Lampe Awa deux', 'Genie', 6000, 'approved'),
    ('00000000-0000-0000-0000-0000000000e3', '${U(15)}', 'Sac Brice', 'Design', 7000, 'approved')`);
  await as(null, 'anon');
  const amb = (await q(`select seller_public('Awa Tchoua') r`))[0].r;
  check('seller_public : deux homonymes ne sont plus confondus', amb.found === false && amb.ambiguous === true, JSON.stringify(amb));
  const byId = (await q(`select seller_public(null, '${U(12)}') r`))[0].r;
  check('seller_public : profil par identifiant', byId.found === true && byId.id === U(12) && byId.products === 1, JSON.stringify(byId));
  const uniq = (await q(`select seller_public('Brice Ndoumbe') r`))[0].r;
  check('seller_public : un nom unique reste résolu', uniq.found === true && uniq.id === U(15));
  const sellers = (await q(`select public_sellers(array['${U(11)}', '${U(15)}', '${U(13)}']::uuid[]) r`))[0].r;
  check('public_sellers : noms abrégés des vendeurs d\'annonces seulement', sellers[U(15)] === 'Brice N.' && sellers[U(11)] === 'Awa T.' && !(U(13) in sellers), JSON.stringify(sellers));
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${U(15)}'`);
  await as(null, 'anon');
  check('seller_public : un vendeur suspendu n\'est plus public', (await q(`select seller_public(null, '${U(15)}') r`))[0].r.found === false);
  check('public_sellers : un vendeur suspendu est exclu', !(U(15) in (await q(`select public_sellers(array['${U(15)}']::uuid[]) r`))[0].r));

  // 4. projets publics sans coordonnées
  await db.exec('reset role');
  await db.exec(`insert into projects (id, owner_id, kind, title, summary, status, visibility, details) values
    ('00000000-0000-0000-0000-0000000000a1', '${U(12)}', 'projet', 'Projet public', 'x', 'approved', 'public', '{"problem":"p","contact_email":"a@b.cm","contact_phone":"690000000"}'),
    ('00000000-0000-0000-0000-0000000000a2', '${U(12)}', 'projet', 'Projet prive', 'x', 'approved', 'private', '{}'),
    ('00000000-0000-0000-0000-0000000000a3', '${U(12)}', 'innovation', 'Brouillon', 'x', 'draft', 'public', '{}')`);
  await as(null, 'anon');
  const pp = (await q(`select public_projects() r`))[0].r;
  check('public_projects : seul le projet validé et public est servi', pp.length === 1 && pp[0].title === 'Projet public');
  check('public_projects : coordonnées de contact retirées', pp[0].details.contact_email === undefined && pp[0].details.contact_phone === undefined && pp[0].details.problem === 'p');
  check('public_projects : filtre par type', (await q(`select public_projects('innovation') r`))[0].r.length === 0);

  // 5. alerte de filière et collections
  await as(U(11));
  await q(`select opp_alert_set('Génie', true)`);
  check('opp_alert_set : alerte activée', (await q(`select opp_my_alert() r`))[0].r === true);
  await q(`select opp_alert_set('', false)`);
  check('opp_alert_set : désactivation sans filière', (await q(`select opp_my_alert() r`))[0].r === false);
  const cid = (await q(`select collection_save(null, 'Mes envies', 'private') id`))[0].id;
  await q(`select collection_item_toggle('${cid}', 'Lampe Awa un')`);
  await db.exec('reset role');
  await db.exec(`update listings set title = 'Lampe Awa renommée' where id = '00000000-0000-0000-0000-0000000000e1'`);
  check('collections : le titre du produit suit son annonce', (await q(`select 1 from user_collection_items where collection_id = '${cid}' and title = 'Lampe Awa renommée'`)).length === 1);

  console.log(`\n${ok}/${ok + ko}`);
}
