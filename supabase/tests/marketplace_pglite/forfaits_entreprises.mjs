let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', O = '00000000-0000-0000-0000-0000000000e2', M = '00000000-0000-0000-0000-0000000000ee', C = '00000000-0000-0000-0000-0000000000e3';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange Cameroun', 'company'], [O, 'ONG Verte', 'other'], [M, 'Mod Admin', 'admin'], [C, 'Client Simple', 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  const need = (t) => `select save_mission(null, '${t}', 'Je cherche une solution de gestion de stock pour mes boutiques', 50000, 100000, '2027-01-31', true) id`;
  const offer = (t) => `select opp_save('Orange Cameroun', 'stage', 'Stage', '${t}', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', null, array['Flutter'], 'Description complete de la mission de stage pour etudiant', array['Coder'], 'Etudiant en informatique', '', '', array['Attestation'], '', true, 'Operateur telecom', false) id`;
  // --- avant verification
  await as(E);
  await fails('besoin : entreprise non verifiee refusee', need('Gestion de stock'), /vérifiée/);
  await fails('offre : entreprise non verifiee refusee', offer('Stagiaire developpeur'), /vérifiée/);
  // --- clients et organisations non commerciales : pas concernes
  await as(C);
  check('client simple : peut publier un besoin sans verification', (await q(need('Besoin client'))).length === 1);
  // --- verification
  await as(E);
  await q(`select company_save(jsonb_build_object('company_name','Orange Cameroun','sector','Telecoms','city','Douala','phone','699','contact_name','Mme N'))`);
  await q(`select company_doc_add('registration', 'RCCM.pdf', '${E}/company/rccm.pdf', 'application/pdf', 1000)`);
  await q(`select company_submit()`);
  await as(M);
  await q(`select company_decide('${E}', true)`);
  // --- forfait Decouverte : 1 besoin, 1 offre
  await as(E);
  const st = (await q(`select company_plan_status() r`))[0].r;
  check('forfait par defaut : Decouverte, quotas 1/1/0', st.plan.code === 'free' && st.plan.max_needs === 1 && st.plan.max_offers === 1 && st.plan.max_contests === 0 && st.used_needs === 0);
  check('besoin : premier accepte', (await q(need('Gestion de stock'))).length === 1);
  await fails('besoin : deuxieme refuse (forfait Decouverte atteint)', need('Deuxieme besoin'), /forfait « Découverte » est atteint/);
  check('offre : premiere acceptee', (await q(offer('Stagiaire developpeur'))).length === 1);
  await fails('offre : deuxieme refusee', offer('Stagiaire design'), /forfait/);
  await fails('concours : aucun avec Decouverte', `select ann_save(jsonb_build_object('title','Hackathon Orange','organizer','Orange','organizer_kind','company','country','Cameroun','place_kind','online','domain','tech','kind','hackathon','description','Description complete du programme pour les etudiants','why','Innover','deadline','2099-12-31','free',true,'official_url','https://orange.cm/hack'))`, /forfait/);
  // --- demande de forfait
  await fails('demande : forfait gratuit non demandable', `select company_subscription_request('free')`, /introuvable/);
  check('demande : forfait Entreprise', (await q(`select company_subscription_request('pro') r`))[0].r === 'requested');
  await as(M);
  check('notification : l administrateur est prevenu', (await q(`select count(*)::int n from notifications where user_id='${M}' and kind='company_plan'`))[0].n === 1);
  const pend = (await q(`select company_subscriptions_pending() r`))[0].r;
  check('file des demandes : entreprise, forfait et prix', pend.length === 1 && pend[0].company_name === 'Orange Cameroun' && pend[0].plan_code === 'pro' && pend[0].price_fcfa === 25000);
  await as(E);
  await fails('activation : reservee a l administrateur', `select company_subscription_activate('${E}', 'pro')`, /Réservé/);
  await as(M);
  await q(`select company_subscription_activate('${E}', 'pro')`);
  await as(E);
  const st2 = (await q(`select company_plan_status() r`))[0].r;
  check('forfait Entreprise actif avec date de fin', st2.plan.code === 'pro' && st2.ends_at !== null && st2.requested === null && st2.used_needs === 1 && st2.used_offers === 1);
  check('besoin : le deuxieme passe maintenant', (await q(need('Deuxieme besoin'))).length === 1);
  check('concours : 2 autorises avec le forfait Entreprise', (await q(`select ann_save(jsonb_build_object('title','Hackathon Orange','organizer','Orange','organizer_kind','company','country','Cameroun','place_kind','online','domain','tech','kind','hackathon','description','Description complete du programme pour les etudiants','why','Innover','deadline','2099-12-31','free',true,'official_url','https://orange.cm/hack')) id`)).length === 1);
  // --- expiration
  await db.exec('reset role');
  await db.exec(`update company_subscriptions set ends_at = now() - interval '1 day' where owner_id = '${E}' and status = 'active'`);
  await as(E);
  check('forfait expire : retour a Decouverte', (await q(`select company_plan_status() r`))[0].r.plan.code === 'free');
  await fails('forfait expire : nouvelle publication refusee', offer('Stagiaire reseau'), /forfait/);
  // --- tableau de bord
  const d = (await q(`select company_dashboard() r`))[0].r;
  check('accueil : statut, forfait et chiffres', d.status === 'approved' && d.plan_name === 'Découverte' && d.needs_open === 2 && d.offers_active === 1 && d.contests_active === 1 && d.proposals_new === 0);
  // --- organisation non commerciale : pas de porte
  await as(O);
  check('ONG / universite (autre role) : aucune porte', (await q(offer('Benevolat environnement'))).length === 1);
  // --- gestion des forfaits par l'administrateur
  await as(E);
  await fails('forfait : creation reservee a l administrateur', `select company_plan_save(jsonb_build_object('code','gold','name','Or','price_fcfa',100000))`, /Réservé/);
  await as(M);
  check('forfait : l administrateur modifie le prix', (await q(`select company_plan_save(jsonb_build_object('code','pro','name','Entreprise','price_fcfa',30000,'period_days',30,'max_needs',10,'max_offers',10,'max_contests',2,'position',2)) r`))[0].r === 'pro');
  check('forfaits : liste avec le nouveau prix', (await q(`select company_plans_list() r`))[0].r.find(x => x.code === 'pro').price_fcfa === 30000);
  console.log(`\n${ok}/${ok + ko}`);
}
