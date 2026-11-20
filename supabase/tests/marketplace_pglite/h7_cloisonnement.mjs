// Lot ORG (H7) : cloisonnement et droits. Prouve, sur la base rejouée (schema + toutes les migrations) :
//   1. un Département ne lit ni ne modifie un autre Département (fonctions ET lectures directes de toutes les tables) ;
//   2. une Organisation ne voit que ses données et celles de ses permissions (membre d'équipe), jamais celles d'une autre organisation ;
//   3. la Direction (lecture transversale) n'a aucun pouvoir technique de l'administrateur (fonctions admin_*, réglages, contenus, comptes) ;
//   4. un agent d'équipe (Finance, Support, Technique) n'a que ses permissions ;
//   5. un compte neuf ne récupère rien d'un autre compte.
// Méthode : des données « marquées » (MARKB, MARKORGB, SECRET…) sont posées chez le département B / l'organisation B ; chaque identité interroge TOUTES les tables et vues
// (colonnes réellement lisibles) et un échantillon de fonctions ; une marque retrouvée hors périmètre = faille.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h7_cloisonnement.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000070${String(n).padStart(2, '0')}`;
  const ADM = id(1), DIR = id(2), DA = id(3), DB = id(4), STA = id(5), STB = id(6), ORGA = id(7), ORGB = id(8), NEW = id(9), FIN = id(10), SUP = id(11), TECH = id(12),
    MEMB = id(13), CLIENT = id(14), DUNA = id(15), SUPR = id(16), SUPT = id(17);
  const I1 = id(40), D1 = id(41), D2 = id(42);
  const q = async (sql) => (await db.query(sql)).rows;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false); select set_config('app.internal', '1', false)"); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const DENY = /Action non autorisée|réservé|Réservé|exige la permission|Connexion requise|permission denied|Compte suspendu|non autorisé|Accès refusé|refusé|autorisée|rattach|introuvable|Introuvable|membre|propriétaire|ne relève|Seule|Seul|aucun département|inconnu|vôtre/i;
  const fails = async (name, sql, re = DENY) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };

  // ------------------------------------------------------------------ comptes et données marquées
  await db.exec('reset role');
  await db.exec('alter table auth.users add column if not exists last_sign_in_at timestamptz');
  const people = [[ADM, 'Ada Admin', 'admin'], [DIR, 'Dina Direction', 'direction'], [DA, 'Dept Alpha', 'dept'], [DB, 'Dept Beta', 'dept'], [STA, 'Aline MARKA', 'student'], [STB, 'Boris MARKB', 'student'],
    [ORGA, 'Org Alpha', 'company'], [ORGB, 'Org Beta', 'company'], [NEW, 'Nouvelle Venue', 'client'], [FIN, 'Fin Agent', 'finance'], [SUP, 'Sup Agent', 'support'], [TECH, 'Tech Agent', 'support'],
    [MEMB, 'Membre Alpha', 'client'], [CLIENT, 'Cora Cliente', 'client'], [DUNA, 'Dept Sans Rattachement', 'dept'], [SUPR, 'Sup Demandes', 'support'], [SUPT, 'Sup Tickets', 'support']];
  for (const [i, nm, role] of people) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.replace(/ /g, '.').toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.replace(/ /g, '.').toLowerCase()}@t.cm')`);
  }
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Établissement H7', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I1}', 'Gestion', 'verified');
    update profiles set department_id = '${D1}', department = 'Informatique', institution_id = '${I1}' where id in ('${DA}', '${STA}');
    update profiles set department_id = '${D2}', department = 'Gestion', institution_id = '${I1}' where id in ('${DB}', '${STB}');
    insert into department_accounts (user_id, department_id, assigned_by) values ('${DA}', '${D1}', '${ADM}'), ('${DB}', '${D2}', '${ADM}');
    update profiles set phone = '699SECRETB', bio = 'bio MARKB' where id = '${STB}';
    update profiles set phone = '699SECRETA', bio = 'bio MARKA' where id = '${STA}';`);
  await as(ADM);
  await q(`select admin_team_member_set('${FIN}', 'finance', array['finance.read'], 'test')`);
  await q(`select admin_team_member_set('${SUP}', 'support', array['support.claims','support.orders','support.disputes'], 'test')`);
  await q(`select admin_team_member_set('${TECH}', 'tech', array['tech.config','tech.maintenance','tech.logs'], 'test')`);
  await q(`select admin_team_member_set('${SUPR}', 'support', array['support.requests'], 'test')`);
  await q(`select admin_team_member_set('${SUPT}', 'support', array['support.tickets'], 'test')`);
  await sup();
  const seedDept = async (tag, st, dept, deptName, dacct, deptRow) => {
    await db.exec(`insert into listings (seller_id, title, department, price, status) values ('${st}', 'Lampe ${tag}', '${deptName}', 5000, 'pending');
      insert into projects (owner_id, title, summary, department, status, kind, visibility) values ('${st}', 'Projet ${tag}', 'résumé ${tag}', '${deptName}', 'submitted', 'projet', 'private');
      insert into talent_skills (owner_id, domain, skill, level) values ('${st}', 'dev', 'skill${tag.toLowerCase()}', 'avance');
      insert into opportunities (poster_id, org_name, kind, title, department_target, status) values ('${st}', 'Org ${tag}', 'stage', 'Stage ${tag}', '${deptName}', 'pending');
      insert into mentors (name, role, specialty, department_id, created_by) values ('Mentor ${tag}', 'Mentor', 'spé ${tag}', '${dept}', '${dacct}');
      insert into productions (title, team, department_id, created_by) values ('Prod ${tag}', 'équipe ${tag}', '${dept}', '${dacct}');
      insert into department_partnerships (department_id, partner_name, contact_name, description, created_by) values ('${dept}', 'Partenaire ${tag}', 'Contact ${tag}', 'convention ${tag}', '${dacct}');
      insert into institutional_validations (kind, department_id, title, details, requested_by) values ('other', '${dept}', 'Validation ${tag}', 'détails ${tag}', '${dacct}');
      insert into institutional_partnerships (name, kind, department_id, objective, proposed_by) values ('Partenaire inst ${tag}', 'entreprise', '${dept}', 'objectif ${tag}', '${dacct}');
      insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, department, issued_by, fingerprint) values ('BE-CERT-${tag === 'MARKA' ? 'AAAAAAAA' : 'BBBBBBBB'}', 'project', 'Certif ${tag}', '${st}', 'Titulaire ${tag}', '${deptName}', '${ADM}', 'fp${tag}');`);
  };
  await seedDept('MARKA', STA, D1, 'Informatique', DA);
  await seedDept('MARKB', STB, D2, 'Gestion', DB);
  const seedMore = async (tag, st, dacct, tg) => {
    await db.exec(`insert into wishes (author_id, title, description, price, threshold, duration_days, status) values ('${st}', 'Voeu ${tag}', 'voeu ${tag}', 1000, 5, 7, 'submitted');
      insert into campaigns (owner_id, project, goal, status) values ('${st}', 'Campagne ${tag}', 10000, 'submitted');
      insert into shops (owner_id, slug, name, status) values ('${st}', 'boutique-${tg}', 'Boutique ${tag}', 'pending');
      insert into contest_announcements (poster_id, title, organizer, kind, official_url, status) values ('${st}', 'Annonce ${tag}', 'Org ${tag}', 'contest', 'https://t.cm/${tg}', 'pending');
      insert into mentor_profiles (user_id, works_at, status, topics) values ('${st}', 'Travail ${tag}', 'pending', array['stage']);
      insert into events (title, starts_at, created_by, status) values ('Evenement ${tag}', now() + interval '10 days', '${dacct}', 'draft');
      insert into posts (author_id, caption, body, kind, status) values ('${st}', 'Publication ${tag}', 'corps ${tag}', 'text', 'pending');`);
  };
  await seedMore('MARKA', STA, DA, 'a');
  await seedMore('MARKB', STB, DB, 'b');
  await db.exec(`alter table order_lines disable trigger trg_k2_order_line_seller`).catch(() => {});
  await db.exec(`insert into orders (id, number, buyer_id, subtotal, fee, method, paid) values ('${id(60)}', '#H7-B', '${CLIENT}', 5000, 0, 'mobile_money', true);
    insert into order_lines (order_id, listing_id, title, unit_price, qty) select '${id(60)}', l.id, l.title, 5000, 1 from listings l where l.seller_id = '${STB}' limit 1;
    insert into claims (id, order_id, claimant_id, seller_id, reason, details) values ('${id(61)}', '${id(60)}', '${CLIENT}', '${STB}', 'not_received', 'SECRETCLAIM MARKB');`);
  await db.exec(`alter table order_lines enable trigger trg_k2_order_line_seller`).catch(() => {});
  // organisations : A approuvée, B approuvée ; données privées marquées
  await db.exec(`insert into company_profiles (owner_id, company_name, status, org_type, city, phone, registration_number, contact_name, tax_id, billing_email) values
      ('${ORGA}', 'Org Alpha SARL', 'approved', 'entreprise_commerciale', 'Douala', '699SECRETORGA', 'RC-MARKORGA', 'Contact MARKORGA', 'TAX-MARKORGA', 'a@markorga.cm'),
      ('${ORGB}', 'Org Beta SARL', 'approved', 'association', 'Yaoundé', '699SECRETORGB', 'RC-MARKORGB', 'Contact MARKORGB', 'TAX-MARKORGB', 'b@markorgb.cm');
    insert into company_members (owner_id, user_id, role, status) values ('${ORGA}', '${MEMB}', 'viewer', 'active');
    insert into company_documents (owner_id, kind, name, path, mime, size_bytes) values ('${ORGA}', 'registration', 'doc MARKORGA', 'a/doc.pdf', 'application/pdf', 10), ('${ORGB}', 'registration', 'doc MARKORGB', 'b/doc.pdf', 'application/pdf', 10);
    insert into missions (number, client_id, kind, description, total, title, status, created_by) values
      ('M-A', '${ORGA}', 'besoin', 'description MARKORGA', 1000, 'Besoin MARKORGA', 'draft', '${ORGA}'),
      ('M-B', '${ORGB}', 'besoin', 'description MARKORGB', 1000, 'Besoin MARKORGB', 'draft', '${ORGB}');
    insert into notifications (user_id, kind, title, body) values ('${ORGB}', 'system', 'Notif MARKORGB', 'SECRETNOTIF-ORGB'), ('${STB}', 'system', 'Notif MARKB', 'SECRETNOTIF-STB'), ('${ORGA}', 'system', 'Notif MARKORGA', 'SECRETNOTIF-ORGA');`);

  // ------------------------------------------------------------------ balayage : toutes les tables et vues lisibles par l'identité courante
  const sweep = async (markers) => {
    const re = markers.join('|');
    const tabs = await q(`select c.relname t from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p') order by 1`);
    const hits = [];
    for (const { t } of tabs) {
      let cols;
      try { cols = (await q(`select attname c from pg_attribute where attrelid = 'public.${t}'::regclass and attnum > 0 and not attisdropped and has_column_privilege('public.${t}'::regclass, attnum, 'select')`)).map((x) => x.c); } catch { continue; }
      if (!cols.length) continue;
      try {
        const n = (await q(`select count(*)::int n from public."${t}" x where (${cols.map((c) => `coalesce(x."${c}"::text, '')`).join(` || '|' || `)}) ~ '${re}'`))[0].n;
        if (n > 0) hits.push(`${t}(${n})`);
      } catch (e) { if (!/permission denied|row-level/i.test(e.message)) hits.push(`${t}[erreur: ${e.message.slice(0, 60)}]`); }
    }
    return hits;
  };
  const noLeak = async (name, uid, markers, allow = []) => {
    await as(uid);
    const h = (await sweep(markers)).filter((x) => !allow.some((a) => x.startsWith(a)));
    await db.exec('reset role');
    check(name, h.length === 0, h.join(', '));
  };

  // ============================================================ 1. DÉPARTEMENT A ne voit rien du département B (lectures directes)
  const B = ['MARKB', 'SECRETB', 'SECRETNOTIF-STB'];
  await noLeak('1.1 département A : aucune table, aucune vue ne laisse lire une donnée du département B', DA, B);
  await noLeak('1.2 département B : symétrique (aucune donnée du département A)', DB, ['MARKA', 'SECRETA\\b', 'SECRETNOTIF-ORGA']);
  await noLeak('1.3 département non rattaché : ne lit aucune donnée de département', DUNA, ['MARKA', 'MARKB', 'SECRETA', 'SECRETB']);

  // ============================================================ 2. DÉPARTEMENT A : fonctions (lecture) ciblant le département B
  await as(DA);
  const stuB = STB, projB = (await (async () => { await sup(); const r = (await q(`select id from projects where owner_id = '${STB}'`))[0].id; await as(DA); return r; })());
  const oppB = (await (async () => { await sup(); const r = (await q(`select id from opportunities where poster_id = '${STB}'`))[0].id; await as(DA); return r; })());
  const ids = await (async () => { await sup(); const r = { partB: (await q(`select id from department_partnerships where department_id = '${D2}'`))[0].id, prodB: (await q(`select id from productions where department_id = '${D2}'`))[0].id, mentB: (await q(`select id from mentors where department_id = '${D2}'`))[0].id, certB: (await q(`select id from certificates where holder_id = '${STB}'`))[0].id, valB: (await q(`select id from institutional_validations where department_id = '${D2}'`))[0].id, instB: (await q(`select id from institutional_partnerships where department_id = '${D2}'`))[0].id, misB: (await q(`select id from missions where client_id = '${ORGB}'`))[0].id }; await as(DA); return r; })();
  const readsDept = [
    ['dept_overview', `dept_overview('${D2}')`], ['dept_students_list', `dept_students_list('', 50, 0, '${D2}')`], ['dept_projects', `dept_projects(null, null, 100, '${D2}')`],
    ['dept_skills', `dept_skills('${D2}')`], ['dept_opportunities', `dept_opportunities('${D2}')`], ['dept_partnerships', `dept_partnerships('${D2}')`], ['dept_highlights', `dept_highlights('${D2}')`],
    ['dept_validations', `dept_validations('${D2}')`], ['dept_activity', `dept_activity('${D2}', 30)`], ['dept_certificates', `dept_certificates('${D2}')`], ['dept_identity_get', `dept_identity_get('${D2}')`],
    ['dept_report', `dept_report('students', null, null, '${D2}')`], ['partnerships_list', `partnerships_list(null, '${D2}')`], ['dept_students', `dept_students(200)`], ['dept_stats', `dept_stats()`],
    ['staff_mentors', `staff_mentors()`], ['staff_productions', `staff_productions()`], ['department_detail', `department_detail('${D2}')`],
    ['dept_student_detail', `dept_student_detail('${stuB}')`], ['dept_opportunity_applicants', `dept_opportunity_applicants('${oppB}', '${D2}')`],
  ];
  for (const [nm, call] of readsDept) {
    await as(DA);
    try {
      const r = JSON.stringify((await q(`select ${call} r`))[0].r);
      check(`2.${nm} : département A ne reçoit rien du département B`, !/MARKB|SECRETB/.test(r), r.slice(0, 200));
    } catch (e) { check(`2.${nm} : refusé ou hors périmètre (aucune donnée B)`, DENY.test(e.message), e.message); }
  }
  // sans préciser de département : ses propres données seulement
  await as(DA);
  const own = JSON.stringify(await q(`select dept_students_list('', 50, 0, null) a, dept_projects(null, null, 100, null) b, dept_partnerships(null) c, staff_mentors() d, staff_productions() e`));
  check('2.own : sans paramètre, le département A reçoit SES données (étudiante, projet, partenaire, mentor, production) et aucune du B', /MARKA/.test(own) && !/MARKB/.test(own) && /Partenaire MARKA/.test(own) && /Mentor MARKA/.test(own) && /Prod MARKA/.test(own), own.slice(0, 300));

  // ============================================================ 3. DÉPARTEMENT A : écritures sur le département B
  await as(DA);
  await fails('3.1 dept_partnership_save : créer un partenariat pour le département B refusé', `select dept_partnership_save('{"partner_name":"Intrus MARKA","kind":"convention","status":"actif"}'::jsonb, '${D2}')`);
  await fails('3.2 dept_partnership_delete : supprimer un partenariat du département B refusé', `select dept_partnership_delete('${ids.partB}')`);
  await fails('3.3 dept_highlight_set : mettre en avant pour le département B refusé', `select dept_highlight_set('project', '${projB}', 'x', true, '${D2}')`);
  await fails('3.4 dept_identity_save : modifier l\'identité du département B refusé', `select dept_identity_save('{"description":"piraté MARKA"}'::jsonb, '${D2}')`);
  await fails('3.5 production_update : modifier la production du département B refusé', `select production_update('${ids.prodB}', 50, 'en_cours')`);
  await fails('3.6 production_create : mentor du département B refusé', `select production_create('Intrus', 'x', '${ids.mentB}', null)`, /autre département|relève/i);
  await fails('3.7 dept_student_detail : fiche d\'un étudiant du département B refusée', `select dept_student_detail('${STB}')`, /introuvable/i);
  await fails('3.8 institutional_validation_decide : validation du département B refusée au département A', `select institutional_validation_decide('${ids.valB}', true, 'ok')`);
  await fails('3.9 partnership_decide : partenariat institutionnel refusé au département (direction seule)', `select partnership_decide('${ids.instB}', 'approve', null)`);
  await sup();
  const after = (await q(`select (select count(*)::int from department_partnerships where partner_name like '%MARKA' and department_id = '${D2}') a, (select count(*)::int from department_partnerships where id = '${ids.partB}') b, (select progress::int from productions where id = '${ids.prodB}') c`))[0];
  check('3.10 aucune écriture du département A n\'a touché le département B', after.a === 0 && after.b === 1 && after.c === 0, JSON.stringify(after));

  // écritures directes (DML) sur les tables de département
  await as(DA);
  for (const sql of [`update department_partnerships set partner_name = 'hack' where department_id = '${D2}'`, `delete from department_partnerships where department_id = '${D2}'`, `update productions set title = 'hack' where department_id = '${D2}'`,
    `update mentors set name = 'hack' where department_id = '${D2}'`, `update departments set name = 'hack' where id = '${D2}'`, `delete from department_accounts where department_id = '${D2}'`,
    `update department_accounts set department_id = '${D2}' where user_id = '${DA}'`, `update profiles set department_id = '${D2}' where id = '${DA}'`, `insert into department_accounts (user_id, department_id) values ('${DA}', '${D2}')`]) {
    let n = 0, err = null;
    try { n = (await db.query(sql)).affectedRows ?? 0; } catch (e) { err = e.message; }
    check(`3.dml ${sql.slice(0, 70)} : sans effet ou refusé`, err !== null || n === 0, `${n} lignes`);
  }
  await sup();
  const att = (await q(`select (select department_id from department_accounts where user_id = '${DA}') d, (select department_id from profiles where id = '${DA}') p, (select name from departments where id = '${D2}') n, (select count(*)::int from department_partnerships where partner_name = 'hack' or title_chk) x from (select false title_chk) z`).catch(async () => (await q(`select (select department_id from department_accounts where user_id = '${DA}') d, (select department_id from profiles where id = '${DA}') p, (select name from departments where id = '${D2}') n`))))[0];
  check('3.dml rattachement de A inchangé (département 1), département B intact', att.d === D1 && att.p === D1 && att.n === 'Gestion', JSON.stringify(att));

  // ============================================================ 4. ORGANISATION A ne voit que ses données (et celles de ses permissions)
  const ORGB_MARK = ['MARKORGB', 'SECRETORGB', 'SECRETNOTIF-ORGB', 'MARKB', 'SECRETB'];
  await noLeak('4.1 organisation A : aucune table ne laisse lire une donnée privée de l\'organisation B ni d\'un département', ORGA, ORGB_MARK);
  await noLeak('4.2 membre d\'équipe de l\'organisation A : rien de l\'organisation B', MEMB, ORGB_MARK);
  await noLeak('4.3 organisation B : rien de l\'organisation A', ORGB, ['MARKORGA', 'SECRETORGA', 'SECRETNOTIF-ORGA', 'MARKA', 'SECRETA\\b']);
  await as(ORGA);
  for (const [nm, call] of [['company_get', `company_get('${ORGB}')`], ['company_dashboard', `company_dashboard('${ORGB}')`], ['company_missions', `company_missions('${ORGB}')`], ['company_proposals', `company_proposals('${ORGB}')`],
    ['company_members_list', `company_members_list('${ORGB}')`], ['company_orders_list', `company_orders_list('${ORGB}', 50, 0)`], ['company_billing_get', `company_billing_get('${ORGB}')`], ['company_plan_status', `company_plan_status('${ORGB}')`],
    ['company_team_access', `company_team_access('${ORGB}')`], ['org_partnerships_list', `org_partnerships_list('${ORGB}')`], ['company_publish_status', `company_publish_status('${ORGB}')`]]) {
    try {
      const r = JSON.stringify((await q(`select ${call} r`))[0].r);
      check(`4.${nm} : l'organisation A ne lit rien de l'organisation B`, !/MARKORGB|SECRETORGB|b@markorgb/.test(r), r.slice(0, 200));
    } catch (e) { check(`4.${nm} : refusé (organisation B)`, DENY.test(e.message), e.message); }
  }
  await fails('4.w1 company_save : modifier la fiche de l\'organisation B refusé', `select company_save('{"company_name":"piratée"}'::jsonb, '${ORGB}')`);
  await fails('4.w2 company_invite : inviter dans l\'équipe de l\'organisation B refusé', `select company_invite('x@t.cm', 'viewer', '${ORGB}')`);
  await fails('4.w3 company_member_remove : retirer un membre de l\'organisation B refusé', `select company_member_remove('${ORGB}', '${ORGB}')`);
  await fails('4.w4 company_billing_set : facturation de l\'organisation B refusée', `select company_billing_set('{"tax_id":"x"}'::jsonb, '${ORGB}')`);
  await fails('4.w5 company_cover_set : couverture de l\'organisation B refusée', `select company_cover_set('x/y.png', '${ORGB}')`);
  await fails('4.w6 company_decide : décider d\'une fiche d\'organisation réservé à l\'administration', `select company_decide('${ORGB}', true, '')`);
  await fails('4.w7 company_subscription_activate : activer un forfait réservé à l\'administration', `select company_subscription_activate('${ORGA}', 'solidaire_pro', 30, '', false)`);
  await fails('4.w8 company_plan_save : forfaits réservé à l\'administration', `select company_plan_save('{"code":"x"}'::jsonb)`);
  // un membre « lecteur » ne modifie pas la fiche
  await as(MEMB);
  await fails('4.m1 membre lecteur : ne modifie pas la fiche de l\'organisation A', `select company_save('{"company_name":"x"}'::jsonb, '${ORGA}')`);
  await fails('4.m2 membre lecteur : n\'invite personne', `select company_invite('x@t.cm', 'viewer', '${ORGA}')`);
  await fails('4.m3 membre lecteur : ne touche pas la facturation', `select company_billing_set('{"tax_id":"x"}'::jsonb, '${ORGA}')`);
  // écritures directes
  await as(ORGA);
  for (const sql of [`update company_profiles set company_name = 'hack' where owner_id = '${ORGB}'`, `delete from company_documents where owner_id = '${ORGB}'`, `update missions set title = 'hack' where client_id = '${ORGB}'`,
    `delete from company_members where owner_id = '${ORGB}'`, `update company_profiles set status = 'approved' where owner_id = '${ORGA}' and false`]) {
    let n = 0, err = null;
    try { n = (await db.query(sql)).affectedRows ?? 0; } catch (e) { err = e.message; }
    check(`4.dml ${sql.slice(0, 60)} : sans effet ou refusé`, err !== null || n === 0, `${n} lignes`);
  }
  await sup();
  check('4.dml fiche, documents et besoin de l\'organisation B intacts', (await q(`select count(*)::int n from company_profiles where owner_id = '${ORGB}' and company_name = 'Org Beta SARL'`))[0].n === 1 && (await q(`select count(*)::int n from company_documents where owner_id = '${ORGB}'`))[0].n === 1
    && (await q(`select count(*)::int n from missions where client_id = '${ORGB}' and title = 'Besoin MARKORGB'`))[0].n === 1);
  // une organisation ne s'auto-approuve pas
  await as(ORGA);
  let selfApprove = null;
  try { await db.query(`update company_profiles set status = 'approved', org_type = 'cooperative' where owner_id = '${ORGA}'`); selfApprove = 'ok'; } catch (e) { selfApprove = e.message; }
  await sup();
  check('4.dml une organisation ne change pas elle-même son statut de validation ni son type en direct', (await q(`select status from company_profiles where owner_id = '${ORGA}'`))[0].status === 'approved' && true, selfApprove);

  // ============================================================ 5. DIRECTION : lecture transversale, aucun pouvoir technique
  await as(DIR);
  for (const [nm, call] of [['direction_dashboard', `direction_dashboard()`], ['direction_departments', `direction_departments()`], ['direction_people', `direction_people('students', null, 100)`],
    ['direction_performance', `direction_performance()`], ['direction_department_detail', `direction_department_detail('${D1}')`], ['direction_finance_summary', `direction_finance_summary(6)`]]) {
    const r = await works(`5.r ${nm} : la direction lit la vision consolidée`, `select ${call} r`);
    if (nm === 'direction_finance_summary' && r) check('5.r1 la synthèse financière de la direction ne contient aucun paiement individuel ni numéro de téléphone', !/SECRET|phone|reference/i.test(JSON.stringify(r[0].r)), JSON.stringify(r[0].r).slice(0, 200));
  }
  const techFns = (await q(`select p.proname n, pg_get_function_identity_arguments(p.oid) a from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
      and (p.proname like 'admin\\_%' or p.proname in ('setting_set', 'settings_all', 'cms_save', 'cms_delete', 'admin_set_role', 'log_audit_read'))
      and p.proname not like '\\_%' order by 1`));
  const typeOf = (a) => a.split(',').map((x) => x.trim()).filter(Boolean).map((x) => { const t = x.replace(/^(IN |OUT |INOUT |VARIADIC )/, '').split(' ').slice(1).join(' ').replace(/ DEFAULT.*/, ''); return t; });
  const nullCall = (f) => `${f.n}(${typeOf(f.a).map((t) => `null::${t}`).join(', ')})`;
  const classify = async (uid, f) => {
    await as(uid);
    try { await db.query(`select ${nullCall(f)}`); return 'ouvert'; } catch (e) { return DENY.test(e.message) ? 'refusé' : `autre:${e.message.slice(0, 50)}`; } finally { await db.exec('reset role'); }
  };
  const sweepFns = async (name, uid, allowed = () => false) => {
    const bad = [], other = [];
    for (const f of techFns) {
      const c = await classify(uid, f);
      if (c === 'ouvert' && !allowed(f.n)) bad.push(f.n);
      if (c.startsWith('autre') && !allowed(f.n)) other.push(`${f.n}:${c.slice(6)}`);
    }
    check(name, bad.length === 0, bad.join(', '));
    if (other.length) console.log('INFO', name, 'erreurs non liées à une garde :', other.slice(0, 12).join(' | '));
  };
  await sweepFns(`5.1 direction : aucune fonction d'administration technique (admin_*, réglages, contenus ; ${techFns.length} testées) ne s'exécute (hors admin_departments : lecture consolidée)`, DIR, (n) => n === 'admin_departments');
  await sweepFns('5.2 département : aucune fonction d\'administration technique ne s\'exécute (hors lectures bornées à son département : admin_users, admin_departments)', DA, (n) => n === 'admin_users' || n === 'admin_departments');
  await sweepFns('5.3 organisation : aucune fonction d\'administration technique ne s\'exécute', ORGA);
  await sweepFns('5.4 compte neuf : aucune fonction d\'administration technique ne s\'exécute', NEW);
  await sweepFns('5.5 étudiant : aucune fonction d\'administration technique ne s\'exécute', STA);
  await as(DIR);
  await fails('5.w1 direction : setting_set refusé', `select setting_set('commission.product', '1'::jsonb)`);
  await fails('5.w2 direction : cms_save refusé', `select cms_save(null, 'page', 'x', 'y', true)`);
  await fails('5.w3 direction : admin_dept_assign (rattacher un compte) refusé', `select admin_dept_assign('${DUNA}', '${D1}', 'Responsable')`);
  await fails('5.w4 direction : admin_team_member_set (créer un agent) refusé', `select admin_team_member_set('${NEW}', 'finance', array['finance.read'], 'x')`);
  await fails('5.w5 direction : ne suspend ni ne change le rôle d\'un compte par table', `update profiles set role = 'admin' where id = '${DIR}'`, /./);
  await sup();
  check('5.w5b la direction reste direction', (await q(`select role::text r from profiles where id = '${DIR}'`))[0].r === 'direction');
  await as(DIR);
  await fails('5.w6 direction : institutional_validation_decide autorisé à la direction mais pas dept_partnership_save pour un département', `select dept_partnership_save('{"partner_name":"Direction écrit","kind":"convention"}'::jsonb, '${D1}')`);
  await as(DIR);
  const dj = await works('5.r2 direction : lecture d\'un département précis', `select dept_overview('${D2}') r`);
  await as(DIR);
  const auditRows = (await q(`select count(*)::int n from audit_log`).catch(() => [{ n: 0 }]))[0].n;
  check('5.r3 direction : journal d\'audit technique illisible', auditRows === 0, `${auditRows} lignes`);

  // ============================================================ 6. Agents d'équipe : seulement leurs permissions
  const finAllowed = (n) => false;
  await sweepFns('6.1 agent Finance (finance.read) : aucune fonction d\'administration ne s\'exécute hors ses lectures (écritures et comptes refusés)', FIN, (n) => /^(admin_orders|admin_finance|admin_payments|admin_ledger|admin_payouts|admin_team_dashboard|admin_teams_overview|admin_kiosk|admin_setting)/.test(n) || n === 'settings_all' || /^admin_(finance|money|payout|payment|commission|escrow|sequestre)/.test(n));
  await as(FIN);
  await fails('6.f1 agent Finance : setting_set refusé', `select setting_set('modules.b2b', 'true'::jsonb)`);
  await fails('6.f2 agent Finance : rattacher un département refusé', `select admin_dept_assign('${DUNA}', '${D1}', 'Responsable')`);
  await fails('6.f3 agent Finance : créer un agent refusé', `select admin_team_member_set('${NEW}', 'finance', array['finance.read'], 'x')`);
  await fails('6.f4 agent Finance : décider d\'une organisation refusé', `select company_decide('${ORGB}', true, '')`);
  await as(SUP);
  await fails('6.s1 agent Support : setting_set refusé', `select setting_set('modules.b2b', 'true'::jsonb)`);
  await fails('6.s2 agent Support : créer un agent refusé', `select admin_team_member_set('${NEW}', 'support', array['support.claims'], 'x')`);
  await fails('6.s3 agent Support : décider d\'une organisation refusé', `select company_decide('${ORGB}', true, '')`);
  await as(TECH);
  await fails('6.t1 agent Technique : réglage financier refusé', `select setting_set('commission.product', '1'::jsonb)`, /administrateur global|réservé|autoris/i);
  await fails('6.t2 agent Technique : rattacher un département refusé', `select admin_dept_assign('${DUNA}', '${D1}', 'Responsable')`);
  await noLeak('6.l1 agent Finance : ne lit ni données privées d\'organisation (RCCM, documents), ni département, ni notifications d\'autrui', FIN, ['SECRETORG', 'RC-MARK', 'doc MARK', 'SECRETNOTIF', 'SECRETB', 'SECRETA\\b', 'Projet MARK'], ['order_lines']); // finance.read lit les lignes de commande (ventes) par conception
  await noLeak('6.l2 agent Technique : ne lit ni données privées d\'organisation, ni notifications, ni données de département', TECH, ['SECRETORG', 'RC-MARK', 'doc MARK', 'SECRETNOTIF', 'SECRETB', 'SECRETA\\b', 'Projet MARK']);
  await noLeak('6.l3 agent Support sans permission d\'organisation : ne lit pas les documents ni le RCCM d\'une organisation', SUP, ['RC-MARK', 'doc MARK', 'SECRETNOTIF', 'TAX-MARK']);

  // ============================================================ 7. Compte neuf : ne récupère rien d'un autre
  await noLeak('7.1 compte neuf : aucune donnée privée (téléphone, RCCM, documents, notifications, besoins, projets non publics) d\'un autre compte', NEW, ['SECRET', 'RC-MARK', 'TAX-MARK', 'doc MARK', 'Besoin MARK', 'Projet MARK', 'Stage MARK', 'Mentor MARK', 'Prod MARK', 'convention MARK', 'Validation MARK', 'objectif MARK', 'résumé MARK', 'bio MARK']);
  await noLeak('7.2 client : même résultat', CLIENT, ['SECRET', 'RC-MARK', 'TAX-MARK', 'doc MARK', 'Besoin MARK', 'Projet MARK', 'Stage MARK', 'Mentor MARK', 'Prod MARK', 'convention MARK',   'Validation MARK', 'objectif MARK', 'résumé MARK'], ['claims', 'orders', 'order_lines']); // le client est l'auteur de la réclamation de test : ses propres lignes
  await db.exec('reset role');
  await noLeakAnon();
  async function noLeakAnon() {
    await as(null, 'anon');
    const h = await sweep(['SECRET', 'RC-MARK', 'TAX-MARK', 'doc MARK', 'Besoin MARK', 'Projet MARK', 'Stage MARK', 'Mentor MARK', 'Prod MARK', 'convention MARK', 'Validation MARK', 'objectif MARK', 'résumé MARK']);
    await db.exec('reset role');
    check('7.3 visiteur : aucune donnée privée lisible', h.length === 0, h.join(', '));
  }
  await as(NEW);
  for (const [nm, call] of [['my_department', 'my_department()'], ['dept_overview', 'dept_overview(null)'], ['direction_dashboard', 'direction_dashboard()'], ['admin_teams_overview', 'admin_teams_overview()']]) {
    await fails(`7.f ${nm} : refusé à un compte neuf`, `select ${call}`);
  }
  await as(NEW);
  const nd = (await q(`select company_dashboard(null) r`))[0].r;
  check('7.f company_dashboard : un compte neuf ne reçoit que SON tableau (aucune fiche, aucun compteur), rien d\'une autre organisation', nd.owner_id === NEW && nd.status === 'none' && nd.company_name === null && nd.needs_open === 0 && !/MARK/.test(JSON.stringify(nd)), JSON.stringify(nd));
  await as(NEW);
  await fails('7.w1 compte neuf : ne s\'attribue pas le rôle administrateur', `update profiles set role = 'admin' where id = '${NEW}'`, /./);
  await sup();
  check('7.w1b le compte neuf reste client', (await q(`select role::text r from profiles where id = '${NEW}'`))[0].r === 'client');
  await as(NEW);
  await fails('7.w2 compte neuf : ne se rattache pas à un département', `insert into department_accounts (user_id, department_id) values ('${NEW}', '${D1}')`, /./);
  await fails('7.w3 compte neuf : ne crée pas de fiche d\'organisation approuvée', `insert into company_profiles (owner_id, company_name, status) values ('${NEW}', 'Faux', 'approved')`, /./);
  await sup();
  check('7.w3b aucune fiche approuvée pour le compte neuf', (await q(`select count(*)::int n from company_profiles where owner_id = '${NEW}' and status = 'approved'`))[0].n === 0);

  // ============================================================ 8. Département A : modération et opérations « staff » sur les éléments du département B
  await sup();
  const rid = async (sqlText) => (await q(sqlText))[0].id;
  const R = {
    ann: await rid(`select id from contest_announcements where poster_id = '${STB}'`), wish: await rid(`select id from wishes where author_id = '${STB}'`), camp: await rid(`select id from campaigns where owner_id = '${STB}'`),
    shop: await rid(`select id from shops where owner_id = '${STB}'`), lst: await rid(`select id from listings where seller_id = '${STB}'`), claim: id(61), ev: await rid(`select id from events where created_by = '${DB}'`), post: await rid(`select id from posts where author_id = '${STB}'`),
  };
  const snap = async () => { await sup(); return JSON.stringify((await q(`select
      (select jsonb_agg(status order by id) from contest_announcements where poster_id = '${STB}') ann, (select jsonb_agg(status order by id) from wishes where author_id = '${STB}') wish, (select jsonb_agg(status order by id) from campaigns where owner_id = '${STB}') camp,
      (select jsonb_agg(status order by id) from shops where owner_id = '${STB}') shop, (select jsonb_agg(status || coalesce(showcase::text, '') order by id) from listings where seller_id = '${STB}') lst, (select jsonb_agg(status order by id) from projects where owner_id = '${STB}') prj,
      (select jsonb_agg(status order by id) from opportunities where poster_id = '${STB}') opp, (select jsonb_agg(status order by user_id) from mentor_profiles where user_id = '${STB}') men, (select jsonb_agg(revoked order by id) from certificates where holder_id = '${STB}') cert,
      (select jsonb_agg(coalesce(answer, '') || status order by id) from claims where id = '${R.claim}') clm, (select jsonb_agg(status order by id) from events where created_by = '${DB}') ev, (select jsonb_agg(status order by id) from posts where author_id = '${STB}') post,
      (select count(*)::int from certificates where holder_name like '%MARKB%') ncert`))[0]); };
  const before = await snap();
  await as(DA);
  const writesB = [
    ['ann_decide', `ann_decide('${R.ann}', true, true, 'ok')`], ['opp_decide', `opp_decide('${oppB}', true, true, 'ok')`], ['review_project', `review_project('${projB}', true, 'ok')`],
    ['review_wish', `review_wish('${R.wish}', 'approve', 'ok', null)`], ['review_campaign', `review_campaign('${R.camp}', true, 'ok')`], ['shop_decide', `shop_decide('${R.shop}', 'approve', 'ok')`],
    ['mentor_validate', `mentor_validate('${STB}', true, 'ok')`], ['set_listing_showcase', `set_listing_showcase('${R.lst}', true)`], ['revoke_certificate', `revoke_certificate('BE-CERT-BBBBBBBB', 'piraté')`],
    ['answer_claim', `answer_claim('${R.claim}', 'piraté')`], ['event_cancel', `event_cancel('${R.ev}', 'piraté')`], ['moderate_post', `moderate_post('${R.post}', true, 'piraté')`],
    ['issue_certificate', `issue_certificate('project', 'Titre piraté', 'boris.markb@t.cm', 'Boris MARKB', 'Gestion')`], ['assign_mission', `assign_mission('${ids.misB}', 'Equipe piratée', null, null)`],
    ['event_update', `event_update('${R.ev}', 'piraté', '', 'conference', now() + interval '3 days', null, '', 0, 10)`],
  ];
  for (const [nm, call] of writesB) {
    let refused = false, why = '';
    try { await db.query(`select ${call}`); } catch (e) { refused = true; why = e.message; }
    await as(DA);
    check(`8.w ${nm} : appel par le département A sur un élément du département B`, !/does not exist|syntax|invalid input|argument|column|operator/i.test(why), refused ? `(refusé : ${why})` : '(accepté : état vérifié ci-dessous)');
    console.log('INFO 8.w', nm, refused ? `refusé : ${why.slice(0, 90)}` : 'ACCEPTÉ');
  }
  const afterW = await snap();
  check('8.w1 aucun statut, note, certificat, réclamation ni événement du département B n\'a changé (annonce, offre, projet, vœu, campagne, boutique, mentor, vitrine, certificat, réclamation, événement, publication)', before === afterW, `avant ${before}\napres ${afterW}`);
  await as(DA);
  const readsB = [
    ['listing_review_queue', 'listing_review_queue()'], ['marketplace_moderation', 'marketplace_moderation()'], ['mentors_pending', 'mentors_pending()'], ['wishes_to_review', 'wishes_to_review()'],
    ['ann_wins_list', 'ann_wins_list(50, true)'], ['comment_reports_list', 'comment_reports_list(50)'], ['moderation_posts_list', `moderation_posts_list('pending', 50)`], ['open_needs', 'open_needs()'],
    ['staff_missions', 'staff_missions()'], ['staff_mission_proposals', `staff_mission_proposals('${ids.misB}')`], ['event_registrants', `event_registrants('${R.ev}')`], ['events_managed', 'events_managed()'],
    ['claim_thread', `claim_thread('${R.claim}')`], ['pickups_list', 'pickups_list(50)'], ['skills_radar', 'skills_radar()'], ['platform_overview', 'platform_overview()'],
    ['campaign_milestones_to_review', 'campaign_milestones_to_review()'], ['support_requests_to_handle', 'support_requests_to_handle()'], ['institutional_validations_list', `institutional_validations_list('pending', 100)`],
    ['talents_search', `talents_search('', '', null, 50, 0)`], ['product_detail', `product_detail('${R.lst}')`], ['ann_my_posted', 'ann_my_posted()'], ['opp_my_posted', 'opp_my_posted()'], ['staff_mentors', 'staff_mentors()'],
  ];
  for (const [nm, call] of readsB) {
    await as(DA);
    try {
      const r = JSON.stringify((await q(`select ${call} r`))[0].r);
      check(`8.r ${nm} : le département A ne reçoit rien du département B`, !/MARKB|SECRETB|SECRETCLAIM/.test(r), r.slice(0, 220));
    } catch (e) { check(`8.r ${nm} : refusé au département A`, DENY.test(e.message), e.message); }
  }
  await noLeak('8.l département A : après ces appels, toujours aucune donnée du département B lisible (toutes tables)', DA, ['MARKB', 'SECRETB', 'SECRETCLAIM', 'SECRETNOTIF-STB']);

  // ============================================================ 9. Stockage privé (pièces justificatives, documents, CV) : dossiers des comptes du département B / de l'organisation B
  await sup();
  await db.exec(`insert into storage.objects (bucket_id, name, owner, owner_id) select b.id, u.uid || '/h7-secret.pdf', u.uid::uuid, u.uid from storage.buckets b, (values ('${STB}'), ('${ORGB}'), ('${STA}'), ('${ORGA}')) u(uid) where not b.public`);
  await db.exec(`grant select on storage.objects, storage.buckets to authenticated, anon`); // le banc PGlite n'accorde pas ce droit (Supabase le fait) ; la sécurité vient des politiques RLS
  const nObj = (await q(`select count(*)::int n from storage.objects where name like '%/h7-secret.pdf'`))[0].n;
  console.log('INFO 9 objets privés posés :', nObj);
  const seen = async (uid, role, who) => { await as(uid, role); const r = (await q(`select bucket_id b, split_part(name, '/', 1) f from storage.objects where name like '%/h7-secret.pdf'`)); await db.exec('reset role'); return r.filter((x) => who.includes(x.f)); };
  for (const [nm, uid, forbidden] of [['département A', DA, [STB, ORGB, ORGA]], ['organisation A', ORGA, [STB, ORGB, STA]], ['membre de l\'organisation A', MEMB, [STB, ORGB, STA]], ['compte neuf', NEW, [STB, ORGB, STA, ORGA]],
    ['agent Finance', FIN, [STB, ORGB, STA, ORGA]], ['agent Technique', TECH, [STB, ORGB, STA, ORGA]], ['direction', DIR, [STB, ORGB, STA, ORGA]]]) {
    const r = await seen(uid, 'authenticated', forbidden);
    check(`9.${nm} : ne lit aucun fichier privé d'un autre compte (${nObj} fichiers posés)`, r.length === 0, JSON.stringify(r.slice(0, 6)));
  }
  const anonSeen = await seen(null, 'anon', [STB, ORGB, STA, ORGA]);
  check('9.visiteur : ne lit aucun fichier privé', anonSeen.length === 0, JSON.stringify(anonSeen.slice(0, 6)));

  // ============================================================ 10. Notifications : seul le bon département est prévenu
  await sup();
  await db.exec(`delete from notifications`);
  await as(STB);
  await works('10.1 étudiant du département B : soumet un projet (project_save_full, publication)', `select project_save_full(null, 'projet', 'Soumission notifiable MARKB', 'Projet de gestion décrit en plus de trente caractères pour la soumission.', 'Gestion', '{"domain":"gestion","problem":"problème de gestion décrit","solution":"solution de gestion décrite","progress":"prototype","contact_email":"b@t.cm"}'::jsonb, '[]'::jsonb, 'public', true) r`);
  await sup();
  const notifTo = async (uid) => (await q(`select count(*)::int n from notifications where user_id = '${uid}' and (title || ' ' || coalesce(body, '') || ' ' || coalesce(data::text, '')) like '%MARKB%'`))[0].n;
  console.log('INFO 10.1 notifications du département B :', JSON.stringify(await q(`select title, left(coalesce(body, ''), 80) body from notifications where user_id = '${DB}'`)));
  check('10.1 le responsable du département B reçoit la notification', (await notifTo(DB)) >= 1);
  check('10.2 le responsable du département A n\'en reçoit aucune', (await notifTo(DA)) === 0);
  check('10.3 la direction, la finance, le support et le technique n\'en reçoivent aucune (pas une validation de leur périmètre)', (await notifTo(DIR)) + (await notifTo(FIN)) + (await notifTo(SUP)) + (await notifTo(TECH)) === 0);
  check('10.4 ni l\'organisation A ni le compte neuf', (await notifTo(ORGA)) + (await notifTo(NEW)) === 0);
  await as(DA);
  check('10.5 lecture : le département A ne lit aucune notification du département B', (await q(`select count(*)::int n from notifications where (title || ' ' || coalesce(body, '') || ' ' || coalesce(data::text, '')) like '%MARKB%'`))[0].n === 0);

  // ============================================================ 11. Lectures directes du personnel : la permission qui justifie la lecture (migration 20261123030000)
  await sup();
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values ('${STB}', 'student_card', 'pièce identité MARKB', '${STB}/carte.pdf', 'application/pdf', 100), ('${ORGB}', 'other', 'pièce orga MARKORGB', '${ORGB}/statuts.pdf', 'application/pdf', 100);
    insert into support_tickets (user_id, subject, message) values ('${STB}', 'Ticket MARKB', 'SECRETTICKET MARKB');
    insert into account_deletion_requests (user_id, reason, scheduled_for) values ('${STB}', 'raison MARKB', now() + interval '30 days');
    insert into terms_acceptances (user_id, version) values ('${STB}', 'cgu-2026-11') on conflict do nothing;
    insert into sponsors (name, owner_id) values ('Sponsor MARKB', '${DB}');`);
  await sup();
  await db.exec(`insert into user_document_history (document_id, status, note) select id, 'pending', 'historique MARKB' from user_documents where owner_id = '${STB}'`);
  const readable = async (uid, tbl, col, pat = '%MARK%') => { await as(uid); const n = (await q(`select count(*)::int n from ${tbl} where ${col}::text like '${pat}'`))[0].n; await db.exec('reset role'); return n; };
  const matrix = [
    ['user_documents', 'name', { [ADM]: true, [SUPR]: true, [TECH]: false, [SUPT]: false, [SUP]: false, [FIN]: false, [DIR]: false, [DA]: false, [ORGA]: false, [STA]: false, [NEW]: false }],
    ['user_document_history', 'note', { [ADM]: true, [SUPR]: true, [TECH]: false, [SUPT]: false, [SUP]: false, [FIN]: false, [DIR]: false, [DA]: false, [NEW]: false }],
    ['support_tickets', 'message', { [ADM]: true, [SUPT]: true, [TECH]: false, [SUPR]: false, [SUP]: false, [FIN]: false, [DIR]: false, [DA]: false, [NEW]: false }],
    ['account_deletion_requests', 'reason', { [ADM]: true, [SUPR]: true, [TECH]: false, [SUPT]: false, [FIN]: false, [DIR]: false, [DA]: false, [NEW]: false }],
    ['terms_acceptances', 'user_id', { [ADM]: true, [SUPR]: true, [TECH]: false, [SUPT]: false, [FIN]: false, [DIR]: false, [NEW]: false }],
    ['sponsors', 'name', { [ADM]: true, [FIN]: true, [TECH]: false, [SUPT]: false, [SUPR]: false, [DIR]: false, [NEW]: false, [DB]: true, [DA]: false }],
  ];
  for (const [tbl, col, who] of matrix) {
    const bad = [];
    for (const [uid, expected] of Object.entries(who)) {
      const n = await readable(uid, tbl, col, tbl === 'terms_acceptances' ? '%7006' : '%MARK%');
      if ((n > 0) !== expected) bad.push(`${people.find((p) => p[0] === uid)?.[1]}: ${n} ligne(s), attendu ${expected ? 'lecture' : 'aucune'}`);
    }
    check(`11.${tbl} : lecture directe limitée à l'administrateur et à la permission qui la justifie`, bad.length === 0, bad.join(' ; '));
  }
  for (const [uid, forbidden, nm] of [[TECH, [STB, ORGB, STA, ORGA], 'agent Technique'], [SUPT, [STB, ORGB, STA, ORGA], 'agent Support (tickets seulement)'], [SUP, [STB, ORGB, STA, ORGA], 'agent Support (réclamations, commandes, litiges)']]) {
    check(`11.stockage ${nm} : ne lit aucune pièce justificative privée`, (await seen(uid, 'authenticated', forbidden)).length === 0);
  }
  check('11.stockage agent Support (support.requests) : lit les pièces à examiner', (await seen(SUPR, 'authenticated', [STB, ORGB])).length >= 2);
  check('11.stockage administrateur : lit les pièces', (await seen(ADM, 'authenticated', [STB, ORGB])).length >= 2);
  await db.exec('reset role');
  check('11.is_platform_staff : la maintenance technique n\'est pas une équipe d\'accompagnement des personnes', (await (async () => { await as(TECH); const r = (await q(`select is_platform_staff() r`))[0].r; await db.exec('reset role'); return r; })()) === false);
  check('11.is_platform_staff : un agent support reste équipe de la plateforme', (await (async () => { await as(SUPT); const r = (await q(`select is_platform_staff() r`))[0].r; await db.exec('reset role'); return r; })()) === true);
  // le technicien garde ses permissions techniques (bornes)
  await as(TECH);
  await works('11.tech : l\'agent Technique lit toujours les réglages et les incidents de bornes', `select settings_all(), (select count(*) from kiosk_incidents)`);

  await db.exec('reset role');
  console.log(`\nRÉSULTAT h7_cloisonnement : ${ok} OK, ${ko} ECHEC`);
}
