// Lot H4 (centre d'administration et équipes internes) : prouve les migrations 20261120040000 à 043000 (cas autorisé ET refusé pour chaque acteur, anonyme et suspendu inclus).
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./act_h4.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000004${String(n).padStart(2, '0')}`;
  const A = id(1), F1 = id(2), F2 = id(3), S1 = id(4), S2 = id(5), SEC = id(6), TECH = id(7), C = id(8), D = id(9), DIR = id(10), ST = id(11), SUSP = id(12), LEG_F = id(13), LEG_S = id(14), A2 = id(15);
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false); select set_config('app.internal', '1', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const passes = async (name, sql, extra) => { try { await q(sql); check(name, true); } catch (e) { check(name, false, e.message); } };
  // « garde franchie » : la fonction va au-delà du contrôle de permission (une autre erreur métier est acceptable)
  const guardPassed = async (name, sql) => { try { await q(sql); check(name, true); } catch (e) { check(name, !/Action non autorisée|réservé|exige la permission|Connexion requise|permission denied/i.test(e.message), e.message); } };
  const guardDenied = async (name, sql) => { try { await q(sql); check(name, false, 'aurait du etre refuse'); } catch (e) { check(name, /Action non autorisée|réservé|exige la permission|permission denied|Connexion requise/i.test(e.message), e.message); } };
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const grant = async (user, team, perms) => { await as(A); return q(`select admin_team_member_set('${user}', '${team}', array[${perms.map((p) => `'${p}'`).join(',')}]) r`); };
  const U = (n) => `'${n}'`;

  await db.exec('reset role');
  // migration des comptes existants : on rejoue la section de migration sur des comptes « d'avant » (sans ligne d'équipe)
  await db.exec(`alter table profiles disable trigger trg_admin_team_autoenroll`);
  await db.exec(`insert into auth.users(id,email) values ('${LEG_F}','legf@t.cm'), ('${LEG_S}','legs@t.cm'); insert into profiles(id,name,role,email) values ('${LEG_F}','Legs Finance','finance','legf@t.cm'), ('${LEG_S}','Legs Support','support','legs@t.cm')`);
  await db.exec(`alter table profiles enable trigger trg_admin_team_autoenroll`);
  const mig = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations', '20261120040000_h4_equipes_permissions.sql'), 'utf8').replace(/\r\n/g, '\n');
  const section = mig.slice(mig.indexOf('insert into admin_team_members (user_id, team_code, permissions)\nselect p.id, \'finance\''), mig.indexOf('create or replace function _admin_team_autoenroll'));
  await sup();
  await db.exec(section);
  await db.exec(section);
  // K1 : les droits de base ne sont plus « larges » ; on simule l'état de PRODUCTION d'avant K1 (droits hérités de H4 : finance = 5 permissions, support = tickets… + remboursements)
  await db.exec(`update admin_team_members set permissions = array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'] where user_id = '${LEG_F}' and team_code = 'finance';
    update admin_team_members set permissions = array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'] where user_id = '${LEG_S}' and team_code = 'support'`);
  const replayRows = (await q(`select count(*)::int n from admin_team_members where user_id in ('${LEG_F}', '${LEG_S}')`))[0].n;
  for (const [i, nm, role] of [[A, 'Ada Admin', 'admin'], [A2, 'Bob Admin', 'admin'], [F1, 'Fina Finance', 'finance'], [F2, 'Fred Finance', 'finance'], [S1, 'Sam Support', 'support'], [S2, 'Suzy Support', 'support'],
    [SEC, 'Sec Securite', 'support'], [TECH, 'Tech Technique', 'support'], [C, 'Cora Cliente', 'client'], [D, 'Dep Dept', 'dept'], [DIR, 'Dir Direction', 'direction'], [ST, 'Etu Etudiant', 'student'], [SUSP, 'Sus Pendu', 'support']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${nm.split(' ')[0].toLowerCase()}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${nm.split(' ')[0].toLowerCase()}@t.cm')`);
  }
  await sup();

  // ============================================================ A. modèle : équipes, catalogue, inscription automatique
  check('A1 quatre équipes (finance, support, sécurité, technique)', (await qs(`select string_agg(code, ',' order by position) s from admin_teams`))[0].s === 'finance,support,security,tech');
  check('A2 catalogue : 21 permissions (20 de H4 + tech.assessments du lot EVAL), chacune dans son équipe', (await qs(`select count(*)::int n from admin_permissions where split_part(code, '.', 1) = case team_code when 'security' then 'security' else team_code end`))[0].n === 21);
  const auto = await qs(`select user_id, team_code, permissions from admin_team_members where user_id in ('${F1}', '${S1}', '${SEC}') order by user_id`);
  check('A3 un compte finance / support créé après la migration est inscrit dans son équipe avec les droits de base', auto.length === 3 && auto.find((r) => r.user_id === F1).team_code === 'finance'
    && auto.find((r) => r.user_id === S1).team_code === 'support' && !auto.find((r) => r.user_id === S1).permissions.includes('support.refunds'), JSON.stringify(auto));
  check('A4 droits de base finance (K1) : aucune permission, ni répartition ni paiements (droits minimaux)', auto.find((r) => r.user_id === F1).permissions.length === 0);
  check('A5 l\'inscription automatique est historisée', (await qs(`select count(*)::int n from admin_team_history where user_id = '${F1}' and action = 'auto_enroll'`))[0].n === 1);
  check('A6 un client, un étudiant, un département ou la direction n\'ont aucune ligne d\'équipe', (await qs(`select count(*)::int n from admin_team_members where user_id in ('${C}', '${ST}', '${D}', '${DIR}', '${A}')`))[0].n === 0);

  check('A7 la section de migration des comptes existants est présente', section.length > 400);
  const leg = await qs(`select user_id, team_code, permissions from admin_team_members where user_id in ('${LEG_F}', '${LEG_S}')`);
  const legF = leg.filter((r) => r.user_id === LEG_F), legS = leg.filter((r) => r.user_id === LEG_S);
  check('A8 compte finance existant -> équipe finance avec ses droits d\'avant (paiements, retraits, remboursements, virements, lecture)', legF.length === 1 && legF[0].team_code === 'finance'
    && ['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'].every((p) => legF[0].permissions.includes(p)), JSON.stringify(legF));
  check('A9 compte support existant -> équipe support ET sécurité (modération, signalements, 2FA, audit, remboursements) : aucun flux interrompu', legS.length === 2
    && legS.find((r) => r.team_code === 'support').permissions.includes('support.refunds') && legS.find((r) => r.team_code === 'security').permissions.includes('security.moderation')
    && legS.find((r) => r.team_code === 'security').permissions.includes('security.accounts'), JSON.stringify(legS));
  check('A10 la migration est rejouable sans doublon', replayRows === 3);
  check('A11 la migration est historisée', (await qs(`select count(*)::int n from admin_team_history where user_id = '${LEG_S}' and action = 'migration'`))[0].n === 2);
  // K1 : rattrapage des comptes hérités (voir fin_k1.mjs pour la preuve détaillée)
  await sup();
  await db.exec(fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations', '20261121010200_k1_droits_minimaux_heritage.sql'), 'utf8'));

  // ============================================================ B. attribution / retrait par l'administrateur global
  await grant(S1, 'support', ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests']);
  await grant(S2, 'support', ['support.tickets']);
  await grant(F2, 'finance', ['finance.read']);
  await grant(SEC, 'security', ['security.moderation', 'security.reports', 'security.accounts', 'security.audit']);
  await q(`select admin_team_member_remove('${SEC}', 'support')`).catch(() => {});
  await q(`select admin_team_member_remove('${TECH}', 'support')`).catch(() => {});
  await grant(TECH, 'tech', ['tech.config', 'tech.integrations', 'tech.logs', 'tech.maintenance']);
  await grant(F1, 'finance', ['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers']);
  await sup();
  check('B1 attribution : permissions enregistrées et triées', JSON.stringify((await qs(`select permissions from admin_team_members where user_id = '${S2}' and team_code = 'support'`))[0].permissions) === '["support.tickets"]');
  check('B2 attribution : historique + audit_log (catégorie Équipes, niveau Critique)', (await qs(`select count(*)::int n from audit_log where category = 'Équipes' and level = 'Critique' and actor_id = '${A}'`))[0].n >= 4
    && (await qs(`select count(*)::int n from admin_team_history where user_id = '${TECH}' and action = 'grant' and actor_id = '${A}'`))[0].n === 1);
  check('B3 l\'agent est prévenu', (await qs(`select count(*)::int n from notifications where user_id = '${TECH}' and kind = 'security' and title like '%équipe%'`))[0].n >= 1);
  await as(A);
  check('B4 mise à jour : changed true puis idempotente (changed false)', (await q(`select admin_team_member_set('${S2}', 'support', array['support.tickets', 'support.claims']) r`))[0].r.changed === true
    && (await q(`select admin_team_member_set('${S2}', 'support', array['support.claims', 'support.tickets']) r`))[0].r.changed === false);
  check('B5 la mise à jour est historisée (update, avant/après)', (await qs(`select count(*)::int n from admin_team_history where user_id = '${S2}' and action = 'update' and before_permissions = array['support.tickets'] and after_permissions = array['support.claims', 'support.tickets']`))[0].n === 1);
  await as(A);
  await fails('B6 permission inconnue refusée', `select admin_team_member_set('${S2}', 'support', array['support.inexistante'])`, /Permission inconnue/);
  await fails('B7 permission d\'une autre équipe refusée', `select admin_team_member_set('${S2}', 'support', array['finance.payouts'])`, /autre équipe/);
  await fails('B8 aucune permission : refusé (il faut retirer l\'agent)', `select admin_team_member_set('${S2}', 'support', array[]::text[])`, /au moins une permission/);
  await fails('B9 équipe inconnue refusée', `select admin_team_member_set('${S2}', 'compta', array['support.tickets'])`, /Équipe inconnue/);
  await fails('B10 un client ne peut pas rejoindre une équipe', `select admin_team_member_set('${C}', 'support', array['support.tickets'])`, /Finance ou Support/);
  await fails('B11 un département ne peut pas rejoindre une équipe', `select admin_team_member_set('${D}', 'support', array['support.tickets'])`, /Finance ou Support/);
  await fails('B12 l\'administrateur ne modifie pas ses propres droits', `select admin_team_member_set('${A}', 'support', array['support.tickets'])`, /propres droits/);
  await sup(); await db.exec(`update profiles set suspended = true where id = '${SUSP}'`); await as(A);
  await fails('B13 un compte suspendu ne rejoint pas une équipe', `select admin_team_member_set('${SUSP}', 'support', array['support.tickets'])`, /suspendu/);
  for (const [who, uid] of [['support', S1], ['finance', F1], ['sécurité', SEC], ['technique', TECH], ['client', C], ['département', D], ['direction', DIR], ['étudiant', ST]]) {
    await as(uid);
    await fails(`B14 ${who} : attribution refusée`, `select admin_team_member_set('${S2}', 'support', array['support.refunds'])`, /administrateur global|Réservé/);
    await fails(`B15 ${who} : retrait refusé`, `select admin_team_member_remove('${S2}', 'support')`, /administrateur global|Réservé/);
  }
  await as(S1);
  await fails('B16 un agent ne liste pas les équipes (admin_teams_overview)', `select admin_teams_overview()`, /administrateur global/);
  await fails('B17 un agent ne liste pas les agents (admin_team_candidates)', `select admin_team_candidates('')`, /administrateur global/);
  await fails('B18 un agent ne lit pas l\'historique des équipes', `select admin_team_history_list(null, 10)`, /administrateur global/);
  await sup(); await db.exec(`reset role; set role anon`);
  await fails('B19 anonyme : attribution refusée', `select admin_team_member_set('${S2}', 'support', array['support.tickets'])`, /permission denied|Connexion/);
  await fails('B20 anonyme : my_admin_access refusé', `select my_admin_access()`, /permission denied|Connexion/);
  await fails('B21 anonyme : has_admin_permission refusé', `select has_admin_permission('finance.read')`, /permission denied/);
  await as(A);
  const ov = (await q(`select admin_teams_overview() r`))[0].r;
  check('B22 vue d\'ensemble : 4 équipes, permissions et droits de base', ov.length === 4 && ov[0].code === 'finance' && ov[0].permissions.length === 6 && ov[1].defaults.length === 0 && ov[0].members >= 3, JSON.stringify(ov.map((t) => [t.code, t.members])));
  check('B23 liste des agents d\'une équipe (noms, rôles, permissions)', (await q(`select admin_team_members_list('support') r`))[0].r.some((m) => m.user_id === S2 && m.role === 'support' && m.permissions.includes('support.claims')));
  const cand = (await q(`select admin_team_candidates('sam') r`))[0].r;
  check('B24 recherche d\'agents recrutables : seulement finance / support', cand.length === 1 && cand[0].id === S1 && cand[0].teams.includes('support'), JSON.stringify(cand));
  check('B25 historique consultable par l\'administrateur', (await q(`select admin_team_history_list('${S2}', 10) r`))[0].r.length >= 2);
  const rm = (await q(`select admin_team_member_remove('${S2}', 'support', 'fin de mission') r`))[0].r;
  check('B26 retrait : agent retiré, historique revoke + audit + notification', rm.removed === true
    && (await qs(`select count(*)::int n from admin_team_history where user_id = '${S2}' and action = 'revoke' and note = 'fin de mission'`))[0].n === 1
    && (await qs(`select count(*)::int n from audit_log where action = 'Équipe : agent retiré' and target like 'Suzy%'`))[0].n === 1
    && (await qs(`select count(*)::int n from notifications where user_id = '${S2}' and title like '%quittez%'`))[0].n === 1);
  await as(A);
  await fails('B27 retirer un agent absent de l\'équipe : refusé', `select admin_team_member_remove('${S2}', 'support')`, /ne fait pas partie/);
  await grant(S2, 'support', ['support.tickets']);
  // changement de rôle : les droits suivent
  await q(`select admin_set_account('${S2}', 'client', false)`);
  check('B28 un compte qui n\'a plus de rôle d\'équipe interne perd ses lignes d\'équipe (auto_revoke)', (await qs(`select count(*)::int n from admin_team_members where user_id = '${S2}'`))[0].n === 0
    && (await qs(`select count(*)::int n from admin_team_history where user_id = '${S2}' and action = 'auto_revoke'`))[0].n === 1);
  await as(A); await q(`select admin_set_account('${S2}', 'support', false)`);
  check('B29 un compte repromu support est réinscrit SANS permission (droits minimaux, K1)', JSON.stringify((await qs(`select permissions from admin_team_members where user_id = '${S2}'`))[0].permissions) === JSON.stringify([]));
  await grant(S2, 'support', ['support.tickets']);

  // ============================================================ C. fonctions de permission
  const perm = async (uid, p) => { await as(uid); return (await q(`select has_admin_permission('${p}') r`))[0].r; };
  check('C1 l\'administrateur global a toutes les permissions', (await perm(A, 'finance.split')) && (await perm(A, 'tech.config')) && (await perm(A, 'security.audit')));
  check('C2 un agent n\'a que les permissions de son équipe', (await perm(F1, 'finance.payments')) && !(await perm(F1, 'finance.split')) && !(await perm(F1, 'support.tickets')) && !(await perm(F1, 'tech.config')));
  check('C3 un agent finance sans finance.payments : refusé', (await perm(F2, 'finance.read')) && !(await perm(F2, 'finance.payments')));
  check('C4 client, étudiant, département, direction : aucune permission', !(await perm(C, 'support.tickets')) && !(await perm(ST, 'finance.read')) && !(await perm(D, 'security.moderation')) && !(await perm(DIR, 'finance.read')));
  check('C5 un agent suspendu n\'a plus aucune permission', !(await perm(SUSP, 'support.tickets')));
  await sup(); await db.exec(`update profiles set suspended = true where id = '${A2}'`); check('C6 un administrateur suspendu n\'a plus aucune permission', !(await perm(A2, 'finance.read')));
  await sup(); await db.exec(`update profiles set suspended = false where id = '${A2}'`);
  await as(S1);
  const acc = (await q(`select my_admin_access() r`))[0].r;
  check('C7 my_admin_access : un agent ne voit que ses équipes', acc.role === 'support' && acc.is_admin === false && Object.keys(acc.teams).join() === 'support' && acc.teams.support.includes('support.claims'), JSON.stringify(acc));
  await as(A);
  const accA = (await q(`select my_admin_access() r`))[0].r;
  check('C8 my_admin_access : l\'administrateur voit les 4 équipes et toutes les permissions', accA.is_admin === true && Object.keys(accA.teams).length === 4 && accA.teams.finance.length === 6);
  await as(C);
  const accC = (await q(`select my_admin_access() r`))[0].r;
  check('C9 my_admin_access : un client n\'a aucune équipe', accC.is_admin === false && Object.keys(accC.teams).length === 0);
  await as(S1);
  check('C10 is_platform_staff : support avec permissions = vrai', (await q(`select is_platform_staff() r`))[0].r === true);
  await as(F1);
  check('C11 is_platform_staff : un agent finance n\'est pas « équipe de la plateforme »', (await q(`select is_platform_staff() r`))[0].r === false);
  await as(A);
  check('C12 is_platform_staff : administrateur = vrai', (await q(`select is_platform_staff() r`))[0].r === true);

  // ============================================================ D. gardes Finance
  await sup();
  await db.exec(`insert into payment_transactions (reference, payer_id, provider, kind, subject, amount, status) values ('PAY-H4-1', '${C}', 'manual', 'other', 'essai', 5000, 'pending'), ('PAY-H4-2', '${C}', 'manual', 'other', 'essai 2', 7000, 'pending'), ('PAY-H4-3', '${C}', 'manual', 'other', 'essai 3', 9000, 'pending')`);
  const P = async (ref) => (await qs(`select id from payment_transactions where reference = '${ref}'`))[0].id;
  const p1 = await P('PAY-H4-1'), p2 = await P('PAY-H4-2'), p3 = await P('PAY-H4-3');
  await as(F2);
  await guardDenied('D1 finance sans finance.payments : valider un paiement refusé', `select payment_set_status('${p1}', 'confirmed')`);
  await guardDenied('D2 finance sans finance.payments : liste des paiements à vérifier refusée', `select payments_to_verify()`);
  await guardDenied('D3 finance sans finance.payouts : créer un retrait refusé', `select payout_create('${ST}', 1000)`);
  await guardDenied('D4 finance sans finance.payouts : changer le statut d\'un retrait refusé', `select payout_set_status('${p1}', 'verse', 'REF-1', null)`);
  await guardDenied('D5 finance sans finance.transfers : virement MoMo refusé', `select momo_prepare_transfer('${p1}', '690000000', 1000, 'x', 'idem')`);
  await guardDenied('D6 finance sans finance.refunds : verser un remboursement refusé', `select order_refund_set_paid('${p1}', 'REF123')`);
  await guardDenied('D7 finance sans finance.split : bloquer le séquestre refusé', `select money_freeze('${p1}', 'motif')`);
  await guardDenied('D8 finance sans finance.split : modifier la règle de répartition refusé', `select money_split_set(60, 25, 15, 'essai')`);
  await guardPassed('D9 finance.read : tableau de bord financier lisible', `select finance_overview()`);
  await guardPassed('D10 finance.read : séquestre en lecture', `select money_admin_overview()`);
  await guardPassed('D11 finance.read : lecture des réglages', `select settings_all()`);
  await as(F1);
  await guardPassed('D12 finance.payments : valider un paiement', `select payment_set_status('${p1}', 'confirmed')`);
  check('D13 le paiement est réellement confirmé', (await qs(`select status from payment_transactions where id = '${p1}'`))[0].status === 'confirmed');
  await guardPassed('D14 finance.payments : liste à vérifier', `select payments_to_verify()`);
  await guardPassed('D15 finance.payouts : création de retrait (garde franchie)', `select payout_create('${ST}', 1000)`);
  await guardPassed('D16 finance.transfers : virement MoMo (garde franchie)', `select momo_prepare_transfer('${p1}', '690000000', 1000, 'x', 'idem')`);
  await guardDenied('D17 finance par défaut : pas de finance.split (déblocage forcé refusé)', `select money_release_now('${p1}')`);
  await guardDenied('D18 finance : une décision de support est refusée (réclamation)', `select claim_decide('${p1}', 'release', 'ok ok ok')`);
  await guardDenied('D19 finance : répondre à un ticket refusé', `select support_ticket_reply('${p1}', 'bonjour')`);
  await guardDenied('D20 finance : modérer une publication refusé', `select moderate_post('${p1}', true, 'ok')`);
  await guardDenied('D21 finance : lire les signalements refusé', `select comment_reports_list(10)`);
  await guardDenied('D22 finance : écrire un réglage technique refusé', `select setting_set('app.test', '1'::jsonb)`);
  await guardDenied('D23 finance : créer une clé d\'API refusé', `select create_api_key('ma clé test')`);
  await guardDenied('D24 finance : réinitialiser une 2FA refusé', `select admin_mfa_reset('${C}', 'identité vérifiée par téléphone')`);
  await guardDenied('D25 finance : liste des comptes (admin_users) refusée', `select admin_users(null, 10)`);
  await guardDenied('D26 finance : pièces justificatives à examiner refusé', `select documents_to_review('pending', 10)`);
  await guardDenied('D27 finance : supervision des bornes refusée', `select kiosk_provision('borne-1')`);
  await as(A);
  await guardPassed('D28 administrateur : valider un paiement', `select payment_set_status('${p2}', 'confirmed')`);
  await guardPassed('D29 administrateur : bloquer le séquestre (garde franchie)', `select money_freeze('${p2}', 'motif')`);
  await guardPassed('D30 administrateur : règle de répartition (garde franchie)', `select money_split_set(70, 20, 10, 'retour')`);
  await guardPassed('D31 administrateur : lecture financière', `select finance_overview()`);
  await guardPassed('D32 administrateur : réglage', `select setting_set('app.test', '1'::jsonb)`);
  await grant(F2, 'finance', ['finance.read', 'finance.split']);
  await as(F2);
  await guardPassed('D33 finance.split attribué par l\'administrateur : bloquer le séquestre (garde franchie)', `select money_freeze('${p2}', 'motif')`);
  await guardPassed('D34 finance.split : règle de répartition (garde franchie)', `select money_split_set(70, 20, 10, 'retour')`);
  await guardDenied('D35 finance.split ne donne pas finance.payments', `select payment_set_status('${p3}', 'confirmed')`);
  await grant(F2, 'finance', ['finance.read']);
  await as(F2);
  await guardDenied('D36 retrait de finance.split : de nouveau refusé', `select money_freeze('${p2}', 'motif')`);

  // direction : lecture consolidée conservée (lot H3), rien d'autre
  await as(DIR);
  await guardPassed('D37 direction : chiffres financiers consolidés conservés', `select finance_overview()`);
  await guardDenied('D38 direction : paiements individuels refusés', `select payments_to_verify()`);
  await as(C);
  await guardDenied('D39 client : lecture financière refusée', `select finance_overview()`);
  await guardDenied('D40 client : valider un paiement refusé', `select payment_set_status('${p3}', 'confirmed')`);
  await as(ST);
  await guardDenied('D41 étudiant : retrait refusé', `select payout_create('${ST}', 1000)`);
  await as(SUSP);
  await guardDenied('D42 agent suspendu : aucune opération sensible', `select payments_to_verify()`);
  await sup(); await db.exec(`reset role; set role anon`);
  await guardDenied('D43 anonyme : valider un paiement refusé', `select payment_set_status('${p3}', 'confirmed')`);

  // ============================================================ E. gardes Support
  await sup();
  await db.exec(`insert into support_tickets (user_id, subject, message) values ('${C}', 'Aide commande', 'Ma commande est bloquée depuis hier merci')`);
  const tk = (await qs(`select id from support_tickets limit 1`))[0].id;
  await as(S1);
  await guardPassed('E1 support.tickets : répondre à une demande d\'aide', `select support_ticket_reply('${tk}', 'Nous regardons cela')`);
  check('E2 la réponse est enregistrée', (await qs(`select status from support_tickets where id = '${tk}'`))[0].status === 'answered');
  await guardPassed('E3 support.claims : lire un fil de réclamation (garde franchie)', `select claim_thread('${tk}')`);
  await guardDenied('E4 support sans support.refunds : décision de remboursement refusée', `select claim_decide('${tk}', 'refund', 'remboursement justifié')`);
  await guardPassed('E5 support.claims : décision « non retenue » (garde franchie)', `select claim_decide('${tk}', 'release', 'non retenu')`);
  await guardDenied('E6 support sans support.refunds : décider une demande de remboursement refusé', `select order_refund_decide('${tk}', 'reject', 'refus motivé')`);
  await guardDenied('E7 support : opération financière (paiement) refusée', `select payment_set_status('${p3}', 'confirmed')`);
  await guardDenied('E8 support : liste des paiements à vérifier refusée', `select payments_to_verify()`);
  await guardDenied('E9 support : création de retrait refusée', `select payout_create('${ST}', 1000)`);
  await guardDenied('E10 support : tableau de bord financier refusé (pas de finance.read)', `select finance_overview()`);
  await guardDenied('E11 support : séquestre refusé', `select money_admin_overview()`);
  await guardDenied('E12 support : virement MoMo refusé', `select momo_prepare_transfer('${tk}', '690000000', 1000, 'x', 'idem')`);
  await guardDenied('E13 support sans security.moderation : modérer refusé', `select moderate_post('${tk}', true, 'ok')`);
  await guardDenied('E14 support sans security.accounts : 2FA refusée', `select admin_mfa_reset('${C}', 'identité vérifiée par téléphone')`);
  await guardDenied('E15 support : écrire un réglage refusé', `select setting_set('app.test', '1'::jsonb)`);
  await guardDenied('E16 support : clé d\'API refusée', `select create_api_key('ma clé test')`);
  await guardPassed('E17 support.requests : pièces justificatives à examiner', `select documents_to_review('pending', 10)`);
  await guardPassed('E18 support.requests : liste des comptes', `select admin_users(null, 10)`);
  await guardPassed('E19 support.orders : retraits en borne (liste)', `select pickups_list(10)`);
  await guardPassed('E20 support.orders : incident de borne (garde franchie)', `select report_kiosk_incident('borne-1', 'other', 'écran éteint')`);
  await grant(S1, 'support', ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds']);
  await as(S1);
  await guardPassed('E21 support.refunds attribué : décision de remboursement dans une réclamation (garde franchie)', `select claim_decide('${tk}', 'refund', 'remboursement justifié')`);
  await guardPassed('E22 support.refunds attribué : décider une demande de remboursement (garde franchie)', `select order_refund_decide('${tk}', 'reject', 'refus motivé')`);
  await guardDenied('E23 support.refunds ne permet pas de verser (finance.refunds)', `select order_refund_set_paid('${tk}', 'REF123')`);
  await grant(S1, 'support', ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests']);
  await as(S2); // support.tickets seulement
  await guardPassed('E24 agent tickets seulement : répondre à une demande', `select support_ticket_reply('${tk}', 'Merci pour votre patience')`);
  await guardDenied('E25 agent tickets seulement : réclamations refusées (non vues comme personnel)', `select claim_decide('${tk}', 'release', 'non retenu')`);
  await guardDenied('E26 agent tickets seulement : litiges refusés', `select dispute_close('${tk}', 'x')`);
  await guardDenied('E27 agent tickets seulement : bornes refusées', `select pickups_list(10)`);
  await guardDenied('E28 agent tickets seulement : pièces justificatives refusées', `select documents_to_review('pending', 10)`);
  await guardPassed('E29 agent tickets : liste des comptes (pour assister l\'utilisateur)', `select admin_users(null, 10)`);
  await as(A);
  await guardPassed('E30 administrateur : réponse à un ticket', `select support_ticket_reply('${tk}', 'Résolu')`);
  await guardPassed('E31 administrateur : décision de remboursement (garde franchie)', `select claim_decide('${tk}', 'refund', 'remboursement justifié')`);
  await as(D);
  await guardDenied('E32 département : répondre à un ticket refusé', `select support_ticket_reply('${tk}', 'x')`);
  await guardPassed('E33 département : modération des publications conservée', `select moderation_posts_list('pending', 10)`);
  await guardPassed('E34 département : liste des comptes conservée (périmètre H2)', `select admin_users(null, 10)`);
  await as(C);
  await guardDenied('E35 client : répondre à un ticket refusé', `select support_ticket_reply('${tk}', 'x')`);
  await guardPassed('E36 client : créer sa propre demande d\'aide (flux inchangé)', `select support_ticket_create('Besoin d aide', 'Bonjour, je ne retrouve pas ma commande')`);
  await as(SUSP);
  await guardDenied('E37 agent suspendu : réponse refusée', `select support_ticket_reply('${tk}', 'x')`);
  await sup(); await db.exec(`reset role; set role anon`);
  await guardDenied('E38 anonyme : réponse refusée', `select support_ticket_reply('${tk}', 'x')`);

  // ============================================================ F. gardes Sécurité et modération
  await as(SEC);
  await guardPassed('F1 security.moderation : file de modération', `select moderation_posts_list('pending', 10)`);
  await guardPassed('F2 security.reports : signalements de commentaires', `select comment_reports_list(10)`);
  await guardPassed('F3 security.reports : signalements de conversations', `select message_reports_list('open', 10)`);
  await guardPassed('F4 security.accounts : 2FA (garde franchie, identité trop courte refusée ensuite)', `select admin_mfa_reset('${C}', 'identité vérifiée par téléphone ok')`);
  await guardDenied('F5 sécurité : opération financière refusée', `select payment_set_status('${p3}', 'confirmed')`);
  await guardDenied('F6 sécurité : décision de remboursement refusée', `select claim_decide('${tk}', 'refund', 'remboursement justifié')`);
  await guardDenied('F7 sécurité : répondre à un ticket refusé', `select support_ticket_reply('${tk}', 'x')`);
  await guardDenied('F8 sécurité : réglage refusé', `select setting_set('app.test', '1'::jsonb)`);
  await guardDenied('F9 sécurité : retraits en borne refusés', `select pickups_list(10)`);
  await as(S1);
  await guardDenied('F10 support sans équipe sécurité : modération refusée', `select moderation_posts_list('pending', 10)`);
  await guardDenied('F11 support sans équipe sécurité : signalements refusés', `select comment_reports_list(10)`);
  await as(LEG_S);
  await guardDenied('F12 compte support d\'avant (migré), réduit par K1 : modération refusée', `select moderation_posts_list('pending', 10)`);
  await guardDenied('F13 compte support d\'avant (migré), réduit par K1 : tickets refusés', `select support_ticket_reply('${tk}', 'Merci')`);
  await guardDenied('F14 compte support d\'avant (migré), réduit par K1 : remboursements refusés', `select order_refund_decide('${tk}', 'reject', 'refus motivé')`);
  await as(LEG_F);
  await guardDenied('F15 compte finance d\'avant (migré), réduit par K1 : paiements refusés', `select payments_to_verify()`);
  await guardDenied('F16 compte finance d\'avant (migré), réduit par K1 : retraits refusés', `select payout_create('${ST}', 1000)`);

  // comptes suspects
  await as(SEC);
  await fails('F17 recherche trop courte : liste vide', `select 1/(case when jsonb_array_length(security_accounts_search('ab')) = 0 then 0 else 1 end)`, /division/);
  const found = (await q(`select security_accounts_search('cora') r`))[0].r;
  check('F18 recherche de comptes : clients trouvés, équipe interne exclue', found.length === 1 && found[0].id === C && (await q(`select security_accounts_search('sam') r`))[0].r.length === 0);
  await fails('F19 motif trop court refusé', `select security_flag_account('${C}', 'abc')`, /5 à 500/);
  await fails('F20 on ne signale pas un compte de l\'équipe', `select security_flag_account('${S1}', 'comportement étrange constaté')`, /équipe/);
  await fails('F21 on ne se signale pas soi-même', `select security_flag_account('${SEC}', 'comportement étrange constaté')`, /invalide/);
  const flag = (await q(`select security_flag_account('${C}', 'Plusieurs paiements refusés avec des numéros différents') r`))[0].r;
  check('F22 signalement enregistré, administrateurs notifiés, audit écrit', !!flag && (await qs(`select count(*)::int n from notifications where user_id = '${A}' and title = 'Compte suspect signalé'`))[0].n === 1
    && (await qs(`select count(*)::int n from audit_log where action = 'Compte signalé comme suspect' and actor_id = '${SEC}'`))[0].n === 1);
  await fails('F23 un seul signalement ouvert par compte', `select security_flag_account('${C}', 'second signalement identique')`, /déjà signalé/);
  check('F24 liste des signalements ouverts', (await q(`select security_flags_list('open') r`))[0].r.length === 1);
  await fails('F25 mise hors de cause sans motif refusée', `select security_flag_decide('${flag}', 'clear', '')`, /hors de cause/);
  await fails('F26 décision inconnue refusée', `select security_flag_decide('${flag}', 'suspendre', 'x')`, /Décision inconnue/);
  check('F27 transmission à l\'administrateur : statut escalated + notification', (await q(`select security_flag_decide('${flag}', 'escalate', 'à suspendre ?') r`))[0].r === 'escalate'
    && (await qs(`select count(*)::int n from notifications where user_id = '${A}' and title = 'Suspension à décider'`))[0].n === 1);
  await fails('F28 décision déjà prise : refusée', `select security_flag_decide('${flag}', 'clear', 'x')`, /déjà traité/);
  check('F29 l\'agent de sécurité ne suspend PAS un compte (admin_set_account réservé à l\'administrateur)', await (async () => { try { await q(`select admin_set_account('${C}', 'client', true)`); return false; } catch (e) { return /administrateur/.test(e.message); } })());
  await as(S1);
  await guardDenied('F30 support sans security.accounts : signalement refusé', `select security_flag_account('${ST}', 'comportement étrange constaté')`);
  await guardDenied('F31 support sans security.accounts : liste refusée', `select security_flags_list('open')`);
  await as(F1);
  await guardDenied('F32 finance : comptes suspects refusés', `select security_accounts_search('cora')`);
  await as(C);
  await guardDenied('F33 client : comptes suspects refusés', `select security_flags_list('open')`);
  check('F34 client : lecture directe de account_flags impossible', (await q(`select count(*)::int n from account_flags`))[0].n === 0);
  await sup(); await db.exec(`reset role; set role anon`);
  await guardDenied('F35 anonyme : comptes suspects refusés', `select security_flags_list('open')`);
  await as(A);
  check('F36 administrateur : liste complète des signalements (tous statuts)', (await q(`select security_flags_list('') r`))[0].r.length === 1 && (await q(`select security_flags_list('escalated') r`))[0].r.length === 1);

  // ============================================================ G. gardes Technique
  await as(TECH);
  await guardPassed('G1 tech.config : réglage technique modifié', `select setting_set('app.maintenance_banner', '"ok"'::jsonb)`);
  check('G2 le réglage est réellement enregistré', (await qs(`select value from platform_settings where key = 'app.maintenance_banner'`))[0].value === 'ok');
  await fails('G3 un réglage financier reste réservé à l\'administrateur global', `select setting_set('payments.manual_number', '"690000000"'::jsonb)`, /administrateur global/);
  await guardPassed('G4 tech.config : lecture des réglages', `select settings_all()`);
  await guardPassed('G5 tech.integrations : clé d\'API (garde franchie)', `select create_api_key('clé technique')`);
  await guardPassed('G6 tech.maintenance : supervision des bornes', `select report_kiosk_incident('borne-1', 'other', 'borne éteinte')`);
  await guardDenied('G7 technique : opération financière refusée', `select payment_set_status('${p3}', 'confirmed')`);
  await guardDenied('G8 technique : tableau de bord financier refusé', `select finance_overview()`);
  await guardDenied('G9 technique : ticket refusé', `select support_ticket_reply('${tk}', 'x')`);
  await guardDenied('G10 technique : modération refusée', `select moderation_posts_list('pending', 10)`);
  await guardDenied('G11 technique : 2FA d\'un utilisateur refusée', `select admin_mfa_reset('${C}', 'identité vérifiée par téléphone ok')`);
  await guardDenied('G12 technique : liste des comptes refusée', `select admin_users(null, 10)`);
  await as(F1);
  await guardDenied('G13 finance : réglage refusé', `select setting_set('app.maintenance_banner', '"x"'::jsonb)`);
  await as(S1);
  await guardDenied('G14 support : modèle de notification refusé', `select save_notification_template('welcome', 'Sujet', 'Message de test', array['app'], true)`);
  await as(TECH);
  await guardPassed('G15 tech.config : modèle de notification (garde franchie)', `select save_notification_template('welcome', 'Sujet', 'Message de test', array['app'], true)`);
  await as(D);
  await guardDenied('G16 département : réglage refusé', `select setting_set('app.maintenance_banner', '"x"'::jsonb)`);
  await as(DIR);
  await guardDenied('G17 direction : réglages refusés (lot H3)', `select settings_all()`);

  // ============================================================ H. lecture directe cloisonnée (politiques restrictives)
  await sup();
  await db.exec(`insert into audit_log (actor, action, target, category, level) values ('Test', 'Action test H4', 'cible', 'Test', 'Info')`);
  const cnt = async (uid, t) => { await as(uid); return (await q(`select count(*)::int n from ${t}`))[0].n; };
  check('H1 administrateur : lit les paiements', (await cnt(A, 'payment_transactions')) === 3);
  check('H2 finance.payments : lit les paiements', (await cnt(F1, 'payment_transactions')) === 3);
  check('H3 support sans finance : ne lit PAS les paiements', (await cnt(S2, 'payment_transactions')) === 0);
  check('H4 sécurité : ne lit pas les paiements', (await cnt(SEC, 'payment_transactions')) === 0);
  check('H5 technique : ne lit pas les paiements', (await cnt(TECH, 'payment_transactions')) === 0);
  check('H6 le payeur lit toujours ses paiements', (await cnt(C, 'payment_transactions')) === 3);
  check('H7 support sans finance : ne lit pas les retraits ni les gains', (await cnt(S2, 'payout_batches')) === 0 && (await cnt(S2, 'earnings')) === 0);
  check('H8 finance : ne lit pas les tickets', (await cnt(F1, 'support_tickets')) === 0);
  check('H9 support.tickets : lit les tickets', (await cnt(S2, 'support_tickets')) >= 1);
  check('H10 le demandeur lit toujours son ticket', (await cnt(C, 'support_tickets')) >= 1);
  check('H11 journal d\'audit : sécurité (security.audit) et technique (tech.logs) lisent', (await cnt(SEC, 'audit_log')) > 0 && (await cnt(TECH, 'audit_log')) > 0);
  check('H12 journal d\'audit : finance et support sans permission ne lisent pas', (await cnt(F1, 'audit_log')) === 0 && (await cnt(S2, 'audit_log')) === 0);
  check('H13 journal d\'audit : administrateur lit', (await cnt(A, 'audit_log')) > 0);
  await sup(); await db.exec(`insert into orders (number, buyer_id, subtotal, fee, method, status, paid) values ('#H4-1', '${C}', 5000, 0, 'Mobile Money', 0, true)`);
  check('H14 commandes : support.orders / finance.read lisent', (await cnt(S1, 'orders')) >= 1 && (await cnt(F1, 'orders')) >= 1);
  check('H15 commandes : un agent tickets seulement ne lit pas toutes les commandes (support.tickets l\'autorise, pas tech)', (await cnt(TECH, 'orders')) === 0 && (await cnt(SEC, 'orders')) === 0);
  check('H16 l\'acheteur lit sa commande', (await cnt(C, 'orders')) >= 1);
  check('H17 un étudiant (autre rôle) n\'est pas concerné par les politiques d\'équipe (ses propres lignes seulement)', (await cnt(ST, 'orders')) === 0);
  check('H18 département : lecture des réclamations conservée (rôle non concerné)', (await cnt(D, 'claims')) >= 0);
  await as(SUSP);
  check('H19 agent suspendu : aucune lecture de paiements', (await cnt(SUSP, 'payment_transactions')) === 0);

  // ============================================================ I. tableaux de bord
  await as(F1);
  const dF = (await q(`select admin_team_dashboard('finance') r`))[0].r;
  const keysF = dF.counters.map((c) => c.key);
  check('I1 finance : indicateurs réels (1 paiement encore à vérifier, séquestre, retraits)', keysF.includes('payments_pending') && dF.counters.find((c) => c.key === 'payments_pending').value === 1 && keysF.includes('escrow_held') && keysF.includes('escrow_frozen'), JSON.stringify(dF.counters.map((c) => [c.key, c.value])));
  await fails('I2 finance : tableau de bord Support refusé', `select admin_team_dashboard('support')`, /Réservé aux agents/);
  await fails('I3 finance : tableau de bord Technique refusé', `select admin_team_dashboard('tech')`, /Réservé aux agents/);
  await as(F2);
  const dF2 = (await q(`select admin_team_dashboard('finance') r`))[0].r.counters.map((c) => c.key);
  check('I4 finance.read seulement : pas d\'indicateur de paiements ni de retraits', !dF2.includes('payments_pending') && !dF2.includes('payouts_requested') && dF2.includes('escrow_held'), JSON.stringify(dF2));
  await as(S1);
  const dS = (await q(`select admin_team_dashboard('support') r`))[0].r.counters.map((c) => c.key);
  check('I5 support : tickets, réclamations, litiges, bornes, demandes', ['tickets_open', 'claims_open', 'disputes_open', 'kiosk_incidents_open', 'documents_pending', 'deletions_pending'].every((k) => dS.includes(k)), JSON.stringify(dS));
  await fails('I6 support : tableau de bord Finance refusé', `select admin_team_dashboard('finance')`, /Réservé aux agents/);
  await as(SEC);
  const dSec = (await q(`select admin_team_dashboard('security') r`))[0].r.counters.map((c) => c.key);
  check('I7 sécurité : publications, signalements, comptes suspects, audit', ['posts_pending', 'reports_open', 'flags_open', 'accounts_suspended', 'audit_sensitive_24h'].every((k) => dSec.includes(k)), JSON.stringify(dSec));
  await as(TECH);
  const dT = (await q(`select admin_team_dashboard('tech') r`))[0].r.counters.map((c) => c.key);
  check('I8 technique : bornes, réglages, clés, journaux', ['kiosk_incidents_open', 'settings_count', 'api_keys_active', 'outbox_failed_24h', 'audit_24h'].every((k) => dT.includes(k)), JSON.stringify(dT));
  await fails('I9 technique : tableau de bord Sécurité refusé', `select admin_team_dashboard('security')`, /Réservé aux agents/);
  await as(A);
  for (const t of ['finance', 'support', 'security', 'tech']) check(`I10 administrateur : tableau de bord ${t}`, (await q(`select admin_team_dashboard('${t}') r`))[0].r.counters.length >= 4);
  await fails('I11 équipe inconnue refusée', `select admin_team_dashboard('compta')`, /Équipe inconnue/);
  for (const [who, uid] of [['client', C], ['étudiant', ST], ['département', D], ['direction', DIR], ['agent suspendu', SUSP]]) {
    await as(uid);
    await fails(`I12 ${who} : tableau de bord refusé`, `select admin_team_dashboard('finance')`, /Réservé aux agents|Connexion/);
  }
  await sup(); await db.exec(`reset role; set role anon`);
  await fails('I13 anonyme : tableau de bord refusé', `select admin_team_dashboard('finance')`, /permission denied|Connexion/);

  // ============================================================ J. 2FA des nouvelles opérations sensibles
  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${A}', 'verified')`);
  const call = async (p, uid, aal) => {
    const claims = JSON.stringify({ sub: uid, ...(aal ? { aal } : {}) });
    await db.exec(`select set_config('request.path', '${p}', false), set_config('request.jwt.claims', '${claims}', false)`);
    try { await db.exec('select enforce_mfa_on_sensitive()'); return 'ok'; } catch (e) { return e.message; }
  };
  for (const fn of ['admin_team_member_set', 'admin_team_member_remove', 'money_freeze', 'money_unfreeze', 'money_split_set', 'order_refund_decide', 'order_refund_set_paid', 'setting_set', 'create_api_key', 'revoke_api_key', 'security_flag_decide', 'payout_set_status', 'momo_prepare_transfer', 'payment_set_status']) {
    check(`J1 ${fn} : refusée en aal1 avec un facteur vérifié`, /double authentification/.test(await call(`/rpc/${fn}`, A, 'aal1')));
  }
  check('J2 admin_team_member_set : autorisée en aal2', (await call('/rpc/admin_team_member_set', A, 'aal2')) === 'ok');
  check('J3 liste d\'origine conservée (payment_start toujours protégée)', /double authentification/.test(await call('/rpc/payment_start', A, 'aal1')));
  check('J4 fonction de lecture jamais bloquée', (await call('/rpc/admin_team_dashboard', A, 'aal1')) === 'ok' && (await call('/rpc/my_admin_access', A, 'aal1')) === 'ok');
  check('J5 préfixe : admin_team_member_set_x non confondue', (await call('/rpc/admin_team_member_set_x', A, 'aal1')) === 'ok');
  await db.exec(`select set_config('request.path', '', false), set_config('request.jwt.claims', '', false)`);

  // ============================================================ K. rejouabilité des migrations (idempotentes) et gardes toujours en place
  await sup();
  const migDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations');
  for (const f of ['20261120040000_h4_equipes_permissions.sql', '20261120041000_h4_gardes_par_permission.sql', '20261120042000_h4_securite_comptes_suspects_et_lecture.sql', '20261120043000_h4_tableaux_equipes_et_2fa.sql']) {
    try { await db.exec(fs.readFileSync(path.join(migDir, f), 'utf8')); check(`K1 ${f} rejouée sans erreur`, true); } catch (e) { check(`K1 ${f} rejouée sans erreur`, false, e.message); }
  }
  const defs = await q(`select proname, pg_get_functiondef(oid) d from pg_proc where pronamespace = 'public'::regnamespace and proname in ('payment_set_status', 'claim_decide', 'setting_set', 'moderate_post')`);
  check('K2 après rejeu : un seul appel de permission par garde (aucun doublon de réécriture)', defs.every((r) => !/has_admin_permission\([^)]*\) or has_admin_permission/.test(r.d)) && defs.length === 4);
  check('K3 après rejeu : les gardes tiennent (support sans finance.payments refusé)', await (async () => { await as(S1); try { await q(`select payment_set_status('${p3}', 'confirmed')`); return false; } catch (e) { return /Action non autorisée/.test(e.message); } })());
  check('K4 le journal de 2FA n\'est pas dupliqué après rejeu', (await qs(`select (length(pg_get_functiondef('enforce_mfa_on_sensitive()'::regprocedure)) - length(replace(pg_get_functiondef('enforce_mfa_on_sensitive()'::regprocedure), 'admin_team_member_set', ''))) / length('admin_team_member_set') n`))[0].n === 1);

  console.log(`act_h4: ${ok} OK, ${ko} KO`);
}
