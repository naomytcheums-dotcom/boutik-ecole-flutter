let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Etudiante', 'student'], [B, 'Paul Membre', 'student'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await as(A);
  const cid = (await q(`select create_community('Dev Flutter','Entraide autour de Flutter','','public','',null,'interest',null,'Flutter') id`))[0].id;
  await as(M);
  await q(`select community_decide('${cid}', true)`);
  await as(B);
  await q(`select join_community('${cid}')`);
  await db.exec('reset role');
  await db.exec(`insert into point_events (user_id, kind, points, ref) values ('${A}', 'answer', 100, 'a'), ('${A}', 'answer', 60, 'b'), ('${B}', 'share', 20, 'c')`);
  await as(null, 'anon');
  let r = (await q(`select user_level('${A}') r`))[0].r;
  check('niveau public : Awa a 160 points, Aidant Argent', r.total === 160 && r.level === 'silver');
  r = (await q(`select user_level('${B}') r`))[0].r;
  check('niveau public : Paul sans niveau', r.total === 20 && r.level === 'none');
  r = (await q(`select user_level('${M}') r`))[0].r;
  check('niveau public : zero point', r.total === 0 && r.level === 'none');
  await as(B);
  r = (await q(`select community_levels('${cid}') r`))[0].r;
  check('membres : seuls ceux qui ont un niveau', r[A].level === 'silver' && r[B] === undefined && Object.keys(r).length === 1);
  console.log(`\n${ok}/${ok + ko}`);
}
