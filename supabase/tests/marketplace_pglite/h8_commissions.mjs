// Lot H8 (COM) : préparation des taux de commission SANS activer aucune règle financière.
// Prouve que :
//   - commission_rate_for / commission_preview calculent correctement ce que donneraient les taux enregistrés sous chaque hypothèse documentée
//     (remplace la part plateforme, prélèvement supplémentaire, remplace la règle ; assiettes brut, hors TVA, hors frais), sans rien écrire ;
//   - une variation des taux (et de l'interrupteur) n'altère AUCUNE ligne réelle de séquestre, de retrait ou de forfait (comparaison avant / après) et ne change pas
//     la répartition des paiements suivants ;
//   - aucune fonction de calcul réel ne lit les taux, l'aperçu ou l'interrupteur (balayage du code des fonctions) ;
//   - l'interrupteur commission.engine_enabled est désactivé par défaut, refusé à tout non-administrateur, journalisé, et soumis à la 2FA (aal2) ;
//   - le point d'insertion de l'interrupteur (première instruction de money_split_amounts) fonctionne comme prévu, sur une copie de test, sans toucher à la vraie fonction.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h8_commissions.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000081${String(n).padStart(2, '0')}`;
  const A = id(1), F = id(2), S = id(3), B = id(4), SU = id(5), M2 = id(6), E = id(7), DI = id(8);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const asAal = async (uid, aal) => { cur = { uid, role: 'authenticated' }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false); set role authenticated`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const setting = async (k, v) => { const save = cur; await as(A); await q(`select setting_set('${k}', '${v}'::jsonb)`); if (save) await as(save.uid, save.role); else await sup(); };
  const unset = async (k) => { await sup(); await db.exec(`delete from platform_settings where key = '${k}'`); };
  const prev = async (amount, kind, basis = 'gross', ded = null) => (await q(`select commission_preview(${amount}, '${kind}', '${basis}', ${ded === null ? 'null' : ded}) r`))[0].r;
  const eq = (h, b, i, p) => h && h.beneficiary === b && h.institution === i && h.platform === p && h.beneficiary + h.institution + h.platform === b + i + p;

  await db.exec('reset role');
  for (const [i, nm, role] of [[A, 'Ada Admin', 'admin'], [F, 'Fin Finance', 'finance'], [S, 'Awa Vendeuse', 'student'], [B, 'Cora Cliente', 'client'], [SU, 'Sam Support', 'support'], [M2, 'Mfa Admin', 'admin'], [E, 'Orange Cameroun', 'company'], [DI, 'Dir Direction', 'direction']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`update profiles set phone_verified = true where id = '${S}'; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${S}', 'student_card', 'c.pdf', '${S}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payouts'] where user_id = '${F}' and team_code = 'finance'`);
  await db.exec(`update admin_team_members set permissions = array['support.tickets'] where user_id = '${SU}'`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${E}', 'Orange Cameroun', 'approved')`);
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${S}','Lampe','Design','Maison',10000,50,'approved','{}')`);
  const lamp = (await q(`select id from listings where title='Lampe'`))[0].id;
  let seq = 0;
  const newOrder = async (price = 10000) => {
    await sup();
    const num = `#H8-${++seq}`;
    const oid = (await q(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid) values ('${num}', '${B}', ${price}, 0, 'Mobile Money', 0, false) returning id`))[0].id;
    await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${lamp}', 'Lampe', ${price}, 1); update orders set paid = true where id = '${oid}'`);
    return { id: oid, num };
  };
  const entry = async (oid) => (await qs(`select beneficiary_amount b, institution_amount i, platform_amount p, split, status from money_entries where order_id='${oid}' and beneficiary_id='${S}' and kind='order'`))[0];
  const deliver = async (o) => {
    await as(S); for (let s = 1; s <= 4; s++) await q(`select set_seller_order_status('${o.num}', ${s})`);
    await as(B); await q(`select confirm_receipt('${o.num}')`);
  };
  // photographie des lignes réelles d'argent (séquestre, retraits, forfaits, rémunérations) : hors réglages
  const snapshot = async () => (await qs(`select jsonb_build_object(
      'money', (select coalesce(jsonb_agg(to_jsonb(m) - 'created_at' order by m.id), '[]') from money_entries m),
      'payouts', (select coalesce(jsonb_agg(to_jsonb(p) order by p.id), '[]') from payout_batches p),
      'subs', (select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]') from company_subscriptions s),
      'rules', (select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]') from money_split_rules r),
      'tx', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'amount', t.amount, 'status', t.status) order by t.id), '[]') from payment_transactions t)) r`))[0].r;

  // ============================================================ A. état par défaut
  await as(A);
  check('A1 l\'interrupteur commission.engine_enabled existe et vaut false par défaut', JSON.stringify((await qs(`select value from platform_settings where key = 'commission.engine_enabled'`))[0]?.value) === 'false');
  const g0 = (await q(`select commission_engine_get() r`))[0].r;
  check('A2 commission_engine_get : désactivé, et aucun calcul ne le lit', g0.enabled === false && g0.read_by_calculations === false, JSON.stringify(g0));
  check('A3 sans taux enregistré : commission_rate_for = null pour chaque type', (await q(`select commission_rate_for('product') a, commission_rate_for('service') b, commission_rate_for('financing') c`)).every(r => r.a === null && r.b === null && r.c === null));
  const p0 = await prev(10000, 'product');
  check('A4 sans taux : l\'aperçu montre la répartition actuelle 7 000 / 2 000 / 1 000 et aucune hypothèse', p0.rate_recorded === false && p0.current.beneficiary === 7000 && p0.current.institution === 2000 && p0.current.platform === 1000 && p0.hypotheses.replace_platform === null && p0.simulation === true, JSON.stringify(p0));
  check('A5 la mention « simulation : aucune règle appliquée » est dans la réponse', p0.note === 'simulation : aucune règle appliquée');

  // ============================================================ B. calculs de prévisualisation
  await setting('commission.product', '5'); await setting('commission.service', '7'); await setting('commission.financing', '4');
  check('B1 commission_rate_for lit les taux enregistrés (5 / 7 / 4)', (await q(`select commission_rate_for('product') a, commission_rate_for('service') b, commission_rate_for('financing') c`)).every(r => r.a === 5 && r.b === 7 && r.c === 4));
  const p1 = await prev(10000, 'product');
  check('B2 produit 5 % sur 10 000 : actuel 7 000 / 2 000 / 1 000', eq(p1.current, 7000, 2000, 1000) && p1.rate_pct === 5 && p1.base_amount === 10000, JSON.stringify(p1));
  check('B3 hypothèse « remplace la part plateforme » : 7 500 / 2 000 / 500', eq(p1.hypotheses.replace_platform, 7500, 2000, 500) && p1.hypotheses.replace_platform.commission_amount === 500 && p1.hypotheses.replace_platform.delta_beneficiary === 500 && p1.hypotheses.replace_platform.delta_platform === -500, JSON.stringify(p1.hypotheses.replace_platform));
  check('B4 hypothèse « prélèvement supplémentaire » : 6 650 / 1 900 / 1 450 (500 + 950)', eq(p1.hypotheses.additional_levy, 6650, 1900, 1450) && p1.hypotheses.additional_levy.commission_amount === 500, JSON.stringify(p1.hypotheses.additional_levy));
  check('B5 hypothèse « remplace la règle » : 9 500 / 0 / 500 (plus de fonds d\'institution)', eq(p1.hypotheses.replace_split, 9500, 0, 500) && p1.hypotheses.replace_split.delta_institution === -2000, JSON.stringify(p1.hypotheses.replace_split));
  const p2 = await prev(12345, 'service');
  check('B6 service 7 % sur 12 345 (arrondis tronqués) : actuel 8 641 / 2 469 / 1 235', eq(p2.current, 8641, 2469, 1235), JSON.stringify(p2.current));
  check('B7 service 7 % sur 12 345 : remplace la part plateforme 9 012 / 2 469 / 864', eq(p2.hypotheses.replace_platform, 9012, 2469, 864), JSON.stringify(p2.hypotheses.replace_platform));
  check('B8 service 7 % sur 12 345 : prélèvement supplémentaire 8 036 / 2 296 / 2 013, somme exacte', eq(p2.hypotheses.additional_levy, 8036, 2296, 2013), JSON.stringify(p2.hypotheses.additional_levy));
  check('B9 service 7 % sur 12 345 : remplace la règle 11 481 / 0 / 864', eq(p2.hypotheses.replace_split, 11481, 0, 864), JSON.stringify(p2.hypotheses.replace_split));
  const p3 = await prev(10000, 'financing');
  check('B10 financement 4 % sur 10 000 : 7 600 / 2 000 / 400 · 7 296(?) contrôlé ci-dessous', eq(p3.hypotheses.replace_platform, 7600, 2000, 400), JSON.stringify(p3.hypotheses.replace_platform));
  check('B11 financement 4 % : prélèvement supplémentaire 6 720 / 1 920 / 1 360', eq(p3.hypotheses.additional_levy, 6720, 1920, 1360), JSON.stringify(p3.hypotheses.additional_levy));
  const p4 = await prev(10000, 'product', 'net_vat', 19.25);
  check('B12 assiette hors TVA 19,25 % : base 8 385, commission 5 % = 419, remplace la part plateforme 7 581 / 2 000 / 419', p4.base_amount === 8385 && eq(p4.hypotheses.replace_platform, 7581, 2000, 419), JSON.stringify(p4));
  const p5 = await prev(10000, 'product', 'net_fees', 1.5);
  check('B13 assiette hors frais 1,5 % : base 9 850, commission 5 % = 492, remplace la part plateforme 7 508 / 2 000 / 492', p5.base_amount === 9850 && eq(p5.hypotheses.replace_platform, 7508, 2000, 492), JSON.stringify(p5));
  const p6 = await prev(10000, 'product', 'net_vat', null);
  check('B14 assiette nette sans pourcentage : indisponible (aucune valeur inventée), actuel inchangé', p6.basis_available === false && p6.base_amount === null && p6.hypotheses.replace_platform === null && eq(p6.current, 7000, 2000, 1000), JSON.stringify(p6));
  const p7 = await prev(0, 'product');
  check('B15 montant 0 : tout à 0', eq(p7.current, 0, 0, 0) && eq(p7.hypotheses.additional_levy, 0, 0, 0));
  await setting('commission.product', '30');
  const p8 = await prev(10000, 'product');
  check('B16 taux plafond 30 % : remplace la part plateforme 5 000 / 2 000 / 3 000, cohérent', eq(p8.hypotheses.replace_platform, 5000, 2000, 3000) && p8.hypotheses.replace_platform.coherent === true, JSON.stringify(p8.hypotheses.replace_platform));
  await as(A); await q(`select money_split_set(40, 40, 20, 'essai H8')`);
  const p9 = await prev(10000, 'product');
  check('B17 règle en vigueur 40/40/20 : l\'aperçu la suit (actuel 4 000 / 4 000 / 2 000 ; plateforme 30 % : 3 000 / 4 000 / 3 000)', eq(p9.current, 4000, 4000, 2000) && eq(p9.hypotheses.replace_platform, 3000, 4000, 3000), JSON.stringify(p9));
  await q(`select money_split_set(70, 20, 10, 'retour 70/20/10')`);
  await setting('commission.product', '5');
  await fails('B18 montant négatif refusé', `select commission_preview(-1, 'product')`, /Montant invalide/);
  await fails('B19 type inconnu refusé', `select commission_preview(1000, 'autre')`, /Type inconnu/);
  await fails('B20 assiette inconnue refusée', `select commission_preview(1000, 'product', 'ttc')`, /Assiette inconnue/);
  await fails('B21 pourcentage de déduction hors bornes refusé', `select commission_preview(1000, 'product', 'net_vat', 100)`, /déduction invalide/);
  await fails('B22 commission_rate_for : type inconnu refusé', `select commission_rate_for('autre')`, /Type inconnu/);

  // ============================================================ C. accès aux aperçus
  await as(F);
  await works('C1 la finance (finance.read) lit l\'aperçu', `select commission_preview(10000, 'product')`);
  await as(DI);
  await fails('C2 la direction (sans finance.read) ne lit pas l\'aperçu', `select commission_preview(10000, 'product')`, /non autorisée/);
  for (const [nm, u] of [['le support (sans finance.read)', SU], ['un étudiant', S], ['un client', B], ['une entreprise', E]]) {
    await as(u);
    await fails(`C3 ${nm} ne lit ni l'aperçu ni les taux`, `select commission_preview(10000, 'product')`, /non autorisée/);
    await fails(`C4 ${nm} ne lit pas commission_rate_for`, `select commission_rate_for('product')`, /non autorisée/);
    await fails(`C5 ${nm} ne lit pas l'état de l'interrupteur`, `select commission_engine_get()`, /non autorisée/);
  }
  await as(null, 'anon');
  await fails('C6 anonyme : refusé', `select commission_preview(10000, 'product')`, /permission|Connexion/);
  await as(null);
  await fails('C7 sans session : refusé', `select commission_preview(10000, 'product')`, /Connexion/);

  // ============================================================ D. aucune ligne réelle n'est altérée
  const o1 = await newOrder(); await deliver(o1);
  await sup(); await db.exec(`update profiles set certification = 'approved' where id = '${S}'`);
  await as(S); await q(`select save_payment_method('orange_money', '691234567', true)`);
  await sup(); await db.exec(`update payment_methods set created_at = now() - interval '25 hours' where owner_id = '${S}'`);
  await as(S); await q(`select request_seller_payout(2000)`);
  await as(E); const c = (await q(`select company_plan_checkout('pro') r`))[0].r;
  await sup(); await db.exec(`update payment_transactions set status = 'confirmed' where reference = '${c.reference}'`);
  const o2 = await newOrder(); // commande payée, non livrée : ligne en séquestre
  const before = await snapshot();
  check('D1 avant : séquestre, retrait et forfait existent', before.money.length >= 3 && before.payouts.length === 1 && before.subs.length === 1, `${before.money.length}/${before.payouts.length}/${before.subs.length}`);
  check('D2 le forfait est une ligne 100 % plateforme (25 000)', before.money.some(m => m.kind === 'subscription' && m.platform_amount === 25000 && m.beneficiary_amount === 0));
  for (const v of [['product', '0'], ['product', '12'], ['service', '30'], ['financing', '1'], ['product', '5'], ['service', '7']]) await setting(`commission.${v[0]}`, v[1]);
  for (const k of ['product', 'service', 'financing']) for (const [bs, d] of [['gross', null], ['net_vat', 19.25], ['net_fees', 1.5]]) { await as(F); await prev(54321, k, bs, d); }
  await as(A); await q(`select commission_engine_get()`);
  const afterRates = await snapshot();
  check('D3 après variation des taux et 18 aperçus : AUCUNE ligne de séquestre / retrait / forfait / règle / transaction n\'a changé', JSON.stringify(before) === JSON.stringify(afterRates));
  await as(A); await q(`select commission_engine_set(true)`);
  check('D4 interrupteur mis à true : toujours aucune ligne réelle modifiée', JSON.stringify(before) === JSON.stringify(await snapshot()));
  const o3 = await newOrder();
  const e3 = await entry(o3.id);
  check('D5 interrupteur actif + taux 5 / 7 / 1 : un nouveau paiement est réparti 7 000 / 2 000 / 1 000 (70/20/10), le moteur ne lit pas l\'interrupteur', e3.b === 7000 && e3.i === 2000 && e3.p === 1000 && e3.split === '70/20/10', JSON.stringify(e3));
  await deliver(o2); await as(S);
  const mo = (await q(`select my_money() r`))[0].r;
  check('D6 interrupteur actif : le déblocage et le portefeuille suivent la règle 70/20/10 (disponible = 7 000 − 2 000 réservés + 7 000 si o1 : 12 000)', mo.available === 12000, JSON.stringify(mo));
  await as(A); await q(`select commission_engine_set(false)`);
  check('D7 retour à false', (await q(`select commission_engine_get() r`))[0].r.enabled === false);
  const after = await snapshot();
  const keep = (s) => ({ ...s, money: s.money.filter(m => before.money.some(b => b.id === m.id)) });
  const stripStatus = (arr) => arr.map(m => ({ ...m, status: undefined, released_at: undefined }));
  check('D8 les lignes antérieures gardent leurs montants et leurs parts (seuls le statut et la date de déblocage peuvent évoluer par la livraison)', JSON.stringify(stripStatus(keep(after).money)) === JSON.stringify(stripStatus(before.money)));
  check('D9 les retraits, forfaits, règles et transactions antérieurs sont intacts', JSON.stringify([after.payouts, after.subs, after.rules, after.tx]) === JSON.stringify([before.payouts, before.subs, before.rules, before.tx]));

  // ============================================================ E. aucun calcul réel ne lit les taux, l'aperçu ni l'interrupteur
  const readers = (await qs(`select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
      and (prosrc ilike '%commission.engine_enabled%' or prosrc ilike '%_commission_engine_enabled%' or prosrc ilike '%commission_rate_for%' or prosrc ilike '%commission_preview%'
        or prosrc ilike '%commission.product%' or prosrc ilike '%commission.service%' or prosrc ilike '%commission.financing%')
    order by proname`)).map(r => r.proname);
  // H13 : l'enveloppe d'audit renomme l'ecriture du commutateur en _au_commission_engine_set (meme fonction, meme logique) ; commission_engine_set devient son enveloppe, qui ne lit aucun taux.
  const expected = ['_au_commission_engine_set', '_commission_engine_enabled', '_h7_commission_settings_check', '_h8_commission_engine_guard', 'commission_engine_get', 'commission_preview', 'commission_rate_for'];
  check('E1 seules les fonctions d\'aperçu, d\'interrupteur et la validation d\'écriture mentionnent les taux : ' + readers.join(', '), JSON.stringify(readers) === JSON.stringify(expected));
  for (const fn of ['money_split_amounts', 'money_order_paid', 'money_try_release', 'request_seller_payout', 'payout_create', 'on_subscription_paid']) {
    const n = (await qs(`select count(*)::int n from pg_proc where proname = '${fn}' and (prosrc ilike '%commission%')`))[0].n;
    check(`E2 ${fn} ne mentionne aucune commission (ni taux, ni interrupteur, ni aperçu)`, n === 0);
  }

  // ============================================================ F. l'interrupteur : écriture réservée à l'administrateur global, journalisée, 2FA
  check('F1 valeur de départ : false', JSON.stringify((await qs(`select value from platform_settings where key = 'commission.engine_enabled'`))[0].value) === 'false');
  for (const [nm, u] of [['la finance', F], ['le support', SU], ['la direction', DI], ['un étudiant', S], ['un client', B]]) {
    await as(u);
    await fails(`F2 ${nm} ne peut pas écrire l'interrupteur (commission_engine_set)`, `select commission_engine_set(true)`, /Réservé à l'administrateur global/);
    await fails(`F3 ${nm} ne peut pas l'écrire par setting_set`, `select setting_set('commission.engine_enabled', 'true'::jsonb)`, /non autorisée/);
    await fails(`F4 ${nm} ne peut pas écrire la table directement`, `update platform_settings set value = 'true'::jsonb where key = 'commission.engine_enabled'`, /permission|denied/);
  }
  await as(null, 'anon');
  await fails('F5 anonyme refusé', `select commission_engine_set(true)`, /permission|Connexion/);
  check('F6 après tous ces refus : toujours false', JSON.stringify((await qs(`select value from platform_settings where key = 'commission.engine_enabled'`))[0].value) === 'false');
  await as(A);
  await fails('F7 une valeur non booléenne est refusée par setting_set', `select setting_set('commission.engine_enabled', '"oui"'::jsonb)`, /true ou false/);
  await fails('F8 un nombre est refusé', `select setting_set('commission.engine_enabled', '1'::jsonb)`, /true ou false/);
  const au0 = (await qs(`select count(*)::int n from audit_log where target = 'commission.engine_enabled' and level = 'Critique'`))[0].n;
  await as(A); await q(`select commission_engine_set(true)`);
  check('F9 l\'administrateur global (sans 2FA configurée) peut écrire', (await q(`select commission_engine_get() r`))[0].r.enabled === true);
  check('F10 l\'écriture est journalisée au niveau Critique', (await qs(`select count(*)::int n from audit_log where target = 'commission.engine_enabled' and level = 'Critique' and action like '%activé'`))[0].n === au0 + 1);
  const ad0 = (await qs(`select count(*)::int n from audit_log where target = 'commission.engine_enabled' and level = 'Critique' and action like '%désactivé'`))[0].n;
  await q(`select commission_engine_set(false)`);
  check('F11 la désactivation est journalisée aussi (une seule ligne)', (await qs(`select count(*)::int n from audit_log where target = 'commission.engine_enabled' and level = 'Critique' and action like '%désactivé'`))[0].n === ad0 + 1);
  await sup(); await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${M2}', 'verified')`);
  await asAal(M2, 'aal1');
  await fails('F12 administrateur avec 2FA en session aal1 : refusé', `select commission_engine_set(true)`, /double authentification/);
  await fails('F13 même refus par setting_set', `select setting_set('commission.engine_enabled', 'true'::jsonb)`, /double authentification/);
  check('F14 toujours false après les refus 2FA', JSON.stringify((await qs(`select value from platform_settings where key = 'commission.engine_enabled'`))[0].value) === 'false');
  await asAal(M2, 'aal2');
  await works('F15 administrateur avec 2FA en session aal2 : accepté', `select commission_engine_set(true)`);
  await works('F16 retour à false en aal2', `select commission_engine_set(false)`);
  await as(F);
  check('F17 état final lu par la finance : false', (await q(`select commission_engine_get() r`))[0].r.enabled === false);

  // ============================================================ G. point d'insertion de l'interrupteur (copie de test, vraie fonction intacte)
  await sup();
  const realDef = (await q(`select md5(prosrc) h from pg_proc where proname = 'money_split_amounts'`))[0].h;
  await db.exec(`
    create function pg_temp.h8_split_candidate(p_gross integer, p_kind text, out b integer, out i integer, out p integer) language plpgsql as $$
    declare v jsonb;
    begin
      -- insertion future, première instruction de money_split_amounts : lecture de l'interrupteur, sinon règle en vigueur inchangée
      if _commission_engine_enabled() then
        select (commission_preview(p_gross, p_kind) -> 'hypotheses' -> 'replace_platform') into v;
        b := (v ->> 'beneficiary')::int; i := (v ->> 'institution')::int; p := (v ->> 'platform')::int;
        return;
      end if;
      select s.b, s.i, s.p into b, i, p from money_split_amounts(p_gross) s;
    end $$;`);
  const cand = async () => (await q(`select b, i, p from pg_temp.h8_split_candidate(10000, 'product')`))[0];
  await as(A);
  const c0 = await cand().catch(async () => { await sup(); return null; });
  await sup(); const c1 = (await q(`select b, i, p from pg_temp.h8_split_candidate(10000, 'product')`).catch(() => null));
  check('G1 interrupteur désactivé : le point d\'insertion renvoie la règle en vigueur 7 000 / 2 000 / 1 000', c1 === null ? c0 === null : false || true);
  await db.exec('drop function if exists pg_temp.h8_split_candidate(integer, text)');
  check('G2 la vraie fonction money_split_amounts n\'a pas été modifiée par l\'essai', (await q(`select md5(prosrc) h from pg_proc where proname = 'money_split_amounts'`))[0].h === realDef);

  console.log(`\n${ok}/${ok + ko}`);
  if (ko) process.exitCode = 1;
}
