// Scénario PGlite du lot F3b (migration 20261118030000) : besoins et propositions de l'entreprise.
//   robocopy supabase C:\tmp\fixroot\F3b\supabase /E /XD functions ; cd C:\tmp\fixroot\F3b\supabase\tests\marketplace_pglite ; node replay.mjs all ./ent_f3b.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  // 21 : propriétaire (client), 22 et 23 : talents, 24 : membre d'équipe, 25 : tiers
  const roles = { 21: ['Marie Essono Biyick', 'client'], 22: ['Jean Mballa', 'student'], 23: ['Paul Ndzana', 'student'], 24: ['Alice Membre', 'client'], 25: ['Xavier Tiers', 'client'] };
  for (const [n, [nm, r]] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','f3b${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','${nm}','${r}','f3b${n}@t.cm')`);
  }
  await db.exec(`update profiles set certification = 'approved' where id = '${U(22)}'`);
  await db.exec(`update profiles set phone = '69032' || right(id::text, 4), phone_verified = true where id in ('${U(22)}', '${U(23)}')`);   // L4 : proposer un devis exige un étudiant éligible
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(23)}', 'student_card', 'c.pdf', '${U(23)}/c.pdf', 'application/pdf', 10, 'verified')`);   // vérifié par une pièce, SANS certification
  await db.exec(`insert into projects (owner_id, title, status, visibility) values ('${U(22)}', 'Projet public A', 'approved', 'public'), ('${U(22)}', 'Projet public B', 'approved', 'public'), ('${U(22)}', 'Projet prive', 'approved', 'private'), ('${U(22)}', 'Projet brouillon', 'draft', 'public')`);

  // 1. date réelle de l'échéance, calculée depuis le texte libre
  await as(U(21));
  const need = (t, dl, pub = true, kind = 'besoin') => `select save_mission(null, '${t}', 'Un besoin décrit avec plus de vingt caractères', 50000, 100000, '${dl}', ${pub}, '${kind}') id`;
  const dl = async (id) => { await db.exec('reset role'); const v = (await q(`select deadline_date::text d from missions where id = '${id}'`))[0].d; await as(U(21)); return v; };
  const ids = {};
  ids.fr = (await q(need('Echeance JJ/MM/AAAA', '30/11/2030')))[0].id;
  ids.iso = (await q(need('Echeance ISO', '2030-12-05')))[0].id;
  ids.txt = (await q(need('Echeance texte', '30 nov. 2030', false)))[0].id;
  ids.accent = (await q(need('Echeance accent', '1er févr. 2031', false)))[0].id;
  check('echeance : dd/MM/yyyy', (await dl(ids.fr)) === '2030-11-30');
  check('echeance : ISO', (await dl(ids.iso)) === '2030-12-05');
  check('echeance : « 30 nov. 2030 »', (await dl(ids.txt)) === '2030-11-30');
  check('echeance : « 1er févr. 2031 »', (await dl(ids.accent)) === '2031-02-01');
  const bad = (await q(need('Echeance invalide', '31/02/2030', false)))[0].id;
  check('echeance : date impossible = null (pas d erreur)', (await dl(bad)) === null);
  const none = (await q(need('Echeance vide', '', false)))[0].id;
  check('echeance : vide = null', (await dl(none)) === null);
  await db.exec('reset role');
  await db.exec(`update missions set deadline = '12/12/2031' where id = '${bad}'`);
  check('echeance : mise a jour du texte recalcule la date', (await q(`select deadline_date::text d from missions where id = '${bad}'`))[0].d === '2031-12-12');
  await as(U(21));

  // 2. besoin annulé, brouillon et mission sur mesure
  const cancelled = (await q(need('Besoin annule', '2030-01-01')))[0].id;
  const custom = (await q(need('Mission sur mesure', '2030-01-01', true, 'mission')))[0].id;

  // 3. propositions
  await as(U(22));
  const pA = (await q(`select propose_on_mission('${ids.fr}', 80000, 7, 'Je propose une application avec tableau de bord.') id`))[0].id;
  await q(`select propose_on_mission('${ids.iso}', 65000, 5, 'Autre besoin') id`);
  await q(`select propose_on_mission('${cancelled}', 40000, 5, 'Sur un besoin annule') id`);
  await as(U(23));
  const pB = (await q(`select propose_on_mission('${ids.fr}', 120000, 10, 'Equipe de deux') id`))[0].id;
  await as(U(21));
  await q(`select mission_cancel('${cancelled}')`);

  const missions = (await q(`select company_missions() r`))[0].r;
  const byId = Object.fromEntries(missions.map((m) => [m.id, m]));
  check('missions : seulement les besoins du propriétaire', missions.length === 8, String(missions.length));
  check('missions : propositions actives (2 sur le besoin 1)', byId[ids.fr].proposals === 2 && byId[ids.fr].proposals_total === 2);
  check('missions : id et date réelle exposés', byId[ids.fr].deadline_date === '2030-11-30' && byId[ids.fr].deadline === '30/11/2030');
  check('missions : besoin publié compte', byId[ids.fr].is_need === true);
  check('missions : brouillon ne compte pas', byId[bad].is_need === false);
  check('missions : annulé ne compte pas', byId[cancelled].is_need === false && byId[cancelled].status === 'cancelled');
  check('missions : mission sur mesure ne compte pas', byId[custom].is_need === false && byId[custom].kind === 'mission');
  check('missions : propositions déclinées par l annulation non comptées comme actives', byId[cancelled].proposals === 0 && byId[cancelled].proposals_total === 1);

  const props = (await q(`select company_proposals() r`))[0].r;
  const A = props.find((p) => p.id === pA);
  check('propositions : auteur abrégé', A.author === 'Jean M.' && !JSON.stringify(props).includes('Mballa'));
  check('propositions : message, ids, montant, délai', A.message.startsWith('Je propose') && A.mission_id === ids.fr && A.author_id === U(22) && A.amount === 80000 && A.delay_days === 7);
  check('propositions : certification et projets publics de l auteur', A.author_certified === true && A.author_projects === 2);
  const B = props.find((p) => p.id === pB);
  check('propositions : auteur non certifié, sans projet', B.author_certified === false && B.author_projects === 0);
  check('propositions : statut du besoin', props.find((p) => p.mission_status === 'cancelled') !== undefined);

  // 4. isolement et équipe
  await as(U(25));
  check('tiers : ne voit aucun besoin', (await q(`select company_missions() r`))[0].r.length === 0);
  check('tiers : ne voit aucune proposition', (await q(`select company_proposals() r`))[0].r.length === 0);
  await fails('tiers : ne lit pas l entreprise d un autre', `select company_missions('${U(21)}')`, /Accès refusé/);
  await fails('tiers : ne lit pas les propositions d un autre', `select company_proposals('${U(21)}')`, /Accès refusé/);
  await db.exec('reset role');
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name) values ('${U(21)}', 'Societe F3b', 'approved', 'Telecoms', 'Douala', '699', 'Mme N')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${U(21)}', '${U(24)}', 'viewer', 'active')`);
  await as(U(24));
  check('membre actif : voit les besoins du propriétaire', (await q(`select company_missions('${U(21)}') r`))[0].r.length === 8);
  check('membre actif : voit les propositions du propriétaire', (await q(`select company_proposals('${U(21)}') r`))[0].r.length === 4);
  check('membre : sa propre liste reste vide', (await q(`select company_missions() r`))[0].r.length === 0);
  await fails('membre : ne décide pas à la place du propriétaire', `select decide_proposal('${pA}', true)`, /Proposition introuvable/);
  await as(null, 'anon');
  await fails('anonyme : refusé', `select company_missions()`, /permission denied|Connexion requise/);

  // 5. décision : suspension, refus avec motif, acceptation
  await as(U(21));
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${U(21)}'`);
  await as(U(21));
  await fails('compte suspendu : ne décide pas', `select decide_proposal('${pB}', false)`, /suspendu/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${U(21)}'`);
  await as(U(21));
  check('refus avec motif', (await q(`select decide_proposal('${pB}', false, '  Budget trop élevé  ') r`))[0].r === 'declined');
  await db.exec('reset role');
  check('motif enregistré et notifié', (await q(`select decline_reason r from mission_proposals where id = '${pB}'`))[0].r === 'Budget trop élevé'
    && (await q(`select count(*)::int n from notifications where user_id = '${U(23)}' and title = 'Proposition non retenue' and body like '%Motif : Budget trop élevé%'`))[0].n === 1);
  await as(U(21));
  await fails('refus déjà traité', `select decide_proposal('${pB}', false)`, /déjà traitée/);
  check('acceptation (2 paramètres, compatibilité)', (await q(`select decide_proposal('${pA}', true) r`))[0].r === 'accepted');
  const after = (await q(`select company_missions() r`))[0].r.find((m) => m.id === ids.fr);
  check('apres acceptation : besoin attribué, équipe abrégée, 1 proposition active', after.status === 'assigned' && after.team === 'Jean M.' && after.proposals === 1 && after.proposals_total === 2);
  await as(U(22));
  await fails('un talent ne décide pas', `select decide_proposal('${pA}', false)`, /Proposition introuvable/);

  // 6. défis : phases à venir / ouvert / terminé, seuls concours, hackathons et appels publiés ou clôturés
  await db.exec('reset role');
  const ann = (t, kind, st, extra = '') => db.exec(`insert into contest_announcements (poster_id, title, organizer, kind, status, official_url, prize_amount, reward ${extra ? ', ' + extra.split('|')[0] : ''}) values ('${U(25)}', '${t}', 'Orga', '${kind}', '${st}', 'https://exemple.cm', 500000, '500 000 FCFA' ${extra ? ', ' + extra.split('|')[1] : ''})`);
  await ann('Defi ouvert', 'contest', 'published', `deadline|current_date + 10`);
  await ann('Defi a venir', 'hackathon', 'published', `opens_on, deadline|current_date + 5, current_date + 20`);
  await ann('Defi expire', 'contest', 'published', `deadline|current_date - 3`);
  await ann('Defi cloture', 'call', 'closed');
  await ann('Defi en attente', 'contest', 'pending');
  await ann('Bourse', 'scholarship', 'published');
  await as(U(21));
  const defis = (await q(`select defis_list() r`))[0].r;
  const ph = Object.fromEntries(defis.map((d) => [d.title, d.phase]));
  check('defis : phases correctes', ph['Defi ouvert'] === 'open' && ph['Defi a venir'] === 'upcoming' && ph['Defi expire'] === 'ended' && ph['Defi cloture'] === 'ended', JSON.stringify(ph));
  check('defis : ni en attente ni bourse', defis.length === 4 && !ph['Defi en attente'] && !ph['Bourse']);
  check('defis : ouverts d abord, terminés en dernier', defis[0].phase === 'open' && defis[defis.length - 1].phase === 'ended');
  check('defis : prix numérique et type', defis.find((d) => d.title === 'Defi a venir').prize_amount === 500000 && defis.find((d) => d.title === 'Defi a venir').kind === 'hackathon');
  await as(null, 'anon');
  await fails('defis : anonyme refusé', `select defis_list()`, /permission denied|Connexion requise/);

  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}

