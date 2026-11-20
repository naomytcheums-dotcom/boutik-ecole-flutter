// Lot H7 (facturation) : les règles enregistrées par l'écran admin 135 (commission.*) et le moteur d'argent.
// Prouve que :
//   - sans règle enregistrée, tout est inchangé (retrait minimum 1 000 FCFA, répartition 70/20/10) ;
//   - « commission.payout_threshold » (Seuil de paiement vendeur) est RÉELLEMENT le minimum d'un retrait (request_seller_payout, my_payouts), borné par payouts.max,
//     et que la suppression du réglage rétablit l'ancien comportement ;
//   - les taux « commission.product / service / financing » sont enregistrés mais NE modifient PAS la répartition 70/20/10 (décision du propriétaire en attente) ;
//   - le serveur refuse une valeur de commission.* invalide (non numérique, décimale, hors bornes), même par écriture directe ;
//   - la finance (payout_create) garde la main sur un versement inférieur au seuil.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h7_facturation.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000071${String(n).padStart(2, '0')}`;
  const A = id(1), F = id(2), S = id(3), B = id(4), C = id(5);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const setting = async (k, v) => { const save = cur; await as(A); await q(`select setting_set('${k}', '${v}'::jsonb)`); if (save) await as(save.uid, save.role); else await sup(); };
  const unset = async (k) => { await sup(); await db.exec(`delete from platform_settings where key = '${k}'`); };

  await db.exec('reset role');
  for (const [i, nm, role] of [[A, 'Ada Admin', 'admin'], [F, 'Fin Finance', 'finance'], [S, 'Awa Vendeuse', 'student'], [B, 'Cora Cliente', 'client'], [C, 'Dan Client', 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`update profiles set phone_verified = true where id = '${S}'; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${S}', 'student_card', 'c.pdf', '${S}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payouts'] where user_id = '${F}' and team_code = 'finance'`);
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${S}','Lampe','Design','Maison',10000,50,'approved','{}'), ('${S}','Armoire','Design','Maison',40000,50,'approved','{}')`);
  const L = async (t) => (await q(`select id from listings where title='${t}'`))[0].id;
  const [lamp, armoire] = [await L('Lampe'), await L('Armoire')];
  let seq = 0;
  const newOrder = async (buyer, lid, title, price) => {
    await sup();
    const num = `#H7-${++seq}`;
    const oid = (await q(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid) values ('${num}', '${buyer}', ${price}, 0, 'Mobile Money', 0, false) returning id`))[0].id;
    await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${lid}', '${title}', ${price}, 1); update orders set paid = true where id = '${oid}'`);
    return { id: oid, num };
  };
  const entry = async (oid) => (await qs(`select * from money_entries where order_id='${oid}' and beneficiary_id='${S}' and kind='order'`))[0];
  const deliver = async (o, buyer) => {
    await as(S); for (let s = 1; s <= 4; s++) await q(`select set_seller_order_status('${o.num}', ${s})`);
    await as(buyer); await q(`select confirm_receipt('${o.num}')`);
  };
  const wallet = async () => { await as(S); return (await q(`select my_money() r`))[0].r; };
  const minOf = async () => { await as(S); return (await q(`select my_payouts() r`))[0].r.min; };

  // ============================================================ A. sans règle enregistrée : comportement inchangé
  const o1 = await newOrder(B, lamp, 'Lampe', 10000);
  const e1 = await entry(o1.id);
  check('A1 sans taux : répartition 70/20/10 sur 10 000 (7 000 / 2 000 / 1 000)', e1.beneficiary_amount === 7000 && e1.institution_amount === 2000 && e1.platform_amount === 1000 && e1.split === '70/20/10', JSON.stringify(e1));
  check('A2 sans seuil : retrait minimum = 1 000 (my_payouts.min)', (await minOf()) === 1000);
  await deliver(o1, B);
  const o2 = await newOrder(C, armoire, 'Armoire', 40000);
  await deliver(o2, C);
  check('A3 le vendeur a 35 000 FCFA disponibles', (await wallet()).available === 35000, JSON.stringify(await wallet()));
  await sup(); await db.exec(`update profiles set certification = 'approved' where id = '${S}'`);
  await as(S); await q(`select save_payment_method('orange_money', '691234567', true)`);
  await sup(); await db.exec(`update payment_methods set created_at = now() - interval '25 hours' where owner_id = '${S}'`);
  await as(S);
  await fails('A4 sans seuil : 500 FCFA refusé (minimum 1000)', `select request_seller_payout(500)`, /Retrait minimum : 1000 FCFA/);

  // ============================================================ B. les taux 135 sont enregistrés mais ne changent pas la répartition
  await setting('commission.product', '6'); await setting('commission.service', '8'); await setting('commission.financing', '3');
  const o3 = await newOrder(B, lamp, 'Lampe', 10000);
  const e3 = await entry(o3.id);
  check('B1 taux 6 / 8 / 3 enregistrés : la répartition de la commande reste 70/20/10', e3.beneficiary_amount === 7000 && e3.institution_amount === 2000 && e3.platform_amount === 1000 && e3.split === '70/20/10', JSON.stringify(e3));
  await as(S);
  check('B2 les taux enregistrés ne modifient pas le retrait minimum', (await minOf()) === 1000);
  await as(B);
  const sg = (await q(`select money_split_get() r`))[0].r;
  check('B3 money_split_get : règle courante 70/20/10', sg.current.beneficiary_pct === 70 && sg.current.institution_pct === 20 && sg.current.platform_pct === 10, JSON.stringify(sg.current));
  await as(A); await q(`select money_split_set(60, 25, 15, 'essai H7')`);
  const o4 = await newOrder(B, lamp, 'Lampe', 10000);
  const e4 = await entry(o4.id);
  check('B4 la règle money_split_rules reste la seule source : 60/25/15 appliquée telle quelle malgré les taux 135', e4.beneficiary_amount === 6000 && e4.institution_amount === 2500 && e4.platform_amount === 1500 && e4.split === '60/25/15', JSON.stringify(e4));
  await as(A); await q(`select money_split_set(70, 20, 10, 'retour 70/20/10')`);
  const o5 = await newOrder(C, lamp, 'Lampe', 10000);
  check('B5 retour à 70/20/10 : nouvelle commande répartie 7 000 / 2 000 / 1 000', (await entry(o5.id)).beneficiary_amount === 7000);
  check('B6 les anciennes lignes de séquestre ne sont pas réécrites', (await entry(o3.id)).beneficiary_amount === 7000 && (await entry(o4.id)).beneficiary_amount === 6000);

  // ============================================================ C. le seuil de paiement vendeur est le retrait minimum
  await setting('commission.payout_threshold', '20000');
  check('C1 seuil 20 000 : my_payouts.min = 20 000', (await minOf()) === 20000);
  await as(S);
  await fails('C2 seuil 20 000 : une demande de 19 999 FCFA est refusée', `select request_seller_payout(19999)`, /Retrait minimum : 20000 FCFA/);
  await fails('C3 seuil 20 000 : 1 000 FCFA (ancien minimum) est refusé', `select request_seller_payout(1000)`, /Retrait minimum : 20000 FCFA/);
  const p1 = (await works('C4 seuil 20 000 : une demande de 20 000 FCFA est acceptée', `select request_seller_payout(20000) id`))?.[0]?.id;
  check('C5 la demande réserve exactement 20 000 FCFA', (await wallet()).requested === 20000);
  await as(S); await q(`select payout_cancel_request('${p1}')`);

  await setting('commission.payout_threshold', '500');
  check('C6 seuil abaissé à 500 : my_payouts.min = 500', (await minOf()) === 500);
  const p2 = (await works('C7 seuil 500 : une demande de 600 FCFA est acceptée (l\'ancien minimum 1 000 est remplacé)', `select request_seller_payout(600) id`))?.[0]?.id;
  await as(S); await q(`select payout_cancel_request('${p2}')`);
  await fails('C8 seuil 500 : 400 FCFA refusé', `select request_seller_payout(400)`, /Retrait minimum : 500 FCFA/);

  await setting('commission.payout_threshold', '0');
  check('C9 seuil 0 : my_payouts.min = 0 (aucun minimum, un montant nul reste invalide)', (await minOf()) === 0);
  await as(S); await fails('C10 seuil 0 : montant nul refusé', `select request_seller_payout(0)`, /Montant invalide/);

  await sup(); await db.exec(`insert into platform_settings (key, value) values ('payouts.max', '2500'::jsonb) on conflict (key) do update set value = excluded.value`);
  await setting('commission.payout_threshold', '100000');
  check('C11 seuil supérieur au plafond : le minimum est borné par payouts.max (2 500), jamais de retrait impossible', (await minOf()) === 2500);
  await unset('payouts.max');
  check('C12 sans payouts.max, le plafond par défaut (500 000) borne le seuil : 100 000 reste 100 000', (await minOf()) === 100000);

  await setting('commission.payout_threshold', '20000');
  await sup(); await db.exec(`insert into platform_settings (key, value) values ('payouts.min', '3000'::jsonb) on conflict (key) do update set value = excluded.value`);
  check('C13 le seuil enregistré par l\'écran 135 prime sur l\'ancien réglage payouts.min (3 000)', (await minOf()) === 20000);
  await unset('commission.payout_threshold');
  check('C14 seuil supprimé : l\'ancien réglage payouts.min (3 000) s\'applique de nouveau', (await minOf()) === 3000);
  await unset('payouts.min');
  check('C15 plus aucun réglage : retour au minimum par défaut 1 000', (await minOf()) === 1000);
  await sup(); await db.exec(`insert into platform_settings (key, value) values ('commission.payout_threshold', '"abc"'::jsonb)`).catch(() => {});
  check('C16 une valeur non numérique n\'est pas enregistrée : aucune ligne, minimum inchangé', (await minOf()) === 1000 && (await qs(`select count(*)::int n from platform_settings where key = 'commission.payout_threshold'`))[0].n === 0);

  // ============================================================ D. validation serveur des règles commission.*
  await as(A);
  await fails('D1 taux > 30 % refusé', `select setting_set('commission.product', '45'::jsonb)`, /de 0 à 30/);
  await fails('D2 taux négatif refusé', `select setting_set('commission.service', '-1'::jsonb)`, /de 0 à 30/);
  await fails('D3 taux décimal refusé', `select setting_set('commission.financing', '2.5'::jsonb)`, /nombre entier/);
  await fails('D4 taux texte refusé', `select setting_set('commission.product', '"cinq"'::jsonb)`, /nombre entier/);
  await fails('D5 seuil négatif refusé', `select setting_set('commission.payout_threshold', '-5'::jsonb)`, /Seuil de paiement vendeur/);
  await fails('D6 seuil démesuré refusé', `select setting_set('commission.payout_threshold', '200000000'::jsonb)`, /Seuil de paiement vendeur/);
  await fails('D7 le null JSON est refusé', `select setting_set('commission.product', 'null'::jsonb)`, /nombre entier/);
  await works('D8 taux 0 % accepté', `select setting_set('commission.product', '0'::jsonb)`);
  await works('D9 taux 30 % accepté (borne haute)', `select setting_set('commission.service', '30'::jsonb)`);
  await works('D10 une autre clé (commission.updated_at, texte) n\'est pas concernée', `select setting_set('commission.updated_at', '"2026-11-20T10:00:00Z"'::jsonb)`);
  await sup();
  try { await db.exec(`update platform_settings set value = '"x"'::jsonb where key = 'commission.product'`); check('D11 écriture directe invalide refusée par le déclencheur', false, 'aurait du echouer'); }
  catch (e) { check('D11 écriture directe invalide refusée par le déclencheur', /nombre entier/.test(e.message), e.message); }
  check('D12 la valeur valide précédente est conservée', (await q(`select value v from platform_settings where key = 'commission.product'`))[0].v === 0);
  await as(F);
  await fails('D13 la finance ne peut toujours pas écrire un taux', `select setting_set('commission.product', '5'::jsonb)`, /autoris|permission|réservé|Réservé/i);

  // ============================================================ E. la finance garde la main sur un versement inférieur au seuil
  await setting('commission.payout_threshold', '20000');
  await as(F);
  const pc = (await works('E1 seuil 20 000 : la finance peut créer un versement de 1 500 FCFA (décision du propriétaire en attente)', `select payout_create('${S}', 1500) id`))?.[0]?.id;
  await as(S);
  await fails('E2 le vendeur, lui, ne peut toujours pas demander moins que le seuil', `select request_seller_payout(1500)`, /Retrait minimum : 20000 FCFA/);
  await as(F); if (pc) await q(`select payout_set_status('${pc}', 'rejete', null, 'test H7')`);

  console.log(`\n${ok}/${ok + ko}`);
  if (ko) process.exitCode = 1;
}
