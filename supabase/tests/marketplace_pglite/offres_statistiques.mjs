let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', A = '00000000-0000-0000-0000-0000000000a1', B = '00000000-0000-0000-0000-0000000000b1', X = '00000000-0000-0000-0000-0000000000c1';
  const O = '00000000-0000-0000-0000-00000000f001';
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role authenticated`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange', 'company'], [A, 'Alice', 'student'], [B, 'Bob', 'student'], [X, 'Xena', 'company']]) await db.exec(`insert into auth.users(id,email) values ('${id}','${nm}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm}@t.cm')`);
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status) values ('${O}', '${E}', 'Orange', 'stage', 'Stage developpeur', 'published')`);
  await as(A); await q(`select opp_view_track('${O}')`); await q(`select opp_view_track('${O}')`);
  await as(B); await q(`select opp_view_track('${O}')`);
  await as(E); await q(`select opp_view_track('${O}')`);
  let s = (await q(`select opp_stats('${O}') r`))[0].r[0];
  check('vues : une par personne et par jour, l auteur exclu', s.views === 2 && s.viewers === 2, JSON.stringify(s));
  check('sans candidature : taux de reponse vide', s.applications === 0 && s.response_rate === null);
  await db.exec(`reset role; insert into opportunity_applications (opportunity_id, applicant_id, status) values ('${O}', '${A}', 'shortlisted'), ('${O}', '${B}', 'sent')`);
  await as(E);
  s = (await q(`select opp_stats('${O}') r`))[0].r[0];
  check('candidatures et reponses', s.applications === 2 && s.answered === 1 && s.response_rate === 50 && s.shortlisted === 1, JSON.stringify(s));
  check('conversion vues vers candidatures', Number(s.conversion) === 100, JSON.stringify(s));
  await as(X);
  check('une autre entreprise ne voit pas ces chiffres', (await q(`select opp_stats('${O}') r`))[0].r.length === 0);
  check('toutes mes offres : liste vide pour qui n en a pas', (await q(`select opp_stats() r`))[0].r.length === 0);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
