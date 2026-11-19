// Scénario PGlite du lot H2 (acteur Département) : migrations 20261120020000 à 20261120020400.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./act_h2.mjs
// Prouve, pour chaque acteur concerné (département rattaché, département non rattaché, autre département, direction, administrateur, étudiant, client, compte suspendu, anonyme) :
// rattachement compte <-> département, identité éditable, suivi cloisonné (étudiants, projets, innovations, compétences, opportunités, partenariats, validations),
// statistiques, rapports exportables, et le cloisonnement des RPC / politiques RLS qui donnaient autrefois tous les départements au rôle dept.
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
  const I1 = '00000000-0000-0000-0000-00000000c101', DX = '00000000-0000-0000-0000-00000000c1a1', DY = '00000000-0000-0000-0000-00000000c1a2';

  await db.exec('reset role');
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test H2', 'verified');
    insert into departments (id, institution_id, name, status) values ('${DX}', '${I1}', 'Génie logiciel', 'verified'), ('${DY}', '${I1}', 'Gestion', 'verified')`);
  // 71 chef X · 72 chef Y · 73 chef non rattaché · 74 admin · 75 direction · 76 étudiant X · 77 étudiant Y · 78 client · 79 chef X suspendu · 80 support · 81 entreprise · 82 étudiant X (2)
  const roles = { 71: 'dept', 72: 'dept', 73: 'dept', 74: 'admin', 75: 'direction', 76: 'student', 77: 'student', 78: 'client', 79: 'dept', 80: 'support', 81: 'company', 82: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h2${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','h2${n}@t.cm')`);
  }
  await db.exec(`update profiles set institution_id='${I1}', department_id='${DX}', department='Génie logiciel', institution='IUT test H2' where id in ('${U(76)}','${U(82)}')`);
  await db.exec(`update profiles set institution_id='${I1}', department_id='${DY}', department='Gestion', institution='IUT test H2' where id = '${U(77)}'`);

  // ============================== Rattachement ==============================
  await as(U(71));
  await fails('rattachement : un compte non rattaché ne lit aucune vue d\'ensemble', `select dept_overview()`, /rattaché à aucun département/);
  check('my_department : non rattaché', (await q(`select my_department() d`))[0].d.attached === false);
  await as(U(73));
  await fails('rattachement : chef non rattaché, vue d\'ensemble refusée', `select dept_overview()`, /rattaché à aucun département/);
  await fails('rattachement : chef non rattaché, partenariat refusé', `select dept_partnership_save('{"partner_name":"Orange"}'::jsonb)`, /rattaché à aucun département/);
  check('rattachement : chef non rattaché, liste des étudiants vide (aucune ligne)', (await q(`select dept_students() r`))[0].r.length === 0);
  await fails('rattachement : un chef ne s\'attribue pas lui-même un département', `select admin_dept_assign('${U(73)}', '${DX}')`, /Réservé à l'administrateur/);
  await as(U(76));
  await fails('rattachement : un étudiant ne rattache pas', `select admin_dept_assign('${U(71)}', '${DX}')`, /Réservé à l'administrateur/);
  await as(U(75));
  await fails('rattachement : la direction ne rattache pas', `select admin_dept_assign('${U(71)}', '${DX}')`, /Réservé à l'administrateur/);
  await as(null, 'anon');
  await fails('rattachement : anonyme refusé', `select admin_dept_assign('${U(71)}', '${DX}')`, /permission denied|denied/);
  await as(U(74));
  await fails('rattachement : compte non Département refusé', `select admin_dept_assign('${U(76)}', '${DX}')`, /n'est pas un compte Département/);
  await db.exec(`reset role; update departments set status = 'proposed' where id = '${DY}'`);
  await as(U(74));
  await fails('rattachement : département non vérifié refusé', `select admin_dept_assign('${U(72)}', '${DY}')`, /introuvable ou non vérifié/);
  await db.exec(`reset role; update departments set status = 'verified' where id = '${DY}'`);
  await as(U(74));
  await q(`select admin_dept_assign('${U(71)}', '${DX}', 'Chef de département')`);
  await q(`select admin_dept_assign('${U(72)}', '${DY}')`);
  await q(`select admin_dept_assign('${U(79)}', '${DX}')`);
  const acc = (await q(`select admin_dept_accounts() a`))[0].a;
  check('admin_dept_accounts : liste les 4 comptes Département dont un non rattaché', acc.length === 4 && acc.filter((a) => !a.attached).length === 1 && acc[0].attached === false, JSON.stringify(acc));
  const pr = (await sudo(`select department_id, department, institution_id from profiles where id = '${U(71)}'`))[0];
  check('rattachement : le profil suit (département, établissement)', pr.department_id === DX && pr.department === 'Génie logiciel' && pr.institution_id === I1);
  check('rattachement : audit journalisé', (await sudo(`select count(*)::int n from audit_log where action = 'Rattachement au département'`))[0].n === 3);
  check('rattachement : le chef est notifié', (await sudo(`select count(*)::int n from notifications where user_id = '${U(71)}' and kind = 'department' and data->>'type' = 'attached'`))[0].n === 1);
  await as(U(71));
  const md = (await q(`select my_department() d`))[0].d;
  check('my_department : rattaché au bon département', md.attached === true && md.department_id === DX && md.title === 'Chef de département', JSON.stringify(md));
  await as(U(71));
  await fails('rattachement : le chef ne change pas son département par le profil', `select profile_set_academic('${I1}', '${DY}', null, null)`, /défini par l'administrateur/);
  await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub', '${U(71)}', false)`);
  await sudo(`select 1`);
  // changement direct de colonne sous l'identité du chef : le déclencheur remet le département d'origine
  await as(U(71));
  try { await db.exec(`update profiles set department_id = '${DY}' where id = '${U(71)}'`); } catch (e) { /* colonne non modifiable : refus aussi accepté */ }
  check('rattachement : département du profil inchangé après tentative directe', (await sudo(`select department_id from profiles where id = '${U(71)}'`))[0].department_id === DX);
  await as(U(74));
  await q(`select admin_dept_assign('${U(71)}', '${DX}', 'Chef de département')`);
  await db.exec(`reset role; update profiles set suspended = true where id = '${U(79)}'`);
  await as(U(79));
  await fails('compte suspendu : plus aucun accès au département', `select dept_overview()`, /non autorisée|Action non autorisée/);
  check('compte suspendu : _dept_id nul', (await q(`select _dept_id() d`))[0].d === null);

  // ============================== Jeu de données ==============================
  await as(null, null);
  const L = (n) => `00000000-0000-0000-0000-00000000d1${String(n).padStart(2, '0')}`;
  await db.exec(`
    insert into listings (id, seller_id, title, department, price, status) values
      ('${L(1)}', '${U(76)}', 'Sac X', 'Génie logiciel', 5000, 'pending'), ('${L(2)}', '${U(77)}', 'Sac Y', 'Gestion', 6000, 'pending'),
      ('${L(3)}', '${U(76)}', 'Sac X approuvé', 'Génie logiciel', 7000, 'approved');
    insert into projects (id, owner_id, title, summary, kind, status, visibility, department) values
      ('${L(11)}', '${U(76)}', 'Appli de gestion de stock', 'Une application mobile pour gérer le stock des petites boutiques de quartier.', 'projet', 'submitted', 'public', 'Génie logiciel'),
      ('${L(12)}', '${U(77)}', 'Comptabilité simplifiée', 'Un tableur guidé pour les tontines de quartier avec rapports mensuels.', 'projet', 'submitted', 'public', 'Gestion'),
      ('${L(13)}', '${U(76)}', 'Capteur solaire', 'Un capteur solaire low-cost pour les villages sans réseau électrique du Nord.', 'innovation', 'approved', 'public', 'Génie logiciel'),
      ('${L(14)}', '${U(77)}', 'Innovation Y', 'Une innovation du département Gestion pour les marchés de proximité locaux.', 'innovation', 'approved', 'public', 'Gestion');
    insert into talent_skills (owner_id, domain, skill, level) values ('${U(76)}', 'Développement', 'Flutter', 'avance'), ('${U(76)}', 'Développement', 'SQL', 'intermediaire'), ('${U(82)}', 'Développement', 'Flutter', 'debutant'), ('${U(77)}', 'Gestion', 'Comptabilité', 'expert');
    update profiles set certification = 'pending' where id in ('${U(76)}', '${U(77)}');
    update profiles set phone_verified = true where id in ('${U(76)}', '${U(77)}');
    insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values
      ('${U(76)}', 'student_card', 'c.pdf', '${U(76)}/c/c.pdf', 'application/pdf', 10, 'verified'), ('${U(77)}', 'student_card', 'c.pdf', '${U(77)}/c/c.pdf', 'application/pdf', 10, 'verified');
    insert into opportunities (id, poster_id, org_name, kind, title, description, department_target, status) values
      ('${L(21)}', '${U(81)}', 'Entreprise Z', 'stage', 'Stage développeur mobile', 'Stage de six mois en développement mobile Flutter pour étudiants.', 'Génie logiciel', 'pending'),
      ('${L(22)}', '${U(81)}', 'Entreprise Z', 'stage', 'Stage général', 'Stage ouvert à tous les départements, sans cible particulière aujourd''hui.', '', 'pending'),
      ('${L(23)}', '${U(81)}', 'Entreprise Z', 'stage', 'Stage gestion', 'Stage de gestion comptable destiné aux étudiants du département Gestion.', 'Gestion', 'pending');
    insert into opportunities (id, poster_id, org_name, kind, title, description, department_target, status) values
      ('${L(24)}', '${U(81)}', 'Entreprise Z', 'emploi', 'Emploi publié', 'Une offre déjà publiée et visible de tous les étudiants du site.', '', 'published');
    insert into opportunity_applications (opportunity_id, applicant_id) values ('${L(24)}', '${U(76)}'), ('${L(24)}', '${U(77)}');
    insert into posts (id, author_id, kind, body, caption, status) values ('${L(31)}', '${U(76)}', 'text', 'Post X', 'Post X', 'pending'), ('${L(32)}', '${U(77)}', 'text', 'Post Y', 'Post Y', 'pending');
  `);

  // ============================== Identité ==============================
  await as(U(71));
  await q(`select dept_identity_save('{"description":"Formation en génie logiciel","mission":"Former des développeurs","programs":["Licence pro","Master","Master"],"head_name":"Dr Mbarga","contact_email":"gl@iut.cm","contact_phone":"+237 699 00 00 00","website":"https://gl.iut.cm"}'::jsonb)`);
  const id1 = (await q(`select dept_identity_get() i`))[0].i;
  check('identité : le chef lit et écrit la fiche de SON département', id1.department_id === DX && id1.description === 'Formation en génie logiciel' && id1.programs.length === 2 && id1.accounts.length === 1, JSON.stringify(id1));
  await fails('identité : e-mail invalide refusé', `select dept_identity_save('{"contact_email":"pas-un-mail"}'::jsonb)`, /e-mail invalide/);
  await fails('identité : site non https refusé', `select dept_identity_save('{"website":"http://x.cm"}'::jsonb)`, /https/);
  await fails('identité : téléphone invalide refusé', `select dept_identity_save('{"contact_phone":"abc"}'::jsonb)`, /téléphone invalide/);
  await fails('identité : autre département refusé', `select dept_identity_save('{"description":"x"}'::jsonb, '${DY}')`, /pas le vôtre/);
  await fails('identité : lecture d\'un autre département refusée', `select dept_identity_get('${DY}')`, /pas le vôtre/);
  await as(U(72));
  check('identité : l\'autre chef ne lit pas la fiche de X (la sienne est vide)', (await q(`select dept_identity_get() i`))[0].i.description === '');
  await as(U(76));
  await fails('identité : un étudiant ne lit pas la fiche de gestion', `select dept_identity_get('${DX}')`, /non autorisée/);
  await fails('identité : un étudiant n\'écrit pas', `select dept_identity_save('{"description":"x"}'::jsonb, '${DX}')`, /non autorisée/);
  await as(U(78));
  await fails('identité : un client n\'écrit pas', `select dept_identity_save('{"description":"x"}'::jsonb, '${DX}')`, /non autorisée/);
  await as(U(74));
  await q(`select dept_identity_save('{"description":"Fiche posée par l''administrateur","contact_public":true,"contact_email":"gl@iut.cm"}'::jsonb, '${DX}')`);
  await fails('identité : l\'administrateur doit indiquer le département', `select dept_identity_save('{"description":"x"}'::jsonb)`, /Indiquez le département/);
  await as(U(75));
  check('identité : la direction lit', (await q(`select dept_identity_get('${DX}') i`))[0].i.description.startsWith('Fiche posée'));
  await fails('identité : la direction n\'écrit pas', `select dept_identity_save('{"description":"x"}'::jsonb, '${DX}')`, /Action non autorisée|non autorisée/);
  await as(null, 'anon');
  const pub = (await q(`select department_detail('${DX}') d`))[0].d;
  check('fiche publique : description et contact publiés (choix du département) lisibles sans compte', pub.description.startsWith('Fiche posée') && pub.contact_email === 'gl@iut.cm', JSON.stringify(pub));
  await as(U(71));
  await q(`select dept_identity_save('{"description":"Fiche privée","contact_public":false,"contact_email":"gl@iut.cm"}'::jsonb)`);
  await as(null, 'anon');
  check('fiche publique : contact masqué sans accord du département', (await q(`select department_detail('${DX}') d`))[0].d.contact_email === '');
  await fails('identité : anonyme refusé', `select dept_identity_get('${DX}')`, /permission denied|denied/);

  // ============================== Étudiants, statistiques ==============================
  await as(U(71));
  const ov = (await q(`select dept_overview() o`))[0].o;
  check('statistiques : le chef X ne compte que ses 2 étudiants et ses projets', ov.students === 2 && ov.projects.total === 1 && ov.innovations.total === 1 && ov.skills.total === 3 && ov.department === 'Génie logiciel', JSON.stringify(ov));
  check('statistiques : candidatures limitées aux étudiants du département', ov.opportunities.applications === 1, JSON.stringify(ov.opportunities));
  await as(U(72));
  const ovy = (await q(`select dept_overview() o`))[0].o;
  check('statistiques : le chef Y ne voit que le sien', ovy.students === 1 && ovy.projects.total === 1 && ovy.skills.total === 1, JSON.stringify(ovy));
  await fails('statistiques : un autre département ciblé est refusé', `select dept_overview('${DX}')`, /pas le vôtre/);
  await as(U(75));
  const ova = (await q(`select dept_overview() o`))[0].o;
  const ovd = (await q(`select dept_overview('${DX}') o`))[0].o;
  check('statistiques : la direction lit tous les départements ou un seul', ova.students === 3 && ovd.students === 2, `${ova.students} ${ovd.students}`);
  await as(U(76));
  await fails('statistiques : un étudiant refusé', `select dept_overview()`, /non autorisée/);
  await as(U(78));
  await fails('statistiques : un client refusé', `select dept_students_list()`, /non autorisée/);
  await as(U(81));
  await fails('statistiques : une organisation refusée', `select dept_report('synthese')`, /non autorisée/);
  await as(null, 'anon');
  await fails('statistiques : anonyme refusé', `select dept_overview()`, /denied/);
  await as(U(71));
  const sl = (await q(`select dept_students_list('', 50, 0) r`))[0].r;
  check('étudiants : liste du département seulement', sl.total === 2 && sl.rows.length === 2 && sl.rows.every((r) => r.id === U(76) || r.id === U(82)), JSON.stringify(sl));
  check('étudiants : recherche par nom', (await q(`select dept_students_list('Personne 82') r`))[0].r.total === 1);
  check('étudiants : dept_students (console 109) limité au département', (await q(`select dept_students(200) r`))[0].r.length === 2);
  const det = (await q(`select dept_student_detail('${U(76)}') d`))[0].d;
  check('étudiants : fiche de suivi (projets, compétences)', det.projects.length === 2 && det.skills.length === 2 && det.applications === 1, JSON.stringify(det));
  await fails('étudiants : fiche d\'un autre département refusée', `select dept_student_detail('${U(77)}')`, /introuvable dans ce département/);
  check('annuaire : admin_users limité aux étudiants du département + soi', (await q(`select admin_users(null, 200) r`))[0].r.length === 3);
  check('annuaire : admin_departments limité au sien', (await q(`select admin_departments() r`))[0].r.length === 1);
  const po = (await q(`select platform_overview() o`))[0].o;
  check('vue d\'ensemble 108 : platform_overview scopé (étudiants du département)', po.students_declared === 2, JSON.stringify(po));
  await as(U(74));
  check('annuaire : l\'administrateur garde tout', (await q(`select admin_users(null, 200) r`))[0].r.length >= 12 && (await q(`select platform_overview() o`))[0].o.students_declared === 3);

  // ============================== Projets, innovations, compétences ==============================
  await as(U(71));
  const pj = (await q(`select dept_projects() r`))[0].r;
  check('projets : le chef X ne voit que ceux de ses étudiants (projet + innovation)', pj.length === 2 && pj.every((p) => p.owner_id === U(76)), JSON.stringify(pj));
  check('innovations : filtre par type', (await q(`select dept_projects('innovation') r`))[0].r.length === 1);
  await fails('projets : type inconnu', `select dept_projects('autre')`, /Type inconnu/);
  const sk = (await q(`select dept_skills() s`))[0].s;
  check('compétences : agrégat du département seulement', sk.total === 3 && sk.students_with_skills === 2 && sk.skills.find((x) => x.skill === 'flutter').students === 2 && !sk.skills.find((x) => x.skill === 'comptabilité'), JSON.stringify(sk));
  await as(U(72));
  await fails('validation projet : le chef Y ne valide pas un projet de X', `select review_project('${L(11)}', true, '')`, /autre département/);
  await as(U(71));
  check('validation projet : le chef X valide', (await q(`select review_project('${L(11)}', true, '') r`))[0].r === 'approved');
  await as(U(72));
  check('RLS projets : le chef Y ne lit que les projets de son département', (await q(`select count(*)::int n from projects`))[0].n === 2);
  await as(U(71));
  check('RLS projets : le chef X ne lit que les siens', (await q(`select count(*)::int n from projects`))[0].n === 2);
  check('RLS compétences : le chef X ne lit que celles de ses étudiants', (await q(`select count(*)::int n from talent_skills`))[0].n === 3);
  await as(U(73));
  check('RLS projets : chef non rattaché ne lit rien', (await q(`select count(*)::int n from projects`))[0].n === 0);
  await as(U(74));
  check('RLS projets : l\'administrateur lit tout', (await q(`select count(*)::int n from projects`))[0].n === 4);

  // ============================== Réalisations mises en avant ==============================
  await as(U(71));
  check('valorisation : projet validé et public de son département mis en avant', (await q(`select dept_highlight_set('project', '${L(11)}', 'Belle réalisation') r`))[0].r === true);
  await fails('valorisation : projet d\'un autre département refusé', `select dept_highlight_set('project', '${L(14)}')`, /de votre département/);
  await fails('valorisation : type inconnu', `select dept_highlight_set('student', '${L(11)}')`, /Type inconnu/);
  await as(null, 'anon');
  const hl = (await q(`select department_detail('${DX}') d`))[0].d.highlights;
  check('valorisation : visible sur la fiche publique', hl.length === 1 && hl[0].title === 'Appli de gestion de stock', JSON.stringify(hl));
  await as(U(72));
  check('valorisation : l\'autre chef ne voit pas les mises en avant de X', (await q(`select dept_highlights() r`))[0].r.length === 0);
  await as(U(71));
  check('valorisation : retrait', (await q(`select dept_highlight_set('project', '${L(11)}', '', false) r`))[0].r === false);

  // ============================== Validations du ressort ==============================
  await as(U(71));
  const v1 = (await q(`select dept_validations() v`))[0].v;
  check('validations : compteurs du département (certification, annonce, offre ciblée)', v1.certifications === 1 && v1.listings === 1 && v1.opportunities === 1 && v1.projects === 0, JSON.stringify(v1));
  const q1 = (await q(`select listing_review_queue() r`))[0].r;
  check('validations : file des annonces limitée au département', q1.length === 2 && q1.every((x) => x.seller_id === U(76)), JSON.stringify(q1.map((x) => x.seller_id)));
  check('validations : annonce d\'un autre département invisible donc non décidable (RLS)', (await q(`update listings set status = 'approved' where id = '${L(2)}' returning id`)).length === 0);
  check('validations : annonce d\'un autre département inchangée', (await sudo(`select status from listings where id = '${L(2)}'`))[0].status === 'pending');
  await as(U(71));
  await db.exec(`update listings set status = 'approved' where id = '${L(1)}'`);
  check('validations : annonce du département approuvée', (await sudo(`select status from listings where id = '${L(1)}'`))[0].status === 'approved');
  await as(U(72));
  check('RLS annonces : le chef Y ne lit pas les annonces en attente de X', (await q(`select count(*)::int n from listings where id = '${L(1)}' or id = '${L(2)}'`))[0].n === 2 && (await q(`select count(*)::int n from listings where status = 'pending' and seller_id = '${U(76)}'`))[0].n === 0);
  // certification
  await as(U(71));
  await fails('certification : le chef X ne décide pas pour un étudiant de Y', `select decide_certification('${U(77)}', 'approved', null)`, /n'appartient pas à votre département/);
  check('certification : file limitée au département', (await q(`select certification_queue() r`))[0].r.length === 1);
  check('certification : le chef X décide pour son étudiant', (await q(`select decide_certification('${U(76)}', 'approved', null) r`))[0].r === 'approved');
  await as(U(73));
  check('certification : chef non rattaché, file vide', (await q(`select certification_queue() r`))[0].r.length === 0);
  await fails('certification : chef non rattaché ne décide pas', `select decide_certification('${U(77)}', 'approved', null)`, /n'appartient pas/);
  // offres
  await as(U(71));
  check('offres : le chef X décide une offre qui cible son département', (await q(`select opp_decide('${L(21)}', true, false, '') r`))[0].r === 'published');
  await fails('offres : offre d\'un autre département refusée', `select opp_decide('${L(23)}', true, false, '')`, /ne cible pas votre département/);
  await fails('offres : offre sans cible réservée à l\'administration', `select opp_decide('${L(22)}', true, false, '')`, /ne cible pas votre département/);
  const oo = (await q(`select dept_opportunities() r`))[0].r;
  check('offres : suivi (publiées + ciblées), pas les offres en attente d\'un autre département', oo.some((o) => o.id === L(21)) && oo.some((o) => o.id === L(24)) && !oo.some((o) => o.id === L(23)) && !oo.some((o) => o.id === L(22)), JSON.stringify(oo.map((o) => o.id.slice(-4))));
  const ap = (await q(`select dept_opportunity_applicants('${L(24)}') r`))[0].r;
  check('offres : candidats limités aux étudiants du département', ap.length === 1 && ap[0].student_id === U(76), JSON.stringify(ap));
  await as(U(74));
  check('offres : l\'administrateur décide l\'offre sans cible', (await q(`select opp_decide('${L(22)}', true, false, '') r`))[0].r === 'published');
  await as(U(72));
  check('offres : ... et celle de Gestion revient au chef Y', (await q(`select opp_decide('${L(23)}', true, false, '') r`))[0].r === 'published');
  // modération réseau
  await as(U(72));
  await fails('modération : le chef Y ne modère pas la publication d\'un étudiant de X', `select moderate_post('${L(31)}', true, '')`, /autre département/);
  check('modération : le chef Y modère celle de son étudiant', (await q(`select moderate_post('${L(32)}', true, '') r`))[0].r === 'published');
  check('modération : file limitée au département (rien d\'autre à décider pour Y)', (await q(`select moderation_posts_list('pending') r`))[0].r.length === 0);
  check('RLS publications : le chef Y ne lit pas les publications en attente de X', (await q(`select count(*)::int n from posts where id = '${L(31)}'`))[0].n === 0);
  await as(U(74));
  check('modération : l\'administrateur garde sa vue complète', (await q(`select moderation_posts_list('pending') r`))[0].r.length === 1);

  // ============================== Partenariats ==============================
  await as(U(71));
  const pid = (await q(`select dept_partnership_save('{"partner_name":"Orange Cameroun","kind":"stage","status":"actif","contact_email":"rh@orange.cm","amount":500000,"students":12}'::jsonb) id`))[0].id;
  check('partenariats : création par le chef du département', !!pid);
  await fails('partenariats : statut inconnu refusé', `select dept_partnership_save('{"partner_name":"Autre","status":"zzz"}'::jsonb)`, /Statut inconnu/);
  await fails('partenariats : type inconnu refusé', `select dept_partnership_save('{"partner_name":"Autre","kind":"zzz"}'::jsonb)`, /Type de partenariat inconnu/);
  await fails('partenariats : dates inversées refusées', `select dept_partnership_save('{"partner_name":"Autre","starts_on":"2027-02-01","ends_on":"2027-01-01"}'::jsonb)`, /fin ne peut pas précéder/);
  check('partenariats : lecture du département', (await q(`select dept_partnerships() r`))[0].r.partnerships.length === 1);
  check('partenariats : direction notifiée d\'un partenariat actif', (await sudo(`select count(*)::int n from notifications where user_id = '${U(75)}' and kind = 'partnership'`))[0].n === 1);
  await as(U(72));
  check('partenariats : l\'autre chef n\'en voit aucun (fonction)', (await q(`select dept_partnerships() r`))[0].r.partnerships.length === 0);
  check('partenariats : l\'autre chef n\'en lit aucun (RLS)', (await q(`select count(*)::int n from department_partnerships`))[0].n === 0);
  await fails('partenariats : l\'autre chef ne modifie pas', `select dept_partnership_save(jsonb_build_object('id', '${pid}', 'partner_name', 'Piraté'))`, /introuvable dans ce département/);
  await fails('partenariats : l\'autre chef ne supprime pas', `select dept_partnership_delete('${pid}')`, /introuvable dans ce département/);
  await as(U(75));
  check('partenariats : la direction lit tout', (await q(`select dept_partnerships() r`))[0].r.partnerships.length === 1);
  await fails('partenariats : la direction n\'écrit pas ici', `select dept_partnership_save('{"partner_name":"Autre"}'::jsonb, '${DX}')`, /non autorisée/);
  await as(U(76));
  await fails('partenariats : un étudiant refusé', `select dept_partnerships()`, /non autorisée/);
  await as(U(71));
  await q(`select dept_partnership_delete('${pid}')`);
  check('partenariats : suppression par le chef', (await q(`select dept_partnerships() r`))[0].r.partnerships.length === 0);
  await as(U(74));
  check('partenariats : l\'administrateur crée pour un département donné', !!(await q(`select dept_partnership_save('{"partner_name":"MTN"}'::jsonb, '${DY}') id`))[0].id);

  // ============================== Rapports ==============================
  await as(U(71));
  const rp = (await q(`select dept_report('etudiants') r`))[0].r;
  check('rapports : étudiants du département seulement, colonnes + lignes exportables', rp.rows.length === 2 && rp.columns.length === 7 && rp.department === 'Génie logiciel', JSON.stringify(rp));
  const rs = (await q(`select dept_report('synthese') r`))[0].r;
  check('rapports : synthèse', rs.rows.length === 17 && rs.rows[0].indicateur === 'Étudiants déclarés' && rs.rows[0].valeur === '2', JSON.stringify(rs.rows.slice(0, 2)));
  for (const k of ['projets', 'competences', 'opportunites', 'partenariats', 'ventes']) check(`rapports : ${k}`, Array.isArray((await q(`select dept_report('${k}') r`))[0].r.rows));
  check('rapports : projets du département', (await q(`select dept_report('projets') r`))[0].r.rows.length === 2);
  await fails('rapports : type inconnu', `select dept_report('zzz')`, /Rapport inconnu/);
  await fails('rapports : période inversée', `select dept_report('projets', '2027-02-01', '2027-01-01')`, /inversée/);
  await fails('rapports : autre département refusé', `select dept_report('etudiants', null, null, '${DY}')`, /pas le vôtre/);
  check('rapports : génération journalisée', (await sudo(`select count(*)::int n from audit_log where action = 'Rapport de département généré'`))[0].n >= 6);
  await as(U(75));
  check('rapports : la direction exporte un département choisi', (await q(`select dept_report('etudiants', null, null, '${DY}') r`))[0].r.rows.length === 1);
  await as(U(76));
  await fails('rapports : un étudiant refusé', `select dept_report('etudiants')`, /non autorisée/);
  await as(null, 'anon');
  await fails('rapports : anonyme refusé', `select dept_report('etudiants')`, /denied/);
  await as(U(71));
  const ac = (await q(`select dept_activity() r`))[0].r;
  check('activité : flux limité au département', ac.length > 0 && !ac.some((a) => /Sac Y|Innovation Y|Comptabilité/.test(a.title)), JSON.stringify(ac.map((a) => a.title)));

  // ============================== Encadrement (mentors, productions) ==============================
  await as(U(71));
  const mx = (await q(`select mentor_create('Mentor X', 'Mentor', 'Web') id`))[0].id;
  check('mentors : création rattachée au département', (await sudo(`select department_id from mentors where id = '${mx}'`))[0].department_id === DX);
  await as(U(72));
  check('mentors : l\'autre chef ne voit pas les mentors de X', (await q(`select staff_mentors() r`))[0].r.length === 0);
  await fails('productions : mentor d\'un autre département refusé', `select production_create('Prod Y', 'Equipe', '${mx}', null)`, /autre département/);
  const py = (await q(`select production_create('Prod Y', 'Equipe', null, null) id`))[0].id;
  await as(U(71));
  check('productions : le chef X ne voit pas celles de Y', (await q(`select staff_productions() r`))[0].r.length === 0);
  await fails('productions : le chef X ne modifie pas celle de Y', `select production_update('${py}', 50, 'en_cours')`, /introuvable/);
  await as(U(73));
  await fails('mentors : chef non rattaché ne crée rien', `select mentor_create('Mentor Z', 'Mentor', 'Web')`, /rattaché à aucun département/);

  // ============================== Concours ==============================
  await as(U(71));
  const ct = (await q(`select save_contest(null, 'Hackathon GL', 'Un hackathon du département de génie logiciel pour tous les étudiants.', 'Tech', '', 'Douala', now() + interval '10 days', now() + interval '20 days', null, null, 100000, 10, true) id`))[0].id;
  check('concours : création par le chef X', !!ct);
  await as(U(72));
  check('RLS concours : le chef Y ne voit que les concours publiés (aucune ligne de gestion)', (await q(`select count(*)::int n from contests where id = '${ct}'`))[0].n === 1);
  await fails('concours : le chef Y ne modifie pas le concours de X', `select save_contest('${ct}', 'Piraté', 'Un hackathon du département de génie logiciel pour tous les étudiants.', 'Tech', '', 'Douala', now() + interval '10 days', now() + interval '20 days', null, null, 100000, 10, true)`, /autre département/);
  await fails('concours : le chef Y ne le clôture pas', `select set_contest_status('${ct}', 'cancelled')`, /autre département/);
  await fails('concours : le chef Y n\'y nomme pas de juré', `select assign_contest_juror('${ct}', 'h281@t.cm', true)`, /introuvable ou terminé/);
  await as(U(71));
  check('concours : le chef X l\'annule', (await q(`select set_contest_status('${ct}', 'cancelled') r`))[0].r === 'cancelled');

  // ============================== Messages privés, certificats, missions ==============================
  await run(`insert into conversations (id, created_by) values ('00000000-0000-0000-0000-00000000e101', '${U(76)}'); insert into message_reports (conversation_id, reporter_id, reason) values ('00000000-0000-0000-0000-00000000e101', '${U(76)}', 'Insultes')`);
  await as(U(71));
  check('RLS signalements de conversation : fermés au rôle dept (messages privés)', (await q(`select count(*)::int n from message_reports`))[0].n === 0);
  await as(U(74));
  check('RLS signalements de conversation : l\'administrateur les lit', (await q(`select count(*)::int n from message_reports`))[0].n === 1);
  await as(U(71));
  const cert = (await q(`select issue_certificate('talent', 'Talent Flutter', 'h276@t.cm', 'Personne 76', 'Gestion') c`))[0].c;
  check('certificat : le chef X en délivre un à son étudiant, avec SON département', (await sudo(`select department from certificates where code = '${cert}'`))[0].department === 'Génie logiciel');
  await as(U(71));
  await fails('certificat : titulaire d\'un autre département refusé', `select issue_certificate('talent', 'Talent Compta', 'h277@t.cm', 'Personne 77', 'Génie logiciel')`, /étudiant de votre département/);
  await fails('certificat : titulaire libre (sans compte) refusé pour un chef', `select issue_certificate('talent', 'Talent Libre', null, 'Quelqu''un', null)`, /étudiant de votre département/);
  await as(U(72));
  check('RLS certificats : le chef Y ne lit pas ceux de X', (await q(`select count(*)::int n from certificates`))[0].n === 0);
  await fails('certificat : le chef Y ne révoque pas celui de X', `select revoke_certificate('${cert}', 'Motif de test')`, /introuvable ou déjà révoqué/);
  await fails('QR : le chef Y ne crée pas le QR d\'un certificat de X', `select qr_issue('certificate', '${cert}')`, /autre département/);
  await as(U(71));
  check('QR : le chef X crée le QR de son certificat', !!(await q(`select qr_issue('certificate', '${cert}') r`))[0].r.token);
  check('RLS certificats : le chef X lit le sien', (await q(`select count(*)::int n from certificates`))[0].n === 1);
  await as(U(75));
  check('RLS certificats : la direction lit tout', (await q(`select count(*)::int n from certificates`))[0].n === 1);
  await as(U(71));
  check('certificat : révocation par le chef X', (await q(`select revoke_certificate('${cert}', 'Motif de test') r`))[0].r === 'revoked');
  const cert2 = (await q(`select issue_certificate('talent', 'Talent SQL', 'h282@t.cm', 'Personne 82', null) c`))[0].c;
  check('registre : le chef X lit ses certificats (valide + révoqué)', (await q(`select dept_certificates() r`))[0].r.length === 2);
  await as(U(72));
  check('registre : le chef Y n\'en lit aucun', (await q(`select dept_certificates() r`))[0].r.length === 0);
  await as(U(75));
  check('registre : la direction lit tout, ou un département choisi', (await q(`select dept_certificates() r`))[0].r.length === 2 && (await q(`select dept_certificates('${DY}') r`))[0].r.length === 0);
  await as(U(71));
  const certId = (await sudo(`select id from certificates where code = '${cert2}'`))[0].id;
  await as(U(71));
  check('valorisation : certificat actif mis en avant', (await q(`select dept_highlight_set('certificate', '${certId}', '') r`))[0].r === true);
  await as(U(72));
  await fails('valorisation : certificat d\'un autre département refusé', `select dept_highlight_set('certificate', '${certId}', '')`, /de votre département/);
  await run(`insert into missions (id, number, client_id, kind, description, total, status, title) values ('${L(41)}', 'M-H2-1', '${U(78)}', 'web', 'Site web', 100000, 'published', 'Site vitrine'), ('${L(42)}', 'M-H2-2', '${U(78)}', 'web', 'Logo', 50000, 'assigned', 'Logo privé')`);
  await run(`insert into mission_proposals (mission_id, author_id, amount, delay_days) values ('${L(41)}', '${U(76)}', 90000, 10), ('${L(41)}', '${U(77)}', 80000, 12), ('${L(42)}', '${U(77)}', 50000, 5)`);
  await as(U(71));
  const sm = (await q(`select staff_missions() r`))[0].r;
  check('missions : le chef X voit le besoin ouvert, pas celui où seul un étudiant de Y est engagé', sm.length === 1 && sm[0].number === 'M-H2-1', JSON.stringify(sm.map((m) => m.number)));
  const sp = (await q(`select staff_mission_proposals('${L(41)}') r`))[0].r;
  check('missions : propositions limitées aux étudiants du département', sp.length === 1 && sp[0].author === 'Personne 76', JSON.stringify(sp));
  await fails('missions : attribution à un talent d\'un autre département refusée', `select assign_mission('${L(41)}', 'Equipe', null, '${U(77)}')`, /autre département/);
  check('RLS missions : le chef X ne lit pas le besoin lié à Y seulement', (await q(`select count(*)::int n from missions`))[0].n === 1);
  check('RLS propositions : le chef X ne lit que celles de ses étudiants', (await q(`select count(*)::int n from mission_proposals`))[0].n === 1);
  await as(U(74));
  check('missions : l\'administrateur voit tout', (await q(`select staff_missions() r`))[0].r.length === 2);

  // ============================== Rapport sponsors (239) ==============================
  await run(`insert into sponsors (id, name) values ('00000000-0000-0000-0000-00000000e201', 'Sponsor Alpha'); insert into sponsorships (sponsor_id, title, department, amount, students) values
    ('00000000-0000-0000-0000-00000000e201', 'Bourses GL', 'Génie logiciel', 300000, 6), ('00000000-0000-0000-0000-00000000e201', 'Bourses Gestion', 'Gestion', 900000, 9)`);
  await as(U(71));
  check('sponsors : le chef X lit le sponsor qui finance son département', (await q(`select count(*)::int n from sponsors`))[0].n === 1);
  const sr = (await q(`select sponsor_report('00000000-0000-0000-0000-00000000e201') r`))[0].r;
  check('sponsors : le rapport ne totalise que les contributions de SON département', sr.total === 300000 && sr.students === 6 && sr.projects.length === 1 && sr.projects[0].title === 'Bourses GL', JSON.stringify(sr));
  check('sponsors : contributions lues (RLS) limitées au département', (await q(`select count(*)::int n from sponsorships`))[0].n === 1);
  await as(U(73));
  check('sponsors : chef non rattaché ne lit rien', (await q(`select count(*)::int n from sponsors`))[0].n === 0);
  await fails('sponsors : chef non rattaché, rapport refusé', `select sponsor_report('00000000-0000-0000-0000-00000000e201')`, /non autorisée/);
  await as(U(76));
  await fails('sponsors : un étudiant ne lit pas le rapport', `select sponsor_report('00000000-0000-0000-0000-00000000e201')`, /non autorisée/);
  await as(U(74));
  check('sponsors : l\'administrateur lit le rapport complet', (await q(`select sponsor_report('00000000-0000-0000-0000-00000000e201') r`))[0].r.total === 1200000);

  console.log(`\n${ok} OK, ${ko} ECHEC`);
  if (ko) process.exitCode = 1;
}







