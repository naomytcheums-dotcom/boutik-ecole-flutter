let ok = 0, ko = 0;
export async function run(db) {
  const S = '00000000-0000-0000-0000-0000000000a1', E = '00000000-0000-0000-0000-0000000000e1';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[S, 'Awa Etudiante', 'student'], [E, 'Orange Cameroun', 'company']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await as(S);
  let p = (await q(`select profile_extras_get() r`))[0].r;
  check('profil vide : rien d invente', p.mine === true && p.availability === null && p.languages.length === 0);
  await fails('disponibilite : type inconnu', `select availability_save(jsonb_build_object('kinds', jsonb_build_array('vacances-au-soleil')))`, /inconnu/);
  await q(`select availability_save(jsonb_build_object('kinds', jsonb_build_array('internship','mission','internship'), 'note', 'Libre le soir et le week-end', 'available_from', '2027-01-15'))`);
  await q(`select language_save('français', 'native')`);
  await q(`select language_save('anglais', 'intermediate')`);
  await q(`select language_save('Anglais', 'advanced')`);
  await fails('langue : niveau inconnu', `select language_save('Espagnol', 'expert')`, /Niveau inconnu/);
  await fails('langue : nom obligatoire', `select language_save('a', 'basic')`, /Indiquez la langue/);
  p = (await q(`select profile_extras_get() r`))[0].r;
  check('disponibilites : types dedoublonnes, note et date', p.availability.kinds.length === 2 && p.availability.note.startsWith('Libre') && p.availability.available_from === '2027-01-15');
  check('langues : anglais mis a jour (une seule ligne, niveau avance)', p.languages.length === 2 && p.languages.find(l => l.language === 'Anglais').level === 'advanced' && p.languages.some(l => l.language === 'Français'));
  await as(E);
  const pub = (await q(`select profile_extras_get('${S}') r`))[0].r;
  check('l entreprise voit les disponibilites et les langues', pub.mine === false && pub.availability.kinds.includes('internship') && pub.languages.length === 2);
  await q(`select availability_save(jsonb_build_object('kinds', jsonb_build_array('job')))`);
  await as(S);
  check('l entreprise ne modifie que son propre profil', (await q(`select profile_extras_get() r`))[0].r.availability.kinds.length === 2);
  await q(`select language_delete('anglais')`);
  check('langue supprimee', (await q(`select profile_extras_get() r`))[0].r.languages.length === 1);
  await q(`select availability_save(jsonb_build_object('kinds', jsonb_build_array()))`);
  check('disponibilites videes : plus aucune', (await q(`select profile_extras_get() r`))[0].r.availability.kinds.length === 0);
  await fails('tables : aucun acces direct', `select * from student_languages`, /permission/);
  console.log(`\n${ok}/${ok + ko}`);
}
