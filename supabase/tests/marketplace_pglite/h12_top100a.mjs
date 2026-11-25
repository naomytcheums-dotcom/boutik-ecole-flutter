// Scénario PGlite du lot H12 / TOP100-A : référentiel des filières et rattachements (20261127010000), règles de score (20261127010100),
// moteur d'événements et de score (20261127010200), anti-fraude (20261127010300).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h12_top100a.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000130${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const qs = async (sql) => { await sup(); return q(sql); };
  const DENY = /permission denied|Connexion requise|Réservé|refusé|introuvable|périmètre|exige/i;

  await sup();
  // Aucun établissement, étudiant ni score n'existe avant les fixtures : les migrations seules n'insèrent rien.
  check('migrations seules : aucun programme', (await q(`select count(*)::int n from programs`))[0].n === 0);
  check('migrations seules : aucun rattachement', (await q(`select count(*)::int n from student_affiliations`))[0].n === 0);
  check('migrations seules : 13 règles en brouillon, toutes inactives à 0 point', (await q(`select count(*)::int n from talent_score_rules where not active and points = 0`))[0].n === 13);
  check('migrations seules : permissions ranking créées, sensibles', (await q(`select count(*)::int n from admin_permissions where code in ('institutions.manage','ranking.rules','ranking.publish','ranking.moderate') and sensitive`))[0].n === 4);

  // 1 admin ; 2 étudiant A ; 3 étudiant B ; 4 responsable d'établissement ; 5 client
  const roles = { 1: 'admin', 2: 'student', 3: 'student', 4: 'support', 5: 'client' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100a${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte T100 ${n}','${r}','t100a${n}@t.cm')`);
  }
  const I1 = '00000000-0000-0000-0000-00000013a001';
  const D1 = '00000000-0000-0000-0000-00000013a011';
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Établissement T100 A', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified')`);

  await as(U(1));
  const pr = (await q(`select admin_program_upsert(null, '${I1}', '${D1}', 'Génie logiciel', true) r`))[0].r;
  check('admin crée une filière', pr.ok === true && !!pr.id, JSON.stringify(pr));
  await as(U(2));
  await fails('étudiant : création de filière refusée', `select admin_program_upsert(null, '${I1}', '${D1}', 'Pirate', true)`, DENY);

  // ============================================================ MOTEUR D'ÉVÉNEMENTS ET DE SCORE (20261127010200)
  await sup();
  for (const [n, r] of Object.entries({ 6: 'student', 7: 'client', 8: 'student' })) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100a${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte T100 ${n}','${r}','t100a${n}@t.cm')`);
  }
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${U(4)}', 'ranking', array['ranking.moderate'])`);
  for (const n of [2, 3]) {
    await db.exec(`update profiles set phone = '69130' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
    await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${U(n)}'`);
  }
  const tot = async (u) => (await qs(`select coalesce((select total from talent_scores where user_id = '${u}'), 0)::int t`))[0].t;
  const led = async (u) => (await qs(`select coalesce(sum(points), 0)::int t from talent_score_ledger where user_id = '${u}'`))[0].t;
  const ev = async (u, rule) => (await qs(`select id, status, source_kind from talent_events where user_id = '${u}' and rule_code = '${rule}' order by id`));
  const evCount = async () => (await qs(`select count(*)::int n from talent_events`))[0].n;
  const rule = async (code, pts, capD, capP, w, active, why = 'Réglage de test du moteur de score') => { await as(U(1)); const r = await q(`select admin_talent_rule_set('${code}', ${pts}, ${capD}, ${capP}, ${w}, ${active}, '${why}') r`); await sup(); return r; };

  check('moteur : aucune activité, aucun registre, aucun score après migration seule', (await evCount()) === 0 && (await qs(`select count(*)::int n from talent_score_ledger`))[0].n === 0 && (await qs(`select count(*)::int n from talent_scores`))[0].n === 0);
  await db.exec(`insert into listings (id, seller_id, title, department, category, price, stock, status, images) values
    ('00000000-0000-0000-0000-00000013b001', '${U(2)}', 'Lampe T100 A', 'Design', 'Maison', 5000, 50, 'approved', '{p.jpg}'),
    ('00000000-0000-0000-0000-00000013b002', '${U(3)}', 'Sac T100 B', 'Design', 'Maison', 7000, 50, 'approved', '{p.jpg}')`);
  const LA = '00000000-0000-0000-0000-00000013b001', LB = '00000000-0000-0000-0000-00000013b002';
  let onum = 0;
  const sale = async (buyer, listing, { paid = true, confirmed = true } = {}) => {
    const oid = (await qs(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid) values ('#T100-${++onum}', '${buyer}', 5000, 0, 'Mobile Money', 0, ${paid}) returning id`))[0].id;
    const lid = (await qs(`insert into order_lines (order_id, listing_id, title, unit_price, qty) values ('${oid}', '${listing}', 'Article', 5000, 1) returning id`))[0].id;
    if (confirmed) await db.exec(`update order_lines set confirmed_at = now() where id = '${lid}'`);
    return { oid, lid };
  };

  // 1. règle en brouillon : l'activité est tracée, aucun point
  const s1 = await sale(U(5), LA);
  check('vente confirmée : événement tracé alors que la règle est en brouillon', (await ev(U(2), 'sale_confirmed')).length === 1 && (await ev(U(2), 'sale_confirmed'))[0].status === 'confirmed');
  check('règle en brouillon : 0 point attribué', (await tot(U(2))) === 0 && (await led(U(2))) === 0);
  const s0 = await sale(U(5), LA, { paid: false });
  const s00 = await sale(U(5), LA, { confirmed: false });
  check('commande non payée ou remise non confirmée : aucun événement', (await ev(U(2), 'sale_confirmed')).length === 1);

  // 2. activation par l'administration puis recomposition explicite, idempotente
  await rule('sale_confirmed', 100, 150, 300, 0, true);
  await as(U(2));
  await fails('étudiant : recomposition refusée', `select admin_talent_recompute('${U(2)}', 'Tentative de recomposition')`, DENY);
  await as(U(4));
  await works('modérateur : recomposition attribue la vente tracée sous la règle active', `select admin_talent_recompute('${U(2)}', 'Règle activée : recomposition') r`, (r) => r[0].r.points_added === 100 && r[0].r.consistent === true);
  check('score = 100 et registre = 100', (await tot(U(2))) === 100 && (await led(U(2))) === 100);
  await as(U(4));
  await works('recomposition rejouée : aucun point en double', `select admin_talent_recompute('${U(2)}', 'Rejeu de la recomposition') r`, (r) => r[0].r.points_added === 0);
  check('rejeu : score inchangé (100)', (await tot(U(2))) === 100);
  await sup(); await db.exec(`update order_lines set confirmed_at = now() where id = '${s1.lid}'`);
  check('même vente reconfirmée : toujours un seul événement et 100 points', (await ev(U(2), 'sale_confirmed')).length === 1 && (await tot(U(2))) === 100);

  // 3. plafond par jour (150) : deuxième vente 50, troisième 0 ; la vente non attribuée est signalée
  const s2 = await sale(U(5), LA);
  check('2e vente : points ramenés au plafond du jour (+50 => 150)', (await tot(U(2))) === 150);
  const s3 = await sale(U(5), LA);
  check('3e vente : plafond atteint, 0 point, événement tracé', (await tot(U(2))) === 150 && (await ev(U(2), 'sale_confirmed')).length === 3);
  await as(U(2));
  await works('explication : 3 activités, détail par règle et événement sans points', `select my_talent_score_explain() r`, (r) => r[0].r.total === 150 && r[0].r.entries.length === 2 && r[0].r.without_points.length === 1
    && r[0].r.by_rule.find((x) => x.code === 'sale_confirmed').points === 150 && r[0].r.by_rule.find((x) => x.code === 'sale_confirmed').activities === 3);

  // 4. annulation : les points attribués sont retirés exactement, une seule fois
  await sup(); await db.exec(`update orders set cancelled = true where id = '${s1.oid}'`);
  check('commande annulée : -100 points (reste 50)', (await tot(U(2))) === 50 && (await led(U(2))) === 50);
  check('événement passé à cancelled', (await ev(U(2), 'sale_confirmed'))[0].status === 'cancelled');
  await db.exec(`update orders set cancelled = true where id = '${s1.oid}'`);
  check('annulation rejouée : aucun retrait en double', (await tot(U(2))) === 50);
  await db.exec(`insert into order_refunds (order_id, requested_by, requester_role, reason, status, amount, kind) values ('${s2.oid}', '${U(5)}', 'buyer', 'Remboursement test', 'refunded', 5000, 'full')`);
  check('remboursement total : points de la vente retirés (0)', (await tot(U(2))) === 0 && (await led(U(2))) === 0);

  // 5. auto-vente : le vendeur ne s'achète pas ses propres articles
  const self = await sale(U(2), LA);
  check('auto-achat : événement neutralisé, 0 point', (await ev(U(2), 'sale_confirmed')).filter((e) => e.status === 'neutralized').length === 1 && (await tot(U(2))) === 0);

  // 6. avis : points pondérés par la qualité, avis sur achat réel seulement
  await rule('review_verified', 80, null, null, 0.5, true);
  const so = await sale(U(7), LB);
  const so2 = await sale(U(7), LB);
  const soCancelled = await sale(U(7), LB, { paid: false });
  const b0 = await tot(U(3));
  await db.exec(`insert into reviews (order_id, listing_id, reviewer_id, rating, comment) values ('${so.oid}', '${LB}', '${U(7)}', 5, 'Très bien')`);
  check('avis 5/5 : +80 points', (await tot(U(3))) === b0 + 80, String(await tot(U(3))));
  await db.exec(`insert into reviews (order_id, listing_id, reviewer_id, rating, comment) values ('${so2.oid}', '${LB}', '${U(7)}', 3, 'Moyen')`);
  check('avis 3/5 : +60 points (qualité 0,5 à poids 0,5)', (await tot(U(3))) === b0 + 140, String(await tot(U(3))));
  await db.exec(`delete from reviews where order_id = '${so2.oid}'`);
  check('avis supprimé : points retirés', (await tot(U(3))) === b0 + 80);
  await db.exec(`insert into reviews (order_id, listing_id, reviewer_id, rating, comment) values ('${soCancelled.oid}', '${LB}', '${U(7)}', 5, 'Sur commande non payée')`);
  check('avis sur commande non payée : aucun point', (await tot(U(3))) === b0 + 80 && (await ev(U(3), 'review_verified')).length === 2);
  const bAfterReview = await tot(U(3));

  // 7. vues et likes : aucune règle, aucun point possible
  check('aucune règle « vues » ni « likes »', (await qs(`select count(*)::int n from talent_score_rules where code ~* '(^|_)(views?|vues?|likes?)(\$|_)'`))[0].n === 0);
  const before = await evCount();
  check('enregistrer une vue par le moteur est ignoré', (await qs(`select _talent_event_record('${U(2)}', 'profile_view', 'view', 'x1', now(), null, null, '{}'::jsonb) r`))[0].r === null && (await evCount()) === before);
  await as(U(2));
  await fails('étudiant : _talent_event_record non appelable', `select _talent_event_record('${U(2)}', 'sale_confirmed', 'order_line', 'zz', now(), null, null, '{}'::jsonb)`, /permission denied/);

  // 8. mission validée : tous les jalons validés
  await rule('mission_validated', 200, null, null, 0, true);
  await db.exec(`insert into missions (id, number, client_id, kind, description, total, title, status) values ('00000000-0000-0000-0000-00000013c001', 'M-T100-1', '${U(5)}', 'service', 'Mission test T100', 90000, 'Logo T100', 'in_progress')`);
  await db.exec(`insert into mission_agreements (mission_id, client_id, provider_id, amount, delay_days, invoice_number) values ('00000000-0000-0000-0000-00000013c001', '${U(5)}', '${U(3)}', 90000, 10, 'F-T100-1')`);
  await db.exec(`insert into mission_milestones (mission_id, position, title, amount, status) values ('00000000-0000-0000-0000-00000013c001', 1, 'Jalon 1', 40000, 'pending'), ('00000000-0000-0000-0000-00000013c001', 2, 'Jalon 2', 50000, 'pending')`);
  check('mission : jalons non validés = aucun événement', (await ev(U(3), 'mission_validated')).length === 0);
  await db.exec(`update mission_milestones set status = 'validated' where mission_id = '00000000-0000-0000-0000-00000013c001' and position = 1`);
  check('mission : un jalon sur deux = aucun événement', (await ev(U(3), 'mission_validated')).length === 0);
  await db.exec(`update mission_milestones set status = 'validated' where mission_id = '00000000-0000-0000-0000-00000013c001' and position = 2`);
  check('mission : tous les jalons validés => +200', (await ev(U(3), 'mission_validated')).length === 1 && (await tot(U(3))) === bAfterReview + 200, String(await tot(U(3))));
  await db.exec(`update mission_milestones set status = 'correction' where mission_id = '00000000-0000-0000-0000-00000013c001' and position = 2`);
  check('mission rouverte : points retirés', (await tot(U(3))) === bAfterReview && (await ev(U(3), 'mission_validated'))[0].status === 'cancelled');

  // 9. certificat : émis et non révoqué ; auto-émission neutralisée
  await rule('certificate_verified', 60, null, null, 0, true);
  await db.exec(`insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, issued_by, fingerprint) values ('BE-CERT-7100A001', 'talent', 'Certification T100', '${U(8)}', 'Étudiant D', '${U(1)}', 'fp1')`);
  check('certificat émis : +60', (await tot(U(8))) === 60);
  await db.exec(`update certificates set revoked = true, revoked_reason = 'erreur', revoked_at = now() where code = 'BE-CERT-7100A001'`);
  check('certificat révoqué : points retirés', (await tot(U(8))) === 0);
  await db.exec(`insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, issued_by, fingerprint) values ('BE-CERT-7100A002', 'talent', 'Auto-émis', '${U(8)}', 'Étudiant D', '${U(8)}', 'fp2')`);
  check('certificat auto-émis : neutralisé, 0 point', (await tot(U(8))) === 0 && (await ev(U(8), 'certificate_verified')).some((e) => e.status === 'neutralized'));

  // 10. challenge
  await rule('challenge_participation', 30, null, null, 0, true);
  await db.exec(`insert into weekly_challenges (id, title, description, kind, ends_at) values ('00000000-0000-0000-0000-00000013d001', 'Défi T100', 'd', 'code', now() + interval '2 days')`);
  await db.exec(`insert into challenge_entries (challenge_id, author_id, title) values ('00000000-0000-0000-0000-00000013d001', '${U(8)}', 'Ma participation')`);
  check('participation à un challenge : +30', (await tot(U(8))) === 30);
  await db.exec(`delete from challenge_entries where author_id = '${U(8)}'`);
  check('participation retirée : points retirés', (await tot(U(8))) === 0);

  // 11. évaluation validée par un humain
  await rule('assessment_validated', 120, null, null, 0, true);
  await db.exec(`insert into assessment_requests (id, candidate_id, family_code, mode, status, funding, consent, accepted_at) values ('00000000-0000-0000-0000-00000013e001', '${U(8)}', 'mecanique', 'ecrit', 'acceptee', 'payee_candidat', true, now())`);
  await db.exec(`insert into assessment_results (id, request_id, candidate_id, competences, limits, validation_status) values ('00000000-0000-0000-0000-00000013e101', '00000000-0000-0000-0000-00000013e001', '${U(8)}', '[]', 'Évaluation à distance.', 'validation_humaine_requise')`);
  check('évaluation en attente de validation humaine : aucun point', (await tot(U(8))) === 0 && (await ev(U(8), 'assessment_validated')).length === 0);
  await as(U(1));
  await works('évaluation validée par un évaluateur humain (RPC H9)', `select assessment_human_validate('00000000-0000-0000-0000-00000013e101', 'validee_humainement', 'Évaluation vérifiée par un évaluateur.') r`, (r) => r[0].r.ok === true);
  await sup();
  check('évaluation validée par un humain : +120', (await tot(U(8))) === 120 && (await ev(U(8), 'assessment_validated')).length === 1, String(await tot(U(8))));

  // 12. isolation et droits
  await as(U(3));
  await works('étudiant B : son explication ne montre que ses propres activités', `select my_talent_score_explain(100) r`, (r) => r[0].r.total === bAfterReview && r[0].r.entries.every((x) => x.points !== 0) && !JSON.stringify(r[0].r).includes(U(2)));
  await fails('étudiant : lecture directe de talent_events refusée', `select * from talent_events`, /permission denied/);
  await fails('étudiant : lecture directe du registre refusée', `select * from talent_score_ledger`, /permission denied/);
  await fails('étudiant : modification directe du score refusée', `update talent_scores set total = 99999 where user_id = '${U(3)}'`, /permission denied/);
  await as(U(5));
  await fails('client : explication refusée', `select my_talent_score_explain()`, /Réservé aux comptes étudiants/);
  await fails('client : tableau de bord refusé', `select my_talent_dashboard()`, /Réservé aux comptes étudiants/);
  await as(null, 'anon');
  await fails('anonyme : explication refusée', `select my_talent_score_explain()`, /permission denied|Connexion requise/);
  await fails('anonyme : tableau de bord refusé', `select my_talent_dashboard()`, /permission denied|Connexion requise/);
  await fails('anonyme : recomposition refusée', `select admin_talent_recompute('${U(2)}', 'Tentative anonyme ici')`, /permission denied|Connexion requise/);
  await as(U(2));
  await fails('étudiant : liste admin des événements refusée', `select admin_talent_events_list('${U(3)}')`, DENY);
  await as(U(4));
  await works('modérateur : liste admin des événements d\'un étudiant', `select admin_talent_events_list('${U(3)}') r`, (r) => r[0].r.total === bAfterReview && r[0].r.events.length >= 2);
  await fails('modérateur sans ranking.rules : modification de règle refusée', `select admin_talent_rule_set('sale_confirmed', 500, null, null, 0, true, 'Tentative non autorisée ici')`, DENY);

  // 13. registre en ajout seul
  await sup();
  await fails('registre : modification refusée', `update talent_score_ledger set points = 1000 where id = (select min(id) from talent_score_ledger)`, /ajout seul/);
  await fails('registre : suppression refusée', `delete from talent_score_ledger`, /ajout seul/);
  await fails('événement : suppression refusée', `delete from talent_events`, /ne se supprime pas/);
  await fails('événement : identité non modifiable', `update talent_events set user_id = '${U(3)}'`, /pas modifiable/);
  check('cohérence : score = somme du registre pour chaque étudiant', (await qs(`select count(*)::int n from talent_scores s where s.total <> coalesce((select sum(points) from talent_score_ledger l where l.user_id = s.user_id), 0)`))[0].n === 0);
  check('versions de règle tracées dans le registre', (await qs(`select count(*)::int n from talent_score_ledger where rule_version >= 2`))[0].n > 0);

  // ============================================================ ANTI-FRAUDE, MODÉRATION ET CONTESTATIONS (20261127010300)
  await sup();
  for (const [n, r] of Object.entries({ 9: 'student', 10: 'client', 11: 'client', 12: 'student' })) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100a${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte T100 ${n}','${r}','t100a${n}@t.cm')`);
  }
  await db.exec(`update profiles set email = 'jean.dupont@t.cm' where id = '${U(9)}'; update profiles set email = 'jeandupont+boutique@t.cm' where id = '${U(10)}'`);
  await rule('collaboration', 10, null, null, 0, true);
  await rule('event_attended', 5, null, null, 0, true);
  const rec = async (u, code, kind, src, actor = null) => (await qs(`select _talent_event_record('${u}', '${code}', '${kind}', '${src}', now(), null, ${actor ? `'${actor}'` : 'null'}, '{}'::jsonb) r`))[0].r;
  const setting = async (k, v) => { await as(U(1)); await q(`select admin_talent_setting_set('${k}', ${v}, 'Réglage du banc de test anti-fraude') r`); await sup(); };
  await as(U(4));
  await fails('modérateur sans ranking.rules : réglage de paramètre refusé', `select admin_talent_setting_set('burst_count', 3, 'Tentative non autorisée ici')`, DENY);
  await as(U(1));
  await fails('paramètre inconnu refusé', `select admin_talent_setting_set('inconnu', 3, 'Paramètre qui n''existe pas ici')`, /Paramètre inconnu/);
  await fails('valeur nulle refusée', `select admin_talent_setting_set('burst_count', 0, 'Valeur nulle refusée par le serveur')`, /Valeur invalide/);
  await sup();

  // rafale : au-delà de 3 activités en 10 minutes, la suivante est neutralisée et signalée
  await setting('burst_count', 3);
  for (let i = 1; i <= 4; i++) await rec(U(9), 'collaboration', 'other', `b${i}`);
  const evs9 = await qs(`select id, status, status_reason from talent_events where user_id = '${U(9)}' order by id`);
  check('rafale : 3 activités comptées, la 4e neutralisée', evs9.filter((e) => e.status === 'confirmed').length === 3 && evs9[3].status === 'neutralized', JSON.stringify(evs9));
  check('rafale : 30 points seulement', (await tot(U(9))) === 30);
  check('rafale : alerte ouverte pour la modération', (await qs(`select count(*)::int n from talent_fraud_flags where user_id = '${U(9)}' and signal = 'burst' and status = 'open'`))[0].n === 1);
  const burstEv = evs9[3].id;
  await setting('burst_count', 50);

  // comptes liés : même adresse e-mail à l'alias près que l'auteur de l'action
  await rec(U(9), 'event_attended', 'other', 'l1', U(10));
  check('même e-mail (alias) auteur/bénéficiaire : neutralisé, 0 point', (await ev(U(9), 'event_attended'))[0].status === 'neutralized' && (await tot(U(9))) === 30);
  check('alerte « comptes liés »', (await qs(`select count(*)::int n from talent_fraud_flags where user_id = '${U(9)}' and signal = 'linked_accounts'`))[0].n === 1);
  await rec(U(9), 'event_attended', 'other', 'l2', U(11));
  check('auteur sans lien : activité comptée (+5)', (await tot(U(9))) === 35);

  // répétition d'un même auteur : au-delà de 2 avis/ventes en 30 jours
  await setting('actor_repeat', 2);
  await rule('review_verified', 80, null, null, 0, true);
  for (let i = 1; i <= 3; i++) await rec(U(12), 'review_verified', 'review', `rr${i}`, U(11));
  const evs12 = await ev(U(12), 'review_verified');
  check('même auteur : 2 avis comptés, le 3e neutralisé (faux avis en série)', evs12.filter((e) => e.status === 'confirmed').length === 2 && evs12[2].status === 'neutralized' && (await tot(U(12))) === 160);
  check('alerte « répétition »', (await qs(`select count(*)::int n from talent_fraud_flags where user_id = '${U(12)}' and signal = 'repeat_actor'`))[0].n === 1);
  await setting('actor_repeat', 3);

  // modération
  await as(U(2));
  await fails('étudiant : liste des alertes refusée', `select admin_talent_flags_list()`, DENY);
  await as(null, 'anon');
  await fails('anonyme : liste des alertes refusée', `select admin_talent_flags_list()`, /permission denied|Connexion requise/);
  await as(U(4));
  await works('modérateur : alertes ouvertes listées (rafale, comptes liés, répétition)', `select admin_talent_flags_list('open') r`, (r) => ['burst', 'linked_accounts', 'repeat_actor'].every((s) => r[0].r.some((f) => f.signal === s)));
  await fails('modérateur : neutralisation sans motif refusée', `select admin_talent_event_neutralize(${evs12[0].id}, 'court')`, /Motivez/);
  await works('modérateur : neutralise un avis confirmé (motif)', `select admin_talent_event_neutralize(${evs12[0].id}, 'Avis jugé de complaisance après examen') r`, (r) => r[0].r.points_removed === 80);
  check('neutralisation manuelle : -80 points, alerte « moderation » confirmée', (await tot(U(12))) === 80 && (await qs(`select count(*)::int n from talent_fraud_flags where event_id = ${evs12[0].id} and signal = 'moderation' and status = 'confirmed'`))[0].n === 1);
  await as(U(4));
  await fails('modérateur : neutraliser une activité déjà neutralisée refusé', `select admin_talent_event_neutralize(${evs12[0].id}, 'Deuxième neutralisation inutile')`, /Seule une activité confirmée/);
  await as(U(12));
  await fails('étudiant : neutralisation refusée', `select admin_talent_event_neutralize(${evs12[1].id}, 'Tentative de neutraliser un autre')`, DENY);

  // contestation
  await works('étudiant : liste ses activités, motif neutralisation sans détail interne', `select my_talent_events('neutralized') r`, (r) => r[0].r.length === 2 && r[0].r.every((x) => !/Rafale|Répétition|Modération|téléphone/.test(x.reason ?? '')) && r[0].r.every((x) => x.reason.includes('contester')));
  await fails('étudiant : contestation trop courte refusée', `select talent_score_dispute_open(${evs12[0].id}, 'non')`, /Expliquez/);
  await fails('étudiant : contester l\'activité d\'un autre refusé', `select talent_score_dispute_open(${burstEv}, 'Ce n''est pas mon activité du tout')`, /Activité introuvable/);
  let dsp;
  await works('étudiant : ouvre une contestation sur son activité neutralisée', `select talent_score_dispute_open(${evs12[0].id}, 'Cet avis vient d''un vrai client, voici mes preuves.') r`, (r) => { dsp = r[0].r.id; return r[0].r.status === 'open'; });
  await fails('étudiant : deuxième contestation sur la même activité refusée', `select talent_score_dispute_open(${evs12[0].id}, 'Deuxième contestation sur la même activité')`, /déjà en cours/);
  await works('étudiant : suit sa contestation', `select my_talent_disputes() r`, (r) => r[0].r.length === 1 && r[0].r[0].status === 'open');
  await as(U(9));
  await works('étudiant 9 : ne voit pas la contestation de l\'étudiant 12', `select my_talent_disputes() r`, (r) => r[0].r.length === 0);
  await as(U(2));
  await fails('étudiant : traitement d\'une contestation refusé', `select admin_talent_dispute_decide('${dsp}', 'accepted', 'Je me donne raison tout seul')`, DENY);
  await as(U(4));
  await works('modérateur : contestations ouvertes listées', `select admin_talent_disputes_list('open') r`, (r) => r[0].r.length === 1 && r[0].r[0].event_status === 'neutralized');
  await fails('modérateur : refus sans réponse motivée refusé', `select admin_talent_dispute_decide('${dsp}', 'rejected', 'non')`, /Motivez/);
  await works('modérateur : accepte la contestation => activité rétablie, points rendus', `select admin_talent_dispute_decide('${dsp}', 'accepted', 'Preuve d''achat vérifiée : l''avis est authentique.') r`, (r) => r[0].r.event_restored === true && r[0].r.points_added === 80);
  check('score rétabli à 160 ; alerte classée sans suite', (await tot(U(12))) === 160 && (await qs(`select count(*)::int n from talent_fraud_flags where event_id = ${evs12[0].id} and status = 'dismissed'`))[0].n >= 1);
  await as(U(4));
  await fails('contestation déjà traitée : nouveau traitement refusé', `select admin_talent_dispute_decide('${dsp}', 'rejected', 'Deuxième décision sur la même contestation')`, /déjà été traitée/);
  check('la décision a notifié l\'étudiant', (await qs(`select count(*)::int n from notifications where user_id = '${U(12)}' and title like '%contestation%'`))[0].n === 1);
  await as(U(4));
  await works('modérateur : rétablit la rafale (décision humaine) => +10', `select admin_talent_event_restore(${burstEv}, 'Vérifié : activités réelles de l''étudiant') r`, (r) => r[0].r.points_added === 10);
  check('score U9 = registre = 45', (await tot(U(9))) === 45 && (await led(U(9))) === 45);
  await as(U(4));
  await fails('rétablir une activité confirmée refusé', `select admin_talent_event_restore(${burstEv}, 'Rétablissement inutile déjà fait')`, /Seule une activité neutralisée/);
  await as(U(4));
  await works('modérateur : recomposition ne double rien après rétablissement', `select admin_talent_recompute('${U(9)}', 'Contrôle de cohérence après rétablissement') r`, (r) => r[0].r.points_added === 0 && r[0].r.consistent === true);
  await sup();
  check('jamais de score négatif ni d\'écart registre/score', (await qs(`select count(*)::int n from talent_scores s where s.total < 0 or s.total <> coalesce((select sum(points) from talent_score_ledger l where l.user_id = s.user_id), 0)`))[0].n === 0);
  check('les alertes automatiques ne sont créées qu\'une fois par neutralisation', (await qs(`select count(*)::int n from (select event_id from talent_fraud_flags where detected_by = 'auto' group by event_id having count(*) > 1) x`))[0].n === 0);

  // ============================================================ RÉFÉRENTIEL, RATTACHEMENTS, RÈGLES, NORMALISATION (20261127010000 / 010100 / 010200)
  await sup();
  const R = { 13: 'client', 14: 'client', 15: 'dept', 16: 'student', 17: 'dept', 18: 'student', 19: 'student', 20: 'support' };
  for (const [n, r] of Object.entries(R)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t100b${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte T100 ${n}','${r}','t100b${n}@t.cm')`);
  }
  const I2 = '00000000-0000-0000-0000-00000013a002', D2 = '00000000-0000-0000-0000-00000013a012';
  await db.exec(`insert into institutions (id, name, status) values ('${I2}', 'Établissement T100 B', 'verified'), ('00000000-0000-0000-0000-00000013a003', 'Établissement non vérifié', 'proposed');
    insert into departments (id, institution_id, name, status) values ('${D2}', '${I2}', 'Gestion', 'verified');
    insert into department_accounts (user_id, department_id, assigned_by) values ('${U(15)}', '${D1}', '${U(1)}'), ('${U(17)}', '${D2}', '${U(1)}');
    insert into admin_team_members (user_id, team_code, permissions) values ('${U(20)}', 'ranking', array['institutions.manage', 'ranking.rules'])`);
  const P1 = pr.id;

  // --- filières : droits et garde-fous
  await as(null, 'anon');
  await fails('anonyme : programs_list refusé', `select programs_list('${I1}')`, DENY);
  await fails('anonyme : demande de rattachement refusée', `select student_affiliation_request('${P1}', '2026')`, DENY);
  await fails('anonyme : file de validation refusée', `select student_affiliation_queue()`, DENY);
  await as(U(4));
  await fails('équipe classement sans institutions.manage : création de filière refusée', `select admin_program_upsert(null, '${I1}', '${D1}', 'Droit refusé', true)`, DENY);
  await as(U(20));
  await works('agent institutions.manage : crée une filière sans département', `select admin_program_upsert(null, '${I1}', null, 'Génie civil', true) r`, (r) => r[0].r.ok === true);
  await fails('filière en double refusée', `select admin_program_upsert(null, '${I1}', null, 'génie CIVIL', true)`, /existe déjà/);
  await fails('département d\'un autre établissement refusé', `select admin_program_upsert(null, '${I1}', '${D2}', 'Gestion croisée', true)`, /n'appartient pas|appartient pas/);
  await fails('établissement non vérifié refusé', `select admin_program_upsert(null, '00000000-0000-0000-0000-00000013a003', null, 'Filière fantôme', true)`, /non vérifié|introuvable/);
  await fails('nom trop court refusé', `select admin_program_upsert(null, '${I1}', null, 'X', true)`, /2 à 120/);
  const P2 = (await qs(`select id from programs where name = 'Génie civil'`))[0].id;
  await as(U(1));
  const p3 = (await q(`select admin_program_upsert(null, '${I2}', '${D2}', 'Comptabilité', true) r`))[0].r.id;
  const pOff = (await q(`select admin_program_upsert(null, '${I1}', null, 'Filière fermée', false) r`))[0].r.id;
  await as(U(2));
  await works('étudiant : programs_list de l\'établissement A (filières actives seulement)', `select programs_list('${I1}') r`, (r) => r[0].r.length === 2 && r[0].r.every((x) => x.active) && !JSON.stringify(r[0].r).includes(p3));
  await works('étudiant : programs_list filtré par département', `select programs_list('${I1}', '${D1}') r`, (r) => r[0].r.length === 1 && r[0].r[0].id === P1);
  await works('programs_list d\'un établissement non vérifié : vide', `select programs_list('00000000-0000-0000-0000-00000013a003') r`, (r) => r[0].r.length === 0);
  await fails('étudiant : lecture directe de institution_managers refusée', `select * from institution_managers`, /permission denied/);
  await fails('étudiant : insertion directe d\'un rattachement refusée', `insert into student_affiliations (user_id, institution_id, program_id, promotion, status) values ('${U(2)}', '${I1}', '${P1}', '2026', 'verified')`, /permission denied/);

  // --- responsables d'établissement
  await as(U(2));
  await fails('étudiant : nommer un responsable refusé', `select admin_institution_manager_set('${U(13)}', '${I1}', true)`, DENY);
  await as(U(20));
  await fails('compte étudiant non nommable responsable', `select admin_institution_manager_set('${U(3)}', '${I1}', true)`, /étudiant ne peut pas/);
  await works('nomme un responsable pour A et un pour B', `select admin_institution_manager_set('${U(13)}', '${I1}', true) a, admin_institution_manager_set('${U(14)}', '${I2}', true) b`, (r) => r[0].a.manager === true && r[0].b.manager === true);

  // --- demandes de rattachement
  await as(U(5));
  await fails('client : demande de rattachement refusée', `select student_affiliation_request('${P1}', '2026')`, /Réservé aux comptes étudiants/);
  await as(U(2));
  await fails('promotion trop courte refusée', `select student_affiliation_request('${P1}', '2')`, /Promotion/);
  await fails('filière inactive refusée', `select student_affiliation_request('${pOff}', '2026')`, /introuvable/);
  const req = async (u, prog, promo = '2026') => { await as(u); return (await q(`select student_affiliation_request('${prog}', '${promo}') r`))[0].r.id; };
  const A2 = await req(U(2), P1);
  await fails('une seule demande en attente par étudiant', `select student_affiliation_request('${P2}', '2026')`, /déjà en attente/);
  await works('l\'étudiant voit sa demande en attente', `select my_student_affiliation() r`, (r) => r[0].r.current.status === 'pending' && r[0].r.history.length === 1);
  const A3 = await req(U(3), P1), A8 = await req(U(8), P1), A9 = await req(U(9), P1), A12 = await req(U(12), P2), A16 = await req(U(16), P2), A18 = await req(U(18), P2), A19 = await req(U(19), p3);

  // --- périmètre de validation (administration, responsable d'établissement, responsable de département)
  await as(U(13));
  await works('responsable de A : voit les 7 demandes de A, pas celle de B', `select student_affiliation_queue() r`, (r) => r[0].r.length === 7 && !r[0].r.some((x) => x.id === A19));
  await as(U(14));
  await works('responsable de B : ne voit que la demande de B', `select student_affiliation_queue() r`, (r) => r[0].r.length === 1 && r[0].r[0].id === A19);
  await as(U(15));
  await works('responsable du département D1 : ne voit que les demandes de sa filière', `select student_affiliation_queue() r`, (r) => r[0].r.length === 4 && r[0].r.every((x) => x.department_id === D1));
  await as(U(17));
  await works('responsable du département D2 : voit la filière de B seulement', `select student_affiliation_queue() r`, (r) => r[0].r.length === 1 && r[0].r[0].id === A19);
  await as(U(2));
  await works('étudiant : file vide (aucune validation possible)', `select student_affiliation_queue() r`, (r) => r[0].r.length === 0);
  await fails('étudiant : valider sa propre demande refusé', `select student_affiliation_decide('${A2}', 'verified', null)`, /périmètre/);
  await as(U(14));
  await fails('responsable de B : valider une demande de A refusé (isolation inter-établissements)', `select student_affiliation_decide('${A2}', 'verified', null)`, /périmètre/);
  await as(U(17));
  await fails('responsable du département D2 : valider une demande de D1 refusé', `select student_affiliation_decide('${A2}', 'verified', null)`, /périmètre/);
  await fails('responsable de département : historique d\'un étudiant d\'un autre département refusé', `select student_affiliation_history_list('${U(2)}')`, /hors de votre périmètre/);
  await as(U(13));
  await fails('refus sans motif refusé', `select student_affiliation_decide('${A8}', 'rejected', null)`, /Motivez/);
  await fails('décision inconnue refusée', `select student_affiliation_decide('${A8}', 'peut-etre', null)`, /Décision inconnue/);
  await works('responsable de A : valide une filière', `select student_affiliation_decide('${A2}', 'verified', 'Inscription vérifiée') r`, (r) => r[0].r.status === 'verified');
  await fails('décision déjà prise : refus de rejouer', `select student_affiliation_decide('${A2}', 'verified', null)`, /déjà été traitée/);
  await works('responsable de A : refuse avec motif', `select student_affiliation_decide('${A8}', 'rejected', 'Matricule introuvable dans la promotion') r`, (r) => r[0].r.status === 'rejected');
  await as(U(15));
  await works('responsable du département D1 : valide dans son périmètre', `select student_affiliation_decide('${A3}', 'verified', null) r`, (r) => r[0].r.status === 'verified');
  await as(U(20));
  await works('agent institutions.manage : valide (2FA non exigée sans facteur)', `select student_affiliation_decide('${A9}', 'verified', null) a, student_affiliation_decide('${A12}', 'verified', null) b, student_affiliation_decide('${A16}', 'verified', null) c, student_affiliation_decide('${A18}', 'verified', null) d, student_affiliation_decide('${A19}', 'verified', null) e`, (r) => r[0].e.status === 'verified');
  await sup();
  check('notification envoyée à l\'étudiant validé', (await qs(`select count(*)::int n from notifications where user_id = '${U(2)}' and title like '%filière%'`))[0].n >= 1);
  await fails('rattachement vérifié : programme non modifiable (garde)', `update student_affiliations set program_id = '${P2}' where id = '${A2}'`, /pas modifiable/);
  await fails('demande refusée : ne revient pas en arrière', `update student_affiliations set status = 'verified' where id = '${A8}'`, /définitive/);
  await fails('rattachement vérifié : ne revient pas à « pending »', `update student_affiliations set status = 'pending' where id = '${A2}'`, /pas en arrière/);
  await as(U(2));
  await fails('déjà rattaché à cette filière : nouvelle demande identique refusée', `select student_affiliation_request('${P1}', '2026')`, /déjà rattaché/);
  const A2b = await req(U(2), P2, '2027');
  await as(U(13));
  await works('changement de filière validé : l\'ancien rattachement est clos', `select student_affiliation_decide('${A2b}', 'verified', 'Réorientation confirmée') r`, (r) => r[0].r.status === 'verified');
  await sup();
  check('un seul rattachement vérifié en cours par étudiant', (await qs(`select count(*)::int n from student_affiliations where user_id = '${U(2)}' and status = 'verified' and ended_at is null`))[0].n === 1);
  check('l\'ancien rattachement a un événement « ended »', (await qs(`select count(*)::int n from student_affiliation_history where user_id = '${U(2)}' and action = 'ended'`))[0].n === 1);
  await as(U(2));
  await works('historique de l\'étudiant : demande, validation, fin, nouvelle demande, validation', `select student_affiliation_history_list() r`, (r) => r[0].r.length === 5);
  await fails('étudiant : historique d\'un autre étudiant refusé', `select student_affiliation_history_list('${U(3)}')`, /hors de votre périmètre/);
  await as(U(14));
  await fails('responsable de B : historique d\'un étudiant de A refusé', `select student_affiliation_history_list('${U(2)}')`, /hors de votre périmètre/);
  await as(U(13));
  await works('responsable de A : historique d\'un étudiant de A', `select student_affiliation_history_list('${U(3)}') r`, (r) => r[0].r.length === 2);

  // --- règles de score (010100)
  await as(U(2));
  await fails('étudiant : liste admin des règles refusée', `select admin_talent_rules_list()`, DENY);
  await fails('étudiant : historique des règles refusé', `select admin_talent_rule_history()`, DENY);
  await fails('étudiant : modification d\'une règle refusée', `select admin_talent_rule_set('live_hosted', 10, null, null, 0, true, 'Tentative d''un étudiant ici')`, DENY);
  await fails('étudiant : lecture directe des règles refusée', `select * from talent_score_rules`, /permission denied/);
  await works('étudiant : règles publiques = uniquement les règles actives', `select talent_rules_public() r`, (r) => r[0].r.length === 8 && r[0].r.every((x) => x.points > 0) && !r[0].r.some((x) => x.code === 'live_hosted'));
  await as(null, 'anon');
  await fails('anonyme : règles publiques refusées', `select talent_rules_public()`, DENY);
  await fails('anonyme : liste des règles refusée', `select admin_talent_rules_list()`, DENY);
  await as(U(20));
  await fails('règle active à 0 point refusée', `select admin_talent_rule_set('live_hosted', 0, null, null, 0, true, 'Activation d''une règle vide')`, /au moins 1 point/);
  await fails('points au-delà de 1000 refusés', `select admin_talent_rule_set('live_hosted', 1001, null, null, 0, true, 'Valeur hors bornes du moteur')`, /entre 0 et 1000/);
  await fails('poids qualité hors 0..1 refusé', `select admin_talent_rule_set('live_hosted', 10, null, null, 1.5, true, 'Poids hors bornes du moteur')`, /Poids qualité|numeric/);
  await fails('règle inconnue refusée', `select admin_talent_rule_set('vues_profil', 10, null, null, 0, true, 'Règle qui n''existe pas ici')`, /Règle inconnue/);
  await fails('motif trop court refusé', `select admin_talent_rule_set('live_hosted', 10, null, null, 0, true, 'court')`, /Motivez/);
  await works('agent ranking.rules : règle modifiée et versionnée', `select admin_talent_rule_set('live_hosted', 25, 100, 500, 0.4, false, 'Brouillon chiffré en attente de validation') r`, (r) => r[0].r.version === 2 && r[0].r.active === false);
  await works('historique : création en brouillon puis modification, avec motif et auteur', `select admin_talent_rule_history('live_hosted') r`, (r) => r[0].r.length === 2 && r[0].r[0].reason === 'Brouillon chiffré en attente de validation' && r[0].r[1].points === 0);
  await works('liste admin : 13 règles et paramètres', `select admin_talent_rules_list() r`, (r) => r[0].r.rules.length === 13 && r[0].r.settings.burst_count !== undefined);
  await sup();
  check('règle inactive à points non nuls : aucune règle publique de plus', (await qs(`select count(*)::int n from talent_score_rules where active and points > 0`))[0].n === 8);

  // --- projet publié avec preuves
  await rule('project_published_with_proof', 40, null, null, 0, true);
  const prj = (await qs(`insert into projects (owner_id, title, summary, department, status, kind, visibility) values ('${U(18)}', 'Projet T100', 'Résumé du projet T100', 'Design', 'draft', 'projet', 'public') returning id`))[0].id;
  const t18 = await tot(U(18));
  await db.exec(`update projects set status = 'approved' where id = '${prj}'`);
  check('projet approuvé sans preuve : aucun point', (await tot(U(18))) === t18 && (await ev(U(18), 'project_published_with_proof')).length === 0);
  await db.exec(`update projects set links = '{"demo": "https://exemple.cm/demo"}'::jsonb where id = '${prj}'`);
  check('projet approuvé avec preuve : +40', (await tot(U(18))) === t18 + 40);
  await db.exec(`update projects set status = 'draft' where id = '${prj}'`);
  check('projet dépublié : points retirés', (await tot(U(18))) === t18 && (await ev(U(18), 'project_published_with_proof'))[0].status === 'cancelled');

  // --- normalisation par filière / établissement / national
  const pct = (all, mine) => { const lt = all.filter((x) => x < mine).length, eq = all.filter((x) => x === mine).length; return Math.round((100 * (lt + 0.5 * eq) / all.length) * 10) / 10; };
  const totalsOf = async (prog) => (await qs(`select coalesce(ts.total, 0)::int t, sa.user_id from student_affiliations sa left join talent_scores ts on ts.user_id = sa.user_id where sa.status = 'verified' and sa.ended_at is null ${prog ? `and sa.program_id = '${prog}'` : ''}`));
  await setting('min_cohort', 3);
  const c2 = await totalsOf(P2), call = await totalsOf(null);
  await as(U(12));
  await works('normalisation : centile dans la filière = calcul indépendant', `select my_talent_dashboard() r`, (r) => {
    const n = r[0].r.normalization;
    const mine = c2.find((x) => x.user_id === U(12)).t;
    return n.affiliated === true && n.program.cohort_size === c2.length && n.program.percentile_total === pct(c2.map((x) => x.t), mine) && n.national.cohort_size === call.length
      && n.national.percentile_total === pct(call.map((x) => x.t), call.find((x) => x.user_id === U(12)).t);
  });
  await works('tableau de bord : aucun classement publié (honnête), progression du mois', `select my_talent_dashboard() r`, (r) => r[0].r.rank === null && /Aucun classement/.test(r[0].r.rank_note) && r[0].r.affiliation.status === 'verified' && r[0].r.total === 160 && r[0].r.month_points === 160 && r[0].r.progression === 160);
  await works('explication : normalisation incluse et dernier mois à 0', `select my_talent_score_explain() r`, (r) => r[0].r.normalization.program.cohort_size === c2.length && r[0].r.previous_month_points === 0);
  await setting('min_cohort', 5);
  await as(U(12));
  await works('cohorte sous le seuil : centile nul avec raison (pas de faux classement)', `select my_talent_dashboard() r`, (r) => r[0].r.normalization.program.percentile_total === null && r[0].r.normalization.program.reason === 'cohorte_insuffisante');
  await as(U(6));
  await works('étudiant sans rattachement vérifié : comparaison impossible, dit honnêtement', `select my_talent_dashboard() r`, (r) => r[0].r.normalization.affiliated === false && r[0].r.affiliation === null && r[0].r.total === 0);
  await as(U(2));
  await works('étudiant : ne voit pas les scores des autres (seulement des centiles)', `select my_talent_dashboard() r`, (r) => !JSON.stringify(r[0].r).includes(U(3)) && !JSON.stringify(r[0].r).includes(U(12)));
  await setting('min_cohort', 3);
  await sup();
  await db.exec(`insert into talent_score_settings (key, value) values ('min_cohort', 3) on conflict (key) do update set value = 3`);
  const g1 = await totalsOf(P1);
  await as(U(3));
  await works('petite filière (cohorte sous le seuil) : pas de centile de filière, mais le centile national reste calculé', `select my_talent_dashboard() r`, (r) => r[0].r.normalization.program.cohort_size === g1.length && r[0].r.normalization.program.percentile_total === null && typeof r[0].r.normalization.national.percentile_total === 'number');

  // --- rejeu des migrations du lot : aucun effet de bord
  await sup();
  const snap = async () => JSON.stringify([(await q(`select count(*)::int n from programs`))[0].n, (await q(`select count(*)::int n from student_affiliations`))[0].n, (await q(`select count(*)::int n from talent_events`))[0].n,
    (await q(`select count(*)::int n from talent_score_ledger`))[0].n, (await q(`select coalesce(sum(total),0)::int n from talent_scores`))[0].n, (await q(`select coalesce(sum(points),0)::int n from talent_score_rules`))[0].n,
    (await q(`select count(*)::int n from talent_score_rules where active`))[0].n, (await q(`select count(*)::int n from talent_score_rule_history`))[0].n, (await q(`select count(*)::int n from talent_fraud_flags`))[0].n,
    (await q(`select count(*)::int n from admin_permissions where code like 'ranking.%' or code = 'institutions.manage'`))[0].n]);
  const before2 = await snap();
  const here = path.dirname(fileURLToPath(import.meta.url));
  for (const f of fs.readdirSync(path.join(here, '..', '..', 'migrations')).filter((x) => /^20261127010[0-3]00_h12_top100/.test(x)).sort()) {
    try { await db.exec(fs.readFileSync(path.join(here, '..', '..', 'migrations', f), 'utf8')); check(`rejeu ${f.slice(0, 14)} : sans erreur`, true); } catch (e) { check(`rejeu ${f.slice(0, 14)} : sans erreur`, false, e.message.slice(0, 160)); }
  }
  check('rejeu : aucune donnée créée, modifiée ni perdue (programmes, rattachements, événements, registre, scores, règles, alertes, permissions)', (await snap()) === before2);

  console.log(`h12_top100a : ${ok} OK, ${ko} ECHEC`);
}
