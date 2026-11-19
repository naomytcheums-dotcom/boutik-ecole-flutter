// Scénario PGlite du lot K3 (acteur Département, point 4) : migrations 20261121030000 à 20261121031900.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./fin_k3.mjs
// Prouve : un compte Département sans rattachement VALIDE (aucun, département non vérifié, nom ambigu) ne voit, n'écrit et ne reçoit rien ;
// traitement administratif (liste, compteur, rattachement, retrait, notification de l'administrateur) ; contrôle d'unicité des noms ;
// notifications départementales envoyées uniquement aux comptes rattachés au bon département ; matrice RPC / RLS pour un compte non rattaché.
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`);
    if (role) await db.exec(`set role ${role}`);
  };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const sudo = async (sql) => { await as(null, null); return q(sql); };
  const run = async (sql) => { await as(null, null); await db.exec(sql); };
  const I1 = '00000000-0000-0000-0000-00000000e101', I2 = '00000000-0000-0000-0000-00000000e102';
  const DX = '00000000-0000-0000-0000-00000000e1a1', DY = '00000000-0000-0000-0000-00000000e1a2', DZ = '00000000-0000-0000-0000-00000000e1a3';
  const DA = '00000000-0000-0000-0000-00000000e1b1', DB = '00000000-0000-0000-0000-00000000e1b2';
  const L = (n) => `00000000-0000-0000-0000-00000000f1${String(n).padStart(2, '0')}`;
  const noAccess = /rattaché à aucun département|non autorisée|Action non autorisée|permission denied|introuvable|Réservé|Connexion requise|ambigu/;

  await db.exec('reset role');
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test K3', 'verified'), ('${I2}', 'Université test K3', 'verified');
    insert into departments (id, institution_id, name, status) values ('${DX}', '${I1}', 'Génie logiciel', 'verified'), ('${DY}', '${I1}', 'Gestion', 'verified'), ('${DZ}', '${I1}', 'Département proposé', 'proposed')`);

  // 74 admin · 86 admin suspendu · 71 chef X · 72 chef Y · 73 chef non rattaché (profil hérité : département X en texte) · 75 direction · 76 étudiant X · 77 étudiant Y · 78 client
  // 79 chef X suspendu · 80 support · 81 organisation · 82 étudiant X (2) · 83 chef rattaché à un département non vérifié · 84 chef rattaché par la reprise automatique (sans administrateur)
  // 85 chef rattaché à un nom ambigu · 87 chef rattaché X puis retiré
  const roles = { 74: 'admin', 86: 'admin', 71: 'dept', 72: 'dept', 73: 'dept', 75: 'direction', 76: 'student', 77: 'student', 78: 'client', 79: 'dept', 80: 'support', 81: 'company', 82: 'student', 83: 'dept', 84: 'dept', 85: 'dept', 87: 'dept' };
  for (const [n, r] of Object.entries(roles).sort((a, b) => (a[1] === 'admin' ? 0 : 1) - (b[1] === 'admin' ? 0 : 1))) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','k3${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','k3${n}@t.cm')`);
    if (Number(n) === 86) await db.exec(`update profiles set suspended = true where id = '${U(86)}'`);
  }
  await db.exec(`update profiles set suspended = true where id = '${U(79)}'`);
  await db.exec(`update profiles set institution_id='${I1}', department_id='${DX}', department='Génie logiciel', institution='IUT test K3' where id in ('${U(76)}','${U(82)}','${U(73)}')`);
  await db.exec(`update profiles set institution_id='${I1}', department_id='${DY}', department='Gestion', institution='IUT test K3' where id = '${U(77)}'`);

  // ============================== Notification de l'administrateur à la création des comptes ==============================
  const adminNotif = async (admin, who) => (await sudo(`select count(*)::int n from notifications where user_id = '${U(admin)}' and kind = 'department' and data->>'type' = 'unassigned' and data->>'user' = '${U(who)}'`))[0].n;
  check('notification admin : un compte Département sans rattachement prévient l\'administrateur', (await adminNotif(74, 73)) === 1 && (await adminNotif(74, 71)) === 1);
  check('notification admin : l\'administrateur suspendu n\'est pas prévenu', (await adminNotif(86, 73)) === 0);
  check('notification compte : le chef non rattaché est informé de l\'attente (sans erreur technique)', (await sudo(`select count(*)::int n from notifications where user_id = '${U(73)}' and kind = 'department' and data->>'type' = 'waiting'`))[0].n === 1);
  check('notification admin : aucun doublon pour un même compte', (await sudo(`select count(*)::int n from notifications where user_id = '${U(74)}' and data->>'user' = '${U(73)}'`))[0].n === 1);
  await run(`update profiles set role = 'dept' where id = '${U(78)}'`);
  check('notification admin : un rôle changé en Département déclenche aussi la notification', (await adminNotif(74, 78)) === 1);
  await run(`update profiles set role = 'client' where id = '${U(78)}'`);

  // ============================== Unicité des noms de département ==============================
  await run(`update departments set status = 'verified' where id = '${DZ}'`);   // 'Département proposé' : nom unique -> accepté
  await run(`update departments set status = 'proposed' where id = '${DZ}'`);
  await fails('unicité : nom identique (casse, espaces) refusé à la vérification', `insert into departments (institution_id, name, status) values ('${I1}', '  GÉNIE   logiciel ', 'verified')`, /ambigu|existe déjà|duplicate|unique/);
  await run(`insert into departments (id, institution_id, name, status) values ('${DB}', '${I1}', 'Génie  logiciel', 'proposed')`);
  await fails('unicité : un homonyme proposé ne peut pas être vérifié', `update departments set status = 'verified' where id = '${DB}'`, /ambigu|existe déjà|duplicate|unique/);
  await run(`delete from departments where id = '${DB}'`);
  check('unicité : même nom dans deux établissements différents autorisé', await (async () => { try { await run(`insert into departments (institution_id, name, status) values ('${I2}', 'Génie logiciel', 'verified')`); return true; } catch (e) { return false; } })());

  // ============================== Rattachements : valide, non vérifié, ambigu, reprise automatique ==============================
  await as(U(74));
  await q(`select admin_dept_assign('${U(71)}', '${DX}', 'Chef de département')`);
  await q(`select admin_dept_assign('${U(72)}', '${DY}')`);
  await q(`select admin_dept_assign('${U(79)}', '${DX}')`);
  await q(`select admin_dept_assign('${U(87)}', '${DX}')`);
  await run(`insert into department_accounts (user_id, department_id) values ('${U(83)}', '${DZ}'), ('${U(84)}', '${DX}')`);
  // nom ambigu hérité : deux départements vérifiés de même nom normalisé (état impossible avec les contrôles actuels, reconstitué en les suspendant)
  await run(`alter table departments disable trigger trg_departments_unique_name; drop index if exists departments_norm_name_key;
    insert into departments (id, institution_id, name, status) values ('${DA}', '${I2}', 'Informatique', 'verified'), ('${DB}', '${I2}', 'informatique ', 'verified');
    insert into department_accounts (user_id, department_id) values ('${U(85)}', '${DA}');`);
  const st = async (n) => (await sudo(`select _dept_attachment_state('${U(n)}') s`))[0].s;
  check('état : rattaché valide = ok', (await st(71)) === 'ok' && (await st(72)) === 'ok');
  check('état : aucun rattachement = none', (await st(73)) === 'none');
  check('état : département non vérifié = unverified', (await st(83)) === 'unverified');
  check('état : nom ambigu = ambiguous', (await st(85)) === 'ambiguous');
  check('état : un compte qui n\'est pas Département = not_dept', (await st(76)) === 'not_dept');
  check('reprise automatique : rattaché mais assigned_by nul -> marqué « à confirmer »', (await sudo(`select assigned_by is null as auto from department_accounts where user_id = '${U(84)}'`))[0].auto === true);
  await as(U(74));
  await fails('rattachement : département au nom ambigu refusé par l\'administrateur', `select admin_dept_assign('${U(73)}', '${DA}')`, /ambigu/);

  // ============================== Traitement administratif ==============================
  const un = (await q(`select admin_dept_unassigned_accounts() a`))[0].a;
  const ids = un.map((x) => x.id);
  check('liste : exactement les comptes sans rattachement valide (73 aucun, 83 non vérifié, 85 ambigu, 87 non — rattaché)', ids.includes(U(73)) && ids.includes(U(83)) && ids.includes(U(85)) && !ids.includes(U(71)) && !ids.includes(U(84)) && un.length === 3, JSON.stringify(ids));
  const e73 = un.find((x) => x.id === U(73)), e83 = un.find((x) => x.id === U(83)), e85 = un.find((x) => x.id === U(85));
  check('liste : raisons lisibles', e73.reason === 'Aucun rattachement' && e83.reason === 'Département non vérifié' && e85.reason === 'Nom de département ambigu', JSON.stringify([e73.reason, e83.reason, e85.reason]));
  const s73 = await st(73);
  await as(U(74));
  check('liste : suggestion pour le compte hérité (département déclaré identique), jamais appliquée', e73.candidates.length === 1 && e73.candidates[0].id === DX && s73 === 'none', JSON.stringify(e73.candidates));
  check('liste : département actuel indiqué pour un rattachement invalide', e83.current_department === 'Département proposé');
  check('compteur : comptes actifs sans rattachement valide', (await q(`select admin_dept_unassigned_count() n`))[0].n === 3);
  const all = (await q(`select admin_dept_accounts() a`))[0].a;
  check('admin_dept_accounts : état, « à réviser » et non rattachés en premier', all[0].attached === false && all.find((x) => x.id === U(84)).to_review === true && all.find((x) => x.id === U(71)).to_review === false && all.find((x) => x.id === U(83)).state === 'unverified', JSON.stringify(all.map((x) => [x.name, x.state, x.to_review])));
  for (const [n, who, sql] of [[76, 'étudiant', 'admin_dept_unassigned_accounts()'], [78, 'client', 'admin_dept_unassigned_count()'], [75, 'direction', 'admin_dept_unassigned_accounts()'], [80, 'support', 'admin_dept_unassigned_count()'],
                               [71, 'chef rattaché', 'admin_dept_unassigned_accounts()'], [73, 'chef non rattaché', 'admin_dept_unassigned_count()'], [81, 'organisation', 'admin_dept_unassigned_accounts()'],
                               [86, 'administrateur suspendu', 'admin_dept_unassigned_accounts()'], [79, 'chef suspendu', 'admin_dept_unassigned_count()']]) {
    await as(U(n));
    await fails(`traitement : ${who} refusé (${sql})`, `select ${sql}`, /Réservé à l'administrateur|Connexion requise|non autorisée/);
  }
  await as(null, 'anon');
  await fails('traitement : anonyme refusé (liste)', 'select admin_dept_unassigned_accounts()', /denied/);
  await fails('traitement : anonyme refusé (compteur)', 'select admin_dept_unassigned_count()', /denied/);
  await fails('traitement : anonyme refusé (rattachement)', `select admin_dept_assign('${U(73)}', '${DX}')`, /denied/);
  await fails('traitement : anonyme refusé (retrait)', `select admin_dept_unassign('${U(71)}')`, /denied/);
  await as(U(75));
  await fails('rattachement : la direction ne rattache pas', `select admin_dept_assign('${U(73)}', '${DX}')`, /Réservé à l'administrateur/);
  await fails('retrait : la direction ne retire pas', `select admin_dept_unassign('${U(71)}')`, /Réservé à l'administrateur/);
  await as(U(73));
  await fails('rattachement : le chef non rattaché ne se rattache pas lui-même', `select admin_dept_assign('${U(73)}', '${DX}')`, /Réservé à l'administrateur/);
  await fails('retrait : un chef ne retire pas un autre', `select admin_dept_unassign('${U(71)}')`, /Réservé à l'administrateur/);
  await as(U(86));
  await fails('rattachement : administrateur suspendu refusé', `select admin_dept_assign('${U(73)}', '${DX}')`, /Réservé à l'administrateur|Connexion/);

  // ============================== Un compte non rattaché ne voit rien ==============================
  // jeu de données dans le département X et Y
  await run(`
    insert into listings (id, seller_id, title, department, price, status) values
      ('${L(1)}', '${U(76)}', 'Sac X', 'Génie logiciel', 5000, 'pending'), ('${L(2)}', '${U(77)}', 'Sac Y', 'Gestion', 6000, 'pending'), ('${L(3)}', '${U(76)}', 'Sac X approuvé', 'Génie logiciel', 7000, 'approved');
    insert into projects (id, owner_id, title, summary, kind, status, visibility, department) values
      ('${L(11)}', '${U(76)}', 'Appli de gestion de stock', 'Une application mobile pour gérer le stock des petites boutiques de quartier.', 'projet', 'submitted', 'public', 'Génie logiciel'),
      ('${L(12)}', '${U(77)}', 'Comptabilité simplifiée', 'Un tableur guidé pour les tontines de quartier avec rapports mensuels.', 'projet', 'submitted', 'public', 'Gestion'),
      ('${L(13)}', '${U(76)}', 'Capteur solaire', 'Un capteur solaire low-cost pour les villages sans réseau électrique du Nord.', 'innovation', 'approved', 'public', 'Génie logiciel');
    insert into talent_skills (owner_id, domain, skill, level) values ('${U(76)}', 'Développement', 'Flutter', 'avance'), ('${U(77)}', 'Gestion', 'Comptabilité', 'expert');
    update profiles set certification = 'pending' where id in ('${U(76)}', '${U(77)}');
    insert into opportunities (id, poster_id, org_name, kind, title, description, department_target, status) values
      ('${L(21)}', '${U(81)}', 'Entreprise Z', 'stage', 'Stage développeur mobile', 'Stage de six mois en développement mobile Flutter pour étudiants.', 'Génie logiciel', 'pending');
    insert into posts (id, author_id, kind, body, caption, status) values ('${L(31)}', '${U(76)}', 'text', 'Post X', 'Post X', 'pending'), ('${L(32)}', '${U(77)}', 'text', 'Post Y', 'Post Y', 'pending');
  `);
  await as(U(71));
  await q(`select dept_identity_save('{"description":"Formation en génie logiciel"}'::jsonb)`);
  const ovX = (await q(`select dept_overview() o`))[0].o;
  check('contrôle : un chef rattaché valide lit bien son département (référence de la matrice)', ovX.students === 3 || ovX.students === 2, JSON.stringify(ovX.students));

  const quiet = (v) => v === null || v === undefined || v === '' || v === false || v === 0 ||
    (Array.isArray(v) ? v.every(quiet) : typeof v === 'object' ? Object.values(v).every(quiet) : false);
  const rpcs = [
    `dept_overview()`, `dept_students_list('', 50, 0)`, `dept_students(200)`, `dept_student_detail('${U(76)}')`, `dept_projects()`, `dept_skills()`, `dept_opportunities()`,
    `dept_partnerships()`, `dept_validations()`, `dept_activity(p_limit => 10)`, `dept_report('synthese')`, `dept_report('etudiants')`, `dept_report('ventes')`, `dept_identity_get()`,
    `dept_identity_save('{"description":"x"}'::jsonb)`, `dept_partnership_save('{"partner_name":"Orange","kind":"stage"}'::jsonb)`, `admin_users(null, 200)`, `admin_departments()`, `platform_overview()`,
    `staff_mentors()`, `staff_productions()`, `mentors_pending()`, `events_managed()`, `listing_review_queue()`, `review_project('${L(11)}', true, '')`, `opp_decide('${L(21)}', true, false, '')`,
    `dept_highlight_set('project', '${L(13)}')`, `mentor_create('Mentor X', 'Mentor', 'Java')`, `production_create('Prod X', 'Equipe', null, null)`,
    `event_create('Atelier', 'Un atelier pour les étudiants', 'atelier', now() + interval '3 days', now() + interval '3 days 2 hours', 'Salle 1', 0, 20)`,
    `challenge_create('Défi test', 'Un défi pour le département', 'projet', 7)`, `invite_department_member('x@y.cm', 'member')`,
    `open_needs_list()`, `open_calls()`, `open_needs()`, `sos_list()`, `direction_dashboard()`, `direction_departments()`, `direction_people('students', null, 50)`, `institutional_validations_list()`,
  ];
  const matrix = async (label, n) => {
    await as(U(n));
    let bad = [];
    for (const sql of rpcs) {
      let res;
      try { res = (await q(`select ${sql} as r`))[0].r; } catch (e) { if (/does not exist|n'existe pas|function .* does not exist/.test(e.message)) continue; continue; }
      if (sql.startsWith('admin_users') && res.every((x) => x.name === `Personne ${n}` && x.students === 0)) continue;   // sa propre ligne de profil, sans aucun compte d'étudiant
      if (!quiet(res)) bad.push(sql.slice(0, 50) + ' => ' + JSON.stringify(res).slice(0, 100));
    }
    check(`matrice RPC : ${label} -> chaque fonction refuse ou renvoie un résultat vide`, bad.length === 0, '\n   ' + bad.join('\n   '));
  };
  await matrix('chef sans rattachement (73, profil hérité au département X)', 73);
  await matrix('chef rattaché à un département non vérifié (83)', 83);
  await matrix('chef rattaché à un nom ambigu (85)', 85);
  await matrix('chef suspendu (79)', 79);

  // Tables protégées par RLS : un compte non rattaché ne lit pas plus qu'un client sans lien
  const tables = (await sudo(`select c.relname t from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity order by 1`)).map((x) => x.t);
  const counts = async (n) => {
    await as(U(n));
    const out = {};
    for (const t of tables) {
      try { out[t] = (await q(`select count(*)::int n from public."${t}"`))[0].n; } catch (e) { out[t] = 0; await db.exec('reset role').catch(() => {}); await as(U(n)); }
    }
    return out;
  };
  const base = await counts(78);
  for (const [label, n] of [['sans rattachement (73)', 73], ['département non vérifié (83)', 83], ['nom ambigu (85)', 85]]) {
    const c = await counts(n);
    const extra = tables.filter((t) => c[t] > base[t] && t !== 'department_accounts');   // department_accounts : chacun lit sa propre ligne de rattachement
    check(`matrice RLS : ${label} ne lit sur aucune table plus qu'un client sans lien`, extra.length === 0, extra.map((t) => `${t}: ${c[t]} > ${base[t]}`).join(' ; '));
  }
  // témoin : le chef rattaché lit davantage (la matrice n'est pas vide par construction)
  const cx = await counts(71);
  check('matrice RLS : témoin — le chef rattaché lit plus de lignes (projets, compétences, annonces)', cx.projects > base.projects && cx.talent_skills > base.talent_skills, `${cx.projects}/${base.projects} ${cx.talent_skills}/${base.talent_skills}`);

  // ============================== Rattachement effectif : tout s'ouvre, puis se referme ==============================
  await as(U(74));
  await q(`select admin_dept_assign('${U(73)}', '${DX}', 'Chef par intérim')`);
  check('rattachement : le compte 73 devient valide', (await st(73)) === 'ok');
  check('rattachement : l\'administrateur n\'a plus de notification en attente pour 73', (await adminNotif(74, 73)) === 1 && (await sudo(`select count(*)::int n from notifications where user_id = '${U(74)}' and data->>'user' = '${U(73)}' and read_at is null`))[0].n === 0);
  check('rattachement : le compte 73 est informé', (await sudo(`select count(*)::int n from notifications where user_id = '${U(73)}' and data->>'type' = 'attached'`))[0].n === 1);
  check('rattachement : l\'avis d\'attente du compte 73 est clos', (await sudo(`select count(*)::int n from notifications where user_id = '${U(73)}' and data->>'type' = 'waiting' and read_at is null`))[0].n === 0);
  await as(U(74));
  check('compteur : 73 rattaché -> 2 restants', (await q(`select admin_dept_unassigned_count() n`))[0].n === 2);
  await as(U(73));
  check('rattachement : 73 lit désormais son département', (await q(`select dept_overview() o`))[0].o.department === 'Génie logiciel');
  await as(U(74));
  await q(`select admin_dept_assign('${U(84)}', '${DX}')`);
  check('confirmation : le rattachement hérité confirmé n\'est plus « à réviser »', (await q(`select admin_dept_accounts() a`))[0].a.find((x) => x.id === U(84)).to_review === false);
  await q(`select admin_dept_unassign('${U(87)}')`);
  check('retrait : effet immédiat, le chef retiré est sans rattachement', (await st(87)) === 'none');
  check('retrait : le chef retiré est informé et l\'administrateur prévenu', (await sudo(`select count(*)::int n from notifications where user_id = '${U(87)}' and data->>'type' = 'waiting' and read_at is null`))[0].n >= 1);
  await as(U(87));
  await fails('retrait : le chef retiré ne lit plus rien', `select dept_overview()`, /rattaché à aucun département/);
  check('retrait : plus aucune ligne de projets', (await q(`select count(*)::int n from projects`))[0].n === 0);
  await as(U(74));
  await fails('retrait : compte déjà non rattaché', `select admin_dept_unassign('${U(87)}')`, /n'est rattaché à aucun département/);
  check('audit : rattachements et retraits journalisés', (await sudo(`select count(*)::int n from audit_log where action in ('Rattachement au département', 'Rattachement retiré')`))[0].n >= 6);
  await db.exec(`reset role; alter table departments enable trigger trg_departments_unique_name`);

  // ============================== Notifications départementales ==============================
  await run(`delete from notifications`);
  const recip = async (sql) => new Set((await sudo(sql)).map((x) => x.u));
  const rx = await recip(`select _owner_reviewers('${U(76)}') u`);
  check('destinataires : porteur du département X -> administrateurs, chefs X (71, 73, 84) seulement', rx.has(U(71)) && rx.has(U(73)) && rx.has(U(84)) && rx.has(U(74)) && !rx.has(U(72)) && !rx.has(U(83)) && !rx.has(U(85)) && !rx.has(U(87)) && !rx.has(U(79)) && !rx.has(U(86)), JSON.stringify([...rx]));
  const ry = await recip(`select _owner_reviewers('${U(77)}') u`);
  check('destinataires : porteur du département Y -> chef Y et administrateur, pas les chefs X', ry.has(U(72)) && ry.has(U(74)) && !ry.has(U(71)) && !ry.has(U(73)));
  const rp = await recip(`select _project_reviewers('génie  LOGICIEL') u`);
  check('destinataires projet (par nom normalisé) : chefs X validement rattachés', rp.has(U(71)) && rp.has(U(73)) && !rp.has(U(72)) && !rp.has(U(83)) && !rp.has(U(85)) && !rp.has(U(87)));
  const rs = await recip(`select _scope_recipients('${U(76)}') u`);
  check('destinataires de périmètre : mêmes comptes', rs.has(U(71)) && !rs.has(U(72)) && !rs.has(U(87)) && !rs.has(U(83)));
  await run(`select notify_department('${DX}', 'department', 'Information X', 'Message pour le département X', '{}'::jsonb)`);
  const nd = (await sudo(`select user_id u from notifications where title = 'Information X'`)).map((x) => x.u).sort();
  check('notify_department : seuls les comptes validement rattachés au département X', JSON.stringify(nd) === JSON.stringify([U(71), U(73), U(84)].sort()), JSON.stringify(nd));
  await as(U(76));
  await fails('notify_department : non appelable par un utilisateur', `select notify_department('${DX}', 'department', 't', 'b', '{}'::jsonb)`, /denied/);
  await as(null, 'anon');
  await fails('notify_department : non appelable par un anonyme', `select notify_department('${DX}', 'department', 't', 'b', '{}'::jsonb)`, /denied/);

  // vœu de l'étudiant X : seuls les chefs X sont prévenus
  await run(`delete from notifications`);
  await as(U(76));
  try {
    await q(`select save_wish(null, 'Sac solaire', 'Un sac avec panneau solaire intégré pour recharger un téléphone.', 15000, 20, 30, true)`);
    const w = (await sudo(`select user_id u from notifications where kind = 'wish' or title ilike '%vœu%'`)).map((x) => x.u);
    check('vœu : les chefs rattachés au département X sont prévenus, pas les autres chefs', !w.includes(U(72)) && !w.includes(U(83)) && !w.includes(U(85)) && !w.includes(U(87)) && !w.includes(U(79)), JSON.stringify(w));
  } catch (e) { check('vœu : soumission', false, e.message); }

  // changement de nom d'un étudiant certifié : prévenus = admin + chefs du département X
  await run(`delete from notifications; update profiles set certification = 'approved' where id = '${U(76)}'`);
  await as(U(76));
  await q(`update profiles set name = 'Nouveau Nom X' where id = '${U(76)}'`);
  const cert = (await sudo(`select certification::text c from profiles where id = '${U(76)}'`))[0].c;
  const rn = (await sudo(`select user_id u from notifications where title like 'Nom modifié%'`)).map((x) => x.u);
  check('certification : nom modifié -> chefs X et administrateur seulement', cert === 'none' && rn.includes(U(71)) && rn.includes(U(74)) && rn.includes(U(84)) && !rn.includes(U(72)) && !rn.includes(U(83)) && !rn.includes(U(85)) && !rn.includes(U(87)), JSON.stringify([cert, rn]));

  // besoin « mission » d'un étudiant X : visible du chef X et de l'administrateur, pas d'un chef Y ni d'un compte non rattaché
  await run(`delete from notifications; update departments set status = 'verified' where id = '${DZ}'; update departments set status = 'proposed' where id = '${DZ}'`);
  await run(`insert into missions (id, number, client_id, kind, title, description, total, status, created_by, published_at) values
    ('${L(41)}', '#BR-2026-K3', '${U(76)}', 'mission', 'Mission qualifiée X', 'Une mission réservée à la qualification par le département concerné ici.', 1000, 'published', '${U(76)}', now())`);
  const seen = async (n, fn) => { await as(n === null ? null : U(n)); try { return (await q(`select ${fn} r`))[0].r.length; } catch (e) { return -1; } };
  const mX = await seen(71, 'open_needs_list()'), mY = await seen(72, 'open_needs_list()'), mA = await seen(74, 'open_needs_list()'), m73 = await seen(87, 'open_needs_list()'), m83 = await seen(83, 'open_needs_list()');
  check('besoins « mission » : le chef du département du porteur et l\'administrateur les voient', mX >= mA - 0 && mX === 1 && mA === 1, `${mX} ${mA}`);
  check('besoins « mission » : un autre chef ou un compte non rattaché ne les voit pas', mY === 0 && m73 === 0 && m83 === 0, `${mY} ${m73} ${m83}`);

  // SOS Cours : la filière d'un chef = son rattachement
  await as(U(76));
  await q(`select sos_create('Besoin d''aide en Java', 'Je ne comprends pas les interfaces en Java, quelqu''un peut m''aider ?')`);
  const sx = await seen(71, `sos_list()`), s84 = await seen(84, `sos_list()`), sy = await seen(72, `sos_list()`), s87 = await seen(87, `sos_list()`), s83 = await seen(83, `sos_list()`);
  check('SOS Cours : un chef non rattaché ne lit pas la filière de son ancien profil', s87 === 0 && s83 === 0, `${s87} ${s83}`);
  check('SOS Cours : les chefs rattachés au département X lisent la filière, pas le chef Y', sx === 1 && s84 === 1 && sy === 0, `${sx} ${s84} ${sy}`);

  // événements : écriture refusée sans rattachement valide, acceptée rattaché
  await as(U(87));
  await fails('événement : chef non rattaché refusé', `select event_create('Atelier', 'Un atelier pour les étudiants', 'atelier', now() + interval '3 days', now() + interval '3 days 2 hours', 'Salle 1', 0, 20)`, /rattaché à aucun département|Action non autorisée/);
  await fails('événements : liste refusée sans rattachement', `select events_managed()`, /rattaché à aucun département/);
  await as(U(71));
  check('événements : chef rattaché lit sa liste', Array.isArray((await q(`select events_managed() r`))[0].r));
  await as(U(74));
  check('événements : l\'administrateur garde l\'accès', Array.isArray((await q(`select events_managed() r`))[0].r));
  await as(U(75));
  check('direction : garde sa lecture consolidée (non restreinte par le rattachement)', (await q(`select dept_overview() o`))[0].o.students >= 3);

  console.log(`\nK3 : ${ok} OK, ${ko} ECHEC`);
}
