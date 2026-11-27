// Lot K1 (sécurité administrateur) : prouve les migrations 20261121010000 à 010300.
//  A. 2FA serveur (enforce_mfa_on_sensitive) ; B. notifications Finance / Support par permission ; C. héritage des anciens comptes (droits minimaux + rattrapage) ;
//  D. effet immédiat, historique auditable, isolement entre équipes (matrice équipe x fonction sensible, lectures directes) ; E. cas anonyme / suspendu / non vérifié / permission révoquée.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./fin_k1.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const dir = path.dirname(fileURLToPath(import.meta.url));
  const mig = (f) => fs.readFileSync(path.join(dir, '..', '..', 'migrations', f), 'utf8');
  const id = (n) => `00000000-0000-0000-0000-0000000051${String(n).padStart(2, '0')}`;
  const A = id(1), A2 = id(2), AF = id(3), AS = id(4), ASEC = id(5), ATECH = id(6), FMIN = id(7), SMIN = id(8), F1 = id(9), S1 = id(10), C = id(11), D = id(12), DIR = id(13), ST = id(14), SUSP = id(15),
    LEG_F = id(16), LEG_S = id(17), LEG_X = id(18), LEG_ADM = id(19), M2FA = id(20), MUNV = id(21), C2 = id(22);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const DENY = /Action non autorisée|réservé|Réservé|exige la permission|Connexion requise|permission denied|Compte suspendu|double authentification/i;
  const guardPassed = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, !DENY.test(e.message), e.message); } };
  const guardDenied = async (name, sql) => { try { await q(sql); check(name, false, 'aurait du etre refuse'); } catch (e) { check(name, DENY.test(e.message), e.message); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const grant = async (user, team, perms, note) => { await as(A); return q(`select admin_team_member_set('${user}', '${team}', array[${perms.map((p) => `'${p}'`).join(',')}]${note ? `, '${note}'` : ''}) r`); };
  const perms = (uid, team) => qs(`select permissions from admin_team_members where user_id = '${uid}' and team_code = '${team}'`).then((r) => r[0]?.permissions ?? null);
  const notifCount = async (uid, title) => (await qs(`select count(*)::int n from notifications where user_id = '${uid}' and title = '${title.replace(/'/g, "''")}'`))[0].n;

  const ALL = {
    finance: ['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers', 'finance.split'],
    support: ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'],
    security: ['security.moderation', 'security.reports', 'security.accounts', 'security.audit'],
    tech: ['tech.config', 'tech.integrations', 'tech.logs', 'tech.maintenance'],
  };
  const OLD_FIN = ['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'];
  const OLD_SUP = ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'];
  const OLD_SEC = ['security.accounts', 'security.audit', 'security.moderation', 'security.reports'];
  const arr = (a) => `array[${a.map((p) => `'${p}'`).join(',')}]::text[]`;

  // ============================================================ comptes
  await db.exec('reset role');
  await db.exec(`alter table profiles disable trigger trg_admin_team_autoenroll`);
  for (const [i, nm, role] of [[LEG_F, 'Legs Finance', 'finance'], [LEG_S, 'Legs Support', 'support'], [LEG_X, 'Legs Explicite', 'finance'], [LEG_ADM, 'Legs Promu', 'finance']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[1].toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[1].toLowerCase()}@t.cm')`);
  }
  await db.exec(`alter table profiles enable trigger trg_admin_team_autoenroll`);
  for (const [i, nm, role] of [[A, 'Ada Admin', 'admin'], [A2, 'Bob Admin', 'admin'], [AF, 'Fina Finance', 'finance'], [AS, 'Sam Support', 'support'], [ASEC, 'Sec Securite', 'support'], [ATECH, 'Tech Technique', 'support'],
    [FMIN, 'Fmin Finance', 'finance'], [SMIN, 'Smin Support', 'support'], [F1, 'Fred Paiements', 'finance'], [S1, 'Suzy Tickets', 'support'], [C, 'Cora Cliente', 'client'], [D, 'Dep Dept', 'dept'], [DIR, 'Dir Direction', 'direction'],
    [ST, 'Etu Etudiant', 'student'], [SUSP, 'Sus Pendu', 'support'], [M2FA, 'Mfa Admin', 'admin'], [MUNV, 'Munv Compte', 'support'], [C2, 'Cyril Client', 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0].toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0].toLowerCase()}@t.cm')`);
  }
  await sup();

  // ============================================================ A. 2FA serveur
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${M2FA}', 'verified'), ('${MUNV}', 'unverified')`);
  const guard = async (p, uid, aal, method = 'POST') => {
    const save = cur; await sup();
    await db.exec(`select set_config('request.path', '${p}', false), set_config('request.method', '${method}', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false)`);
    let r = 'ok';
    try { await db.exec('select enforce_mfa_on_sensitive()'); } catch (e) { r = e.message; }
    if (save) await as(save.uid, save.role);
    return r;
  };
  const NEW_OPS = ['partnership_decide', 'institutional_validation_decide', 'admin_dept_assign', 'admin_dept_unassign', 'claim_decide', 'campaign_refund_done', 'event_refund_done',
    'save_notification_template', 'admin_process_account_deletions', 'admin_mfa_reset', 'admin_mfa_reset_by_email'];
  for (const op of NEW_OPS) {
    check(`A1 ${op} : sans aal2 (compte avec facteur TOTP vérifié) refusé`, /double authentification/.test(await guard('/rpc/' + op, M2FA, 'aal1')));
    check(`A2 ${op} : avec aal2 accepté`, (await guard('/rpc/' + op, M2FA, 'aal2')) === 'ok');
    check(`A3 ${op} : compte sans 2FA (aal1) : comportement inchangé, accepté`, (await guard('/rpc/' + op, A2, 'aal1')) === 'ok');
  }
  check('A4 facteur non vérifié : aucune exigence', (await guard('/rpc/admin_dept_assign', MUNV, 'aal1')) === 'ok');
  const OLD_OPS = ['request_account_deletion', 'export_my_data', 'profile_set_phone', 'set_whatsapp_number', 'payment_start', 'payment_declare', 'payment_set_status', 'marketplace_checkout', 'create_order', 'cancel_order',
    'confirm_cod_order', 'company_plan_checkout', 'company_decide', 'company_plan_save', 'company_subscription_activate', 'subscription_start', 'campaign_contribute', 'event_checkout', 'ann_prize_checkout', 'ann_prize_set',
    'ann_prize_award', 'ann_prize_refund', 'request_referral_payout', 'referral_payout_decide', 'payout_create', 'payout_set_status', 'money_release_now', 'dispute_decide', 'admin_set_account', 'request_seller_payout',
    'seller_payout_decide', 'momo_prepare_transfer', 'admin_team_member_set', 'admin_team_member_remove', 'money_freeze', 'money_unfreeze', 'money_split_set', 'order_refund_decide', 'order_refund_set_paid', 'setting_set',
    'create_api_key', 'revoke_api_key', 'security_flag_decide'];
  let oldKept = 0;
  for (const op of OLD_OPS) { if (/double authentification/.test(await guard('/rpc/' + op, M2FA, 'aal1'))) oldKept++; }
  check('A5 aucune opération déjà protégée n\'a été retirée de la garde', oldKept === OLD_OPS.length, `${oldKept}/${OLD_OPS.length}`);
  for (const op of ['security_flag_account', 'dept_report', 'partnership_save', 'dept_partnership_save', 'direction_dashboard', 'admin_team_dashboard', 'my_admin_access']) {
    check(`A6 ${op} (lecture ou proposition, volontairement hors garde 2FA) : accepté en aal1`, (await guard('/rpc/' + op, M2FA, 'aal1')) === 'ok');
  }
  check('A7 un chemin voisin (partnership_decide_x) n\'est pas capturé par erreur', (await guard('/rpc/partnership_decide_x', M2FA, 'aal1')) === 'ok');
  await sup(); await db.exec(`update profiles set suspended = true where id = '${SUSP}'`);
  check('A8 la garde « compte suspendu » est conservée (écriture refusée)', /suspendu/i.test(await guard('/rpc/create_post', SUSP, 'aal2')));
  // H13.1 (sessions) : un compte suspendu est refusé aussi en lecture (la garde exempte seulement support, CGU, suppression de compte, appareils).
  check('A9 lecture (GET) d\'un compte suspendu refusée depuis H13.1 (exceptions : support, CGU, suppression de compte)', /suspendu/i.test(await guard('/rpc/my_admin_access', SUSP, 'aal2', 'GET')));
  check('A10 erreur de lecture des claims : la garde ne bloque jamais l\'API', await (async () => { await sup(); await db.exec(`select set_config('request.path', '/rpc/partnership_decide', false), set_config('request.method','POST',false), set_config('request.jwt.claims', 'pas-du-json', false)`); try { await db.exec('select enforce_mfa_on_sensitive()'); return true; } catch { return false; } })());
  await sup();
  await db.exec(mig('20261121010000_k1_mfa_operations_sensibles.sql'));
  const def = (await q(`select pg_get_functiondef('enforce_mfa_on_sensitive()'::regprocedure) d`))[0].d;
  check('A11 la migration rejouée n\'ajoute aucun doublon', NEW_OPS.every((o) => def.split('|' + o + '|').length + def.split('|' + o + ')').length - 2 === 1));
  const defCount = (await q(`select count(*)::int n from pg_proc where proname = 'enforce_mfa_on_sensitive'`))[0].n;
  check('A12 une seule définition de la garde', defCount === 1);

  // ============================================================ C. héritage : état de production simulé, puis rattrapage
  await sup();
  // état de production d'avant K1 : droits larges hérités de H4 (granted_by nul = migration), plus un compte promu par l'administrateur (inscription automatique, granted_by = admin) et un compte attribué explicitement
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${LEG_F}', 'finance', ${arr(OLD_FIN)}), ('${LEG_S}', 'support', ${arr(OLD_SUP)}), ('${LEG_S}', 'security', ${arr(OLD_SEC)})
    on conflict (user_id, team_code) do update set permissions = excluded.permissions`);
  await db.exec(`insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note) values
    (null, '${LEG_F}', 'finance', 'migration', '{}', ${arr(OLD_FIN)}, 'mig'), (null, '${LEG_S}', 'support', 'migration', '{}', ${arr(OLD_SUP)}, 'mig'), (null, '${LEG_S}', 'security', 'migration', '{}', ${arr(OLD_SEC)}, 'mig')`);
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions, granted_by) values ('${LEG_ADM}', 'finance', ${arr(OLD_FIN)}, '${A}')
    on conflict (user_id, team_code) do update set permissions = excluded.permissions, granted_by = '${A}'`);
  await db.exec(`insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note) values ('${A}', '${LEG_ADM}', 'finance', 'auto_enroll', '{}', ${arr(OLD_FIN)}, 'rôle attribué')`);
  await grant(LEG_X, 'finance', ['finance.payments', 'finance.payouts'], 'attribution volontaire');
  await sup();
  await db.exec(`insert into payment_transactions (reference, payer_id, provider, kind, subject, amount, status) values ('PAY-K1-1', '${C}', 'manual', 'other', 'essai', 5000, 'pending'), ('PAY-K1-2', '${C}', 'manual', 'other', 'essai 2', 7000, 'pending'), ('PAY-K1-3', '${C}', 'manual', 'other', 'essai 3', 9000, 'pending'), ('PAY-K1-4', '${C}', 'manual', 'other', 'essai 4', 3000, 'pending')`);
  const P = async (ref) => (await qs(`select id from payment_transactions where reference = '${ref}'`))[0].id;
  const p1 = await P('PAY-K1-1'), p2 = await P('PAY-K1-2'), p3 = await P('PAY-K1-3'), p4 = await P('PAY-K1-4');
  await as(LEG_F);
  await guardPassed('C0a état hérité (avant rattrapage) : le compte finance d\'avant avait bien un droit sensible (paiements) sans attribution explicite', `select payments_to_verify()`);
  await as(LEG_S);
  await guardPassed('C0b état hérité : le compte support d\'avant modérait sans attribution explicite', `select moderation_posts_list('pending', 10)`);

  await sup();
  const reduceSql = mig('20261121010200_k1_droits_minimaux_heritage.sql');
  await db.exec(reduceSql);
  check('C1 finance hérité : ligne réduite à AUCUNE permission, équipe du rôle conservée', JSON.stringify(await perms(LEG_F, 'finance')) === '[]');
  check('C2 support hérité : équipe support réduite à aucune permission', JSON.stringify(await perms(LEG_S, 'support')) === '[]');
  check('C3 support hérité : ligne Sécurité (jamais attribuée) supprimée', (await perms(LEG_S, 'security')) === null);
  check('C4 compte promu par l\'administrateur (inscription automatique) : non explicite, donc réduit', JSON.stringify(await perms(LEG_ADM, 'finance')) === '[]');
  check('C5 attribution EXPLICITE conservée (grant par l\'administrateur)', JSON.stringify(await perms(LEG_X, 'finance')) === JSON.stringify(['finance.payments', 'finance.payouts']));
  check('C6 la réduction est historisée avec les permissions d\'avant', (await qs(`select count(*)::int n from admin_team_history where action = 'reduce' and user_id = '${LEG_F}' and before_permissions @> ${arr(OLD_FIN)} and after_permissions = '{}'`))[0].n === 1
    && (await qs(`select count(*)::int n from admin_team_history where action = 'reduce' and user_id = '${LEG_S}'`))[0].n === 2);
  check('C7 la réduction est auditée (catégorie Équipes, niveau Critique)', (await qs(`select count(*)::int n from audit_log where action = 'Équipe : droits hérités réduits' and category = 'Équipes' and level = 'Critique'`))[0].n === 4);
  check('C8 les administrateurs sont prévenus (compte, comptes à réviser)', (await notifCount(A, 'Comptes Finance / Support à réviser')) === 1 && (await notifCount(A2, 'Comptes Finance / Support à réviser')) === 1);
  check('C9 aucune notification de révision aux non administrateurs', (await notifCount(AF, 'Comptes Finance / Support à réviser')) === 0 && (await notifCount(C, 'Comptes Finance / Support à réviser')) === 0);
  const before = (await qs(`select count(*)::int n from admin_team_history where action = 'reduce'`))[0].n;
  await db.exec(reduceSql);
  check('C10 rattrapage idempotent : rejoué, aucune nouvelle réduction, aucune nouvelle notification', (await qs(`select count(*)::int n from admin_team_history where action = 'reduce'`))[0].n === before && (await notifCount(A, 'Comptes Finance / Support à réviser')) === 1);
  check('C11 granted_by remis à nul (aucun privilège conservé automatiquement)', (await qs(`select count(*)::int n from admin_team_members where user_id in ('${LEG_F}', '${LEG_S}', '${LEG_ADM}') and granted_by is not null`))[0].n === 0);
  check('C12 un nouveau compte finance / support est inscrit SANS permission', (await perms(FMIN, 'finance')).length === 0 && (await perms(SMIN, 'support')).length === 0
    && (await qs(`select count(*)::int n from admin_team_history where user_id = '${FMIN}' and action = 'auto_enroll' and after_permissions = '{}'`))[0].n === 1);
  check('C13 les droits de base (defaults) du serveur sont vides pour chaque équipe', (await qs(`select bool_and(cardinality(d) = 0) b from (select _admin_team_defaults(c) d from unnest(array['finance','support','security','tech']) c) x`))[0].b === true);

  // les opérations sensibles du compte hérité sont refusées
  const SENS = [
    ['payment_set_status', `select payment_set_status('${p1}', 'confirmed')`],
    ['payments_to_verify', `select payments_to_verify()`],
    ['payout_create', `select payout_create('${ST}', 1000)`],
    ['momo_prepare_transfer', `select momo_prepare_transfer('${p1}', '690000000', 1000, 'x', 'idem')`],
    ['order_refund_set_paid', `select order_refund_set_paid('${p1}', 'REF123')`],
    ['money_freeze', `select money_freeze('${p1}', 'motif')`],
    ['money_split_set', `select money_split_set(60, 25, 15, 'essai')`],
    ['finance_overview', `select finance_overview()`],
    ['money_admin_overview', `select money_admin_overview()`],
  ];
  for (const [who, uid] of [['finance hérité', LEG_F], ['promu par l\'admin (auto-inscription)', LEG_ADM], ['finance minimal', FMIN]]) {
    await as(uid);
    for (const [n, sql] of SENS.filter((s) => s[0] !== 'finance_overview' || true)) await guardDenied(`C14 ${who} : ${n} refusé`, sql);
  }
  await as(LEG_S);
  for (const [n, sql] of [
    ['moderation_posts_list', `select moderation_posts_list('pending', 10)`], ['comment_reports_list', `select comment_reports_list(10)`],
    ['admin_mfa_reset', `select admin_mfa_reset('${C}', 'identité vérifiée par téléphone ok')`], ['admin_users', `select admin_users(null, 10)`],
    ['order_refund_decide', `select order_refund_decide('${p1}', 'reject', 'refus motivé')`], ['pickups_list', `select pickups_list(10)`], ['documents_to_review', `select documents_to_review('pending', 10)`],
    ['support_ticket_reply', `select support_ticket_reply('${p1}', 'Merci')`],
  ]) await guardDenied(`C15 support hérité : ${n} refusé`, sql);
  await as(LEG_X);
  await guardPassed('C16 attribution explicite : validation de paiement permise', `select payment_set_status('${p4}', 'confirmed')`);
  await guardDenied('C17 attribution explicite : mais pas les virements (non attribués)', `select momo_prepare_transfer('${p1}', '690000000', 1000, 'x', 'idem')`);

  // tableau de bord : lecture minimale
  await as(LEG_F);
  const dashMin = (await q(`select admin_team_dashboard('finance') r`))[0].r;
  check('C18 compte minimal : lit son tableau de bord, sans aucun indicateur (aucune permission)', dashMin.team.code === 'finance' && dashMin.counters.length === 0 && dashMin.minimal === true, JSON.stringify(dashMin));
  await guardDenied('C19 compte finance minimal : le tableau de bord d\'une AUTRE équipe est refusé', `select admin_team_dashboard('support')`);
  const accMin = (await q(`select my_admin_access() r`))[0].r;
  check('C20 my_admin_access : équipe visible, zéro permission', Object.keys(accMin.teams).join() === 'finance' && accMin.teams.finance.length === 0 && accMin.is_admin === false, JSON.stringify(accMin));
  await as(LEG_X);
  const dashX = (await q(`select admin_team_dashboard('finance') r`))[0].r;
  check('C21 compte explicite : indicateurs limités à ses permissions (paiements, retraits, pas de séquestre)', dashX.minimal === false && dashX.counters.some((c) => c.key === 'payments_pending') && !dashX.counters.some((c) => c.key === 'escrow_held'), JSON.stringify(dashX.counters));
  await as(C);
  await guardDenied('C22 client : tableau de bord d\'équipe refusé', `select admin_team_dashboard('finance')`);
  await sup(); await db.exec(`reset role; set role anon`);
  await guardDenied('C23 anonyme : tableau de bord refusé', `select admin_team_dashboard('finance')`);

  // liste « à réviser »
  await as(A);
  const rev = (await q(`select admin_team_accounts_review() r`))[0].r;
  const rv = (uid) => rev.find((x) => x.user_id === uid);
  check('C24 liste à réviser : comptes hérités signalés (needs_review) avec leurs permissions d\'avant', rv(LEG_F)?.needs_review === true && rv(LEG_S)?.needs_review === true && rv(LEG_ADM)?.needs_review === true
    && rv(LEG_F).previous.some((p) => p.team === 'finance' && p.permissions.includes('finance.payments')), JSON.stringify(rv(LEG_F)));
  check('C25 liste à réviser : le compte attribué explicitement n\'est pas à réviser', rv(LEG_X)?.needs_review === false && rv(LEG_X).teams[0].explicit === true);
  check('C26 liste à réviser : nouveaux comptes minimaux à réviser aussi, rôles finance / support uniquement', rv(FMIN)?.needs_review === true && !rv(C) && !rv(A) && rev.every((x) => ['finance', 'support'].includes(x.role)));
  check('C27 liste triée : à réviser d\'abord', rev[0].needs_review === true);
  for (const [who, uid] of [['finance', AF], ['support', AS], ['direction', DIR], ['département', D], ['client', C], ['étudiant', ST], ['hérité', LEG_F]]) {
    await as(uid); await fails(`C28 ${who} : liste à réviser refusée`, `select admin_team_accounts_review()`, /administrateur global/);
  }
  await sup(); await db.exec(`reset role; set role anon`);
  await fails('C29 anonyme : liste à réviser refusée', `select admin_team_accounts_review()`, /Connexion requise|permission denied|administrateur global/);
  // l'attribution explicite sort le compte de la liste
  await grant(LEG_F, 'finance', ['finance.read', 'finance.payments']);
  await as(A);
  const rev2 = (await q(`select admin_team_accounts_review() r`))[0].r;
  check('C30 attribution explicite : le compte n\'est plus à réviser', rev2.find((x) => x.user_id === LEG_F).needs_review === false);
  await as(LEG_F);
  await guardPassed('C31 … et ses droits ne couvrent que ce qui lui a été attribué (paiements)', `select payments_to_verify()`);
  await guardDenied('C32 … pas les retraits', `select payout_create('${ST}', 1000)`);

  // ============================================================ équipes pour la suite
  await grant(AF, 'finance', ALL.finance);
  await grant(AS, 'support', ALL.support);
  await grant(ASEC, 'security', ALL.security);
  await grant(ATECH, 'tech', ALL.tech);
  await grant(F1, 'finance', ['finance.payments']);
  await grant(S1, 'support', ['support.tickets']);
  await sup(); await db.exec(`update profiles set suspended = false where id = '${SUSP}'`);
  await grant(SUSP, 'support', ['support.tickets', 'support.requests']);
  await sup(); await db.exec(`update profiles set suspended = true where id = '${SUSP}'`);

  // ============================================================ B. notifications par permission
  await sup();
  const AG = { admin: A, admin2: A2, AF, AS, ASEC, ATECH, FMIN, SMIN, F1, S1, SUSP };
  const recips = async (perms) => (await qs(`select array_agg(r) a from _team_recipients(${arr(perms)}) r`))[0].a ?? [];
  const r1 = await recips(['finance.payments']);
  check('B1 finance.payments : admin(s), agents avec la permission (AF, F1) ; PAS le compte minimal, pas le support', r1.includes(A) && r1.includes(A2) && r1.includes(AF) && r1.includes(F1) && !r1.includes(FMIN) && !r1.includes(AS) && !r1.includes(S1) && !r1.includes(LEG_ADM));
  check('B2 un compte suspendu est exclu même avec la permission', !(await recips(['support.tickets'])).includes(SUSP));
  const r3 = await recips(['support.tickets']);
  check('B3 support.tickets : AS et S1 ; pas SMIN, pas finance, pas sécurité/technique', r3.includes(AS) && r3.includes(S1) && !r3.includes(SMIN) && !r3.includes(AF) && !r3.includes(ASEC) && !r3.includes(ATECH));
  check('B4 client, étudiant, département, direction jamais destinataires, quelle que soit la permission demandée', !(await recips([...ALL.finance, ...ALL.support, ...ALL.security, ...ALL.tech])).some((u) => [C, C2, ST, D, DIR].includes(u)));
  check('B5 liste de permissions vide ou nulle : seulement les administrateurs', (await recips([])).every((u) => [A, A2, M2FA].includes(u)) && (await qs(`select count(*)::int n from _team_recipients(null)`))[0].n === (await recips([])).length);
  // effet immédiat
  await grant(F1, 'finance', ['finance.read']);
  check('B6 permission retirée : n\'est plus destinataire à l\'envoi suivant', !(await recips(['finance.payments'])).includes(F1) && (await recips(['finance.read'])).includes(F1));
  await as(A); await q(`select admin_team_member_remove('${F1}', 'finance')`);
  check('B7 agent retiré de l\'équipe : plus destinataire', !(await recips(['finance.read'])).includes(F1));
  await grant(F1, 'finance', ['finance.payments']);
  check('B8 permission attribuée : destinataire immédiatement', (await recips(['finance.payments'])).includes(F1));
  const n1 = (await qs(`select notify_team_permission(array['finance.payments'], 'payment', 'K1 test direct', 'corps', '{"x":1}'::jsonb, '${AF}') n`))[0].n;
  check('B9 notify_team_permission : insère pour les destinataires, hors exclu', n1 === (await recips(['finance.payments'])).filter((u) => u !== AF).length && (await notifCount(F1, 'K1 test direct')) === 1 && (await notifCount(AF, 'K1 test direct')) === 0 && (await notifCount(A, 'K1 test direct')) === 1);
  await as(C);
  await fails('B10 un client ne peut pas appeler _team_recipients', `select * from _team_recipients(array['finance.payments'])`, /permission denied/);
  await fails('B11 un client ne peut pas appeler notify_team_permission', `select notify_team_permission(array['finance.payments'], 'x', 'y', 'z')`, /permission denied/);
  await as(AF);
  await fails('B12 un agent ne peut pas appeler notify_team_permission', `select notify_team_permission(array['finance.payments'], 'x', 'y', 'z')`, /permission denied/);
  await sup(); await db.exec(`reset role; set role anon`);
  await fails('B13 anonyme : pas d\'accès aux destinataires', `select * from _team_recipients(array['finance.payments'])`, /permission denied/);
  await sup();

  // flux réels : qui est prévenu ?
  const snap = async () => { const m = {}; for (const [k, u] of Object.entries(AG)) m[k] = (await qs(`select count(*)::int n from notifications where user_id = '${u}'`))[0].n; return m; };
  const delta = (a, b) => Object.fromEntries(Object.keys(a).map((k) => [k, b[k] - a[k]]));
  let s0 = await snap();
  await as(C); await q(`select support_ticket_create('Besoin d aide K1', 'Bonjour, ma commande est bloquée depuis hier soir')`);
  let d = delta(s0, await snap());
  check('B14 demande d\'aide : prévenus = admins + agents support.tickets (AS, S1) ; ni finance, ni sécurité, ni technique, ni agent minimal, ni suspendu', d.admin === 1 && d.admin2 === 1 && d.AS === 1 && d.S1 === 1 && d.AF === 0 && d.ASEC === 0 && d.ATECH === 0 && d.SMIN === 0 && d.FMIN === 0 && d.F1 === 0 && d.SUSP === 0, JSON.stringify(d));
  s0 = await snap();
  await sup(); await db.exec(`update payment_transactions set status = 'created' where id = '${p2}'`);
  await as(C); await q(`select payment_declare('${p2}', 'REF-K1-001')`);
  d = delta(s0, await snap());
  check('B15 paiement déclaré : prévenus = admins + agents finance.payments (AF, F1) ; ni le support, ni le finance minimal', d.admin === 1 && d.AF === 1 && d.F1 === 1 && d.FMIN === 0 && d.AS === 0 && d.S1 === 0 && d.SMIN === 0, JSON.stringify(d));
  s0 = await snap();
  await as(C2); await q(`select request_account_deletion('Je souhaite fermer mon compte K1')`);
  d = delta(s0, await snap());
  check('B16 suppression de compte demandée : prévenus = admins + agents support.requests (AS, SUSP exclu car suspendu) ; pas S1 (tickets seulement)', d.admin === 1 && d.AS === 1 && d.S1 === 0 && d.SUSP === 0 && d.AF === 0 && d.ASEC === 0, JSON.stringify(d));
  s0 = await snap();
  await sup(); await db.exec(`insert into posts (id, author_id, kind, body, status, published_at) values ('${id(80)}', '${ST}', 'text', 'Publication K1 à signaler', 'published', now())`);
  await as(C); await q(`select report_post('${id(80)}', 'contenu inapproprié K1')`);
  d = delta(s0, await snap());
  check('B17 publication signalée : prévenus = admins + agents security.reports (ASEC) ; pas le support, pas la finance, pas la technique', d.admin === 1 && d.ASEC === 1 && d.AS === 0 && d.S1 === 0 && d.AF === 0 && d.ATECH === 0, JSON.stringify(d));
  // révocation effective sur flux réel
  await grant(S1, 'support', ['support.claims']);
  s0 = await snap();
  await as(C); await q(`select support_ticket_create('Deuxième demande K1', 'Bonjour, ma deuxième demande est ici merci')`);
  d = delta(s0, await snap());
  check('B18 permission support.tickets révoquée (S1 garde seulement claims) : S1 n\'est plus prévenu des demandes d\'aide, AS toujours', d.S1 === 0 && d.AS === 1, JSON.stringify(d));
  await grant(S1, 'support', ['support.tickets']);
  // suspension
  await as(A); await q(`select admin_set_account('${AS}', 'support', true)`);
  s0 = await snap();
  await as(C); await q(`select support_ticket_create('Troisième demande K1', 'Bonjour, ma troisième demande est ici merci')`);
  d = delta(s0, await snap());
  check('B19 agent suspendu : plus prévenu (effet immédiat)', d.AS === 0 && d.S1 === 1, JSON.stringify(d));
  await as(A); await q(`select admin_set_account('${AS}', 'support', false)`);
  // analyse statique : plus aucun filtre de destinataires par rôle seul
  await sup();
  // seule exception : claim_referral (liste d'EXCLUSION des parrainages du personnel, aucune notification à ces rôles)
  const left = await q(`select p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname <> 'claim_referral'
    and pg_get_functiondef(p.oid) ~* $re$role::text\\s+(not\\s+)?(in\\s*\\([^)]*|=\\s*)'(finance|support)'$re$
    and pg_get_functiondef(p.oid) ~* '(insert into notifications|notify_user)' order by 1`);
  check('B20 plus aucune fonction n\'envoie de notification à « tous les finance/support » par le seul rôle', left.length === 0, left.map((x) => x.proname).join(','));
  const patched = (await q(`select count(*)::int n from pg_proc p where p.pronamespace = 'public'::regnamespace and pg_get_functiondef(p.oid) like '%_team_recipients(%' and p.proname <> 'notify_team_permission'`))[0].n;
  check('B21 les 31 fonctions d\'envoi (et leurs aides) passent par _team_recipients', patched >= 31, String(patched));
  const notDefiner = (await q(`select p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace and pg_get_functiondef(p.oid) like '%_team_recipients(%' and not p.prosecdef`)).length;
  check('B22 toutes sont security definer (l\'aide reste inaccessible aux clients)', notDefiner === 0);

  // ============================================================ D. effet immédiat, historique, isolement
  await sup();
  await db.exec(`insert into support_tickets (user_id, subject, message) values ('${C}', 'Aide K1', 'Ma commande est bloquée depuis hier merci')`);
  const tk = (await qs(`select id from support_tickets where subject = 'Aide K1' limit 1`))[0].id;
  await as(S1);
  await guardPassed('D1 support.tickets : répondre à une demande', `select support_ticket_reply('${tk}', 'Nous regardons')`);
  await as(A); await q(`select admin_team_member_remove('${S1}', 'support', 'fin de mission K1')`);
  await as(S1);
  await guardDenied('D2 retrait : refusé IMMÉDIATEMENT (même session)', `select support_ticket_reply('${tk}', 'Encore')`);
  await grant(S1, 'support', ['support.tickets']);
  await as(S1);
  await guardPassed('D3 ré-attribution : accepté immédiatement', `select support_ticket_reply('${tk}', 'Merci')`);
  await grant(S1, 'support', ['support.claims']);
  await as(S1);
  await guardDenied('D4 modification (tickets retiré) : refusé immédiatement', `select support_ticket_reply('${tk}', 'Encore')`);
  await grant(S1, 'support', ['support.tickets', 'support.claims']);
  await as(A); await q(`select admin_set_account('${S1}', 'support', true)`);
  await as(S1);
  await guardDenied('D5 suspension : refusé immédiatement', `select support_ticket_reply('${tk}', 'Encore')`);
  await as(A); await q(`select admin_set_account('${S1}', 'support', false)`);
  await as(S1);
  await guardPassed('D6 levée de la suspension : droits rétablis (aucune perte d\'attribution)', `select support_ticket_reply('${tk}', 'Re')`);
  // historique + audit
  await as(A);
  const hist = (await q(`select admin_team_history_list('${S1}', 50) r`))[0].r;
  const acts = hist.map((h) => h.action);
  check('D7 historique S1 : auto_enroll, grant, revoke, grant, update… dans l\'ordre (plus récent d\'abord)', ['auto_enroll', 'grant', 'revoke', 'update'].every((a) => acts.includes(a)) && hist[0].action === 'update' && hist[0].actor === 'Ada Admin', JSON.stringify(acts));
  check('D8 historique : motif et permissions avant / après enregistrés', hist.some((h) => h.action === 'revoke' && h.note === 'fin de mission K1' && h.before.includes('support.tickets') && h.after.length === 0)
    && hist.some((h) => h.action === 'update' && h.before.includes('support.claims') && h.after.includes('support.tickets')));
  check('D9 audit_log : une ligne Critique par attribution / modification / retrait', (await qs(`select count(*)::int n from audit_log where category = 'Équipes' and level = 'Critique' and target like 'Suzy%'`))[0].n >= 5
    && (await qs(`select count(*)::int n from audit_log where action = 'Équipe : agent retiré' and target like 'Suzy%'`))[0].n === 1);
  check('D10 l\'agent est notifié de chaque changement', (await notifCount(S1, 'Vos permissions d\'équipe ont changé')) >= 2 && (await notifCount(S1, 'Vous quittez une équipe d\'administration')) === 1);
  for (const [who, uid] of [['finance', AF], ['support', AS], ['sécurité', ASEC], ['technique', ATECH], ['minimal', FMIN], ['client', C], ['département', D], ['direction', DIR], ['étudiant', ST]]) {
    await as(uid);
    check(`D11 ${who} : ne lit ni l\'historique des équipes (table) ni l\'audit des équipes ni la liste des membres`, (await q(`select count(*)::int n from admin_team_history`))[0].n === 0
      && (await q(`select count(*)::int n from admin_team_members where user_id <> '${uid}'`))[0].n === 0);
    await fails(`D12 ${who} : admin_team_history_list refusé`, `select admin_team_history_list(null, 10)`, /administrateur global/);
    await fails(`D13 ${who} : s'attribuer / attribuer des droits refusé`, `select admin_team_member_set('${uid}', 'finance', array['finance.read'])`, /administrateur global|propres droits/);
  }
  await sup(); await db.exec(`reset role; set role anon`);
  await fails('D14 anonyme : historique refusé', `select admin_team_history_list(null, 10)`, /Connexion requise|permission denied|administrateur global/);
  await fails('D15 anonyme : attribution refusée', `select admin_team_member_set('${AF}', 'finance', array['finance.read'])`, /Connexion requise|permission denied|administrateur global/);
  await as(A);
  await fails('D16 l\'administrateur ne modifie pas ses propres droits', `select admin_team_member_set('${A}', 'finance', array['finance.read'])`, /propres droits/);

  // matrice équipe x fonction sensible : chaque agent (toutes les permissions de SON équipe) ne passe que les gardes de son équipe
  await sup();
  const pid = p1;
  const FN = [
    ['finance_overview', `select finance_overview()`, ['finance.read']],
    ['money_admin_overview', `select money_admin_overview()`, ['finance.read']],
    ['payments_to_verify', `select payments_to_verify()`, ['finance.payments']],
    ['payment_set_status', `select payment_set_status('${p3}', 'refused')`, ['finance.payments']],
    ['payout_create', `select payout_create('${ST}', 1000)`, ['finance.payouts']],
    ['payout_set_status', `select payout_set_status('${pid}', 'verse', 'REF-1', null)`, ['finance.payouts']],
    ['momo_prepare_transfer', `select momo_prepare_transfer('${pid}', '690000000', 1000, 'x', 'idem')`, ['finance.transfers']],
    ['order_refund_set_paid', `select order_refund_set_paid('${pid}', 'REF123')`, ['finance.refunds']],
    ['money_freeze', `select money_freeze('${pid}', 'motif')`, ['finance.split']],
    ['money_split_set', `select money_split_set(60, 25, 15, 'essai')`, ['finance.split']],
    ['support_ticket_reply', `select support_ticket_reply('${tk}', 'Bonjour')`, ['support.tickets']],
    ['claim_decide', `select claim_decide('${tk}', 'release', 'non retenu')`, ['support.claims']],
    ['dispute_close', `select dispute_close('${tk}', 'x')`, ['support.disputes']],
    ['pickups_list', `select pickups_list(10)`, ['support.orders']],
    ['documents_to_review', `select documents_to_review('pending', 10)`, ['support.requests']],
    ['order_refund_decide', `select order_refund_decide('${tk}', 'reject', 'refus motivé')`, ['finance.refunds', 'support.refunds']],
    ['moderation_posts_list', `select moderation_posts_list('pending', 10)`, ['security.moderation']],
    ['comment_reports_list', `select comment_reports_list(10)`, ['security.reports']],
    ['admin_mfa_reset', `select admin_mfa_reset('${C}', 'identité vérifiée par téléphone ok')`, ['security.accounts']],
    ['security_flags_list', `select security_flags_list('open')`, ['security.accounts']],
    ['setting_set', `select setting_set('app.test', '1'::jsonb)`, ['tech.config']],
    ['create_api_key', `select create_api_key('ma clé test')`, ['tech.integrations']],
    ['kiosk_provision', `select kiosk_provision('borne-1')`, ['support.orders', 'tech.maintenance']],
  ];
  const AGENTS = [['finance', AF, ALL.finance], ['support', AS, ALL.support], ['sécurité', ASEC, ALL.security], ['technique', ATECH, ALL.tech], ['finance minimal', FMIN, []], ['support minimal', SMIN, []]];
  let cells = 0, wrong = [];
  for (const [label, uid, ps] of AGENTS) {
    await as(uid);
    for (const [name, sql, need] of FN) {
      const allowed = need.some((p) => ps.includes(p));
      let passed;
      try { await q(sql); passed = true; } catch (e) { passed = !DENY.test(e.message); }
      cells++;
      if (passed !== allowed) wrong.push(`${label} x ${name} attendu ${allowed ? 'permis' : 'refusé'}`);
    }
  }
  check(`D17 matrice ${AGENTS.length} agents x ${FN.length} fonctions sensibles (${cells} cellules) : accès exactement conforme aux permissions de l'équipe`, wrong.length === 0, wrong.join(' ; '));
  // administrateur : toutes les cellules passent ; autres rôles : aucune
  await as(A); let adminOk = 0;
  for (const [name, sql] of FN) { try { await q(sql); adminOk++; } catch (e) { if (!DENY.test(e.message)) adminOk++; } }
  check('D18 administrateur global : toutes les gardes franchies', adminOk === FN.length);
  for (const [label, uid] of [['client', C], ['département', D], ['direction', DIR], ['étudiant', ST], ['suspendu', SUSP]]) {
    await as(uid); let denied = 0, list = [];
    // le département garde, dans SON périmètre (lot H2, prouvé par act_h2.mjs), la file de modération, les signalements, les retraits en borne et les pièces à examiner
    const deptScope = ['pickups_list', 'documents_to_review', 'moderation_posts_list', 'comment_reports_list'];
    for (const [name, sql, need] of FN) {
      try { await q(sql); if ((label === 'direction' && name === 'finance_overview') || (label === 'département' && deptScope.includes(name))) { denied++; } else list.push(name); } catch (e) { if (DENY.test(e.message)) denied++; else list.push(name); }
    }
    check(`D19 ${label} : aucune fonction sensible d'équipe accessible (hors lecture consolidée de la direction et périmètre département H2)`, denied === FN.length, list.join(','));
  }
  await sup(); await db.exec(`reset role; set role anon`);
  let anonDenied = 0;
  for (const [name, sql] of FN) { try { await q(sql); } catch (e) { if (DENY.test(e.message)) anonDenied++; } }
  check('D20 anonyme : toutes les fonctions sensibles refusées', anonDenied === FN.length, `${anonDenied}/${FN.length}`);

  // lectures directes (RLS) : un agent sans permission ne lit pas les données des autres équipes
  await sup();
  await db.exec(`insert into posts (author_id, kind, body, status) values ('${ST}', 'text', 'Post en attente K1', 'pending')`);
  const cnt = async (sql) => (await q(sql))[0].n;
  const tables = [
    ['payment_transactions (finance, et support.claims / support.disputes par conception H4)', `select count(*)::int n from payment_transactions`, { AF: true, AS: true, ASEC: false, ATECH: false, FMIN: false, SMIN: false }],
    ['support_tickets', `select count(*)::int n from support_tickets`, { AF: false, AS: true, ASEC: false, ATECH: false, FMIN: false, SMIN: false }],
    ['posts (publication en attente)', `select count(*)::int n from posts where status = 'pending'`, { AF: false, AS: false, ASEC: true, ATECH: false, FMIN: false, SMIN: false }],
    ['profiles (autres comptes)', `select count(*)::int n from profiles where id <> auth.uid()`, { AF: false, AS: true, ASEC: true, ATECH: false, FMIN: false, SMIN: false }],
  ];
  for (const [label, sql, exp] of tables) {
    for (const [k, uid] of [['AF', AF], ['AS', AS], ['ASEC', ASEC], ['ATECH', ATECH], ['FMIN', FMIN], ['SMIN', SMIN]]) {
      await as(uid);
      check(`D21 ${label} : ${k} ${exp[k] ? 'lit' : 'ne lit pas'}`, exp[k] ? (await cnt(sql)) > 0 : (await cnt(sql)) === 0);
    }
  }
  await as(A);
  check('D22 administrateur lit tout (profils, publications, paiements)', (await cnt(`select count(*)::int n from profiles where id <> auth.uid()`)) > 5 && (await cnt(`select count(*)::int n from posts where status = 'pending'`)) > 0 && (await cnt(`select count(*)::int n from payment_transactions`)) > 0);
  await as(C);
  check('D23 un client ne lit toujours que ses propres paiements / demandes d\'aide', (await cnt(`select count(*)::int n from payment_transactions where payer_id <> auth.uid()`)) === 0 && (await cnt(`select count(*)::int n from support_tickets where user_id <> auth.uid()`)) === 0);
  await as(ST);
  check('D24 un étudiant voit toujours ses propres publications en attente', (await cnt(`select count(*)::int n from posts where author_id = auth.uid() and status = 'pending'`)) === 1);
  await sup(); await db.exec(`reset role; set role anon`);
  check('D25 anonyme : ne lit ni paiements, ni demandes d\'aide, ni historique d\'équipe', await (async () => { for (const t of ['payment_transactions', 'support_tickets', 'admin_team_history', 'admin_team_members']) { try { const n = await cnt(`select count(*)::int n from ${t}`); if (n > 0) return false; } catch { /* refus */ } } return true; })());
  // les lectures PUBLIQUES (politiques réécrites) doivent rester possibles pour l'anonyme, sans erreur de permission
  for (const t of ['listings', 'shops', 'posts', 'post_comments', 'profiles']) {
    let err = null; try { await cnt(`select count(*)::int n from ${t}`); } catch (e) { err = e.message; }
    check(`D26 anonyme : lecture de ${t} sans erreur (politique réécrite exécutable par anon)`, err === null, err);
  }
  await sup(); await db.exec(`reset role; set role anon`);
  check('D28 anonyme : ne voit pas la publication en attente (modération)', (await cnt(`select count(*)::int n from posts where status = 'pending'`)) === 0);

  // ============================================================ E. rejeu des migrations K1 (idempotence)
  await sup();
  for (const f of ['20261121010100_k1_notifications_par_permission.sql', '20261121010200_k1_droits_minimaux_heritage.sql', '20261121010300_k1_isolation_lectures_equipes.sql']) {
    try { await db.exec(mig(f)); check(`E1 ${f} rejouée sans erreur`, true); } catch (e) { check(`E1 ${f} rejouée sans erreur`, false, e.message); }
  }
  check('E2 le rejeu ne change pas les droits explicites', JSON.stringify(await perms(LEG_X, 'finance')) === JSON.stringify(['finance.payments', 'finance.payouts']) && JSON.stringify(await perms(AF, 'finance')) === JSON.stringify([...ALL.finance].sort()));

  console.log(`fin_k1 : ${ok} OK, ${ko} ECHEC`);
  console.log(`${ok}/${ok + ko}`);
}
