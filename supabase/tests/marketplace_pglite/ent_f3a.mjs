// Scénario PGlite de 20261118050000_f3a_fiche_proposition.sql : fiche d'une proposition reçue, réservée au client du besoin.
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const C = '00000000-0000-0000-0000-0000000000c1', S = '00000000-0000-0000-0000-0000000000c2', X = '00000000-0000-0000-0000-0000000000c3';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  for (const [id, nm, role] of [[C, 'Orange Cameroun', 'company'], [S, 'Mariam Essono', 'student'], [X, 'Xavier Externe', 'company']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into missions (number, client_id, kind, description, total, title, status, budget_min, budget_max) values ('F3A1', '${C}', 'service', 'Un besoin décrit avec plus de vingt caractères', 0, 'Logo', 'published', 50000, 100000)`);
  await db.exec(`insert into mission_proposals (mission_id, author_id, amount, delay_days, message, status) select id, '${S}', 80000, 1, 'Je peux le faire en un jour', 'submitted' from missions where number = 'F3A1'`);
  const pid = (await q(`select id from mission_proposals limit 1`))[0].id;

  await as(C);
  const d = (await q(`select company_proposal_detail('${pid}') r`))[0].r;
  check('client : fiche complète (auteur, message, montant, délai)', d.author_id === S && d.message === 'Je peux le faire en un jour' && d.amount === 80000 && d.delay_days === 1 && d.status === 'submitted' && d.mission === 'Logo');
  check('client : nom de l\'auteur abrégé', d.author === 'Mariam E.', d.author);
  check('client : fiche sans coordonnées', !('email' in d) && !('phone' in d));

  await as(X);
  await fails('autre entreprise : fiche refusée', `select company_proposal_detail('${pid}')`, /Proposition introuvable/);
  await as(S);
  await fails('auteur de la proposition : fiche client refusée', `select company_proposal_detail('${pid}')`, /Proposition introuvable/);
  await as(null, 'anon');
  await fails('anonyme : exécution refusée', `select company_proposal_detail('${pid}')`, /permission denied/);
  await as(C);
  await fails('identifiant inconnu', `select company_proposal_detail('00000000-0000-0000-0000-00000000ffff')`, /Proposition introuvable/);

  // la décision réelle reste decide_proposal : la fiche reflète le nouveau statut
  check('decide_proposal : refus', (await q(`select decide_proposal('${pid}', false) r`))[0].r === 'declined');
  const d2 = (await q(`select company_proposal_detail('${pid}') r`))[0].r;
  check('fiche : statut refusé après décision', d2.status === 'declined' && d2.decided_at !== null);
  await as(X);
  await fails('autre entreprise : decide_proposal refusé', `select decide_proposal('${pid}', true)`, /Proposition introuvable/);
  console.log(`ent_f3a: ${ok} OK, ${ko} KO`);
}
