// H13 · Lives : audit de send_live_reminders et de live_remind_set (migration 20261128020000).
// Prouve : appel refusé à un utilisateur lambda / hôte / administrateur connecté / visiteur, autorisé à service_role et au rôle de la tâche planifiée ;
// aucun doublon sur deux appels (et sur un rappel réarmé uniquement quand l'hôte change la date) ; live annulé / terminé / hors délai : aucun rappel ;
// rappels désactivés : aucun ; hôte ou destinataire suspendu : aucun ; live privé sans invitation : aucun (et inscription refusée) ; message de l'hôte nettoyé et borné ;
// un rappel en échec ne bloque pas les autres ; rejeu de la migration sans effet de bord.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h13_live.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000097${String(n).padStart(2, '0')}`;
  const ADM = id(1), HOST = id(2), H2 = id(3), V1 = id(5), V2 = id(6), V3 = id(7), SUSP = id(8), INV = id(9), BAN = id(10), HSUSP = id(11), BAD = id(12);
  const mail = (uid) => `a${uid.slice(-2)}@t.cm`;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims({})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const sup = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { await sup(); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const DENY = /permission denied|Connexion requise/i;
  const send = async () => { await sup(); return (await q('select send_live_reminders() n'))[0].n; };
  const notifs = async (live, user) => qs(`select title, body from notifications where kind = 'live_reminder' and data->>'live' = '${live}'${user ? ` and user_id = '${user}'` : ''}`);

  await sup();
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [HOST, 'Hugo Hote', 'student'], [H2, 'Hana Autre', 'student'], [V1, 'Vera Un', 'student'], [V2, 'Vic Deux', 'student'],
    [V3, 'Vera Trois', 'student'], [SUSP, 'Suzie Suspendue', 'student'], [INV, 'Ines Invitee', 'student'], [BAN, 'Boris Banni', 'student'], [HSUSP, 'Hector Suspendu', 'student'], [BAD, 'Bad Poison', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }
  await db.exec(`update profiles set suspended = true where id in ('${SUSP}', '${HSUSP}'); alter table lives disable trigger trg_lives_daily_quota`);
  const mk = async (host, title, o = {}) => { await sup(); return (await q(`insert into lives (host_id, title, status, scheduled_at, started_at, ended_at, visibilite, live_type) values
    ('${host}', '${title}', '${o.status ?? 'scheduled'}', ${o.at === undefined ? `now() + interval '20 minutes'` : o.at === null ? 'null' : `now() + interval '${o.at}'`},
     ${o.status === 'live' ? 'now()' : 'null'}, ${o.status === 'ended' ? 'now()' : 'null'}, '${o.vis ?? 'public'}', '${o.vis === 'prive' ? 'prive' : 'public'}') returning id`))[0].id; };
  const rem = (live, ...users) => db.exec(`insert into live_reminders (live_id, user_id) values ${users.map((u) => `('${live}', '${u}')`).join(', ')}`);

  // ============================================================ A. Permissions
  const LA = await mk(HOST, 'Atelier imminent');
  await rem(LA, V1, V2);
  for (const [nm, uid] of [['A1 visiteur anonyme', null], ['A2 utilisateur lambda', V1], ['A3 hôte du live', HOST], ['A4 administrateur connecté', ADM]]) {
    await as(uid);
    await fails(`${nm} : send_live_reminders refusé`, 'select send_live_reminders()', DENY);
  }
  await sup();
  check('A5 aucun rappel parti après les refus', (await qs(`select count(*)::int n from notifications where kind = 'live_reminder'`))[0].n === 0);
  await db.exec(`grant usage on schema public to service_role`);
  await db.exec(`reset role; set role service_role`);
  let svc = null; try { svc = (await q('select send_live_reminders() n'))[0].n; } catch (e) { svc = e.message; }
  await sup();
  check('A6 service_role (tâche serveur) autorisé : 2 rappels', svc === 2, String(svc));
  const acl = await qs(`select has_function_privilege('anon', 'send_live_reminders()', 'execute') a, has_function_privilege('authenticated', 'send_live_reminders()', 'execute') u, has_function_privilege('service_role', 'send_live_reminders()', 'execute') s`);
  check('A7 droits d\'exécution : ni anon ni authenticated, service_role oui', acl[0].a === false && acl[0].u === false && acl[0].s === true, JSON.stringify(acl));

  // ============================================================ B. Doublons
  check('B1 deux appels de suite : second appel = 0 rappel', (await send()) === 0);
  check('B2 un seul rappel par (live, utilisateur)', (await notifs(LA, V1)).length === 1 && (await notifs(LA, V2)).length === 1);
  check('B3 texte : « Un live commence bientôt » + titre', (await notifs(LA, V1))[0].title === 'Un live commence bientôt' && /Atelier imminent/.test((await notifs(LA, V1))[0].body));
  check('B4 les rappels sont marqués notifiés', (await qs(`select count(*)::int n from live_reminders where live_id = '${LA}' and notified`))[0].n === 2);
  // l'inscription rejouée ne recrée pas de ligne et n'envoie rien de plus
  await as(V1);
  await rpc(`live_remind_set('${LA}', true)`);
  await sup();
  check('B5 inscription rejouée : pas de doublon, rien de plus envoyé', (await send()) === 0 && (await qs(`select count(*)::int n from live_reminders where live_id = '${LA}' and user_id = '${V1}'`))[0].n === 1);
  // simultanéité : un rappel déjà verrouillé par une autre transaction est sauté (pas de double envoi)
  const LC2 = await mk(HOST, 'Atelier concurrent');
  await rem(LC2, V1);
  check('B6 rappel d\'un autre live : envoyé une seule fois sur deux appels', (await send()) === 1 && (await notifs(LC2)).length === 1 && (await send()) === 0);
  // La concurrence réelle (deux transactions) n'est pas reproductible dans PGlite (une seule connexion) : voir for update skip locked dans la migration et le document H13.

  // ============================================================ C. Live annulé / terminé / hors délai
  const LX = await mk(HOST, 'Atelier annule');
  await rem(LX, V1, V2);
  await as(HOST);
  await rpc(`live_cancel('${LX}', 'Imprévu')`);
  await sup();
  const nx = await send();
  check('C1 live annulé : aucun rappel de rappel', (await notifs(LX)).length === 0, `n=${nx}`);
  check('C2 live annulé : rappels supprimés', (await qs(`select count(*)::int n from live_reminders where live_id = '${LX}'`))[0].n === 0);
  check('C3 live annulé : les inscrits ont reçu l\'avis d\'annulation (autre type)', (await qs(`select count(*)::int n from notifications where kind = 'live' and title = 'Live annulé' and data->>'live' = '${LX}'`))[0].n === 2);
  const LE = await mk(HOST, 'Atelier termine', { status: 'ended', at: null });
  await rem(LE, V1);
  await send();
  check('C4 live terminé : aucun rappel, ligne supprimée', (await notifs(LE)).length === 0 && (await qs(`select count(*)::int n from live_reminders where live_id = '${LE}'`))[0].n === 0);
  const LS = await mk(HOST, 'Atelier perime', { at: '-4 hours' });
  await rem(LS, V1);
  await send();
  check('C5 live programmé dont l\'heure est dépassée de plus de 3 h : aucun rappel', (await notifs(LS)).length === 0);
  const LL = await mk(HOST, 'Atelier lointain', { at: '5 hours' });
  await rem(LL, V1);
  await send();
  check('C6 live à plus de 30 minutes : pas encore de rappel', (await notifs(LL)).length === 0 && (await qs(`select count(*)::int n from live_reminders where live_id = '${LL}' and not notified`))[0].n === 1);
  await db.exec(`update lives set scheduled_at = now() + interval '25 minutes' where id = '${LL}'`);
  check('C7 puis à moins de 30 minutes : un rappel', (await send()) === 1 && (await notifs(LL)).length === 1);
  const LDirect = await mk(HOST, 'Direct commence', { status: 'live', at: null });
  await rem(LDirect, V3);
  await send();
  const nd = await notifs(LDirect, V3);
  check('C8 live démarré : « Le live a commencé »', nd.length === 1 && nd[0].title === 'Le live a commencé' && /est en direct/.test(nd[0].body), JSON.stringify(nd));
  await db.exec(`delete from live_reminders where live_id = '${LS}'; update lives set scheduled_at = now() - interval '2 days' where id = '${LL}'; update live_reminders set notified = true where live_id = '${LL}'`);
  await send();
  check('C9 live programmé jamais démarré depuis plus d\'un jour : rappels nettoyés', (await qs(`select count(*)::int n from live_reminders where live_id = '${LL}'`))[0].n === 0);

  // ============================================================ D. Rappels désactivés / comptes suspendus / privé
  const LD = await mk(HOST, 'Atelier sans rappel');
  await rem(LD, V1);
  await as(HOST);
  await rpc(`live_set_settings('${LD}', '{"reminders_enabled": false}'::jsonb)`);
  await sup();
  await send();
  check('D1 rappels désactivés par l\'hôte après inscription : aucun rappel', (await notifs(LD)).length === 0);
  await as(HOST);
  await rpc(`live_set_settings('${LD}', '{"reminders_enabled": true}'::jsonb)`);
  await sup();
  check('D1b réactivés : le rappel part', (await send()) === 1 && (await notifs(LD)).length === 1);
  const LH = await mk(HSUSP, 'Atelier hote suspendu');
  await rem(LH, V1);
  await send();
  check('D2 hôte suspendu : aucun rappel', (await notifs(LH)).length === 0);
  const LU = await mk(HOST, 'Atelier destinataire suspendu');
  await rem(LU, SUSP);
  await send();
  check('D3 destinataire suspendu : aucun rappel', (await notifs(LU)).length === 0);
  const LP = await mk(HOST, 'Atelier tres prive', { vis: 'prive' });
  await db.exec(`insert into live_invites (live_id, user_id) values ('${LP}', '${INV}'); insert into live_bans (live_id, user_id) values ('${LP}', '${BAN}')`);
  await rem(LP, V1, INV, BAN);
  await send();
  check('D4 live privé : invité reçoit, non invité et banni non', (await notifs(LP, INV)).length === 1 && (await notifs(LP, V1)).length === 0 && (await notifs(LP, BAN)).length === 0);
  const LP2 = await mk(HOST, 'Atelier prive 2', { vis: 'prive' });
  await db.exec(`insert into live_invites (live_id, user_id) values ('${LP2}', '${INV}')`);
  await as(V1);
  await fails('D5 live_remind_set : live privé sans invitation refusé', `select live_remind_set('${LP2}', true)`, /privé/);
  await as(INV);
  check('D6 live_remind_set : invité accepté', (await rpc(`live_remind_set('${LP2}', true)`)) === true);
  await as(null);
  await fails('D7 live_remind_set : anonyme refusé', `select live_remind_set('${LA}', true)`, DENY);
  await sup();
  const LPub = await mk(HOST, 'Atelier public futur', { at: '2 days' });
  await as(V2);
  check('D8 live public : rappel accepté (comportement conservé)', (await rpc(`live_remind_set('${LPub}', true)`)) === true && (await rpc(`live_remind_set('${LPub}', false)`)) === false);
  await as(HOST);
  await fails('D9 l\'hôte ne peut pas se rappeler son propre live (comportement conservé)', `select live_remind_set('${LPub}', true)`, /hôte/);

  // ============================================================ E. Message de l'hôte
  const LM = await mk(HOST, 'Atelier avec message');
  await rem(LM, V1);
  await as(HOST);
  await rpc(`live_set_settings('${LM}', '{"notify_message": "Apportez votre casque https://evil.example/x <b>vite</b>"}'::jsonb)`);
  await sup();
  await send();
  const m1 = (await notifs(LM, V1))[0];
  check('E1 message de l\'hôte repris, liens et balises retirés', m1 && /Apportez votre casque/.test(m1.body) && !/https?:|evil|<|>/.test(m1.body), JSON.stringify(m1));
  const LM2 = await mk(HOST, 'Atelier message long');
  await db.exec(`insert into live_settings (live_id) values ('${LM2}') on conflict do nothing`);
  await rem(LM2, V1);
  await db.exec(`alter table live_settings drop constraint if exists live_settings_notify_message_check`);
  await db.exec(`update live_settings set notify_message = '${'x'.repeat(400)} https://evil.example/y' where live_id = '${LM2}'`);
  await send();
  const m2 = (await notifs(LM2, V1))[0];
  check('E2 message trop long (écrit hors contrôle) : corps borné à 500 caractères, sans lien', m2 && m2.body.length <= 500 && !/evil/.test(m2.body), String(m2 && m2.body.length));
  const LM3 = await mk(HOST, 'Atelier guillemets');
  await db.exec(`update lives set title = 'L''atelier "SQL"; drop table notifications;--' where id = '${LM3}'`);
  await rem(LM3, V1);
  await send();
  check('E3 titre avec guillemets / SQL : texte inerte', (await notifs(LM3, V1)).length === 1 && (await qs(`select count(*)::int n from notifications`))[0].n > 0);

  // ============================================================ F. Un rappel en échec ne bloque pas les autres
  const LF = await mk(HOST, 'Atelier poison');
  await rem(LF, BAD, V1, V2);
  await db.exec(`create or replace function _h13_poison() returns trigger language plpgsql as $$ begin if new.user_id = '${BAD}'::uuid then raise exception 'poison'; end if; return new; end $$;
    create trigger h13_poison before insert on notifications for each row execute function _h13_poison();`);
  const nf = await send();
  await db.exec(`drop trigger h13_poison on notifications; drop function _h13_poison();`);
  check('F1 un rappel en échec : les autres partent (2) et l\'appel ne plante pas', nf === 2 && (await notifs(LF, V1)).length === 1 && (await notifs(LF, V2)).length === 1 && (await notifs(LF, BAD)).length === 0, `n=${nf}`);
  check('F2 le rappel en échec est clos (pas rejoué indéfiniment)', (await qs(`select notified from live_reminders where live_id = '${LF}' and user_id = '${BAD}'`))[0].notified === true);

  // ============================================================ G. Réarmement par l'hôte (changement de date) : un nouveau rappel, pas de doublon
  const LR = await mk(HOST, 'Atelier reprogramme', { at: '10 hours' });
  await rem(LR, V3);
  await as(HOST);
  await rpc(`live_update('${LR}', 'Atelier reprogramme', null, now() + interval '2 days')`);
  await sup();
  check('G1 reprogrammé à 2 jours : aucun rappel immédiat', (await send()) === 0 && (await notifs(LR)).length === 0);
  await db.exec(`update lives set scheduled_at = now() + interval '10 minutes' where id = '${LR}'`);
  check('G2 à l\'approche de la nouvelle heure : un seul rappel', (await send()) === 1 && (await send()) === 0 && (await notifs(LR)).length === 1);

  // ============================================================ I. Quiz de replay côté hôte / co-hôte (migration 20261128021000)
  const CO = id(13), S1 = id(14), S2 = id(15), S3 = id(16), S4 = id(17);
  await sup();
  for (const [i, nm] of [[CO, 'Coco Cohote'], [S1, 'Stu Un'], [S2, 'Stu Deux'], [S3, 'Stu Trois'], [S4, 'Stu Quatre']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','student','${mail(i)}')`);
  }
  await db.exec(`grant select, delete on storage.objects to authenticated, anon`);
  const mkRec = async (live, vis = 'public') => (await q(`insert into live_recordings (live_id, requested_by, status, storage_path, duration_sec, ready_at) values ('${live}', '${HOST}', 'pret', '${HOST}/${live.slice(-6)}.mp4', 600, now()) returning id`))[0].id;
  const mkEnded = async (title, vis = 'public') => (await q(`insert into lives (host_id, title, status, started_at, ended_at, visibilite, live_type) values ('${HOST}', '${title}', 'ended', now() - interval '2 hours', now() - interval '1 hour', '${vis}', '${vis}') returning id`))[0].id;
  const LQ = await mkEnded('Atelier avec quiz'), LQ2 = await mkEnded('Atelier sans quiz'), LQP = await mkEnded('Atelier prive quiz', 'prive');
  const RQ = await mkRec(LQ), RQ2 = await mkRec(LQ2), RQP = await mkRec(LQP);
  await db.exec(`insert into live_cohosts (live_id, user_id, status) values ('${LQ}', '${CO}', 'approved'); insert into replay_meta (recording_id, certificate_enabled) values ('${RQ}', true), ('${RQ2}', true)`);
  const seq = { n: 0 };
  const ts = () => `(extract(epoch from clock_timestamp()) * 1000)::bigint + ${++seq.n}`;
  const rep = async (uid, rec, from, to) => { await sup(); await db.exec(`update replay_progress set session_at = clock_timestamp() - interval '25 seconds', win_start = null, win_count = 0 where user_id = '${uid}' and recording_id = '${rec}'`); await as(uid); return rpc(`replay_progress_report('${rec}', ${from}, ${to}, ${ts()})`); };
  const watchAll = async (uid, rec) => {
    await sup(); await db.exec(`insert into replay_progress (user_id, recording_id) values ('${uid}', '${rec}') on conflict do nothing; update replay_progress set session_at = clock_timestamp() - interval '10 seconds', win_start = null, win_count = 0 where user_id = '${uid}' and recording_id = '${rec}'`);
    await as(uid); await rpc(`replay_playback_start('${rec}', 0)`);
    await sup(); await db.exec(`update replay_progress set created_at = now() - interval '3 hours' where user_id = '${uid}' and recording_id = '${rec}'`);
    let r; for (let k = 0; k < 20; k++) r = await rep(uid, rec, k * 30, (k + 1) * 30);
    return r;
  };
  const badge = async (uid, rec) => (await qs(`select count(*)::int n from user_badges where user_id = '${uid}' and code = 'jai_suivi' and ref_id = '${rec}'`))[0].n;
  const cert = async (uid, rec) => (await qs(`select count(*)::int n from replay_certificates where user_id = '${uid}' and recording_id = '${rec}'`))[0].n;
  const QS = (arr) => `'${JSON.stringify(arr).replace(/'/g, "''")}'::jsonb`;
  const Q2 = [{ q: 'Gaz de protection ?', options: ['argon', 'eau'], correct: 0 }, { q: 'Fil ?', options: ['acier', 'bois', 'verre'], correct: 0 }];
  const setQ = (rec, title, pct, arr) => `select replay_quiz_set('${rec}', ${title === null ? 'null' : `'${title}'`}, ${pct}, ${QS(arr)})`;

  for (const [nm, uid, exp] of [['I1 anonyme', null, false], ['I1b étudiant quelconque', S1, false], ['I1c hôte', HOST, true], ['I1d co-hôte approuvé', CO, true], ['I1e administrateur', ADM, true], ['I1f hôte d\'un autre live', H2, false]]) {
    await as(uid);
    check(`${nm} : replay_quiz_can_edit = ${exp}`, (await rpc(`replay_quiz_can_edit('${RQ}')`)) === exp);
  }
  await as(S1);
  await fails('I2 étudiant : replay_quiz_get_host refusé', `select replay_quiz_get_host('${RQ}')`, /non autorisée/);
  await fails('I2b étudiant : replay_quiz_set refusé', setQ(RQ, 'Quiz', 70, Q2), /non autorisée/);
  await fails('I2c étudiant : replay_quiz_delete refusé', `select replay_quiz_delete('${RQ}')`, /non autorisée/);
  await as(null);
  await fails('I2d anonyme : set / get_host / delete refusés', `select replay_quiz_set('${RQ}', 'x', 70, ${QS(Q2)})`, DENY);
  await fails('I2e anonyme : get_host refusé', `select replay_quiz_get_host('${RQ}')`, DENY);
  await as(H2);
  await fails('I2f hôte d\'un autre live : refusé', setQ(RQ, 'Quiz', 70, Q2), /non autorisée/);
  await as(HOST);
  await fails('I2g replay inconnu', setQ('00000000-0000-0000-0000-00000000dead', 'Quiz', 70, Q2), /introuvable/);

  // validations
  const bad = [
    ['I3 zéro question', 70, [], /1 à 20 questions/], ['I3b 21 questions', 70, Array.from({ length: 21 }, () => Q2[0]), /1 à 20 questions/],
    ['I3c une seule option', 70, [{ q: 'A ?', options: ['a'], correct: 0 }], /2 à 6 options/], ['I3d sept options', 70, [{ q: 'A ?', options: ['a', 'b', 'c', 'd', 'e', 'f', 'g'], correct: 0 }], /2 à 6 options/],
    ['I3e options identiques', 70, [{ q: 'A ?', options: ['Argon', 'argon'], correct: 0 }], /identiques/], ['I3f bonne réponse hors options', 70, [{ q: 'A ?', options: ['a', 'b'], correct: 2 }], /bonne réponse/],
    ['I3g bonne réponse en texte', 70, [{ q: 'A ?', options: ['a', 'b'], correct: '0' }], /invalide/], ['I3h bonne réponse décimale', 70, [{ q: 'A ?', options: ['a', 'b'], correct: 0.5 }], /invalide/],
    ['I3i bonne réponse négative', 70, [{ q: 'A ?', options: ['a', 'b'], correct: -1 }], /invalide/], ['I3j bonne réponse gigantesque', 70, [{ q: 'A ?', options: ['a', 'b'], correct: 99999999999 }], /invalide/],
    ['I3k énoncé vide', 70, [{ q: '  ', options: ['a', 'b'], correct: 0 }], /énoncé/], ['I3l énoncé réduit à un lien', 70, [{ q: 'https://evil.example/x', options: ['a', 'b'], correct: 0 }], /énoncé/],
    ['I3m énoncé non texte', 70, [{ q: 5, options: ['a', 'b'], correct: 0 }], /invalide/], ['I3n option non texte', 70, [{ q: 'A ?', options: ['a', 3], correct: 0 }], /du texte/],
    ['I3o option vide', 70, [{ q: 'A ?', options: ['a', ' '], correct: 0 }], /option/], ['I3p option de 201 caractères', 70, [{ q: 'A ?', options: ['a', 'x'.repeat(201)], correct: 0 }], /option/],
    ['I3q énoncé de 301 caractères', 70, [{ q: 'x'.repeat(301), options: ['a', 'b'], correct: 0 }], /énoncé/], ['I3r seuil 49 %', 49, Q2, /seuil/], ['I3s seuil 101 %', 101, Q2, /seuil/],
    ['I3t question non objet', 70, ['A ?'], /invalide/],
  ];
  for (const [nm, pct, arr, re] of bad) await fails(`${nm} : refusé`, setQ(RQ, 'Quiz', pct, arr), re);
  check('I3u aucune des tentatives invalides n\'a créé de quiz', (await qs(`select count(*)::int n from replay_quizzes`))[0].n === 0);

  // co-hôte définit, hôte relit avec les bonnes réponses
  await as(CO);
  check('I4 le co-hôte approuvé définit le quiz', (await rpc(`replay_quiz_set('${RQ}', 'Quiz <b>soudure</b> https://x.cm', 70, ${QS([{ q: 'Gaz de protection https://evil.example ?', options: ['argon', 'eau'], correct: 0 }, Q2[1]])})`)) === true);
  await as(HOST);
  let gh = await rpc(`replay_quiz_get_host('${RQ}')`);
  check('I5 hôte : quiz complet avec les bonnes réponses, textes nettoyés (liens, balises)', gh.defined === true && gh.questions.length === 2 && gh.questions[0].correct === 0 && !/evil|<|https/.test(JSON.stringify(gh)) && gh.pass_pct === 70 && gh.title.startsWith('Quiz'), JSON.stringify(gh));
  check('I5b statistiques : aucune tentative', gh.attempts === 0 && gh.takers === 0 && gh.passers === 0);
  await as(S1);
  const qg = await rpc(`replay_quiz_get('${RQ}')`);
  check('I6 étudiant : la bonne réponse n\'est jamais envoyée avant correction', qg.defined === true && !JSON.stringify(qg).includes('correct') && qg.questions.every((x) => Object.keys(x).sort().join() === 'options,q'), JSON.stringify(qg));
  await as(HOST);
  check('I7 modification par l\'hôte (seuil 100 %, ordre des options) : conservée', (await rpc(`replay_quiz_set('${RQ}', 'Quiz soudure', 100, ${QS([{ q: 'Gaz de protection ?', options: ['eau', 'argon'], correct: 1 }, Q2[1]])})`)) === true
    && (await rpc(`replay_quiz_get_host('${RQ}')`)).pass_pct === 100);
  await rpc(`replay_quiz_set('${RQ}', 'Quiz soudure', 70, ${QS([{ q: 'Gaz de protection ?', options: ['eau', 'argon'], correct: 1 }, Q2[1]])})`);
  await as(ADM);
  check('I7b l\'administrateur peut aussi relire le quiz', (await rpc(`replay_quiz_get_host('${RQ}')`)).defined === true);

  // badge / certificat : complétion ET quiz réussi
  await sup();
  const r1 = await watchAll(S1, RQ);
  check('I8 S1 termine le replay : complétion enregistrée', r1.completed === true && r1.newly_completed === true, JSON.stringify(r1));
  check('I8b replay avec quiz non réussi : ni badge ni certificat', (await badge(S1, RQ)) === 0 && (await cert(S1, RQ)) === 0);
  await as(S1);
  let pg = await rpc(`replay_progress_get('${RQ}')`);
  check('I8c progression : complété, quiz défini, pas de badge, pas de bonne réponse', pg.completed === true && pg.badge === false && pg.quiz_defined === true && pg.quiz_passed === false && !JSON.stringify(pg).includes('correct'), JSON.stringify(pg));
  await fails('I9 réponses incomplètes refusées', `select replay_quiz_submit('${RQ}', '[1]'::jsonb)`, /toutes les questions/);
  let qz = await rpc(`replay_quiz_submit('${RQ}', '["1","0"]'::jsonb)`);
  check('I9b réponses en texte : comptées fausses, sans erreur, sans fuite', qz.passed === false && qz.score_pct === 0 && qz.completed === true && qz.badge === false && !JSON.stringify(qz).includes('correct'), JSON.stringify(qz));
  qz = await rpc(`replay_quiz_submit('${RQ}', '[9,9]'::jsonb)`);
  check('I9c réponses hors options : fausses', qz.passed === false && qz.score_pct === 0);
  qz = await rpc(`replay_quiz_submit('${RQ}', '[1,1]'::jsonb)`);
  check('I9d une réponse sur deux : 50 % < 70 %, pas de badge ni de certificat', qz.passed === false && qz.score_pct === 50 && (await badge(S1, RQ)) === 0 && (await cert(S1, RQ)) === 0, JSON.stringify(qz));
  await as(S1);
  qz = await rpc(`replay_quiz_submit('${RQ}', '[1,0]'::jsonb)`);
  check('I10 quiz réussi après complétion : badge et certificat', qz.passed === true && qz.badge === true && (await badge(S1, RQ)) === 1 && (await cert(S1, RQ)) === 1, JSON.stringify(qz));
  await as(S1); await rpc(`replay_quiz_submit('${RQ}', '[1,0]'::jsonb)`);
  check('I10b réussite rejouée : un seul badge, un seul certificat', (await badge(S1, RQ)) === 1 && (await cert(S1, RQ)) === 1);

  // quiz réussi AVANT la complétion : rien tant que le replay n'est pas terminé
  await as(S2);
  qz = await rpc(`replay_quiz_submit('${RQ}', '[1,0]'::jsonb)`);
  check('I11 quiz réussi sans avoir terminé le replay : ni badge ni certificat', qz.passed === true && qz.completed === false && qz.badge === false && (await badge(S2, RQ)) === 0 && (await cert(S2, RQ)) === 0, JSON.stringify(qz));
  const r2 = await watchAll(S2, RQ);
  check('I11b puis replay terminé : badge et certificat attribués', r2.newly_completed === true && (await badge(S2, RQ)) === 1 && (await cert(S2, RQ)) === 1, JSON.stringify(r2));

  // replay sans quiz : complétion seule (comportement conservé)
  const r3 = await watchAll(S3, RQ2);
  check('I12 replay sans quiz : badge et certificat dès la complétion', r3.newly_completed === true && (await badge(S3, RQ2)) === 1 && (await cert(S3, RQ2)) === 1);

  // suppression du quiz : les personnes en attente reçoivent leur badge
  await sup(); await db.exec(`insert into replay_completions (user_id, recording_id, live_id, coverage, watched_sec) values ('${S4}', '${RQ}', '${LQ}', 1, 600)`);
  check('I13 S4 a terminé sans réussir le quiz : pas de badge', (await badge(S4, RQ)) === 0);
  await as(S4);
  await fails('I13b étudiant : suppression du quiz refusée', `select replay_quiz_delete('${RQ}')`, /non autorisée/);
  await as(HOST);
  gh = await rpc(`replay_quiz_get_host('${RQ}')`);
  check('I14 statistiques hôte : tentatives, participants, réussites', gh.attempts === 6 && gh.takers === 2 && gh.passers === 2, JSON.stringify(gh));
  check('I15 l\'hôte supprime le quiz', (await rpc(`replay_quiz_delete('${RQ}')`)) === true && (await rpc(`replay_quiz_get_host('${RQ}')`)).defined === false);
  check('I15b suppression : la personne qui attendait le quiz reçoit badge et certificat', (await badge(S4, RQ)) === 1 && (await cert(S4, RQ)) === 1);
  await as(HOST);
  check('I15c supprimer un quiz absent : faux, sans erreur', (await rpc(`replay_quiz_delete('${RQ}')`)) === false);
  await as(S1);
  check('I15d étudiant : plus de quiz', (await rpc(`replay_quiz_get('${RQ}')`)).defined === false);
  await fails('I15e étudiant : soumission sans quiz refusée', `select replay_quiz_submit('${RQ}', '[0]'::jsonb)`, /pas de quiz/);

  // limite de tentatives, accès hérité du live, RLS
  await as(HOST);
  await rpc(`replay_quiz_set('${RQ}', 'Quiz bis', 70, ${QS(Q2)})`);
  await as(S2);
  for (let k = 0; k < 9; k++) await rpc(`replay_quiz_submit('${RQ}', '[1,1]'::jsonb)`);
  await fails('I16 plus de dix tentatives par jour', `select replay_quiz_submit('${RQ}', '[0,0]'::jsonb)`, /Trop de tentatives/);
  await as(HOST);
  await rpc(`replay_quiz_set('${RQP}', 'Quiz privé', 70, ${QS(Q2)})`);
  await as(S1);
  await fails('I17 replay d\'un live privé sans invitation : quiz et soumission refusés', `select replay_quiz_get('${RQP}')`, /privé/);
  await fails('I17b soumission refusée', `select replay_quiz_submit('${RQP}', '[0,0]'::jsonb)`, /privé/);
  await fails('I18 lecture directe des quiz refusée (bonnes réponses)', `select * from replay_quizzes`, DENY);
  check('I18b tentatives : chacun ne voit que les siennes', (await q(`select count(*)::int n from replay_quiz_attempts where user_id <> '${S1}'`))[0].n === 0);
  await as(null);
  await fails('I18c anonyme : tentatives illisibles', `select * from replay_quiz_attempts`, DENY);

  // ============================================================ J. Action Unique « Postuler » sur une mission (migration 20261128022000)
  await sup();
  await db.exec(`update profiles set certification = 'approved', phone_verified = true where id = '${S3}'; update profiles set role = 'client' where id = '${V2}'`);
  const mkMission = async (client, num, title, o = {}) => (await q(`insert into missions (number, client_id, kind, description, total, title, status) values ('${num}', '${client}', '${o.kind ?? 'web'}', 'Description du besoin', 100000, '${title}', '${o.status ?? 'published'}') returning id`))[0].id;
  const M1 = await mkMission(HOST, 'M-H13-1', 'Site vitrine'), M2 = await mkMission(HOST, 'M-H13-2', 'Brouillon', { status: 'draft' }), M3 = await mkMission(HOST, 'M-H13-3', 'Mission privee', { kind: 'mission' });
  const M4 = await mkMission(H2, 'M-H13-4', 'Logo de Hana');
  await as(null);
  await fails('J1 visiteur : mission_public_card refusée', `select mission_public_card('${M1}')`, DENY);
  await as(S1);
  let mc = await rpc(`mission_public_card('${M1}')`);
  check('J2 étudiant non vérifié : fiche lisible avec la raison honnête du refus', mc.open === true && mc.title === 'Site vitrine' && mc.own === false && /vérifi/.test(mc.block_reason ?? ''), JSON.stringify(mc));
  await fails('J2b … et le serveur refuse sa proposition', `select propose_on_mission('${M1}', 50000, 10, 'Je peux le faire')`, /prestation de service/);
  await as(S3);
  mc = await rpc(`mission_public_card('${M1}')`);
  check('J3 étudiant éligible : aucune raison de refus, aucune proposition', mc.block_reason === null && mc.my_status === null && mc.proposals === 0, JSON.stringify(mc));
  await fails('J3b montant nul refusé', `select propose_on_mission('${M1}', 0, 10, 'x')`, /montant/);
  await fails('J3c délai hors bornes refusé', `select propose_on_mission('${M1}', 1000, 400, 'x')`, /délai/);
  check('J4 proposition envoyée', typeof (await rpc(`propose_on_mission('${M1}', 50000, 10, 'Je peux le faire')`)) === 'string');
  mc = await rpc(`mission_public_card('${M1}')`);
  check('J4b la fiche reflète ma proposition', mc.my_status === 'submitted' && mc.proposals === 1 && mc.my_attempts === 1, JSON.stringify(mc));
  await fails('J4c seconde proposition refusée', `select propose_on_mission('${M1}', 40000, 8, 'bis')`, /déjà proposé/);
  await as(HOST);
  mc = await rpc(`mission_public_card('${M1}')`);
  await fails('J5 l\'auteur ne répond pas à son propre besoin', `select propose_on_mission('${M1}', 1000, 5, 'x')`, /propre besoin/);
  check('J5b fiche de l\'auteur : own', mc.own === true);
  await as(V2);
  mc = await rpc(`mission_public_card('${M1}')`);
  check('J6 compte client : fiche sans capacité vendeur ; la proposition est refusée', mc.role === 'client' && mc.block_reason === null, JSON.stringify(mc));
  await fails('J6b client : propose_on_mission refusé', `select propose_on_mission('${M1}', 1000, 5, 'x')`, /talents/);
  await as(S3);
  await fails('J7 brouillon : introuvable pour les autres', `select mission_public_card('${M2}')`, /introuvable/);
  await fails('J7b mission privée (type « mission ») : introuvable pour les autres', `select mission_public_card('${M3}')`, /introuvable/);
  await fails('J7c identifiant inconnu', `select mission_public_card('00000000-0000-0000-0000-00000000dead')`, /introuvable/);
  await as(HOST);
  check('J7d l\'auteur voit son brouillon (non ouvert)', (await rpc(`mission_public_card('${M2}')`)).open === false);
  const LAct = await mk(HOST, 'Atelier avec action', { at: '2 days' });
  await as(HOST);
  const sm = (m) => `select live_set_settings('${LAct}', '{"main_action":"postuler","action_target_kind":"mission","action_target_id":"${m}"}'::jsonb)`;
  await fails('J8 action Postuler sur un brouillon : refusée', sm(M2), /ne reçoit pas de propositions/);
  await fails('J8b sur une mission privée : refusée', sm(M3), /ne reçoit pas de propositions/);
  await fails('J8c sur la mission d\'un autre : refusée', sm(M4), /n'appartient pas|n''appartient pas/);
  check('J8d cibles proposées : uniquement les besoins publiés et ouverts', (await rpc(`live_action_targets('mission')`)).map((x) => x.id).join() === M1);
  await q(sm(M1));
  let st = await rpc(`live_settings_get('${LAct}')`);
  check('J9 action Postuler sur un besoin ouvert : bouton disponible avec le titre', st.action_available === true && st.main_action === 'postuler' && st.action_target_kind === 'mission' && st.action_target_title === 'Site vitrine', JSON.stringify(st));
  await sup(); await db.exec(`update missions set status = 'draft' where id = '${M1}'`);
  await as(S1);
  st = await rpc(`live_settings_get('${LAct}')`);
  check('J10 besoin fermé après coup : le bouton disparaît (action_available faux, aucune cible exposée)', st.action_available === false && st.action_target_id === null, JSON.stringify(st));

  // ============================================================ K. Sécurité des enregistrements (retour du webhook)
  await sup(); await db.exec(`update live_recording_config set enabled = true`);
  const mkRecEg = async (title, egress) => {
    const l = await mk(HOST, title, { status: 'ended', at: null });
    return (await qs(`insert into live_recordings (live_id, requested_by, status, egress_id, egress_status) values ('${l}', '${HOST}', 'en_attente', '${egress}', 'active') returning id`))[0].id;
  };
  const evt = async (egress, path, dur = 300) => {
    await sup(); await db.exec('reset role; set role service_role');
    let r; try { r = (await q(`select live_recording_egress_event('${egress}', 'complete', ${path === null ? 'null' : `'${path}'`}, ${dur}, null) r`))[0].r; } catch (e) { r = e.message; }
    await sup(); return r;
  };
  const recRow = async (id) => (await qs(`select status, egress_status, egress_error, storage_path from live_recordings where id = '${id}'`))[0];
  const badPaths = ['../autre/secret.mp4', '/etc/passwd', 'a//b.mp4', 'live/../x.mp4', 'dossier/fichier mp4', 'a/b.mp4\nx', 'ab.m'];
  for (const [i, p] of badPaths.entries()) {
    const id = await mkRecEg(`Chemin dangereux ${i}`, `EG-K-BAD-${i}`);
    const r = await evt(`EG-K-BAD-${i}`, p);
    const row = await recRow(id);
    check(`K${i + 1} chemin dangereux « ${p.replace(/\n/g, '\\n')} » : échec, jamais prêt`, r === 'failed' && row.status === 'en_attente' && row.storage_path === null, JSON.stringify([r, row]));
  }
  const KA = await mkRecEg('Livraison valide', 'EG-K-OK');
  check('K8 chemin sobre : replay prêt', (await evt('EG-K-OK', 'live-x/rec-1.mp4')) === 'pret' && (await recRow(KA)).status === 'pret');
  const KB = await mkRecEg('Fichier déjà pris', 'EG-K-DUP');
  check('K9 fichier déjà attribué à un autre enregistrement : échec honnête, le premier replay intact', (await evt('EG-K-DUP', 'live-x/rec-1.mp4')) === 'failed'
    && /déjà attribué/.test((await recRow(KB)).egress_error) && (await recRow(KB)).status === 'en_attente' && (await recRow(KA)).storage_path === 'live-x/rec-1.mp4');
  check('K10 événement rejoué sur un replay prêt : sans effet', (await evt('EG-K-OK', 'live-x/autre.mp4', 999)) === 'pret' && (await recRow(KA)).storage_path === 'live-x/rec-1.mp4');
  await as(V1);
  check('K11 un tiers ne voit aucun enregistrement ni chemin (RLS)', (await q('select count(*)::int n from live_recordings'))[0].n === 0);
  await fails('K12 un tiers ne peut pas appeler le retour du webhook', `select live_recording_egress_event('EG-K-OK', 'failed', null, null, 'x')`, DENY);
  await as(null);
  await fails('K13 anonyme : enregistrements illisibles', 'select * from live_recordings', DENY);
  await sup(); await db.exec(`update live_recording_config set enabled = false`);

  // ============================================================ H. RLS et rejeu
  await as(V1);
  check('H1 un utilisateur ne voit que ses propres rappels', (await q(`select count(*)::int n from live_reminders where user_id <> '${V1}'`))[0].n === 0);
  await as(null);
  await fails('H2 anonyme : lecture des rappels refusée', 'select * from live_reminders', DENY);
  await sup();
  const before = (await q(`select (select count(*)::int from notifications) a, (select count(*)::int from live_reminders) b`))[0];
  let err = '';
  for (const f of ['20261128020000_h13_live_rappels_audit.sql', '20261128021000_h13_replay_quiz_hote.sql', '20261128022000_h13_live_action_mission.sql', '20261128023000_h13_live_securite_enregistrements.sql']) {
    try { await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); } catch (e) { err += `${f}: ${e.message}`; }
  }
  check('H3 rejeu des migrations 20261128020000, 021000, 022000 et 023000 : sans erreur', err === '', err);
  const after = (await q(`select (select count(*)::int from notifications) a, (select count(*)::int from live_reminders) b`))[0];
  check('H4 après rejeu : données conservées, aucun rappel envoyé', before.a === after.a && before.b === after.b, JSON.stringify([before, after]));
  console.log(`\n${ok}/${ok + ko}`);
}
