// H12 · Évaluations : envoi aux fournisseurs et réception des résultats (migration 20261127400000, fonction Edge assessment-dispatch).
// Prouve : RPC réservées au service ; seuls les fournisseurs ACTIFS et choisis sont réclamés ; espacement des tentatives ; acceptation ; échec sans consommer le quota gratuit ;
// résultat idempotent soumis aux garde-fous (biais, limites, validation humaine) ; fournisseur non actif ou différent refusé ; journal réservé aux administrateurs ; aucune donnée inventée.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h12_eval_dispatch.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000094${String(n).padStart(2, '0')}`;
  const ADM = id(1), ST1 = id(2), ST2 = id(3), ST3 = id(4);
  const mail = (uid) => `u${uid.slice(-2)}@t.cm`;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims({})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const svc = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', 'service_role', false), ${claims({ role: 'service_role' })}; set role service_role`); };
  const sup = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { await sup(); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const jq = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const srpc = async (sql) => { await svc(); return rpc(sql); };
  const DENY = /Réservé|permission denied|Accès refusé|Connexion requise/i;
  const LIM = 'Évaluation à distance : le geste technique n\'a pas été observé.';
  const mkReq = async (cand, prov, status = 'envoyee') => (await qs(`insert into assessment_requests (candidate_id, family_code, mode, provider_code, status, funding, consent, created_at)
    values ('${cand}', 'mecanique', 'evaluation_projets', ${prov ? `'${prov}'` : 'null'}, '${status}', 'gratuite_mensuelle', true, now()) returning id`))[0].id;
  const notifs = async (uid) => (await qs(`select count(*)::int n from notifications where user_id = '${uid}' and kind = 'assessment'`))[0].n;
  const reqRow = async (rid) => (await qs(`select status, external_ref, candidate_url, dispatch_attempts, status_note from assessment_requests where id = '${rid}'`))[0];

  await sup();
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [ST1, 'Etu Un', 'student'], [ST2, 'Etu Deux', 'student'], [ST3, 'Etu Trois', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }
  await db.exec(`insert into assessment_providers (code, name, status, family_codes, modes) values
    ('prov_a', 'Fournisseur A (banc)', 'actif', array['mecanique'], array['evaluation_projets']),
    ('prov_b', 'Fournisseur B (banc)', 'actif', array['mecanique'], array['evaluation_projets']),
    ('prov_c', 'Fournisseur C (banc)', 'candidat', array['mecanique'], array['evaluation_projets'])`);

  // ============================================================ A. Droits : réservé au service
  const r1 = await mkReq(ST1, 'prov_a');
  for (const [who, fn] of [['anonyme', () => as(null)], ['étudiant', () => as(ST1)], ['administrateur', () => as(ADM)]]) {
    await fn();
    await fails(`A1 ${who} : assessment_dispatch_claim refusé`, `select assessment_dispatch_claim(5, null)`, DENY);
    await fails(`A2 ${who} : assessment_dispatch_accepted refusé`, `select assessment_dispatch_accepted('${r1}', 'X', null)`, DENY);
    await fails(`A3 ${who} : assessment_dispatch_result refusé`, `select assessment_dispatch_result('${r1}', 'prov_a', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '{}'::jsonb, 'x', '[]'::jsonb)`, DENY);
    await fails(`A4 ${who} : assessment_dispatch_failed / provider_failed refusés`, `select assessment_dispatch_failed('${r1}', 500, 'x'), assessment_dispatch_provider_failed('${r1}', 'prov_a', 'x')`, DENY);
  }
  await as(ST1);
  await fails('A5 le candidat ne lit pas le journal d\'envoi directement', `select count(*) from assessment_dispatch_log`, /permission denied|row-level/i);
  await fails('A6 le candidat ne lit pas le journal d\'administration', `select assessment_dispatch_log_admin(10)`, DENY);
  await as(ADM);
  check('A7 l\'administrateur lit le journal d\'administration (vide au départ)', Array.isArray(await rpc(`assessment_dispatch_log_admin(10)`)));

  // ============================================================ B. Réclamation : fournisseurs actifs et choisis seulement
  const r2 = await mkReq(ST2, 'prov_c');      // fournisseur candidat (non actif)
  const r3 = await mkReq(ST3, null);          // pas de fournisseur
  await svc();
  let c = await srpc(`assessment_dispatch_claim(10, array['inconnu'])`);
  check('B1 liste de fournisseurs sans correspondance : rien réclamé', c.length === 0);
  c = await srpc(`assessment_dispatch_claim(10, array[]::text[])`);
  check('B2 liste vide : rien réclamé', c.length === 0);
  c = await srpc(`assessment_dispatch_claim(10, array['prov_a', 'prov_c'])`);
  check('B3 seule la demande du fournisseur ACTIF est réclamée (candidat et sans fournisseur ignorés)', c.length === 1 && c[0].request_id === r1 && c[0].provider === 'prov_a' && c[0].family === 'mecanique' && c[0].mode === 'evaluation_projets' && c[0].attempt === 1, JSON.stringify(c));
  check('B4 la réclamation ne contient aucune donnée personnelle', Object.keys(c[0]).sort().join() === 'attempt,family,mode,provider,request_id');
  c = await srpc(`assessment_dispatch_claim(10, null)`);
  check('B5 deuxième réclamation immédiate : rien (espacement de 10 minutes)', c.length === 0);
  check('B6 tentative comptée, statut inchangé', (await reqRow(r1)).dispatch_attempts === 1 && (await reqRow(r1)).status === 'envoyee');

  // ============================================================ C. Acceptation
  await svc();
  await fails('C1 référence du fournisseur obligatoire', `select assessment_dispatch_accepted('${r1}', '  ', null)`, /Référence/);
  let a = await srpc(`assessment_dispatch_accepted('${r1}', 'EXT-1', 'http://pas-https.test/e')`);
  const rr = await reqRow(r1);
  check('C2 acceptation : statut acceptee, référence conservée, lien non https ignoré', a.ok === true && rr.status === 'acceptee' && rr.external_ref === 'EXT-1' && rr.candidate_url === null, JSON.stringify(rr));
  check('C3 le candidat est notifié', (await notifs(ST1)) === 1);
  a = await srpc(`assessment_dispatch_accepted('${r1}', 'EXT-1', null)`);
  check('C4 seconde acceptation : sans effet (not_pending)', a.ok === false && a.reason === 'not_pending');
  const r4 = await mkReq(ST2, 'prov_b');
  await svc();
  await srpc(`assessment_dispatch_claim(10, array['prov_b'])`);
  await srpc(`assessment_dispatch_accepted('${r4}', 'EXT-4', 'https://passer.exemple.test/e/4')`);
  check('C5 lien https conservé pour le candidat', (await reqRow(r4)).candidate_url === 'https://passer.exemple.test/e/4');

  // ============================================================ D. Résultat : garde-fous et idempotence
  const good = { competences: [{ name: 'Usinage', level: 'intermediaire', verifiable_remotely: true }], criteria: [{ name: 'Précision', score: 7, max_score: 10 }], evidence: [], details: {}, limits: LIM, recommendations: [] };
  const res = async (rid, prov, ref, o) => srpc(`assessment_dispatch_result('${rid}', '${prov}', ${ref ? `'${ref}'` : 'null'}, ${jq(o.competences)}, ${jq(o.criteria)}, ${jq(o.evidence)}, ${jq(o.details)}, '${(o.limits ?? '').replace(/'/g, "''")}', ${jq(o.recommendations)})`);
  await svc();
  await fails('D1 fournisseur différent de celui de la demande : refusé', `select assessment_dispatch_result('${r1}', 'prov_b', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '{}'::jsonb, 'x', '[]'::jsonb)`, /Fournisseur différent/);
  await fails('D2 référence du fournisseur différente : refusée', `select assessment_dispatch_result('${r1}', 'prov_a', 'AUTRE', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '{}'::jsonb, 'x', '[]'::jsonb)`, /Référence du fournisseur différente/);
  let o = await res(r1, 'prov_a', 'EXT-1', { ...good, details: { accent_oral: 'marqué' } });
  check('D3 champ de biais (accent) : résultat refusé et journalisé', o.ok === false && o.reason === 'result_rejected', JSON.stringify(o));
  check('D4 refusé : aucun résultat, demande toujours acceptee', (await qs(`select count(*)::int n from assessment_results where request_id = '${r1}'`))[0].n === 0 && (await reqRow(r1)).status === 'acceptee');
  await svc();
  o = await res(r1, 'prov_a', 'EXT-1', { ...good, limits: '' });
  check('D5 limites vides : résultat refusé', o.ok === false && o.reason === 'result_rejected', JSON.stringify(o));
  await svc();
  o = await res(r1, 'prov_a', 'EXT-1', good);
  check('D6 résultat valide : enregistré, demande terminee', o.ok === true && !!o.result && (await reqRow(r1)).status === 'terminee', JSON.stringify(o));
  const row = (await qs(`select validation_status, limits, provider_code, competences->0->>'name' n from assessment_results where request_id = '${r1}'`))[0];
  check('D7 résultat enregistré tel que reçu (rien ajouté), statut automatique, fournisseur et limites conservés', row.validation_status === 'automatique' && row.limits === LIM && row.provider_code === 'prov_a' && row.n === 'Usinage', JSON.stringify(row));
  await svc();
  o = await res(r1, 'prov_a', 'EXT-1', good);
  check('D8 renvoi du même résultat : idempotent (duplicate), une seule ligne', o.ok === true && o.duplicate === true && (await qs(`select count(*)::int n from assessment_results where request_id = '${r1}'`))[0].n === 1);
  check('D9 notification de résultat envoyée une seule fois (acceptation + résultat = 2)', (await notifs(ST1)) === 2);
  // geste non observable à distance : validation humaine imposée
  o = await res(r4, 'prov_b', 'EXT-4', { ...good, competences: [{ name: 'Soudure', level: 'avance', verifiable_remotely: false }] });
  await svc();
  check('D10 compétence non vérifiable à distance : validation_humaine_requise', o.ok === true && (await qs(`select validation_status v from assessment_results where request_id = '${r4}'`))[0].v === 'validation_humaine_requise');
  // fournisseur suspendu avant la réception
  const r5 = await mkReq(ST3, 'prov_a', 'acceptee');
  await db.exec(`reset role; update assessment_providers set status = 'suspendu' where code = 'prov_a'`);
  await svc();
  o = await res(r5, 'prov_a', null, good);
  check('D11 fournisseur non actif : résultat refusé (provider_not_active), aucune ligne', o.ok === false && o.reason === 'provider_not_active' && (await qs(`select count(*)::int n from assessment_results where request_id = '${r5}'`))[0].n === 0, JSON.stringify(o));
  await db.exec(`reset role; update assessment_providers set status = 'actif' where code = 'prov_a'`);
  await svc();
  const r6 = await mkReq(ST2, 'prov_a', 'envoyee'); await svc();
  o = await res(r6, 'prov_a', null, good);
  check('D12 résultat sur une demande non démarrée (envoyee) : refusé (not_running)', o.ok === false && o.reason === 'not_running', JSON.stringify(o));

  // ============================================================ E. Échecs : quota gratuit non consommé
  await sup();
  const r7 = await mkReq(ST2, 'prov_b');
  await as(ST2);
  const usedBefore = Number((await rpc(`assessment_quota()`)).used ?? -1);
  for (let i = 1; i <= 5; i++) {
    await sup(); await db.exec(`update assessment_requests set last_dispatch_at = now() - interval '11 minutes' where id = '${r7}'`);
    await svc();
    const cl = await srpc(`assessment_dispatch_claim(10, array['prov_b'])`);
    if (!cl.some((x) => x.request_id === r7)) { check(`E0 tentative ${i} réclamée`, false, JSON.stringify(cl)); break; }
    const f = await srpc(`assessment_dispatch_failed('${r7}', 503, 'HTTP 503')`);
    if (i < 5) check(`E1.${i} échec ${i}/5 : la demande reste envoyee`, f.ok === true && f.final === false && (await reqRow(r7)).status === 'envoyee');
    else check('E2 cinquième échec : abandon définitif (echouee) avec message', f.final === true && (await reqRow(r7)).status === 'echouee' && /pas pu être joint/.test((await reqRow(r7)).status_note));
  }
  await sup(); await db.exec(`update assessment_requests set last_dispatch_at = now() - interval '11 minutes' where id = '${r7}'`);
  await svc();
  check('E3 une demande abandonnée n\'est plus réclamée', (await srpc(`assessment_dispatch_claim(10, null)`)).every((x) => x.request_id !== r7));
  await as(ST2);
  check('E4 le quota gratuit du candidat n\'est pas consommé par une demande echouee', Number((await rpc(`assessment_quota()`)).used ?? -1) === usedBefore);
  await svc();
  const r8 = await mkReq(ST3, 'prov_b', 'acceptee'); await svc();
  o = await srpc(`assessment_dispatch_provider_failed('${r8}', 'prov_a', 'x')`).catch(() => null);
  await fails('E5 échec signalé par un autre fournisseur : refusé', `select assessment_dispatch_provider_failed('${r8}', 'prov_a', 'x')`, /Fournisseur différent/);
  o = await srpc(`assessment_dispatch_provider_failed('${r8}', 'prov_b', 'abandon')`);
  check('E6 échec signalé par le bon fournisseur : demande echouee, candidat notifié', o.ok === true && (await reqRow(r8)).status === 'echouee' && (await notifs(ST3)) >= 1);
  o = await srpc(`assessment_dispatch_provider_failed('${r8}', 'prov_b', 'abandon')`);
  check('E7 second signalement : sans effet', o.ok === false && o.reason === 'not_running');

  // ============================================================ F. Journal, isolation et livraison
  await as(ADM);
  const log = await rpc(`assessment_dispatch_log_admin(200)`);
  const events = new Set(log.map((l) => l.event));
  check('F1 le journal contient claimed, accepted, failed, gave_up, result, result_rejected', ['claimed', 'accepted', 'failed', 'gave_up', 'result', 'result_rejected'].every((e) => events.has(e)), [...events].join());
  await as(ST2);
  const mine = await rpc(`assessment_my_list()`);
  check('F2 le candidat ne voit que ses demandes (pas celles des autres)', mine.every((x) => x.id !== r1 && x.id !== r8), JSON.stringify(mine.map((x) => x.id)));
  await fails('F3 le candidat ne peut pas fabriquer un résultat par écriture directe', `insert into assessment_results (request_id, candidate_id, limits) values ('${r6}', '${ST2}', 'x')`, /row-level|permission denied/i);
  await sup();
  check('F4 livraison : aucun résultat, fournisseur ni demande n\'existait avant ce scénario (tout vient des fixtures ci-dessus)', (await qs(`select count(*)::int n from assessment_providers where code not in ('prov_a','prov_b','prov_c')`))[0].n === 0);
  console.log(`h12_eval_dispatch : ${ok} OK, ${ko} ECHEC`);
}
