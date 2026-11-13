let ok = 0, ko = 0;
export async function run(db) {
  const S1 = '00000000-0000-0000-0000-0000000000a1', S2 = '00000000-0000-0000-0000-0000000000a2', B = '00000000-0000-0000-0000-0000000000b1', M = '00000000-0000-0000-0000-0000000000ee', F = '00000000-0000-0000-0000-0000000000f1';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[S1, 'Awa Vendeuse', 'student'], [S2, 'Boris Vendeur', 'student'], [B, 'Cora Cliente', 'client'], [M, 'Mod Admin', 'admin'], [F, 'Fin Finance', 'finance']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await sup();
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values
    ('${S1}','Lampe','Design','Maison',10000,5,'approved','{}'), ('${S2}','Table','Design','Maison',5000,5,'approved','{}'), (null,'Cahier campus','Design','Papeterie',2000,50,'approved','{}')`);
  const L = async (t) => (await q(`select id from listings where title='${t}'`))[0].id;
  const [l1, l2, l3] = [await L('Lampe'), await L('Table'), await L('Cahier campus')];
  const newOrder = async (num, cod, lines) => {
    await sup();
    const o = (await q(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, cod) values ('${num}', '${B}', 0, 0, 'Mobile Money', 0, false, false, ${cod}) returning id`))[0].id;
    for (const [lid, title, price, qty] of lines) await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${o}', '${lid}', '${title}', ${price}, ${qty})`);
    return o;
  };
  const o1 = await newOrder('#T-1', false, [[l1, 'Lampe', 10000, 1], [l2, 'Table', 5000, 2], [l3, 'Cahier campus', 2000, 1]]);
  check('regle de depart 70/20/10', (await q(`select money_split_label() l`))[0].l === '70/20/10');
  await db.exec(`update orders set paid = true where id = '${o1}'`);
  let e = await q(`select e.*, p.name from money_entries e left join profiles p on p.id = e.beneficiary_id where order_id = '${o1}' order by gross desc, name`);
  const e1 = e.find(x => x.name === 'Awa Vendeuse'), e2 = e.find(x => x.name === 'Boris Vendeur'), ep = e.find(x => x.beneficiary_id === null);
  check('paiement : 3 lignes de sequestre (2 vendeurs + plateforme)', e.length === 3);
  check('vendeur 1 : 70 / 20 / 10 sur 10000 en sequestre', e1.gross === 10000 && e1.beneficiary_amount === 7000 && e1.institution_amount === 2000 && e1.platform_amount === 1000 && e1.status === 'held');
  check('vendeur 2 : meme regle', e2.gross === 10000 && e2.beneficiary_amount === 7000 && e2.status === 'held');
  check('produit de la plateforme : 100 % plateforme, sans beneficiaire', ep.gross === 2000 && ep.platform_amount === 2000 && ep.status === 'released');
  // aucun versement possible tant que rien n'est livre
  await as(S1);
  let w = (await q(`select my_money() r`))[0].r;
  check('solde : 7000 en sequestre, 0 disponible', w.held === 7000 && w.available === 0 && w.rule === '70/20/10');
  await as(F);
  await fails('versement : impossible avant livraison', `select payout_create('${S1}', 1000)`, /solde disponible \(0 FCFA\)/);
  // livraison -> deblocage
  await sup();
  await db.exec(`update order_lines set fulfillment = 4 where order_id = '${o1}' and listing_id = '${l1}'`);
  await as(S1);
  w = (await q(`select my_money() r`))[0].r;
  check('livraison : 7000 debloques pour le vendeur 1', w.available === 7000 && w.held === 0 && w.released === 7000);
  check('notification : argent debloque', (await q(`select count(*)::int n from notifications where user_id='${S1}' and title='Argent débloqué'`))[0].n === 1);
  await as(S2);
  check('vendeur 2 : toujours en sequestre (pas livre)', (await q(`select my_money() r`))[0].r.available === 0);
  // versements : par la finance, dans la limite du solde
  await as(S1);
  await fails('l etudiant ne peut pas se verser lui-meme', `select payout_create('${S1}', 1000)`, /non autorisée/);
  await as(F);
  await fails('versement : au-dela du solde refuse', `select payout_create('${S1}', 7001)`, /solde disponible \(7000 FCFA\)/);
  check('versement : cree par la finance dans la limite', (await q(`select payout_create('${S1}', 5000) id`)).length === 1);
  await fails('versement : le reste seulement', `select payout_create('${S1}', 2001)`, /solde disponible \(2000 FCFA\)/);
  await as(S1);
  check('solde apres versement prevu : 2000', (await q(`select my_money() r`))[0].r.available === 2000);
  // reclamation ouverte : le deblocage attend
  await sup();
  await db.exec(`insert into claims (order_id, claimant_id, seller_id, reason, details) values ('${o1}', '${B}', '${S2}', 'damaged', 'Table abimee a la livraison, photo disponible')`);
  await db.exec(`update order_lines set fulfillment = 4 where order_id = '${o1}' and listing_id = '${l2}'`);
  await as(S2);
  check('reclamation ouverte : l argent reste en sequestre', (await q(`select my_money() r`))[0].r.available === 0);
  // blocage / deblocage par l'administrateur
  await sup();
  const id2 = (await q(`select id from money_entries where order_id = '${o1}' and beneficiary_amount = 7000 and status = 'held'`))[0].id;
  await as(M);
  await q(`select money_freeze('${id2}', 'Litige en cours sur la table')`);
  await sup();
  check('blocage : montant bloque avec son motif', (await q(`select status, frozen_reason from money_entries where id = '${id2}'`))[0].status === 'frozen');
  await sup();
  await db.exec(`update claims set status = 'closed' where order_id = '${o1}'`);
  await as(M);
  await q(`select money_unfreeze('${id2}')`);
  await as(S2);
  check('deblocage apres cloture de la reclamation : 7000', (await q(`select my_money() r`))[0].r.available === 7000);
  await as(F);
  await fails('blocage : la finance ne bloque pas', `select money_freeze('${id2}', 'test')`, /Réservé à l'administrateur/);
  // annulation avant livraison : remboursement
  const o2 = await newOrder('#T-2', false, [[l1, 'Lampe', 10000, 1]]);
  await db.exec(`update orders set paid = true where id = '${o2}'`);
  await db.exec(`update orders set cancelled_at = now() where id = '${o2}'`);
  check('commande annulee : sequestre rembourse', (await q(`select status from money_entries where order_id = '${o2}'`))[0].status === 'refunded');
  // paiement a la livraison : part a reverser
  const o3 = await newOrder('#T-3', true, [[l1, 'Lampe', 10000, 1]]);
  await db.exec(`update orders set paid = true where id = '${o3}'`);
  await db.exec(`update order_lines set fulfillment = 4 where order_id = '${o3}'`);
  check('paiement a la livraison : part a recouvrer (30 % = 3000)', (await q(`select status, institution_amount + platform_amount as du from money_entries where order_id = '${o3}'`))[0].du === 3000);
  await as(S1);
  w = (await q(`select my_money() r`))[0].r;
  check('solde : les 3000 a recouvrer sont deduits (2000 - 3000 -> 0)', w.owed === 3000 && w.available === 0);
  // regle modifiable, uniquement par l'administrateur, pour les paiements futurs
  await as(F);
  await fails('regle : modification reservee a l administrateur', `select money_split_set(60, 25, 15)`, /Réservé/);
  await as(M);
  await fails('regle : total 100 obligatoire', `select money_split_set(60, 25, 10)`, /100/);
  await q(`select money_split_set(60, 25, 15, 'Test')`);
  const o4 = await newOrder('#T-4', false, [[l2, 'Table', 5000, 1]]);
  await db.exec(`update orders set paid = true where id = '${o4}'`);
  const e4 = (await q(`select beneficiary_amount b, institution_amount i, platform_amount p, split from money_entries where order_id = '${o4}'`))[0];
  check('nouvelle regle 60/25/15 appliquee aux paiements futurs', e4.b === 3000 && e4.i === 1250 && e4.p === 750 && e4.split === '60/25/15');
  check('anciennes lignes inchangees (70/20/10)', (await q(`select split from money_entries where order_id = '${o1}' and beneficiary_amount = 7000 limit 1`))[0].split === '70/20/10');
  // administration
  await as(M);
  const ov = (await q(`select money_admin_overview() r`))[0].r;
  check('administration : vue d ensemble', ov.rule === '60/25/15' && ov.platform > 0 && ov.institution_fund > 0);
  check('administration : liste des lignes', (await q(`select money_admin_list(null, 50) r`))[0].r.length >= 6);
  await as(S1);
  await fails('un etudiant ne voit pas la vue d administration', `select money_admin_overview()`, /Réservé/);
  await fails('aucun acces direct aux lignes', `select * from money_entries`, /permission/);
  await as(S1);
  const rev = (await q(`select seller_revenue() r`))[0].r;
  check('revenus du vendeur : parts nettes et regle affichees', rev.rule === '60/25/15' && rev.total > 0 && rev.paid_out === 0);
  console.log(`\n${ok}/${ok + ko}`);
}
