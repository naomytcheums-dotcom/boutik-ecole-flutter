let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Etudiante', 'student'], [B, 'Paul Membre', 'student'], [C, 'Cora Prof', 'dept'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  // --- création par type
  await as(A);
  await fails('promo : la promotion est obligatoire', `select create_community('Promo des anciens','', '', 'public', '', null, 'promo')`, /promotion/);
  await fails('interet : le centre d interet est obligatoire', `select create_community('Dev Flutter','', '', 'public', '', null, 'interest')`, /centre d'intérêt/);
  await fails('type inconnu refuse', `select create_community('Club inconnu','', '', 'public', '', null, 'zzz')`, /Type de communauté inconnu/);
  const cid = (await q(`select create_community('Dev Flutter','Entraide autour de Flutter','','public','',null,'interest',null,'Flutter') id`))[0].id;
  const cid2 = (await q(`select create_community('Promo 2026','Retrouver sa classe','','approval','',null,'promo','Promo 2026',null) id`))[0].id;
  await as(M);
  await q(`select community_decide('${cid}', true)`);
  await q(`select community_decide('${cid2}', true)`);
  await q(`select community_set_official('${cid2}', true)`);
  await as(B);
  await fails('badge officiel reserve a l equipe', `select community_set_official('${cid}', true)`, /Réservé/);
  let list = await q(`select * from communities_list('')`);
  const dev = list.find(x => x.id === cid), promo = list.find(x => x.id === cid2);
  check('annuaire : type, centre d interet, promotion', dev.kind === 'interest' && dev.interest === 'Flutter' && promo.kind === 'promo' && promo.promo_year === 'Promo 2026');
  check('annuaire : badge Officiel, responsable etudiant, membres', promo.official === true && dev.official === false && dev.owner_kind === 'student' && dev.members === 1);
  check('annuaire : recherche par centre d interet', (await q(`select * from communities_list('flutter')`)).length === 1);
  // --- adhésion
  await q(`select join_community('${cid}')`);
  // --- publications avec fond
  await fails('fond design : texte limite a 280 caracteres', `select create_community_post('${cid}', '${'x'.repeat(300)}', 'sunset')`, /280/);
  await fails('fond inconnu refuse', `select create_community_post('${cid}', 'Salut', 'rose-fluo')`, /check|violates/);
  const p1 = (await q(`select create_community_post('${cid}', 'Quelqu un a deja fait le TP de reseaux ?', 'ocean') id`))[0].id;
  const p2 = (await q(`select create_community_post('${cid}', 'Publication simple sans fond') id`))[0].id;
  await as(C);
  await fails('non membre ne publie pas', `select create_community_post('${cid}', 'Intrus')`, /Réservé aux membres/);
  await as(A);
  // --- sondage
  const poll = (await q(`select create_community_poll('${cid}', 'Quel jour pour la revision ?', array['Lundi','Mardi','Mercredi'], 'fun') id`))[0].id;
  await fails('sondage : au moins 2 reponses', `select create_community_poll('${cid}', 'Question sans choix', array['Seule'])`, /2 à 6/);
  await as(B);
  await q(`select vote_community_poll('${poll}', 1)`);
  await q(`select vote_community_poll('${poll}', 2)`);
  let feed = await q(`select * from community_feed('${cid}')`);
  const pf = feed.find(x => x.id === poll);
  check('sondage : un vote par personne, modifiable', pf.poll.total === 1 && pf.poll.mine === 2 && pf.poll.options[2].votes === 1 && pf.poll.options[1].votes === 0);
  await fails('sondage : reponse hors liste refusee', `select vote_community_poll('${poll}', 5)`, /Réponse inconnue/);
  check('fil : fond conserve', feed.find(x => x.id === p1).style === 'ocean' && feed.find(x => x.id === p2).style === null);
  // --- annonces épinglées
  await fails('epingle : reserve aux responsables', `select pin_community_post('${p2}', true)`, /Réservé aux responsables/);
  await as(A);
  await q(`select pin_community_post('${p2}', true)`);
  feed = await q(`select * from community_feed('${cid}')`);
  check('epingle : en haut du fil', feed[0].id === p2 && feed[0].pinned === true);
  await q(`select pin_community_post('${p1}', true)`);
  await q(`select pin_community_post('${poll}', true)`);
  const p4 = (await q(`select create_community_post('${cid}', 'Quatrieme annonce') id`))[0].id;
  await fails('epingle : trois au plus', `select pin_community_post('${p4}', true)`, /Trois annonces/);
  check('activite recente et publications de la semaine', (await q(`select * from communities_list('flutter')`))[0].posts_week === 4 && (await q(`select * from communities_list('flutter')`))[0].last_activity !== null);
  console.log(`\n${ok}/${ok + ko}`);
}
