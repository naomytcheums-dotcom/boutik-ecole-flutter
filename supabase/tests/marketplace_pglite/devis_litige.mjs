let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Prestataire', 'student'], [B, 'Boris Client', 'student'], [C, 'Cora Autre', 'student'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values
    ('${A}','Creation de logo','Design','Services',20000,99,'approved','{}'),
    ('${A}','Lampe en bois','Genie civil','Maison',25000,5,'approved','{a,b,c}')`);
  const logo = (await q(`select id from listings where title='Creation de logo'`))[0].id;
  // --- devis accepté -> commande au prix convenu
  await as(B);
  const qid = (await q(`select request_quote_offer('${logo}', 'Un logo pour ma boutique de jus', 15000, '2 semaines') id`))[0].id;
  await fails('commande : devis pas encore accepte', `select quote_checkout('${qid}')`, /Acceptez d'abord/);
  await as(A);
  await q(`select answer_quote('${qid}', 18000, 5, 'Trois propositions de logo')`);
  await as(B);
  await q(`select decide_quote('${qid}', true)`);
  await as(C);
  await fails('commande : seul le demandeur commande', `select quote_checkout('${qid}')`, /introuvable/);
  await as(B);
  const r1 = (await q(`select quote_checkout('${qid}') r`))[0].r;
  check('commande : au prix du devis (18000) et non au prix catalogue (20000)', r1.subtotal === 18000 && r1.number.startsWith('#BE-') && r1.existing === false);
  const ln = (await q(`select ol.unit_price, ol.qty, o.subtotal, o.paid, o.buyer_id from orders o join order_lines ol on ol.order_id = o.id where o.number = '${r1.number}'`))[0];
  check('commande : ligne a 18000, non payee, a l acheteur', ln.unit_price === 18000 && ln.qty === 1 && ln.subtotal === 18000 && ln.paid === false && ln.buyer_id === B);
  const r2 = (await q(`select quote_checkout('${qid}') r`))[0].r;
  check('commande : une seule par devis (idempotent)', r2.number === r1.number && r2.existing === true);
  await as(A);
  check('commande : le prestataire est notifie', (await q(`select count(*)::int n from notifications where user_id='${A}' and title='Commande au prix du devis'`))[0].n === 1);
  // --- litige : refus de payer à la remise
  await as(B);
  const lamp = (await q(`select id from listings where title='Lampe en bois'`))[0].id;
  await db.exec('reset role');
  await db.exec(`select set_config('app.internal','1',false)`);
  await db.exec(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, cod) values ('#BE-T-9', '${B}', 25000, 0, 'Paiement à la livraison', 0, false, false, true)`);
  await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty, fulfillment) select id, '${lamp}', 'Lampe en bois', 25000, 1, 3 from orders where number = '#BE-T-9'`);
  await db.exec(`select set_config('app.internal','',false)`);
  await as(C);
  await fails('litige : seul le vendeur de la commande', `select dispute_open('#BE-T-9', 'Le client refuse de payer a la remise')`, /introuvable/);
  await as(A);
  await fails('litige : description obligatoire', `select dispute_open('#BE-T-9', 'court')`, /10 caractères/);
  const d = (await q(`select dispute_open('#BE-T-9', 'Le client refuse de payer a la remise') id`))[0].id;
  await fails('litige : un seul ouvert par commande', `select dispute_open('#BE-T-9', 'Le client refuse toujours de payer')`, /déjà ouvert/);
  await as(B);
  check('litige : l acheteur est notifie', (await q(`select count(*)::int n from notifications where user_id='${B}' and kind='dispute'`))[0].n === 1);
  await q(`select dispute_reply('${d}', 'La lampe etait abimee')`);
  let list = (await q(`select my_disputes() r`))[0].r;
  check('litige : mes litiges cote acheteur avec ma reponse', list.length === 1 && list[0].as === 'buyer' && list[0].buyer_reply === 'La lampe etait abimee');
  await as(C);
  check('litige : invisible pour un tiers', (await q(`select my_disputes() r`))[0].r.length === 0);
  await fails('litige : decision reservee a l equipe', `select dispute_decide('${d}', 'cancel')`, /Réservé/);
  await as(M);
  check('litige : l equipe voit tout', (await q(`select my_disputes() r`))[0].r.length === 1);
  await fails('litige : decision inconnue', `select dispute_decide('${d}', 'zzz')`, /inconnue/);
  const stockBefore = (await q(`select stock from listings where id='${lamp}'`))[0].stock;
  check('litige : annulation par l equipe', (await q(`select dispute_decide('${d}', 'cancel', 'Produit abime') r`))[0].r === 'cancel');
  const o = (await q(`select cancelled_at from orders where number = '#BE-T-9'`))[0];
  const stockAfter = (await q(`select stock from listings where id='${lamp}'`))[0].stock;
  check('litige : commande annulee et stock remis', o.cancelled_at !== null && stockAfter === stockBefore + 1);
  await fails('litige : deja tranche', `select dispute_decide('${d}', 'close')`, /déjà tranché/);
  await as(A);
  check('litige : le vendeur est notifie de la decision', (await q(`select count(*)::int n from notifications where user_id='${A}' and title='Litige tranché'`))[0].n === 1);
  // --- annonce épinglée : notification des membres
  const cid = (await q(`select create_community('Dev Flutter','Entraide autour de Flutter','','public','',null,'interest',null,'Flutter') id`))[0].id;
  await as(M);
  await q(`select community_decide('${cid}', true)`);
  await as(B);
  await q(`select join_community('${cid}')`);
  await as(A);
  const pid = (await q(`select create_community_post('${cid}', 'Reunion vendredi a 10h') id`))[0].id;
  await q(`select pin_community_post('${pid}', true)`);
  await as(B);
  check('annonce epinglee : les membres sont notifies', (await q(`select count(*)::int n from notifications where user_id='${B}' and kind='community_announcement'`))[0].n === 1);
  await as(A);
  check('annonce epinglee : pas de notification a soi-meme', (await q(`select count(*)::int n from notifications where user_id='${A}' and kind='community_announcement'`))[0].n === 0);
  console.log(`\n${ok}/${ok + ko}`);
}
