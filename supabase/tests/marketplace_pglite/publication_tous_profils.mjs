let ok = 0, ko = 0;
export async function run(db) {
  const ids = { client: 'c1', company: 'c2', other: 'c3', visitor: 'c4', student: 'c5' };
  const U = (k) => `00000000-0000-0000-0000-0000000000${ids[k].slice(1).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const k of Object.keys(ids)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(k)}','${k}@t.cm'); insert into profiles(id,name,role,email) values ('${U(k)}','Profil ${k}','${k}','${k}@t.cm')`);
  }
  for (const k of ['client', 'company', 'other', 'visitor', 'student']) {
    await as(U(k));
    const r = (await q(`select create_post('${U(k)}/photo.jpg', 'image', 'Ma couverture ${k}', '{}', null) r`))[0].r;
    check(`publication : le profil ${k} peut publier (couverture, photo)`, r.id !== undefined);
    const s = await q(`select create_story('${U(k)}/story.jpg', 'image', 'Mon histoire') id`);
    check(`histoire : le profil ${k} peut publier`, s.length === 1);
  }
  await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false)");
  await db.exec(`update profiles set suspended = true where id = '${U('company')}'`);
  await as(U('company'));
  await fails('un compte suspendu ne publie pas', `select create_post('${U('company')}/p2.jpg', 'image', 'x', '{}', null)`, /./);
  await as(U('client'));
  await fails('reste reserve aux etudiants : repondre a un besoin d entreprise', `select propose_on_mission('00000000-0000-0000-0000-0000000000f1', 1000, 3, 'Bonjour')`, /talents|étudiants|introuvable|Réservé/);
  console.log(`\n${ok}/${ok + ko}`);
}
