let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role, dept, inst] of [[A, 'Awa Etudiante', 'student', 'Génie informatique', 'IUT de Douala'], [B, 'Orange Cameroun', 'company', '', ''], [C, 'Cora Externe', 'student', 'Génie civil', 'Université de Yaoundé'], [M, 'Mod Admin', 'admin', 'Direction', 'IUT de Douala']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,department,institution) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm','${dept}','${inst}')`);
  }
  const post = (org, kind, title, extra = {}) => {
    const e = { contract: 'academique', loc: 'Douala', mode: 'onsite', dur: '3 mois', payKind: 'paid', amount: 50000, deadline: "current_date + 10", dept: 'Génie informatique', iut: 'false', wa: '', app: 'true', ...extra };
    return `select opp_save('${org}', '${kind}', '${e.contract}', '${title}', '${e.loc}', '${e.mode}', '${e.dur}', '${e.payKind}', ${e.amount}, '', ${e.deadline}, array['Flutter','Canva'], 'Description complete de l offre pour les etudiants', array['Developper des ecrans','Tester'], 'Etudiant motive', '${e.dept}', 'Licence 2', array['Attestation de stage','Experience'], '${e.wa}', ${e.app}, 'Operateur de telecommunications', ${e.iut}) id`;
  };
  // --- publication
  await as(A);
  await fails('publication : reservee aux organisations', post('Moi', 'stage', 'Stage test'), /Réservé aux entreprises/);
  await as(B);
  await fails('publication : description trop courte', `select opp_save('Orange', 'stage', '', 'Stage dev', '', 'onsite', '', 'paid', 50000, '', null, array[]::text[], 'court', array[]::text[], '', '', '', array[]::text[], '', true, '', false)`, /20 caractères/);
  await fails('publication : un moyen de postuler obligatoire', post('Orange', 'stage', 'Stage dev', { app: 'false' }), /moyen de postuler/);
  const o1 = (await q(post('Orange Cameroun', 'stage', 'Stagiaire developpeur Flutter')))[0].id;
  const o2 = (await q(post('Orange Cameroun', 'emploi', 'Developpeur mobile junior', { contract: 'CDD', iut: 'true', deadline: 'current_date + 2', amount: 150000 })))[0].id;
  const o3 = (await q(post('Orange Cameroun', 'benevolat', 'Benevolat association', { payKind: 'unpaid', amount: 'null', dept: '', wa: '+237690112233', app: 'false', deadline: 'null' })))[0].id;
  await as(A);
  check('validation : non publiee, invisible des etudiants', (await q(`select opps_list() r`))[0].r.length === 0);
  await as(M);
  check('validation : l equipe voit les offres a valider', (await q(`select opp_my_posted() r`))[0].r.length === 3);
  await fails('validation : motif de refus obligatoire', `select opp_decide('${o3}', false)`, /motif/);
  await q(`select opp_decide('${o1}', true, true)`);
  await q(`select opp_decide('${o2}', true, false)`);
  await q(`select opp_decide('${o3}', true, true)`);
  await as(B);
  check('validation : l organisation est notifiee', (await q(`select count(*)::int n from notifications where user_id='${B}' and kind='opportunity_review' and title='Offre publiée'`))[0].n === 3);
  // --- liste, filtres, sections
  await as(A);
  let list = (await q(`select opps_list() r`))[0].r;
  check('liste : 3 offres, remunerees d abord, verifiees marquees', list.length === 3 && list[list.length - 1].pay_kind === 'unpaid' && list.find(x => x.id === o1).verified === true && list.find(x => x.id === o2).verified === false);
  check('filtre : par type', (await q(`select opps_list('emploi') r`))[0].r.length === 1);
  check('filtre : remunerees seulement', (await q(`select opps_list(null, null, null, true) r`))[0].r.length === 2);
  check('filtre : recherche par competence', (await q(`select opps_list(null, 'flutter') r`))[0].r.length === 3);
  check('section : date limite proche', (await q(`select opps_list(null,null,null,false,false,null,'closing') r`))[0].r.map(x => x.id).join() === o2);
  check('section : reservees a l IUT', (await q(`select opps_list(null,null,null,false,false,null,'iut') r`))[0].r.length === 1);
  check('section : pour vous (filiere de l etudiant)', (await q(`select opps_list(null,null,null,false,false,null,'foryou') r`))[0].r.length === 3);
  check('section : nouvelles de la semaine', (await q(`select opps_list(null,null,null,false,false,null,'new') r`))[0].r.length === 3);
  // --- fiche
  const det = (await q(`select opp_detail('${o1}') r`))[0].r;
  check('fiche : missions, profil, gains, organisation, autres offres', det.missions.length === 2 && det.profile_wanted === 'Etudiant motive' && det.gains.length === 2 && det.about_org.startsWith('Operateur') && det.other_offers.length === 2);
  // --- candidature
  await fails('candidature : lettre trop courte', `select opp_apply('${o1}', 'court')`, /20 caractères/);
  const app1 = (await q(`select opp_apply('${o1}', 'Je suis tres motivee pour ce stage de developpement Flutter', 'https://cv.exemple.cm/awa') id`))[0].id;
  await fails('candidature : une seule par offre', `select opp_apply('${o1}', 'Encore une candidature pour la meme offre')`, /déjà postulé/);
  await as(B);
  check('candidature : l organisation est notifiee', (await q(`select count(*)::int n from notifications where user_id='${B}' and kind='opportunity_application'`))[0].n === 1);
  const apps = (await q(`select opp_applications_for('${o1}') r`))[0].r;
  check('candidature : l organisation voit la lettre et la filiere', apps.length === 1 && apps[0].department === 'Génie informatique' && apps[0].cv_link.startsWith('https://') && apps[0].name.startsWith('Awa'));
  await as(C);
  await fails('offre reservee a l IUT : un externe ne postule pas', `select opp_apply('${o2}', 'Je souhaite beaucoup postuler a ce poste de developpeur')`, /réservée aux étudiants de l'IUT/);
  await as(A);
  await fails('candidature : WhatsApp seul = pas de candidature dans l app', `select opp_apply('${o3}', 'Je souhaite beaucoup rejoindre cette association')`, /uniquement par WhatsApp/);
  // --- favoris, rappel, alerte
  check('favori : ajoute', (await q(`select opp_save_toggle('${o2}') r`))[0].r === true);
  check('section : mes favoris', (await q(`select opps_list(null,null,null,false,false,null,'saved') r`))[0].r.length === 1);
  await q(`select opp_remind('${o2}', true)`);
  await fails('rappel : offre sans date limite refusee', `select opp_remind('${o3}', true)`, /date limite/);
  await q(`select opps_list()`);
  check('rappel : envoye quand la date limite approche (2 jours)', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='opportunity_reminder'`))[0].n === 1);
  await q(`select opps_list()`);
  check('rappel : une seule fois', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='opportunity_reminder'`))[0].n === 1);
  await q(`select opp_alert_set('Génie informatique', true)`);
  check('alerte filiere : active', (await q(`select opp_my_alert() r`))[0].r === true);
  await as(B);
  const o4 = (await q(post('Camtel', 'formation', 'Formation reseaux certifiante', { dept: 'Génie informatique' })))[0].id;
  await as(M);
  await q(`select opp_decide('${o4}', true)`);
  await as(A);
  check('alerte filiere : prevenue d une nouvelle offre de sa filiere', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='opportunity_alert'`))[0].n === 1);
  // --- recrutés
  await as(B);
  await fails('recrute : statut inconnu refuse', `select opp_application_decide('${app1}', 'zzz')`, /Statut inconnu/);
  await q(`select opp_application_decide('${app1}', 'hired')`);
  await as(A);
  check('recrute : la candidate est notifiee', (await q(`select count(*)::int n from notifications where user_id='${A}' and title='Félicitations !'`))[0].n === 1);
  check('recrute : mes candidatures avec statut', (await q(`select opp_my_applications() r`))[0].r[0].status === 'hired');
  await as(null, 'anon');
  check('recrutes : rien tant que le candidat n a pas donne son accord', (await q(`select opp_hired_list() r`))[0].r.length === 0);
  await as(A);
  await q(`select opp_hire_publish('${app1}')`);
  await as(null, 'anon');
  const hl = (await q(`select opp_hired_list() r`))[0].r;
  check('recrutes : visible apres accord du candidat', hl.length === 1 && hl[0].org === 'Orange Cameroun' && hl[0].department === 'Génie informatique' && hl[0].role === 'Stagiaire developpeur Flutter');
  await as(B);
  await q(`select opp_close('${o1}')`);
  await as(A);
  check('offre fermee : retiree de la liste', !(await q(`select opps_list() r`))[0].r.some(x => x.id === o1));
  console.log(`\n${ok}/${ok + ko}`);
}
