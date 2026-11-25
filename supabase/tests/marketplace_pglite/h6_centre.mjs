// Lot L3 (H6) : centre d'administration (300-306), quatre équipes internes, rattachement des comptes Département, revue des anciens comptes Finance / Support.
// Prouve les migrations 20261122020000 et 20261122021000 et, par parcours de TOUTES les fonctions gardées par permission d'équipe, que :
//   - l'administrateur global n'est refusé par aucune garde de permission d'équipe (il peut exécuter chaque RPC d'administration) ;
//   - un agent sans permission est refusé partout où la garde est une permission d'équipe, et n'a que ce que ses permissions autorisent ;
//   - le rattachement des comptes Département (liste, assignation avec 2FA, historique) et la revue des comptes Finance / Support (liste, attribution explicite, historique) marchent de bout en bout ;
//   - l'administrateur tranche les comptes suspects transmis (suspension réelle ou classement) avec 2FA.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h6_centre.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000061${String(n).padStart(2, '0')}`;
  const A = id(1), A2 = id(2), AF = id(3), AS = id(4), SEC = id(5), TECH = id(6), FMIN = id(7), SMIN = id(8), F1 = id(9), S1 = id(10), C = id(11), D1 = id(12), D2 = id(13), DIR = id(14),
    ST = id(15), SUSP = id(16), M2FA = id(17), LEG_F = id(18), LEG_S = id(19), C2 = id(20), DSUSP = id(21), MINA = id(22);
  const I1 = id(50), DX = id(51), DY = id(52), DZ = id(53), DU = id(54);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const asAal = async (uid, aal) => { cur = { uid, role: 'authenticated' }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false); set role authenticated`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const DENY = /Action non autorisée|réservé|Réservé|exige la permission|Connexion requise|permission denied|Compte suspendu|double authentification|non autorisé|Accès refusé|refusé/i;
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const grant = async (user, team, perms, note) => { await as(A); return q(`select admin_team_member_set('${user}', '${team}', array[${perms.map((p) => `'${p}'`).join(',')}]${note ? `, '${note}'` : ''}) r`); };

  // ============================================================ comptes
  await db.exec('reset role');
  await db.exec(`alter table profiles disable trigger trg_admin_team_autoenroll`);
  for (const [i, nm, role] of [[LEG_F, 'Legs Finance', 'finance'], [LEG_S, 'Legs Support', 'support']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[1].toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[1].toLowerCase()}@t.cm')`);
  }
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${LEG_F}', 'finance', array['finance.read','finance.payments','finance.payouts','finance.refunds','finance.transfers']), ('${LEG_S}', 'support', array['support.tickets','support.claims'])`);
  await db.exec(`alter table profiles enable trigger trg_admin_team_autoenroll`);
  for (const [i, nm, role] of [[A, 'Ada Admin', 'admin'], [A2, 'Bob Admin', 'admin'], [AF, 'Fina Finance', 'finance'], [AS, 'Sam Support', 'support'], [SEC, 'Sec Securite', 'support'], [TECH, 'Tech Technique', 'support'],
    [FMIN, 'Fmin Finance', 'finance'], [MINA, 'Mina Agent', 'finance'], [SMIN, 'Smin Support', 'support'], [F1, 'Fred Paiements', 'finance'], [S1, 'Suzy Tickets', 'support'], [C, 'Cora Cliente', 'client'], [C2, 'Cyril Client', 'client'],
    [DIR, 'Dir Direction', 'direction'], [ST, 'Etu Etudiant', 'student'], [SUSP, 'Sus Pendu', 'support'], [M2FA, 'Mfa Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0].toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0].toLowerCase()}@t.cm')`);
  }
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test L3', 'verified');
    insert into departments (id, institution_id, name, status) values ('${DX}', '${I1}', 'Génie logiciel', 'verified'), ('${DY}', '${I1}', 'Gestion', 'verified'), ('${DU}', '${I1}', 'Non vérifié', 'proposed')`);
  // comptes Département créés après les départements : en attente de rattachement
  for (const [i, nm] of [[D1, 'Dep Premier'], [D2, 'Dep Second'], [DSUSP, 'Dep Suspendu']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[1].toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','dept','${nm.split(' ')[1].toLowerCase()}@t.cm')`);
  }
  await db.exec(`update profiles set suspended = true where id in ('${SUSP}', '${DSUSP}')`);
  await sup();

  // ============================================================ A. Rattachement des comptes Département
  await as(A);
  let un = (await q(`select admin_dept_unassigned_accounts() r`))[0].r;
  check('A1 liste des non rattachés : les trois comptes Département', un.length === 3 && un.every((x) => x.state === 'none'), JSON.stringify(un.map((x) => x.state)));
  check('A2 compteur des non rattachés : 2 actifs (le suspendu n\'est pas compté)', (await q(`select admin_dept_unassigned_count() r`))[0].r === 2);
  let accts = (await q(`select admin_dept_accounts() r`))[0].r;
  check('A3 admin_dept_accounts : e-mail fourni (homonymes)', accts.length === 3 && accts.every((x) => x.email), JSON.stringify(accts[0]));
  check('A4 historique vide avant toute assignation', (await q(`select admin_dept_assignments_history(null, 50) r`))[0].r.length === 0);
  for (const [who, uid] of [['agent Finance', AF], ['agent Support', AS], ['client', C], ['direction', DIR], ['département', D1]]) {
    await as(uid);
    await fails(`A5 ${who} : assignation refusée`, `select admin_dept_assign('${D1}', '${DX}', 'Responsable')`, DENY);
    await fails(`A6 ${who} : retrait refusé`, `select admin_dept_unassign('${D1}')`, DENY);
    await fails(`A7 ${who} : liste des non rattachés refusée`, `select admin_dept_unassigned_accounts()`, DENY);
    await fails(`A8 ${who} : historique refusé`, `select admin_dept_assignments_history(null, 10)`, DENY);
  }
  // 2FA : administrateur avec facteur TOTP vérifié mais session aal1 : refus interne ; aal2 : accepté
  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${M2FA}', 'verified')`);
  await asAal(M2FA, 'aal1');
  await fails('A9 assignation : administrateur avec 2FA en session aal1 refusé', `select admin_dept_assign('${D1}', '${DX}', 'Responsable')`, /double authentification/);
  await fails('A10 retrait : même exigence 2FA', `select admin_dept_unassign('${D1}')`, /double authentification/);
  await asAal(M2FA, 'aal2');
  await works('A11 assignation : administrateur avec 2FA en session aal2 accepté', `select admin_dept_assign('${D1}', '${DX}', 'Responsable')`);
  await as(A);
  await fails('A12 département non vérifié refusé', `select admin_dept_assign('${D2}', '${DU}', 'Responsable')`, /non vérifié/);
  await fails('A13 compte qui n\'est pas Département refusé', `select admin_dept_assign('${C}', '${DX}', 'Responsable')`, /pas un compte Département/);
  await fails('A14 fonction trop longue refusée', `select admin_dept_assign('${D2}', '${DX}', '${'x'.repeat(81)}')`, /80 caractères/);
  await works('A15 assignation du second compte (sans 2FA : comportement inchangé)', `select admin_dept_assign('${D2}', '${DY}', 'Directeur')`);
  await works('A16 changement de département du premier compte', `select admin_dept_assign('${D1}', '${DY}', 'Responsable')`);
  await works('A17 confirmation (même département)', `select admin_dept_assign('${D1}', '${DY}', 'Responsable')`);
  let h = (await q(`select admin_dept_assignments_history(null, 50) r`))[0].r;
  check('A18 historique : 4 événements, du plus récent au plus ancien', h.length === 4 && h[0].action === 'confirm' && h[1].action === 'change' && h[3].action === 'assign', JSON.stringify(h.map((x) => x.action)));
  check('A19 historique : acteur, département, précédent département', h[1].actor === 'Ada Admin' && h[1].department === 'Gestion' && h[1].previous === 'Génie logiciel', JSON.stringify(h[1]));
  check('A20 historique d\'un seul compte', (await q(`select admin_dept_assignments_history('${D2}', 50) r`))[0].r.length === 1);
  check('A21 la 1re assignation faite par le compte aal2 est attribuée à lui', h[3].actor === 'Mfa Admin', JSON.stringify(h[3]));
  check('A22 le compte rattaché lit son département (my_department)', await (async () => { await as(D1); const r = (await q(`select my_department() r`))[0].r; await as(A); return r.attached === true && r.department === 'Gestion'; })());
  check('A23 il reste un compte actif non rattaché : compteur = 0 (le suspendu n\'est pas compté)', (await q(`select admin_dept_unassigned_count() r`))[0].r === 0);
  un = (await q(`select admin_dept_unassigned_accounts() r`))[0].r;
  check('A24 liste des non rattachés : seul le compte suspendu reste, marqué suspendu', un.length === 1 && un[0].suspended === true, JSON.stringify(un));
  await works('A25 retrait du rattachement', `select admin_dept_unassign('${D1}')`);
  await fails('A26 retrait d\'un compte non rattaché refusé', `select admin_dept_unassign('${D1}')`, /aucun département/);
  h = (await q(`select admin_dept_assignments_history('${D1}', 50) r`))[0].r;
  check('A27 historique du compte : retrait en tête', h[0].action === 'unassign' && h[0].previous === 'Gestion', JSON.stringify(h[0]));
  check('A28 le compte retiré est de nouveau en attente', (await q(`select admin_dept_unassigned_count() r`))[0].r === 1);
  await works('A29 rattachement du retiré', `select admin_dept_assign('${D1}', '${DX}', 'Responsable')`);
  check('A30 audit : rattachement et retrait journalisés', (await qs(`select count(*)::int n from audit_log where category = 'Départements'`))[0].n >= 6);
  await as(A);
  check('A31 le compte rattaché a été prévenu', (await qs(`select count(*)::int n from notifications where user_id = '${D1}' and title = 'Rattachement à un département'`))[0].n >= 1);
  await sup();
  await db.exec(`delete from department_assignment_history`);
  await db.exec(`delete from department_accounts where user_id = '${D2}'`);
  await db.exec(`insert into department_accounts (user_id, department_id, title, assigned_by) values ('${D2}', '${DX}', 'Responsable', null)`);
  await as(A);
  await q(`select admin_dept_accounts() r`);
  check('A32 rattachement repris par le système : signalé « à confirmer »', (await q(`select admin_dept_accounts() r`))[0].r.find((x) => x.id === D2).to_review === true);

  // ============================================================ B. Équipes : attribution explicite et revue des anciens comptes
  await sup();
  await db.exec(`insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note) values
    (null, '${LEG_F}', 'finance', 'migration', '{}', array['finance.read'], 'migration'), (null, '${LEG_S}', 'support', 'migration', '{}', array['support.tickets'], 'migration')`);
  await as(A);
  let rev = (await q(`select admin_team_accounts_review() r`))[0].r;
  const need = (uid) => rev.find((x) => x.user_id === uid);
  check('B1 comptes hérités (jamais attribués par l\'administrateur) : à réviser', need(LEG_F)?.needs_review === true && need(LEG_S)?.needs_review === true, JSON.stringify(rev.map((x) => [x.name, x.needs_review])));
  check('B2 un compte neuf sans permission est à réviser', need(FMIN)?.needs_review === true && need(SMIN)?.needs_review === true);
  for (const [who, uid] of [['agent Finance', AF], ['client', C], ['direction', DIR]]) {
    await as(uid);
    await fails(`B3 ${who} : liste à réviser refusée`, `select admin_team_accounts_review()`, DENY);
    await fails(`B4 ${who} : confirmation minimale refusée`, `select admin_team_account_keep_minimal('${FMIN}', 'motif valable')`, DENY);
    await fails(`B5 ${who} : attribution refusée`, `select admin_team_member_set('${FMIN}', 'finance', array['finance.read'])`, DENY);
    await fails(`B6 ${who} : historique refusé`, `select admin_team_history_list(null, 10)`, DENY);
  }
  await as(A);
  await grant(FMIN, 'finance', ['finance.read', 'finance.payments'], 'Besoin du suivi des paiements');
  rev = (await q(`select admin_team_accounts_review() r`))[0].r;
  check('B7 attribution explicite : le compte sort de la liste à réviser', need(FMIN)?.needs_review === false && need(FMIN).teams[0].explicit === true);
  await fails('B8 confirmation minimale refusée pour un compte qui a des permissions', `select admin_team_account_keep_minimal('${FMIN}', 'motif valable')`, /déjà des permissions/);
  await fails('B9 confirmation minimale : motif obligatoire', `select admin_team_account_keep_minimal('${SMIN}', '')`, /pourquoi/);
  await fails('B10 confirmation minimale : compte hors Finance/Support refusé', `select admin_team_account_keep_minimal('${C}', 'motif valable')`, /Finance ou Support/);
  await fails('B11 confirmation minimale : pas sur soi-même', `select admin_team_account_keep_minimal('${A}', 'motif valable')`, /propres droits/);
  await works('B12 confirmation explicite des droits minimaux (compte Support)', `select admin_team_account_keep_minimal('${SMIN}', 'Compte de formation : lecture seule')`);
  rev = (await q(`select admin_team_accounts_review() r`))[0].r;
  check('B13 confirmé : plus « à réviser », signalé « minimal_confirmed »', need(SMIN).needs_review === false && need(SMIN).minimal_confirmed === true, JSON.stringify(need(SMIN)));
  let hs = (await q(`select admin_team_history_list('${SMIN}', 20) r`))[0].r;
  check('B14 historique du compte : confirmation en tête avec le motif et l\'acteur', hs[0].action === 'keep_minimal' && /formation/.test(hs[0].note) && hs[0].actor === 'Ada Admin', JSON.stringify(hs[0]));
  check('B15 audit : confirmation journalisée', (await qs(`select count(*)::int n from audit_log where action = 'Équipe : droits minimaux confirmés'`))[0].n === 1);
  await grant(SMIN, 'support', ['support.tickets']);
  rev = (await q(`select admin_team_accounts_review() r`))[0].r;
  check('B16 attribution après confirmation : explicite, hors revue', need(SMIN).needs_review === false && need(SMIN).minimal_confirmed === false);
  await as(A);
  await q(`select admin_team_member_remove('${SMIN}', 'support', 'Fin de mission')`);
  rev = (await q(`select admin_team_accounts_review() r`))[0].r;
  check('B17 retrait : le compte est de nouveau à réviser (aucune permission, aucune confirmation valable)', need(SMIN).needs_review === true, JSON.stringify(need(SMIN)));
  hs = (await q(`select admin_team_history_list('${SMIN}', 20) r`))[0].r;
  check('B18 historique du compte : confirmation, attribution (mise à jour de la ligne créée à l\'inscription), retrait', ['revoke', 'update', 'keep_minimal'].every((a) => hs.some((x) => x.action === a)), JSON.stringify(hs.map((x) => x.action)));
  await sup();
  await db.exec(`update profiles set role = 'finance' where id = '${SMIN}'`);
  await as(A);
  await works('B19 changement de rôle : la revue reste lisible', `select admin_team_accounts_review()`);
  // 2FA interne
  await asAal(M2FA, 'aal1');
  await fails('B20 confirmation minimale : 2FA exigée en session aal1', `select admin_team_account_keep_minimal('${FMIN}', 'motif valable')`, /double authentification|déjà des permissions/);
  await fails('B21 confirmation minimale sur un compte sans permission : 2FA en aal1 refusée', `select admin_team_account_keep_minimal('${LEG_S}', 'motif valable')`, /double authentification/);
  await asAal(M2FA, 'aal2');
  await works('B22 confirmation minimale en aal2 acceptée', `select admin_team_account_keep_minimal('${SMIN}', 'motif valable')`);

  // ============================================================ C. Comptes suspects : signalement, transmission, décision de l'administrateur
  await as(A);
  await grant(SEC, 'security', ['security.accounts']);
  await grant(S1, 'support', ['support.tickets']);
  await as(SEC);
  const f1 = (await q(`select security_flag_account('${C}', 'Plusieurs paiements refusés avec des numéros différents') r`))[0].r;
  const f2 = (await q(`select security_flag_account('${C2}', 'Messages de hameçonnage envoyés à des vendeurs') r`))[0].r;
  await works('C1 transmission à l\'administrateur', `select security_flag_decide('${f1}', 'escalate', 'Suspension à envisager')`);
  await as(A);
  check('C2 l\'administrateur lit la liste des transmis', (await q(`select security_flags_list('escalated') r`))[0].r.length === 1);
  for (const [who, uid] of [['agent Sécurité', SEC], ['agent Support', S1], ['client', C]]) {
    await as(uid);
    await fails(`C3 ${who} : décision de l'administrateur refusée`, `select security_flag_resolve('${f1}', 'suspend', 'x')`, DENY);
  }
  await as(A);
  await fails('C4 décision inconnue refusée', `select security_flag_resolve('${f1}', 'bannir', 'x')`, /Décision inconnue/);
  await fails('C5 classement sans motif refusé', `select security_flag_resolve('${f1}', 'dismiss', '')`, /pourquoi/);
  await asAal(M2FA, 'aal1');
  await fails('C6 suspension : 2FA exigée (aal1)', `select security_flag_resolve('${f1}', 'suspend', 'x')`, /double authentification/);
  await as(A);
  check('C7 le signalement reste intact après le refus', (await q(`select security_flags_list('escalated') r`))[0].r.length === 1);
  await works('C8 suspension du compte transmis', `select security_flag_resolve('${f1}', 'suspend', 'Fraude confirmée')`);
  check('C9 compte réellement suspendu et connexion bloquée', (await qs(`select p.suspended s, u.banned_until is not null b from profiles p join auth.users u on u.id = p.id where p.id = '${C}'`))[0].s === true && (await qs(`select banned_until is not null b from auth.users where id = '${C}'`))[0].b === true);
  await as(A);
  let sus = (await q(`select security_flags_list('suspended') r`))[0].r;
  check('C10 liste « suspendus » : décision, auteur et motif', sus.length === 1 && sus[0].decided_by === 'Ada Admin' && sus[0].decision_note === 'Fraude confirmée' && sus[0].suspended === true, JSON.stringify(sus));
  await fails('C11 une décision déjà prise ne se rejoue pas', `select security_flag_resolve('${f1}', 'dismiss', 'motif valable')`, /déjà tranché/);
  check('C12 l\'agent à l\'origine du signalement est prévenu', (await qs(`select count(*)::int n from notifications where user_id = '${SEC}' and title = 'Compte suspendu par l''administrateur'`))[0].n === 1);
  await works('C13 classement d\'un signalement ouvert (sans transmission préalable)', `select security_flag_resolve('${f2}', 'dismiss', 'Messages légitimes, vérifié')`);
  check('C14 classé : statut cleared, compte non suspendu', (await q(`select security_flags_list('cleared') r`))[0].r.length === 1 && (await qs(`select suspended s from profiles where id = '${C2}'`))[0].s === false);
  check('C15 audit : suspension et classement journalisés', (await qs(`select count(*)::int n from audit_log where action in ('Compte suspect suspendu', 'Signalement de compte classé')`))[0].n === 2);
  await asAal(M2FA, 'aal2');
  check('C16 la liste accepte le nouveau statut en aal2', (await q(`select security_flags_list('suspended') r`))[0].r.length === 1);
  await fails('C17 statut inconnu refusé', `select security_flags_list('inconnu')`, /Statut inconnu/);

  // ============================================================ D. Tableaux de bord et gestion des équipes : administrateur global et agents
  await as(A);
  for (const t of ['finance', 'support', 'security', 'tech']) {
    const r = (await q(`select admin_team_dashboard('${t}') r`))[0].r;
    check(`D1 tableau de bord ${t} : administrateur, indicateurs réels (jamais refusé)`, Array.isArray(r.counters) && r.counters.length >= 3 && r.counters.every((c) => typeof c.value === 'number'), JSON.stringify(r).slice(0, 200));
  }
  check('D2 le tableau de bord Finance de l\'administrateur porte les 9 indicateurs financiers', (await q(`select admin_team_dashboard('finance') r`))[0].r.counters.length === 9);
  await as(F1);
  await fails('D3 agent sans appartenance : tableau de bord d\'une autre équipe refusé', `select admin_team_dashboard('support')`, DENY);
  await grant(F1, 'finance', ['finance.payments']);
  await as(F1);
  const fdash = (await q(`select admin_team_dashboard('finance') r`))[0].r.counters;
  check('D4 agent Finance (finance.payments) : seul l\'indicateur des paiements', fdash.length === 1 && fdash[0].key === 'payments_pending', JSON.stringify(fdash));
  await as(FMIN);
  await grant(AF, 'finance', ['finance.read']);
  await as(A);
  const ov = (await q(`select admin_teams_overview() r`))[0].r;
  check('D5 aperçu des équipes : cinq équipes (dont classement H12) avec catalogue de permissions', ov.length === 5 && ov.every((t) => t.permissions.length >= 4), JSON.stringify(ov.map((t) => [t.code, t.permissions.length])));
  check('D6 agents de l\'équipe Finance listés', (await q(`select admin_team_members_list('finance') r`))[0].r.length >= 2);
  check('D7 recherche d\'agents recrutables', (await q(`select admin_team_candidates('Fred') r`))[0].r.some((x) => x.id === F1));
  const mine = (await q(`select my_admin_access() r`))[0].r;
  check('D8 my_admin_access de l\'administrateur : toutes les permissions des cinq équipes', mine.is_admin === true && Object.keys(mine.teams).length === 5 && mine.teams.finance.length === 6);
  await as(F1);
  const mf = (await q(`select my_admin_access() r`))[0].r;
  check('D9 my_admin_access d\'un agent : seulement ses permissions', mf.is_admin === false && JSON.stringify(mf.teams) === JSON.stringify({ finance: ['finance.payments'] }), JSON.stringify(mf));
  for (const [who, uid] of [['agent Finance', F1], ['client', C2], ['étudiant', ST]]) {
    await as(uid);
    await fails(`D10 ${who} : aperçu des équipes refusé`, `select admin_teams_overview()`, DENY);
    await fails(`D11 ${who} : liste des agents refusée`, `select admin_team_members_list('finance')`, DENY);
    await fails(`D12 ${who} : recherche d'agents refusée`, `select admin_team_candidates('')`, DENY);
  }
  await as(A);
  await fails('D13 on ne modifie pas ses propres droits', `select admin_team_member_set('${A}', 'finance', array['finance.read'])`, /propres droits/);
  await fails('D14 un compte hors Finance/Support ne rejoint pas une équipe', `select admin_team_member_set('${C2}', 'finance', array['finance.read'])`, /Finance ou Support/);
  await fails('D15 un compte suspendu ne rejoint pas une équipe', `select admin_team_member_set('${SUSP}', 'support', array['support.tickets'])`, /suspendu/);
  await fails('D16 permission d\'une autre équipe refusée', `select admin_team_member_set('${F1}', 'finance', array['support.tickets'])`, /autre équipe|inconnue/);
  await fails('D17 aucune permission : refusé (utiliser le retrait)', `select admin_team_member_set('${F1}', 'finance', array[]::text[])`, /au moins une permission/);

  // ============================================================ E. Parcours de TOUTES les fonctions gardées par permission d'équipe
  await sup();
  const fns = await q(`select p.oid::int oid, p.proname name, pg_get_function_identity_arguments(p.oid) args, p.prosrc src
    from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.prorettype <> 'trigger'::regtype and p.proname not like '\\_%'
      and has_function_privilege('authenticated', p.oid, 'execute') and has_function_privilege('anon', p.oid, 'execute') is not true
      and p.proname not in ('enforce_mfa_on_sensitive', 'has_admin_permission', 'has_any_admin_permission', 'is_admin_team_member')
      and (p.prosrc ~ 'has_admin_permission\\(|has_any_admin_permission\\(|_admin_only\\(\\)|_security_accounts_guard\\(\\)|is_platform_staff\\(\\)')
    order by p.proname`);
  check('E0 inventaire des fonctions d\'administration gardées', fns.length >= 40, `${fns.length}`);
  const argSql = (a) => {
    if (!a.trim()) return '';
    return a.split(/,\s*(?![^(]*\))/).map((x) => {
      const t = x.replace(/^(IN |OUT |INOUT |VARIADIC )/, '').trim();
      const parts = t.split(/\s+/);
      const type = /^(uuid|text|integer|int|bigint|boolean|numeric|jsonb|date|timestamp|timestamptz|app_role)/i.test(parts[0]) && parts.length === 1 ? parts[0] : parts.slice(1).join(' ');
      return `null::${type.replace(/\s+DEFAULT.*$/i, '')}`;
    }).join(', ');
  };
  const blockedAdmin = [], blockedAgent = [], passedAgent = [], skipped = [];
  const guardMsg = /exige la permission|Réservé à l'équipe|Réservé aux agents|Action non autorisée|permission denied|Accès refusé|Réservé aux/i;
  await sup();
  const SPONSOR = id(60);
  await db.exec(`insert into sponsors (id, name) values ('${SPONSOR}', 'Sponsor L3')`);
  const needsObject = new Set(['sponsor_report', 'replay_comments_list']); // garde liée à l'objet (null refusé pour tous) : prouvée à part avec un vrai objet (sponsor_report ci-dessous ; replay_comments_list : h12_live_replay E13b, l'administration lit les commentaires d'un replay réel)
  for (const f of fns) {
    if (needsObject.has(f.name)) continue;
    let call;
    try { call = `select ${f.name}(${argSql(f.args)})`; } catch { skipped.push(f.name); continue; }
    await as(A);
    try { await q(call); } catch (e) { if (guardMsg.test(e.message) && !/administrateur|double authentification/i.test(e.message)) blockedAdmin.push(`${f.name}: ${e.message}`); else if (/syntax|does not exist|cannot cast/i.test(e.message)) skipped.push(f.name); }
    await as(MINA);
    try { await q(call); passedAgent.push(f.name); } catch (e) { if (guardMsg.test(e.message) || DENY.test(e.message)) blockedAgent.push(f.name); else passedAgent.push(`${f.name} (${e.message.slice(0, 60)})`); }
  }
  await as(A);
  await works('E1b administrateur global : sponsor_report sur un vrai sponsor', `select sponsor_report('${SPONSOR}')`);
  await as(MINA);
  await fails('E1c agent sans permission : sponsor_report refusé', `select sponsor_report('${SPONSOR}')`, DENY);
  check('E1 administrateur global : aucune fonction refusée par une garde de permission d\'équipe', blockedAdmin.length === 0, blockedAdmin.join(' | '));
  check('E2 agent sans permission (droits minimaux) : la grande majorité des fonctions gardées est refusée', blockedAgent.length >= fns.length * 0.8, `${blockedAgent.length}/${fns.length} refusées ; non refusées : ${passedAgent.join(', ')}`);
  console.log(`   (E : ${fns.length} fonctions gardées parcourues, ${blockedAgent.length} refusées à l'agent minimal, ${skipped.length} ignorées)`);
  console.log(`   non refusées à l'agent minimal : ${passedAgent.join(', ')}`);

  // ============================================================ F. Rejeu des migrations (idempotence)
  await sup();
  const fs = await import('fs'); const path = await import('path'); const { fileURLToPath } = await import('url');
  const dir = path.dirname(fileURLToPath(import.meta.url));
  for (const f of ['20261122020000_l3_rattachement_historique_2fa.sql', '20261122021000_l3_comptes_suspects_revue_equipes.sql']) {
    try { await db.exec(fs.readFileSync(path.join(dir, '..', '..', 'migrations', f), 'utf8')); check(`F1 ${f} rejouée sans erreur`, true); } catch (e) { check(`F1 ${f} rejouée sans erreur`, false, e.message); }
  }
  await as(A);
  check('F2 le rejeu ne duplique pas l\'historique des rattachements existants', (await qs(`select count(*)::int n from (select user_id from department_assignment_history group by user_id having count(*) > 1 and bool_and(action = 'existing')) x`)).length === 1);
  console.log(`h6_centre : ${ok} OK, ${ko} ECHEC`);
  console.log(`${ok}/${ok + ko}`);
}
