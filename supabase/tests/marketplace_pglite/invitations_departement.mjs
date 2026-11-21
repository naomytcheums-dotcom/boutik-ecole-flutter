// Invitations privées des responsables de département (migration 20261125010000).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./invitations_departement.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${n}`;
  const ADM = U('ad'), CLI = U('c1'), CLI2 = U('c2'), STU = U('a1'), ORG = U('e1'), SUS = U('c3');
  const I1 = '00000000-0000-0000-0000-0000000001f1', D1 = '00000000-0000-0000-0000-0000000001d1', D2 = '00000000-0000-0000-0000-0000000001d2';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role; select set_config(\'request.jwt.claim.sub\', \'\', false)');
  for (const [id, nm, role] of [[ADM, 'Admin', 'admin'], [CLI, 'Clara', 'client'], [CLI2, 'Claude', 'client'], [STU, 'Alice', 'student'], [ORG, 'Orange', 'company'], [SUS, 'Susp', 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.toLowerCase()}@t.cm') on conflict (id) do update set name = excluded.name, role = excluded.role, email = excluded.email`);
  }
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test invitations', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Génie logiciel', 'verified'), ('${D2}', '${I1}', 'Gestion', 'proposed')`);

  // ---- création : réservée à l'administrateur
  await as(CLI);
  await fails('un client ne crée pas d invitation', `select dept_invite_create('${D1}')`, /Réservé à l'administrateur/);
  await as(STU);
  await fails('un étudiant ne crée pas d invitation', `select dept_invite_create('${D1}')`, /Réservé à l'administrateur/);
  await as(null, 'anon');
  await fails('un visiteur ne crée pas d invitation', `select dept_invite_create('${D1}')`, /permission denied|Connexion requise/);
  await as(ADM);
  await fails('département non vérifié refusé', `select dept_invite_create('${D2}')`, /introuvable ou non vérifié/);
  await fails('durée hors limites refusée', `select dept_invite_create('${D1}', null, 'Responsable', 90)`, /1 à 30 jours/);
  await fails('adresse invalide refusée', `select dept_invite_create('${D1}', 'pas-une-adresse')`, /invalide/);
  const inv = (await q(`select dept_invite_create('${D1}', null, 'Chef de département', 7) r`))[0].r;
  check('l administrateur reçoit un lien (jeton de 64 caractères) une seule fois', typeof inv.token === 'string' && inv.token.length === 64 && inv.department === 'Génie logiciel', JSON.stringify(inv));
  const list = (await q(`select dept_invites_list() r`))[0].r;
  check('la liste n expose jamais le jeton', list.length === 1 && !JSON.stringify(list).includes(inv.token) && list[0].state === 'valid');
  await db.exec('reset role');
  const stored = (await q(`select token_hash from dept_leader_invitations`))[0].token_hash;
  check('seule l empreinte du jeton est conservée', stored !== inv.token && stored.length === 64);

  // ---- lecture publique avant connexion
  await as(null, 'anon');
  const info = (await q(`select dept_invite_info('${inv.token}') r`))[0].r;
  check('visiteur : la page d invitation voit département et validité', info.valid === true && info.department === 'Génie logiciel' && info.institution === 'IUT test invitations', JSON.stringify(info));
  check('visiteur : jeton inconnu', (await q(`select dept_invite_info('inconnu') r`))[0].r.state === 'unknown');
  await fails('visiteur : ne peut pas accepter', `select dept_invite_accept('${inv.token}')`, /permission denied|Connexion requise/);

  // ---- acceptation
  await as(STU);
  await fails('un étudiant ne devient pas responsable par ce lien', `select dept_invite_accept('${inv.token}')`, /ne peut pas devenir responsable/);
  await as(ORG);
  await fails('une organisation ne devient pas responsable par ce lien', `select dept_invite_accept('${inv.token}')`, /ne peut pas devenir responsable/);
  await as(SUS);
  await fails('un compte suspendu ne peut pas accepter', `select dept_invite_accept('${inv.token}')`, /suspendu/);
  await as(CLI);
  await fails('jeton faux refusé', `select dept_invite_accept('faux')`, /Invitation introuvable/);
  const acc = (await q(`select dept_invite_accept('${inv.token}') r`))[0].r;
  check('un client accepte : département et fonction', acc.department === 'Génie logiciel' && acc.title === 'Chef de département', JSON.stringify(acc));
  await db.exec('reset role');
  check('le compte est devenu Département', (await q(`select role::text r from profiles where id = '${CLI}'`))[0].r === 'dept');
  check('rattaché au bon département', (await q(`select department_id, title from department_accounts where user_id = '${CLI}'`))[0].department_id === D1);
  check('historique de rattachement', (await q(`select count(*)::int n from department_assignment_history where user_id = '${CLI}' and action = 'assign'`))[0].n === 1);
  check('journal d audit', (await q(`select count(*)::int n from audit_log where action = 'Invitation de département acceptée'`))[0].n === 1);
  { const n = await q(`select kind, data->>'type' t from notifications where user_id = '${ADM}'`); check('l administrateur est prévenu de l acceptation', n.some(x => x.kind === 'department' && x.t === 'invite_accepted'), JSON.stringify(n)); }
  await as(CLI2);
  await fails('lien à usage unique : second compte refusé', `select dept_invite_accept('${inv.token}')`, /déjà été utilisée/);
  await as(null, 'anon');
  check('l état devient « utilisé »', (await q(`select dept_invite_info('${inv.token}') r`))[0].r.state === 'used');

  // ---- lien réservé à une adresse, expiration, révocation
  await as(ADM);
  const inv2 = (await q(`select dept_invite_create('${D1}', 'claude@t.cm') r`))[0].r;
  await as(STU);
  await as(CLI);
  await fails('lien réservé : une autre adresse est refusée', `select dept_invite_accept('${inv2.token}')`, /réservée à une autre adresse|ne peut pas devenir/);
  await as(ADM);
  const inv3 = (await q(`select dept_invite_create('${D1}') r`))[0].r;
  await db.exec('reset role');
  await db.exec(`update dept_leader_invitations set expires_at = now() - interval '1 minute' where token_hash = _dept_invite_hash('${inv3.token}')`);
  await as(CLI2);
  await fails('lien expiré refusé', `select dept_invite_accept('${inv3.token}')`, /a expiré/);
  await as(ADM);
  const inv4 = (await q(`select dept_invite_create('${D1}') r`))[0].r;
  await db.exec('reset role');
  const id4b = (await q(`select id from dept_leader_invitations where token_hash = _dept_invite_hash('${inv4.token}')`))[0].id;
  await as(CLI);
  await fails('un client ne révoque pas', `select dept_invite_revoke('${id4b}')`, /Réservé à l'administrateur/);
  await as(ADM);
  await q(`select dept_invite_revoke('${id4b}')`);
  await as(CLI2);
  await fails('lien révoqué refusé', `select dept_invite_accept('${inv4.token}')`, /annulée/);
  await as(ADM);
  { const usedId = (await q(`select dept_invites_list() r`))[0].r.find(x => x.state === 'used').id; await fails('révoquer un lien déjà utilisé : refusé', `select dept_invite_revoke('${usedId}')`, /introuvable ou déjà utilisée/); }
  await as(CLI);
  await fails('table inaccessible en lecture directe', `select * from dept_leader_invitations`, /permission denied/);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
