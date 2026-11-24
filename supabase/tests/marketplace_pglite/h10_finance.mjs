// Lot H10 (FIN) : état RÉEL de rapprochement du journal financier (migration 20261126010000).
// Prouve que :
//   A. sans preuve, un encaissement ou un versement est « à rapprocher » (plus de « rapproché » automatique) ; les compteurs serveur sont exacts et indépendants de la limite ;
//   B. les preuves serveur existantes sont reconnues : événement signé confirmé (payment_events), paiement confirmé par la finance (payment_transactions), versement versé avec référence ;
//      un événement non confirmé, une référence inconnue ou un paiement seulement déclaré ne prouvent rien ;
//   C. l'action explicite finance_reconcile_record : permission finance.payments / finance.payouts, 2FA (aal2), refus de tous les cas invalides, rejeu sans doublon, audit ;
//   D. isolement : anonyme, client, étudiant, support, finance sans la permission, lecture directe de la table et de la vue refusées ;
//   E. aucun montant, aucune écriture de séquestre ni de versement n'est modifié ; rejeu de la migration sans effet de bord.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h10_finance.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const dir = path.dirname(fileURLToPath(import.meta.url));
  const mig = (f) => fs.readFileSync(path.join(dir, '..', '..', 'migrations', f), 'utf8');
  const id = (n) => `00000000-0000-0000-0000-0000000101${String(n).padStart(2, '0')}`;
  const A = id(1), F = id(2), FR = id(3), FP = id(4), SU = id(5), S = id(6), B = id(7), B2 = id(8), M2 = id(9), ST = id(10);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const asAal = async (uid, aal) => { cur = { uid, role: 'authenticated' }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false); set role authenticated`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const rec = (kind, ref, pref, src = 'releve_prestataire', date = 'current_date', note = null) =>
    `select finance_reconcile_record('${kind}', '${ref}', ${pref === null ? 'null' : `'${pref}'`}, '${src}', ${date === null ? 'null' : date.startsWith('current') ? date : `'${date}'`}, ${note === null ? 'null' : `'${note}'`}) r`;
  const journal = async (n = 300) => (await q(`select finance_journal(${n}) r`))[0].r;
  const rowOf = (j, label) => j.rows.find((x) => x.label === label);
  const DENY = /Action non autorisée|Connexion requise|permission denied|double authentification/i;

  await db.exec('reset role');
  for (const [i, nm, role] of [[A, 'Ada Admin', 'admin'], [F, 'Fin Finance', 'finance'], [FR, 'Read Finance', 'finance'], [FP, 'Pay Finance', 'finance'], [SU, 'Sam Support', 'support'],
    [S, 'Awa Vendeuse', 'student'], [B, 'Cora Cliente', 'client'], [B2, 'Cyril Client', 'client'], [M2, 'Mfa Finance', 'finance'], [ST, 'Etu Etudiant', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`update profiles set phone_verified = true where id = '${S}'; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${S}', 'student_card', 'c.pdf', '${S}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments'] where user_id = '${F}' and team_code = 'finance'`);
  await db.exec(`update admin_team_members set permissions = array['finance.read'] where user_id = '${FR}' and team_code = 'finance'`);
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payouts'] where user_id = '${FP}' and team_code = 'finance'`);
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts'] where user_id = '${M2}' and team_code = 'finance'`);
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${M2}', 'verified')`);
  await db.exec(`insert into listings (seller_id,title,department,category,price,stock,status,images) values ('${S}','Lampe','Design','Maison',10000,50,'approved','{}')`);
  const lamp = (await q(`select id from listings where title='Lampe'`))[0].id;
  let seq = 0;
  const newOrder = async (price = 10000, o = {}) => {
    await sup();
    const num = `#BE-2026-${String(9100 + ++seq)}`;
    const ref = o.ref === undefined ? `NP-REF-${seq}` : o.ref;
    const oid = (await q(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid, reference, cod) values ('${num}', '${B}', ${price}, ${o.fee ?? 0}, 'Mobile Money', 0, false, ${ref === null ? 'null' : `'${ref}'`}, ${!!o.cod}) returning id`))[0].id;
    await db.exec(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${lamp}', 'Lampe', ${price}, 1)`);
    if (o.paid !== false) await db.exec(`update orders set paid = true where id = '${oid}'`);
    return { id: oid, num, ref };
  };
  const event = async (ref, outcome, eid) => { await sup(); await db.exec(`insert into payment_events (id, event_type, reference, outcome) values ('${eid ?? `ev-${ref}-${outcome}`}', 'payment.complete', '${ref}', ${outcome === null ? 'null' : `'${outcome}'`})`); };
  const payout = async (num, status, ref, amount = 5000) => { await sup(); return (await q(`insert into payout_batches (number, seller_id, amount, status, paid_on, reference, decided_by, decided_at) values ('${num}', '${S}', ${amount}, '${status}', ${status === 'verse' ? 'current_date' : 'null'}, ${ref === null ? 'null' : `'${ref}'`}, ${ref === null ? 'null' : `'${F}'`}, ${ref === null ? 'null' : 'now()'}) returning id`))[0].id; };
  const snapshot = async () => (await qs(`select jsonb_build_object(
      'money', (select coalesce(jsonb_agg(to_jsonb(m) - 'created_at' order by m.id), '[]') from money_entries m),
      'orders', (select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'subtotal', o.subtotal, 'fee', o.fee, 'paid', o.paid) order by o.id), '[]') from orders o),
      'payouts', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'amount', p.amount, 'status', p.status) order by p.id), '[]') from payout_batches p),
      'rules', (select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]') from money_split_rules r)) r`))[0].r;

  // ============================================================ A. sans preuve : « à rapprocher »
  const o1 = await newOrder(10000, { fee: 1500 });
  const o2 = await newOrder(20000);
  const o3 = await newOrder(30000);
  const ocod = await newOrder(5000, { cod: true, ref: null });
  const ounpaid = await newOrder(7000, { paid: false });
  const p1 = await payout('RV-T1', 'verse', null);
  const p2 = await payout('RV-T2', 'prevu', null);
  await as(F);
  const j0 = await journal();
  check('A1 encaissement sans preuve : reconciled = false (le « toujours rapproché » est supprimé)', rowOf(j0, `Encaissement ${o1.num}`)?.reconciled === false && rowOf(j0, `Encaissement ${o2.num}`)?.reconciled === false, JSON.stringify(rowOf(j0, `Encaissement ${o1.num}`)));
  check('A2 « Dont frais de livraison » sans preuve : à rapprocher aussi', rowOf(j0, `Dont frais de livraison ${o1.num}`)?.reconciled === false);
  check('A3 versement versé sans référence : à rapprocher ; versement prévu : à rapprocher', rowOf(j0, 'Reversement RV-T1')?.reconciled === false && rowOf(j0, 'Reversement RV-T2')?.reconciled === false);
  check('A4 commande non payée absente du journal', !j0.rows.some((x) => x.ref === ounpaid.num));
  check('A5 compteurs serveur : reconciled + to_reconcile = total_rows, rien de rapproché', j0.reconciled === 0 && j0.to_reconcile === j0.total_rows && j0.total_rows === 7, JSON.stringify({ r: j0.reconciled, t: j0.to_reconcile, n: j0.total_rows }));
  const jl = await journal(2);
  check('A6 les compteurs portent sur toutes les lignes, pas sur la limite', jl.rows.length === 2 && jl.total_rows === 7 && jl.to_reconcile === 7);
  check('A7 chaque ligne indique son type et sa référence (kind, ref) et aucune preuve', rowOf(j0, `Encaissement ${o2.num}`)?.kind === 'order' && rowOf(j0, `Encaissement ${o2.num}`)?.ref === o2.num && rowOf(j0, `Encaissement ${o2.num}`)?.proof === null && rowOf(j0, 'Reversement RV-T1')?.kind === 'payout');
  const fp0 = (await q(`select finance_payments(null, 50) r`))[0].r;
  check('A8 finance_payments : commande vérifiée sans preuve = reconciled false', fp0.find((x) => x.order === o1.num)?.state === 'verified' && fp0.find((x) => x.order === o1.num)?.reconciled === false);
  check('A9 finance_payments : commande non payée = à vérifier, non rapprochée', fp0.find((x) => x.order === ounpaid.num)?.state === 'to_verify' && fp0.find((x) => x.order === ounpaid.num)?.reconciled === false);
  const credit0 = j0.total_credit, debit0 = j0.total_debit;

  // ============================================================ B. preuves serveur existantes
  await event(o1.ref, 'confirmed');
  await event(o2.ref, 'underpaid');
  await event(o3.ref, null);
  await event('NP-REF-INCONNUE', 'confirmed');
  await event(ocod.num, 'confirmed', 'ev-cod');
  await as(F);
  const j1 = await journal();
  const r1 = rowOf(j1, `Encaissement ${o1.num}`);
  check('B1 événement signé « confirmed » : encaissement rapproché avec source, référence et date', r1.reconciled === true && r1.proof?.source === 'webhook_prestataire' && r1.proof?.reference === o1.ref && !!r1.proof?.date && r1.proof?.author === null, JSON.stringify(r1));
  check('B2 la ligne « Dont frais de livraison » de la même commande est rapprochée avec elle', rowOf(j1, `Dont frais de livraison ${o1.num}`)?.reconciled === true);
  check('B3 événement non confirmé (underpaid) ou sans issue : rien n\'est prouvé', rowOf(j1, `Encaissement ${o2.num}`).reconciled === false && rowOf(j1, `Encaissement ${o3.num}`).reconciled === false);
  check('B4 événement confirmé sur une référence inconnue : aucune commande rapprochée à tort', j1.reconciled === 2 && !j1.rows.some((x) => x.ref === ocod.num && x.reconciled));
  check('B5 compteurs mis à jour (2 rapprochées dont la ligne de livraison, 5 à rapprocher)', j1.reconciled === 2 && j1.to_reconcile === 5 && j1.reconciled + j1.to_reconcile === j1.total_rows, JSON.stringify({ r: j1.reconciled, t: j1.to_reconcile }));
  const fp1 = (await q(`select finance_payments(null, 50) r`))[0].r;
  check('B6 finance_payments : la commande prouvée est rapprochée (source)', fp1.find((x) => x.order === o1.num)?.reconciled === true && fp1.find((x) => x.order === o1.num)?.proof_source === 'webhook_prestataire');

  // paiement déclaré puis confirmé par la finance (payment_transactions)
  const o4 = await newOrder(12000, { paid: false, ref: null });
  await as(B);
  const tx = (await q(`select payment_start('order', 'Commande ${o4.num}', 12000, 'manual') id`))[0].id;
  await q(`select payment_declare('${tx}', 'OM-DECL-7788')`);
  await sup(); await db.exec(`update orders set paid = true where id = '${o4.id}'`);
  await as(F);
  check('B7 paiement seulement déclaré (non confirmé par la finance) : pas de preuve', rowOf(await journal(), `Encaissement ${o4.num}`)?.reconciled === false);
  await sup(); await db.exec(`update orders set paid = false where id = '${o4.id}'`);
  await as(F);
  await q(`select payment_set_status('${tx}', 'confirmed', 'vérifié sur le relevé')`);
  await as(F);
  const r4 = rowOf(await journal(), `Encaissement ${o4.num}`);
  check('B8 paiement confirmé par la finance : rapproché, source confirmation_finance, référence du payeur, auteur journalisé', r4?.reconciled === true && r4.proof?.source === 'confirmation_finance' && r4.proof?.reference === 'OM-DECL-7788' && r4.proof?.author === 'Fin Finance', JSON.stringify(r4));

  // versements
  const p3 = await payout('RV-T3', 'verse', 'OM-PAY-4411');
  const p4 = await payout('RV-T4', 'prevu', 'OM-PAY-0000');
  await as(F);
  const j2 = await journal();
  check('B9 versement versé avec référence de l\'opérateur : rapproché (source versement_finance)', rowOf(j2, 'Reversement RV-T3')?.reconciled === true && rowOf(j2, 'Reversement RV-T3')?.proof?.source === 'versement_finance');
  check('B10 versement seulement prévu (même avec une référence) : à rapprocher', rowOf(j2, 'Reversement RV-T4')?.reconciled === false);

  // ============================================================ C. action explicite
  const o6 = await newOrder(4000);
  await sup(); await db.exec(`update orders set cancelled_at = now() where id = '${o6.id}'`);
  const before = await snapshot();
  await as(F);
  const jC = await journal();
  const auditN = async () => (await qs(`select count(*)::int n from audit_log where action like 'Rapprochement enregistré%'`))[0].n;
  const a0 = await auditN();
  await as(F);
  await fails('C1 sans 2FA : un compte sans facteur peut agir, mais pas sur une écriture inexistante', rec('order', '#BE-0000-0', 'REL-0001'), /introuvable ou non encaissée/);
  const c1 = (await q(rec('order', o2.num, 'REL-2026-0002', 'releve_prestataire', 'current_date', 'relevé Notch Pay du jour')))[0].r;
  check('C2 finance.payments : preuve enregistrée (state recorded)', c1.state === 'recorded' && c1.reference === 'REL-2026-0002');
  const rc = rowOf(await journal(), `Encaissement ${o2.num}`);
  check('C3 la ligne devient rapprochée avec source, référence, date et auteur', rc.reconciled === true && rc.proof.source === 'releve_prestataire' && rc.proof.reference === 'REL-2026-0002' && rc.proof.author === 'Fin Finance', JSON.stringify(rc));
  check('C4 audit : une ligne « Rapprochement enregistré » par preuve, au nom de l\'auteur', (await auditN()) === a0 + 1 && (await qs(`select count(*)::int n from audit_log where action like 'Rapprochement enregistré%' and actor_id = '${F}' and category = 'Finance' and level = 'Sensible' and target like '%REL-2026-0002%'`))[0].n === 1);
  await as(F);
  const c2 = (await q(rec('order', o2.num, 'rel-2026-0002')))[0].r;
  check('C5 rejeu (même référence, casse différente) : state already, aucune écriture ni audit supplémentaire', c2.state === 'already' && (await auditN()) === a0 + 1 && (await qs(`select count(*)::int n from finance_reconciliation_proofs where order_id = '${o2.id}'`))[0].n === 1);
  await fails('C6 écriture déjà rapprochée avec une autre référence : refusé', rec('order', o2.num, 'REL-AUTRE-0099'), /déjà rapprochée/);
  await fails('C7 référence déjà utilisée pour une autre commande : refusé', rec('order', o3.num, 'REL-2026-0002'), /déjà utilisée/);
  await fails('C8 une référence déjà prouvée par le prestataire ne peut pas être réutilisée', rec('order', o3.num, o1.ref), /déjà utilisée/);
  await fails('C9 référence absente', rec('order', o3.num, null), /Référence du prestataire invalide/);
  await fails('C10 référence trop courte', rec('order', o3.num, 'ab'), /Référence du prestataire invalide/);
  await fails('C11 source de preuve invalide', rec('order', o3.num, 'REL-0003', 'oral'), /Source de preuve invalide/);
  await fails('C12 date dans le futur', rec('order', o3.num, 'REL-0003', 'releve_prestataire', '2099-01-01'), /Date de preuve invalide/);
  await fails('C13 date absente', rec('order', o3.num, 'REL-0003', 'releve_prestataire', null), /Date de preuve invalide/);
  await fails('C14 type d\'écriture invalide', rec('refund', o3.num, 'REL-0003'), /Type d'écriture invalide/);
  await fails('C15 commande non encaissée', rec('order', ounpaid.num, 'REL-0004'), /introuvable ou non encaissée/);
  await fails('C16 commande annulée', rec('order', o6.num, 'REL-0005'), /introuvable ou non encaissée/);
  const cc = (await q(rec('order', ocod.num, 'CAISSE-2026-11-21', 'remise_caisse')))[0].r;
  check('C17 paiement à la livraison : remise en caisse enregistrée', cc.state === 'recorded' && rowOf(await journal(), `Encaissement ${ocod.num}`)?.proof?.source === 'remise_caisse');
  await fails('C19 finance avec finance.payments sans finance.payouts : versement refusé', rec('payout', 'RV-T1', 'OM-PAY-2000'), /Action non autorisée/);
  await as(FP);
  await fails('C20 finance.payouts sans finance.payments : encaissement refusé', rec('order', o3.num, 'REL-0006'), /Action non autorisée/);
  await fails('C18 versement non versé (prévu) : refusé', rec('payout', 'RV-T2', 'OM-PAY-1000'), /introuvable ou non versé/);
  const cp = (await q(rec('payout', 'RV-T1', 'OM-PAY-2000', 'recu_operateur')))[0].r;
  check('C21 finance.payouts : versement rapproché', cp.state === 'recorded' && rowOf(await journal(), 'Reversement RV-T1')?.proof?.source === 'recu_operateur');
  await as(A);
  const ca = (await q(rec('order', o3.num, 'REL-ADMIN-0003', 'releve_prestataire')))[0].r;
  check('C22 administrateur : action autorisée', ca.state === 'recorded');
  const jf = await journal();
  check('C24 il ne reste à rapprocher que le versement prévu (RV-T2) et le versement RV-T4', jf.to_reconcile === 2 && jf.rows.filter((x) => !x.reconciled).map((x) => x.ref).sort().join() === 'RV-T2,RV-T4', JSON.stringify(jf.rows.filter((x) => !x.reconciled).map((x) => x.ref)));
  await sup();
  const after = await snapshot();
  check('C25 aucun montant, séquestre, versement ni règle n\'a changé (comparaison avant / après)', JSON.stringify(before) === JSON.stringify(after));
  check('C26 totaux crédit / débit du journal inchangés par le rapprochement', jf.total_credit === jC.total_credit && jf.total_debit === jC.total_debit && jf.total_rows === jC.total_rows && jf.reconciled + jf.to_reconcile === jf.total_rows);

  // ============================================================ D. droits et isolement
  const o5 = await newOrder(9000);
  for (const [lab, uid] of [['anonyme', null], ['client', B], ['étudiant', ST], ['vendeuse', S], ['support', SU]]) {
    if (uid === null) await as(null, 'anon'); else await as(uid);
    await fails(`D1 ${lab} : finance_reconcile_record refusé`, rec('order', o5.num, 'REL-HACK-1'), /Action non autorisée|Connexion requise|permission denied/);
    await fails(`D2 ${lab} : finance_journal refusé`, 'select finance_journal(10)', /Action non autorisée|Connexion requise|permission denied/);
    await fails(`D3 ${lab} : finance_payments refusé`, 'select finance_payments(null, 10)', /Action non autorisée|Connexion requise|permission denied/);
  }
  await as(FR);
  await fails('D4 finance.read seule : lecture autorisée mais enregistrement refusé', rec('order', o5.num, 'REL-HACK-2'), /Action non autorisée/);
  await works('D5 finance.read seule : lecture du journal autorisée', 'select finance_journal(10) r');
  await as(B);
  await fails('D6 client : lecture directe de la table des preuves refusée', 'select * from finance_reconciliation_proofs', /permission denied/);
  await fails('D7 client : lecture directe de la vue des preuves refusée', 'select * from finance_entry_proofs', /permission denied/);
  await fails('D8 client : insertion directe refusée', `insert into finance_reconciliation_proofs (kind, order_id, provider_reference, source, proof_date) values ('order', '${o5.id}', 'HACK-0001', 'releve_prestataire', current_date)`, /permission denied/);
  await as(F);
  await fails('D9 même la finance ne lit ni n\'écrit la table directement', 'select * from finance_reconciliation_proofs', /permission denied/);
  await sup(); await db.exec(`update profiles set suspended = true where id = '${F}'`); await as(F);
  await fails('D10 compte finance suspendu : enregistrement refusé', rec('order', o5.num, 'REL-HACK-3'), /Action non autorisée/);
  await sup(); await db.exec(`update profiles set suspended = false where id = '${F}'`);

  // ============================================================ E. 2FA
  await asAal(M2, 'aal1');
  await fails('E1 compte avec 2FA vérifiée en aal1 : refusé (garde interne)', rec('order', o5.num, 'REL-2FA-0001'), /double authentification/);
  check('E2 rien n\'a été enregistré par le refus', (await qs(`select count(*)::int n from finance_reconciliation_proofs where order_id = '${o5.id}'`))[0].n === 0);
  await asAal(M2, 'aal2');
  const e3 = (await q(rec('order', o5.num, 'REL-2FA-0001')))[0].r;
  check('E3 en aal2 : accepté', e3.state === 'recorded');
  const guard = async (p, uid, aal) => {
    const save = cur; await sup();
    await db.exec(`select set_config('request.path', '${p}', false), set_config('request.method', 'POST', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false)`);
    let r = 'ok'; try { await db.exec('select enforce_mfa_on_sensitive()'); } catch (e) { r = e.message; }
    if (save) await as(save.uid, save.role);
    return r;
  };
  check('E4 garde API : /rpc/finance_reconcile_record exige aal2 pour un compte avec 2FA', /double authentification/.test(await guard('/rpc/finance_reconcile_record', M2, 'aal1')) && (await guard('/rpc/finance_reconcile_record', M2, 'aal2')) === 'ok');
  check('E5 garde API : compte sans 2FA inchangé', (await guard('/rpc/finance_reconcile_record', F, 'aal1')) === 'ok');
  let kept = 0; const OLD = ['payment_set_status', 'payout_create', 'payout_set_status', 'money_release_now', 'money_freeze', 'money_split_set', 'claim_decide', 'admin_mfa_reset', 'finance_overview_x'];
  for (const op of OLD.slice(0, 8)) if (/double authentification/.test(await guard('/rpc/' + op, M2, 'aal1'))) kept++;
  check('E6 aucune opération déjà protégée n\'a été retirée de la garde 2FA', kept === 8, `${kept}/8`);
  check('E7 un chemin voisin n\'est pas capturé', (await guard('/rpc/finance_reconcile_record_x', M2, 'aal1')) === 'ok');

  // ============================================================ F. rejeu de la migration
  await as(A);
  const jBefore = JSON.stringify(await journal());
  await sup();
  await db.exec(mig('20261126010000_h10_fin_rapprochement_reel.sql'));
  await db.exec(mig('20261126010000_h10_fin_rapprochement_reel.sql'));
  await as(A);
  check('F1 rejeu de la migration (deux fois) : journal et preuves inchangés', JSON.stringify(await journal()) === jBefore);
  const listOnce = (await qs(`select pg_get_functiondef(p.oid) d from pg_proc p where p.proname = 'enforce_mfa_on_sensitive'`))[0].d;
  check('F2 rejeu : finance_reconcile_record n\'apparaît qu\'une fois dans la garde 2FA', (listOnce.match(/finance_reconcile_record/g) || []).length === 1);
  check('F3 rejeu : aucune preuve dupliquée', (await qs(`select count(*)::int n from (select order_id from finance_reconciliation_proofs where order_id is not null group by 1 having count(*) > 1) x`))[0].n === 0);

  console.log(`\nh10_finance : ${ok} OK / ${ko} ECHEC`);
}
