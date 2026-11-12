let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Etudiante', 'student'], [B, 'Paul Membre', 'student'], [C, 'Cora Dehors', 'student'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await as(A);
  const cid = (await q(`select create_community('Dev Flutter','Entraide autour de Flutter','','public','',null,'interest',null,'Flutter') id`))[0].id;
  await as(M);
  await q(`select community_decide('${cid}', true)`);
  await as(B);
  await q(`select join_community('${cid}')`);
  await as(C);
  await fails('creation : reservee aux membres', `select study_room_create('${cid}', 'Revision reseaux')`, /membres/);
  await fails('liste : reservee aux membres', `select study_rooms_list('${cid}')`, /membres/);
  await as(B);
  await fails('creation : titre obligatoire', `select study_room_create('${cid}', 'a')`, /titre/);
  const r1 = (await q(`select study_room_create('${cid}', 'Revision reseaux', 'TP de jeudi') id`))[0].id;
  await as(A);
  check('notification : les membres sont prevenus (pas le createur)', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='study_room'`))[0].n === 1);
  let l = (await q(`select study_rooms_list('${cid}') r`))[0].r;
  check('liste : salon ouvert avec son organisateur', l.length === 1 && l[0].title === 'Revision reseaux' && l[0].host === 'Paul M.' && l[0].mine === false && l[0].can_close === true);
  let e = (await q(`select study_room_enter('${r1}') r`))[0].r;
  check('entree : identite et droits', e.self_id === A && e.name === 'Awa E.' && e.host_id === B && e.title === 'Revision reseaux');
  await as(C);
  await fails('entree : reservee aux membres', `select study_room_enter('${r1}')`, /membres/);
  await as(B);
  await q(`select study_room_create('${cid}', 'Maths', '')`);
  await q(`select study_room_create('${cid}', 'Algo', '')`);
  await fails('creation : trois salons ouverts au plus', `select study_room_create('${cid}', 'Quatrieme', '')`, /Trois salons/);
  // fermeture
  await as(A);
  check('fermeture : un responsable (proprietaire) ferme le salon d un autre', (await q(`select study_room_close('${r1}')`)).length === 1);
  await fails('fermeture : deja ferme', `select study_room_close('${r1}')`, /fermé/);
  await fails('entree : salon ferme', `select study_room_enter('${r1}')`, /fermé/);
  await as(B);
  l = (await q(`select study_rooms_list('${cid}') r`))[0].r;
  check('liste : le salon ferme disparait', l.length === 2 && !l.some(x => x.id === r1));
  const other = l[0].id;
  await db.exec('reset role');
  await db.exec(`update study_rooms set created_at = now() - interval '13 hours' where id = '${other}'`);
  await as(B);
  check('nettoyage : un salon oublie se ferme apres 12 heures', (await q(`select study_rooms_list('${cid}') r`))[0].r.length === 1);
  await fails('tables : aucun acces direct', `select * from study_rooms`, /permission/);
  console.log(`\n${ok}/${ok + ko}`);
}
