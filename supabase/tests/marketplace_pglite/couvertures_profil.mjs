let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-0000000000a1', B = '00000000-0000-0000-0000-0000000000b1';
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role authenticated`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm] of [[A, 'Alice'], [B, 'Bob']]) await db.exec(`insert into auth.users(id,email) values ('${id}','${nm}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','student','${nm}@t.cm')`);
  await as(A);
  await q(`select profile_cover_set(0, '${A}/a.jpg', 'image')`);
  await q(`select profile_cover_set(2, '${A}/b.mp4', 'video')`);
  check('deux couvertures enregistrees', (await q(`select profile_covers_get() r`))[0].r.length === 2);
  await q(`select profile_cover_set(0, '${A}/c.jpg', 'image')`);
  check('remplacement d un emplacement', (await q(`select profile_covers_get() r`))[0].r.find(x => x.slot === 0).path === `${A}/c.jpg`);
  await fails('dossier d un autre refuse', `select profile_cover_set(1, '${B}/x.jpg', 'image')`, /Fichier invalide/);
  await fails('emplacement inconnu', `select profile_cover_set(3, '${A}/x.jpg', 'image')`, /Emplacement inconnu/);
  await as(B);
  check('un autre compte voit les couvertures d Alice', (await q(`select profile_covers_get('${A}') r`))[0].r.length === 2);
  check('et les siennes sont vides', (await q(`select profile_covers_get() r`))[0].r.length === 0);
  await q(`select profile_cover_clear(0)`);
  await as(A);
  check('Bob ne supprime pas la couverture d Alice', (await q(`select profile_covers_get() r`))[0].r.length === 2);
  await q(`select profile_cover_clear(2)`);
  check('suppression', (await q(`select profile_covers_get() r`))[0].r.length === 1);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
