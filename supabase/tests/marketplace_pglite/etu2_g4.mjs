// Lot G4 (argent du vendeur) : prouve chaque correction de 20261119040000 / 040100 / 040200 (cas autorise ET refuse) et la compatibilite avec les flux voisins.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./etu2_g4.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000000${n}`;
  const S1 = id('a1'), S2 = id('a2'), S3 = id('a3'), B = id('b1'), M = id('ee'), F = id('f1'), SU = id('d1'), D = id('e2'), CO = id('e1'), X = id('a9');
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const nc = async (uid, title) => (await qs(`select count(*)::int n from notifications where user_id='${uid}' and title='${title}'`))[0].n;
  await db.exec('reset role');
  for (const [i, nm, role] of [[S1, 'Awa Vendeuse', 'student'], [S2, 'Boris Vendeur', 'student'], [S3, 'Carine Vendeuse', 'student'], [X, 'Xavier Eleve', 'student'], [B, 'Cora Cliente', 'client'],
    [M, 'Mod Admin', 'admin'], [F, 'Fin Finance', 'finance'], [SU, 'Sam Support', 'support'], [D, 'Dep Dept', 'dept'], [CO, 'Ent Cliente', 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  // Équipes internes (lot H4) : l'agent de support de ce scénario décide aussi les remboursements (droit explicite).
  // K1 : droits minimaux par défaut ; la finance et le support du scénario reçoivent explicitement les permissions dont il a besoin.
  await db.exec(`update admin_team_members set permissions = array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'] where user_id = '${SU}' and team_code = 'support';
    update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${F}' and team_code = 'finance'`);
  await sup();
  // K2 : les vendeurs (S1, S2, S3) sont éligibles dès le départ (certifiés, téléphone vérifié) : ils reçoivent des commandes
  await db.exec(`update profiles set phone_verified = true, certification = 'approved' where id in ('${S1}', '${S2}', '${S3}')`);
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values
    ('${S1}','Lampe','Design','Maison',10000,500,'approved','{}'), ('${S2}','Table','Design','Maison',5000,500,'approved','{}'), ('${S3}','Chaise','Design','Maison',1000,500,'approved','{}'),
    ('${S1}','Lampe fine','Design','Maison',1001,500,'approved','{}'), ('${S2}','Table fine','Design','Maison',1000,500,'approved','{}'), ('${S3}','Chaise fine','Design','Maison',1000,500,'approved','{}')`);
  const L = async (t) => (await q(`select id from listings where title='${t}'`))[0].id;
  const lamp = await L('Lampe'), table = await L('Table'), chair = await L('Chaise'), lampF = await L('Lampe fine'), tableF = await L('Table fine'), chairF = await L('Chaise fine');
  let seq = 0;
  const newOrder = async (buyer, lines, o = {}) => {
    await sup();
    const num = `#G4-${++seq}`;
    const sub = lines.reduce((s, [, , p, n]) => s + p * n, 0) - (o.discount ?? 0);
    const oid = (await q(`insert into orders (number, buyer_id, subtotal, fee, discount, method, status, paid, home_delivery, cod) values ('${num}', '${buyer}', ${sub}, 0, ${o.discount ?? 0}, 'Mobile Money', 0, false, false, false) returning id`))[0].id;
    for (const [lid, title, price, qty] of lines) await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${lid}', '${title}', ${price}, ${qty})`);
    await db.exec(`update orders set paid = true where id = '${oid}'`);
    return { id: oid, num };
  };
  const steps = async (seller, num, upto = 4) => { await as(seller); for (let s = 1; s <= upto; s++) await q(`select set_seller_order_status('${num}', ${s})`); };
  const entries = async (oid) => qs(`select * from money_entries where order_id='${oid}' and kind='order' order by beneficiary_id`);
  const entry = async (oid, who) => (await qs(`select * from money_entries where order_id='${oid}' and beneficiary_id='${who}' and kind='order'`))[0];
  const wallet = async (who) => { await as(who); return (await q(`select my_money() r`))[0].r; };
  const backdate = async (oid) => { await sup(); await db.exec(`update order_lines set delivered_at = now() - interval '73 hours' where order_id='${oid}'`); };
  const autoRelease = async () => { await sup(); return (await q(`select money_auto_release() n`))[0].n; };
  const delivered = async (buyer, seller, lines) => { const o = await newOrder(buyer, lines); await steps(seller, o.num); return o; };
  const released = async (buyer, seller, lines) => { const o = await delivered(buyer, seller, lines); await as(buyer); await q(`select confirm_receipt('${o.num}')`); return o; };

  // ============================================================ A. arithmetique entiere
  const oA = await newOrder(B, [[lampF, 'Lampe fine', 1001, 1], [tableF, 'Table fine', 1000, 1], [chairF, 'Chaise fine', 1000, 1]], { discount: 100 });
  const eA = await entries(oA.id);
  check('A1 remise repartie : la somme des lignes de sequestre = exactement le prix paye des articles (2901)', eA.length === 3 && eA.reduce((s, e) => s + e.gross, 0) === 2901, JSON.stringify(eA.map((e) => e.gross)));
  check('A2 chaque ligne : part vendeur + fonds + plateforme = brut (aucun FCFA cree ou perdu)', eA.every((e) => e.beneficiary_amount + e.institution_amount + e.platform_amount === e.gross));
  const oA2 = await newOrder(B, [[lamp, 'Lampe', 10000, 1], [table, 'Table', 5000, 1], [chair, 'Chaise', 1000, 1]], { discount: 1000 });
  const eA2 = await entries(oA2.id);
  check('A3 remise de 1000 sur trois vendeurs : somme des lignes = 15000', eA2.reduce((s, e) => s + e.gross, 0) === 15000 && eA2.every((e) => e.beneficiary_amount + e.institution_amount + e.platform_amount === e.gross));
  await as(M);
  check('A4 l administrateur change la regle (historique conserve)', (await q(`select money_split_set(60, 25, 15, 'essai G4') r`))[0].r === '60/25/15');
  const oA3 = await newOrder(B, [[lampF, 'Lampe fine', 1001, 1]]);
  const eA3 = (await entries(oA3.id))[0];
  check('A5 regle 60/25/15 appliquee en entiers : 600 / 250 / reliquat 151 a la plateforme', eA3.beneficiary_amount === 600 && eA3.institution_amount === 250 && eA3.platform_amount === 151 && eA3.split === '60/25/15', JSON.stringify(eA3));
  await as(S1);
  let rev = (await q(`select seller_revenue() r`))[0].r;
  check('A6 seller_revenue expose la regle lue en base (rule_parts) et sa base de calcul', rev.rule === '60/25/15' && rev.rule_parts.beneficiary === 60 && rev.rule_parts.institution === 25 && rev.rule_parts.platform === 15 && /hors frais de livraison/.test(rev.rule_parts.base), JSON.stringify(rev.rule_parts));
  await as(M); await q(`select money_split_set(70, 20, 10, 'retour a la regle de depart')`);
  await as(S1);
  rev = (await q(`select seller_revenue() r`))[0].r;
  check('A7 apres retour a 70/20/10 la regle affichee suit la base', rev.rule === '70/20/10' && rev.rule_parts.beneficiary === 70);

  // ============================================================ B. deblocage : idempotence, gel d un vendeur suspendu, deblocage force
  const oB = await delivered(B, S1, [[lamp, 'Lampe', 10000, 1]]);
  await backdate(oB.id);
  await sup(); await db.exec(`update profiles set suspended = true where id = '${S1}'`);
  check('B1 vendeur suspendu : le cron ne debloque rien (l argent reste en sequestre)', (await autoRelease()) === 0 && (await entry(oB.id, S1)).status === 'held');
  await as(S1);
  rev = (await q(`select seller_revenue() r`))[0].r;
  check('B2 le vendeur voit « compte suspendu » comme raison du sequestre', rev.suspended === true && rev.holds.some((h) => h.reason === 'suspended'), JSON.stringify(rev.holds));
  await as(M);
  await fails('B3 deblocage force refuse pour un vendeur suspendu', `select money_release_now('${(await entry(oB.id, S1)).id}')`, /suspendu/);
  await sup(); await db.exec(`update profiles set suspended = false where id = '${S1}'`);
  const n0 = await nc(S1, 'Argent débloqué');
  check('B4 suspension levee : le cron libere', (await autoRelease()) >= 1 && (await entry(oB.id, S1)).status === 'released');
  check('B5 double passage du cron : rien de plus, une seule notification', (await autoRelease()) === 0 && (await nc(S1, 'Argent débloqué')) === n0 + 1);
  const oB2 = await delivered(B, S1, [[lamp, 'Lampe', 10000, 1]]);
  await as(B);
  const cB = (await q(`select submit_claim('${oB2.num}', 'damaged', 'La lampe est arrivee cassee et inutilisable') id`))[0].id;
  await as(M);
  const eB2 = await entry(oB2.id, S1);
  await fails('B6 deblocage force refuse pendant une reclamation', `select money_release_now('${eB2.id}')`, /réclamation/);
  await as(S1);
  await fails('B7 un vendeur ne force pas le deblocage', `select money_release_now('${eB2.id}')`, /Réservé/);
  await as(F);
  await fails('B8 la finance ne force pas le deblocage', `select money_release_now('${eB2.id}')`, /Réservé/);
  await as(SU);
  await q(`select claim_decide('${cB}', 'release', 'Reclamation non retenue, colis conforme')`);
  check('B9 reclamation rejetee : le sequestre suit son cours (confirmation ou garde)', (await entry(oB2.id, S1)).status === 'held');
  await as(M);
  await q(`select money_release_now('${eB2.id}')`);
  check('B10 deblocage force par l administrateur (hors reclamation) : libere et trace dans audit_log', (await entry(oB2.id, S1)).status === 'released' && (await qs(`select count(*)::int n from audit_log where action = 'Déblocage forcé du séquestre'`))[0].n === 1);
  await fails('B11 deblocage force rejoue : refuse (idempotent)', `select money_release_now('${eB2.id}')`, /introuvable/);
  await as(null, 'anon');
  await fails('B12 anonyme : aucun acces au deblocage force', `select money_release_now('${eB2.id}')`, /permission denied|Connexion/);

  // ============================================================ C. remboursements partiels et totaux
  const oC = await newOrder(B, [[lamp, 'Lampe', 10000, 1], [table, 'Table', 5000, 1]]);
  await as(B);
  const rC = (await q(`select order_refund_request('${oC.num}', 'Je souhaite un geste commercial partiel', null, null) id`))[0].id;
  check('C1 la demande porte le montant payable (15000)', (await qs(`select amount from order_refunds where id='${rC}'`))[0].amount === 15000);
  await as(S1);
  await fails('C2 un vendeur ne decide pas', `select order_refund_decide('${rC}', 'approve', 'ok', 1001)`, /Réservé/);
  await as(SU);
  await fails('C3 montant au-dela du paye refuse', `select order_refund_decide('${rC}', 'approve', 'Remboursement partiel accorde', 15001)`, /Montant invalide/);
  await fails('C4 montant nul refuse', `select order_refund_decide('${rC}', 'approve', 'Remboursement partiel accorde', 0)`, /Montant invalide/);
  await fails('C5 un remboursement partiel exige un motif', `select order_refund_decide('${rC}', 'approve', '', 1001)`, /motif/);
  check('C6 remboursement partiel de 1001 accepte', (await q(`select order_refund_decide('${rC}', 'approve', 'Remise commerciale accordee', 1001) r`))[0].r === 'approve');
  const eC = await entries(oC.id);
  const g1 = eC.find((e) => e.beneficiary_id === S1), g2 = eC.find((e) => e.beneficiary_id === S2);
  check('C7 reversement proportionnel au plus grand reste : 667 sur la vente de 10000, 334 sur celle de 5000', g1.gross === 10000 - 667 && g2.gross === 5000 - 334, `${g1.gross} ${g2.gross}`);
  check('C8 la somme des reductions = exactement 1001 (aucun FCFA cree ou perdu)', eC.reduce((s, e) => s + e.gross, 0) === 15000 - 1001);
  check('C9 chaque ligne reste equilibree (vendeur + fonds + plateforme = brut)', eC.every((e) => e.beneficiary_amount + e.institution_amount + e.platform_amount === e.gross));
  check('C10 la part du vendeur baisse au prorata (7000 -> 6533 environ), pas plus que sa ligne', g1.beneficiary_amount === Math.floor(7000 * g1.gross / 10000) && g1.beneficiary_amount < 7000);
  const oc = (await qs(`select cancelled_at, (select kind from order_refunds where id='${rC}') k, (select amount from order_refunds where id='${rC}') a from orders where id='${oC.id}'`))[0];
  check('C11 la commande n est PAS annulee ; demande « partial » de 1001', oc.cancelled_at === null && oc.k === 'partial' && oc.a === 1001);
  check('C12 vendeurs prevenus du remboursement partiel, finance prevenue du versement', (await nc(S1, 'Remboursement partiel accordé')) + (await nc(S1, 'Remboursement partiel')) >= 1 && (await nc(F, 'Remboursement à verser')) === 1);
  await as(SU);
  await fails('C13 double decision : refusee', `select order_refund_decide('${rC}', 'approve', 'Remise commerciale accordee', 1001)`, /déjà traitée/);
  await as(B);
  await fails('C14 pas de seconde demande tant que la premiere n est pas versee', `select order_refund_request('${oC.num}', 'Je demande un autre remboursement', null, null)`, /déjà en cours/);
  await as(SU);
  await fails('C15 le support n inscrit pas le versement', `select order_refund_set_paid('${rC}', 'OM-REF-1')`, /Réservé/);
  await as(F);
  check('C16 la finance inscrit le remboursement partiel verse', (await q(`select order_refund_set_paid('${rC}', 'OM-REF-1') r`))[0].r === 'refunded');
  await fails('C17 inscrit une seule fois (pas de double remboursement)', `select order_refund_set_paid('${rC}', 'OM-REF-2')`, /introuvable/);
  await as(B);
  const rC2 = (await q(`select order_refund_request('${oC.num}', 'Finalement j annule toute la commande', null, null) id`))[0].id;
  check('C18 une demande totale ulterieure ne rembourse que le reste (15000 - 1001)', (await qs(`select amount from order_refunds where id='${rC2}'`))[0].amount === 15000 - 1001);
  await as(SU);
  check('C19 remboursement total : commande annulee, sequestre restant « refunded »', (await q(`select order_refund_decide('${rC2}', 'approve', 'Annulation acceptee') r`))[0].r === 'approve'
    && (await qs(`select count(*)::int n from money_entries where order_id='${oC.id}' and status = 'refunded'`))[0].n === 2);
  await as(B);
  await fails('C20 plus rien a rembourser une fois la commande annulee', `select order_refund_request('${oC.num}', 'Encore une demande de remboursement', null, null)`, /annulée/);
  check('C21 audit_log : decisions de remboursement tracees', (await qs(`select count(*)::int n from audit_log where action in ('Remboursement partiel accepté', 'Remboursement accepté', 'Remboursement versé')`))[0].n >= 3);

  // reclamation : decision partielle
  const oD = await delivered(B, S2, [[table, 'Table', 5000, 2]]);
  await as(B);
  const cD = (await q(`select submit_claim('${oD.num}', 'damaged', 'Un des deux plateaux est raye et abime') id`))[0].id;
  await as(SU);
  await fails('C22 montant superieur au paye refuse dans une decision de reclamation', `select claim_decide('${cD}', 'refund', 'Un plateau abime', 10001)`, /Montant invalide/);
  await fails('C23 un montant n a de sens que pour un remboursement', `select claim_decide('${cD}', 'release', 'Non retenue', 1000)`, /remboursement/);
  check('C24 decision « refund » partielle de 3000', (await q(`select claim_decide('${cD}', 'refund', 'Un plateau abime, remboursement partiel', 3000) r`))[0].r === 'refund');
  const eD = await entry(oD.id, S2);
  check('C25 reduction proportionnelle (7000 -> 7000 * 7000 / 10000 = 4900) et commande non annulee', eD.gross === 7000 && eD.beneficiary_amount === 4900 && (await qs(`select cancelled_at from orders where id='${oD.id}'`))[0].cancelled_at === null, JSON.stringify(eD));
  check('C26 la finance est prevenue du remboursement issu de la reclamation', (await nc(F, 'Remboursement à verser')) === 3);
  await sup();
  const rD = (await q(`select id from order_refunds where claim_id='${cD}'`))[0];
  check('C27 la demande issue de la reclamation est « approved » partielle', (await q(`select kind, status, amount from order_refunds where id='${rD.id}'`))[0].kind === 'partial');

  // argent deja debloque et verse : solde negatif compense
  const oE = await released(B, S3, [[chair, 'Chaise', 1000, 5]]);
  await sup(); await db.exec(`update profiles set phone_verified = true, certification = 'approved' where id in ('${S1}', '${S2}', '${S3}')`);
  await as(S3);
  await q(`select save_payment_method('mtn_momo', '677000111', true)`);
  await sup(); await db.exec(`update payment_methods set created_at = now() - interval '30 hours' where owner_id = '${S3}'`);
  await as(S3);
  const avE = (await q(`select my_money() r`))[0].r.available;
  check('E0 la vente de 5000 est disponible (3500)', avE === 3500, String(avE));
  const pE = (await q(`select request_seller_payout(3500) id`))[0].id;
  await as(F);
  await q(`select payout_set_status('${pE}', 'verse', 'MTN-ABC')`);
  await as(B);
  const cE = (await q(`select submit_claim('${oE.num}', 'damaged', 'Produit defectueux apres confirmation de reception') id`))[0].id;
  await as(SU);
  await q(`select claim_decide('${cE}', 'refund', 'Remboursement integral accepte apres versement')`);
  const wE2 = await wallet(S3);
  check('E1 remboursement d une vente deja versee : solde disponible 0 et deficit de 3500 expose', wE2.available === 0 && wE2.deficit === 3500, JSON.stringify(wE2));
  check('E2 le vendeur et la finance sont prevenus du solde a compenser', (await nc(S3, 'Solde à compenser')) === 1 && (await nc(F, 'Montant versé à récupérer')) === 1);
  const oE2 = await released(B, S3, [[chair, 'Chaise', 1000, 10]]);
  const wE3 = await wallet(S3);
  check('E3 le deficit se compense sur le deblocage suivant : 7000 - 3500 = 3500 disponibles', wE3.available === 3500 && wE3.deficit === 0, JSON.stringify(wE3));

  // ============================================================ D. retraits securises
  await sup(); await db.exec(`update profiles set phone_verified = true where id in ('${S1}', '${S2}')`);
  await released(B, S1, [[lamp, 'Lampe', 10000, 1]]);
  await as(X);
  await fails('D1 compte etudiant sans pouvoir ni solde : telephone non verifie refuse', `select request_seller_payout(2000)`, /téléphone vérifié/);
  await sup(); await db.exec(`update profiles set phone_verified = true where id = '${X}'`);
  await as(X);
  await fails('D2 etudiant NON verifie (ni piece ni certification) : retrait refuse', `select request_seller_payout(2000)`, /statut d'étudiant n'est pas vérifié/);
  await as(B);
  await fails('D3 client sans telephone verifie : refuse',   `select request_seller_payout(2000)`, /téléphone vérifié|réservés aux comptes étudiants/);
  await sup(); await db.exec(`update profiles set phone_verified = true where id in ('${B}', '${CO}', '${D}')`);
  await as(B);
  await fails('D4 client avec telephone verifie mais sans solde : refuse (aucun pouvoir cree)', `select request_seller_payout(2000)`, /Enregistrez d'abord|solde disponible|réservés aux comptes étudiants/);
  await as(D);
  await fails('D5 departement : meme refus', `select request_seller_payout(2000)`, /Enregistrez d'abord|solde disponible|réservés aux comptes étudiants/);
  await as(null, 'anon');
  await fails('D6 anonyme : aucun acces', `select request_seller_payout(2000)`, /permission denied|Connexion/);
  await as(S1);
  const nBefore = await nc(S1, 'Nouveau numéro de paiement');
  await q(`select save_payment_method('orange_money', '691234567', true)`);
  check('D7 un nouveau numero est signale au titulaire (notification) et trace', (await nc(S1, 'Nouveau numéro de paiement')) === nBefore + 1 && (await qs(`select count(*)::int n from audit_log where action = 'Numéro de paiement ajouté'`))[0].n >= 1);
  await q(`select save_payment_method('orange_money', '691234567', true)`);
  check('D8 re-enregistrer le meme numero ne declenche pas une seconde alerte', (await nc(S1, 'Nouveau numéro de paiement')) === nBefore + 1);
  let po = (await q(`select my_payouts() r`))[0].r;
  check('D9 my_payouts : delai de securite, numero non encore utilisable, aucun blocage de compte', po.delay_hours === 24 && po.methods[0].usable === false && po.blocker === null && po.min === 1000 && po.max === 500000);
  await fails('D10 delai de securite : numero tout juste enregistre refuse', `select request_seller_payout(2000)`, /vient d'être enregistré/);
  await as(F);
  await fails('D11 la finance ne verse pas non plus sur un numero tout neuf', `select payout_create('${S1}', 1000)`, /délai de sécurité/);
  await sup(); await db.exec(`update payment_methods set created_at = now() - interval '25 hours' where owner_id = '${S1}'`);
  await as(S1);
  po = (await q(`select my_payouts() r`))[0].r;
  check('D12 apres 25 h le numero est utilisable', po.methods[0].usable === true);
  await sup(); await db.exec(`insert into platform_settings (key, value) values ('payouts.number_delay_hours', '48'::jsonb) on conflict (key) do update set value = excluded.value`);
  await as(S1);
  await fails('D13 le delai est un reglage : porte a 48 h, le numero de 25 h est de nouveau refuse', `select request_seller_payout(2000)`, /vient d'être enregistré/);
  await sup(); await db.exec(`delete from platform_settings where key = 'payouts.number_delay_hours'`);
  await as(S1);
  const w0 = await wallet(S1);
  await fails('D14 retrait superieur au solde : refuse', `select request_seller_payout(${w0.available + 1})`, /solde disponible/);
  await fails('D15 retrait sous le minimum existant : refuse', `select request_seller_payout(999)`, /minimum/);
  const pId = (await q(`select request_seller_payout(2000) id`))[0].id;
  check('D16 retrait accepte : le montant demande est exactement celui reserve (aucun frais invente)', (await wallet(S1)).requested === 2000 && (await qs(`select amount from payout_batches where id='${pId}'`))[0].amount === 2000);
  await fails('D17 une seule demande en cours (double retrait)', `select request_seller_payout(1000)`, /déjà en cours/);
  await sup(); await db.exec(`update profiles set suspended = true where id = '${S1}'`);
  await as(F);
  await fails('D18 compte suspendu : la finance ne passe pas la demande a « prevu »', `select payout_set_status('${pId}', 'prevu')`, /suspendu/);
  await fails('D19 ni a « verse »', `select payout_set_status('${pId}', 'verse', 'OM-1')`, /suspendu/);
  await fails('D20 ni versement manuel', `select payout_create('${S1}', 1000)`, /suspendu/);
  await q(`select payout_set_status('${pId}', 'rejete', null, 'Compte suspendu, retrait gele')`);
  check('D21 un rejet reste possible : le montant redevient disponible', (await qs(`select status from payout_batches where id='${pId}'`))[0].status === 'rejete');
  await as(S1);
  await fails('D22 compte suspendu : plus de nouvelle demande', `select request_seller_payout(1000)`, /Compte inactif|suspendu/);
  await sup(); await db.exec(`update profiles set suspended = false where id = '${S1}'`);
  await as(S1);
  const pId2 = (await q(`select request_seller_payout(1500) id`))[0].id;
  check('D23 suspension levee : le vendeur peut redemander', !!pId2);
  check('D24 annulation par le vendeur tracee dans audit_log', (await q(`select payout_cancel_request('${pId2}') r`))[0].r === 'cancelled' && (await qs(`select count(*)::int n from audit_log where action = 'Demande de retrait annulée'`))[0].n === 1);
  await as(S2);
  await fails('D25 un autre vendeur ne peut pas annuler', `select payout_cancel_request('${pId2}')`, /introuvable|déjà traitée/);
  await as(SU);
  await fails('D26 le support ne traite pas les retraits', `select payout_set_status('${pId}', 'verse', 'x')`, /non autorisée/);
  await as(CO);
  await fails('D27 entreprise : pas de versement', `select payout_create('${S1}', 1000)`, /non autorisée/);
  await as(D);
  await fails('D28 departement : pas de versement', `select payout_create('${S1}', 1000)`, /non autorisée/);
  await as(null, 'anon');
  await fails('D29 anonyme : pas de versement', `select payout_create('${S1}', 1000)`, /permission denied|Connexion/);
  await as(F);
  const p3 = (await q(`select payout_create('${S1}', 1000) id`))[0].id;
  await q(`select payout_set_status('${p3}', 'verse', 'OM-OK')`);
  check('D30 versement par la finance : cree puis verse avec reference (flux existant)', (await qs(`select status, phone from payout_batches where id='${p3}'`))[0].phone === '691234567');
  await fails('D31 un versement effectue ne se rejoue pas', `select payout_set_status('${p3}', 'verse', 'OM-OK2')`, /Transition impossible/);

  // ============================================================ F. visibilite de chaque acteur
  await as(S2);
  let blocked = false;
  try { await q(`select count(*) from money_entries`); } catch (e) { blocked = /permission denied/.test(e.message); }
  check('F2 money_entries : lecture directe interdite a l etudiant', blocked);
  await as(B);
  blocked = false;
  try { await q(`select count(*) from payout_batches where seller_id = '${S1}'`).then((r) => { blocked = Number(r[0].count) === 0; }); } catch (e) { blocked = true; }
  check('F3 un client ne voit aucun retrait d un vendeur', blocked);
  await as(F);
  check('F4 la finance voit la file des retraits avec numero et solde', (await q(`select finance_payouts(20) r`))[0].r.length >= 2);

  console.log(`\nG4 : ${ok} OK, ${ko} ECHEC`);
}

