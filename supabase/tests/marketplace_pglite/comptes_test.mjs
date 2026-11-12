let ok = 0, ko = 0;
export async function run(db) {
  const M = '00000000-0000-0000-0000-0000000000ee', S = '00000000-0000-0000-0000-00000000000a', T = '00000000-0000-0000-0000-0000000000b1';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[M, 'Mod Admin', 'admin'], [S, 'Awa Etudiante', 'student'], [T, 'Test Etudiant', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`update profiles set is_test = true where id = '${T}'`);
  await as(S);
  await fails('liste : reservee a l administrateur', `select test_accounts_list()`, /Réservé/);
  await fails('un compte ne se declare pas test lui-meme', `update profiles set is_test = true where id = '${S}'`, /réservée à l'administrateur/);
  await as(T);
  await fails('un compte de test ne retire pas son marquage', `update profiles set is_test = false where id = '${T}'`, /réservée à l'administrateur/);
  await as(M);
  const l = (await q(`select test_accounts_list() r`))[0].r;
  check('liste : seulement les comptes marques test', l.length === 1 && l[0].id === T && l[0].role === 'student' && l[0].last_login === null);
  await db.exec('reset role');
  await db.exec(`insert into test_login_log (admin_id, target_id) values ('${M}', '${T}')`);
  await as(M);
  check('liste : dernier acces journalise', (await q(`select test_accounts_list() r`))[0].r[0].last_login !== null);
  await db.exec('reset role');
  await db.exec(`update profiles set is_test = false where id = '${T}'`);
  await as(M);
  check('le serveur peut retirer le marquage : le compte disparait de la liste', (await q(`select test_accounts_list() r`))[0].r.length === 0);
  await as(S);
  await fails('journal : aucun acces direct', `select * from test_login_log`, /permission/);
  console.log(`\n${ok}/${ok + ko}`);
}
