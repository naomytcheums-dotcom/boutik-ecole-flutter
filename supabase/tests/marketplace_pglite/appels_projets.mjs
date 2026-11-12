let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Etudiante', 'student'], [B, 'Boris Etudiant', 'student'], [C, 'Orange Cameroun', 'other']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  // besoins publiés (insertions directes : la création passe par un autre écran)
  const mission = (n, title, desc, bmin, bmax) => db.exec(`insert into missions (number, client_id, kind, description, total, title, status, budget_min, budget_max) values ('${n}', '${C}', 'service', '${desc}', 0, '${title}', 'published', ${bmin}, ${bmax})`);
  await mission('M1', 'Application de caisse', 'Application mobile pour boutiques, filière informatique', 100000, 300000);
  await mission('M2', 'Logo et identité', 'Identité visuelle pour une marque de jus, filière design', 20000, 50000);
  await mission('M3', 'Site vitrine', 'Site web pour un hôtel, filière informatique', 150000, 150000);
  await db.exec(`insert into mission_proposals (mission_id, author_id, amount, delay_days, message, status) select id, '${A}', 10000, 5, 'Je peux le faire', 'submitted' from missions where number = 'M3'`);
  await as(A);
  let l = (await q(`select open_calls() r`))[0].r;
  check('appels : recents d abord par defaut', l.length === 3);
  l = (await q(`select open_calls(null, 30, 'budget') r`))[0].r;
  check('appels : budget le plus eleve d abord', l[0].number === 'M1' && l[1].number === 'M3' && l[2].number === 'M2');
  l = (await q(`select open_calls(null, 30, 'fewest') r`))[0].r;
  check('appels : moins de propositions d abord', l[2].number === 'M3');
  l = (await q(`select open_calls(null, 30, 'recent', 'design') r`))[0].r;
  check('appels : filiere mentionnee', l.length === 1 && l[0].number === 'M2');
  l = (await q(`select open_calls('site', 30, 'recent', 'informatique') r`))[0].r;
  check('appels : recherche et filiere ensemble', l.length === 1 && l[0].number === 'M3');
  await fails('appels : tri inconnu', `select open_calls(null, 30, 'zzz')`, /Tri inconnu/);
  // projets validés
  const proj = async (title, dept, owner) => (await db.query(`insert into projects (owner_id, title, summary, department, status) values ('${owner}', '${title}', 'Resume', '${dept}', 'approved') returning id`)).rows[0].id;
  await db.exec('reset role');
  const p1 = await proj('Projet ancien', 'Informatique', B), p2 = await proj('Projet recent', 'Design', B), p3 = await proj('Projet moyen', 'Informatique', C);
  await db.exec(`update projects set created_at = now() - interval '10 days' where id = '${p1}'`);
  await as(A);
  check('soutien : pose', (await q(`select project_upvote_toggle('${p1}') r`))[0].r === true);
  await q(`select project_upvote_toggle('${p3}')`);
  await as(C);
  await q(`select project_upvote_toggle('${p1}')`);
  await fails('soutien : pas son propre projet', `select project_upvote_toggle('${p3}')`, /propre projet/);
  await as(A);
  let pr = (await q(`select iut_projects() r`))[0].r;
  check('meilleurs : soutiens d abord, puis recents', pr[0].id === p1 && pr[0].votes === 2 && pr[1].id === p3 && pr[2].id === p2);
  check('soutien : mon soutien visible', pr[0].voted === true && pr[2].voted === false);
  pr = (await q(`select iut_projects(null, 40, 'recent') r`))[0].r;
  check('recents : ordre chronologique inverse', pr[2].id === p1);
  pr = (await q(`select iut_projects('design') r`))[0].r;
  check('projets : filtre par filiere', pr.length === 1 && pr[0].id === p2);
  check('soutien : retrait', (await q(`select project_upvote_toggle('${p1}') r`))[0].r === false);
  await fails('soutien : projet inconnu', `select project_upvote_toggle('00000000-0000-0000-0000-0000000000f1')`, /introuvable/);
  console.log(`\n${ok}/${ok + ko}`);
}
