let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', A = '00000000-0000-0000-0000-0000000000a1', F = '00000000-0000-0000-0000-0000000000a2', V = '00000000-0000-0000-0000-0000000000a3', X = '00000000-0000-0000-0000-0000000000a4', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange Cameroun', 'company'], [A, 'Alice Admin', 'client'], [F, 'Fabrice Finance', 'student'], [V, 'Vero Lectrice', 'client'], [X, 'Xavier Externe', 'client'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name) values ('${E}', 'Orange Cameroun', 'approved', 'Telecoms', 'Douala', '699', 'Mme N')`);
  await as(E);
  await fails('invitation : personne sans compte', `select company_invite('inconnu@t.cm', 'viewer')`, /d'abord créer son compte/);
  await fails('invitation : role inconnu', `select company_invite('Alice@t.cm', 'chef')`, /Rôle inconnu/);
  await fails('invitation : pas le proprietaire lui-meme', `select company_invite('Orange@t.cm', 'viewer')`, /propriétaire/);
  check('invitation : Alice (administratrice)', (await q(`select company_invite('Alice@t.cm', 'admin') r`))[0].r === 'invited');
  check('invitation : Fabrice (finance)', (await q(`select company_invite(' fabrice@T.cm ', 'finance') r`))[0].r === 'invited');
  check('invitation : Vero (lectrice)', (await q(`select company_invite('Vero@t.cm', 'viewer') r`))[0].r === 'invited');
  // avant acceptation : aucun acces
  await as(A);
  await fails('avant acceptation : pas d acces a l entreprise', `select company_dashboard('${E}')`, /Accès refusé/);
  check('notification d invitation recue', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='company_team'`))[0].n === 1);
  const mine = (await q(`select my_company_memberships() r`))[0].r;
  check('mes entreprises : invitation en attente visible', mine.length === 1 && mine[0].status === 'invited' && mine[0].company_name === 'Orange Cameroun' && mine[0].verified === true);
  check('acceptation : Alice', (await q(`select company_member_respond('${E}', true) r`))[0].r === 'active');
  await as(F);
  await q(`select company_member_respond('${E}', true)`);
  await as(V);
  await q(`select company_member_respond('${E}', true)`);
  await as(X);
  await fails('une personne non invitee ne peut pas accepter', `select company_member_respond('${E}', true)`, /Invitation introuvable/);
  await fails('un tiers ne voit pas l entreprise', `select company_dashboard('${E}')`, /Accès refusé/);
  await fails('un tiers ne voit pas la fiche', `select company_get('${E}')`, /Accès refusé/);
  // vue partagee
  await as(V);
  const d = (await q(`select company_dashboard('${E}') r`))[0].r;
  check('lectrice : voit l accueil de l entreprise (meme interface)', d.company_name === 'Orange Cameroun' && d.my_role === 'viewer' && d.status === 'approved' && d.members === 4);
  const g = (await q(`select company_get('${E}') r`))[0].r;
  check('lectrice : fiche visible, pieces justificatives masquees', g.company_name === 'Orange Cameroun' && g.documents.length === 0 && g.my_role === 'viewer');
  await fails('lectrice : ne modifie pas la fiche', `select company_save(jsonb_build_object('company_name','Hack'), '${E}')`, /Réservé au propriétaire/);
  await fails('lectrice : n invite personne', `select company_invite('Xavier@t.cm', 'viewer', '${E}')`, /Réservé au propriétaire/);
  await fails('lectrice : ne paie pas le forfait', `select company_plan_checkout('pro', '${E}')`, /Réservé au propriétaire/);
  const ml = (await q(`select company_members_list('${E}') r`))[0].r;
  check('lectrice : voit l equipe sans les e-mails', ml.members.length === 3 && ml.members.every(m => m.email === null) && ml.owner.name === 'Orange C.');
  // administratrice
  await as(A);
  check('administratrice : modifie la fiche', (await q(`select company_save(jsonb_build_object('company_name','Orange Cameroun','sector','Telecoms et mobile','city','Douala','phone','699','contact_name','Mme N'), '${E}') r`))[0].r === 'approved');
  await fails('administratrice : ne cree pas de fiche pour une autre entreprise', `select company_save(jsonb_build_object('company_name','X'), '${A}')`, /Réservé aux entreprises|Fiche introuvable/);
  check('administratrice : invite Xavier', (await q(`select company_invite('Xavier@t.cm', 'viewer', '${E}') r`))[0].r === 'invited');
  const ml2 = (await q(`select company_members_list('${E}') r`))[0].r;
  check('administratrice : voit les e-mails de l equipe', ml2.members.some(m => m.email === 'Fabrice@t.cm'));
  await q(`select company_member_set_role('${V}', 'finance', '${E}')`);
  check('administratrice : change un role', (await q(`select company_members_list('${E}') r`))[0].r.members.find(m => m.user_id === V).role === 'finance');
  await q(`select company_member_set_role('${V}', 'viewer', '${E}')`);
  // paiement du forfait par la finance
  await as(F);
  const c = (await q(`select company_plan_checkout('pro', '${E}') r`))[0].r;
  check('finance : peut lancer le paiement du forfait de l entreprise', c.amount === 25000);
  await db.exec('reset role');
  check('sujet de la transaction : forfait et entreprise visee', (await q(`select subject from payment_transactions where reference = '${c.reference}'`))[0].subject === `plan:pro:${E}`);
  await db.exec(`update payment_transactions set status = 'confirmed' where reference = '${c.reference}'`);
  await as(E);
  check('confirmation du paiement : forfait Entreprise actif pour l entreprise', (await q(`select company_plan_status() r`))[0].r.plan.code === 'pro');
  await as(F);
  check('la finance voit le forfait actif', (await q(`select company_plan_status('${E}') r`))[0].r.plan.code === 'pro');
  // retrait et depart
  await as(A);
  await q(`select company_member_remove('${V}', '${E}')`);
  await as(V);
  await fails('apres retrait : plus d acces', `select company_dashboard('${E}')`, /Accès refusé/);
  await as(F);
  await q(`select company_member_remove('${F}', '${E}')`);
  await fails('depart volontaire : plus d acces', `select company_dashboard('${E}')`, /Accès refusé/);
  // decline
  await as(X);
  check('invitation declinee', (await q(`select company_member_respond('${E}', false) r`))[0].r === 'declined');
  check('plus d invitation apres refus', (await q(`select my_company_memberships() r`))[0].r.length === 0);
  // limite
  await as(E);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
