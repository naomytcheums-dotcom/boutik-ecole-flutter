let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', A = '00000000-0000-0000-0000-0000000000a1', B = '00000000-0000-0000-0000-0000000000b1', C = '00000000-0000-0000-0000-0000000000c1', X = '00000000-0000-0000-0000-0000000000d1';
  const O = '00000000-0000-0000-0000-00000000f001';
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role authenticated`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange', 'company'], [A, 'Alice', 'student'], [B, 'Bob', 'student'], [C, 'Carl', 'student'], [X, 'Xena', 'company']]) await db.exec(`insert into auth.users(id,email) values ('${id}','${nm}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm}@t.cm')`);
  // Alice : tout correspond ; Bob : une competence sur deux ; Carl : profil vide
  await db.exec(`update profiles set skills='Flutter, Excel', department='Génie informatique', bio='Je developpe des apps', avatar_url='a.png' where id='${A}'`);
  await db.exec(`update profiles set skills='Excel', department='Gestion', bio='Gestionnaire' where id='${B}'`);
  await db.exec(`insert into student_availability (user_id, kinds) values ('${A}', array['internship'])`);
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status, skills, department_target) values ('${O}', '${E}', 'Orange', 'stage', 'Stage Flutter', 'published', array['Flutter','Excel'], 'Génie informatique')`);
  await db.exec(`insert into opportunity_applications (opportunity_id, applicant_id) values ('${O}', '${A}'), ('${O}', '${C}')`);
  await as(E);
  const apps = (await q(`select opp_applications_for('${O}') r`))[0].r;
  const a = apps.find(x => x.applicant_id === A).match, c = apps.find(x => x.applicant_id === C).match;
  check('candidate qui correspond : 100', a.score === 100, JSON.stringify(a));
  check('candidat au profil vide : score bas et expliqué', c.score < 30 && c.skills === 0 && c.skills_found === 0 && c.skills_wanted === 2, JSON.stringify(c));
  const sug = (await q(`select opp_suggested_students('${O}') r`))[0].r;
  check('suggestions : Bob propose, pas les candidats', sug.length === 1 && sug[0].id === B, JSON.stringify(sug));
  check('suggestion de Bob : une competence sur deux', sug[0].match.skills === 25 && sug[0].match.skills_found === 1, JSON.stringify(sug[0].match));
  await as(X);
  await fails('une autre entreprise : offre introuvable', `select opp_suggested_students('${O}')`, /Offre introuvable/);
  await fails('une autre entreprise : candidatures refusees', `select opp_applications_for('${O}')`, /Offre introuvable/);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
