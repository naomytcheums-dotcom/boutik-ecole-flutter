// Scénario PGlite de la migration 20261116120000 (droits des abonnements : stats avancées, portfolio, équipe d'entreprise, promesses des plans).
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./droits_abonnements.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const sub = (uid, plan, status = 'active', end = "now() + interval '30 days'") =>
    db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${uid}', '${plan}', '${status}', now(), ${end})`);

  await db.exec('reset role');
  // 31 vendeur sans offre, 32 vendeur Pro, 33 vendeur échu, 34 acheteur, 35 compte de test, 36 autre vendeur Pro, 37 créatrice sans offre, 38 créatrice Pro,
  // 39 entreprise sans offre, 40 entreprise abonnée, 41 entreprise au forfait payant, 42 administrateur membre de 40, 43 collègue invité
  const roles = { 31: 'student', 32: 'student', 33: 'student', 34: 'client', 35: 'student', 36: 'student', 37: 'student', 38: 'student', 39: 'company', 40: 'company', 41: 'company', 42: 'client', 43: 'client', 44: 'admin' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','d${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte ${n}','${r}','d${n}@t.cm')`);
  }
  await db.exec(`update profiles set is_test = true where id = '${U(35)}'`);

  // --- promesses des plans
  const feats = async (code) => (await q(`select features f, sellable s from plans where code = '${code}'`))[0];
  let p = await feats('vendeur_pro');
  check('vendeur_pro : stats avancées et campagnes, plus d\'outils fantômes', p.f.includes('stats_avancees') && p.f.includes('boost_campagnes') && !p.f.includes('outils_vendeur_pro') && p.s === true);
  p = await feats('entreprise');
  check('entreprise : campagnes et équipe, plus de stats avancées', p.f.includes('boost_campagnes') && p.f.includes('gestion_equipe') && !p.f.includes('stats_avancees'));
  p = await feats('createur_pro');
  check('createur_pro : portfolio enrichi seul, non vendable tant que le propriétaire ne l\'ouvre pas', p.f.length === 1 && p.f[0] === 'portfolio_enrichi' && p.s === false);
  p = await feats('admin_communaute');
  check('admin_communaute : aucun droit, non vendable', p.f.length === 0 && p.s === false);
  check('aucun plan ne promet un droit sans code', (await q(`select count(*)::int n from plans where features && array['visiteurs_profil', 'outils_vendeur_pro', 'gestion_communaute']`))[0].n === 0);

  // --- droits internes non exposés
  await as(U(31));
  await fails('feature_granted : non appelable par un compte', `select feature_granted('${U(31)}', 'stats_avancees')`, /permission denied/);
  await fails('company_team_allowed : non appelable par un compte', `select company_team_allowed('${U(40)}')`, /permission denied/);
  await as(null, 'anon');
  await fails('seller_advanced_stats : refusé aux visiteurs', `select seller_advanced_stats(30)`, /permission denied/);
  await fails('company_team_access : refusé aux visiteurs', `select company_team_access(null)`, /permission denied/);

  // --- stats_avancees
  await db.exec('reset role');
  const L1 = '00000000-0000-0000-0000-0000000000f1', L2 = '00000000-0000-0000-0000-0000000000f2', L3 = '00000000-0000-0000-0000-0000000000f3';
  await db.exec(`insert into listings (id, seller_id, title, department, price, status) values
    ('${L1}', '${U(32)}', 'Lampe', 'Genie', 5000, 'approved'), ('${L2}', '${U(32)}', 'Sac', 'Genie', 2000, 'approved'), ('${L3}', '${U(36)}', 'Autre vendeur', 'Genie', 1000, 'approved')`);
  await db.exec(`insert into listing_views (listing_id, day, views) values ('${L1}', current_date, 40), ('${L1}', current_date - 10, 10), ('${L1}', current_date - 60, 100), ('${L2}', current_date - 2, 5), ('${L3}', current_date, 999)`);
  await db.exec(`insert into favorites (user_id, listing_id) values ('${U(34)}', '${L1}'), ('${U(35)}', '${L1}')`);
  await db.exec(`insert into favorites (user_id, listing_id, created_at) values ('${U(31)}', '${L1}', now() - interval '60 days')`);
  const ordA = (await q(`insert into orders (number, buyer_id, subtotal, method, paid) values ('#D-1', '${U(34)}', 15000, 'cash', true) returning id`))[0].id;
  const ordB = (await q(`insert into orders (number, buyer_id, subtotal, method, paid) values ('#D-2', '${U(34)}', 5000, 'cash', true) returning id`))[0].id;
  const ordC = (await q(`insert into orders (number, buyer_id, subtotal, method, paid, cancelled_at) values ('#D-3', '${U(34)}', 5000, 'cash', true, now()) returning id`))[0].id;
  await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${ordA}', '${L1}', 'Lampe', 5000, 2), ('${ordA}', '${L2}', 'Sac', 2000, 2), ('${ordB}', '${L1}', 'Lampe', 5000, 1), ('${ordC}', '${L1}', 'Lampe', 5000, 1)`);
  await sub(U(32), 'vendeur_pro');
  await sub(U(33), 'vendeur_pro', 'expired', "now() - interval '2 days'");
  await sub(U(36), 'vendeur_pro');

  await as(U(31));
  await fails('stats avancées : refusées sans le droit', `select seller_advanced_stats(30)`, /Réservé au forfait Vendeur professionnel/);
  await as(U(33));
  await fails('stats avancées : refusées après échéance', `select seller_advanced_stats(30)`, /Réservé au forfait/);
  await as(U(34));
  await fails('stats avancées : un acheteur sans offre est refusé', `select seller_advanced_stats(90)`, /Réservé au forfait/);
  await as(U(32));
  await fails('stats avancées : période limitée à 30 ou 90 jours', `select seller_advanced_stats(7)`, /30 ou 90 jours/);
  let s = (await q(`select seller_advanced_stats(30) r`))[0].r;
  const l1 = s.products.find((x) => x.id === L1), l2 = s.products.find((x) => x.id === L2);
  check('stats avancées : seulement ses produits', s.products.length === 2 && !s.products.some((x) => x.id === L3));
  check('stats avancées : vues sur 30 jours (hors vues plus anciennes)', l1.views === 50 && l2.views === 5);
  check('stats avancées : favoris de la période', l1.favorites === 2 && l2.favorites === 0);
  check('stats avancées : ventes payées non annulées', l1.units === 3 && l1.orders === 2 && l1.revenue === 15000 && l2.units === 2 && l2.revenue === 4000);
  check('stats avancées : conversion = commandes / vues', Number(l1.conversion) === 4 && Number(l2.conversion) === 20);
  check('stats avancées : classées par chiffre d\'affaires', s.products[0].id === L1);
  check('stats avancées : série quotidienne sur la période', s.series.length === 30 && s.series.reduce((a, d) => a + d.views, 0) === 55);
  s = (await q(`select seller_advanced_stats(90) r`))[0].r;
  check('stats avancées : 90 jours incluent les vues plus anciennes', s.products.find((x) => x.id === L1).views === 150 && s.series.length === 90);
  await as(U(36));
  s = (await q(`select seller_advanced_stats(30) r`))[0].r;
  check('stats avancées : un autre vendeur ne voit que les siennes', s.products.length === 1 && s.products[0].id === L3 && s.products[0].views === 999);
  await as(U(35));
  check('stats avancées : un compte de test garde l\'accès', (await q(`select seller_advanced_stats(30) r`))[0].r.products.length === 0);
  await db.exec('reset role');
  await db.exec(`update subscriptions set status = 'cancel_at_period_end' where user_id = '${U(32)}'`);
  await as(U(32));
  check('stats avancées : annulation en fin de période, droit conservé jusqu\'à l\'échéance', (await q(`select seller_advanced_stats(30) r`))[0].r.products.length === 2);

  // --- portfolio_enrichi
  await db.exec('reset role');
  await db.exec(`insert into portfolio_items (owner_id, kind, title) select '${U(37)}', 'realisation', 'Travail ' || g from generate_series(1, 100) g`);
  await db.exec(`insert into portfolio_items (owner_id, kind, title) select '${U(38)}', 'realisation', 'Travail ' || g from generate_series(1, 100) g`);
  await sub(U(38), 'createur_pro');
  const add = (t) => `select portfolio_save(null, 'realisation', '${t}', '', '', '', '', null, false)`;
  await as(U(37));
  await fails('portfolio : 100 éléments au plus sans le droit', add('Un de trop'), /Limite de 100 éléments atteinte/);
  check('portfolio : une modification reste possible à la limite', (await q(`select portfolio_save((select id from portfolio_items where owner_id = '${U(37)}' limit 1), 'realisation', 'Renommé', '', '', '', '', null, false) id`)).length === 1);
  await db.exec('reset role');
  await db.exec(`update plans set price_xaf = 4000, sellable = true where code = 'createur_pro'`);
  await as(U(37));
  await fails('portfolio : le message indique l\'offre qui lève la limite', add('Encore'), /300 avec l'offre Créateur professionnel/);
  await as(U(38));
  check('portfolio : le titulaire du droit dépasse 100', (await q(add('Numéro 101') + ' id')).length === 1);
  await db.exec('reset role');
  await db.exec(`insert into portfolio_items (owner_id, kind, title) select '${U(38)}', 'realisation', 'Bis ' || g from generate_series(1, 199) g`);
  await as(U(38));
  await fails('portfolio : 300 éléments au plus avec le droit', add('Numéro 301'), /Limite de 300 éléments atteinte/);
  await db.exec('reset role');
  await db.exec(`update subscriptions set current_period_end = now() - interval '1 day' where user_id = '${U(38)}'`);
  await as(U(38));
  await fails('portfolio : droit échu, retour à 100 (rien n\'est supprimé)', add('Après échéance'), /Limite de 100 éléments atteinte/);
  check('portfolio : les éléments existants restent', (await q(`select count(*)::int n from portfolio_items where owner_id = '${U(38)}'`))[0].n === 300);
  await as(null, 'anon');
  await fails('portfolio_save : refusé aux visiteurs', add('x'), /permission denied/);

  // --- gestion_equipe
  await db.exec('reset role');
  for (const n of [39, 40, 41]) {
    await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name) values ('${U(n)}', 'Entreprise ${n}', 'approved', 'Telecoms', 'Douala', '699', 'Mme N')`);
  }
  await sub(U(40), 'entreprise');
  await db.exec(`insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at) values ('${U(41)}', 'pro', 'active', now(), now() + interval '30 days')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${U(40)}', '${U(42)}', 'admin', 'active')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${U(39)}', '${U(42)}', 'admin', 'active')`);
  await as(U(39));
  check('équipe : sans offre, l\'accès à l\'invitation est indiqué fermé', (await q(`select company_team_access() r`))[0].r === false);
  await fails('équipe : invitation refusée sans le droit', `select company_invite('d43@t.cm', 'viewer')`, /fait partie de l'offre Organisation/);
  await as(U(40));
  check('équipe : abonné Entreprise, accès ouvert', (await q(`select company_team_access() r`))[0].r === true);
  check('équipe : abonné Entreprise, invitation acceptée', (await q(`select company_invite('d43@t.cm', 'viewer') r`))[0].r === 'invited');
  await as(U(42));
  check('équipe : un administrateur invite au nom d\'une entreprise abonnée', (await q(`select company_invite('d43@t.cm', 'finance', '${U(40)}') r`))[0].r === 'invited');
  check('équipe : le droit s\'apprécie sur l\'entreprise, pas sur l\'administrateur', (await q(`select company_team_access('${U(40)}') r`))[0].r === true && (await q(`select company_team_access('${U(39)}') r`))[0].r === false);
  await fails('équipe : un administrateur ne contourne pas l\'entreprise sans droit', `select company_invite('d43@t.cm', 'viewer', '${U(39)}')`, /fait partie de l'offre Organisation/);
  await as(U(41));
  check('équipe : un forfait d\'entreprise payant ouvre l\'invitation', (await q(`select company_invite('d43@t.cm', 'viewer') r`))[0].r === 'invited');
  await db.exec('reset role');
  await db.exec(`update subscriptions set current_period_end = now() - interval '1 day' where user_id = '${U(40)}'`);
  await as(U(40));
  await fails('équipe : abonnement échu, plus de nouvelle invitation', `select company_invite('d43@t.cm', 'viewer')`, /fait partie de l'offre Organisation/);
  await db.exec('reset role');
  check('équipe : les membres existants restent', (await q(`select count(*)::int n from company_members where owner_id = '${U(40)}'`))[0].n >= 2);
  await db.exec('reset role');
  await db.exec(`update profiles set is_test = true where id = '${U(39)}'`);
  await as(U(39));
  check('équipe : un compte de test garde l\'accès', (await q(`select company_invite('d43@t.cm', 'viewer') r`))[0].r === 'invited');

  // --- rejeu de la migration : idempotente, et les abonnés dont l'offre perd un droit sont prévenus
  await db.exec('reset role');
  await db.exec(`update plans set features = '{stats_avancees,boost_campagnes,gestion_equipe}' where code = 'entreprise'`);
  await sub(U(41), 'entreprise');
  const before = (await q(`select count(*)::int n from notifications where user_id = '${U(41)}' and kind = 'subscription'`))[0].n;
  const sql = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations', '20261116120000_droits_abonnements.sql'), 'utf8');
  await db.exec(sql);
  check('migration rejouée : droit retiré à nouveau', !(await feats('entreprise')).f.includes('stats_avancees'));
  const note = await q(`select body from notifications where user_id = '${U(41)}' and kind = 'subscription' order by created_at desc limit 1`);
  check('migration : l\'abonné qui perd un droit est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${U(41)}' and kind = 'subscription'`))[0].n === before + 1 && /statistiques avancées/.test(note[0].body));
  await db.exec(sql);
  check('migration : second rejeu sans nouvelle notification', (await q(`select count(*)::int n from notifications where user_id = '${U(41)}' and kind = 'subscription'`))[0].n === before + 1);

  console.log(`\n${ok}/${ok + ko}`);
}
