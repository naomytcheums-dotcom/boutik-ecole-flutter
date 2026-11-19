// Scénario PGlite de 20261119030000_g3_commande_machine_etats.sql (lot G3 : commande, paiement, livraison, retrait).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./etu2_g3.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000003${String(n).padStart(2, '0')}`;
  const S1 = U(1), S2 = U(2), S3 = U(3), SB = U(4), B = U(5), B2 = U(6), ADM = U(7), FIN = U(8), SUP = U(9), DEP = U(10), CO = U(11), COP = U(12);
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  const roles = [[S1, 'student'], [S2, 'student'], [S3, 'student'], [SB, 'student'], [B, 'client'], [B2, 'client'], [ADM, 'admin'], [FIN, 'finance'], [SUP, 'support'], [DEP, 'dept'], [CO, 'company'], [COP, 'company']];
  for (const [id, role] of roles) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','g3${id.slice(-2)}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','Nom ${id.slice(-2)}','${role}','g3${id.slice(-2)}@t.cm')`);
  }
  await db.exec(`update profiles set certification = 'approved', phone_verified = true where role = 'student'`);
  // K1 : droits minimaux par défaut ; la finance et le support du scénario reçoivent explicitement leurs permissions.
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${FIN}' and team_code = 'finance';
    update admin_team_members set permissions = array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests'] where user_id = '${SUP}' and team_code = 'support'`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${CO}', 'Approuvee', 'approved'), ('${COP}', 'En attente', 'pending') on conflict (owner_id) do update set status = excluded.status`);
  await sup();
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values
    ('${S1}','Lampe G3','Design','Maison',10000,50,'approved','{}'), ('${S2}','Table G3','Design','Maison',5000,50,'approved','{}'),
    ('${S3}','Chaise G3','Design','Maison',3000,50,'approved','{}'), ('${S1}','Logo G3','Design','Services',20000,5,'approved','{}'),
    ('${S1}','Sac G3','Design','Mode',8000,50,'approved','{}')`);
  const L = async (t) => (await q(`select id from listings where title='${t}'`))[0].id;
  const [lLampe, lTable, lChaise, lLogo, lSac] = [await L('Lampe G3'), await L('Table G3'), await L('Chaise G3'), await L('Logo G3'), await L('Sac G3')];
  const item = (id, qty = 1) => `{"id":"${id}","qty":${qty}}`;
  const buy = async (uid, items, method = 'Mobile Money', key = null) => {
    await as(uid);
    return (await q(`select marketplace_checkout('[${items.join(',')}]'::jsonb, false, '${method}', null, null, ${key ? `'${key}'` : 'null'}) r`))[0].r;
  };
  const pay = async (num) => { await sup(); await db.exec(`update orders set paid = true where number = '${num}'`); };

  // --- création : propriétaire, rôles, prix et quantités recalculés côté serveur
  await as(S1);
  await fails('achat de sa propre annonce refusé (étudiant-vendeur)', `select marketplace_checkout('[${item(lLampe)}]'::jsonb, false, 'Mobile Money')`, /propre/);
  const oSB = await buy(SB, [item(lLampe, 2)]);
  check('un étudiant peut acheter l\'annonce d\'un autre : prix lu en base (2 x 10000)', oSB.subtotal === 20000 && oSB.fee === 0);
  const oMulti = await buy(B, [item(lLampe), item(lTable, 2), item(lChaise)], 'Mobile Money', 'cle-g3-multi-01');
  check('commande multi-vendeurs : total recalculé (10000 + 10000 + 3000)', oMulti.subtotal === 23000);
  const oGarbage = await buy(B2, [item(lSac)], 'x');
  check('moyen de paiement libre ramené à Mobile Money (pas de circuit à la livraison forgé)', (await q(`select method from orders where number = '${oGarbage.number}'`))[0].method === 'Mobile Money');
  await as(B2);
  await fails('quantité non numérique refusée', `select marketplace_checkout('[{"id":"${lSac}","qty":"abc"}]'::jsonb, false, 'Mobile Money')`, /Quantité invalide/);
  await fails('quantité hors limite refusée', `select marketplace_checkout('[${item(lSac, 21)}]'::jsonb, false, 'Mobile Money')`, /Quantité invalide/);
  await fails('identifiant mal formé refusé', `select marketplace_checkout('[{"id":"pas-un-uuid","qty":1}]'::jsonb, false, 'Mobile Money')`, /indisponible/);
  await fails('service : commande directe refusée (devis)', `select marketplace_checkout('[${item(lLogo)}]'::jsonb, false, 'Mobile Money')`, /devis/);
  await fails('panier vide refusé', `select marketplace_checkout('[]'::jsonb, false, 'Mobile Money')`, /Panier vide/);
  await as(null, 'anon');
  await fails('anonyme : commande refusée', `select marketplace_checkout('[${item(lSac)}]'::jsonb, false, 'Mobile Money')`, /permission denied|Connexion/);
  // client prestataire (entreprise) : ses droits d'achat sont inchangés
  const oCo = await buy(CO, [item(lSac)]);
  check('entreprise approuvée : achat inchangé', oCo.subtotal === 8000);
  const oCop = await buy(COP, [item(lSac)]);
  check('entreprise non approuvée : achat inchangé', oCop.subtotal === 8000);

  // --- idempotence
  const r1 = await buy(B2, [item(lTable)], 'Mobile Money', 'cle-g3-idem-001');
  const r2 = await buy(B2, [item(lTable)], 'Mobile Money', 'cle-g3-idem-001');
  check('double soumission : la même commande est rejouée', r2.replayed === true && r2.number === r1.number);
  await pay(r1.number);
  const r3 = await buy(B2, [item(lTable)], 'Mobile Money', 'cle-g3-idem-001');
  check('une commande déjà payée n\'est pas rejouée : nouvelle commande', r3.replayed === false && r3.number !== r1.number);

  // --- vendeur suspendu : plus d'achat, plus de préparation
  const oS3 = await buy(B, [item(lChaise)]);
  await pay(oS3.number);
  await sup();
  await db.exec(`update profiles set suspended = true where id = '${S3}'`);
  await as(S3);
  await fails('vendeur suspendu : ne peut pas avancer une commande', `select set_seller_order_status('${oS3.number}', 1)`, /suspendu/);
  await as(B2);
  await fails('annonce d\'un vendeur suspendu : commande refusée', `select marketplace_checkout('[${item(lChaise)}]'::jsonb, false, 'Mobile Money')`, /indisponible/);

  // --- machine d'états : aucune transition illégale
  await as(S1);
  await fails('vendeur : commande non payée introuvable', `select set_seller_order_status('${oMulti.number}', 1)`, /non payée/);
  await pay(oMulti.number);
  await as(B);
  await fails('acheteur : ne peut pas faire avancer la préparation', `select set_seller_order_status('${oMulti.number}', 1)`, /introuvable/);
  await as(DEP);
  await fails('dept : ne peut pas faire avancer une commande qui n\'est pas à la plateforme', `select set_seller_order_status('${oMulti.number}', 1)`, /introuvable/);
  await as(SB);
  await fails('un autre étudiant ne touche pas à cette commande', `select set_seller_order_status('${oMulti.number}', 1)`, /introuvable/);
  await as(S1);
  await fails('vendeur : « livré » sans étape refusé', `select set_seller_order_status('${oMulti.number}', 4)`, /dans l'ordre/);
  await fails('vendeur : statut hors plage refusé', `select set_seller_order_status('${oMulti.number}', 7)`, /Statut invalide/);
  check('vendeur : accepte (1)', (await q(`select set_seller_order_status('${oMulti.number}', 1) s`))[0].s === 1);
  await fails('vendeur : statut déjà atteint refusé', `select set_seller_order_status('${oMulti.number}', 1)`, /déjà atteint/);
  await as(B);
  await fails('acheteur : confirmer la réception avant livraison refusé', `select confirm_receipt('${oMulti.number}')`, /pas encore déclaré/);
  await as(B2);
  await fails('acheteur : confirmer une commande non payée refusé', `select confirm_receipt('${oGarbage.number}')`, /pas payée/);
  await as(S1);
  for (const s of [2, 3, 4]) await q(`select set_seller_order_status('${oMulti.number}', ${s})`);
  await as(S2);
  check('multi-vendeurs : le vendeur 2 reste à son propre sous-statut (0)', (await q(`select status from seller_orders() where number = '${oMulti.number}'`))[0].status === 0);
  await as(B);
  check('acheteur : confirme la réception du vendeur 1 seulement', (await q(`select confirm_receipt('${oMulti.number}') r`))[0].r === 'confirmed');
  await sup();
  const confirmed = await q(`select l.seller_id, ol.confirmed_at is not null c from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = (select id from orders where number = '${oMulti.number}')`);
  check('multi-vendeurs : seules les lignes livrées sont confirmées', confirmed.filter((r) => r.c).every((r) => r.seller_id === S1) && confirmed.some((r) => r.seller_id === S2 && !r.c));
  await as(B);
  check('acheteur : seconde confirmation sans effet', (await q(`select confirm_receipt('${oMulti.number}') r`))[0].r === 'already');

  // --- demande d'annulation en cours : le vendeur n'avance plus
  const oRef = await buy(B, [item(lSac)]);
  await pay(oRef.number);
  await as(B);
  await q(`select order_refund_request('${oRef.number}', 'Je me suis trompé de modèle')`);
  await as(S1);
  await fails('demande d\'annulation en cours : le vendeur ne peut plus avancer', `select set_seller_order_status('${oRef.number}', 1)`, /demande d'annulation/);

  // --- paiement à la livraison : confirmation, remise, encaissement
  const oCod = await buy(B2, [item(lSac)], 'Paiement à la livraison');
  await as(B2);
  await fails('à la livraison : un code de retrait n\'existe pas avant confirmation', `select my_pickup_code('${oCod.number}')`, /payée/);
  await fails('à la livraison : pas de QR de retrait avant confirmation', `select qr_issue('order_pickup', '${oCod.number}')`, /payée/);
  check('à la livraison : confirmation', (await q(`select confirm_cod_order('${oCod.number}') s`))[0].s === 'confirmed');
  await fails('à la livraison : payer en ligne refusé (messagerie)', `select payment_start('order', 'Commande ${oCod.number}', ${oCod.subtotal + oCod.fee})`, /à la livraison/);
  const code = (await q(`select my_pickup_code('${oCod.number}') c`))[0].c;
  check('à la livraison : le code de retrait est délivré à l\'acheteur', /^[0-9]{6}$/.test(code));
  await as(S1);
  for (const s of [1, 2, 3]) await q(`select set_seller_order_status('${oCod.number}', ${s})`);
  await as(B);
  await fails('acheteur : pas de remise par lui-même', `select confirm_pickup('${oCod.number}', '${code}')`, /Réservé/);
  await as(SB);
  await fails('un autre étudiant ne remet pas la commande', `select confirm_pickup('${oCod.number}', '${code}')`, /Réservé/);
  await as(SUP);
  check('remise au kiosque : code faux', (await q(`select confirm_pickup('${oCod.number}', '000000') r`))[0].r === 'incorrect' || code === '000000');
  check('remise au kiosque : commande à la livraison remise et encaissée', (await q(`select confirm_pickup('${oCod.number}', '${code}') r`))[0].r === 'delivered');
  await sup();
  check('à la livraison : la commande est marquée payée à la remise', (await q(`select paid from orders where number = '${oCod.number}'`))[0].paid === true);
  await as(SUP);
  await fails('remise : une commande déjà remise ne se remet pas', `select confirm_pickup('${oCod.number}', '${code}')`, /déjà remise/);

  // --- remise : commande non payée / annulée
  const oUnpaid = await buy(B2, [item(lTable)]);
  await as(SUP);
  await fails('remise : commande non payée refusée', `select confirm_pickup('${oUnpaid.number}', '123456')`, /non payée/);
  await as(B2);
  check('annulation d\'une commande non payée', (await q(`select cancel_order('${oUnpaid.number}') r`))[0].r === 'cancelled');
  await as(SUP);
  await fails('remise : commande annulée refusée', `select confirm_pickup('${oUnpaid.number}', '123456')`, /non payée/);

  // --- paiements déclarés : commande annulée ou à la livraison
  const oDecl = await buy(B2, [item(lTable)]);
  await as(B2);
  const tx = (await q(`select payment_start('order', 'Commande ${oDecl.number}', ${oDecl.subtotal + oDecl.fee}) id`))[0].id;
  await q(`select cancel_order('${oDecl.number}')`).catch(() => null);
  await fails('payer en ligne une commande annulée : déclaration refusée', `select payment_declare('${tx}', 'MP123456')`, /annulée ou déjà réglée/);
  const oRefPay = await buy(B2, [item(lTable)]);
  await sup();
  await db.exec(`update orders set reference = 'NP-REF-1' where number = '${oRefPay.number}'`);
  await as(B2);
  await fails('paiement Mobile Money en cours : pas de seconde demande manuelle', `select payment_start('order', 'Commande ${oRefPay.number}', ${oRefPay.subtotal + oRefPay.fee})`, /déjà en cours/);
  await fails('paiement Mobile Money en cours : pas de passage à la livraison', `select confirm_cod_order('${oRefPay.number}')`, /method|n'est pas en paiement|en cours/);
  const oRefCod = await buy(B2, [item(lSac)], 'Paiement à la livraison');
  await sup();
  await db.exec(`update orders set reference = 'NP-REF-2' where number = '${oRefCod.number}'`);
  await as(B2);
  await fails('paiement à la livraison refusé quand un paiement en ligne est en cours', `select confirm_cod_order('${oRefCod.number}')`, /en cours/);
  await sup();
  const oCod2 = await buy(B, [item(lSac)], 'Paiement à la livraison');
  await as(B);
  await q(`select confirm_cod_order('${oCod2.number}')`);
  await sup();
  await db.exec(`insert into payment_transactions (reference, payer_id, kind, subject, amount, status) values ('PAY-G3-1', '${B}', 'order', 'Commande ${oCod2.number}', ${oCod2.subtotal + oCod2.fee}, 'pending')`);
  const txCod = (await q(`select id from payment_transactions where reference = 'PAY-G3-1'`))[0].id;
  await as(FIN);
  await fails('finance : confirmer un paiement en ligne sur une commande à la livraison refusé', `select payment_set_status('${txCod}', 'confirmed')`, /à la livraison/);
  await as(S1);
  await fails('vendeur : pas de décision sur un paiement', `select payment_set_status('${txCod}', 'confirmed')`, /non autorisée/);

  // --- QR de retrait
  const oQr = await buy(B, [item(lSac)]);
  await as(B);
  await fails('QR retrait : commande non payée refusée', `select qr_issue('order_pickup', '${oQr.number}')`, /payée/);
  await pay(oQr.number);
  await as(SB);
  await fails('QR retrait : un autre compte ne peut pas l\'émettre', `select qr_issue('order_pickup', '${oQr.number}')`, /ne vous appartient pas/);
  await as(S1);
  await fails('QR retrait : le vendeur ne peut pas l\'émettre', `select qr_issue('order_pickup', '${oQr.number}')`, /ne vous appartient pas/);
  await as(B);
  const tok = (await q(`select qr_issue('order_pickup', '${oQr.number}', 'Retrait', 600) r`))[0].r.token;
  check('QR retrait : l\'acheteur de la commande payée l\'émet', typeof tok === 'string' && tok.length === 32);
  check('QR retrait : l\'acheteur le lit sans le consommer', (await q(`select qr_resolve('${tok}', true) r`))[0].r.valid === true && (await q(`select qr_resolve('${tok}', true) r`))[0].r.valid === true);
  await as(SB);
  check('QR retrait : un tiers ne le lit pas', (await q(`select qr_resolve('${tok}', false) r`))[0].r.reason === 'forbidden');
  await as(B2);
  check('QR retrait : un autre client ne le lit pas', (await q(`select qr_resolve('${tok}', false) r`))[0].r.reason === 'forbidden');
  await as(S1);
  check('QR retrait : le vendeur de la commande le lit et le consomme', (await q(`select qr_resolve('${tok}', true) r`))[0].r.valid === true);
  check('QR retrait : usage unique', (await q(`select qr_resolve('${tok}', true) r`))[0].r.reason === 'used');
  await as(B);
  const tok2 = (await q(`select qr_issue('order_pickup', '${oQr.number}', 'Retrait', 600) r`))[0].r.token;
  await sup();
  await db.exec(`update orders set cancelled_at = now() where number = '${oQr.number}'`);
  await as(S1);
  check('QR retrait : commande annulée, code refusé', (await q(`select qr_resolve('${tok2}', false) r`))[0].r.reason === 'unavailable');
  await as(B);
  await fails('QR retrait : commande annulée, pas de nouveau code', `select qr_issue('order_pickup', '${oQr.number}', 'Retrait', 600)`, /annulée/);

  // --- RLS : chacun ne voit que ses données
  const cnt = async (uid, tbl, role = 'authenticated') => { await as(uid, role); return (await q(`select count(*)::int n from ${tbl}`))[0].n; };
  check('RLS orders : l\'acheteur voit ses commandes', (await cnt(B, 'orders')) >= 4);
  await as(B2);
  check('RLS orders : un autre client ne voit pas celles de B', (await q(`select count(*)::int n from orders where buyer_id = '${B}'`))[0].n === 0);
  check('RLS orders : le vendeur ne lit pas la table (RPC seller_orders)', (await cnt(S1, 'orders')) === 0);
  check('RLS order_lines : le vendeur ne lit pas les lignes', (await cnt(S1, 'order_lines')) === 0);
  check('RLS orders : dept ne voit rien', (await cnt(DEP, 'orders')) === 0);
  check('RLS orders : entreprise ne voit que ses propres commandes', (await cnt(CO, 'orders')) === 1);
  check('RLS orders : finance voit tout', (await cnt(FIN, 'orders')) >= 8);
  check('RLS orders : support voit tout', (await cnt(SUP, 'orders')) >= 8);
  check('RLS payment_transactions : le payeur seulement', (await cnt(B2, 'payment_transactions')) >= 1 && (await cnt(S1, 'payment_transactions')) === 0 && (await cnt(DEP, 'payment_transactions')) === 0);
  check('RLS payment_transactions : finance voit', (await cnt(FIN, 'payment_transactions')) >= 2);
  check('RLS orders : anonyme, aucune ligne lisible', (await cnt(null, 'orders', 'anon')) === 0);
  await as(B);
  check('orders : l\'écriture directe ne change rien', (await q(`update orders set paid = true where number = '${oUnpaid.number}' returning id`)).length === 0);
  check('order_lines : l\'écriture directe ne change rien', (await q(`update order_lines set fulfillment = 4 returning id`)).length === 0);

  // --- expiration : l'acheteur est prévenu
  await sup();
  const oOld = await buy(B2, [item(lTable)]);
  await sup();
  await db.exec(`update orders set created_at = now() - interval '3 hours' where number = '${oOld.number}'`);
  await sup();
  const n = (await q(`select expire_unpaid_orders() n`))[0].n;
  check('expiration : commande impayée annulée', n >= 1 && (await q(`select cancelled_at is not null c from orders where number = '${oOld.number}'`))[0].c === true);
  check('expiration : l\'acheteur est prévenu', (await q(`select count(*)::int n from notifications where user_id = '${B2}' and title = 'Commande expirée'`))[0].n >= 1);

  // --- plafond de commandes ouvertes
  for (let i = 0; i < 12; i++) {
    try { await buy(SB, [item(lSac)]); } catch (e) { check('plafond : refus au-delà de 10 commandes ouvertes', /10 commandes en attente/.test(e.message), e.message); break; }
    if (i === 11) check('plafond : refus au-delà de 10 commandes ouvertes', false, 'aucun refus');
  }
  console.log(`\n${ok} OK, ${ko} ECHEC`);
}
