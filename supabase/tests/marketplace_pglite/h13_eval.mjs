// H13 · Évaluations : santé des fournisseurs, parcours complet candidat -> envoi -> résultat -> validation -> contestation, quota gratuit de bout en bout, avancement d'une campagne,
// planification. Migrations 20261128040000 / 040100 / 040200 (+ 20261127400000 déjà en production). Fixtures créées dans la base de test seulement : aucun fournisseur, aucun secret réel.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h13_eval.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const migDir = path.resolve(here, '..', '..', 'migrations');
  const id = (n) => `00000000-0000-0000-0000-0000000096${String(n).padStart(2, '0')}`;
  const ADM = id(1), TECH = id(2), REV = id(3), ST1 = id(4), ST2 = id(5), ST3 = id(6), CLI = id(7), ORG = id(8), ORG2 = id(9), ST4 = id(10);
  const mail = (uid) => `u${uid.slice(-2)}@t.cm`;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims(uid ? { sub: uid } : {})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const svc = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', 'service_role', false), ${claims({ role: 'service_role' })}; set role service_role`); };
  const sup = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { await sup(); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const jq = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const DENY = /Réservé|permission denied|Accès refusé|Connexion requise|introuvable|exige la permission/i;
  const LIM = 'Évaluation à distance : le geste technique n\'a pas été observé.';
  const GOOD = { competences: [{ name: 'Usinage', level: 'intermediaire', verifiable_remotely: true }], criteria: [{ name: 'Précision', score: 7, max_score: 10 }], evidence: [{ kind: 'Rapport du fournisseur' }], details: {}, limits: LIM, recommendations: [] };
  const report = async (rows) => { await svc(); return rpc(`assessment_provider_health_report(${jq(rows)})`); };
  const ready = async (uid) => { await as(uid); return (await rpc(`assessment_provider_readiness()`)); };
  const resultCall = (rid, prov, ref, o) => `assessment_dispatch_result('${rid}', '${prov}', ${ref ? `'${ref}'` : 'null'}, ${jq(o.competences)}, ${jq(o.criteria)}, ${jq(o.evidence)}, ${jq(o.details)}, '${o.limits.replace(/'/g, "''")}', ${jq(o.recommendations)})`;
  const reqRow = async (rid) => (await qs(`select status, provider_code, external_ref, candidate_url, dispatch_attempts, funding from assessment_requests where id = '${rid}'`))[0];
  const quota = async (uid) => { await as(uid); return rpc(`assessment_quota()`); };
  const ask = async (uid, funding = 'gratuite_mensuelle', fam = 'mecanique', mode = 'evaluation_projets', extra = '') => { await as(uid); return rpc(`assessment_request('${fam}', '${mode}', true, '${funding}'${extra})`); };
  const age = async (rid) => { await db.exec(`reset role; update assessment_requests set last_dispatch_at = now() - interval '11 minutes' where id = '${rid}'`); };

  // ============================================================ comptes
  await sup();
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [TECH, 'Tech Agent', 'support'], [REV, 'Rev Evaluateur', 'support'], [ST1, 'Etu Un', 'student'], [ST2, 'Etu Deux', 'student'], [ST3, 'Etu Trois', 'student'],
    [CLI, 'Cli Client', 'client'], [ORG, 'Org Une', 'company'], [ORG2, 'Org Deux', 'company'], [ST4, 'Etu Quatre', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }
  await as(ADM);
  await q(`select admin_team_member_set('${TECH}', 'tech', array['tech.integrations'])`);
  await q(`select admin_team_member_set('${REV}', 'tech', array['tech.assessments'])`);
  await sup();

  // ============================================================ A. Livraison : rien d'inventé, migrations rejouables
  check('A1 livraison : aucun fournisseur, aucun rapport de santé, aucune demande, aucun réglage « assessment.* »',
    (await qs(`select (select count(*) from assessment_providers) p, (select count(*) from assessment_provider_health) h, (select count(*) from assessment_requests) r, (select count(*) from platform_settings where key like 'assessment.%') s`))
      .every((x) => Object.values(x).every((v) => Number(v) === 0)));
  const files = ['20261128040000_h13_eval_sante_fournisseur.sql', '20261128040100_h13_eval_campagne_avancement.sql', '20261128040200_h13_eval_planification.sql'];
  for (const f of files) {
    try { await db.exec(fs.readFileSync(path.join(migDir, f), 'utf8')); check(`A2 rejeu sans erreur : ${f.slice(0, 14)}`, true); } catch (e) { check(`A2 rejeu sans erreur : ${f.slice(0, 14)}`, false, e.message); }
  }
  await sup();
  check('A3 le rejeu n\'a rien inséré (aucune ligne de santé, aucun fournisseur)', (await qs(`select (select count(*) from assessment_provider_health) h, (select count(*) from assessment_providers) p`)).every((x) => Number(x.h) === 0 && Number(x.p) === 0));
  check('A4 table de santé : RLS active, aucun droit pour les rôles applicatifs',
    (await qs(`select relrowsecurity r from pg_class where relname = 'assessment_provider_health'`))[0].r === true
    && (await qs(`select count(*)::int n from information_schema.role_table_grants where table_name = 'assessment_provider_health' and grantee in ('anon', 'authenticated', 'public')`))[0].n === 0);

  await db.exec(`insert into assessment_providers (code, name, status, family_codes, modes) values
    ('prov_a', 'Fournisseur A (banc)', 'actif', array['mecanique'], array['evaluation_projets']),
    ('prov_b', 'Fournisseur B (banc)', 'candidat', array['mecanique'], array['evaluation_projets'])`);

  // ============================================================ B. Rapport de santé : écriture réservée au service, booléens seulement
  for (const [who, fn] of [['anonyme', () => as(null)], ['étudiant', () => as(ST1)], ['administrateur', () => as(ADM)], ['agent technique', () => as(TECH)]]) {
    await fn();
    await fails(`B1 ${who} : assessment_provider_health_report refusé`, `select assessment_provider_health_report('[]'::jsonb)`, DENY);
  }
  await as(ST1);
  await fails('B2 le candidat ne lit pas la table de santé', `select count(*) from assessment_provider_health`, /permission denied|row-level/i);
  await as(ADM);
  await fails('B2b même l\'administrateur ne lit pas la table directement (RPC seulement)', `select count(*) from assessment_provider_health`, /permission denied|row-level/i);
  await svc();
  await fails('B3 rapport non tableau refusé', `select assessment_provider_health_report('{"a":1}'::jsonb)`, /Rapport invalide/);
  let r = await report([{ provider: 'inconnu', base_url: true, api_key: true, webhook_secret: true }, { provider: 'prov_a', base_url: true, api_key: true, webhook_secret: false }, { base_url: true }]);
  check('B4 fournisseur inconnu ou sans code ignoré : un seul rapport écrit', r.ok === true && r.updated === 1, JSON.stringify(r));
  let h = (await qs(`select has_base_url b, has_api_key k, has_webhook_secret w, configured c from assessment_provider_health where provider_code = 'prov_a'`))[0];
  check('B5 deux secrets sur trois : configured = false', h.b && h.k && !h.w && h.c === false, JSON.stringify(h));
  r = await report([{ provider: 'prov_a', base_url: 'true', api_key: 1, webhook_secret: true }]);
  h = (await qs(`select has_base_url b, has_api_key k, has_webhook_secret w, configured c from assessment_provider_health where provider_code = 'prov_a'`))[0];
  check('B6 valeurs non booléennes (chaîne, nombre) comptées comme absentes : jamais interprétées', !h.b && !h.k && h.w && h.c === false, JSON.stringify(h));
  check('B7 la table ne contient que des booléens et une date (aucune colonne pouvant porter un secret)',
    (await qs(`select string_agg(column_name || ':' || data_type, ',' order by column_name) c from information_schema.columns where table_name = 'assessment_provider_health'`))[0].c
      === 'checked_at:timestamp with time zone,configured:boolean,has_api_key:boolean,has_base_url:boolean,has_webhook_secret:boolean,provider_code:text');

  // ============================================================ C. Indicateur de disponibilité (étudiant = oui/non ; équipe technique = détail sans secret)
  await as(null);
  await fails('C1 anonyme : assessment_provider_readiness refusé', `select assessment_provider_readiness()`, DENY);
  let rd = await ready(ST1);
  check('C2 étudiant : seulement « ready », faux (actif mais configuration incomplète)', Object.keys(rd).join() === 'ready' && rd.ready === false, JSON.stringify(rd));
  await report([{ provider: 'prov_a', base_url: true, api_key: true, webhook_secret: true }]);
  rd = await ready(ST1);
  check('C3 configuration complète confirmée par la fonction Edge : ready = true, toujours aucun détail pour l\'étudiant', rd.ready === true && Object.keys(rd).join() === 'ready', JSON.stringify(rd));
  rd = await ready(CLI);
  check('C3b client : même réponse minimale', rd.ready === true && Object.keys(rd).join() === 'ready');
  await db.exec(`reset role; update assessment_provider_health set checked_at = now() - interval '4 hours' where provider_code = 'prov_a'`);
  rd = await ready(ST1);
  check('C4 rapport périmé (4 h) : ready = false, aucune disponibilité affirmée sans preuve récente', rd.ready === false);
  await report([{ provider: 'prov_a', base_url: true, api_key: true, webhook_secret: true }]);
  await db.exec(`reset role; update assessment_providers set status = 'suspendu' where code = 'prov_a'`);
  rd = await ready(ST1);
  check('C5 fournisseur suspendu : ready = false même configuré', rd.ready === false);
  await db.exec(`reset role; update assessment_providers set status = 'actif' where code = 'prov_a'`);
  rd = await ready(ST1);
  check('C5b réactivé : ready = true', rd.ready === true);
  rd = await ready(TECH);
  const pa = (rd.providers ?? []).find((p) => p.code === 'prov_a'), pb = (rd.providers ?? []).find((p) => p.code === 'prov_b');
  check('C6 agent « tech.integrations » : détail par fournisseur (booléens, date, test) et file', rd.ready === true && !!pa && pa.configured === true && pa.has_webhook_secret === true && pa.reported === true && pa.stale === false && !!pa.checked_at
    && !!pb && pb.reported === false && pb.configured === null && rd.queue && rd.queue.waiting === 0 && rd.queue.running === 0 && rd.queue.failed_24h === 0, JSON.stringify(rd));
  check('C7 le détail ne contient que des booléens, des chaînes de nom/statut/date : aucun secret', (rd.providers ?? []).every((p) => Object.values(p).every((v) => v === null || ['boolean', 'string'].includes(typeof v))));
  rd = await ready(ADM);
  check('C8 administrateur global : détail visible', Array.isArray(rd.providers) && rd.providers.length === 2);
  rd = await ready(REV);
  check('C9 évaluateur (tech.assessments seulement) : pas le détail des fournisseurs', Object.keys(rd).join() === 'ready');

  // ============================================================ D. Parcours complet : demande -> fournisseur attribué par le serveur -> envoi -> résultat -> validation -> contestation
  let a = await ask(ST1);
  check('D1 demande enregistrée « envoyee », fournisseur attribué par le SERVEUR (le candidat ne le choisit pas)', a.ok === true && a.status === 'envoyee', JSON.stringify(a));
  const R1 = a.id;
  check('D2 le serveur a attribué prov_a', (await reqRow(R1)).provider_code === 'prov_a');
  await as(ST1);
  let list = await rpc(`assessment_my_list()`);
  check('D3 liste du candidat : état « envoyee », nom du fournisseur, 0 tentative, aucun lien', list.length === 1 && list[0].status === 'envoyee' && list[0].provider_name === 'Fournisseur A (banc)' && list[0].dispatch_attempts === 0 && list[0].candidate_url === null, JSON.stringify(list));
  check('D3b la liste ne contient aucune clé de secret ni de configuration', !JSON.stringify(list).match(/secret|api_key|base_url|webhook/i));
  let qt = await quota(ST1);
  check('D4 envoyee : quota gratuit PAS consommé, demande en attente signalée', qt.used === 0 && qt.remaining === 1 && qt.pending === true, JSON.stringify(qt));
  await svc();
  const c = await rpc(`assessment_dispatch_claim(10, array['prov_a'])`);
  check('D5 réclamation par le service : la demande est réclamée, tentative 1', c.length === 1 && c[0].request_id === R1 && c[0].attempt === 1);
  await as(ST1);
  list = await rpc(`assessment_my_list()`);
  check('D6 après réclamation : toujours « envoyee », 1 tentative visible', list[0].status === 'envoyee' && list[0].dispatch_attempts === 1);
  await svc();
  await rpc(`assessment_dispatch_accepted('${R1}', 'EXT-1', 'https://passer.exemple.test/e/1')`);
  await as(ST1);
  list = await rpc(`assessment_my_list()`);
  check('D7 acceptée : bouton possible (lien https du fournisseur) ; le lien n\'est visible que du candidat', list[0].status === 'acceptee' && list[0].candidate_url === 'https://passer.exemple.test/e/1');
  await as(ST2);
  check('D8 un autre étudiant ne voit ni la demande ni le lien', (await rpc(`assessment_my_list()`)).length === 0);
  qt = await quota(ST1);
  check('D9 acceptée : quota gratuit consommé (1/1)', qt.used === 1 && qt.remaining === 0 && qt.pending === false);
  await svc();
  const res1 = await rpc(resultCall(R1, 'prov_a', 'EXT-1', GOOD));
  check('D10 résultat enregistré par le service (rappel signé vérifié par la fonction Edge)', res1.ok === true && !!res1.result, JSON.stringify(res1));
  await as(ST1);
  list = await rpc(`assessment_my_list()`);
  check('D11 terminée : résultat lié, plus de lien, statut de validation automatique', list[0].status === 'terminee' && list[0].result_id === res1.result && list[0].candidate_url === null && list[0].validation_status === 'automatique');
  const detail = await rpc(`assessment_result('${res1.result}')`);
  check('D12 le candidat lit son résultat : compétences, critères, preuves et limites', detail.competences.length === 1 && detail.criteria.length === 1 && detail.evidence.length === 1 && detail.limits === LIM && detail.dispute_possible === true);
  await as(ST2);
  await fails('D13 un autre étudiant ne lit pas ce résultat', `select assessment_result('${res1.result}')`, /introuvable/i);
  await fails('D13b ni ne le conteste', `select assessment_dispute('${res1.result}', 'Je conteste un résultat qui n''est pas le mien')`, /introuvable/i);
  await as(ST1);
  await fails('D14 contestation trop courte refusée', `select assessment_dispute('${res1.result}', 'non')`, /10 à 2000/);
  const d1 = await rpc(`assessment_dispute('${res1.result}', 'Le résultat ne reflète pas mon projet réel présenté.')`);
  check('D15 contestation ouverte', d1.ok === true);
  await fails('D16 une seconde contestation en cours est refusée', `select assessment_dispute('${res1.result}', 'Encore une contestation sur le même résultat.')`, /déjà en cours/);
  list = await rpc(`assessment_my_list()`);
  check('D17 la liste expose l\'état de la contestation', list[0].dispute_status === 'ouverte');
  await as(ST2);
  await fails('D18 un étudiant ne lit pas la file de validation', `select assessment_review_queue()`, DENY);
  await as(TECH);
  await fails('D19 un agent sans « tech.assessments » ne lit pas la file de validation', `select assessment_review_queue()`, DENY);
  await as(REV);
  const queue = await rpc(`assessment_review_queue()`);
  check('D20 l\'évaluateur voit la contestation (nom du candidat, motif)', queue.disputes.length === 1 && queue.disputes[0].reason.includes('projet réel'));
  const took = await rpc(`assessment_dispute_handle('${d1.id}', 'take')`);
  check('D21 contestation prise en examen', took.status === 'en_examen');
  const closed = await rpc(`assessment_dispute_handle('${d1.id}', 'close', 'Résultat réexaminé par un évaluateur : les critères sont conformes au projet fourni.')`);
  check('D22 contestation close avec résolution motivée', closed.status === 'close');
  await as(ST1);
  const detail2 = await rpc(`assessment_result('${res1.result}')`);
  check('D23 le candidat lit la résolution', detail2.disputes[0].status === 'close' && detail2.disputes[0].resolution.includes('réexaminé'));
  // geste non observable à distance -> validation humaine
  await as(ST3);
  a = await ask(ST3);
  const R2 = a.id;
  await svc();
  await rpc(`assessment_dispatch_claim(10, array['prov_a'])`);
  await rpc(`assessment_dispatch_accepted('${R2}', 'EXT-2', null)`);
  const res2 = await rpc(resultCall(R2, 'prov_a', 'EXT-2', { ...GOOD, competences: [{ name: 'Soudure', level: 'avance', verifiable_remotely: false }] }));
  await as(REV);
  const q2 = await rpc(`assessment_review_queue()`);
  check('D24 compétence non vérifiable à distance : en file de validation humaine', q2.results.length === 1 && q2.results[0].result_id === res2.result);
  await as(ST3);
  list = await rpc(`assessment_my_list()`);
  check('D25 le candidat voit « validation humaine requise » et aucun lien', list[0].status === 'terminee' && list[0].validation_status === 'validation_humaine_requise' && list[0].candidate_url === null);
  await as(REV);
  const v = await rpc(`assessment_human_validate('${res2.result}', 'non_verifiable_a_distance', 'Le geste de soudure ne peut pas être observé à distance.')`);
  check('D26 décision humaine enregistrée', v.ok === true && v.validation_status === 'non_verifiable_a_distance');
  await sup();
  const log = (await qs(`select event from assessment_dispatch_log order by id`)).map((x) => x.event);
  check('D27 journal d\'envoi : claimed, accepted, result pour chaque demande', log.join() === 'claimed,accepted,result,claimed,accepted,result', log.join());
  await as(ST1);
  await fails('D28 le candidat ne lit pas le journal d\'envoi', `select assessment_dispatch_log_admin(10)`, DENY);
  await as(ADM);
  const jl = await rpc(`assessment_dispatch_log_admin(10)`);
  check('D29 l\'administrateur lit le journal d\'envoi (6 événements)', jl.length === 6);
  await as(TECH);
  rd = await rpc(`assessment_provider_readiness()`);
  check('D30 file de l\'équipe technique après le parcours : 0 en attente, 0 en cours, aucun échec', rd.queue.waiting === 0 && rd.queue.running === 0 && rd.queue.failed_24h === 0 && !!rd.queue.last_event_at, JSON.stringify(rd.queue));

  // ============================================================ E. Quota gratuit mensuel de bout en bout
  await as(ST1);
  a = await ask(ST1);
  check('E1 deuxième demande gratuite du même mois : refusée (quota_exhausted), rien enregistré', a.ok === false && a.code === 'quota_exhausted' && !!a.next_reset, JSON.stringify(a));
  check('E1b aucune demande supplémentaire enregistrée', (await qs(`select count(*)::int n from assessment_requests where candidate_id = '${ST1}'`))[0].n === 1);
  a = await ask(ST1, 'payee_candidat', 'mecanique', 'evaluation_projets', ', 5000');
  check('E2 évaluation supplémentaire : indisponible tant que le prix n\'est pas décidé (aucun tarif inventé)', a.ok === false && a.code === 'extra_unavailable', JSON.stringify(a));
  qt = await quota(ST1);
  check('E3 quota : extra.available = false, prix nul, paiement non prêt', qt.extra.available === false && qt.extra.price_xaf === null && qt.extra.payment_ready === false && /pas encore été décidé/.test(qt.extra.message), JSON.stringify(qt.extra));
  await as(CLI);
  a = await rpc(`assessment_request('mecanique', 'evaluation_projets', true, 'payee_candidat', 5000)`);
  check('E4 client : supplémentaire indisponible aussi', a.ok === false && a.code === 'extra_unavailable');
  await fails('E5 client : gratuite réservée aux étudiants', `select assessment_request('mecanique', 'evaluation_projets', true, 'gratuite_mensuelle')`, /Accès refusé/);
  await as(ORG);
  await fails('E6 organisation : aucune évaluation candidat', `select assessment_request('mecanique', 'evaluation_projets', true, 'gratuite_mensuelle')`, /Accès refusé/);
  await as(null);
  await fails('E7 anonyme : refusé', `select assessment_request('mecanique', 'evaluation_projets', true, 'gratuite_mensuelle')`, DENY);
  await as(ST4);
  a = await rpc(`assessment_request('mecanique', 'evaluation_projets', false, 'gratuite_mensuelle')`);
  check('E8 sans consentement : refusé (consent_required)', a.ok === false && a.code === 'consent_required');
  a = await rpc(`assessment_request('mecanique', 'ecrit', true, 'gratuite_mensuelle')`);
  check('E9 mode sans fournisseur actif : no_provider, quota intact', a.ok === false && a.code === 'no_provider' && (await quota(ST4)).remaining === 1);
  // une demande en attente bloque une seconde demande gratuite
  a = await ask(ST4);
  const R4 = a.id;
  check('E10 ST4 : demande enregistrée', a.ok === true);
  a = await ask(ST4);
  check('E11 seconde demande pendant l\'attente : already_pending', a.ok === false && a.code === 'already_pending');
  // échec d'envoi x5 : le quota n'est JAMAIS décompté
  for (let k = 1; k <= 5; k++) {
    if (k > 1) await age(R4);
    await svc();
    const cl = await rpc(`assessment_dispatch_claim(10, array['prov_a'])`);
    check(`E12.${k} réclamation ${k} (espacement de 10 min respecté)`, cl.length === 1 && cl[0].attempt === k, JSON.stringify(cl));
    const f = await rpc(`assessment_dispatch_failed('${R4}', 503, 'HTTP 503')`);
    check(`E13.${k} échec d'envoi ${k} journalisé`, f.ok === true && f.final === (k === 5));
    qt = await quota(ST4);
    check(`E14.${k} quota non consommé après l'échec ${k}`, qt.used === 0 && qt.remaining === 1);
  }
  let row = await reqRow(R4);
  check('E15 après 5 échecs : demande « echouee », message serveur explicite', row.status === 'echouee' && row.dispatch_attempts === 5);
  await as(ST4);
  list = await rpc(`assessment_my_list()`);
  check('E16 le candidat voit l\'erreur et le message du serveur « non consommée »', list[0].status === 'echouee' && /n'est pas consommée/.test((await qs(`select status_note n from assessment_requests where id = '${R4}'`))[0].n));
  a = await ask(ST4);
  check('E17 une nouvelle demande est possible après l\'échec (quota intact)', a.ok === true);
  const R5 = a.id;
  await svc();
  await rpc(`assessment_dispatch_claim(10, array['prov_a'])`);
  await rpc(`assessment_dispatch_accepted('${R5}', 'EXT-5', null)`);
  qt = await quota(ST4);
  check('E18 acceptée : 1 consommée', qt.used === 1 && qt.remaining === 0);
  await svc();
  const pf = await rpc(`assessment_dispatch_provider_failed('${R5}', 'prov_a', 'abandon du fournisseur')`);
  check('E19 échec signalé par le fournisseur après acceptation', pf.ok === true && (await reqRow(R5)).status === 'echouee');
  qt = await quota(ST4);
  check('E20 le quota est rendu (echouee n\'est pas décomptée)', qt.used === 0 && qt.remaining === 1);
  // mois précédent : n'est pas décompté
  await db.exec(`reset role; insert into assessment_requests (candidate_id, family_code, mode, provider_code, status, funding, consent, accepted_at, created_at)
    values ('${ST2}', 'mecanique', 'evaluation_projets', 'prov_a', 'terminee', 'gratuite_mensuelle', true, now() - interval '40 days', now() - interval '40 days')`);
  qt = await quota(ST2);
  check('E21 une évaluation du mois précédent ne compte pas dans le mois courant', qt.used === 0 && qt.remaining === 1);
  a = await ask(ST2);
  check('E22 ST2 peut donc demander cette fois', a.ok === true);
  await as(ADM);
  qt = await rpc(`assessment_quota()`);
  check('E23 administrateur : pas d\'évaluation gratuite (non éligible)', qt.eligible === false);

  // ============================================================ F. Campagne d'organisation : avancement et état du fournisseur
  await as(ORG);
  const camp = await rpc(`assessment_campaign_create('Recrutement mécaniciens', 'mecanique', 'evaluation_projets')`);
  check('F1 campagne créée « en attente de financement » (aucun paiement)', camp.ok === true && camp.status === 'en_attente_financement');
  let pr = await rpc(`assessment_campaign_progress('${camp.id}')`);
  check('F2 avancement : tout à zéro, fournisseur prêt (actif + configuré + famille/mode couverts)', pr.invited === 0 && pr.waiting === 0 && pr.running === 0 && pr.done === 0 && pr.error === 0 && pr.reused === 0 && pr.provider_ready === true && pr.status === 'en_attente_financement', JSON.stringify(pr));
  await as(ORG2);
  await fails('F3 une autre organisation ne lit pas l\'avancement', `select assessment_campaign_progress('${camp.id}')`, DENY);
  await as(ST1);
  await fails('F4 un étudiant ne lit pas l\'avancement', `select assessment_campaign_progress('${camp.id}')`, DENY);
  await as(null);
  await fails('F5 anonyme refusé', `select assessment_campaign_progress('${camp.id}')`, DENY);
  await as(ORG);
  await q(`select assessment_campaign_invite('${camp.id}', '${mail(ST1)}')`);
  await q(`select assessment_campaign_invite('${camp.id}', '${mail(ST3)}')`);
  await q(`select assessment_campaign_invite('${camp.id}', '${mail(ST4)}')`);
  await db.exec(`reset role; update assessment_campaigns set status = 'ouverte' where id = '${camp.id}'`); // le financement n'a aucune RPC : ouverture simulée en base de test seulement
  const cr = async (uid) => { await as(uid); return rpc(`assessment_request('mecanique', 'evaluation_projets', true, 'financee_organisation', null, '${camp.id}')`); };
  const c1 = await cr(ST1), c3 = await cr(ST3), c4 = await cr(ST4);
  check('F6 trois invités demandent : financement organisation, envoyées', c1.ok && c3.ok && c4.ok, JSON.stringify([c1, c3, c4]));
  await as(ORG);
  pr = await rpc(`assessment_campaign_progress('${camp.id}')`);
  check('F7 avancement : 3 invités, 3 en attente (partage implicite de la demande de campagne)', pr.invited === 3 && pr.waiting === 3 && pr.running === 0, JSON.stringify(pr));
  await svc();
  await rpc(`assessment_dispatch_claim(10, array['prov_a'])`);
  await rpc(`assessment_dispatch_accepted('${c1.id}', 'EXT-C1', null)`);
  await rpc(`assessment_dispatch_accepted('${c3.id}', 'EXT-C3', null)`);
  await rpc(`assessment_dispatch_result('${c3.id}', 'prov_a', 'EXT-C3', ${jq(GOOD.competences)}, ${jq(GOOD.criteria)}, ${jq(GOOD.evidence)}, '{}'::jsonb, '${LIM.replace(/'/g, "''")}', '[]'::jsonb)`);
  await rpc(`assessment_dispatch_failed('${c4.id}', 500, 'x')`);
  for (let k = 2; k <= 5; k++) {
    await age(c4.id); await svc();
    await rpc(`assessment_dispatch_claim(10, array['prov_a'])`);
    await rpc(`assessment_dispatch_failed('${c4.id}', 500, 'x')`);
  }
  await as(ORG);
  pr = await rpc(`assessment_campaign_progress('${camp.id}')`);
  check('F8 avancement : 1 en cours, 1 terminée, 1 en erreur', pr.running === 1 && pr.done === 1 && pr.error === 1 && pr.waiting === 0, JSON.stringify(pr));
  check('F9 le résultat n\'est lisible par l\'organisation que s\'il est partagé : 1 résultat partagé', (await rpc(`assessment_campaign_results('${camp.id}')`)).results.length === 1);
  await as(ST3);
  await q(`select assessment_share_set('${c3.id}', false)`);
  await as(ORG);
  pr = await rpc(`assessment_campaign_progress('${camp.id}')`);
  check('F10 le candidat retire son partage : sa demande disparaît de l\'avancement et son résultat du partage', pr.done === 0 && pr.running === 1 && (await rpc(`assessment_campaign_results('${camp.id}')`)).results.length === 0, JSON.stringify(pr));
  await db.exec(`reset role; update assessment_provider_health set has_api_key = false where provider_code = 'prov_a'`);
  await as(ORG);
  pr = await rpc(`assessment_campaign_progress('${camp.id}')`);
  check('F11 clé d\'API absente (rapport de santé) : provider_ready = false pour la campagne', pr.provider_ready === false);
  await report([{ provider: 'prov_a', base_url: true, api_key: true, webhook_secret: true }]);
  await db.exec(`reset role; update assessment_providers set modes = array['ecrit'] where code = 'prov_a'`);
  await as(ORG);
  pr = await rpc(`assessment_campaign_progress('${camp.id}')`);
  check('F12 fournisseur ne couvrant plus le mode de la campagne : provider_ready = false', pr.provider_ready === false);

  // ============================================================ G. Planification
  const sql = fs.readFileSync(path.join(migDir, files[2]), 'utf8');
  check('G1 la planification n\'embarque aucune clé : seule la lecture de internal_secrets existe ; l\'envoi n\'est planifié que s\'il y a un fournisseur actif', !/eyJ|sk_|Bearer\s/.test(sql) && /x-dispatch-key/.test(sql) && /where exists \(select 1 from public\.assessment_providers where status = 'actif'\)/.test(sql));

  // ============================================================ H. Non-régression des droits déjà en production
  await as(ST1);
  for (const fn of [`assessment_dispatch_claim(1, null)`, `assessment_dispatch_failed('${R1}', 1, 'x')`]) await fails(`H1 étudiant : ${fn.split('(')[0]} toujours réservé au service`, `select ${fn}`, DENY);
  await as(ADM);
  await fails('H2 l\'administrateur ne peut pas écrire un rapport de santé (service seulement)', `select assessment_provider_health_report('[]'::jsonb)`, DENY);
  check('H3 la liste d\'administration des fournisseurs répond toujours', (await rpc(`assessment_providers_admin_list()`)).length === 2);

  console.log(`\nh13_eval : ${ok} OK, ${ko} ECHEC`);
}
