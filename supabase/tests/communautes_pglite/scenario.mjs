// Communautés : création soumise à validation, 500 mots, département du référentiel, mentors, membres. Lancer :
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ../communautes_pglite/scenario.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (n, c, x = '') => { if (c) { ok++; console.log('OK', n); } else { ko++; console.log('ECHEC', n, x); } };
  const fails = async (n, sql, re) => { try { await q(sql); check(n, false, 'aurait du echouer'); } catch (e) { check(n, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Atelier', 'student'], [B, 'Paul Buyer', 'student'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into institutions(name, short_name, kind, city, status, source) values ('Inst Test','IT','ecole','Douala','verified','test') on conflict do nothing`);
  await db.exec(`insert into departments(institution_id, name, status) select id, 'Génie logiciel', 'verified' from institutions where short_name='IT'`);
  const dep = (await q(`select id from departments where name='Génie logiciel'`))[0].id;
  await as(A);
  const words = n => Array.from({ length: n }, (_, i) => 'mot' + i).join(' ');
  await fails('501 mots refusés', `select create_community('Les Devs', '${words(501)}', '', 'public', '', null)`, /500 mots/);
  const id = (await q(`select create_community('Les Devs', '${words(500)}', '', 'public', '', '${dep}') id`))[0].id;
  check('500 mots acceptés', !!id);
  await fails('département inconnu refusé', `select create_community('Autre', 'x', '', 'public', '', '00000000-0000-0000-0000-000000000999')`, /Département inconnu/);
  check('statut en attente', (await q(`select status from communities where id='${id}'`))[0].status === 'pending');
  check('le créateur voit sa demande', (await q(`select count(*)::int n from communities_list('')`))[0].n === 1);
  await fails('publier avant validation refusé', `select create_community_post('${id}', 'bonjour')`, /pas encore validée/);
  await as(B);
  check('invisible aux autres', (await q(`select count(*)::int n from communities_list('')`))[0].n === 0);
  await fails('B ne valide pas', `select community_decide('${id}', true)`, /Réservé/);
  await as(M);
  check('liste en attente pour l\'équipe', (await q(`select count(*)::int n from communities_pending()`))[0].n === 1);
  await fails('refus sans motif impossible', `select community_decide('${id}', false, '')`, /motif/);
  check('validation', (await q(`select community_decide('${id}', true) s`))[0].s === 'active');
  await as(A);
  check('notification de validation', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='community_approved'`))[0].n === 1);
  check('publication après validation', !!(await q(`select create_community_post('${id}', 'Bonjour à tous') p`))[0].p);
  await as(B);
  check('B voit la communauté avec son département', (await q(`select department d from communities_list('') where id='${id}'`))[0]?.d === 'Génie logiciel');
  check('B rejoint', (await q(`select join_community('${id}') j`))[0].j === 'joined');
  await as(A);
  check('mentor nommé par le propriétaire', (await q(`select set_member_role('${id}', '${B}', 'mentor') r`))[0].r === 'mentor');
  const mem = await q(`select name, role from community_members_list('${id}')`);
  check('liste des membres : propriétaire puis mentor', mem.length === 2 && mem[0].role === 'owner' && mem[1].role === 'mentor', JSON.stringify(mem));
  await as(B);
  await fails('un mentor ne nomme personne', `select set_member_role('${id}', '${A}', 'member')`, /non autorisée/);
  console.log(`${ok}/${ok + ko}`);
}
