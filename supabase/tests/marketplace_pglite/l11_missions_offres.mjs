// Scénario PGlite du lot L11 (migration 20261115210000) : missions, offres premium, campagnes, invitations.
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./l11_missions_offres.mjs
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
  const roles = { 11: 'client', 12: 'student', 13: 'dept', 14: 'admin', 15: 'company', 16: 'finance', 17: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','u${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Profil Complet ${n}','${r}','u${n}@t.cm')`);
  }
  // Lot L4 : proposer un devis est une prestation de service, réservée aux étudiants éligibles (vérifié + téléphone vérifié) : les deux talents de ce scénario le sont.
  await db.exec(`update profiles set phone = '69011' || right(id::text, 4), phone_verified = true, certification = 'approved' where id in ('${U(12)}', '${U(17)}')`);
  // Rattachement du compte département (lot H2/K3) : un compte non rattaché n'est ni notifié ni autorisé à voir les besoins départementaux.
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000c4a0', 'IUT Test', 'verified') on conflict (id) do nothing; insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000c4a1', '00000000-0000-0000-0000-00000000c4a0', 'Génie logiciel', 'verified') on conflict (id) do nothing; insert into department_accounts (user_id, department_id) values ('${U(13)}', '00000000-0000-0000-0000-00000000c4a1') on conflict (user_id) do update set department_id = excluded.department_id; update profiles set department_id = '00000000-0000-0000-0000-00000000c4a1' where id = '${U(11)}'`);

  // 1. publication d'un besoin : le département et l'administration sont prévenus, plafond de 5 par jour
  await as(U(11));
  const need = (t) => `select save_mission(null, '${t}', 'Un besoin décrit avec plus de vingt caractères', 50000, 100000, '2027-01-31', true, 'mission') id`;
  const m1 = (await q(need('Mission sur mesure 1')))[0].id;
  await db.exec('reset role');
  const n1 = await q(`select user_id from notifications where title = 'Nouveau besoin à qualifier'`);
  check('publication : dept et admin notifiés', n1.length === 2 && n1.some((r) => r.user_id === U(13)) && n1.some((r) => r.user_id === U(14)), JSON.stringify(n1));
  await as(U(11));
  for (let i = 2; i <= 5; i++) await q(need(`Mission sur mesure ${i}`));
  await fails('plafond : la sixième publication du jour est refusée', need('Mission sur mesure 6'), /5 besoins publiés par jour/);
  check('brouillon : non limité', (await q(`select save_mission(null, 'Brouillon', '', null, null, '', false, 'besoin') id`)).length === 1);

  // 2. propositions : trois au plus par talent et par besoin
  await as(U(12));
  const p1 = (await q(`select propose_on_mission('${m1}', 80000, 10, 'Une équipe') id`))[0].id;
  await fails('proposition : doublon en attente refusé', `select propose_on_mission('${m1}', 70000, 10, '')`, /déjà proposé/);
  for (const k of [1, 2]) {
    await as(U(11));
    const cur = (await q(`select id from mission_proposals where mission_id = '${m1}' and author_id = '${U(12)}'`))[0].id;
    await q(`select decide_proposal('${cur}', false)`);
    await as(U(12));
    if (k === 1) check('proposition : redépôt après refus (2e)', (await q(`select propose_on_mission('${m1}', 75000, 10, '') id`)).length === 1);
    else check('proposition : redépôt après refus (3e)', (await q(`select propose_on_mission('${m1}', 70000, 10, '') id`)).length === 1);
  }
  await as(U(11));
  const cur3 = (await q(`select id from mission_proposals where mission_id = '${m1}' and author_id = '${U(12)}'`))[0].id;
  await q(`select decide_proposal('${cur3}', false)`);
  await as(U(12));
  await fails('proposition : une quatrième est refusée', `select propose_on_mission('${m1}', 60000, 10, '')`, /trois propositions/);

  // 3. mes besoins avec l'auteur des propositions, puis annulation du besoin
  await as(U(17));
  await q(`select propose_on_mission('${m1}', 90000, 12, 'Autre équipe')`);
  await as(U(11));
  const needs = (await q(`select my_needs() r`))[0].r;
  const mm = needs.find((x) => x.id === m1);
  check('my_needs : propositions avec nom abrégé', mm && mm.proposals.some((p) => p.author_name === 'Profil C.' && p.status === 'submitted'), JSON.stringify(mm));
  check('mission_cancel : besoin retiré', (await q(`select mission_cancel('${m1}') r`))[0].r === 'cancelled');
  await db.exec('reset role');
  check('mission_cancel : proposition en attente déclinée', (await q(`select status from mission_proposals where mission_id = '${m1}' and author_id = '${U(17)}'`))[0].status === 'declined');
  check('mission_cancel : le proposant est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${U(17)}' and title = 'Besoin retiré'`))[0].n === 1);
  await as(U(12));
  await fails('mission annulée : plus de proposition', `select propose_on_mission('${m1}', 60000, 10, '')`, /ne reçoit plus/);
  await as(U(17));
  await fails('mission_cancel : réservé à l\'auteur', `select mission_cancel('${m1}')`, /introuvable/);

  // 4. offres : audience, offres sans contenu, paiement échoué, expiration, annulation ciblée
  await as(U(14));
  await q(`select plan_set('vendeur_pro', 'Vendeur professionnel', 5000, true)`);
  await q(`select plan_set('entreprise', 'Entreprise', 9000, true)`);
  await q(`select plan_set('admin_communaute', 'Administrateur de communauté', 3000, true)`);
  await as(U(11));
  await fails('offre : un client ne souscrit pas une offre réservée aux vendeurs', `select subscription_start('vendeur_pro')`, /ne concerne pas votre type de compte/);
  await fails('offre : un client ne souscrit pas une offre entreprise', `select subscription_start('entreprise')`, /ne concerne pas votre type de compte/);
  await as(U(12));
  await fails('offre : sans fonction livrée, non vendue', `select subscription_start('admin_communaute')`, /pas encore disponible/);
  await fails('offre : plan gratuit sans prix refusé', `select subscription_start('gratuit')`, /pas encore disponible/);
  const pay1 = (await q(`select subscription_start('vendeur_pro') p`))[0].p;
  await fails('offre : double souscription en attente refusée', `select subscription_start('vendeur_pro')`, /déjà ce plan/);
  await as(U(14));
  await q(`select payment_set_status('${pay1}', 'cancelled', null)`);
  await as(U(12));
  const pay2 = (await q(`select subscription_start('vendeur_pro') p`))[0].p;
  check('offre : recommencer après un paiement annulé', pay2 !== pay1);
  await as(U(14));
  await q(`select payment_set_status('${pay2}', 'confirmed', null)`);
  await as(U(12));
  check('droit boost_campagnes après confirmation', (await q(`select my_entitlements() r`))[0].r.features.includes('boost_campagnes'));
  await q(`select subscription_cancel('vendeur_pro')`);
  await fails('annulation ciblée : seconde annulation refusée', `select subscription_cancel('vendeur_pro')`, /Aucun abonnement actif/);
  await db.exec('reset role');
  await db.exec(`update subscriptions set current_period_end = now() - interval '1 day' where user_id = '${U(12)}' and status = 'cancel_at_period_end'`);
  check('expire_subscriptions : un abonnement échu expire', (await q(`select expire_subscriptions() n`))[0].n === 1 && (await q(`select status from subscriptions where user_id = '${U(12)}' and payment_id = '${pay2}'`))[0].status === 'expired');
  await as(U(12));
  await fails('expire_subscriptions : non exécutable par un compte', `select expire_subscriptions()`, /permission denied/);

  // 5. campagnes : droit exigé côté serveur, erreurs lisibles, annulation
  await as(U(11));
  await fails('campagne : droit requis pour un client', `select ad_campaign_save(null, 'Ma campagne', 'x', null, null, 5000, null, null, null)`, /Vendeur professionnel et Organisation/);
  await db.exec('reset role');
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${U(17)}', 'vendeur_pro', 'active', now(), now() + interval '30 days')`);
  await db.exec(`insert into posts (id, author_id, media_path, media_kind, status) values ('00000000-0000-0000-0000-0000000000b1', '${U(17)}', '${U(17)}/a.jpg', 'image', 'published')`);
  await as(U(17));
  await fails('campagne : titre trop court (message lisible)', `select ad_campaign_save(null, 'ab', '', '00000000-0000-0000-0000-0000000000b1', null, 5000, null, null, null)`, /Titre : 3 à 80/);
  await fails('campagne : budget trop bas (message lisible)', `select ad_campaign_save(null, 'Ma campagne', '', '00000000-0000-0000-0000-0000000000b1', null, 500, null, null, null)`, /1 000 FCFA au minimum/);
  const c1 = (await q(`select ad_campaign_save(null, 'Ma campagne', '', '00000000-0000-0000-0000-0000000000b1', null, 5000, null, null, null) id`))[0].id;
  const pay = (await q(`select ad_campaign_submit('${c1}') p`))[0].p;
  check('campagne : paiement du budget en attente', (await q(`select status from ad_campaigns where id = '${c1}'`))[0].status === 'awaiting_payment');
  await q(`select ad_campaign_cancel('${c1}')`);
  check('campagne en attente de paiement : annulée', (await q(`select count(*)::int n from ad_campaigns where id = '${c1}'`))[0].n === 0);
  await db.exec('reset role');
  check('campagne annulée : paiement annulé', (await q(`select status from payment_transactions where id = '${pay}'`))[0].status === 'cancelled');

  // 6. invitations d'équipe : réponse identique que le compte existe ou non
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name) values ('${U(15)}', 'Entreprise L11', 'approved', 'Telecoms', 'Douala', '699', 'Mme N')`);
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${U(15)}', 'entreprise', 'active', now(), now() + interval '30 days')`);
  await as(U(15));
  const a = (await q(`select company_invite('inconnu@t.cm', 'viewer') r`))[0].r;
  const b = (await q(`select company_invite('u11@t.cm', 'viewer') r`))[0].r;
  check('invitation : même réponse, compte inconnu ou existant', a === b && a === 'invited');
  await db.exec('reset role');
  check('invitation : seul le compte existant reçoit l\'invitation', (await q(`select count(*)::int n from company_members where owner_id = '${U(15)}'`))[0].n === 1);

  console.log(`\n${ok} OK, ${ko} ECHEC`);
}
