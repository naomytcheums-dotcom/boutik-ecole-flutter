// Scénario PGlite H13.2 (agent 6 : administration, sécurité, données).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_admin.mjs   (compter les lignes ECHEC / ERREUR : le code de sortie est toujours 0)
// A. log_audit : le client ne peut journaliser que des catégories non sensibles ; B. matrice acteur x objet (RLS, RPC, Storage).
let ok = 0, ko = 0;

export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('request.headers', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000132${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const root = async (sql) => { await db.exec('reset role'); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const succeeds = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, false, e.message); } };

  // comptes : 1 admin, 2 support, 3 finance, 4 client, 5 étudiant, 6 suspendu
  await db.exec('reset role');
  const roles = { 1: ['admin', 'Admin Global'], 2: ['support', 'Support'], 3: ['finance', 'Finance'], 4: ['client', 'Client'], 5: ['student', 'Etudiante'], 6: ['client', 'Suspendu'] };
  for (const [n, [r, nm]] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h132_${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','h132_${n}@t.cm')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${U(6)}'`);
  const [ADM, SUP, FIN, CLI, STU, SUS] = [1, 2, 3, 4, 5, 6].map(U);

  // ================================================================== A. log_audit
  const audit = async (uid, action, cat, level = 'Normal') => { await as(uid); try { await q(`select log_audit('${action}', 'cible', '${cat}', '${level}')`); return null; } catch (e) { return e.message; } };
  const count = async (action) => (await root(`select count(*)::int n from audit_log where action = '${action}'`))[0].n;

  for (const cat of ['Finances', 'Finance', 'Comptes', 'Paramètres', 'Réglages', 'Sécurité', 'Administration', 'Modération', 'Certificats', 'Suppressions', '']) {
    for (const [who, uid] of [['client', CLI], ['etudiant', STU], ['support', SUP], ['finance', FIN], ['admin', ADM]]) {
      await audit(uid, `FAUX ${who} ${cat}`, cat, 'Critique');
      check(`A1 ${who} : log_audit n ecrit pas la categorie « ${cat || '(vide)'} »`, await count(`FAUX ${who} ${cat}`) === 0);
    }
  }
  check('A1b categorie avec espaces/casse differente non contournee', (await audit(CLI, 'FAUX casse', 'finances')) === null && await count('FAUX casse') === 0);
  check('A1c categorie injectee (point-virgule) non ecrite', (await audit(CLI, 'FAUX inj', 'Connexions; Finances')) === null && await count('FAUX inj') === 0);
  check('A1d NULL non ecrit', await (async () => { await as(CLI); await q(`select log_audit('FAUX null', 'c', null, 'Normal')`); return (await count('FAUX null')) === 0; })());

  for (const [who, uid] of [['client', CLI], ['etudiant', STU], ['support', SUP], ['admin', ADM]]) {
    for (const cat of ['Connexions', 'Validations']) {
      const err = await audit(uid, `OK ${who} ${cat}`, cat);
      check(`A2 ${who} : categorie « ${cat} » journalisee`, err === null && await count(`OK ${who} ${cat}`) === 1, err);
    }
  }
  const row = (await root(`select actor, actor_id, level, category, origin from audit_log where action = 'OK client Connexions'`))[0];
  check('A3 acteur impose par le serveur, niveau plafonne, origine client', row.actor === 'Client' && row.actor_id === CLI && row.level === 'Normal' && row.origin === 'client', JSON.stringify(row));
  await audit(CLI, 'NIVEAU client', 'Connexions', 'Critique');
  await audit(SUP, 'NIVEAU support', 'Connexions', 'Critique');
  check('A3b client : niveau Critique ramene a Normal', (await root(`select level from audit_log where action = 'NIVEAU client'`))[0].level === 'Normal');
  check('A3b support : niveau sensible conserve', (await root(`select level from audit_log where action = 'NIVEAU support'`))[0].level === 'Critique');
  check('A4 compte suspendu : rien n est journalise', (await audit(SUS, 'FAUX suspendu', 'Connexions')) === null && await count('FAUX suspendu') === 0);
  await as(null, 'anon');
  await fails('A5 visiteur : log_audit refuse', `select log_audit('FAUX anon', 'c', 'Connexions', 'Normal')`, /permission denied/);
  check('A5 visiteur : aucune ligne', await count('FAUX anon') === 0);

  // les fonctions serveur continuent d'écrire les catégories sensibles (pas de régression) : suspension d'un compte par l'administrateur
  await as(ADM);
  await succeeds('A6 admin_set_account suspend un compte', `select admin_set_account('${U(4)}', 'client', true)`);
  const srv = (await root(`select category, level, origin from audit_log where action = 'Compte suspendu' order by id desc limit 1`))[0];
  check('A6 la suspension est journalisee par le serveur (Comptes, Sensible, origine serveur)', srv && srv.category === 'Comptes' && srv.level === 'Sensible' && srv.origin === null, JSON.stringify(srv));
  await as(ADM);
  await q(`select admin_set_account('${U(4)}', 'client', false)`);

  // quota quotidien des comptes ordinaires (200) toujours appliqué
  await db.exec('reset role');
  await db.exec(`insert into audit_log (actor, actor_id, action, target, category, level, origin) select 'Etudiante', '${STU}', 'bulk', '', 'Connexions', 'Normal', 'client' from generate_series(1, 200)`);
  await audit(STU, 'AU DELA du quota', 'Connexions');
  check('A7 plafond quotidien conserve pour un compte ordinaire', await count('AU DELA du quota') === 0);

  // ================================================================== B. STORAGE : TOUS les compartiments
  await db.exec('reset role');
  await db.exec(`grant select, insert, update, delete on storage.objects to anon, authenticated; grant select, insert, update, delete on storage.buckets to anon, authenticated`);
  const esc = (s) => s.replace(/'/g, "''");
  const SID = (n) => `00000000-0000-0000-0001-0000000132${String(n).padStart(2, '0')}`;
  const sess = async (uid, sid) => db.exec(`insert into auth.sessions (id, user_id) values ('${sid}', '${uid}') on conflict do nothing`);
  await sess(CLI, SID(1)); await sess(STU, SID(2)); await sess(SUS, SID(3)); await sess(ADM, SID(4));
  const stor = async (uid, sid, sql, role = 'authenticated') => {
    await db.exec('reset role');
    await db.exec(`select set_config('request.jwt.claims', '${esc(JSON.stringify(uid ? { sub: uid, role, session_id: sid } : { role: 'anon' }))}', false), set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`);
    await db.exec(`set role ${role}`);
    try { return { rows: await q(sql) }; } catch (e) { return { err: e.message }; }
  };
  const denied = (r) => r.err && /row-level security|permission denied/.test(r.err);
  const buckets = (await root(`select id, public from storage.buckets order by id`));
  console.log(`CONSTAT B1 ${buckets.length} compartiments : ${buckets.map((b) => b.id + (b.public ? '(public)' : '')).join(', ')}`);
  const pol = await root(`select polname, polcmd, polpermissive from pg_policy where polrelid = 'storage.objects'::regclass`);
  check('B1 la politique restrictive de session existe et couvre toutes les commandes', pol.some((p) => p.polname === 'H13.2 session ouverte' && !p.polpermissive && p.polcmd === '*'));

  // sessions : compte intact, session fermée, compte suspendu (session encore présente)
  const own = (b, n) => `insert into storage.objects (bucket_id, name, owner, owner_id) values ('${b}', '${n}', '${CLI}', '${CLI}')`;
  check('B2 session ouverte : depot dans son dossier (avatars)', !(await stor(CLI, SID(1), own('avatars', `${CLI}/a.png`))).err);
  check('B2 session fermee (id inconnu) : depot refuse', denied(await stor(CLI, SID(99), own('avatars', `${CLI}/b.png`))));
  check('B2 session fermee : suppression de son fichier sans effet', ((await stor(CLI, SID(99), `delete from storage.objects where name = '${CLI}/a.png' returning name`)).rows ?? []).length === 0);
  check('B2 session ouverte : suppression de son fichier', ((await stor(CLI, SID(1), `delete from storage.objects where name = '${CLI}/a.png' returning name`)).rows ?? []).length === 1);
  check('B2 compte suspendu (session presente) : depot refuse', denied(await stor(SUS, SID(3), `insert into storage.objects (bucket_id, name, owner, owner_id) values ('avatars', '${SUS}/c.png', '${SUS}', '${SUS}')`)));
  check('B2 un autre compte intact depose toujours', !(await stor(STU, SID(2), `insert into storage.objects (bucket_id, name, owner, owner_id) values ('avatars', '${STU}/d.png', '${STU}', '${STU}')`)).err);
  await db.exec('reset role');
  await db.exec(`insert into storage.objects (bucket_id, name, owner, owner_id) values ('profile-documents', '${CLI}/doc.pdf', '${CLI}', '${CLI}')`);
  check('B2 session ouverte : le proprietaire lit son document prive', ((await stor(CLI, SID(1), `select name from storage.objects where bucket_id = 'profile-documents'`)).rows ?? []).length === 1);
  check('B2 session fermee : le document prive n est plus lisible', ((await stor(CLI, SID(99), `select name from storage.objects where bucket_id = 'profile-documents'`)).rows ?? []).length === 0);
  check('B2 requete de service (claims service_role) ou sans revendication : la garde laisse passer', ((await stor(null, null, `select _session_is_live() ok`, 'anon')).rows ?? [{}])[0].ok === true && ((await stor(CLI, SID(99), `select _session_is_live() ok`)).rows ?? [{}])[0].ok === false);

  // chaque compartiment : un compte ordinaire ne dépose pas dans le dossier d'un autre ; un visiteur ne dépose nulle part ; les compartiments privés sont illisibles pour les tiers
  for (const b of buckets) {
    const foreign = `${STU}/intrus-${b.id}.png`;
    check(`B3 ${b.id} : un client ne depose pas dans le dossier d un autre compte`, denied(await stor(CLI, SID(1), `insert into storage.objects (bucket_id, name, owner, owner_id) values ('${b.id}', '${foreign}', '${CLI}', '${CLI}')`)));
    check(`B3 ${b.id} : un visiteur ne depose pas`, denied(await stor(null, null, `insert into storage.objects (bucket_id, name) values ('${b.id}', 'anon/x.png')`, 'anon')));
  }
  await db.exec('reset role');
  for (const b of buckets.filter((x) => !x.public)) {
    await db.exec(`reset role; insert into storage.objects (bucket_id, name, owner, owner_id, metadata) values ('${b.id}', '${STU}/prive-${b.id}.png', '${STU}', '${STU}', '{}'::jsonb)`);
    check(`B4 ${b.id} (prive) : un visiteur ne lit rien`, ((await stor(null, null, `select name from storage.objects where bucket_id = '${b.id}'`, 'anon')).rows ?? []).length === 0);
    check(`B4 ${b.id} (prive) : un client tiers ne lit pas le fichier d un autre compte`, ((await stor(CLI, SID(1), `select name from storage.objects where bucket_id = '${b.id}' and name like '${STU}/%'`)).rows ?? []).length === 0);
  }
  const pub = buckets.filter((b) => b.public).map((b) => b.id);
  const pubWrite = [];
  for (const id of pub) {
    const r = await stor(CLI, SID(1), `update storage.objects set metadata = '{"x":1}'::jsonb where bucket_id = '${id}' and name like '${STU}/%' returning name`);
    if ((r.rows ?? []).length) pubWrite.push(id);
  }
  check('B5 compartiments publics : un tiers ne modifie pas les fichiers d un autre compte', pubWrite.length === 0, pubWrite.join(', '));

  // ================================================================== C. MATRICE ACTEUR x OBJET (lignes d'un client, d'un étudiant)
  await db.exec('reset role');
  const extra = { 7: ['company', 'OrgA'], 8: ['company', 'OrgB'], 9: ['dept', 'DeptA'], 10: ['dept', 'DeptB'], 11: ['client', 'Autre'], 12: ['direction', 'Direction'], 13: ['support', 'Support sans droit'] };
  for (const [n, [r, nm]] of Object.entries(extra)) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h132_${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','h132_${n}@t.cm')`);
  const [ORGA, ORGB, DEPA, DEPB, AUTRE, DIR, SUP0] = [7, 8, 9, 10, 11, 12, 13].map(U);
  await db.exec(`
    insert into orders (number, buyer_id, subtotal, method) values ('#H132-1', '${CLI}', 1000, 'cod');
    insert into payment_transactions (reference, payer_id, kind, amount) values ('H132-R1', '${CLI}', 'order', 1000);
    insert into payout_batches (number, seller_id, amount) values ('H132-P1', '${STU}', 500);
    insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values ('${CLI}', 'student_card', 'c', '${CLI}/h132.png', 'image/png', 1);
    insert into notifications (user_id, kind, title) values ('${CLI}', 'k', 'h132 notification');
    insert into support_tickets (user_id, subject, message) values ('${CLI}', 'sujet test', 'message de test long');
    insert into device_tokens (token, user_id, platform) values ('tok-0123456789-abcdefghijklmnopqrstuvwxyz-0123456789', '${CLI}', 'android')`);
  await db.exec(`update admin_team_members set permissions = array['support.tickets'] where user_id = '${SUP}'; update admin_team_members set permissions = array['finance.payments', 'finance.read'] where user_id = '${FIN}'`);
  const seen = async (uid, role, sql) => { await as(uid, role); try { return (await q(sql))[0].n; } catch { return 'deny'; } };
  const T = {
    orders: `select count(*)::int n from orders where number = '#H132-1'`,
    payments: `select count(*)::int n from payment_transactions where reference = 'H132-R1'`,
    payouts: `select count(*)::int n from payout_batches where number = 'H132-P1'`,
    documents: `select count(*)::int n from user_documents where path = '${CLI}/h132.png'`,
    notifications: `select count(*)::int n from notifications where title = 'h132 notification'`,
    tickets: `select count(*)::int n from support_tickets where subject = 'sujet test'`,
    devices: `select count(*)::int n from device_tokens where user_id = '${CLI}'`,
    audit: `select count(*)::int n from audit_log where action = 'Compte suspendu'`,
    teams: `select count(*)::int n from admin_team_members where user_id <> '${ADM}' and user_id <> auth.uid()`,
  };
  // [orders, payments, payouts, documents, notifications, tickets, devices, audit, teams] : 1 = lit la ligne, 0 = rien, 'deny' = droit refuse
  const EXPECT = {
    anon: [0, 'deny', 'deny', 'deny', 'deny', 'deny', 'deny', 'deny', 'deny'],
    client: [1, 1, 0, 1, 1, 1, 1, 0, 0],
    autre: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    etudiant: [0, 0, 1, 0, 0, 0, 0, 0, 0],
    orgA: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    orgB: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    deptA: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    deptB: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    direction: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    supportSansDroit: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    supportTickets: [1, 0, 0, 0, 0, 1, 0, 0, 0],
    financePaiements: [1, 1, 1, 0, 0, 0, 0, 0, 0],
    admin: [1, 1, 1, 1, 0, 1, 0, 1, 3],
  };
  const actors = { anon: [null, 'anon'], client: [CLI], autre: [AUTRE], etudiant: [STU], orgA: [ORGA], orgB: [ORGB], deptA: [DEPA], deptB: [DEPB], direction: [DIR], supportSansDroit: [SUP0], supportTickets: [SUP], financePaiements: [FIN], admin: [ADM] };
  const names = Object.keys(T);
  for (const [label, [uid, role]] of Object.entries(actors)) {
    const got = [];
    for (const n of names) got.push(await seen(uid, role ?? 'authenticated', T[n]));
    check(`C1 ${label} : lignes visibles conformes au perimetre (${got.join(',')})`, JSON.stringify(got) === JSON.stringify(EXPECT[label]), `attendu ${EXPECT[label].join(',')}`);
  }
  // écritures : un compte ordinaire ne s'élève pas, ne modifie ni le rôle, ni la suspension, ni les droits d'équipe, ni les réglages
  for (const [label, uid] of [['client', CLI], ['etudiant', STU], ['organisation', ORGA], ['departement', DEPA], ['support', SUP], ['finance', FIN]]) {
    await as(uid);
    const attempts = [
      [`update profiles set role = 'admin' where id = '${uid}'`, 'devenir administrateur'],
      [`update profiles set suspended = false, certification = 'verified' where id = '${uid}'`, 'se certifier'],
      [`insert into admin_team_members (user_id, team_code, permissions) values ('${uid}', 'finance', array['finance.payments'])`, 's attribuer une equipe'],
      [`update admin_team_members set permissions = array['finance.payments'] where user_id = '${uid}'`, 'modifier ses droits'],
      [`update payment_transactions set status = 'paid' where reference = 'H132-R1'`, 'valider un paiement'],
      [`update payout_batches set status = 'paid' where number = 'H132-P1'`, 'payer un lot'],
      [`update orders set paid = true where number = '#H132-1'`, 'marquer payee'],
      [`insert into platform_settings (key, value) values ('h132', '1'::jsonb)`, 'ecrire un reglage'],
    ];
    for (const [sql, what] of attempts) {
      await as(uid);
      let blocked = false, changed = 0;
      try { await db.query('begin'); const r = await db.query(sql); changed = r.affectedRows ?? 0; } catch { blocked = true; }
      try { await db.query('rollback'); } catch { /* rien */ }
      check(`C2 ${label} : ne peut pas ${what}`, blocked || changed === 0, `lignes modifiees : ${changed}`);
    }
  }
  const roleNow = (await root(`select role::text r from profiles where id = '${CLI}'`))[0].r;
  check('C2b aucun role n a change apres les tentatives', roleNow === 'client' && (await root(`select count(*)::int n from profiles where role = 'admin'`))[0].n === 1);
  // ================================================================== E. EXPORTS ET RAPPORTS : qui appelle, que contient-il, est-ce journalise
  await db.exec('reset role');
  for (const [n, r, nm] of [[14, 'support', 'Support securite'], [15, 'support', 'Technique logs']]) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h132_${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','h132_${n}@t.cm')`);
  }
  const [SEC, TECH] = [14, 15].map(U);
  await db.exec(`update profiles set is_test = true where id = '${ORGA}'`);
  await db.exec(`update admin_team_members set team_code = 'security', permissions = array['security.reports', 'security.audit'] where user_id = '${SEC}'; update admin_team_members set team_code = 'tech', permissions = array['tech.logs'] where user_id = '${TECH}'`);
  await db.exec(`update profiles set phone = '+237690112233' where id = '${CLI}'`).catch(() => {});
  await db.exec(`
    insert into sponsors (id, name) values ('00000000-0000-0000-0002-000000013201', 'Sponsor H132');
    insert into sponsorships (sponsor_id, title, amount, students, department) values ('00000000-0000-0000-0002-000000013201', 'Bourse H132', 123456, 4, 'DeptA');
    insert into payout_batches (number, seller_id, amount, status, paid_on) values ('H132-P2', '${STU}', 700, 'verse', current_date);
    insert into conversations (id, created_by) values ('00000000-0000-0000-0004-000000013201', '${CLI}');
    insert into notifications (user_id, kind, title) values ('${AUTRE}', 'k', 'notification de AUTRE');`);
  await db.exec(`
    insert into conversation_participants (conversation_id, user_id) values ('00000000-0000-0000-0004-000000013201', '${CLI}');
    insert into messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0004-000000013201', '${CLI}', 'message prive H132');
    insert into message_reports (conversation_id, reporter_id, reason) select id, '${AUTRE}', 'abus H132' from conversations order by created_at desc limit 1`).catch((e) => console.log('CONSTAT E fixtures messages :', e.message));
  const SPONSOR = '00000000-0000-0000-0002-000000013201';
  const EA = { anon: [null, 'anon'], client: [CLI], etudiant: [STU], orgA: [ORGA], deptA: [DEPA], direction: [DIR], supportSansDroit: [SUP0], supportTickets: [SUP], finance: [FIN], securite: [SEC], technique: [TECH], admin: [ADM] };
  const tryCall = async (uid, role, sql) => { await as(uid, role ?? 'authenticated'); try { return { rows: await q(sql) }; } catch (e) { return { err: e.message }; } };
  const auditCount = async () => (await root(`select count(*)::int n from audit_log`))[0].n;
  // matrice : qui peut appeler quoi (true = autorise)
  const MATRIX = [
    ['admin_export_csv audit', `select admin_export_csv('audit', '{}'::jsonb) r`, { securite: 1, technique: 1, admin: 1 }],
    ['admin_export_csv rattachements', `select admin_export_csv('rattachements', '{"state":"all"}'::jsonb) r`, { admin: 1 }],
    ['admin_export_csv contestations', `select admin_export_csv('contestations', '{}'::jsonb) r`, { admin: 1 }],
    ['dept_report synthese', `select dept_report('synthese') r`, { direction: 1, admin: 1 }],
    ['dept_report etudiants', `select dept_report('etudiants') r`, { direction: 1, admin: 1 }],
    ['direction_consolidated_report', `select direction_consolidated_report() r`, { direction: 1, admin: 1 }],
    ['direction_finance_summary', `select direction_finance_summary(12) r`, { direction: 1, admin: 1 }],
    ['direction_sponsors_report', `select direction_sponsors_report() r`, { direction: 1, admin: 1 }],
    ['sponsor_report', `select sponsor_report('${SPONSOR}') r`, { finance: 1, admin: 1 }],
    ['message_reports_list', `select message_reports_list('open', 50) r`, { securite: 1, admin: 1 }],
    ['live_reports_list', `select live_reports_list(50) r`, { securite: 1, admin: 1 }],
    ['comment_reports_list', `select comment_reports_list(50) r`, { securite: 1, admin: 1, deptA: 1 }],
    ['social_moderation_summary', `select social_moderation_summary() r`, { securite: 1, admin: 1, deptA: 1 }],
    ['pool_export', `select pool_export() r`, { orgA: 1, deptA: 1, admin: 1 }],
    ['media_migration_report', `select media_migration_report() r`, {}],
    ['assessment_provider_health_report', `select assessment_provider_health_report('[]'::jsonb) r`, {}],
  ];
  const outcome = {};
  for (const [name, sql, allowed] of MATRIX) {
    const got = [];
    for (const [who, [uid, role]] of Object.entries(EA)) {
      const r = await tryCall(uid, role, sql);
      outcome[`${name}|${who}`] = r;
      const ok = !r.err;
      got.push(`${who}=${ok ? 'oui' : 'non'}`);
      check(`E1 ${name} : ${who} ${allowed[who] ? 'autorise' : 'refuse'}`, ok === !!allowed[who], r.err ?? 'a repondu');
    }
  }
  // anonyme : refus au niveau du droit d'execution
  for (const [name] of MATRIX) check(`E2 ${name} : anonyme refuse par droit d execution`, /permission denied/.test(outcome[`${name}|anon`].err ?? ''), outcome[`${name}|anon`].err);

  // contenu : aucun secret, aucun e-mail ni telephone complet hors besoin d'administration
  const csv = async (kind, f = '{}') => (await tryCall(ADM, 'authenticated', `select admin_export_csv('${kind}', '${f}'::jsonb) ->> 'csv' c`)).rows?.[0]?.c ?? '';
  const aud = await csv('audit');
  check('E3 export audit : en-tetes attendus, aucune adresse e-mail ni numero de telephone', /^"Date";"Acteur";"Action";"Cible";"Catégorie";"Niveau"/.test(aud) && !/@|\+237|6\d{8}/.test(aud.split('\r\n').slice(1).join('\n')), aud.slice(0, 200));
  const ratt = await csv('rattachements', '{"state":"all"}');
  check('E3b export rattachements : e-mail present mais reserve a l administrateur ; aucun hash ni secret', /@t\.cm/.test(ratt) && !/hash|secret|token|password/i.test(ratt));
  const mine = (await tryCall(CLI, 'authenticated', `select export_my_data() r`)).rows?.[0]?.r;
  const dump = JSON.stringify(mine ?? {});
  check('E4 export_my_data : donnees du titulaire seulement (rien de AUTRE)', !!mine && mine.compte === CLI && !/notification de AUTRE/.test(dump) && !dump.includes(AUTRE));
  check('E4b export_my_data : aucun jeton d appareil, hash ni secret', !/tok-0123456789/.test(dump) && !/"(token|token_hash|code_hash|secret|pickup_code|access_token|refresh_token|p256dh|auth)"\s*:/.test(dump));
  const pe = (await tryCall(ORGA, 'authenticated', `select pool_export() r`)).rows?.[0]?.r;
  check('E5 pool_export : ni e-mail ni telephone dans les colonnes', !!pe && !/e-?mail|t[ée]l[ée]phone/i.test(pe.csv.split('\r\n')[0]) && !/@/.test(pe.csv));
  const st = (await tryCall(STU, 'authenticated', `select seller_money_statement() r`)).rows?.[0]?.r;
  const stc = (await tryCall(CLI, 'authenticated', `select seller_money_statement() r`)).rows?.[0]?.r;
  check('E6 releve vendeur : le versement H132-P2 n apparait que chez son beneficiaire', JSON.stringify(st ?? {}).includes('H132-P2') && !JSON.stringify(stc ?? {}).includes('H132-P2'), JSON.stringify(stc).slice(0, 200));
  const stm = (await tryCall(CLI, 'authenticated', `select seller_statement() r`)).rows?.[0]?.r;
  check('E6b releve des ventes : vide pour un compte sans vente', !!stm && (stm.sales ?? []).length === 0);
  const msgList = (await tryCall(SEC, 'authenticated', `select message_reports_list('open', 50) r`)).rows?.[0]?.r ?? [];
  console.log(`CONSTAT E message_reports_list : ${msgList.length} signalement(s), ${(msgList[0]?.messages ?? []).length} message(s) prive(s) montres`);
  // un compte sans organisation (departement, administrateur) n obtient que son propre vivier : vide\n  for (const [who, uid] of [['departement', DEPA], ['administrateur', ADM]]) {\n    const r = await tryCall(uid, 'authenticated', `select pool_export() r`);\n    check(`E7b pool_export  : ne contient aucun talent d une organisation`, !!r.rows && r.rows[0].r.count === 0, r.err);\n  }\n  for (const [who, uid, exp] of [['support', SUP, 0], ['securite', SEC, 0], ['finance', FIN, 1], ['client', CLI, 0]]) {\n    const r = await tryCall(uid, 'authenticated', `select count(*)::int n from sponsorships`);\n    check(`E7c table sponsorships :  lit  contribution`, !r.err && r.rows[0].n === exp, r.err);\n  }\n  // filtres de l'export : la file d'un autre perimetre ne fuit pas (organisation B ne voit pas la liste de A)
  const rl = (await tryCall(ORGB, 'authenticated', `select pool_export('00000000-0000-0000-0003-000000013299') r`));
  check('E7 pool_export : une liste inexistante / d une autre organisation est refusee', !!rl.err || (rl.rows[0].r.count === 0), rl.err);

  // journalisation : chaque export/rapport sensible laisse une trace attribuable
  const traced = async (name, uid, sql, re) => {
    const last = (await root(`select coalesce(max(id), 0)::bigint m from audit_log`))[0].m;
    const r = await tryCall(uid, 'authenticated', sql);
    const rows = await root(`select actor_id, action, category, level from audit_log where id > ${last} order by id`);
    check(`E8 ${name} : acces journalise`, !r.err && rows.some((x) => re.test(x.action) && (x.actor_id === uid || x.actor_id === null)), `${r.err ?? ''} ${JSON.stringify(rows)}`);
  };
  await traced('admin_export_csv audit', ADM, `select admin_export_csv('audit') r`, /Export CSV/);
  await traced('dept_report', DIR, `select dept_report('synthese') r`, /Rapport de département/);
  await traced('pool_export', ORGA, `select pool_export() r`, /Export CSV du vivier/);
  await traced('export_my_data', CLI, `select export_my_data() r`, /Export de mes données/);
  await db.exec(`insert into auth.users(id,email) values ('${U(16)}','h132_16@t.cm'); insert into profiles(id,name,role,email) values ('${U(16)}','Support securite 2','support','h132_16@t.cm'); update admin_team_members set team_code = 'security', permissions = array['security.reports'] where user_id = '${U(16)}'`);
  await traced('message_reports_list (messages prives)', U(16), `select message_reports_list('open', 50) r`, /signalements de messages/);
  const n2 = (await root(`select count(*)::int n from audit_log where action = 'Lecture des signalements de messages'`))[0].n;
  await tryCall(U(16), 'authenticated', `select message_reports_list('open', 50) r`);
  check('E8b message_reports_list : une seule ligne par tranche de 10 minutes', (await root(`select count(*)::int n from audit_log where action = 'Lecture des signalements de messages'`))[0].n === n2);
  await traced('direction_consolidated_report', DIR, `select direction_consolidated_report() r`, /Rapport consolidé/);

  // ================================================================== D. REJEU DES MIGRATIONS H13.2 (idempotence)
  const fs = await import('fs'); const path = await import('path'); const { fileURLToPath } = await import('url');
  const migDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations');
  const snap = async () => (await root(`select (select count(*) from pg_proc where pronamespace = 'public'::regnamespace)::int f, (select count(*) from pg_policy)::int p, (select count(*) from audit_log)::int a`))[0];
  const s1 = await snap();
  let rej = true;
  for (const f of ['20261130060000_h132_log_audit_categories_client.sql', '20261130060100_h132_storage_session_ouverte.sql', '20261130060300_h132_exports_rapports_acces.sql']) {
    try { await db.exec('reset role'); await db.exec(fs.readFileSync(path.join(migDir, f), 'utf8')); await db.exec(fs.readFileSync(path.join(migDir, f), 'utf8')); } catch (e) { rej = false; console.log(f, e.message); }
  }
  check('D1 migrations H13.2 rejouees deux fois : sans erreur ni effet de bord', rej && JSON.stringify(s1) === JSON.stringify(await snap()));

  console.log(`h132_admin : ${ok} OK, ${ko} ECHEC`);
}


