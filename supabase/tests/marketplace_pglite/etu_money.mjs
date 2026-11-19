// Lot MONEY : prouve chaque correction (cas refusé ET cas autorisé) et que l'ancien flux acheteur -> paiement -> livraison -> déblocage fonctionne toujours.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./etu_money.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000000${n}`;
  const S1 = id('a1'), S2 = id('a2'), B = id('b1'), B2 = id('b2'), B3 = id('b3'), R = id('c1'), M = id('ee'), F = id('f1'), SU = id('d1'), C = id('e1'), D = id('e2');
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const nc = async (uid, title) => (await qs(`select count(*)::int n from notifications where user_id='${uid}' and title='${title}'`))[0].n;
  await db.exec('reset role');
  for (const [i, nm, role] of [[S1, 'Awa Vendeuse', 'student'], [S2, 'Boris Vendeur', 'student'], [B, 'Cora Cliente', 'client'], [B2, 'Dan Client', 'client'], [B3, 'Eve Cliente', 'client'], [R, 'Rita Parrain', 'client'],
    [M, 'Mod Admin', 'admin'], [F, 'Fin Finance', 'finance'], [SU, 'Sam Support', 'support'], [C, 'Ent Cliente', 'client'], [D, 'Dep Dept', 'dept']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  // Rattachement du compte département (lot H2/K3) : un compte non rattaché ne voit et ne reçoit aucune donnée départementale.
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000c4a0', 'IUT Test', 'verified') on conflict (id) do nothing; insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000c4a1', '00000000-0000-0000-0000-00000000c4a0', 'Génie logiciel', 'verified') on conflict (id) do nothing; insert into department_accounts (user_id, department_id) values ('${D}', '00000000-0000-0000-0000-00000000c4a1') on conflict (user_id) do update set department_id = excluded.department_id; update profiles set department_id = '00000000-0000-0000-0000-00000000c4a1' where id = '${C}'`);
  // K2 : les vendeurs (S1, S2) sont éligibles (pièce d'étudiant validée, téléphone vérifié)
  for (const s of [S1, S2]) await db.exec(`update profiles set phone_verified = true where id = '${s}'; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${s}', 'student_card', 'c.pdf', '${s}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  // Équipes internes (lot H4) : l'agent de support de ce scénario décide aussi les remboursements (droit explicite).
  // K1 : droits minimaux par défaut ; la finance et le support du scénario reçoivent explicitement les permissions dont il a besoin.
  await db.exec(`update admin_team_members set permissions = array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'] where user_id = '${SU}' and team_code = 'support';
    update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${F}' and team_code = 'finance'`);
  await sup();
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values
    ('${S1}','Lampe','Design','Maison',10000,50,'approved','{}'), ('${S2}','Table','Design','Maison',5000,50,'approved','{}'), ('${S2}','Bureau','Design','Maison',15000,50,'approved','{}')`);
  const L = async (t) => (await q(`select id from listings where title='${t}'`))[0].id;
  const [lamp, table, bureau] = [await L('Lampe'), await L('Table'), await L('Bureau')];
  let seq = 0;
  const newOrder = async (buyer, lines, o = {}) => {
    await sup();
    const num = `#M-${++seq}`;
    const sub = lines.reduce((s, [, , p, n]) => s + p * n, 0);
    const oid = (await q(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, cod, delivery_address) values ('${num}', '${buyer}', ${sub}, ${o.fee ?? 0}, '${o.cod ? 'Paiement à la livraison' : 'Mobile Money'}', 0, false, ${o.home ?? false}, ${o.cod ?? false}, ${o.city ? `'{"city":"${o.city}"}'::jsonb` : 'null'}) returning id`))[0].id;
    for (const [lid, title, price, qty] of lines) await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${lid}', '${title}', ${price}, ${qty})`);
    if (o.paid !== false && !o.cod) await db.exec(`update orders set paid = true where id = '${oid}'`);
    if (o.cod) await db.exec(`update orders set cod = true where id = '${oid}'`);
    return { id: oid, num };
  };
  const steps = async (seller, num, upto = 4) => { await as(seller); for (let s = 1; s <= upto; s++) await q(`select set_seller_order_status('${num}', ${s})`); };
  const entry = async (oid, who) => (await qs(`select * from money_entries where order_id='${oid}' and beneficiary_id='${who}' and kind='order'`))[0];
  const wallet = async (who) => { await as(who); return (await q(`select my_money() r`))[0].r; };
  const backdate = async (oid) => { await sup(); await db.exec(`update order_lines set delivered_at = now() - interval '73 hours' where order_id='${oid}'`); };
  const autoRelease = async () => { await sup(); return (await q(`select money_auto_release() n`))[0].n; };

  // ============================================================ A. SQL1-1 / S4-12 : l'ancien flux fonctionne, mais « livrée » ne libère plus seul
  const o1 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  check('A0 paiement : 7000 en sequestre', (await entry(o1.id, S1)).status === 'held' && (await entry(o1.id, S1)).beneficiary_amount === 7000);
  await as(S1);
  await fails('A1 S4-12 : 0 -> 4 directement refuse (ordre impose)', `select set_seller_order_status('${o1.num}', 4)`, /dans l'ordre/);
  await fails('A2 S4-12 : 0 -> 3 refuse', `select set_seller_order_status('${o1.num}', 3)`, /dans l'ordre/);
  await steps(S1, o1.num);
  check('A3 SQL1-1 : « livree » declaree par le vendeur ne libere PAS l argent', (await entry(o1.id, S1)).status === 'held');
  check('A4 le vendeur voit 0 disponible, 7000 en sequestre', (await wallet(S1)).available === 0 && (await wallet(S1)).held === 7000);
  check('A5 l acheteur est prevenu avec le delai de garde', (await qs(`select body from notifications where user_id='${B}' and title='Commande livrée'`))[0].body.includes('72 h'));
  await as(S2);
  await fails('A6 un tiers ne confirme pas la reception', `select confirm_receipt('${o1.num}')`, /introuvable/);
  await as(B);
  check('A7 l acheteur confirme la reception', (await q(`select confirm_receipt('${o1.num}') s`))[0].s === 'confirmed');
  check('A8 apres confirmation : 7000 disponibles', (await wallet(S1)).available === 7000);
  check('A9 notification « Argent debloque » (1)', (await nc(S1, 'Argent débloqué')) === 1);
  await as(B);
  check('A10 confirmer deux fois est sans effet', (await q(`select confirm_receipt('${o1.num}') s`))[0].s === 'already');
  await as(B);
  const oa11 = await newOrder(B, [[table, 'Table', 5000, 1]]);
  await as(B);
  await fails('A11 confirmation impossible avant la livraison', `select confirm_receipt('${oa11.num}')`, /pas encore déclaré la livraison/);

  // ============================================================ B. délai de garde (cron money_auto_release)
  const o2 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await steps(S1, o2.num);
  check('B1 cron : rien de libere avant le delai', (await autoRelease()) === 0 && (await entry(o2.id, S1)).status === 'held');
  await as(S1);
  await fails('B2 le cron n est pas appelable par un utilisateur', `select money_auto_release()`, /permission denied/);
  await backdate(o2.id);
  check('B3 cron : libere apres 72 h sans reclamation', (await autoRelease()) >= 1 && (await entry(o2.id, S1)).status === 'released');
  check('B4 le vendeur est notifie du deblocage', (await nc(S1, 'Argent débloqué')) === 2);
  await sup();
  await db.exec(`insert into platform_settings (key, value) values ('money.hold_hours', '24'::jsonb) on conflict (key) do update set value = excluded.value`);
  const o2b = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await steps(S1, o2b.num);
  await sup(); await db.exec(`update order_lines set delivered_at = now() - interval '25 hours' where order_id='${o2b.id}'`);
  check('B5 delai de garde reglable (24 h)', (await autoRelease()) >= 1 && (await entry(o2b.id, S1)).status === 'released');
  await sup(); await db.exec(`delete from platform_settings where key = 'money.hold_hours'`);

  // ============================================================ C. S10-1 : code de retrait utilisable par le vendeur
  const o3 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await steps(S1, o3.num, 3);
  await as(B);
  let code;
  try { code = (await q(`select my_pickup_code('${o3.num}') c`))[0].c; } catch (e) { await sup(); await db.exec(`update orders set pickup_code = '482915', pickup_attempts = 0 where id = '${o3.id}'`); code = '482915'; }
  check('C0 l acheteur obtient un code de retrait a 6 chiffres', /^[0-9]{6}$/.test(code));
  const wrong = code === '000000' ? '111111' : '000000';
  await as(S2);
  await fails('C1 un autre vendeur ne peut pas saisir le code', `select seller_confirm_handover('${o3.num}', '${code}')`, /introuvable/);
  await as(S1);
  check('C2 code errone : « incorrect », rien n est livre', (await q(`select seller_confirm_handover('${o3.num}', '${wrong}') r`))[0].r === 'incorrect' && (await entry(o3.id, S1)).status === 'held');
  check('C3 la tentative est comptee', (await qs(`select pickup_attempts a from orders where id='${o3.id}'`))[0].a === 1);
  check('C4 bon code : remise confirmee, argent libere tout de suite', (await q(`select seller_confirm_handover('${o3.num}', '${code}') r`))[0].r === 'delivered' && (await entry(o3.id, S1)).status === 'released');
  check('C5 les lignes sont livrees et confirmees par code', (await qs(`select fulfillment f, confirmed_via v from order_lines where order_id='${o3.id}'`))[0].v === 'code');
  await sup();
  const o3b = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await db.exec(`update orders set pickup_code = '123456' where id = '${o3b.id}'`);
  await as(S1);
  for (let k = 0; k < 5; k++) await q(`select seller_confirm_handover('${o3b.num}', '999999')`);
  await fails('C6 apres 5 essais le code est bloque', `select seller_confirm_handover('${o3b.num}', '123456')`, /Trop d'essais/);
  // staff au kiosque : preuve de remise, libere
  await sup();
  const o3c = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await db.exec(`update orders set pickup_code = '654321' where id = '${o3c.id}'`);
  await as(SU);
  check('C7 le personnel du kiosque confirme la remise : argent libere', (await q(`select confirm_pickup('${o3c.num}', '654321') r`))[0].r === 'delivered' && (await entry(o3c.id, S1)).status === 'released');

  // ============================================================ D. réclamations : S4-51 / 52 / 53 / 54
  const o4 = await newOrder(B, [[lamp, 'Lampe', 10000, 1], [table, 'Table', 5000, 1]]);
  await as(B);
  const cid = (await q(`select submit_claim('${o4.num}', 'not_received', 'Je n ai rien recu de cette commande') id`))[0].id;
  check('D1 S4-54 : les DEUX vendeurs sont rattaches a la reclamation', (await qs(`select count(*)::int n from claim_sellers where claim_id='${cid}'`))[0].n === 2);
  check('D2 S4-54 : les deux vendeurs sont notifies', (await nc(S1, 'Réclamation reçue')) === 1 && (await nc(S2, 'Réclamation reçue')) === 1);
  await as(S2);
  check('D3 S4-54 : le 2e vendeur lit la reclamation (RLS)', (await q(`select count(*)::int n from claims where id='${cid}'`))[0].n === 1);
  await fails('D4 S4-51 : une reponse d un caractere est refusee', `select answer_claim('${cid}', 'ok')`, /trop courte/);
  check('D5 le 2e vendeur peut repondre', (await q(`select answer_claim('${cid}', 'Nous verifions la livraison, merci de patienter') r`))[0].r === 'answered');
  await as(S1);
  check('D6 le 1er vendeur peut repondre aussi', (await q(`select answer_claim('${cid}', 'Colis remis au kiosque, code utilise') r`))[0].r === 'answered');
  await steps(S1, o4.num); await steps(S2, o4.num);
  await backdate(o4.id);
  check('D7 S4-51 : reclamation « repondue » : le vendeur livre, 72 h passees, l argent RESTE bloque', (await autoRelease()) === 0 && (await entry(o4.id, S1)).status === 'held' && (await entry(o4.id, S2)).status === 'held');
  await as(B);
  await fails('D8 l acheteur ne peut pas confirmer pendant la reclamation', `select confirm_receipt('${o4.num}')`, /réclamation/);
  check('D9 l acheteur peut ecrire au fil (statut repasse a open)', (await q(`select answer_claim('${cid}', 'Je maintiens ma reclamation, rien recu') r`))[0].r === 'open');
  await as(S1);
  await fails('D10 un vendeur ne decide pas', `select claim_decide('${cid}', 'release', 'x')`, /Réservé/);
  await as(B);
  await fails('D11 l acheteur ne decide pas', `select claim_decide('${cid}', 'release', 'x')`, /Réservé/);
  await as(SU);
  check('D12 S4-53 : decision « release » : les deux montants sont debloques', (await q(`select claim_decide('${cid}', 'release', 'Colis bien remis, reclamation non retenue') r`))[0].r === 'release'
    && (await entry(o4.id, S1)).status === 'released' && (await entry(o4.id, S2)).status === 'released');
  await as(S1);
  await fails('D13 S4-52 : une reclamation close n est plus modifiable (vendeur)', `select answer_claim('${cid}', 'Je reecris la decision de l equipe')`, /clôturée/);
  await as(B);
  await fails('D14 S4-52 : ni par l acheteur', `select answer_claim('${cid}', 'Un message apres la cloture')`, /clôturée/);
  await sup();
  check('D15 S4-52 : decision et reponse conservees', (await q(`select status, decision, answer from claims where id='${cid}'`))[0].decision === 'release' && (await q(`select answer from claims where id='${cid}'`))[0].answer.includes('non retenue'));
  check('D16 S4-52 : historique des echanges (>= 5 messages horodates)', (await q(`select count(*)::int n from claim_messages where claim_id='${cid}'`))[0].n >= 5);
  await as(B);
  const th = (await q(`select claim_thread('${cid}') t`))[0].t;
  check('D17 claim_thread : fil, statut close, plus de reponse possible', th.status === 'closed' && th.can_reply === false && th.messages.length >= 5 && th.as === 'buyer');
  await as(S2);
  check('D18 le vendeur voit le meme fil', (await q(`select claim_thread('${cid}') t`))[0].t.as === 'seller');
  await as(C);
  await fails('D19 un tiers ne lit pas le fil', `select claim_thread('${cid}')`, /introuvable/);

  // retrait de la réclamation par l'acheteur -> déblocage relancé
  const o5 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await as(B); const c5 = (await q(`select submit_claim('${o5.num}', 'damaged', 'Lampe abimee a la reception') id`))[0].id;
  await steps(S1, o5.num); await backdate(o5.id);
  check('D20 reclamation ouverte : meme apres 72 h rien n est libere', (await autoRelease()) === 0);
  await as(S1);
  await fails('D21 une seule reclamation en cours par commande', `select submit_claim('${o5.num}', 'refund', 'Une deuxieme reclamation')`, /Commande introuvable/);
  await as(B);
  await fails('D22 une 2e reclamation est refusee', `select submit_claim('${o5.num}', 'refund', 'Une deuxieme reclamation')`, /déjà ouverte/);
  check('D23 l acheteur retire sa reclamation : argent libere (delai ecoule)', (await q(`select claim_withdraw('${c5}') r`))[0].r === 'closed' && (await entry(o5.id, S1)).status === 'released');

  // décision « refund »
  const o6 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await as(B); const c6 = (await q(`select submit_claim('${o6.num}', 'not_received', 'Commande jamais arrivee chez moi') id`))[0].id;
  await as(SU);
  await fails('D24 remboursement : motif obligatoire', `select claim_decide('${c6}', 'refund', '')`, /motif/);
  check('D25 decision « refund » : commande annulee, sequestre rembourse', (await q(`select claim_decide('${c6}', 'refund', 'Acheteur dans son droit, remboursement') r`))[0].r === 'refund'
    && (await entry(o6.id, S1)).status === 'refunded' && (await q(`select cancelled_at is not null c from orders where id='${o6.id}'`))[0].c === true);
  await sup();
  const rf6 = (await q(`select * from order_refunds where order_id='${o6.id}'`))[0];
  check('D26 une demande de remboursement tracee est creee (approuvee, 10000 FCFA)', rf6.status === 'approved' && rf6.amount === 10000 && rf6.claim_id === c6);
  check('D27 le stock est remis', (await q(`select stock from listings where id='${lamp}'`))[0].stock >= 1);
  await as(SU);
  await fails('D28 le support n inscrit pas le versement (finance seulement)', `select order_refund_set_paid('${rf6.id}', 'MP123456')`, /Réservé à l.équipe Finance/);
  await as(F);
  await fails('D29 la finance doit donner une reference', `select order_refund_set_paid('${rf6.id}', '')`, /référence/);
  check('D30 la finance inscrit le remboursement verse', (await q(`select order_refund_set_paid('${rf6.id}', 'MP123456') r`))[0].r === 'refunded');
  check('D31 l acheteur est prevenu du remboursement verse', (await nc(B, 'Remboursement versé')) === 1);
  await as(F);
  await fails('D32 un remboursement verse ne se rejoue pas', `select order_refund_set_paid('${rf6.id}', 'MP999999')`, /introuvable/);

  // ============================================================ E. S4-48 : annulation / remboursement d'une commande payée
  const o7 = await newOrder(B, [[table, 'Table', 5000, 2]]);
  await steps(S2, o7.num);
  await as(B);
  await fails('E1 reason trop courte', `select order_refund_request('${o7.num}', 'non')`, /10 caractères/);
  const r7 = (await q(`select order_refund_request('${o7.num}', 'Je ne veux plus de cet article, erreur de commande') id`))[0].id;
  check('E2 demande creee, finance et support prevenus', (await nc(F, 'Remboursement à traiter')) >= 1 && (await nc(SU, 'Remboursement à traiter')) >= 1);
  check('E3 le vendeur est prevenu et le sequestre reste en attente', (await nc(S2, "Demande d''annulation")) === 1 && (await entry(o7.id, S2)).status === 'held');
  await fails('E4 une seule demande en cours', `select order_refund_request('${o7.num}', 'Encore une demande identique')`, /déjà en cours/);
  await as(S2);
  const mine = (await q(`select my_refunds() r`))[0].r;
  check('E5 le vendeur voit la demande (sans numero de remboursement)', mine.length === 1 && mine[0].as === 'seller' && mine[0].refund_phone === null);
  await backdate(o7.id);
  check('E6 une demande en cours bloque aussi la liberation', (await autoRelease()) === 0 && (await entry(o7.id, S2)).status === 'held');
  await as(S1);
  await fails('E7 un vendeur etranger a la commande ne decide pas', `select order_refund_decide('${r7}', 'approve', '')`, /Réservé/);
  await as(SU);
  await fails('E8 le refus exige un motif', `select order_refund_decide('${r7}', 'reject', '')`, /motif/);
  const stockBefore = (await q(`select stock from listings where id='${table}'`))[0].stock;
  check('E9 le support accepte : commande annulee, stock remis, sequestre rembourse', (await q(`select order_refund_decide('${r7}', 'approve', 'Accord') r`))[0].r === 'approve'
    && (await entry(o7.id, S2)).status === 'refunded' && (await q(`select stock from listings where id='${table}'`))[0].stock === stockBefore + 2);
  await as(F);
  check('E10 la finance voit la file des remboursements a verser', (await q(`select finance_overview() r`))[0].r.refunds_to_pay >= 1);
  const o8 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]]);
  await as(S1);
  const r8 = (await q(`select order_refund_request('${o8.num}', 'Rupture de stock, je ne peux pas honorer la commande') id`))[0].id;
  check('E11 le vendeur peut demander l annulation (acheteur prevenu)', (await nc(B, 'Annulation demandée par le vendeur')) === 1);
  await as(SU);
  check('E12 refus motive : la commande suit son cours', (await q(`select order_refund_decide('${r8}', 'reject', 'Le stock est reapprovisionne') r`))[0].r === 'reject' && (await entry(o8.id, S1)).status === 'held');
  await steps(S1, o8.num); await backdate(o8.id);
  check('E13 apres le refus, la liberation reprend', (await autoRelease()) >= 1 && (await entry(o8.id, S1)).status === 'released');
  await as(B);
  await fails('E14 apres confirmation de la reception : reclamation, pas d annulation', `select order_refund_request('${o1.num}', 'Je veux finalement annuler cette commande')`, /confirmé la réception/);
  const oc = await newOrder(B, [[table, 'Table', 5000, 1]], { cod: true });
  const ou = await newOrder(B, [[table, 'Table', 5000, 1]], { paid: false });
  await as(B);
  await fails('E15 paiement en especes : pas de remboursement par la plateforme', `select order_refund_request('${oc.num}', 'Je veux annuler cette commande payee')`, /espèces|pas payée/);
  await fails('E16 commande non payee : on l annule simplement', `select order_refund_request('${ou.num}', 'Je veux annuler cette commande')`, /pas payée/);

  // ============================================================ F. S4-124 : gel / dégel notifiés
  const o9 = await newOrder(B, [[table, 'Table', 5000, 1]]);
  const e9 = await entry(o9.id, S2);
  await as(M);
  await q(`select money_freeze('${e9.id}', 'Verification d identite en cours')`);
  check('F1 le vendeur est notifie du gel avec le motif', (await qs(`select body from notifications where user_id='${S2}' and title='Montant bloqué'`))[0].body.includes('Verification d identite'));
  await as(S2);
  let rev = (await q(`select seller_revenue() r`))[0].r;
  const h = rev.holds.find((x) => x.reason === 'frozen');
  check('F2 seller_revenue expose le blocage, son motif et le montant', h && h.frozen_reason === 'Verification d identite en cours' && h.amount === 3500 && rev.frozen >= 3500);
  await as(M); await q(`select money_unfreeze('${e9.id}')`);
  check('F3 le vendeur est notifie du degel', (await nc(S2, 'Montant débloqué du gel')) === 1);

  // ============================================================ G. S4-1 / S4-82 / S4-123 : retraits
  const w0 = await wallet(S1);
  check('G0 le vendeur a un solde disponible (> 5000)', w0.available > 5000, JSON.stringify(w0));
  await sup(); await db.exec(`update profiles set phone_verified = true, certification = 'approved' where id in ('${S1}', '${S2}')`);
  await as(S1);
  await fails('G1 sans numero Mobile Money enregistre : refuse', `select request_seller_payout(2000)`, /Enregistrez d'abord/);
  await q(`select save_payment_method('orange_money', '691234567', true)`);
  await fails('G1b delai de securite : un numero tout juste enregistre ne recoit aucun retrait', `select request_seller_payout(2000)`, /vient d'être enregistré/);
  await sup(); await db.exec(`update payment_methods set created_at = now() - interval '25 hours' where owner_id = '${S1}'`);
  await as(S1);
  await fails('G2 minimum 1000 FCFA', `select request_seller_payout(500)`, /minimum/);
  await fails('G3 au-dela du solde : refuse', `select request_seller_payout(${w0.available + 1})`, /solde disponible/);
  await fails('G4 numero non enregistre : refuse', `select request_seller_payout(2000, '677000000')`, /pas enregistré/);
  await sup(); await db.exec(`insert into platform_settings (key, value) values ('payouts.max', '2500'::jsonb) on conflict (key) do update set value = excluded.value`);
  await as(S1);
  await fails('G5 plafond par demande (reglable)', `select request_seller_payout(3000)`, /maximum/);
  await sup(); await db.exec(`delete from platform_settings where key = 'payouts.max'`);
  await as(S1);
  const p1 = (await q(`select request_seller_payout(2000) id`))[0].id;
  const w1 = await wallet(S1);
  check('G6 la demande reserve le montant (disponible -2000, demande 2000)', w1.available === w0.available - 2000 && w1.requested === 2000);
  await sup();
  const pb = (await q(`select * from payout_batches where id='${p1}'`))[0];
  check('G7 S4-82 : numero et operateur du vendeur lies a la demande', pb.phone === '691234567' && pb.provider === 'orange_money' && pb.status === 'demande' && pb.source === 'seller');
  check('G8 S4-123 : le vendeur et la finance sont notifies a la creation', (await nc(S1, 'Demande de retrait enregistrée')) === 1 && (await nc(F, 'Retrait à traiter')) === 1);
  await as(S1);
  await fails('G9 une seule demande en cours', `select request_seller_payout(1000)`, /déjà en cours/);
  await fails('G10 le vendeur ne traite pas sa demande', `select payout_set_status('${p1}', 'verse', 'REF1')`, /non autorisée/);
  await as(S2);
  await fails('G11 un autre vendeur n annule pas la demande', `select payout_cancel_request('${p1}')`, /introuvable/);
  await as(F);
  const fp = (await q(`select finance_payouts(50) r`))[0].r;
  check('G12 file finance : la demande est en tete avec numero Mobile Money', fp[0].id === p1 && fp[0].status === 'demande' && fp[0].phone === '691234567');
  check('G13 vue d ensemble : demandes comptees', (await q(`select finance_overview() r`))[0].r.payout_requests === 1);
  await fails('G14 versement sans reference de transaction : refuse', `select payout_set_status('${p1}', 'verse')`, /référence/);
  await fails('G15 statut inconnu : refuse', `select payout_set_status('${p1}', 'inconnu')`, /Statut invalide/);
  await q(`select payout_set_status('${p1}', 'verse', 'OM-778899')`);
  check('G16 versement enregistre avec reference ; vendeur notifie', (await nc(S1, 'Retrait versé')) === 1 && (await wallet(S1)).paid_out === 2000);
  await as(F);
  await fails('G17 S4-123 : un lot verse ne peut plus etre rejete (pas de double versement)', `select payout_set_status('${p1}', 'rejete', null, 'erreur')`, /Transition impossible/);
  await fails('G18 ni repasse a prevu', `select payout_set_status('${p1}', 'prevu')`, /Transition impossible/);
  await as(S1);
  const p2 = (await q(`select request_seller_payout(1500) id`))[0].id;
  await as(F);
  await fails('G19 un rejet exige un motif', `select payout_set_status('${p2}', 'rejete')`, /motif/);
  const wB = await wallet(S1);
  await as(F);
  await q(`select payout_set_status('${p2}', 'rejete', null, 'Numero Mobile Money injoignable')`);
  check('G20 rejet : montant de nouveau disponible, vendeur notifie avec le motif', (await wallet(S1)).available === wB.available + 1500 && (await qs(`select body from notifications where user_id='${S1}' and title='Retrait rejeté'`))[0].body.includes('injoignable'));
  await as(S1);
  const p3 = (await q(`select request_seller_payout(1200) id`))[0].id;
  check('G21 le vendeur annule sa propre demande', (await q(`select payout_cancel_request('${p3}') r`))[0].r === 'cancelled');
  await as(F);
  const avG22 = (await wallet(S1)).available;
  await as(F);
  await fails('G22 payout_create : plafonne au solde disponible', `select payout_create('${S1}', ${avG22 + 1})`, /solde disponible/);
  const p4 = (await q(`select payout_create('${S1}', 1000) id`))[0].id;
  await sup();
  check('G23 versement cree par la finance : numero lie, vendeur notifie', (await q(`select phone from payout_batches where id='${p4}'`))[0].phone === '691234567' && (await nc(S1, 'Versement prévu')) === 1);
  check('G24 S4-123 : actions de retrait tracees dans le journal d audit', (await q(`select count(*)::int n from audit_log where category = 'Finance' and action in ('Demande de retrait', 'Versement effectué', 'Versement rejeté', 'Versement créé')`))[0].n >= 4);
  await as(F);
  await fails('G25 un lot prevu ne repasse pas a « prevu »', `select payout_set_status('${p4}', 'prevu')`, /Transition impossible/);
  await q(`select payout_set_status('${p4}', 'verse', 'OM-1')`);
  await as(F);
  const jr = (await q(`select finance_journal(50) r`))[0].r;
  check('G26 journal : les demandes ne sont pas des ecritures ; reversements verses presents', !jr.rows.some((x) => /Reversement/.test(x.label) && x.debit === 1500));

  // ============================================================ H. S4-121 : frais de livraison rattachés à la répartition
  await sup();
  await db.exec(`insert into delivery_zones (seller_id, from_city, to_city, fee) values ('${S1}', 'Douala', 'Douala', 1500)`);
  const oh = await newOrder(B, [[lamp, 'Lampe', 10000, 1]], { fee: 1500, home: true, city: 'Douala' });
  const dh = (await q(`select * from money_entries where order_id='${oh.id}' and kind='delivery'`));
  check('H1 frais de livraison : une ligne « delivery » de 1500 au vendeur qui livre', dh.length === 1 && dh[0].beneficiary_id === S1 && dh[0].beneficiary_amount === 1500 && dh[0].gross === 1500 && dh[0].status === 'held');
  const oh2 = await newOrder(B, [[lamp, 'Lampe', 10000, 1]], { fee: 2000, home: true, city: 'Douala' });
  const dh2 = (await q(`select * from money_entries where order_id='${oh2.id}' and kind='delivery'`));
  check('H2 les frais payes (2000) sont integralement repartis sur les vendeurs qui livrent', dh2.length === 1 && dh2[0].beneficiary_id === S1 && dh2.reduce((s, x) => s + x.gross, 0) === 2000);
  await steps(S1, oh.num); await as(B); await q(`select confirm_receipt('${oh.num}')`);
  check('H3 la livraison est liberee avec la vente (70 % + 1500)', (await entry(oh.id, S1)).status === 'released' && (await qs(`select status from money_entries where order_id='${oh.id}' and kind='delivery'`))[0].status === 'released');
  await as(F);
  const jr2 = (await q(`select finance_journal(200) r`))[0].r;
  check('H4 journal finance : « Dont frais de livraison » (plus de « Commission »)', jr2.rows.some((x) => /Dont frais de livraison/.test(x.label)) && !jr2.rows.some((x) => /^Commission/.test(x.label)));
  const ohc = await newOrder(B, [[lamp, 'Lampe', 10000, 1]], { fee: 1500, home: true, city: 'Douala', cod: true });
  await sup(); await db.exec(`update orders set paid = true where id = '${ohc.id}'`);
  check('H5 paiement a la livraison : aucune ligne de livraison (le vendeur encaisse en especes)', (await q(`select count(*)::int n from money_entries where order_id='${ohc.id}' and kind='delivery'`))[0].n === 0);

  // ============================================================ I. SQL1-17 : parrainage et livraison déclarée par le vendeur seul
  await sup();
  await db.exec(`insert into referrals (referee_id, referrer_id, status) values ('${B2}', '${R}', 'pending'), ('${B3}', '${R}', 'pending')`);
  const ocod = await newOrder(B2, [[bureau, 'Bureau', 15000, 1]], { cod: true });
  await as(B2); await q(`select my_pickup_code('${ocod.num}')`).catch(() => {});
  await steps(S2, ocod.num);
  await sup();
  check('I1 commande a la livraison declaree livree par le vendeur : payee mais AUCUNE prime', (await q(`select paid from orders where id='${ocod.id}'`))[0].paid === true && (await q(`select count(*)::int n from earnings where user_id='${R}'`))[0].n === 0);
  await as(B2); await q(`select confirm_receipt('${ocod.num}')`);
  await sup();
  check('I2 apres confirmation de l acheteur : prime de parrainage creee (500)', (await q(`select amount from earnings where user_id='${R}' and source='referral_bonus'`))[0]?.amount === 500);
  const opay = await newOrder(B3, [[lamp, 'Lampe', 10000, 1]]);
  await sup();
  check('I3 paiement Mobile Money trace : prime due des le paiement (flux inchange)', (await q(`select count(*)::int n from earnings where user_id='${R}' and referee_id='${B3}'`))[0].n === 1);
  await db.exec(`insert into auth.users(id,email) values ('${id('c2')}','x2@t.cm'); insert into profiles(id,name,role,email) values ('${id('c2')}','Zoe Filleule','client','x2@t.cm')`);
  await db.exec(`insert into referrals (referee_id, referrer_id, status) values ('${id('c2')}', '${S2}', 'pending')`);
  const oself = await newOrder(id('c2'), [[bureau, 'Bureau', 15000, 1]]);
  await sup();
  check('I4 le parrain qui vend lui-meme sur la commande ne gagne rien', (await q(`select count(*)::int n from earnings where user_id='${S2}'`))[0].n === 0);

  // ============================================================ J. revenus, relevé, reçu, commandes reçues
  await as(S1);
  rev = (await q(`select seller_revenue() r`))[0].r;
  check('J1 S4-24/29 : la cle « weeks » est de retour avec des ventes', Array.isArray(rev.weeks) && rev.weeks.length >= 1 && rev.weeks[0].week.length === 10);
  check('J2 S4-23 : « months » limite a 6 mois', rev.months.length >= 1 && rev.months.length <= 6);
  check('J3 S4-30 : chiffre d affaires brut distinct de la part nette', rev.gross > rev.total - rev.available && rev.gross > 0);
  check('J4 S4-25 : parts nettes coherentes avec le portefeuille', rev.available === (await wallet(S1)).available);
  const rv5 = (await q(`select seller_revenue() r`))[0].r.holds;
  check('J5 chaque blocage a sa raison (confirmation en attente ou livraison)', Array.isArray(rv5));
  const st = (await q(`select seller_money_statement() s`))[0].s;
  check('J6 S4-73 : releve du vendeur : lignes, totaux et versements reels', st.rows.length >= 5 && st.totals.mine > 0 && st.payouts.length >= 1 && st.payouts[0].reference !== undefined && st.rule === '70/20/10');
  await as(S1);
  await fails('J7 releve : periode invalide refusee', `select seller_money_statement('2026-02-01', '2026-01-01')`, /invalide/);
  const rc = (await q(`select seller_sale_receipt('${o1.num}') r`))[0].r;
  check('J8 S4-73 : recu de vente reel (lignes, parts, nom abrege de l acheteur)', rc.lines.length === 1 && rc.entries[0].mine === 7000 && rc.buyer === 'Cora C.' && rc.mode === 'campus');
  await as(S2);
  await fails('J9 un autre vendeur ne lit pas ce recu', `select seller_sale_receipt('${o1.num}')`, /introuvable/);
  await as(S1);
  const so = await q(`select * from seller_orders() where number='${oh.num}'`);
  check('J10 S4-11/15 : commandes recues : mode, ville et etat de la remise', so.length === 1 && so[0].home_delivery === true && so[0].delivery_city === 'Douala' && so[0].confirmed === true && so[0].cod === false);
  await as(S2);
  const so2 = (await q(`select * from seller_orders() where number='${ocod.num}'`))[0];
  check('J11 paiement a la livraison signale au vendeur', so2.cod === true);

  // ============================================================ K. S4-117 : visibilité de la table missions
  await sup();
  await db.exec(`insert into missions (number, client_id, kind, title, description, total, status) values
    ('#BR-1', '${C}', 'besoin', 'Logo pour ma boutique', 'Je cherche un logo moderne pour ma boutique de vetements.', 50000, 'published'),
    ('#BR-2', '${C}', 'mission', 'Mission sur mesure · Identite', 'Brief adresse au departement, qualification des equipes.', 90000, 'published'),
    ('#BR-3', '${C}', 'besoin', 'Brouillon prive', 'Un brouillon que personne ne doit voir.', 10000, 'draft')`);
  const mid1 = (await q(`select id from missions where number='#BR-1'`))[0].id;
  await as(S1);
  check('K1 un etudiant ne lit plus la table missions (ni titre, ni description, ni client_id)', (await q(`select count(*)::int n from missions`))[0].n === 0);
  const on = (await q(`select open_needs_list() r`))[0].r;
  check('K2 open_needs_list : le besoin public, sans identifiant du client', on.length === 1 && on[0].title === 'Logo pour ma boutique' && !('client_id' in on[0]) && on[0].own === false);
  check('K3 le brief adresse au departement n est pas liste aux autres comptes', !on.some((x) => /Identite/.test(x.title)));
  check('K4 open_calls (ecran des appels) repond pareil', (await q(`select open_calls() r`))[0].r.length === 1);
  check('K5 open_needs() du lot missions n expose plus le brief non plus', !(await q(`select open_needs() r`))[0].r.some((x) => x.kind === 'mission'));
  await as(C);
  check('K6 le client voit ses 3 besoins (table) ', (await q(`select count(*)::int n from missions`))[0].n === 3);
  check('K7 le client retrouve son propre brief dans la liste (own = true)', (await q(`select open_needs_list() r`))[0].r.some((x) => x.own === true && /Identite/.test(x.title)));
  await as(D);
  check('K8 le département lit les besoins ouverts (qualification) mais plus les besoins fermés qui ne concernent pas ses étudiants (H2)', (await q(`select count(*)::int n from missions`))[0].n === 2 && (await q(`select open_needs_list() r`))[0].r.length === 2, JSON.stringify(await q(`select count(*)::int n from missions`)));
  await sup();
  await db.exec(`insert into mission_proposals (mission_id, author_id, amount, delay_days, status) values ('${mid1}', '${S1}', 40000, 10, 'accepted')`);
  await as(S1);
  check('K9 le prestataire retenu lit sa mission (et seulement elle)', (await q(`select count(*)::int n from missions`))[0].n === 1);
  await as(null, 'anon');
  check('K10 un visiteur ne lit aucun besoin', (await q(`select count(*)::int n from missions`))[0].n === 0);

  console.log(`\n${ok}/${ok + ko}`);
}

