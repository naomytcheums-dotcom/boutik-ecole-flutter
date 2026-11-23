// Scénario PGlite du lot F1 (profil Entreprise : sécurité des données, des rôles et de la publication) — migrations 20261118010000 à 20261118019900.
// Un test PGlite prouve la logique SQL, pas la production.
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000f${String(n).padStart(4, '0')}`;
  let cur = [null, 'authenticated'];
  const as = async (uid, role = 'authenticated') => { cur = [uid, role]; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const one = async (sql) => (await q(sql))[0].r;
  // lecture directe d'une table protégée (rôle administrateur de base), puis retour au compte courant
  const rd = async (sql) => { const c = cur; await db.exec('reset role'); const rows = await q(sql); await as(...c); return rows; };
  const rdone = async (sql) => (await rd(sql))[0].r;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, false, e.message); } };

  // ---- comptes : COA/OTA = entreprise/organisation approuvées ; COU/OTU = non approuvées ; CLI client ; DEP département ; ADM admin ; SUS entreprise approuvée suspendue
  const COA = U(1), COU = U(2), OTA = U(3), OTU = U(4), CLI = U(5), DEP = U(6), ADM = U(7), SUS = U(8), CST = U(9);
  const S1 = U(11), S2 = U(12), S3 = U(13), S4 = U(14), S5 = U(15);
  await db.exec('reset role');
  const mk = async (id, nm, role, extra = '') => {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.toLowerCase().replace(/ /g, '')}@t.cm')`);
    await db.exec(`insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.toLowerCase().replace(/ /g, '')}@t.cm')`);
    if (extra) await db.exec(`update profiles set ${extra} where id = '${id}'`);
  };
  await mk(COA, 'Orange Cameroun', 'company'); await mk(COU, 'Faux Entrepreneur', 'company'); await mk(OTA, 'Association Espoir', 'other'); await mk(OTU, 'Asso Fantome', 'other');
  await mk(CLI, 'Claire Client', 'client'); await mk(DEP, 'Daniel Dept', 'dept'); await mk(ADM, 'Admin Root', 'admin'); await mk(SUS, 'Suspendu Corp', 'company', 'suspended = true');
  await mk(S1, 'Alice Dupont', 'student', `skills = 'Flutter, SQL', department = 'Génie Logiciel', institution = 'IUT Douala', city = 'Douala'`);
  await mk(S2, 'Bob Retire', 'student', `skills = 'Flutter', department = 'Génie Logiciel'`);
  await mk(S3, 'Carl Nonverifie', 'student', `skills = 'Flutter'`);
  await mk(S4, 'Dina Suspendue', 'student', `skills = 'Flutter', suspended = true`);
  await mk(S5, 'Eric Prive', 'student', `skills = 'Python, SQL', department = 'Réseaux'`);
  for (const [id, nm] of [[COA, 'Orange Cameroun'], [OTA, 'Association Espoir']]) {
    await db.exec(`insert into company_profiles(owner_id, company_name, status) values ('${id}', '${nm}', 'approved')`);
  }
  await db.exec(`insert into company_profiles(owner_id, company_name, status) values ('${COU}', 'Faux Entrepreneur SARL', 'pending'), ('${OTU}', 'Asso Fantome', 'draft'), ('${SUS}', 'Suspendu Corp', 'approved')`);
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) select id, 'student_card', 'c', id || '/c.pdf', 'application/pdf', 10, 'verified' from profiles where id in ('${S1}', '${S2}', '${S4}', '${S5}')`);
  await db.exec(`update profiles set phone = '690010001', phone_verified = true where id = '${S1}'`);   // L4 : proposer un devis exige un étudiant éligible (vérifié + téléphone vérifié)
  await db.exec(`insert into student_talent_prefs(user_id, visible_to_recruiters) values ('${S2}', false)`);
  // H2 : le responsable DEP est rattaché au département « Réseaux » (celui d'Éric) : il ne cherche des talents que dans son département
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000fa01', 'IUT F1', 'verified');
    insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000faa1', '00000000-0000-0000-0000-00000000fa01', 'Réseaux', 'verified');
    update profiles set department_id = '00000000-0000-0000-0000-00000000faa1', institution_id = '00000000-0000-0000-0000-00000000fa01' where id = '${S5}';
    insert into department_accounts (user_id, department_id) values ('${DEP}', '00000000-0000-0000-0000-00000000faa1')`);
  // Alice a publié le lien de son CV (consentement), Eric non
  await db.exec(`insert into cv_links(token, owner_id, consent_at) values ('${'a'.repeat(32)}', '${S1}', now())`);

  // ================================================================ 1. talents_search / talents_list (E1-1, E1-2, E5-3, E5-4)
  await as(COA);
  let r = await one(`select talents_search('', '', '{}', 20, 0) r`);
  const names = r.items.map((i) => i.name).sort();
  check('E1-1 entreprise approuvée : seuls les étudiants vérifiés et visibles sont listés', r.total === 2 && names.length === 2, JSON.stringify(r));
  check('E1-1 étudiant retiré (« Me proposer aux recruteurs ») absent', !r.items.some((i) => i.id === S2));
  check('étudiant non vérifié et suspendu absents', !r.items.some((i) => i.id === S3 || i.id === S4));
  const alice = r.items.find((i) => i.id === S1), eric = r.items.find((i) => i.id === S5);
  check('E1-2 nom complet seulement avec le lien de CV publié', alice.name === 'Alice Dupont' && alice.name_full === true && alice.cv_published === true, JSON.stringify(alice));
  check('E1-2 sans lien de CV : nom abrégé', eric.name === 'Eric P.' && eric.name_full === false, JSON.stringify(eric));
  check('jamais de téléphone ni d\'e-mail dans la réponse', !JSON.stringify(r).match(/phone|email|@t\.cm/));
  check('total + pagination', r.limit === 20 && r.offset === 0);
  let p2 = await one(`select talents_search('', '', '{}', 1, 1) r`);
  check('pagination : total inchangé, une ligne', p2.total === 2 && p2.items.length === 1);
  check('filtre filière', (await one(`select talents_search('', 'logiciel', '{}', 20, 0) r`)).items.length === 1);
  check('filtre compétences (toutes)', (await one(`select talents_search('', '', array['sql','python'], 20, 0) r`)).items.map((i) => i.id).join() === S5);
  check('recherche texte compétence', (await one(`select talents_search('flutter', '', '{}', 20, 0) r`)).total === 1);
  check('la recherche ne devine pas un nom complet masqué (Eric Prive -> Prive)', (await one(`select talents_search('Prive', '', '{}', 20, 0) r`)).total === 0);
  check('la recherche d\'un nom complet consenti fonctionne', (await one(`select talents_search('Dupont', '', '{}', 20, 0) r`)).total === 1);
  check('joker % échappé', (await one(`select talents_search('%', '', '{}', 20, 0) r`)).total === 0);
  check('talents_list : même contrat (tableau)', (await one(`select talents_list('', 12) r`)).length === 2);
  for (const [who, id] of [['entreprise non approuvée', COU], ['organisation non approuvée', OTU]]) {
    await as(id);
    r = await one(`select talents_search('', '', '{}', 20, 0) r`);
    check(`E5-3 ${who} : verrouillée, aucun talent`, r.locked === true && r.total === 0 && r.items.length === 0 && /vérifi/.test(r.reason), JSON.stringify(r));
    check(`E5-3 ${who} : talents_list vide`, (await one(`select talents_list('', 12) r`)).length === 0);
  }
  await as(OTA);
  check('organisation (other) approuvée : voit les talents (décision 2)', (await one(`select talents_search('', '', '{}', 20, 0) r`)).total === 2);
  await as(SUS);
  await fails('compte suspendu refusé', `select talents_search('', '', '{}', 20, 0)`, /suspendu/);
  await as(CLI);
  r = await one(`select talents_search('', '', '{}', 20, 0) r`);
  check('client : noms abrégés (jamais le nom complet)', r.total === 2 && r.items.every((i) => i.name_full === false && !/Dupont|Prive/.test(i.name)), JSON.stringify(r));
  await as(S1);
  check('étudiant : noms abrégés, lui-même absent du retrait', (await one(`select talents_search('', '', '{}', 20, 0) r`)).items.every((i) => i.name_full === false));
  await as(DEP);
  r = await one(`select talents_search('', '', '{}', 20, 0) r`);
  check('département : nom complet, le retiré n\'apparaît jamais', r.items.some((i) => i.name === 'Eric Prive') && !r.items.some((i) => i.id === S2));
  await as(ADM);
  check('administrateur : lecture complète', (await one(`select talents_search('', '', '{}', 20, 0) r`)).items.some((i) => i.name === 'Eric Prive'));
  await as(null, 'anon');
  await fails('anonyme : talents_search refusé', `select talents_search('', '', '{}', 20, 0)`, /permission denied/);
  await fails('anonyme : talents_list refusé', `select talents_list('', 5)`, /permission denied/);

  // ================================================================ 2. vivier (E5-3 : _talent_guard)
  await as(COU);
  await fails('E5-3 vivier : entreprise non approuvée refusée', `select talent_lists_get()`, /vérifiée/);
  await as(OTU);
  await fails('vivier : organisation non approuvée refusée', `select talent_lists_get()`, /vérifiée/);
  await as(CLI);
  await fails('vivier : un client n\'a pas accès', `select talent_lists_get()`, /Réservé aux organisations/);
  await as(COA);
  const fav = (await one(`select talent_lists_get() r`))[0].id;
  await works('vivier : entreprise approuvée ajoute un étudiant visible', `select talent_list_add('${fav}', '${S5}')`);
  await fails('E1-1 vivier : l\'étudiant retiré ne s\'ajoute pas', `select talent_list_add('${fav}', '${S2}')`, /Étudiant introuvable/);
  await as(OTA);
  await works('vivier : organisation approuvée (other) accède', `select talent_lists_get()`);
  await db.exec('reset role');
  await db.exec(`insert into student_talent_prefs(user_id, visible_to_recruiters) values ('${S5}', false)`);
  await as(COA);
  const fav2 = (await one(`select talent_lists_get() r`))[0];
  check('vivier : un étudiant qui se retire n\'est plus compté', fav2.count === 0, JSON.stringify(fav2));
  check('vivier : ni listé', (await one(`select talent_list_members_get('${fav}') r`)).length === 0);
  await db.exec('reset role');
  await db.exec(`delete from student_talent_prefs where user_id = '${S5}'`);

  // ================================================================ 3. porte de publication (E1-3, E1-4, E1-19, E1-22, E5-2, E5-8)
  const FUT = new Date(Date.now() + 40 * 86400000).toISOString().slice(0, 10);
  const need = (t, pub, extra = '') => `select save_mission(${extra ? extra : 'null'}, '${t}', 'Une description suffisamment longue du besoin', 1000, 2000, '31/12/2027', ${pub}, 'besoin') r`;
  const needUnpub = (id, t, pub, unp, owner = 'null') => `select save_mission('${id}', '${t}', 'Une description suffisamment longue du besoin', 1000, 2000, null, ${pub}, 'besoin', ${unp}, ${owner}) r`;
  const needFor = (t, pub, owner) => `select save_mission(null, '${t}', 'Une description suffisamment longue du besoin', 1000, 2000, null, ${pub}, 'besoin', false, '${owner}') r`;
  await as(COU);
  let st = await one(`select company_publish_status() r`);
  check('E1-19 statut : entreprise non approuvée ne peut pas publier, raison explicite, brouillon possible',
    st.is_org === true && st.verified === false && st.can.need === false && st.can.offer === false && st.can.contest === false && st.can.draft === true && /vérifiée/.test(st.reasons.need) && st.can_publish === false, JSON.stringify(st));
  await fails('E1-3/E5-2 entreprise non approuvée : publication d\'un besoin refusée', need('Besoin non verifie', true), /vérifiée par l'administrateur/);
  await works('E1-4 entreprise non approuvée : brouillon autorisé', need('Brouillon COU', false));
  await as(OTU);
  st = await one(`select company_publish_status() r`);
  check('E5-8 statut organisation (other) non approuvée : refus identique', st.is_org === true && st.verified === false && /organisation/i.test(st.reasons.need), JSON.stringify(st.reasons));
  await fails('E5-2 other non approuvée : besoin refusé', need('Besoin asso fantome', true), /Votre organisation doit être vérifiée/);
  await works('other non approuvée : brouillon autorisé', need('Brouillon OTU', false));
  await as(COA);
  st = await one(`select company_publish_status() r`);
  check('E1-19 statut : entreprise approuvée, forfait Découverte, quotas restants',
    st.verified === true && st.plan.code === 'free' && st.needs.max === 1 && st.needs.remaining === 1 && st.offers.remaining === 1 && st.contests.max === 0 && st.can.need === true && st.can.offer === true && st.can.contest === false, JSON.stringify(st));
  const NEED1 = await one(need('Besoin Orange 1', true));
  st = await one(`select company_publish_status() r`);
  check('E1-19 statut : quota besoins atteint, raison exacte', st.needs.used === 1 && st.needs.remaining === 0 && st.can.need === false && /forfait « Découverte » est atteint : 1 besoins actifs sur 1/.test(st.reasons.need), JSON.stringify(st.reasons));
  await fails('E1-22 quota exact : deuxième besoin refusé', need('Besoin Orange 2', true), /forfait « Découverte » est atteint : 1 besoins actifs sur 1\. Clôturez une publication active/);
  await works('brouillon possible malgré le quota publié', need('Brouillon Orange', false));
  // E1-18 : « Brouillon » sur un besoin publié
  await as(S1);
  const PROP = await one(`select propose_on_mission('${NEED1}', 50000, 10, 'Je peux le faire') r`);
  await as(COA);
  await fails('E1-18 « Brouillon » sur un besoin publié : refus explicite (pas de dépublication silencieuse)', needUnpub(NEED1, 'Besoin Orange 1', false, false), /Ce besoin est publié.*1 proposition\(s\) en attente.*Utilisez « Publier »/s);
  check('E1-18 le besoin est resté publié', (await one(`select status r from missions where id = '${NEED1}'`)) === 'published');
  await works('E1-18 « Publier » met à jour sans retirer', needUnpub(NEED1, 'Besoin Orange 1 (modifié)', true, false));
  check('E1-18 mise à jour effectuée, toujours publié', (await one(`select title || '/' || status r from missions where id = '${NEED1}'`)) === 'Besoin Orange 1 (modifié)/published');
  await works('E1-18 retrait confirmé (p_unpublish = true)', needUnpub(NEED1, 'Besoin Orange 1 (modifié)', false, true));
  check('E1-18 retiré après confirmation', (await one(`select status r from missions where id = '${NEED1}'`)) === 'draft');
  check('E1-18 le proposant est prévenu', (await rdone(`select count(*)::int r from notifications where user_id = '${S1}' and kind = 'mission' and title = 'Besoin retiré de la liste'`)) === 1);
  await works('republication après retrait', needUnpub(NEED1, 'Besoin Orange 1 (modifié)', true, false));
  // other approuvée, client, étudiant, département, administration (décision 3)
  await as(OTA);
  await works('E5-8 other approuvée : besoin publié (1 sur 1)', need('Besoin Association', true));
  await fails('E5-8 other approuvée : quota Découverte aussi appliqué', need('Besoin Association 2', true), /forfait « Découverte » est atteint/);
  await as(CLI);
  st = await one(`select company_publish_status() r`);
  check('client : pas de forfait, besoin autorisé, offre et concours non', st.is_org === false && st.plan === null && st.can.need === true && st.can.offer === false && st.can.contest === false && st.verified === null, JSON.stringify(st));
  await works('décision 3 : le client publie toujours un besoin', need('Besoin du client', true));
  await as(S5);
  await works('décision 3 : l\'étudiant publie un besoin', need('Besoin etudiant', true));
  await as(DEP);
  await works('décision 3 : le département publie un besoin', need('Besoin dept', true));
  await as(ADM);
  await works('administration : besoin publié', need('Besoin admin', true));
  await db.exec('reset role');
  await mk(CST, 'Compte Test', 'company', 'is_test = true');
  await as(CST);
  await works('compte de test : exempté de la porte (inchangé)', need('Besoin test', true));
  await as(SUS);
  await fails('compte suspendu : publication refusée', need('Besoin suspendu', true), /suspendu/);
  await as(null, 'anon');
  await fails('anonyme : company_publish_status refusé', `select company_publish_status()`, /permission denied/);
  await fails('anonyme : save_mission refusé', need('x', false), /permission denied/);
  // brouillons plafonnés (E1-4) et plafond quotidien (E1-22)
  await as(CLI);
  for (let i = 1; i <= 10; i++) await q(need('Brouillon client ' + i, false));
  await fails('E1-4 onzième brouillon refusé', need('Brouillon client 11', false), /Dix brouillons au plus/);
  const firstDraft = (await q(`select id from missions where client_id = '${CLI}' and status = 'draft' limit 1`))[0].id;
  await q(`select mission_cancel('${firstDraft}')`);
  await works('E1-4 un brouillon annulé libère une place', need('Brouillon client 11', false));
  await works('E1-4 modifier un brouillon existant reste possible au plafond', needUnpub((await q(`select id from missions where client_id = '${CLI}' and status = 'draft' limit 1`))[0].id, 'Brouillon renomme', false, false));
  const ids = (await q(`select id from missions where client_id = '${CLI}' and status = 'draft' order by created_at limit 4`)).map((x) => x.id);
  for (const id of ids) await q(needUnpub(id, 'Publication ' + id.slice(-4), true, false));
  st = await one(`select company_publish_status() r`);
  check('E1-22 statut quotidien : 5 publications, prochaine date indiquée', st.daily.used === 5 && st.daily.next_at && st.can.need === false && /5 besoins publiés par jour \(les besoins annulés comptent\)/.test(st.reasons.need), JSON.stringify(st.daily));
  await fails('E1-22 sixième publication : message exact avec heure de reprise', needUnpub((await q(`select id from missions where client_id = '${CLI}' and status = 'draft' limit 1`))[0].id, 'Sixieme', true, false), /Prochaine publication possible vers \d\d\/\d\d à \d\dh\d\d \(heure du Cameroun\)/);
  await q(`select mission_cancel('${ids[0]}')`);
  await fails('E1-22 un besoin annulé compte toujours dans les 5 par jour (le message ne ment plus)', needUnpub((await q(`select id from missions where client_id = '${CLI}' and status = 'draft' limit 1`))[0].id, 'Septieme', true, false), /les besoins annulés comptent/);

  // ---- offres (E5-2, E5-7, E5-8)
  const opp = (org, extra = '') => `select opp_save('${org}', 'stage', 'CDD', 'Stage dev mobile', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', '${FUT}', array['Flutter'], 'Description de l offre de stage assez longue', array['Developper'], 'Profil', 'GL', 'L3', array['Transport'], '+237690000000', true, 'A propos', false${extra}) r`;
  await as(COU);
  await fails('E5-2 offre : entreprise non approuvée refusée', opp('Faux'), /vérifiée/);
  await as(OTU);
  await fails('E5-8 offre : other non approuvée refusée', opp('Faux'), /vérifiée/);
  await as(CLI);
  await fails('offre : un client ne publie pas d\'offre', opp('Client SARL'), /Réservé aux organisations/);
  await as(S5);
  await fails('offre : un étudiant ne publie pas d\'offre', opp('Etudiant SARL'), /Réservé aux organisations/);
  await as(COA);
  const OPP1 = await one(opp('Nom libre usurpe'));
  check('E5-7 offre : le nom de l\'organisation est celui de la fiche approuvée', (await rdone(`select org_name r from opportunities where id = '${OPP1}'`)) === 'Orange Cameroun');
  await fails('E5-2 offre : quota Découverte (1 offre) appliqué', opp('Orange'), /forfait « Découverte » est atteint : 1 offres actifs sur 1/);
  await as(OTA);
  await works('E5-8 offre : other approuvée publie (nom de sa fiche)', opp('Autre nom'));
  check('E5-7 offre other : nom de la fiche', (await rdone(`select org_name r from opportunities where poster_id = '${OTA}' limit 1`)) === 'Association Espoir');
  await as(DEP);
  await works('offre : le département garde un nom libre', opp('Partenaire Libre'));
  check('offre du département publiée directement', (await rdone(`select org_name || '/' || status r from opportunities where poster_id = '${DEP}' limit 1`)) === 'Partenaire Libre/published');

  // ---- concours (E5-2, E5-14, E6-13)
  const ann = (extra = {}) => `select ann_save('${JSON.stringify({ title: 'Concours innovation', organizer: 'Quelqu un', organizer_kind: 'government', kind: 'contest', official_url: 'https://orange.cm/concours', deadline: FUT, ...extra }).replace(/'/g, "''")}'::jsonb) r`;
  await as(COU);
  await fails('E5-2 concours : entreprise non approuvée refusée', ann(), /vérifiée/);
  await as(OTU);
  await fails('E5-8 concours : other non approuvée refusée', ann(), /vérifiée/);
  await as(CLI);
  await fails('concours : un client est refusé', ann(), /Réservé à l'équipe/);
  await as(COA);
  await fails('E5-2 concours : forfait Découverte (0 concours) : refus', ann(), /forfait « Découverte » est atteint : 0 concours actifs sur 0/);
  await db.exec('reset role');
  await db.exec(`insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at) values ('${COA}', 'pro', 'active', now(), now() + interval '30 days'), ('${OTA}', 'pro', 'active', now(), now() + interval '30 days')`);
  await as(COA);
  const ANN1 = await one(ann());
  const row = (await rd(`select organizer, organizer_kind, status from contest_announcements where id = '${ANN1}'`))[0];
  check('E6-13 concours company : organisateur = fiche, type imposé « company »', row.organizer === 'Orange Cameroun' && row.organizer_kind === 'company' && row.status === 'pending', JSON.stringify(row));
  await works('concours : deuxième autorisé (forfait Entreprise : 2)', ann({ title: 'Concours deux' }));
  await fails('E5-14 troisième refusé (pas de dépassement de 1)', ann({ title: 'Concours trois' }), /forfait « Organisation » est atteint : 2 concours actifs sur 2/);
  await fails('E5-14 même avec un id fourni dans la charge, le quota tient', ann({ title: 'Concours quatre', id: ANN1 }), /forfait « Organisation » est atteint/);
  await as(OTA);
  const ANN2 = await one(ann());
  check('E6-13 concours other : « government » ramené à « ngo »', (await rdone(`select organizer_kind r from contest_announcements where id = '${ANN2}'`)) === 'ngo');
  await as(DEP);
  const ANN3 = await one(ann({ organizer: 'Université de Douala', organizer_kind: 'university' }));
  check('concours du département : libre et publié', (await rdone(`select organizer || '/' || organizer_kind || '/' || status r from contest_announcements where id = '${ANN3}'`)) === 'Université de Douala/university/published');

  // ---- duels (E5-15)
  const duel = (prize = 'Un stage de trois mois') => `select duel_create('Refonte du logo', '${prize}', 24) r`;
  await as(COU);
  await fails('E5-15 duel : entreprise non approuvée refusée', duel(), /vérifiée/);
  await as(OTU);
  await fails('E5-15 duel : other non approuvée refusée', duel(), /vérifiée/);
  await as(S5);
  await fails('duel : un étudiant ne le crée pas', duel(), /Action non autorisée/);
  await as(COA);
  const DUEL1 = await one(duel());
  await fails('E5-15 prix chiffré en FCFA refusé', duel('50 000 FCFA'), /ne peut pas être une somme d'argent/);
  await fails('E5-15 prix chiffré (€) refusé', duel('100 €'), /ne peut pas être une somme d'argent/);
  await fails('E5-15 prix chiffré (XAF) refusé', duel('XAF 20000'), /ne peut pas être une somme d'argent/);
  await works('prix sans somme accepté', duel('Un casque audio'));
  await as(OTA);
  await works('duel : other approuvée', duel());
  await as(CLI);
  await works('duel : le client garde la possibilité', duel('Visibilité sur nos réseaux'));
  const dl = await one(`select duels_list('all', 50, 0) r`);
  check('E5-15 le prix est étiqueté comme non financier', dl.length >= 3 && dl.every((d) => !d.prize || /non financière/.test(d.prize_note)), JSON.stringify(dl[0]));

  // ================================================================ 4. publication au nom de l'entreprise (E5-19)
  const MA = U(21), MF = U(22), MV = U(23), MI = U(24), STR = U(25), MU = U(26);
  await db.exec('reset role');
  await mk(MA, 'Membre Admin', 'client'); await mk(MF, 'Membre Finance', 'student'); await mk(MV, 'Membre Lecteur', 'client'); await mk(MI, 'Membre Invite', 'client'); await mk(STR, 'Etranger Total', 'client'); await mk(MU, 'Membre Unapproved', 'client');
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${COA}', '${MA}', 'admin', 'active'), ('${COA}', '${MF}', 'finance', 'active'), ('${COA}', '${MV}', 'viewer', 'active'), ('${COA}', '${MI}', 'admin', 'invited'), ('${COU}', '${MU}', 'admin', 'active')`);
  await as(MA);
  st = await one(`select company_publish_status('${COA}') r`);
  check('E5-19 statut au nom de l\'entreprise : forfait et quotas de l\'ENTREPRISE', st.verified === true && st.plan.code === 'pro' && st.team_role === 'admin' && st.can.need === true, JSON.stringify(st));
  const MN = await one(needFor('Besoin publie par equipe', true, COA));
  const mrow = (await rd(`select client_id, created_by, status from missions where id = '${MN}'`))[0];
  check('E5-19 un administrateur d\'équipe publie au nom de l\'entreprise (client_id = entreprise, auteur tracé)', mrow.client_id === COA && mrow.created_by === MA && mrow.status === 'published', JSON.stringify(mrow));
  await works('E5-19 il peut modifier le besoin de l\'entreprise', needUnpub(MN, 'Besoin equipe modifie', true, false, `'${COA}'`));
  await fails('E5-19 il ne peut pas toucher aux besoins de l\'entreprise sans p_owner', needUnpub(MN, 'Autre', true, false), /Besoin introuvable/);
  await db.exec('reset role');
  check('E5-19 le propriétaire est prévenu et l\'audit tracé',
    (await one(`select count(*)::int r from notifications where user_id = '${COA}' and kind = 'company_team' and title = 'Besoin publié par votre équipe'`)) === 1 &&
    (await one(`select count(*)::int r from audit_log where actor = '${MA}' and action like 'Besoin publié au nom%'`)) === 1);
  await as(MA);
  const OPPM = await one(opp('Nom libre', `, '${COA}'`));
  check('E5-19 offre au nom de l\'entreprise : poster_id = entreprise, posted_by = membre, nom de la fiche', JSON.stringify((await rd(`select poster_id, posted_by, org_name from opportunities where id = '${OPPM}'`))[0]) === JSON.stringify({ poster_id: COA, posted_by: MA, org_name: 'Orange Cameroun' }));
  await db.exec('reset role');
  await db.exec(`update contest_announcements set status = 'closed' where poster_id = '${COA}' and title = 'Concours deux'`);
  await as(MA);
  const ANNM = await one(`select ann_save('${JSON.stringify({ title: 'Concours membre', organizer: 'x', organizer_kind: 'government', kind: 'contest', official_url: 'https://orange.cm/m', deadline: FUT })}'::jsonb, '${COA}') r`);
  check('E5-19 concours au nom de l\'entreprise : poster_id = entreprise, posted_by = membre, organisateur = fiche',
    JSON.stringify((await rd(`select poster_id, posted_by, organizer, organizer_kind from contest_announcements where id = '${ANNM}'`))[0]) === JSON.stringify({ poster_id: COA, posted_by: MA, organizer: 'Orange Cameroun', organizer_kind: 'company' }));
  await fails('E5-19 le quota de concours de l\'ENTREPRISE s\'applique au membre (2 déjà)', `select ann_save('${JSON.stringify({ title: 'Encore un', organizer: 'x', kind: 'contest', official_url: 'https://orange.cm/m', deadline: FUT })}'::jsonb, '${COA}') r`, /forfait « Organisation » est atteint/);
  await as(MF);
  await fails('E5-19 un membre « finance » ne publie pas', needFor('Besoin finance', true, COA), /Réservé au propriétaire et aux administrateurs/);
  await as(MV);
  await fails('E5-19 un lecteur ne publie pas', needFor('Besoin lecteur', true, COA), /Réservé au propriétaire et aux administrateurs/);
  await fails('E5-19 un lecteur ne dépose pas d\'offre', opp('x', `, '${COA}'`), /Réservé au propriétaire et aux administrateurs/);
  await as(MI);
  await fails('E5-19 un invité non accepté ne publie pas', needFor('Besoin invité', true, COA), /Accès refusé/);
  await as(STR);
  await fails('E5-19 un étranger à l\'entreprise ne publie pas', needFor('Besoin étranger', true, COA), /Accès refusé/);
  await fails('E5-19 ni d\'offre', opp('x', `, '${COA}'`), /Accès refusé/);
  await as(MU);
  await fails('E5-19 la vérification reste exigée : entreprise non approuvée, même par son administrateur', needFor('Besoin MU', true, COU), /Votre organisation doit être vérifiée/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${MA}'`);
  await as(MA);
  await fails('E5-19 un administrateur d\'équipe suspendu ne publie plus', needFor('Besoin suspendu MA', true, COA), /suspendu|Accès refusé/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${MA}'`);

  // ================================================================ 5. contacts avec les talents (E5-5, E6-8)
  const COB = U(31), SP = [U(41), U(42), U(43), U(44), U(45)];
  await db.exec('reset role');
  await mk(COB, 'Banque Atlas', 'company');
  await db.exec(`insert into company_profiles(owner_id, company_name, status) values ('${COB}', 'Banque Atlas', 'approved')`);
  for (let i = 0; i < SP.length; i++) await mk(SP[i], 'Spare Etudiant' + String.fromCharCode(65 + i), 'student', `skills = 'Excel'`);
  await db.exec(`insert into cv_links(token, owner_id, consent_at) values ('${'b'.repeat(32)}', '${S2}', now())`);
  const contact = (u, k = 'contact', m = '') => `select talent_contact_request('${u}', '${k}', '${m}') r`;
  await as(COU);
  await fails('E5-3/E6-8 contact : entreprise non approuvée refusée', contact(S1), /vérifiée par l'administrateur/);
  await as(OTU);
  await fails('E6-8 contact : other non approuvée refusée', contact(S1), /vérifiée par l'administrateur/);
  await as(S5);
  await fails('contact : un étudiant ne peut pas', contact(S1), /réservée aux organisations/);
  await as(SUS);
  await fails('contact : compte suspendu refusé', contact(S1), /réservée|suspendu/);
  await as(null, 'anon');
  await fails('contact : anonyme refusé', contact(S1), /permission denied/);
  await as(CLI);
  await fails('E6-8 contact : un client ne fait pas de proposition de stage', contact(S1, 'internship_offer', 'Un stage de six mois'), /réservée aux organisations vérifiées/);
  await works('contact : un client peut adresser une demande de contact', contact(S1, 'contact', 'Bonjour'));
  await as(COA);
  await fails('contact : proposition de stage sans texte utile refusée', contact(S1, 'internship_offer', 'Stage'), /10 caractères/);
  await fails('E1-1 contact : talent retiré des recruteurs introuvable (même avec un CV publié)', contact(S2, 'contact', 'Bonjour'), /Talent introuvable/);
  await fails('contact : talent non vérifié introuvable', contact(S3, 'contact', 'Bonjour'), /Talent introuvable/);
  await fails('contact : talent sans CV publié', contact(S5, 'contact', 'Bonjour'), /n'a pas publié son CV/);
  await works('E6-8 contact : entreprise approuvée → talent visible avec CV publié (texte nettoyé)', `select talent_contact_request('${S1}', 'internship_offer', 'Stage de six mois' || chr(1) || ' en developpement') r`);
  check('E6-8 le texte est nettoyé des caractères de contrôle', (await rdone(`select message r from talent_contacts where sender_id = '${COA}' and target_id = '${S1}'`)) === 'Stage de six mois en developpement');
  check('E6-8 le talent voit la raison sociale approuvée (jamais un autre nom)', /^Orange Cameroun vous propose un stage/.test(await rdone(`select body r from notifications where user_id = '${S1}' and kind = 'talent_contact' and title = 'Proposition de stage'`)));
  await fails('contact : doublon du jour', contact(S1, 'internship_offer', 'Stage de six mois encore'), /déjà adressé/);
  // quota serveur de 10 par jour et texte répété (COB)
  await db.exec('reset role');
  for (let i = 0; i < 3; i++) await db.exec(`insert into talent_contacts(sender_id, target_id, kind, message) values ('${COB}', '${SP[i]}', 'contact', 'Offre identique pour tous')`);
  await as(COB);
  await fails('E6-8 le même texte envoyé à trois talents : quatrième refusé', contact(S1, 'contact', 'Offre identique pour tous'), /même message a déjà été envoyé à trois talents/);
  await db.exec('reset role');
  for (let i = 3; i < 5; i++) await db.exec(`insert into talent_contacts(sender_id, target_id, kind, message) values ('${COB}', '${SP[i]}', 'contact', 'a'), ('${COB}', '${SP[i]}', 'internship_offer', 'b')`);
  for (let i = 0; i < 3; i++) await db.exec(`insert into talent_contacts(sender_id, target_id, kind, message) values ('${COB}', '${SP[i]}', 'internship_offer', 'c${i}')`);
  await as(COB);
  await fails('E6-8 quota serveur : dix demandes par jour au plus', contact(S1, 'contact', 'Un texte différent'), /Dix demandes par jour/);

  const dm = (u, b = 'Bonjour, une proposition de mission') => `select start_direct_conversation('${u}', '${b}') r`;
  await as(COU);
  await fails('E5-5 message direct : entreprise non approuvée → talent refusée', dm(S1), /vérifiée par l'administrateur/);
  await as(OTU);
  await fails('E5-5 message direct : other non approuvée refusée', dm(S1), /vérifiée par l'administrateur/);
  await as(COA);
  await fails('E5-5 message direct : talent non proposé aux recruteurs → introuvable', dm(S2), /Destinataire introuvable/);
  await fails('E5-5 message direct : talent non vérifié → introuvable', dm(S3), /Destinataire introuvable/);
  await fails('E5-5 message direct : une entreprise n\'écrit pas à un client', dm(CLI), /Destinataire introuvable/);
  await fails('message direct : texte vide après nettoyage', `select start_direct_conversation('${S1}', chr(1) || '  ') r`, /Message vide/);
  const CV1 = await one(dm(S1));
  check('E5-5 message direct : entreprise approuvée → talent visible', !!CV1);
  check('message direct : même conversation réutilisée', (await one(dm(S1, 'Deuxième message'))) === CV1);
  await works('message direct : une entreprise écrit à l\'équipe de la plateforme', dm(ADM, 'Question sur ma verification'));
  await as(S2);
  const CV2 = await one(dm(COA, 'Bonjour, je vous écris le premier'));
  await as(COA);
  check('E5-5 réponse possible dans une conversation ouverte par le talent (même retiré)', (await one(dm(S2, 'Merci pour votre message'))) === CV2);
  await as(CLI);
  await works('message direct : un client écrit toujours à un étudiant retiré (pas une entreprise)', dm(S2, 'Bonjour'));
  await as(S1);
  await works('message direct : l\'étudiant écrit à une entreprise', dm(COB, 'Bonjour'));
  await db.exec('reset role');
  for (let i = 0; i < 10; i++) await db.exec(`insert into conversations(created_by) values ('${COB}')`);
  await as(COB);
  await fails('E6-8 quota serveur : dix nouvelles conversations par jour pour une entreprise', dm(S5, 'Bonjour'), /Dix nouvelles conversations par jour/);

  // ================================================================ 6. CV, passeport, profil public (E5-6)
  await as(COU);
  await fails('E5-6 CV : entreprise non approuvée refusée', `select cv_public('${S1}')`, /vérifiée par l'administrateur/);
  await as(COA);
  let cv = await one(`select cv_public('${S1}') r`);
  check('E5-6 CV : entreprise approuvée, lien publié → nom complet (consentement)', cv && cv.nom === 'Alice Dupont' && cv.user_id === S1, JSON.stringify(cv));
  check('E5-6 CV : jamais de téléphone ni d\'e-mail', !/phone|telephone|@t\.cm/i.test(JSON.stringify(cv)));
  check('E5-6 CV : sans lien publié → rien', (await one(`select cv_public('${S5}') r`)) === null);
  check('E1-1 CV : talent retiré des recruteurs → rien, même avec un lien', (await one(`select cv_public('${S2}') r`)) === null);
  await as(CLI);
  check('E5-6 CV : un client voit le nom abrégé', (await one(`select cv_public('${S1}') r`)).nom === 'Alice D.');
  await as(S1);
  check('CV : la personne se voit en entier', (await one(`select cv_public('${S1}') r`)).nom === 'Alice Dupont');
  await as(DEP);
  check('CV : le département voit le nom complet', (await one(`select cv_public('${S1}') r`)).nom === 'Alice Dupont');
  await as(null, 'anon');
  await fails('E5-6 CV : anonyme refusé (cv_public)', `select cv_public('${S1}')`, /permission denied/);
  check('CV : le lien secret reste public (shared_cv)', (await one(`select shared_cv('${'a'.repeat(32)}') r`)).nom === 'Alice Dupont');
  check('E5-6 passeport anonyme : nom abrégé', (await one(`select talent_passport('${S1}') r`)).name === 'Alice D.');
  await as(COU);
  check('E5-6 passeport : entreprise non approuvée → rien d\'un étudiant', (await one(`select talent_passport('${S1}') r`)) === null);
  await as(COA);
  check('passeport : entreprise approuvée + CV publié → nom complet', (await one(`select talent_passport('${S1}') r`)).name === 'Alice Dupont');
  check('passeport : entreprise approuvée sans CV publié → nom abrégé', (await one(`select talent_passport('${S5}') r`)).name === 'Eric P.');
  await as(CLI);
  check('passeport : client inchangé', (await one(`select talent_passport('${S1}') r`)).name === 'Alice Dupont');
  await as(null, 'anon');
  check('profil public anonyme : nom abrégé', (await one(`select public_profile('${S1}') r`)).name === 'Alice D.');
  await as(COU);
  check('E5-3 profil public : entreprise non approuvée → nom abrégé', (await one(`select public_profile('${S1}') r`)).name === 'Alice D.');
  await as(COA);
  check('profil public : entreprise approuvée → complet seulement avec CV publié', (await one(`select public_profile('${S1}') r`)).name === 'Alice Dupont' && (await one(`select public_profile('${S5}') r`)).name === 'Eric P.');
  check('profil public : une entreprise garde son propre nom complet', (await one(`select public_profile('${COA}') r`)).name === 'Orange Cameroun');

  // ---- envoi du CV à une entreprise (E5-11)
  await as(S1);
  check('E5-11 envoi de CV : réponse identique pour une entreprise approuvée', (await one(`select send_cv_to_recruiter('orangecameroun@t.cm', 'Mon CV') r`)) === 'sent');
  check('E5-11 envoi de CV : réponse identique pour une entreprise NON approuvée', (await one(`select send_cv_to_recruiter('fauxentrepreneur@t.cm', 'Mon CV') r`)) === 'sent');
  check('E5-11 envoi de CV : réponse identique pour une adresse inconnue', (await one(`select send_cv_to_recruiter('inconnu@nulle.part', 'Mon CV') r`)) === 'sent');
  check('E5-11 seule l\'entreprise approuvée reçoit le CV', (await rdone(`select count(*)::int r from cv_sends where sender_id = '${S1}' and recipient_id = '${COA}'`)) === 1 && (await rdone(`select count(*)::int r from cv_sends where sender_id = '${S1}' and recipient_id = '${COU}'`)) === 0);

  // ================================================================ 7. gagnant d'un concours (E5-11)
  const PRIZE = '00000000-0000-0000-0000-0000000f0f01';
  await db.exec('reset role');
  await db.exec(`insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status) values ('event', 'PRZ-F1', '${COB}', null, 5000, 5000, 'séquestre défi', 'held')`);
  await db.exec(`insert into contest_announcements (id, poster_id, title, organizer, kind, status, official_url, prize_amount, prize_status, prize_entry) values ('${PRIZE}', '${COB}', 'Defi Atlas', 'Banque Atlas', 'contest', 'published', 'https://atlas.cm/d', 5000, 'held', (select id from money_entries where ref = 'PRZ-F1'))`);
  await db.exec(`insert into contest_ann_saves (announcement_id, user_id) values ('${PRIZE}', '${S1}'), ('${PRIZE}', '${S3}')`);
  await as(COB);
  const msgs = [];
  for (const mail of ['inconnu@t.cm', 'ericprive@t.cm', 'carlnonverifie@t.cm']) msgs.push(await one(`select ann_prize_award('${PRIZE}', '${mail}') r`));
  check('E5-11 adresse inconnue / étudiant sans lien / étudiant non vérifié : même réponse (aucun oracle)', msgs.every((m) => m === 'not_eligible'), JSON.stringify(msgs));
  await as(COA);
  await fails('E5-11 une autre entreprise ne désigne pas de gagnant', `select ann_prize_award('${PRIZE}', 'aliceDupont@t.cm')`, /Annonce introuvable/);
  await as(COB);
  check('E5-11 gagnant lié à l\'annonce (enregistrée) et vérifié : attribué', (await one(`select ann_prize_award('${PRIZE}', 'alicedupont@t.cm') r`)) === 'awarded');
  check('E5-11 le gagnant est bien celui désigné', (await rdone(`select prize_winner r from contest_announcements where id = '${PRIZE}'`)) === S1);
  const PRIZE2 = '00000000-0000-0000-0000-0000000f0f02';
  await db.exec('reset role');
  await db.exec(`insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status) values ('event', 'PRZ-F2', '${COB}', null, 5000, 5000, 'séquestre défi', 'held')`);
  await db.exec(`insert into contest_announcements (id, poster_id, title, organizer, kind, status, official_url, prize_amount, prize_status, prize_entry) values ('${PRIZE2}', '${COB}', 'Defi Atlas 2', 'Banque Atlas', 'contest', 'published', 'https://atlas.cm/d2', 5000, 'held', (select id from money_entries where ref = 'PRZ-F2'))`);
  await as(COB);
  let lim = '';
  for (let i = 0; i < 12; i++) { try { await q(`select ann_prize_award('${PRIZE2}', 'x${i}@t.cm')`); } catch (e) { lim = e.message; } }
  check('E5-11 tentatives limitées à dix par jour', /Dix tentatives par jour/.test(lim), lim);

  // ================================================================ 8. étiquettes honnêtes des besoins et offres (E5-7, E6-4, E5-12)
  await db.exec('reset role');
  await db.exec(`insert into missions (number, client_id, kind, title, description, total, status, budget_max, published_at) values
    ('#F1-1', '${COU}', 'besoin', 'Besoin ancien COU', 'Description longue de ce besoin ancien', 10, 'published', 10, now()),
    ('#F1-2', '${SUS}', 'besoin', 'Besoin du suspendu', 'Description longue de ce besoin suspendu', 10, 'published', 10, now())`);
  await as(S5);
  const nl = await one(`select open_needs_list(null, 100) r`);
  const byTitle = (t) => nl.find((x) => x.title.startsWith(t));
  const orange = byTitle('Besoin Orange 1'), client = byTitle('Besoin du client'), stu = byTitle('Besoin etudiant'), old = byTitle('Besoin ancien COU');
  check('E5-7 besoin d\'une entreprise approuvée : raison sociale + badge vérifié + identifiant', orange && orange.company === 'Orange Cameroun' && orange.verified === true && orange.company_id === COA && orange.poster_role === 'company', JSON.stringify(orange));
  check('E6-4 besoin d\'un client : nom abrégé + rôle, jamais « entreprise », non vérifié', client && client.company === 'Claire C. · Client' && client.verified === false && client.company_id === null && !/Claire Client/.test(JSON.stringify(client)), JSON.stringify(client));
  check('E6-4 besoin d\'un étudiant : étiquette honnête', stu && stu.company === 'Alice D. · Étudiant' || stu && /Étudiant/.test(stu.company), JSON.stringify(stu));
  check('E5-7 besoin d\'une entreprise non approuvée : « non vérifiée », sans badge', old && /^Faux E\. · Organisation non vérifiée$/.test(old.company) && old.verified === false, JSON.stringify(old));
  check('E6-4 besoin d\'un compte suspendu : filtré', !byTitle('Besoin du suspendu'));
  const cl = await one(`select open_calls(null, 100, 'recent', null) r`);
  check('E6-4 open_calls : mêmes étiquettes, suspendu filtré', cl.find((x) => x.title.startsWith('Besoin Orange 1')).company === 'Orange Cameroun' && cl.find((x) => x.title.startsWith('Besoin du client')).company === 'Claire C. · Client' && !cl.some((x) => x.title === 'Besoin du suspendu'));
  await as(null, 'anon');
  await fails('open_needs_list : anonyme refusé', `select open_needs_list(null, 10)`, /permission denied/);

  // ---- opp_detail anonyme (E5-12)
  await db.exec('reset role');
  await db.exec(`update opportunities set status = 'published' where id = '${OPP1}'`);
  await as(null, 'anon');
  const od = await one(`select opp_detail('${OPP1}') r`);
  check('E5-12 opp_detail visiteur : pas de numéro WhatsApp', od.apply_whatsapp === '' && !/690000000/.test(JSON.stringify(od)), JSON.stringify(od.apply_whatsapp));
  await as(S1);
  check('E5-12 opp_detail connecté : numéro fourni', (await one(`select opp_detail('${OPP1}') r`)).apply_whatsapp === '+237690000000');

  // ================================================================ 9. E5-1 : le rôle company reste auto-déclarable mais ne donne aucun pouvoir sensible
  const NEWC = U(51), NEWO = U(52);
  await db.exec('reset role');
  await db.exec(`insert into auth.users(id,email) values ('${NEWC}','nouvelleentreprise@t.cm'), ('${NEWO}','nouvelleasso@t.cm')`);
  await as(NEWC);
  await works('E5-1 inscription : le rôle « company » reste auto-déclarable (décision 1)', `insert into profiles(id, name, role, email) values ('${NEWC}', 'Nouvelle Entreprise', 'company', 'nouvelleentreprise@t.cm')`);
  await as(NEWO);
  await fails('H1 inscription : le rôle « other » n\'est plus attribuable à l\'inscription', `insert into profiles(id, name, role, email) values ('${NEWO}', 'Nouvelle Asso', 'other', 'nouvelleasso@t.cm')`, /row-level security/);
  await db.exec('reset role');
  await db.exec(`insert into profiles(id, name, role, email) values ('${NEWO}', 'Nouvelle Asso', 'other', 'nouvelleasso@t.cm')`);
  for (const [who, id] of [['company', NEWC], ['other', NEWO]]) {
    await as(id);
    check(`E5-1 ${who} auto-déclaré : aucun talent nominatif`, (await one(`select talents_search('', '', '{}', 20, 0) r`)).locked === true);
    await fails(`E5-1 ${who} auto-déclaré : ni publication, ni offre`, need('Besoin auto', true), /doit être vérifiée/);
    await fails(`E5-1 ${who} auto-déclaré : pas de message direct à un talent`, `select start_direct_conversation('${S1}', 'Bonjour')`, /doit être vérifiée/);
    await fails(`E5-1 ${who} auto-déclaré : pas de vivier`, `select talent_lists_get()`, /doit être vérifiée/);
    await fails(`E5-1 ${who} auto-déclaré : pas de duel`, duel(), /doit être vérifiée/);
  }
  // l'approbation de la fiche débloque la porte (la vérification est unique : décision 5 côté lot F2)
  await db.exec('reset role');
  await db.exec(`insert into company_profiles(owner_id, company_name, status) values ('${NEWC}', 'Nouvelle Entreprise SA', 'approved')`);
  await as(NEWC);
  check('E5-1 après approbation de la fiche : talents visibles', (await one(`select talents_search('', '', '{}', 20, 0) r`)).locked === false);
  await works('E5-1 après approbation : publication possible', need('Besoin NEWC', true));

  console.log(`\nent_f1 : ${ok}/${ok + ko}`);
}
