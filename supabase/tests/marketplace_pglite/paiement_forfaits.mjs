let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', N = '00000000-0000-0000-0000-0000000000e2', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange Cameroun', 'company'], [N, 'Nouvelle Entreprise', 'company'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${E}', 'Orange Cameroun', 'approved'), ('${N}', 'Nouvelle', 'draft')`);
  check('reglage : paiement Tara active', (await q(`select value::text v from platform_settings where key = 'payments.tara_enabled'`))[0].v === 'true');
  await as(N);
  await fails('paiement : entreprise non verifiee refusee', `select company_plan_checkout('pro')`, /vérifier/);
  await as(E);
  await fails('paiement : forfait gratuit impossible', `select company_plan_checkout('free')`, /introuvable/);
  await fails('paiement : forfait inconnu', `select company_plan_checkout('nope')`, /introuvable/);
  const c = (await q(`select company_plan_checkout('pro') r`))[0].r;
  check('paiement : transaction creee au prix de la base (25000)', c.amount === 25000 && c.reference.length > 3 && c.plan === 'Entreprise');
  const t = (await q(`select provider, kind, subject, status, amount from payment_transactions where reference = '${c.reference}'`))[0];
  check('transaction : Tara, abonnement, plan:pro, a payer', t.provider === 'tara' && t.kind === 'subscription' && t.subject === 'plan:pro' && t.status === 'created' && t.amount === 25000);
  check('avant confirmation : toujours Decouverte', (await q(`select company_plan_status() r`))[0].r.plan.code === 'free');
  // le client ne peut pas se confirmer lui-meme
  await fails('le client ne confirme pas son propre paiement', `update payment_transactions set status = 'confirmed' where reference = '${c.reference}'`, /permission|row-level|violates/);
  // le fournisseur confirme (webhook, service)
  await db.exec('reset role');
  await db.exec(`update payment_transactions set status = 'confirmed' where reference = '${c.reference}'`);
  await as(E);
  const st = (await q(`select company_plan_status() r`))[0].r;
  check('apres confirmation : forfait Entreprise actif automatiquement', st.plan.code === 'pro' && st.ends_at !== null);
  check('notification : forfait active', (await q(`select count(*)::int n from notifications where user_id='${E}' and title='Forfait activé'`))[0].n === 1);
  // idempotence : une seconde confirmation n'ajoute rien
  await db.exec('reset role');
  await db.exec(`update payment_transactions set status = 'confirmed', note = 'doublon' where reference = '${c.reference}'`);
  check('doublon de confirmation : un seul abonnement actif', (await q(`select count(*)::int n from company_subscriptions where owner_id = '${E}' and status = 'active'`))[0].n === 1);
  // montant insuffisant : pas d'activation
  await db.exec('reset role');
  await db.exec(`update company_subscriptions set status = 'expired' where owner_id = '${E}'`);
  await as(E);
  const c2 = (await q(`select company_plan_checkout('partner') r`))[0].r;
  await db.exec('reset role');
  await db.exec(`update payment_transactions set amount = 1000, status = 'confirmed' where reference = '${c2.reference}'`);
  await as(E);
  check('montant insuffisant : forfait non active', (await q(`select company_plan_status() r`))[0].r.plan.code === 'free');
  console.log(`\n${ok}/${ok + ko}`);
}
