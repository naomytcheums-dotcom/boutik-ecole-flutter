// Scénario PGlite du lot H13 / RANKING (migrations 20261128010000 à 20261128010400) :
//  A. présence réelle aux événements (code organisateur, fenêtre, inscription valable, anti-doublon, annulation) branchée sur le score ;
//  B. proposition de pondérations initiales (brouillon, jamais active, aucune publication) ;
//  C. cohérence profil / compétences / badges / collaborations / replays / score ;
//  D. explications publiques du classement ; E. contestations, corrections, archivage ; F. anti-fraude durci ; G. rejeu des migrations.
// Toutes les données sont des fixtures de test (aucune pondération n'est fixée par le code).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h13_ranking.mjs
import fs from 'fs';
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-00000016${String(n).padStart(4, '0')}`;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims({})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const sup = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { await sup(); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const DENY = /permission denied|Connexion requise|Réservé|refusé|introuvable|exige/i;
  const P1 = (await qs(`select to_char(now() at time zone 'utc', 'YYYY-MM') p`))[0].p;

  // ============================================================ FIXTURES
  const mkUser = async (n, role, name, email, extra = '') => { await db.exec(`insert into auth.users(id,email) values ('${U(n)}','${email}'); insert into profiles(id,name,role,email${extra ? ', matricule' : ''}) values ('${U(n)}','${name}','${role}','${email}'${extra ? `, '${extra}'` : ''})`); return U(n); };
  const ADM = await mkUser(1, 'admin', 'Admin Ranking', 'rk1@t.cm');
  const PUB = await mkUser(2, 'support', 'Agent Classement', 'rk2@t.cm');
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${PUB}', 'ranking', array['ranking.publish', 'ranking.rules', 'ranking.moderate'])`);
  const MOD = await mkUser(3, 'support', 'Agent Modération', 'rk3@t.cm');
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${MOD}', 'ranking', array['ranking.moderate'])`);
  const ORG1 = await mkUser(10, 'dept', 'Organisateur Un', 'org1@t.cm');
  const ORG2 = await mkUser(11, 'dept', 'Organisateur Deux', 'org2@t.cm');
  const CMP = await mkUser(12, 'company', 'Entreprise Test', 'cmp@t.cm');
  const I1 = '00000000-0000-0000-0000-00000016a001', D1 = '00000000-0000-0000-0000-00000016a011', G1 = '00000000-0000-0000-0000-00000016a021';
  await db.exec(`insert into institutions (id, name, short_name, status) values ('${I1}', 'Université Ranking', 'URK', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified');
    insert into programs (id, institution_id, department_id, name) values ('${G1}', '${I1}', '${D1}', 'Génie logiciel')`);
  const mkStudent = async (n, { verified = true, consent = false, program = false, email = null, name = null, matricule = null } = {}) => {
    const id = U(100 + n);
    await db.exec(`insert into auth.users(id,email) values ('${id}','${email ?? `rks${n}@t.cm`}'); insert into profiles(id,name,role,email${matricule ? ', matricule' : ''}) values ('${id}','${name ?? `Etudiant Rk${n}`}','student','${email ?? `rks${n}@t.cm`}'${matricule ? `, '${matricule}'` : ''})`);
    if (verified) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${id}', 'student_card', 'c.pdf', '${id}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${id}'`);
    if (program) await db.exec(`insert into student_affiliations (user_id, institution_id, department_id, program_id, promotion, status) values ('${id}', '${I1}', '${D1}', '${G1}', '2026', 'verified')`);
    if (consent) await db.exec(`insert into talent_visibility_settings (user_id, public_ranking, show_full_name, shared_sections) values ('${id}', true, true, array['rank','score','evolution','skills','badges','projects','passport'])`);
    return id;
  };
  const S = []; for (let i = 1; i <= 12; i++) S[i] = await mkStudent(i, { consent: true, program: true });
  const evs = (u, rule) => qs(`select id, status, status_reason, actor_id, source_kind, source_id, meta from talent_events where user_id = '${u}' and rule_code = '${rule}' order by id`);
  const total = async (u) => Number((await qs(`select coalesce((select total from talent_scores where user_id = '${u}'), 0) t`))[0].t);
  const ledgerSum = async (u) => Number((await qs(`select coalesce(sum(points), 0) t from talent_score_ledger where user_id = '${u}'`))[0].t);
  const notifs = async (u, kind) => Number((await qs(`select count(*)::int n from notifications where user_id = '${u}' and kind = '${kind}'`))[0].n);

  // ============================================================ A. PRÉSENCE AUX ÉVÉNEMENTS
  check('A1 migrations seules : aucune présence, aucun code, aucun événement de score', (await qs(`select (select count(*) from event_attendance) + (select count(*) from event_attendance_codes) + (select count(*) from talent_events) n`))[0].n == 0);
  const mkEvent = async (title, startsOffset, endsOffset, by, status = 'published', createdAgo = '7 days') => (await qs(`insert into events (title, starts_at, ends_at, created_by, status, created_at) values ('${title}', now() + interval '${startsOffset}', ${endsOffset ? `now() + interval '${endsOffset}'` : 'null'}, '${by}', '${status}', now() - interval '${createdAgo}') returning id`))[0].id;
  const reg = (ev, u, status = 'confirmed') => qs(`insert into event_registrations (event_id, user_id, status) values ('${ev}', '${u}', '${status}') on conflict (event_id, user_id) do update set status = excluded.status`);
  const EV1 = await mkEvent('Masterclass Un', '-30 minutes', '2 hours', ORG1);
  const EVF = await mkEvent('Atelier futur', '3 days', '3 days 2 hours', ORG1);
  const EVP = await mkEvent('Atelier passé', '-2 days', '-2 days 1 hour', ORG1);
  const EVD = await mkEvent('Brouillon', '-10 minutes', '1 hour', ORG1, 'draft');
  const EVS = await mkEvent('Bientôt', '10 minutes', '2 hours', ORG1);
  const EVO = await mkEvent('Chevauchement', '-10 minutes', '90 minutes', ORG1);
  for (const [ev, us] of [[EV1, [1, 2, 3, 4, 5]], [EVF, [1]], [EVP, [1]], [EVD, [1]], [EVS, [1]], [EVO, [2]]]) for (const u of us) await reg(ev, S[u]);
  await reg(EV1, S[6], 'cancelled');
  // S7 (non inscrit) et S8 (suspendu inscrit) ; client non étudiant
  await reg(EV1, S[8]);
  await qs(`update profiles set suspended = true where id = '${S[8]}'`);

  for (const f of [`event_attendance_code_generate('${EV1}')`, `event_attendance_list('${EV1}')`, `event_attendance_check_in('${EV1}', 'AAAAAAAA')`, `my_event_attendance()`]) {
    await as(null); await fails(`A2 anonyme refusé : ${f.split('(')[0]}`, `select ${f}`, DENY);
  }
  await as(S[1]); await fails('A3 un étudiant ne génère pas de code', `select event_attendance_code_generate('${EV1}')`, /introuvable/i);
  await fails('A3b un étudiant ne lit pas la liste des présents', `select event_attendance_list('${EV1}')`, /introuvable/i);
  await fails('A3c accès direct aux tables refusé', `select * from event_attendance_codes`, /permission denied/i);
  await fails('A3d accès direct aux présences refusé', `select * from event_attendance`, /permission denied/i);
  await fails('A3e écriture directe d\'une présence refusée', `insert into event_attendance (event_id, user_id, code_version) values ('${EV1}', '${S[1]}', 1)`, /permission denied/i);
  await fails('A3f fonctions internes refusées', `select _event_attendance_sync('${EV1}', '${S[1]}')`, /permission denied/i);
  await as(ORG2); await fails('A4 un autre organisateur ne génère pas le code', `select event_attendance_code_generate('${EV1}')`, /introuvable/i);
  await fails('A4b un autre organisateur ne lit pas la liste', `select event_attendance_list('${EV1}')`, /introuvable/i);
  await as(CMP); await fails('A4c une entreprise ne génère pas de code', `select event_attendance_code_generate('${EV1}')`, /introuvable/i);
  await as(ORG1);
  await fails('A5 événement non publié : pas de code', `select event_attendance_code_generate('${EVD}')`, /pas publié/i);
  await fails('A5b fenêtre terminée : pas de code', `select event_attendance_code_generate('${EVP}')`, /terminée/i);
  const c1 = await rpc(`event_attendance_code_generate('${EV1}')`);
  check('A6 code de 8 caractères, version 1, fenêtre ouverte', /^[0-9A-F]{8}$/.test(c1.code) && c1.version === 1 && c1.window_open === true && /^[0-9A-F]{4}-[0-9A-F]{4}$/.test(c1.code_display), JSON.stringify(c1));
  const c1b = await rpc(`event_attendance_code_generate('${EV1}')`);
  check('A6b ré-appel sans renouvellement : même code', c1b.code === c1.code && c1b.version === 1);
  const cf = await rpc(`event_attendance_code_generate('${EVF}')`);
  check('A6c code possible avant la fenêtre, fenêtre fermée', /^[0-9A-F]{8}$/.test(cf.code) && cf.window_open === false);

  // règle encore en brouillon : la présence est tracée, 0 point
  await as(S[7]);
  await fails('A7b étudiant sans inscription : pointage refusé même avec le bon code', `select event_attendance_check_in('${EV1}', '${c1.code}')`, /pas inscrit/i);
  await as(S[6]);
  await fails('A7c inscription annulée : pointage refusé', `select event_attendance_check_in('${EV1}', '${c1.code}')`, /pas inscrit/i);
  await as(S[8]);
  await fails('A7d compte suspendu : pointage refusé', `select event_attendance_check_in('${EV1}', '${c1.code}')`, /étudiants|pas inscrit/i);
  await as(CMP);
  await fails('A7e compte non étudiant : pointage refusé', `select event_attendance_check_in('${EV1}', '${c1.code}')`, /étudiants/i);
  await as(S[1]);
  await fails('A8 hors fenêtre (événement futur) : refusé même avec le bon code', `select event_attendance_check_in('${EVF}', '${cf.code}')`, /pendant l'événement/i);
  await fails('A8b hors fenêtre (événement passé) : refusé', `select event_attendance_check_in('${EVP}', 'AAAAAAAA')`, /pendant l'événement|pas inscrit/i);
  await fails('A8c événement non publié : introuvable', `select event_attendance_check_in('${EVD}', 'AAAAAAAA')`, /introuvable/i);
  await fails('A8d code mal formé refusé', `select event_attendance_check_in('${EV1}', 'ABC')`, /8 caractères/i);
  await fails('A8e aucun code émis pour l\'événement : refusé', `select event_attendance_check_in('${EVS}', 'AAAAAAAA')`, /pas encore émis/i);
  let r = await rpc(`event_attendance_check_in('${EV1}', 'ZZZZZZZZ')`);
  check('A9 code faux : refus explicite, tentative restante comptée, aucune présence', r.ok === false && r.reason === 'bad_code' && r.remaining_attempts === 4
    && (await qs(`select count(*)::int n from event_attendance where user_id = '${S[1]}'`))[0].n === 0, JSON.stringify(r));
  for (let i = 0; i < 4; i++) { await as(S[1]); r = await rpc(`event_attendance_check_in('${EV1}', 'ZZZZZZZ${i}')`); }
  check('A9b 5e code faux : plus aucune tentative restante', r.ok === false && r.remaining_attempts === 0, JSON.stringify(r));
  await as(S[1]);
  await fails('A9c blocage temporaire : même le bon code est refusé après 5 échecs', `select event_attendance_check_in('${EV1}', '${c1.code}')`, /Trop de codes erronés/i);
  await as(S[2]);
  check('A9d le blocage est individuel : un autre étudiant pointe normalement', (await rpc(`event_attendance_check_in('${EV1}', '${c1.code.toLowerCase().slice(0, 4)}-${c1.code.slice(4)}')`)).ok === true);
  await fails('A10 double pointage refusé', `select event_attendance_check_in('${EV1}', '${c1.code}')`, /déjà enregistrée/i);
  await sup();
  let e = await evs(S[2], 'event_attended');
  check('A11 présence confirmée -> activité event_attended confirmée, auteur = organisateur, source unique', e.length === 1 && e[0].status === 'confirmed' && e[0].actor_id === ORG1 && e[0].source_kind === 'event_attendance' && e[0].source_id === `${EV1}:${S[2]}`, JSON.stringify(e));
  check('A11b règle en brouillon : 0 point, score cohérent', (await total(S[2])) === 0 && (await ledgerSum(S[2])) === 0);
  check('A11c notification « Présence enregistrée » à l\'étudiant', (await notifs(S[2], 'event')) >= 1);
  check('A11d présence unique par (événement, étudiant)', (await qs(`select count(*)::int n from event_attendance where event_id = '${EV1}' and user_id = '${S[2]}'`))[0].n === 1);

  // règle activée par l'administration (valeurs de test) : la présence suivante rapporte des points
  await as(PUB);
  await works('A12 activation de la règle event_attended (valeurs de test)', `select admin_talent_rule_set('event_attended', 10, 20, 50, 0, true, 'Activation de test de la présence') r`, (x) => x[0].r.active === true);
  await as(S[3]);
  check('A13 pointage avec le bon code après activation', (await rpc(`event_attendance_check_in('${EV1}', '${c1.code}')`)).ok === true);
  await sup();
  check('A13b 10 points attribués une seule fois, registre cohérent', (await total(S[3])) === 10 && (await ledgerSum(S[3])) === 10);
  // renouvellement du code : l'ancien ne marche plus
  await as(ORG1);
  const c2 = await rpc(`event_attendance_code_generate('${EV1}', true)`);
  check('A14 renouvellement : nouveau code, version 2', c2.code !== c1.code && c2.version === 2, JSON.stringify(c2));
  await as(S[4]);
  r = await rpc(`event_attendance_check_in('${EV1}', '${c1.code}')`);
  check('A14b ancien code refusé après renouvellement', r.ok === false && r.reason === 'bad_code', JSON.stringify(r));
  check('A14c nouveau code accepté', (await rpc(`event_attendance_check_in('${EV1}', '${c2.code}')`)).ok === true);
  await as(ORG1);
  await works('A15 liste organisateur : 3 présents, inscrits valables comptés', `select event_attendance_list('${EV1}') r`,
    (x) => x[0].r.present === 3 && x[0].r.registered === 6 && x[0].r.items.length === 3 && x[0].r.window_open === true && x[0].r.code_issued === true && x[0].r.code_version === 2
      && x[0].r.items.every((i) => i.name && !('email' in i)));
  await as(S[4]);
  await works('A16 mes présences : événement pointé marqué, autres non', `select my_event_attendance() r`,
    (x) => { const a = x[0].r.find((i) => i.event === EV1); return a && a.attended === true && a.window_open === true && x[0].r.length >= 1; });
  // chevauchement
  await as(ORG1);
  const co = await rpc(`event_attendance_code_generate('${EVO}')`);
  await as(S[2]);
  await fails('A17 deux événements simultanés : le second pointage est refusé', `select event_attendance_check_in('${EVO}', '${co.code}')`, /autre événement au même moment/i);
  // pointage dans la marge avant le début (événement « Bientôt », 10 min avant)
  await as(ORG1);
  const cs = await rpc(`event_attendance_code_generate('${EVS}')`);
  await as(S[1]);
  await qs(`delete from event_attendance_attempts where user_id = '${S[1]}'`);
  await as(S[1]);
  check('A18 pointage dans la marge de 15 minutes avant le début', (await rpc(`event_attendance_check_in('${EVS}', '${cs.code}')`)).ok === true);

  // annulation : l'inscription est annulée -> présence annulée, points retirés
  await sup();
  const n0 = await notifs(S[3], 'event');
  await qs(`update event_registrations set status = 'cancelled' where event_id = '${EV1}' and user_id = '${S[3]}'`);
  e = await evs(S[3], 'event_attended');
  check('A19 inscription annulée : présence annulée, activité annulée, points retirés exactement', e[0].status === 'cancelled' && (await total(S[3])) === 0 && (await ledgerSum(S[3])) === 0
    && (await qs(`select status from event_attendance where event_id = '${EV1}' and user_id = '${S[3]}'`))[0].status === 'cancelled', JSON.stringify(e));
  check('A19b l\'étudiant est prévenu', (await notifs(S[3], 'event')) === n0 + 1);
  await qs(`update event_registrations set status = 'confirmed' where event_id = '${EV1}' and user_id = '${S[3]}'`);
  check('A19c réinscription seule : la présence reste annulée (aucun point)', (await total(S[3])) === 0);
  await as(S[3]);
  check('A19d nouveau pointage valide après réinscription : réactivation, 10 points une seule fois', (await rpc(`event_attendance_check_in('${EV1}', '${c2.code}')`)).ok === true);
  await sup();
  check('A19e un seul événement de score, 10 points', (await evs(S[3], 'event_attended')).length === 1 && (await total(S[3])) === 10);
  // remboursement
  await qs(`update event_registrations set refund_status = 'to_refund' where event_id = '${EV1}' and user_id = '${S[3]}'`);
  check('A20 inscription à rembourser : présence annulée, points retirés', (await total(S[3])) === 0 && (await evs(S[3], 'event_attended'))[0].status === 'cancelled');
  // désinscription (suppression de l'inscription gratuite)
  await qs(`delete from event_registrations where event_id = '${EV1}' and user_id = '${S[4]}'`);
  check('A21 inscription supprimée : présence et points annulés', (await evs(S[4], 'event_attended'))[0].status === 'cancelled' && (await total(S[4])) === 0 && (await ledgerSum(S[4])) === 0);
  // événement annulé
  await qs(`update events set status = 'cancelled' where id = '${EV1}'`);
  check('A22 événement annulé : toutes les présences annulées, points retirés', (await qs(`select count(*)::int n from event_attendance where event_id = '${EV1}' and status = 'confirmed'`))[0].n === 0 && (await total(S[2])) === 0);
  check('A22b cohérence : score = somme du registre pour tous', (await qs(`select count(*)::int n from talent_scores s where s.total <> coalesce((select sum(points) from talent_score_ledger l where l.user_id = s.user_id), 0)`))[0].n === 0);
  await as(S[5]);
  await fails('A22c événement annulé : pointage refusé', `select event_attendance_check_in('${EV1}', '${c2.code}')`, /introuvable/i);
  // suppression de l'événement
  await sup();
  await qs(`update events set status = 'published' where id = '${EV1}'`);
  await qs(`update event_registrations set status = 'confirmed', refund_status = null where event_id = '${EV1}' and user_id = '${S[3]}'`);
  await as(S[3]);
  await rpc(`event_attendance_check_in('${EV1}', '${c2.code}')`);
  await as(S[5]);
  await rpc(`event_attendance_check_in('${EV1}', '${c2.code}')`);
  await sup();
  check('A23 plafond du jour : annuler puis re-pointer ne contourne pas le plafond (S3 : 0 point de plus) ; S5 : 10 points', (await total(S[3])) === 0 && (await total(S[5])) === 10 && (await evs(S[3], 'event_attended'))[0].status === 'confirmed',
    `${await total(S[3])} ${await total(S[5])}`);
  await qs(`delete from events where id = '${EV1}'`);
  check('A23b événement supprimé : activités annulées et points retirés', (await evs(S[5], 'event_attended'))[0].status === 'cancelled' && (await total(S[5])) === 0 && (await evs(S[3], 'event_attended'))[0].status === 'cancelled');
  // organisateur lié : e-mail à l'alias près / même matricule
  const OL = await mkUser(13, 'dept', 'Organisateur Lié', 'jean.lie+org@t.cm');
  const EVL = await mkEvent('Événement lié', '-10 minutes', '2 hours', OL);
  const SL = await mkStudent(21, { consent: true, program: true, email: 'jeanlie@t.cm', name: 'Jean Lié' });
  await reg(EVL, SL);
  await as(OL);
  const cl = await rpc(`event_attendance_code_generate('${EVL}')`);
  await as(SL);
  await rpc(`event_attendance_check_in('${EVL}', '${cl.code}')`);
  await sup();
  e = await evs(SL, 'event_attended');
  check('A24 organisateur et étudiant liés (même e-mail à l\'alias près) : activité neutralisée, 0 point, alerte ouverte', e.length === 1 && e[0].status === 'neutralized' && /Comptes liés/.test(e[0].status_reason) && (await total(SL)) === 0
    && (await qs(`select count(*)::int n from talent_fraud_flags where user_id = '${SL}' and status = 'open'`))[0].n === 1, JSON.stringify(e));
  // organisateur = même matricule
  const OM = await mkUser(14, 'dept', 'Organisateur Matricule', 'om@t.cm', 'MAT-7777');
  const SM = await mkStudent(22, { consent: true, program: true, matricule: 'mat-7777' });
  const EVM = await mkEvent('Événement matricule', '-10 minutes', '2 hours', OM);
  await reg(EVM, SM);
  await as(OM);
  const cm = await rpc(`event_attendance_code_generate('${EVM}')`);
  await as(SM);
  await rpc(`event_attendance_check_in('${EVM}', '${cm.code}')`);
  check('A25 même matricule que l\'organisateur : activité neutralisée', (await evs(SM, 'event_attended'))[0].status === 'neutralized');
  // administration (rôle admin) : organisateur de tout événement
  await as(ADM);
  await works('A26 l\'administration lit la liste des présents de n\'importe quel événement', `select event_attendance_list('${EVL}') r`, (x) => x[0].r.present === 1);
  await sup();
  const snapA = async () => JSON.stringify((await qs(`select (select count(*) from event_attendance) a, (select count(*) from event_attendance_codes) c, (select count(*) from event_attendance_attempts) t,
    (select count(*) from talent_events) e, (select count(*) from talent_score_ledger) l, (select count(*) from talent_scores) s, (select sum(total) from talent_scores) st, (select count(*) from notifications) n`))[0]);
  const beforeA = await snapA();
  const migDir = new URL('../../migrations/', import.meta.url);
  const f0 = fs.readdirSync(migDir).find((f) => f.startsWith('20261128010000_'));
  let rejeuOk = true; try { await db.exec(fs.readFileSync(new URL(f0, migDir), 'utf8')); } catch (er) { rejeuOk = false; console.log('ECHEC rejeu', f0, er.message); }
  check('A27 rejeu de la migration de présence : sans erreur ni effet de bord', rejeuOk && (await snapA()) === beforeA);

  // ============================================================ B. PROPOSITION DE PONDÉRATIONS (brouillon, jamais active)
  await sup();
  const settingsBefore = (await qs(`select count(*)::int n from ranking_settings`))[0].n;
  for (const f of [`admin_talent_rules_proposal()`, `admin_talent_rules_apply_proposal('Application de la proposition initiale')`]) {
    await as(null); await fails(`B1 anonyme refusé : ${f.split('(')[0]}`, `select ${f}`, DENY);
    await as(S[1]); await fails(`B1b étudiant refusé : ${f.split('(')[0]}`, `select ${f}`, DENY);
    await as(MOD); await fails(`B1c agent sans ranking.rules refusé : ${f.split('(')[0]}`, `select ${f}`, DENY);
    await as(ORG1); await fails(`B1d organisateur refusé : ${f.split('(')[0]}`, `select ${f}`, DENY);
  }
  await as(PUB);
  await works('B2 lecture de la proposition : 13 familles, seuils proposés, rien d\'appliqué', `select admin_talent_rules_proposal() r`,
    (x) => x[0].r.rules.length === 13 && x[0].r.proposal_only === true && x[0].r.thresholds.min_score === 50 && x[0].r.thresholds.entries_limit === 100 && x[0].r.rules.every((i) => i.rationale && i.category));
  await fails('B3 motif trop court refusé', `select admin_talent_rules_apply_proposal('court')`, /Motivez/i);
  await fails('B4 une règle déjà active : la proposition ne la remplace pas', `select admin_talent_rules_apply_proposal('Application de la proposition initiale')`, /déjà actives/i);
  await works('B4b désactivation de la règle de test', `select admin_talent_rule_set('event_attended', 10, 20, 50, 0, false, 'Retour au brouillon avant la proposition') r`, (x) => x[0].r.active === false);
  const verBefore = (await qs(`select jsonb_object_agg(code, version) v from talent_score_rules`))[0].v;
  await as(PUB);
  const ap = await rpc(`admin_talent_rules_apply_proposal('Application de la proposition initiale de pondérations')`);
  check('B5 proposition enregistrée : 13 règles, aucune active', ap.ok === true && ap.draft_only === true && ap.active_rules === 0 && ap.applied + ap.unchanged === 13 && ap.applied >= 12, JSON.stringify(ap));
  await sup();
  const rules = await qs(`select code, points, cap_per_day, cap_per_period, quality_weight::float8 w, active, version from talent_score_rules order by code`);
  check('B5b toutes les règles sont inactives (brouillon) avec les valeurs proposées', rules.length === 13 && rules.every((r) => r.active === false && r.points > 0) && rules.find((r) => r.code === 'assessment_validated').points === 120
    && rules.find((r) => r.code === 'review_verified').w === 0.8 && rules.find((r) => r.code === 'review_verified').cap_per_period === 120);
  check('B5c poids qualité : seulement là où une qualité est mesurée (avis)', rules.filter((r) => r.w > 0).map((r) => r.code).join() === 'review_verified');
  check('B5d plafonds cohérents : plafond de période >= plafond du jour', rules.every((r) => r.cap_per_period >= r.cap_per_day));
  check('B5e popularité : les familles à plus forts points sont des réalisations vérifiées', rules.filter((r) => r.points >= 70).every((r) => ['assessment_validated', 'mission_validated', 'certificate_verified', 'project_published_with_proof'].includes(r.code)));
  const hist = await qs(`select count(*)::int n from talent_score_rule_history where reason like 'Proposition de pondérations initiales (brouillon)%'`);
  check('B5f historique : une version par règle modifiée, motif tracé', hist[0].n === ap.applied);
  check('B5g audit : une ligne « Proposition de pondérations enregistrée en brouillon »', (await qs(`select count(*)::int n from audit_log where action like 'Proposition de pondérations enregistrée%' and category = 'Classement'`))[0].n === 1);
  check('B5h les réglages de publication ne sont pas écrits, aucun classement ni entrée', (await qs(`select count(*)::int n from ranking_settings`))[0].n === settingsBefore && (await qs(`select (select count(*) from ranking_periods) + (select count(*) from ranking_entries) n`))[0].n == 0);
  await as(PUB);
  const ap2 = await rpc(`admin_talent_rules_apply_proposal('Seconde application identique de la proposition')`);
  await sup();
  const verAfter = (await qs(`select jsonb_object_agg(code, version) v from talent_score_rules`))[0].v;
  const verMid = JSON.stringify(verAfter);
  check('B6 seconde application : idempotente (aucune version supplémentaire)', ap2.applied === 0 && ap2.unchanged === 13 && JSON.stringify((await qs(`select jsonb_object_agg(code, version) v from talent_score_rules`))[0].v) === verMid);
  check('B6b versions incrémentées seulement pour les règles modifiées', Object.keys(verBefore).every((k) => verAfter[k] >= verBefore[k]));
  await as(PUB);
  await works('B7 les valeurs proposées sont visibles comme règles inactives, avec écart nul', `select admin_talent_rules_proposal() r`, (x) => x[0].r.rules.every((i) => i.differs === false && i.current.active === false));
  await works('B7b règles publiques : aucune règle active, donc rien n\'est affiché comme en vigueur', `select talent_rules_public() r`, (x) => x[0].r.length === 0);
  await works('B7c réglages de publication décidés (fixture de test) : seuil, entrées, portées', `select admin_ranking_settings_set(50, 3, 100, array['national','institution','program'], 'Réglages de test : fixture') r`, (x) => x[0].r.decided === true);
  await fails('B8 ranking_publish refuse : aucune règle active malgré réglages et proposition enregistrée', `select ranking_publish('${P1}')`, /Aucune règle de score active/i);
  await works('B8b préparation de publication : bloquée, rien créé', `select admin_ranking_readiness('${P1}') r`, (x) => x[0].r.ready === false && x[0].r.blockers.some((b) => /Aucune règle de score active/.test(b)));
  await sup();
  const B9 = await qs(`select _talent_event_record('${S[9]}', 'mission_validated', 'mission', 'b9-test', now(), null, null, '{}'::jsonb) id`);
  check('B9 règle proposée mais inactive : l\'activité est tracée sans point', B9[0].id !== null && (await total(S[9])) === 0 && (await ledgerSum(S[9])) === 0);
  await as(S[9]);
  await works('B9c l\'étudiant voit « règle inactive »', `select my_talent_score_explain() r`, (x) => x[0].r.without_points.length === 1 && x[0].r.without_points[0].cause === 'rule_inactive');
  await sup();
  check('B10 aucun classement publié, aucune ligne de classement (rien n\'est publié par la proposition)', (await qs(`select (select count(*) from ranking_periods) + (select count(*) from ranking_entries) + (select count(*) from ranking_institution_entries) n`))[0].n == 0);

  // ============================================================ C. COHÉRENCE PROFIL / COMPÉTENCES / BADGES / COLLABORATIONS / REPLAYS / SCORE
  await sup();
  const TS = await mkStudent(30, { consent: true, program: true }), TB = await mkStudent(31, { consent: true, program: true }), TC = await mkStudent(32, { consent: true, program: true }),
    TM = await mkStudent(33, { consent: true, program: true }), TCL = await mkStudent(34, { consent: true, program: true }), TP = await mkStudent(35, { consent: true });
  await qs(`update talent_visibility_settings set shared_sections = '{}' where user_id in ('${TS}', '${TB}', '${TC}', '${TM}', '${TCL}')`);
  const snapC = async () => JSON.stringify((await qs(`select (select count(*) from talent_events) e, (select count(*) from talent_score_ledger) l, (select sum(total) from talent_scores) s, (select count(*) from talent_fraud_flags) f, (select count(*) from notifications) n,
    (select count(*) from audit_log) a`))[0]);
  const issues = async (u, via = 'admin') => { if (via === 'admin') { await as(MOD); return (await rpc(`admin_talent_consistency_check('${u}')`)); } await as(u); return rpc(`my_talent_consistency()`); };
  const has = (res, code, sev) => res.issues.some((x) => x.code === code && (!sev || x.severity === sev));
  await as(null); await fails('C1 anonyme refusé : contrôle administrateur', `select admin_talent_consistency_check('${TS}')`, DENY);
  await fails('C1b anonyme refusé : contrôle étudiant', `select my_talent_consistency()`, DENY);
  await as(S[1]); await fails('C1c un étudiant ne lance pas le contrôle d\'un autre compte', `select admin_talent_consistency_check('${TS}')`, DENY);
  await as(ORG1); await fails('C1d un organisateur sans droit de classement refusé', `select admin_talent_consistency_check('${TS}')`, DENY);
  await fails('C1e un compte non étudiant n\'a pas de cohérence personnelle', `select my_talent_consistency()`, /étudiants/i);
  await as(MOD); await fails('C1f compte inconnu', `select admin_talent_consistency_check('${U(999)}')`, /introuvable/i);
  let c = await issues(TCL);
  check('C2 étudiant sans source ni écart : cohérent, aucune alerte, rien de corrigé', c.applicable === true && c.consistent === true && c.issues.length === 0 && c.auto_correction === false && c.student, JSON.stringify(c));
  c = await issues(ORG1);
  check('C3 cible non étudiante : non applicable', c.applicable === false);
  const before = await snapC();
  // compétences
  await sup();
  const doc = async (owner, n) => (await q(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values ('${owner}', 'certificate', 'att.pdf', '${owner}/cert/${n}.pdf', 'application/pdf', 10) returning id`))[0].id;
  const sk1 = (await q(`insert into talent_skills (owner_id, domain, skill, level) values ('${TS}', 'Informatique', 'Sans preuve', 'debutant') returning id`))[0].id;
  const dP = await doc(TS, 'p1');
  const sk2 = (await q(`insert into talent_skills (owner_id, domain, skill, level, proof_document_id) values ('${TS}', 'Informatique', 'Preuve en attente', 'avance', '${dP}') returning id`))[0].id;
  c = await issues(TS);
  check('C4 compétence sans justificatif : information (aucun point)', has(c, 'skill_without_proof', 'info') && c.issues.find((x) => x.code === 'skill_without_proof').refs.includes(sk1), JSON.stringify(c.issues));
  check('C4b justificatif non vérifié : avertissement', has(c, 'skill_proof_not_verified', 'warning') && c.issues.find((x) => x.code === 'skill_proof_not_verified').refs.includes(sk2));
  check('C4c cohérent = faux dès qu\'un avertissement existe, résumé chiffré', c.consistent === false && c.summary.warnings >= 1 && c.summary.infos >= 1 && c.summary.errors === 0, JSON.stringify(c.summary));
  await sup();
  await db.exec(`alter table talent_skills disable trigger trg_talent_skills; alter table user_documents disable trigger trg_talent_skill_docs`);
  const dV = await doc(TS, 'p2');
  await db.exec(`update user_documents set status = 'verified', reviewed_by = '${ADM}', reviewed_at = now() where id = '${dV}'`);
  const sk3 = (await q(`insert into talent_skills (owner_id, domain, skill, level, proof_document_id) values ('${TS}', 'Informatique', 'Vérifiée sans activité', 'expert', '${dV}') returning id`))[0].id;
  await db.exec(`alter table talent_skills enable trigger trg_talent_skills; alter table user_documents enable trigger trg_talent_skill_docs`);
  c = await issues(TS);
  check('C5 justificatif vérifié sans activité de score : avertissement', has(c, 'skill_verified_without_event', 'warning') && c.issues.find((x) => x.code === 'skill_verified_without_event').refs.includes(sk3), JSON.stringify(c.issues));
  await sup();
  const dW = await doc(TS, 'p3');
  await db.exec(`update user_documents set status = 'verified', reviewed_by = '${ADM}', reviewed_at = now() where id = '${dW}'`);
  const sk4 = (await q(`insert into talent_skills (owner_id, domain, skill, level, proof_document_id) values ('${TS}', 'Informatique', 'Vérifiée normale', 'avance', '${dW}') returning id`))[0].id;
  check('C5b compétence vérifiée avec collecte active : activité confirmée, aucun écart pour elle', (await evs(TS, 'skill_demonstrated')).some((x) => x.source_id === sk4 && x.status === 'confirmed'));
  c = await issues(TS);
  check('C5c compétence normale : pas dans les écarts', !(c.issues.find((x) => x.code === 'skill_verified_without_event')?.refs ?? []).includes(sk4));
  await sup();
  await db.exec(`alter table user_documents disable trigger trg_talent_skill_docs; update user_documents set status = 'pending' where id = '${dW}'; alter table user_documents enable trigger trg_talent_skill_docs`);
  c = await issues(TS);
  check('C6 activité de compétence dont le justificatif n\'est plus vérifié : erreur', has(c, 'skill_event_unsupported', 'error') && c.summary.errors >= 1, JSON.stringify(c.issues.map((x) => x.code)));

  // badges, replays
  await sup();
  const LV = (await q(`insert into lives (host_id, title, status, started_at, ended_at) values ('${S[1]}', 'Live cohérence', 'ended', now() - interval '3 hours', now() - interval '2 hours') returning id`))[0].id;
  const RC = (await q(`insert into live_recordings (live_id, requested_by, status, storage_path, duration_sec, ready_at) values ('${LV}', '${S[1]}', 'pret', '${S[1]}/coh.mp4', 100, now()) returning id`))[0].id;
  const BG = (await q(`insert into user_badges (user_id, code, label, ref_kind, ref_id) values ('${TB}', 'jai_suivi', 'J''ai suivi', 'replay', '${U(777)}') returning id`))[0].id;
  c = await issues(TB);
  check('C7 badge sans complétion de replay : erreur', has(c, 'badge_without_completion', 'error') && c.issues.find((x) => x.code === 'badge_without_completion').refs.includes(BG), JSON.stringify(c.issues));
  await sup();
  await db.exec(`alter table replay_completions disable trigger trg_talent_replay_completions; alter table user_badges disable trigger trg_talent_user_badges`);
  const CP = (await q(`insert into replay_completions (user_id, recording_id, live_id, coverage, watched_sec) values ('${TB}', '${RC}', '${LV}', 1, 100) returning id`))[0].id;
  const BG2 = (await q(`insert into user_badges (user_id, code, label, ref_kind, ref_id) values ('${TB}', 'jai_suivi', 'J''ai suivi', 'replay', '${RC}') returning id`))[0].id;
  await db.exec(`alter table replay_completions enable trigger trg_talent_replay_completions; alter table user_badges enable trigger trg_talent_user_badges`);
  c = await issues(TB);
  check('C8 complétion et badge sans activité de score : avertissements', has(c, 'replay_without_event', 'warning') && has(c, 'badge_without_event', 'warning'), JSON.stringify(c.issues.map((x) => x.code)));
  await sup();
  await qs(`select _talent_event_record('${TB}', 'replay_completed_100', 'replay_completion', '${CP}', now(), null, '${S[1]}', '{}'::jsonb), _talent_event_record('${TB}', 'badge_verified', 'user_badge', '${BG2}', now(), null, '${S[1]}', '{}'::jsonb)`);
  c = await issues(TB);
  check('C8b après collecte (activités enregistrées) : plus d\'avertissement de replay ni de badge sans activité', !has(c, 'replay_without_event') && !has(c, 'badge_without_event'), JSON.stringify(c.issues.map((x) => x.code)));
  await sup();
  await db.exec(`alter table replay_completions disable trigger trg_talent_replay_completions; delete from replay_completions where id = '${CP}'; alter table replay_completions enable trigger trg_talent_replay_completions`);
  c = await issues(TB);
  check('C9 complétion retirée sans annulation : erreurs replay et badge non étayés', has(c, 'replay_event_unsupported', 'error') && has(c, 'badge_event_unsupported', 'error') && has(c, 'badge_without_completion', 'error'), JSON.stringify(c.issues.map((x) => x.code)));
  // live
  await sup();
  await qs(`select _talent_event_record('${TB}', 'live_hosted', 'live', '${U(888)}', now(), null, null, '{}'::jsonb)`);
  c = await issues(TB);
  check('C9b activité de live sans live terminé : erreur', has(c, 'live_event_unsupported', 'error'));

  // collaborations
  await sup();
  const PJ = (await q(`insert into projects (owner_id, title, summary, status) values ('${TC}', 'Projet cohérence', 'Collaboration', 'approved') returning id`))[0].id;
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ}', '${TM}', 'accepted')`);
  c = await issues(TC);
  check('C10 projet approuvé à deux étudiants réels avec activités : aucun écart de collaboration', !has(c, 'collaboration_without_members') && !has(c, 'collaboration_without_event'), JSON.stringify(c.issues.map((x) => x.code)));
  await sup();
  await db.exec(`alter table project_members disable trigger trg_talent_collab_members; delete from project_members where project_id = '${PJ}' and user_id = '${TM}'; alter table project_members enable trigger trg_talent_collab_members`);
  c = await issues(TC);
  check('C11 collaboration sans membres (membre retiré sans annulation) : erreur', has(c, 'collaboration_without_members', 'error'), JSON.stringify(c.issues.map((x) => x.code)));
  await sup();
  const PJ2 = (await q(`insert into projects (owner_id, title, summary, status) values ('${TCL}', 'Projet à inviter', 'Invitations', 'approved') returning id`))[0].id;
  await db.exec(`insert into project_members (project_id, user_id, status) values ('${PJ2}', '${TM}', 'invited'), ('${PJ2}', '${CMP}', 'accepted')`);
  c = await issues(TCL);
  check('C12 invitation en attente : information ; membre accepté non étudiant : avertissement', has(c, 'project_invitations_pending', 'info') && has(c, 'project_member_not_countable', 'warning'), JSON.stringify(c.issues.map((x) => x.code)));
  await sup();
  const PJ3 = (await q(`insert into projects (owner_id, title, summary, status) values ('${TM}', 'Projet sans activité', 'Collaboration ancienne', 'draft') returning id`))[0].id;
  await db.exec(`alter table projects disable trigger trg_talent_collab_projects; alter table project_members disable trigger trg_talent_collab_members;
    insert into project_members (project_id, user_id, status) values ('${PJ3}', '${TC}', 'accepted'); update projects set status = 'approved' where id = '${PJ3}';
    alter table projects enable trigger trg_talent_collab_projects; alter table project_members enable trigger trg_talent_collab_members`);
  c = await issues(TM);
  check('C13 collaboration réelle sans activité de score : avertissement', has(c, 'collaboration_without_event', 'warning') && c.issues.find((x) => x.code === 'collaboration_without_event').refs.includes(PJ3), JSON.stringify(c.issues.map((x) => x.code)));

  // score
  await sup();
  const evSc = await evs(S[3], 'event_attended');
  await qs(`select _talent_ledger_add(${evSc[0].id}, '${S[3]}', 'award', 5, 'event_attended', 1, 'test d''incohérence')`);
  c = await issues(S[3]);
  check('C14 points restés sur une activité annulée : erreur', has(c, 'points_on_inactive_event', 'error'), JSON.stringify(c.issues.map((x) => x.code)));
  await sup();
  await qs(`update talent_scores set total = total + 7 where user_id = '${S[3]}'`);
  c = await issues(S[3]);
  check('C15 total du score différent du registre : erreurs de total et de solde', has(c, 'score_ledger_mismatch', 'error') && has(c, 'score_balance_mismatch', 'error') && c.score.total === c.score.ledger_sum + 7, JSON.stringify(c.score));

  // profil
  await sup();
  await qs(`update talent_visibility_settings set shared_sections = array['skills','badges','projects'] where user_id = '${TP}'`);
  c = await issues(TP);
  check('C16 consentement sans rattachement vérifié et rubriques partagées vides : informations', has(c, 'consent_without_affiliation', 'info') && has(c, 'shared_section_empty', 'info') && c.issues.find((x) => x.code === 'shared_section_empty').count === 2, JSON.stringify(c.issues));

  // vue étudiant et isolation
  c = await issues(TS, 'me');
  check('C17 mon contrôle : mes écarts, sans identité ni donnée d\'autrui', c.applicable === true && c.issues.length >= 3 && !('student' in c) && JSON.stringify(c).indexOf(TB) < 0);
  c = await issues(TCL, 'me');
  check('C17b un autre étudiant ne voit pas les écarts d\'autrui', !has(c, 'skill_without_proof'));
  await sup();
  const after = await snapC();
  check('C18 lecture seule : aucun événement, point, score, alerte ni notification créé ou modifié par les contrôles (hors fixtures)', after.length > 0 && (await issues(TS)).applicable === true && (await snapC()) === after);

  // ============================================================ D. EXPLICATIONS PUBLIQUES (avant publication)
  await sup();
  const MIS = await mkUser(60, 'company', 'Entreprise Missions', 'mis@t.cm');
  const mkS = async (n, o) => mkStudent(n, o);
  const R = []; for (let i = 0; i < 10; i++) R[i] = await mkS(40 + i, { consent: true, program: true });
  const NVF = await mkS(53, { verified: false, consent: true, program: true });
  await mkS(55, { consent: false, program: true });
  const IDRE = /-00000016\d{4}"/;
  await as(null);
  let ex = await rpc(`ranking_explain()`);
  check('D1 anonyme, aucun classement publié : réponse honnête, aucune règle en vigueur, aucune identité', ex.published === false && ex.rules_in_force === false && ex.rules.length === 0 && ex.settings_decided === true && /Aucun classement/.test(ex.note) && ex.status === null
    && !IDRE.test(JSON.stringify(ex)), JSON.stringify(ex).slice(0, 300));
  check('D1b formule, caractéristiques de normalisation et critères d\'éligibilité présents', ex.formula.points.includes('(1 − w)') && ex.formula.not_counted.includes("j'aime") && ex.eligibility.length === 7 && ex.formula.freeze.includes('correction auditée'));
  const cnt = (e, m) => e.exclusions.find((x) => x.motif === m);
  check('D1c exclus par motif, sans identité : suspendus, non vérifiés, non consentants comptés', cnt(ex, 'suspendus').count >= 1 && cnt(ex, 'non_verifies').count >= 1 && cnt(ex, 'non_consentants').count >= 1 && ex.exclusions.length === 6);
  check('D1d petit effectif « contrôle d\'intégrité » masqué (moins de 5), jamais un nombre exact', cnt(ex, 'controle_integrite').count === null && cnt(ex, 'controle_integrite').masked === true);
  await as(S[1]);
  await fails('D2 portée inconnue refusée', `select ranking_explain(null, 'galaxie')`, /Portée inconnue/i);
  await fails('D2b période invalide refusée', `select ranking_explain('2026-13')`, /Période invalide/i);
  await fails('D2c référence de portée manquante refusée', `select ranking_explain(null, 'program')`, /référence/i);
  await fails('D2d référence de portée invalide refusée', `select ranking_explain(null, 'program', 'pas-un-uuid')`, /invalide/i);
  await sup();

  // ============================================================ E. PUBLICATION, CORRECTION, ARCHIVAGE, CONTESTATIONS
  await as(PUB);
  await works('E0 règles réelles activées pour le scénario (valeurs de test : mission 100, certificat 80)', `select admin_talent_rule_set('mission_validated', 100, 200, 400, 0, true, 'Activation de test pour la publication') a, admin_talent_rule_set('certificate_verified', 80, 80, 240, 0, true, 'Activation de test pour la publication') b`, (x) => x[0].a.active && x[0].b.active);
  await works('E0b réglages de publication de test (seuil 20, activités 1, 100 entrées, 3 portées)', `select admin_ranking_settings_set(20, 1, 100, array['national','institution','program'], 'Réglages de test : fixture E') r`, (x) => x[0].r.decided === true);
  await sup();
  for (let i = 0; i < 10; i++) {
    await qs(`select _talent_event_record('${R[i]}', 'mission_validated', 'mission', 'e-m-${i}', now(), null, '${MIS}', '{}'::jsonb)`);
    if (i < 5) await qs(`select _talent_event_record('${R[i]}', 'certificate_verified', 'certificate', 'e-c-${i}', now(), null, '${MIS}', '{}'::jsonb)`);
  }
  check('E0c scores de test : 180 pour les cinq premiers, 100 pour les cinq suivants', (await total(R[0])) === 180 && (await total(R[9])) === 100);
  ex = await (async () => { await as(null); return rpc(`ranking_explain()`); })();
  check('D3 règles en vigueur à la date (historique) : 2 règles actives avec leurs plafonds', ex.published === false && ex.rules_in_force === true && ex.rules.length === 2 && ex.rules_source === 'history_at_period_end'
    && ex.rules.find((r) => r.code === 'mission_validated').points === 100 && ex.rules.find((r) => r.code === 'mission_validated').cap_per_period === 400);
  check('D3b éligibles décomptés (10) hors exclus ; non vérifié compté sans identité', ex.eligible_now === 10 && cnt(ex, 'non_verifies').count >= 1);
  await as(MOD); await fails('E1 sans ranking.publish : publication refusée', `select ranking_publish('${P1}')`, DENY);
  await as(null); await fails('E1b anonyme : publication refusée', `select ranking_publish('${P1}')`, DENY);
  await as(PUB);
  await works('E2 préparation : prête, 10 éligibles', `select admin_ranking_readiness('${P1}') r`, (x) => x[0].r.ready === true && x[0].r.students.eligibles === 10);
  const P0 = (await qs(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;
  await as(PUB);
  const pub = await rpc(`ranking_publish('${P1}')`);
  check('E3 publication du mois courant : 30 entrées (national, établissement, filière), empreinte', pub.ok === true && pub.entries === 30 && pub.groups === 3 && /^[0-9a-f]{64}$/.test(pub.content_hash), JSON.stringify(pub));
  await fails('E3b publier une période déjà publiée : refusé', `select ranking_publish('${P1}')`, /déjà publié/i);
  await fails('E3c publier un mois ANTÉRIEUR après un mois plus récent : refusé (ordre)', `select ranking_publish('${P0}')`, /plus récent|dans l'ordre/i);
  await works('E3d préparation du mois antérieur : bloquée avec le motif d\'ordre', `select admin_ranking_readiness('${P0}') r`, (x) => x[0].r.ready === false && x[0].r.blockers.some((b) => /dans l'ordre/.test(b)));
  await fails('E3e période future refusée', `select ranking_publish('2999-01')`, /invalide|future/i);
  await as(null);
  await works('E4 lecture publique anonyme : 10 talents classés, rang 1 partagé par 5', `select top100_national() r`, (x) => x[0].r.published === true && x[0].r.total === 10 && x[0].r.items[0].rank === 1 && x[0].r.items.filter((i) => i.rank === 1).length === 5);
  await works('E4b vérification publique des empreintes : intact', `select ranking_verify_hash('${P1}') r`, (x) => x[0].r.found === true && x[0].r.intact === true && x[0].r.corrections === 0);
  ex = await rpc(`ranking_explain('${P1}')`);
  check('D4 période publiée : règles FIGÉES à la publication, réglages figés, 10 entrées dans la portée nationale', ex.published === true && ex.status === 'published' && ex.rules_source === 'frozen_at_publication' && ex.rules.length === 2
    && ex.settings.min_score === 20 && ex.entries_in_scope === 10 && ex.scope_published === true);
  ex = await rpc(`ranking_explain('${P1}', 'program', '${G1}')`);
  check('D5 portée filière : 10 entrées, décomptes limités aux étudiants de cette filière', ex.scope === 'program' && ex.entries_in_scope === 10 && ex.scope_ref === G1 && cnt(ex, 'non_verifies').count >= 1 && !IDRE.test(JSON.stringify(ex)));
  ex = await rpc(`ranking_explain('${P1}', 'department', '${D1}')`);
  check('D5b portée non publiée (département) : indiquée comme telle', ex.scope_published === false && ex.entries_in_scope === 0);
  // la règle courante change après la publication : la période publiée reste reproductible
  await as(PUB);
  await rpc(`admin_talent_rule_set('certificate_verified', 80, 80, 240, 0, false, 'Désactivation de test après publication')`);
  await as(null);
  ex = await rpc(`ranking_explain('${P1}')`);
  check('D6 règle désactivée après publication : la période publiée affiche toujours les règles figées (2)', ex.rules.length === 2 && ex.rules_source === 'frozen_at_publication');
  await as(PUB);
  await rpc(`admin_talent_rule_set('certificate_verified', 80, 80, 240, 0, true, 'Réactivation de test (retour à l''état publié)')`);
  await sup();
  // --- correction auditée
  const neutEv = (await evs(R[4], 'mission_validated'))[0].id;
  await as(MOD);
  await works('E5 neutralisation par la modération d\'une activité d\'un classé', `select admin_talent_event_neutralize(${neutEv}, 'Mission non conforme, vérification manuelle') r`, (x) => x[0].r.status === 'neutralized');
  await as(MOD);
  await works('E5b contrôle de cohérence : entrée publiée d\'un étudiant devenu inéligible signalée (rien corrigé)', `select admin_talent_consistency_check('${R[4]}') r`, (x) => x[0].r.issues.some((i) => i.code === 'ranked_but_ineligible' && i.severity === 'warning'));
  await as(MOD); await fails('E6 sans ranking.publish : correction refusée', `select ranking_correct('${P1}', 'Correction suite à une fraude confirmée')`, DENY);
  await as(PUB);
  await fails('E6b motif trop court refusé', `select ranking_correct('${P1}', 'court')`, /Motivez/i);
  await fails('E6c étudiant éligible hors classement : aucune entrée à corriger', `select ranking_correct('${P1}', 'Correction ciblée sans objet', '${S[2]}')`, /Aucune entrée à corriger/i);
  await fails('E6d période inconnue', `select ranking_correct('2020-01', 'Correction suite à une fraude confirmée')`, /introuvable/i);
  const oldHash = (await qs(`select content_hash h from ranking_periods where period = '${P1}'`))[0].h;
  await as(PUB);
  const cor = await rpc(`ranking_correct('${P1}', 'Retrait après fraude confirmée sur une mission')`);
  check('E7 correction auditée : 3 entrées retirées, ancienne et nouvelle empreinte différentes', cor.ok === true && cor.voided === 3 && cor.old_hash === oldHash && cor.new_hash !== oldHash, JSON.stringify(cor));
  await as(null);
  await works('E7b après correction : empreinte recalculée intacte, 1 correction ; classement à 9', `select ranking_verify_hash('${P1}') v, top100_national() n`, (x) => x[0].v.intact === true && x[0].v.corrections === 1 && x[0].n.total === 9);
  await as(MOD);
  await works('E7c après correction : plus d\'alerte « classé mais inéligible »', `select admin_talent_consistency_check('${R[4]}') r`, (x) => !x[0].r.issues.some((i) => i.code === 'ranked_but_ineligible'));
  await sup();
  check('E7d notification de correction envoyée une seule fois à l\'étudiant touché', (await notifs(R[4], 'ranking_correction')) === 1);
  check('E7e journal des corrections : 3 lignes avec ancienne et nouvelle valeur', (await qs(`select count(*)::int n from ranking_corrections where reason like 'Retrait après fraude%' and field = 'entry' and old_value is not null and new_value is not null`))[0].n === 3);
  // intégrité : toute altération est détectée ou refusée
  await fails('E8 modification directe d\'une entrée publiée : refusée', `update ranking_entries set score = score + 1`, /ne se modifie pas|correction auditée|permission denied|figés|Seuls/i);
  await fails('E8b suppression directe d\'une entrée : refusée', `delete from ranking_entries`, /ne se supprime pas|retirez-la|permission denied/i);
  await sup();
  const entId = (await q(`select id from ranking_entries where voided_at is null order by id limit 1`))[0].id;
  await db.exec(`alter table ranking_entries disable trigger trg_ranking_guard_entry; update ranking_entries set score = score + 1 where id = ${entId}; alter table ranking_entries enable trigger trg_ranking_guard_entry`);
  await as(null);
  check('E8c altération hors garde (simulée) : l\'empreinte publique la détecte', (await rpc(`ranking_verify_hash('${P1}')`)).intact === false);
  await sup();
  await db.exec(`alter table ranking_entries disable trigger trg_ranking_guard_entry; update ranking_entries set score = score - 1 where id = ${entId}; alter table ranking_entries enable trigger trg_ranking_guard_entry`);
  await as(null);
  check('E8d valeur restaurée : empreinte de nouveau intacte (le calcul est reproductible)', (await rpc(`ranking_verify_hash('${P1}')`)).intact === true);
  await as(S[1]); await fails('E8e accès direct aux classements refusé', `select * from ranking_entries`, /permission denied/i);
  // --- archivage
  await as(MOD); await fails('E9 sans ranking.publish : archivage refusé', `select ranking_archive('${P1}', 'Archivage de fin de mois')`, DENY);
  await as(PUB);
  await fails('E9b motif trop court refusé', `select ranking_archive('${P1}', 'court')`, /Motivez/i);
  await fails('E9c période inconnue', `select ranking_archive('2020-01', 'Archivage de fin de mois')`, /introuvable/i);
  await works('E9d archivage', `select ranking_archive('${P1}', 'Archivage de fin de mois de test') r`, (x) => x[0].r.status === 'archived');
  await fails('E9e double archivage refusé', `select ranking_archive('${P1}', 'Archivage de fin de mois de test')`, /déjà archivé/i);
  await fails('E9f correction après archivage refusée', `select ranking_correct('${P1}', 'Correction tardive après archivage', '${R[0]}')`, /archivé/i);
  await fails('E9g publication d\'une période déjà publiée (archivée) refusée', `select ranking_publish('${P1}')`, /déjà publié/i);
  await as(null);
  await works('E9h classement archivé : toujours lisible et intact', `select top100_national('${P1}') n, ranking_verify_hash('${P1}') v`, (x) => x[0].n.total === 9 && x[0].n.status === 'archived' && x[0].v.status === 'archived' && x[0].v.intact === true);
  await sup();
  await fails('E9i modification directe d\'une période archivée refusée', `update ranking_periods set status = 'published'`, /archivé|ne se modifie|permission denied|ne revient pas/i);
  // --- contestations
  await as(R[4]);
  await works('E10 l\'étudiant retiré voit son activité neutralisée et peut la contester', `select my_talent_events('neutralized') r`, (x) => x[0].r.length === 1 && x[0].r[0].id == neutEv && /contester/.test(x[0].r[0].reason));
  await fails('E10b message trop court refusé', `select talent_score_dispute_open(${neutEv}, 'court')`, /10 à 1000/i);
  await as(R[3]); await fails('E10c contester l\'activité d\'un autre étudiant : refusé', `select talent_score_dispute_open(${neutEv}, 'Je conteste cette activité qui n''est pas la mienne')`, /introuvable/i);
  await as(null); await fails('E10d anonyme refusé', `select talent_score_dispute_open(${neutEv}, 'Je conteste cette activité sans compte')`, DENY);
  await as(R[4]);
  const dp = await rpc(`talent_score_dispute_open(${neutEv}, 'La mission est réelle, voici la preuve de validation client.')`);
  check('E10e contestation ouverte', dp.ok === true && dp.status === 'open');
  await fails('E10f double contestation de la même activité refusée', `select talent_score_dispute_open(${neutEv}, 'Seconde contestation de la même activité')`, /déjà en cours/i);
  await as(R[4]); await fails('E10g un étudiant ne décide pas', `select admin_talent_dispute_decide('${dp.id}', 'accepted', 'Je m''auto-valide la contestation')`, DENY);
  await as(MOD);
  await fails('E11 motif trop court refusé', `select admin_talent_dispute_decide('${dp.id}', 'accepted', 'court')`, /Motivez/i);
  await fails('E11b décision inconnue refusée', `select admin_talent_dispute_decide('${dp.id}', 'peut-etre', 'Décision invalide de test pour la modération')`, /Décision inconnue/i);
  await fails('E11c contestation inconnue', `select admin_talent_dispute_decide('${U(9999)}', 'accepted', 'Contestation inexistante pour le test')`, /introuvable/i);
  const dec = await rpc(`admin_talent_dispute_decide('${dp.id}', 'accepted', 'Preuve de validation client vérifiée : activité rétablie.')`);
  check('E12 décision acceptée : activité rétablie, points rendus (100)', dec.status === 'accepted' && dec.event_restored === true && dec.points_added === 100, JSON.stringify(dec));
  await as(MOD); await fails('E12b double décision refusée', `select admin_talent_dispute_decide('${dp.id}', 'rejected', 'Seconde décision sur la même contestation')`, /déjà été traitée/i);
  await sup();
  check('E12c score rétabli, registre cohérent, étudiant notifié', (await total(R[4])) === (await ledgerSum(R[4])) && (await total(R[4])) === 180 && (await notifs(R[4], 'profile')) >= 1);
  check('E12d le classement archivé n\'est PAS modifié par la décision (publication figée)', (await qs(`select count(*)::int n from ranking_entries where user_id = '${R[4]}' and voided_at is null`))[0].n === 0);
  // délai de contestation
  const old = (await evs(R[0], 'mission_validated'))[0].id;
  await qs(`update talent_events set created_at = now() - interval '61 days', status_changed_at = now() - interval '61 days' where id = ${old}`);
  await as(R[0]);
  await fails('E13 activité plus ancienne que le délai (60 jours par défaut) : contestation refusée', `select talent_score_dispute_open(${old}, 'Contestation tardive d''une activité ancienne')`, /délai de contestation \(60 jours\)/i);
  await as(MOD); await fails('E13b un agent de modération ne règle pas les paramètres (ranking.rules requis)', `select admin_talent_setting_set('dispute_days', 90, 'Délai étendu pour le test')`, DENY);
  await as(PUB);
  await works('E13c le délai est configurable (90 jours)', `select admin_talent_setting_set('dispute_days', 90, 'Délai de contestation étendu pour le test') r`, (x) => x[0].r.value == 90);
  await as(R[0]);
  const dq = await rpc(`talent_score_dispute_open(${old}, 'Contestation dans le nouveau délai de 90 jours.')`);
  check('E13d dans le nouveau délai : contestation acceptée à l\'ouverture', dq.ok === true);
  await as(MOD);
  const dr = await rpc(`admin_talent_dispute_decide('${dq.id}', 'rejected', 'Activité conforme : aucun changement à apporter.')`);
  check('E13e décision refusée : activité inchangée, aucun point modifié', dr.status === 'rejected' && dr.event_restored === false && dr.points_added === 0);
  await as(PUB); await rpc(`admin_talent_setting_set('dispute_days', 60, 'Retour au délai par défaut après le test')`);

  // ============================================================ F. ANTI-FRAUDE DURCI
  await sup();
  await as(MOD); await fails('F1 un agent sans ranking.rules ne règle pas les seuils', `select admin_talent_setting_set('burst_count', 5, 'Seuil de rafale abaissé pour le test')`, DENY);
  await as(PUB);
  await fails('F1b clé inconnue refusée', `select admin_talent_setting_set('seuil_magique', 5, 'Clé inconnue pour le test')`, /inconnu/i);
  await fails('F1c valeur hors bornes refusée (fenêtre de pointage : 240 minutes au plus)', `select admin_talent_setting_set('attendance_grace_minutes', 500, 'Valeur excessive pour le test')`, /Valeur invalide/i);
  await fails('F1d valeur décimale refusée pour un seuil entier', `select admin_talent_setting_set('attendance_max_failures', 2.5, 'Valeur décimale pour le test')`, /entier/i);
  await fails('F1e valeur nulle refusée', `select admin_talent_setting_set('attendance_max_failures', 0, 'Valeur nulle pour le test')`, /Valeur invalide/i);
  await as(null); await fails('F1f anonyme refusé', `select admin_talent_setting_set('burst_count', 5, 'Seuil de rafale abaissé pour le test')`, DENY);
  await as(PUB);
  await works('F1g valeurs en vigueur (repli compris) exposées à l\'administration', `select admin_talent_rules_list() r`, (x) => x[0].r.effective.dispute_days == 60 && x[0].r.effective.attendance_max_failures == 5 && x[0].r.effective.event_min_notice_minutes == 30 && x[0].r.effective.min_cohort == 5);
  // blocage des codes erronés : seuil abaissé à 2
  await rpc(`admin_talent_setting_set('attendance_max_failures', 2, 'Seuil de codes erronés abaissé pour le test')`);
  const EVF1 = await mkEvent('Fraude codes', '-20 minutes', '2 hours', ORG1);
  await reg(EVF1, R[5]);
  await as(ORG1); const cf1 = await rpc(`event_attendance_code_generate('${EVF1}')`);
  await as(R[5]);
  let rr = await rpc(`event_attendance_check_in('${EVF1}', 'AAAAAAAA')`); rr = await rpc(`event_attendance_check_in('${EVF1}', 'BBBBBBBB')`);
  check('F2 seuil durci à 2 : deuxième code faux, plus aucune tentative', rr.ok === false && rr.remaining_attempts === 0);
  await fails('F2b troisième tentative bloquée même avec le bon code', `select event_attendance_check_in('${EVF1}', '${cf1.code}')`, /Trop de codes erronés/i);
  await as(PUB); await rpc(`admin_talent_setting_set('attendance_max_failures', 5, 'Retour au seuil par défaut après le test')`);
  // événement créé trop près de son début : présence neutralisée
  await sup();
  const EVS2 = await mkEvent('Événement de dernière minute', '-5 minutes', '2 hours', ORG1, 'published', '1 minute');
  await reg(EVS2, R[6]);
  await as(ORG1); const cs2 = await rpc(`event_attendance_code_generate('${EVS2}')`);
  await as(R[6]); await rpc(`event_attendance_check_in('${EVS2}', '${cs2.code}')`);
  await sup();
  e = await evs(R[6], 'event_attended');
  check('F3 événement créé moins de 30 minutes avant son début : présence neutralisée, alerte, 0 point', e.length === 1 && e[0].status === 'neutralized' && /Événement suspect/.test(e[0].status_reason)
    && (await qs(`select count(*)::int n from talent_fraud_flags where event_id = ${e[0].id} and status = 'open'`))[0].n === 1, JSON.stringify(e));
  // événement normal : compté (la règle présence est inactive : tracé sans point)
  await as(PUB); await rpc(`admin_talent_rule_set('event_attended', 10, 10, 40, 0, true, 'Activation de test de la présence aux événements')`);
  await sup();
  const EVN = await mkEvent('Événement annoncé', '-5 minutes', '2 hours', ORG1);
  await reg(EVN, R[7]);
  await as(ORG1); const cn = await rpc(`event_attendance_code_generate('${EVN}')`);
  await as(R[7]); await rpc(`event_attendance_check_in('${EVN}', '${cn.code}')`);
  await sup();
  check('F3b événement annoncé à l\'avance : présence comptée (10 points)', (await evs(R[7], 'event_attended'))[0].status === 'confirmed' && (await total(R[7])) === (await ledgerSum(R[7])) && (await total(R[7])) === 100 + 10);
  // répétition d'un même auteur : missions et certificats
  const RP = await mkS(50, { consent: true, program: true });
  for (let i = 0; i < 4; i++) await qs(`select _talent_event_record('${RP}', 'mission_validated', 'mission', 'rep-${i}', now(), null, '${MIS}', '{}'::jsonb)`);
  const repEv = await qs(`select source_id, status, status_reason from talent_events where user_id = '${RP}' and rule_code = 'mission_validated' order by id`);
  check('F4 même client : 3 missions comptées, la 4e en 30 jours est neutralisée (répétition suspecte)', repEv.filter((x) => x.status === 'confirmed').length === 3 && repEv[3].status === 'neutralized' && /Répétition suspecte/.test(repEv[3].status_reason), JSON.stringify(repEv));
  const RC2 = await mkS(51, { consent: true, program: true });
  for (let i = 0; i < 4; i++) await qs(`select _talent_event_record('${RC2}', 'certificate_verified', 'certificate', 'rep-c-${i}', now(), null, '${MIS}', '{}'::jsonb)`);
  check('F4b même émetteur : le 4e certificat en 30 jours est neutralisé', (await qs(`select status from talent_events where user_id = '${RC2}' and rule_code = 'certificate_verified' order by id`)).map((x) => x.status).join() === 'confirmed,confirmed,confirmed,neutralized');
  // rafale : seuil abaissé à 3
  await as(PUB); await rpc(`admin_talent_setting_set('burst_count', 3, 'Seuil de rafale abaissé pour le test')`);
  await sup();
  const RB = await mkS(52, { consent: true, program: true });
  for (let i = 0; i < 4; i++) await qs(`select _talent_event_record('${RB}', 'live_hosted', 'live', 'burst-${i}', now(), null, null, '{}'::jsonb)`);
  const bEv = await qs(`select status, status_reason from talent_events where user_id = '${RB}' order by id`);
  check('F5 seuil de rafale durci à 3 : la 4e activité en quelques minutes est neutralisée', bEv.map((x) => x.status).join() === 'confirmed,confirmed,confirmed,neutralized' && /Rafale/.test(bEv[3].status_reason), JSON.stringify(bEv));
  await as(PUB); await rpc(`admin_talent_setting_set('burst_count', 10, 'Retour au seuil de rafale par défaut après le test')`);
  // comptes liés (alias d'e-mail) sur une vente
  await sup();
  const LK = await mkUser(61, 'company', 'Acheteur lié', 'ab.c+x@t.cm');
  const LS = await mkS(54, { consent: true, program: true, email: 'abc@t.cm' });
  await qs(`select _talent_event_record('${LS}', 'sale_confirmed', 'order_line', 'lk-1', now(), null, '${LK}', '{}'::jsonb)`);
  check('F6 acheteur lié au vendeur (alias d\'e-mail) : vente neutralisée', (await evs(LS, 'sale_confirmed'))[0].status === 'neutralized' && /Comptes liés/.test((await evs(LS, 'sale_confirmed'))[0].status_reason));
  await qs(`select _talent_event_record('${LS}', 'sale_confirmed', 'order_line', 'lk-1', now(), null, '${LK}', '{}'::jsonb)`);
  check('F6b rejouer la même vente ne crée ni doublon ni point', (await evs(LS, 'sale_confirmed')).length === 1 && (await total(LS)) === 0);
  check('F7 cohérence globale : pour tout étudiant, score = somme du registre (hors fixtures d\'incohérence volontaire)', (await qs(`select count(*)::int n from talent_scores s where s.total <> coalesce((select sum(points) from talent_score_ledger l where l.user_id = s.user_id), 0) and s.user_id <> '${S[3]}'`))[0].n === 0);

  // ============================================================ G. REJEU DES MIGRATIONS H13
  await sup();
  const snapG = async () => JSON.stringify((await qs(`select (select count(*) from talent_events) e, (select count(*) from talent_score_ledger) l, (select sum(total) from talent_scores) st, (select count(*) from talent_fraud_flags) f, (select count(*) from notifications) n,
    (select count(*) from ranking_periods) p, (select count(*) from ranking_entries) re, (select count(*) from talent_score_rules where active) ra, (select string_agg(code || version, ',' order by code) from talent_score_rules) rv,
    (select count(*) from talent_score_settings) ss, (select count(*) from event_attendance) a, (select count(*) from event_attendance_codes) c, (select count(*) from audit_log) au`))[0]);
  const beforeG = await snapG();
  const filesG = fs.readdirSync(migDir).filter((f) => /^2026112801\d{4}_h13_.*\.sql$/.test(f)).sort();
  check('G1 5 migrations H13 présentes dans la plage 20261128010000-20261128019999', filesG.length === 5 && filesG.every((f) => /^2026112801\d{4}_/.test(f)), filesG.join());
  let replayG = true;
  for (const f of filesG) { try { await db.exec(fs.readFileSync(new URL(f, migDir), 'utf8')); } catch (er) { replayG = false; console.log('ECHEC rejeu', f, er.message); } }
  check('G2 rejeu des 5 migrations : exécution sans erreur', replayG);
  check('G3 rejeu : aucune donnée créée, supprimée ni modifiée (événements, registre, règles, réglages, classement, présences, audit)', (await snapG()) === beforeG, beforeG + ' / ' + (await snapG()));
  await as(null);
  await works('G4 rejeu : empreinte du classement archivé toujours intacte, explication publique toujours disponible', `select ranking_verify_hash('${P1}') v, ranking_explain('${P1}') x`, (x) => x[0].v.intact === true && x[0].x.published === true);
  await fails('G5 rejeu : droits inchangés (anonyme refusé sur le moteur et la présence)', `select event_attendance_check_in('${U(900)}', 'AAAAAAAA')`, DENY);
  await as(PUB);
  await works('G6 rejeu : la contrainte de clés accepte toujours les paramètres H13', `select admin_talent_setting_set('attendance_lock_minutes', 10, 'Vérification après rejeu des migrations') r`, (x) => x[0].r.ok === true);
  await sup();

  console.log(`\nh13_ranking : ${ok} OK / ${ko} ECHEC`);
}
