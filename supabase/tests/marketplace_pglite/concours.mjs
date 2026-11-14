let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role, dept] of [[A, 'Awa Etudiante', 'student', 'Génie informatique'], [B, 'Universite Canada', 'other', ''], [C, 'Cora Etudiante', 'student', 'Génie civil'], [M, 'Mod Admin', 'admin', 'Direction']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,department) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm','${dept}')`);
  }
  const ann = (title, kind, extra = {}) => {
    const e = { organizer: 'Universite de Montreal', country: 'Canada', place: 'online', domain: 'scholarship', deadline: "'2099-12-31'", free: 'true', url: 'https://bourse.exemple.ca/apply', reward: 'Bourse complete', ...extra };
    return `select ann_save(jsonb_build_object('title','${title}','organizer','${e.organizer}','organizer_kind','university','country','${e.country}','place_kind','${e.place}','domain','${e.domain}','kind','${kind}',
      'description','Description complete du programme pour les etudiants','why','Financer les etudes de talents africains','conditions', jsonb_build_array('Etre etudiant','Avoir moins de 30 ans'),
      'documents', jsonb_build_array('CV','Lettre de motivation'),'steps', jsonb_build_array('Creer un compte','Deposer le dossier'),'criteria', jsonb_build_array('Excellence academique','Projet'),
      'deadline', ${e.deadline}, 'reward','${e.reward}','eligible_level','Master','free', ${e.free}, 'official_url','${e.url}')) id`;
  };
  // --- publication
  await as(A);
  await fails('publication : reservee aux organisations', ann('Bourse test', 'scholarship'), /Réservé/);
  await as(B);
  await fails('publication : lien officiel obligatoire', ann('Bourse Canada', 'scholarship', { url: 'pas-un-lien' }), /lien officiel/);
  await fails('publication : date limite dans le futur', ann('Bourse Canada', 'scholarship', { deadline: "'2020-01-01'" }), /date limite/);
  const c1 = (await q(ann('Bourse Canada Excellence', 'scholarship')))[0].id;
  const c2 = (await q(ann('Hackathon Afrique Tech', 'hackathon', { country: 'Afrique', domain: 'tech', place: 'onsite', free: 'false', reward: '500 000 FCFA', deadline: "to_char(current_date + 2, 'YYYY-MM-DD')" })))[0].id;
  const c3 = (await q(ann('Concours Agriculture Durable', 'contest', { country: 'Cameroun', domain: 'agriculture', reward: 'Materiel agricole' })))[0].id;
  await as(A);
  check('validation : non publiees, invisibles des etudiants', (await q(`select anns_list() r`))[0].r.length === 0);
  await as(M);
  check('validation : l equipe voit les annonces a valider', (await q(`select ann_my_posted() r`))[0].r.length === 3);
  await fails('validation : motif de refus obligatoire', `select ann_decide('${c3}', false)`, /motif/);
  await q(`select ann_decide('${c1}', true, true)`);
  await q(`select ann_decide('${c2}', true)`);
  await q(`select ann_decide('${c3}', true, true)`);
  await as(B);
  check('validation : l organisateur est notifie', (await q(`select count(*)::int n from notifications where user_id='${B}' and title='Annonce publiée'`))[0].n === 3);
  // --- liste et filtres
  await as(A);
  let list = (await q(`select anns_list() r`))[0].r;
  check('liste : 3 annonces, triees par date limite', list.length === 3 && list[0].id === c2 && list.find(x => x.id === c1).verified === true && list.find(x => x.id === c2).verified === false);
  check('filtre : par pays', (await q(`select anns_list(null, 'canada') r`))[0].r.length === 1);
  check('filtre : par domaine', (await q(`select anns_list(null, null, 'agriculture') r`))[0].r.length === 1);
  check('filtre : gratuit', (await q(`select anns_list(null, null, null, 'free') r`))[0].r.length === 2);
  check('filtre : payant', (await q(`select anns_list(null, null, null, 'paid') r`))[0].r.length === 1);
  check('filtre : presentiel', (await q(`select anns_list(null, null, null, null, 'onsite') r`))[0].r.length === 1);
  check('filtre : date limite dans 7 jours', (await q(`select anns_list(null, null, null, null, null, 7) r`))[0].r.length === 1);
  check('filtre : type', (await q(`select anns_list(null, null, null, null, null, null, 'hackathon') r`))[0].r.length === 1);
  check('recherche : par mot-cle', (await q(`select anns_list('bourse') r`))[0].r.length === 1);
  // --- fiche
  const det = (await q(`select ann_detail('${c1}') r`))[0].r;
  check('fiche : conditions, documents, etapes, criteres, lien officiel, gain', det.conditions.length === 2 && det.documents[0] === 'CV' && det.steps.length === 2 && det.criteria.length === 2 && det.official_url.startsWith('https://') && det.reward === 'Bourse complete' && det.why.startsWith('Financer'));
  // --- enregistrer et rappel
  check('enregistrer : ajoute', (await q(`select ann_save_toggle('${c2}') r`))[0].r === true);
  check('enregistres : liste filtree', (await q(`select anns_list(null,null,null,null,null,null,null,true) r`))[0].r.length === 1);
  await q(`select ann_remind('${c2}', true)`);
  await q(`select anns_list()`);
  check('rappel : la lecture de la liste ne cree aucune notification', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='contest_reminder'`))[0].n === 0);
  await db.exec('reset role'); await q(`select send_due_reminders()`); await as(A);
  check('rappel : envoye quand la date limite approche (3 jours)', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='contest_reminder'`))[0].n === 1);
  await db.exec('reset role'); await q(`select send_due_reminders()`); await as(A);
  check('rappel : une seule fois', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='contest_reminder'`))[0].n === 1);
  // --- ils ont gagné
  await fails('victoire : preuve obligatoire', `select ann_win_submit('Hackathon Orange', '1er prix', 2026, 'pas-un-lien')`, /preuve/);
  const w = (await q(`select ann_win_submit('Hackathon Orange Digital', '1er prix', 2026, 'https://orange.exemple.cm/gagnants') id`))[0].id;
  await as(null, 'anon');
  check('victoire : invisible avant validation', (await q(`select ann_wins_list() r`))[0].r.length === 0);
  await as(A);
  await fails('victoire : validation reservee a l equipe', `select ann_win_decide('${w}', true)`, /Réservé/);
  await as(M);
  check('victoire : l equipe voit les declarations a valider', (await q(`select ann_wins_list(10, true) r`))[0].r.length === 1);
  await q(`select ann_win_decide('${w}', true)`);
  await as(null, 'anon');
  const wl = (await q(`select ann_wins_list() r`))[0].r;
  check('Ils ont gagne : victoire publiee avec filiere et preuve', wl.length === 1 && wl[0].department === 'Génie informatique' && wl[0].prize === '1er prix' && wl[0].proof_url.startsWith('https://'));
  await as(B);
  await q(`select ann_close('${c1}')`);
  await as(A);
  check('annonce close : retiree de la liste', !(await q(`select anns_list() r`))[0].r.some(x => x.id === c1));
  console.log(`\n${ok}/${ok + ko}`);
}
