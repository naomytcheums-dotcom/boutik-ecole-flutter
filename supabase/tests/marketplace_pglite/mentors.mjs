let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', D = '00000000-0000-0000-0000-00000000000d';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role, dept] of [[A, 'Awa Ancienne', 'student', 'Génie informatique'], [B, 'Paul Etudiant', 'student', 'Génie informatique'], [C, 'Cora Alumni', 'student', 'Génie civil'], [D, 'Dan Occupe', 'student', 'Génie informatique']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,department) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm','${dept}')`);
  }
  // --- devenir mentor
  await as(A);
  await fails('mentor : employeur obligatoire', `select mentor_save('', 'Promo 2021', array['Flutter'], 'x')`, /où vous travaillez/);
  await fails('mentor : au moins un sujet', `select mentor_save('Orange Cameroun', 'Promo 2021', array[]::text[], 'x')`, /1 à 10 sujets/);
  await q(`select mentor_save('Orange Cameroun', 'Promo 2021', array['Flutter','Entretien d embauche'], 'Developpeuse mobile', 'this_week', true)`);
  check('mon profil mentor', (await q(`select my_mentor() r`))[0].r.works_at === 'Orange Cameroun');
  await as(C);
  await q(`select mentor_save('Eneo', 'Promo 2019', array['Electricite','Chantier'], 'Ingenieure', 'available', false)`);
  await as(D);
  await q(`select mentor_save('Camlight', 'Promo 2020', array['Flutter','Design'], 'Occupe en ce moment', 'busy', false)`);
  // --- annuaire et match
  await as(B);
  let list = (await q(`select mentors_list() r`))[0].r;
  check('annuaire : 3 mentors, disponibles avant les occupes', list.length === 3 && list[list.length - 1].name.startsWith('Dan') && list[0].availability !== 'busy');
  check('annuaire : recherche par sujet', (await q(`select mentors_list(null, 'flutter') r`))[0].r.length === 2);
  check('annuaire : nom abrege, filiere et employeur', list.find(x => x.user_id === A).name === 'Awa A.' && list.find(x => x.user_id === A).department === 'Génie informatique' && list.find(x => x.user_id === A).works_at === 'Orange Cameroun');
  let match = (await q(`select mentor_match('Je veux apprendre Flutter', true) r`))[0].r;
  check('match : le mentor Flutter disponible le soir en premier, pas l occupe', match.length === 1 && match[0].user_id === A && match[0].score > 0);
  await fails('match : sujet obligatoire', `select mentor_match('  ')`, /Dites ce que vous voulez/);
  check('match : rien d inventé quand personne ne correspond', (await q(`select mentor_match('plomberie') r`))[0].r.length === 0);
  // --- demande
  await fails('demande : mentor occupe refuse', `select mentor_request('${D}', 'Flutter')`, /pas disponible/);
  await fails('demande : sujet obligatoire', `select mentor_request('${A}', '')`, /ce que vous voulez apprendre/);
  const rid = (await q(`select mentor_request('${A}', 'Flutter', 'Je debute et je cherche de l aide') id`))[0].id;
  await fails('demande : une seule en attente par mentor', `select mentor_request('${A}', 'Flutter encore')`, /déjà en attente/);
  await as(A);
  check('demande : le mentor est notifie', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='mentor_request'`))[0].n === 1);
  check('demande : visible dans les demandes recues', (await q(`select my_mentor_requests('mentor') r`))[0].r.length === 1);
  await as(B);
  await fails('avis : pas avant l acceptation', `select mentor_review('${rid}', 5, 'Top')`, /demande acceptée/);
  await fails('decision : seul le mentor decide', `select mentor_request_decide('${rid}', true)`, /Demande introuvable/);
  await as(A);
  await q(`select mentor_request_decide('${rid}', true)`);
  await fails('decision : une seule fois', `select mentor_request_decide('${rid}', false)`, /déjà reçu une réponse/);
  await as(B);
  check('demande acceptee : l etudiant est notifie', (await q(`select count(*)::int n from notifications where user_id='${B}' and title='Mentor trouvé'`))[0].n === 1);
  // --- avis
  await fails('avis : note de 1 a 5', `select mentor_review('${rid}', 9, 'x')`, /1 à 5/);
  await q(`select mentor_review('${rid}', 5, 'Il m a beaucoup aide')`);
  const det = (await q(`select mentor_detail('${A}') r`))[0].r;
  check('fiche mentor : note moyenne, avis et ma demande', det.rating === 5 && det.reviews === 1 && det.helped === 1 && det.review_list[0].comment === 'Il m a beaucoup aide' && det.my_request.status === 'accepted');
  await as(C);
  await fails('avis : seul l etudiant concerne', `select mentor_review('${rid}', 1, 'faux')`, /Demande introuvable/);
  // --- histoires
  await as(B);
  await fails('histoire : reservee aux mentors', `select mentor_story_save('De l IUT a Orange', 'Mon parcours depuis la licence jusqu au premier emploi', 'Orange')`, /Réservé aux mentors/);
  await as(A);
  await fails('histoire : texte trop court refuse', `select mentor_story_save('Titre', 'court')`, /20 caractères/);
  await q(`select mentor_story_save('De l IUT a Orange Cameroun', 'Apres ma licence, j ai fait un stage puis ete embauchee comme developpeuse mobile.', 'Orange Cameroun')`);
  await as(null, 'anon');
  const st = (await q(`select mentor_stories() r`))[0].r;
  check('histoires visibles de tous', st.length === 1 && st[0].title === 'De l IUT a Orange Cameroun' && st[0].company === 'Orange Cameroun');
  // --- disponibilité : mentor désactivé
  await as(A);
  await q(`select mentor_save('Orange Cameroun', 'Promo 2021', array['Flutter'], 'Pause', 'busy', false, false)`);
  await as(B);
  check('mentor desactive : retire de l annuaire', !(await q(`select mentors_list() r`))[0].r.some(x => x.user_id === A));
  console.log(`\n${ok}/${ok + ko}`);
}
