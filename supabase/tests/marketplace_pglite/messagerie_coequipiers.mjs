let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, skills] of [[A, 'Awa Etudiante', 'Flutter'], [B, 'Boris Etudiant', 'Figma'], [C, 'Cora Etudiante', 'Marketing']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,skills) values ('${id}','${nm}','student','${nm.split(' ')[0]}@t.cm','${skills}')`);
  }
  await as(A);
  const inv = (await q(`select teammate_invite('${B}', 'On monte une equipe') id`))[0].id;
  await fails('message : invitation pas encore acceptee', `select teammate_message_send('${inv}', 'Salut')`, /acceptée/);
  await as(B);
  await q(`select teammate_invite_decide('${inv}', true)`);
  await as(C);
  await fails('message : un tiers ne lit pas', `select teammate_messages_list('${inv}')`, /introuvable/);
  await fails('message : un tiers n ecrit pas', `select teammate_message_send('${inv}', 'Intrus')`, /introuvable/);
  await as(B);
  await fails('message : vide refuse', `select teammate_message_send('${inv}', '   ')`, /entre 1 et 1000/);
  await q(`select teammate_message_send('${inv}', 'Bonjour Awa, on commence quand ?')`);
  await q(`select teammate_message_send('${inv}', 'Je suis dispo ce soir')`);
  await as(A);
  check('notification : une seule par rafale de messages', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='teammate_message'`))[0].n === 1);
  await q(`select teammate_message_send('${inv}', 'Parfait, 18h ?')`);
  const l = (await q(`select teammate_messages_list('${inv}') r`))[0].r;
  check('fil : 3 messages dans l ordre avec auteur et "mine"', l.length === 3 && l[0].body.startsWith('Bonjour') && l[0].mine === false && l[0].author === 'Boris E.' && l[2].mine === true);
  const after = l[1].created_at;
  check('fil : seulement les nouveaux apres une date', (await q(`select teammate_messages_list('${inv}', '${after}'::timestamptz) r`))[0].r.length <= 1);
  await as(B);
  check('notification : l autre est prevenu de la reponse', (await q(`select count(*)::int n from notifications where user_id='${B}' and kind='teammate_message'`))[0].n === 1);
  const r = (await q(`select mates_search('Flutter') r`))[0].r;
  check('recherche : coequipier accepte avec identifiant d invitation', r.length === 1 && r[0].invite === 'accepted' && r[0].invite_id === inv);
  await fails('tables : aucun acces direct', `select * from teammate_messages`, /permission/);
  console.log(`\n${ok}/${ok + ko}`);
}
