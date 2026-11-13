let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', S = '00000000-0000-0000-0000-0000000000a1';
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role authenticated`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange', 'company'], [S, 'Sara', 'student']]) await db.exec(`insert into auth.users(id,email) values ('${id}','${nm}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm}@t.cm')`);
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status) values ('00000000-0000-0000-0000-00000000f001', '${E}', 'Orange', 'stage', 'Stage developpeur', 'published')`);
  const O = '00000000-0000-0000-0000-00000000f001';
  await as(E);
  await fails('media : dossier d un autre refuse', `select opp_media_set('${O}', '${S}/a.jpg', 'image')`, /Fichier invalide/);
  await fails('media : format inconnu', `select opp_media_set('${O}', '${E}/a.jpg', 'gif')`, /Format inconnu/);
  await q(`select opp_media_set('${O}', '${E}/a.jpg', 'image')`);
  await as(S);
  const d = (await q(`select opp_detail('${O}') r`))[0].r;
  check('detail : media visible par un etudiant', d.media_path === `${E}/a.jpg` && d.media_kind === 'image');
  const l = (await q(`select opps_list() r`))[0].r;
  check('liste : media dans la carte', JSON.stringify(l).includes(`${E}/a.jpg`));
  await fails('un tiers ne change pas le media', `select opp_media_set('${O}', '${S}/b.jpg', 'image')`, /Offre introuvable/);
  await as(E);
  await q(`select opp_media_set('${O}', '', null)`);
  check('retrait du media', (await q(`select opp_detail('${O}') r`))[0].r.media_path === null);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
