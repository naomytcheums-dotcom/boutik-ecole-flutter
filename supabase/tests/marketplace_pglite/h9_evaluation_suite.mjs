// Lot H9 / EVAL-SQL : complément du socle « Talent Assessment » (migrations 20261125095000 modifiée, 20261125096000, 20261125096100, 20261125096200).
// Prouve : 11 modes du CDC 8.2 ; validation humaine par permission explicite « tech.assessments » (une IA ne certifie jamais un geste non observé : statut humain impossible côté fournisseur) ;
// contestation traitée (en_examen -> close motivée, notification, immuable) ; campagnes d'organisation (équipe d'organisation, aucun paiement, partage consenti) ;
// réutilisation d'une évaluation récente avec accord révocable (durée absente = indisponible) ; correspondance catalogue - 33 familles ; non-discrimination des critères ; rejeu.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h9_evaluation_suite.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000092${String(n).padStart(2, '0')}`;
  const ADM = id(1), ADM2FA = id(2), ST1 = id(3), ST2 = id(4), CLI = id(5), ORG = id(6), ORG2 = id(7), TECH = id(8), SUP = id(9), REV = id(10), MEMA = id(11), MEMF = id(12), MEMV = id(13), ST3 = id(14), REV2FA = id(15);
  const mail = (uid) => `u${uid.slice(-2)}@t.cm`;
  let cur = null;
  const as = async (uid, role = 'authenticated') => { cur = { uid, role }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false)`); if (role) await db.exec(`set role ${role}`); };
  const asAal = async (uid, aal) => { cur = { uid, role: 'authenticated' }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false), set_config('request.jwt.claims', '${JSON.stringify({ sub: uid, aal })}', false); set role authenticated`); };
  const sup = async () => { cur = null; await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid, save.role); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const DENY = /Réservé|réservé|Accès refusé|Connexion requise|permission denied|exige la permission|row-level security|Campagne introuvable|introuvable/i;
  const ADMIN_ONLY = /Réservé|Accès refusé|Connexion requise|permission denied/i;
  const jq = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const rec = async (reqId, obj) => (await q(`select assessment_result_record('${reqId}', ${jq(obj)}) r`))[0].r;
  const notifs = async (uid) => (await qs(`select count(*)::int n from notifications where user_id = '${uid}' and kind = 'assessment'`))[0].n;
  // Demande déjà acceptée par le fournisseur (jeu de test inséré par le superutilisateur : le scénario ne passe pas par le quota gratuit)
  const mkReq = async (cand, fam, mode, camp = null) => (await qs(`insert into assessment_requests (candidate_id, family_code, mode, provider_code, status, funding, campaign_id, consent, share_with_org, accepted_at)
    values ('${cand}', '${fam}', '${mode}', 'prov_b', 'acceptee', '${camp ? 'financee_organisation' : 'payee_candidat'}', ${camp ? `'${camp}'` : 'null'}, true, ${camp ? 'true' : 'false'}, now()) returning id`))[0].id;
  const LIM = 'Évaluation à distance : le geste technique n\'a pas été observé.';
  const snapshot = async () => (await qs(`select
      (select count(*) from assessment_families) f, (select count(*) from assessment_providers) p, (select count(*) from assessment_campaigns) c, (select count(*) from assessment_campaign_invites) i,
      (select count(*) from assessment_requests) r, (select count(*) from assessment_results) s, (select count(*) from assessment_disputes) d, (select count(*) from assessment_family_skill_map) m,
      (select count(*) from admin_permissions where code = 'tech.assessments') perm, (select count(*) from pg_policies where tablename like 'assessment_%') pol,
      (select count(*) from pg_proc where proname like 'assessment_%' or proname like '\\_assessment\\_%') fn, (select count(*) from pg_trigger where tgname like 'trg_assessment_%') trg`))[0];

  // ============================================================ comptes
  await db.exec('reset role');
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [ADM2FA, 'Mfa Admin', 'admin'], [ST1, 'Etu Un', 'student'], [ST2, 'Etu Deux', 'student'], [CLI, 'Cli Client', 'client'],
    [ORG, 'Org Une', 'company'], [ORG2, 'Org Deux', 'company'], [TECH, 'Tech Agent', 'support'], [SUP, 'Sup Agent', 'support'], [REV, 'Rev Evaluateur', 'support'],
    [MEMA, 'Mem Admin', 'client'], [MEMF, 'Mem Finance', 'client'], [MEMV, 'Mem Lecteur', 'client'], [ST3, 'Etu Trois', 'student'], [REV2FA, 'Rev Mfa', 'support']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }

  // ============================================================ A. État de livraison : rien d'inventé
  const s0 = await snapshot();
  check('A1 livraison : aucun fournisseur, campagne, demande, résultat, contestation, correspondance', ['p', 'c', 'i', 'r', 's', 'd', 'm'].every((k) => Number(s0[k]) === 0), JSON.stringify(s0));
  check('A2 livraison : 33 familles et aucun réglage « assessment.* » inventé', Number(s0.f) === 33 && (await qs(`select count(*)::int n from platform_settings where key like 'assessment.%'`))[0].n === 0);
  check('A3 les 11 modes du CDC 8.2 sont dans la liste unique du serveur', (await qs(`select cardinality(_assessment_modes()) n`))[0].n === 11);
  const modesDb = (await qs(`select unnest(_assessment_modes()) m`)).map((x) => x.m);
  check('A4 modes : analyse de fichiers, évaluation de projets, analyse d\'images/vidéos présents (absents du socle précédent)', ['analyse_fichiers', 'evaluation_projets', 'analyse_images_videos'].every((m) => modesDb.includes(m)));
  check('A5 la fonction du socle précédent (_assessment_shared_with_org) a disparu au profit de la version résultat', (await qs(`select count(*)::int n from pg_proc where proname = '_assessment_shared_with_org'`))[0].n === 0);

  // permission : catalogue, aucune extension des droits existants
  const perm = (await qs(`select team_code, sensitive from admin_permissions where code = 'tech.assessments'`))[0];
  check('B1 permission « tech.assessments » : équipe Technique, sensible', perm && perm.team_code === 'tech' && perm.sensitive === true);
  check('B2 aucun jeu de droits par défaut ne contient la nouvelle permission', (await qs(`select count(*)::int n from (select unnest(_admin_team_defaults(t)) p from unnest(array['finance','support','security','tech']) t) x where p = 'tech.assessments'`))[0].n === 0);

  await as(ADM);
  await q(`select admin_team_member_set('${TECH}', 'tech', array['tech.integrations'])`);
  await q(`select admin_team_member_set('${SUP}', 'support', array['support.disputes', 'support.tickets'])`);
  await q(`select admin_team_member_set('${REV}', 'tech', array['tech.assessments'])`);
  await q(`select admin_team_member_set('${REV2FA}', 'tech', array['tech.assessments'])`);
  await sup();
  check('B3 agents existants inchangés (technique : intégrations seulement ; support : litiges et tickets)',
    (await qs(`select permissions from admin_team_members where user_id = '${TECH}' and team_code = 'tech'`))[0].permissions.join() === 'tech.integrations'
    && (await qs(`select permissions from admin_team_members where user_id = '${SUP}' and team_code = 'support'`))[0].permissions.join() === 'support.disputes,support.tickets'
    && (await qs(`select count(*)::int n from admin_team_members where 'tech.assessments' = any (permissions)`))[0].n === 2);
  for (const [who, uid, exp] of [['agent technique', TECH, false], ['agent support', SUP, false], ['évaluateur', REV, true], ['administrateur', ADM, true], ['étudiant', ST1, false], ['organisation', ORG, false]]) {
    await as(uid);
    check(`B4 ${who} : has_admin_permission('tech.assessments') = ${exp}`, (await rpc(`has_admin_permission('tech.assessments')`)) === exp);
  }

  // ============================================================ C. Fournisseur de banc (les 11 modes) : aucun appel externe
  await as(ADM);
  await works('C1 enregistrement d\'un fournisseur couvrant les 11 modes', `select assessment_provider_register('prov_b', 'Fournisseur B (banc)', array['mecanique','soudure','plomberie'], _assessment_modes())`);
  await fails('C2 mode hors liste refusé dans le registre', `select assessment_provider_register('prov_c', 'Fournisseur C', array['mecanique'], array['hologramme'])`, /check|violates/i);
  await q(`select assessment_provider_record_test('prov_b', true, 'appel de test réussi (banc)')`);
  await works('C3 activation (test réussi enregistré)', `select assessment_provider_set_status('prov_b', 'actif')`);
  await as(ST2);
  for (const mode of ['evaluation_projets', 'analyse_fichiers', 'analyse_images_videos']) {
    const r = await rpc(`assessment_request('mecanique', '${mode}', true, 'gratuite_mensuelle', null, null)`);
    check(`C4 demande en mode « ${mode} » acceptée par le serveur`, r.ok === true && r.status === 'envoyee', JSON.stringify(r));
    await as(ADM);
    await q(`select assessment_request_ack('${r.id}', 'refusee', 'banc')`);
    await as(ST2);
  }
  check('C5 quota gratuit d\'ST2 intact après trois demandes refusées', (await rpc(`assessment_quota()`)).remaining === 1);
  await fails('C6 mode inconnu refusé', `select assessment_request('mecanique', 'hologramme', true, 'gratuite_mensuelle', null, null)`, /Mode d'évaluation inconnu/);

  // ============================================================ D. Validation humaine (une IA ne certifie jamais un geste non observé)
  const payloadNV = { competences: [{ name: 'Diagnostic sur dossier', verifiable_remotely: true }, { name: 'Réglage manuel d\'un moteur', verifiable_remotely: false }], criteria: [{ name: 'Méthode', score: 3, max_score: 5 }], evidence: [{ kind: 'réponse écrite' }], limits: LIM, recommendations: ['Faire valider le geste en présentiel'] };
  const payloadOK = { competences: [{ name: 'Lecture de plans', verifiable_remotely: true }], criteria: [{ name: 'Exactitude' }], limits: 'Évaluation écrite uniquement.' };
  const rqA = await mkReq(ST1, 'mecanique', 'ecrit'), rqB = await mkReq(ST2, 'soudure', 'ecrit'), rqC = await mkReq(ST1, 'plomberie', 'simulation'), rqD = await mkReq(REV, 'mecanique', 'ecrit'),
    rqE = await mkReq(ST2, 'plomberie', 'validation_humaine');
  await as(ADM);
  const RA = await rec(rqA, { ...payloadNV, validation_status: 'validee_humainement' });
  check('D1 un fournisseur ne peut pas poser « validee_humainement » (valeur ignorée, validation humaine requise)', (await qs(`select validation_status v from assessment_results where id = '${RA}'`))[0].v === 'validation_humaine_requise');
  const RB = await rec(rqB, payloadNV), RC = await rec(rqC, payloadOK), RD = await rec(rqD, payloadNV);
  const RE = await rec(rqE, { ...payloadOK, validation_status: 'automatique' });
  check('D2 résultat conforme : automatique ; mode « validation_humaine » : validation humaine requise même si le fournisseur dit automatique',
    (await qs(`select validation_status v from assessment_results where id = '${RC}'`))[0].v === 'automatique' && (await qs(`select validation_status v from assessment_results where id = '${RE}'`))[0].v === 'validation_humaine_requise');
  await sup();
  const RAW = (extra, st) => `insert into assessment_results (request_id, candidate_id, provider_code, competences, limits, validation_status ${extra.cols}) values ('${extra.req}', '${extra.cand}', 'prov_b', '[]', 'x', '${st}' ${extra.vals})`;
  const rqF = await mkReq(ST3, 'mecanique', 'ecrit');
  await fails('D3 insertion directe « validee_humainement » sans évaluateur : refusée par le serveur', RAW({ cols: '', vals: '', req: rqF, cand: ST3 }, 'validee_humainement'), /Une IA ne certifie jamais/);
  await fails('D4 insertion directe « non_verifiable_a_distance » sans évaluateur : refusée', RAW({ cols: '', vals: '', req: rqF, cand: ST3 }, 'non_verifiable_a_distance'), /Une IA ne certifie jamais/);
  await fails('D5 mise à jour directe vers « validee_humainement » : refusée', `update assessment_results set validation_status = 'validee_humainement' where id = '${RA}'`, /Une IA ne certifie jamais/);
  await fails('D6 évaluateur et date usurpés sans passer par la RPC : refusés', `update assessment_results set validation_status = 'validee_humainement', reviewed_by = '${REV}', reviewed_at = now() where id = '${RA}'`, /Une IA ne certifie jamais/);
  check('D7 aucun résultat n\'a été certifié par ces tentatives', (await qs(`select count(*)::int n from assessment_results where validation_status in ('validee_humainement', 'non_verifiable_a_distance')`))[0].n === 0);

  for (const [who, uid] of [['étudiant', ST1], ['client', CLI], ['organisation', ORG], ['agent technique (intégrations)', TECH], ['agent support (litiges)', SUP], ['membre d\'organisation', MEMA]]) {
    await as(uid);
    await fails(`D8 ${who} : validation humaine refusée`, `select assessment_human_validate('${RA}', 'validee_humainement', 'Geste observé en atelier le jour même')`, DENY);
    await fails(`D9 ${who} : file de l'évaluateur refusée`, `select assessment_review_queue()`, DENY);
  }
  await as(null, 'anon');
  await fails('D10 anonyme : validation humaine refusée', `select assessment_human_validate('${RA}', 'validee_humainement', 'Geste observé en atelier le jour même')`, /permission denied|Connexion requise/i);
  await fails('D11 anonyme : file refusée', `select assessment_review_queue()`, /permission denied|Connexion requise/i);

  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${REV2FA}', 'verified')`);
  await asAal(REV2FA, 'aal1');
  await fails('D12 évaluateur avec 2FA en session aal1 : refusé', `select assessment_human_validate('${RA}', 'validee_humainement', 'Geste observé en atelier le jour même')`, /double authentification/);

  await as(REV);
  const queue = await rpc(`assessment_review_queue()`);
  check('D13 évaluateur : la file contient les résultats à valider (A, B, D, E) et pas le résultat automatique C',
    queue.results.length === 4 && queue.results.every((x) => x.result_id !== RC) && queue.results.every((x) => x.limits && x.candidate), JSON.stringify(queue.results.map((x) => x.result_id)));
  await fails('D14 motif trop court refusé', `select assessment_human_validate('${RA}', 'validee_humainement', 'ok')`, /10 à 1000/);
  await fails('D15 décision inconnue refusée', `select assessment_human_validate('${RA}', 'certifie_par_ia', 'Geste observé en atelier le jour même')`, /Décision inconnue/);
  await fails('D16 résultat sans besoin de validation (automatique) : refusé', `select assessment_human_validate('${RC}', 'validee_humainement', 'Geste observé en atelier le jour même')`, /n'attend pas de validation humaine/);
  await fails('D17 évaluateur : ne valide pas sa propre évaluation', `select assessment_human_validate('${RD}', 'validee_humainement', 'Geste observé en atelier le jour même')`, /votre propre évaluation/);
  await fails('D18 résultat inconnu refusé', `select assessment_human_validate('${id(99)}', 'validee_humainement', 'Geste observé en atelier le jour même')`, /introuvable/);
  const nA = await notifs(ST1);
  const vA = await rpc(`assessment_human_validate('${RA}', 'validee_humainement', 'Geste observé en atelier le 24/11 : réglage conforme.')`);
  check('D19 validation humaine enregistrée', vA.ok === true && vA.validation_status === 'validee_humainement');
  const rowA = (await qs(`select validation_status, reviewed_by, reviewed_at, review_note from assessment_results where id = '${RA}'`))[0];
  check('D20 évaluateur, date et motif tracés', rowA.validation_status === 'validee_humainement' && rowA.reviewed_by === REV && rowA.reviewed_at && /réglage conforme/.test(rowA.review_note));
  check('D21 le candidat est notifié', (await notifs(ST1)) === nA + 1);
  const vB = await rpc(`assessment_human_validate('${RB}', 'non_verifiable_a_distance', 'Geste impossible à vérifier à distance : examen en présentiel nécessaire.')`);
  check('D22 « non vérifiable à distance » enregistré', vB.ok === true && (await qs(`select validation_status v from assessment_results where id = '${RB}'`))[0].v === 'non_verifiable_a_distance');
  await fails('D23 une décision déjà prise n\'est pas rejouée', `select assessment_human_validate('${RA}', 'non_verifiable_a_distance', 'Je change d''avis sur ce résultat déjà validé.')`, /n'attend pas de validation humaine/);
  await fails('D24 résultat validé : compétences non modifiables (même en écriture directe)', `update assessment_results set competences = '[]' where id = '${RA}'`, /Décision humaine déjà enregistrée|permission denied/);
  await sup();
  await fails('D25 résultat validé : retour arrière du statut refusé (superutilisateur)', `update assessment_results set competences = '[{"name":"x"}]'::jsonb where id = '${RA}'`, /Décision humaine déjà enregistrée/);
  await fails('D26 résultat validé : statut non remplaçable (superutilisateur)', `update assessment_results set validation_status = 'automatique' where id = '${RA}'`, /Décision humaine déjà enregistrée/);
  await as(ST1);
  const resA = await rpc(`assessment_result('${RA}')`);
  check('D27 le candidat voit son statut humain et le motif', resA.validation_status === 'validee_humainement' && /réglage conforme/.test(resA.review_note) && resA.human_validation_required === false);
  await as(ST2);
  await fails('D28 un autre candidat ne voit pas ce résultat', `select assessment_result('${RA}')`, /introuvable/);
  await as(ADM);
  const vE = await rpc(`assessment_human_validate('${RE}', 'validee_humainement', 'Évaluation en présentiel réalisée par un évaluateur habilité.')`);
  check('D29 l\'administrateur global (toutes permissions) peut valider', vE.ok === true);
  await as(ADM);
  await q(`select admin_team_member_remove('${REV}', 'tech')`);
  await as(REV);
  await fails('D30 permission retirée : file refusée', `select assessment_review_queue()`, DENY);

  // ============================================================ E. Contestations
  await as(ADM);
  await q(`select admin_team_member_set('${REV}', 'tech', array['tech.assessments'])`);
  await as(ST1);
  const disp = await rpc(`assessment_dispute('${RC}', 'Je conteste : le critère d''exactitude ne tient pas compte de mon dossier.')`);
  check('E1 contestation ouverte par le candidat', disp.ok === true);
  const DID = disp.id;
  await as(SUP);
  check('E2 agent support (support.disputes) : lit la contestation mais ne la traite pas', (await q(`select count(*)::int n from assessment_disputes`))[0].n === 1);
  await fails('E3 agent support : traitement refusé', `select assessment_dispute_handle('${DID}', 'take')`, DENY);
  await as(TECH);
  await fails('E4 agent technique (intégrations) : traitement refusé', `select assessment_dispute_handle('${DID}', 'take')`, DENY);
  await as(ST2);
  check('E5 autre candidat : ne voit pas la contestation', (await q(`select count(*)::int n from assessment_disputes`))[0].n === 0);
  await fails('E6 autre candidat : traitement refusé', `select assessment_dispute_handle('${DID}', 'take')`, DENY);
  await as(REV);
  check('E7 évaluateur : la contestation est dans sa file', (await rpc(`assessment_review_queue()`)).disputes.some((x) => x.id === DID && x.status === 'ouverte'));
  await fails('E8 action inconnue refusée', `select assessment_dispute_handle('${DID}', 'delete')`, /Action inconnue/);
  await fails('E9 une contestation ouverte ne se clôt pas sans passer en examen', `select assessment_dispute_handle('${DID}', 'close', 'Résolution motivée suffisamment longue pour passer.')`, /Seule une contestation en examen/);
  const nT = await notifs(ST1);
  const t = await rpc(`assessment_dispute_handle('${DID}', 'take')`);
  check('E10 prise en examen', t.status === 'en_examen' && (await notifs(ST1)) === nT + 1);
  await fails('E11 une contestation déjà en examen ne se reprend pas', `select assessment_dispute_handle('${DID}', 'take')`, /n'est plus ouverte/);
  await fails('E12 résolution trop courte refusée', `select assessment_dispute_handle('${DID}', 'close', 'non')`, /20 à 2000/);
  await fails('E13 résolution vide refusée', `select assessment_dispute_handle('${DID}', 'close')`, /20 à 2000/);
  const c = await rpc(`assessment_dispute_handle('${DID}', 'close', 'Examen du dossier : le critère est maintenu, les preuves fournies ne couvrent pas la question 3.')`);
  check('E14 contestation close avec résolution motivée', c.status === 'close' && (await notifs(ST1)) === nT + 2);
  await fails('E15 une contestation close ne se rouvre pas', `select assessment_dispute_handle('${DID}', 'take')`, /n'est plus ouverte/);
  await as(ST1);
  const resC = await rpc(`assessment_result('${RC}')`);
  check('E16 le candidat voit la résolution', resC.disputes[0].status === 'close' && /critère est maintenu/.test(resC.disputes[0].resolution));
  check('E17 liste du candidat : statut de contestation close', (await rpc(`assessment_my_list()`)).some((x) => x.result_id === RC && x.dispute_status === 'close'));
  await fails('E18 le candidat ne peut pas modifier sa contestation close', `update assessment_disputes set reason = 'Je réécris mon motif après coup.' where id = '${DID}'`, /permission denied/i);
  await fails('E19 le candidat ne peut pas supprimer sa contestation close', `delete from assessment_disputes where id = '${DID}'`, /permission denied/i);
  await sup();
  await fails('E20 même en écriture directe (superutilisateur) : modification d\'une contestation close refusée', `update assessment_disputes set resolution = 'autre' where id = '${DID}'`, /ni modifiée ni supprimée/);
  await fails('E21 même en écriture directe : suppression refusée', `delete from assessment_disputes where id = '${DID}'`, /ni modifiée ni supprimée/);
  check('E22 la contestation close est intacte', (await qs(`select status, resolved_at is not null ok from assessment_disputes where id = '${DID}'`))[0].ok === true);
  // suppression en cascade d'un compte : possible (droit à l'effacement)
  const rqG = await mkReq(ST3, 'mecanique', 'ecrit');
  await as(ADM);
  const RG = await rec(rqG, payloadOK);
  await as(ST3);
  const dg = await rpc(`assessment_dispute('${RG}', 'Contestation d''un compte qui sera supprimé ensuite.')`);
  await as(REV);
  await q(`select assessment_dispute_handle('${dg.id}', 'take')`);
  await q(`select assessment_dispute_handle('${dg.id}', 'close', 'Contestation examinée : aucune erreur constatée sur ce résultat.')`);
  await sup();
  await works('E23 suppression du compte du candidat : contestation close supprimée en cascade', `delete from profiles where id = '${ST3}'`);
  check('E24 plus aucune ligne du compte supprimé', (await qs(`select count(*)::int n from assessment_disputes where id = '${dg.id}'`))[0].n === 0);

  // ============================================================ F. Non-discrimination des critères
  await as(ADM);
  const rqH = await mkReq(ST2, 'mecanique', 'ecrit');
  const refusals = [
    ['critère « accent »', { criteria: [{ name: 'Maîtrise', accent: 'léger' }] }],
    ['critère libellé « Apparence »', { criteria: [{ name: 'Apparence' }] }],
    ['critère libellé « Accent de l\'orateur »', { criteria: [{ label: 'Accent de l\'orateur' }] }],
    ['clé « sexe » dans les compétences', { competences: [{ name: 'Soudure', sexe: 'F' }] }],
    ['clé « handicap » imbriquée dans les détails', { details: { profil: { handicap: false } } }],
    ['clé « Origine » (majuscule) dans les preuves', { evidence: [{ Origine: 'x' }] }],
    ['clé « âge » accentuée', { competences: [{ name: 'x', 'âge': 30 }] }],
    ['clé « origine_ethnique » dans les recommandations', { recommendations: [{ origine_ethnique: 'x' }] }],
    ['clé « apparence_physique »', { criteria: [{ name: 'Tenue', apparence_physique: 3 }] }],
    ['clé hors liste blanche dans un critère', { criteria: [{ name: 'Méthode', note_secrete: 3 }] }],
    ['critère qui n\'est pas un objet', { criteria: ['Méthode'] }]
  ];
  for (const [label, extra] of refusals) {
    await fails(`F1 refus : ${label}`, `select assessment_result_record('${rqH}', ${jq({ ...payloadOK, ...extra })})`, /Critère refusé|Champ refusé/);
  }
  check('F2 aucun résultat enregistré par les refus', (await qs(`select count(*)::int n from assessment_results where request_id = '${rqH}'`))[0].n === 0);
  await sup();
  await fails('F3 écriture directe (superutilisateur) : même garde', `insert into assessment_results (request_id, candidate_id, limits, criteria) values ('${rqH}', '${ST2}', 'x', '[{"name":"Méthode","sexe":"F"}]')`, /Critère refusé|Champ refusé/);
  await as(ADM);
  await works('F4 critères conformes (liste blanche) acceptés', `select assessment_result_record('${rqH}', ${jq({ ...payloadOK, criteria: [{ name: 'Méthode', score: 3, max_score: 5, weight: 0.4, comment: 'Accentuation correcte des étapes', observed: true, evidence_refs: ['e1'] }] })})`);
  check('F5 le mot « accentuation » dans une VALEUR n\'est pas refusé', (await qs(`select count(*)::int n from assessment_results where request_id = '${rqH}'`))[0].n === 1);
  check('F6 fonction de contrôle : clés interdites repérées, clés neutres non', (await qs(`select _assessment_bias_key('{"a":{"b":[{"Accent":1}]}}'::jsonb) k1, _assessment_bias_key('{"méthode":1,"score":2}'::jsonb) k2`))[0].k1 === 'Accent'
    && (await qs(`select _assessment_bias_key('{"méthode":1,"score":2}'::jsonb) k2`))[0].k2 === null);

  // ============================================================ G. Campagnes d'une organisation
  await sup();
  await db.exec(`insert into company_profiles (owner_id, company_name) values ('${ORG}', 'Entreprise Une'), ('${ORG2}', 'Entreprise Deux');
    insert into company_members (owner_id, user_id, role, status) values ('${ORG}', '${MEMA}', 'admin', 'active'), ('${ORG}', '${MEMF}', 'finance', 'active'), ('${ORG}', '${MEMV}', 'viewer', 'active')`);
  await as(ORG);
  const k1 = await rpc(`assessment_campaign_create('Campagne soudeurs', 'soudure', 'ecrit')`);
  check('G1 organisation : campagne créée « en attente de financement », sans paiement', k1.ok && k1.status === 'en_attente_financement' && /aucun paiement/i.test(k1.message), JSON.stringify(k1));
  const K1 = k1.id;
  check('G2 la campagne est enregistrée avec ce statut', (await qs(`select status, org_id, created_by from assessment_campaigns where id = '${K1}'`))[0].status === 'en_attente_financement');
  for (const [who, uid] of [['étudiant', ST1], ['client', CLI], ['agent support', SUP]]) {
    await as(uid);
    await fails(`G3 ${who} : création de campagne refusée`, `select assessment_campaign_create('Campagne pirate', 'soudure', 'ecrit')`, ADMIN_ONLY);
  }
  await as(null, 'anon');
  await fails('G4 anonyme : création refusée', `select assessment_campaign_create('Campagne pirate', 'soudure', 'ecrit')`, /permission denied|Connexion requise/i);
  await as(MEMV);
  await fails('G5 lecteur d\'équipe : création refusée', `select assessment_campaign_create('Campagne lecteur', 'soudure', 'ecrit', '${ORG}')`, /Accès refusé/);
  await as(MEMF);
  await fails('G6 responsable financier d\'équipe : création refusée', `select assessment_campaign_create('Campagne finance', 'soudure', 'ecrit', '${ORG}')`, /Accès refusé/);
  await as(ORG2);
  await fails('G7 autre organisation : ne crée pas au nom de l\'organisation voisine', `select assessment_campaign_create('Campagne voisine', 'soudure', 'ecrit', '${ORG}')`, /Accès refusé/);
  await as(MEMA);
  const k1b = await rpc(`assessment_campaign_create('Campagne par un administrateur d''équipe', 'mecanique', 'etude_cas', '${ORG}')`);
  check('G8 administrateur d\'équipe : crée au nom de l\'organisation', k1b.ok && (await qs(`select org_id from assessment_campaigns where id = '${k1b.id}'`))[0].org_id === ORG);
  await as(ORG);
  await fails('G9 mode inconnu refusé', `select assessment_campaign_create('Campagne', 'soudure', 'hologramme')`, /Mode d'évaluation inconnu/);
  await fails('G10 famille inconnue refusée', `select assessment_campaign_create('Campagne', 'famille_x', 'ecrit')`, /Famille de métiers inconnue/);
  await fails('G11 titre trop court refusé', `select assessment_campaign_create('x', 'soudure', 'ecrit')`, /titre/);
  for (const mode of modesDb) {
    const r = await rpc(`assessment_campaign_create('Campagne ${mode}', 'plomberie', '${mode}')`);
    if (!r.ok) check(`G12 mode ${mode}`, false);
  }
  check('G12 les 11 modes sont acceptés pour une campagne', (await qs(`select count(distinct mode)::int n from assessment_campaigns`))[0].n >= 11);
  const lstO = await rpc(`assessment_campaigns_list()`);
  check('G13 organisation : liste ses campagnes (en attente de financement, note explicite)', lstO.length === 13 && lstO.every((x) => x.status === 'en_attente_financement') && lstO.every((x) => /aucun paiement/.test(x.note)), String(lstO.length));
  await as(ORG2);
  check('G14 autre organisation : aucune campagne de l\'organisation voisine', (await rpc(`assessment_campaigns_list()`)).length === 0 && (await q(`select count(*)::int n from assessment_campaigns`))[0].n === 0);
  const k2 = await rpc(`assessment_campaign_create('Campagne mécanique Deux', 'mecanique', 'simulation')`);
  await as(ORG);
  check('G15 une organisation ne voit pas la campagne d\'une autre (RLS)', (await q(`select count(*)::int n from assessment_campaigns where id = '${k2.id}'`))[0].n === 0);
  await as(MEMV);
  const lv = await rpc(`assessment_campaigns_list('${ORG}')`);
  check('G16 lecteur d\'équipe : lit les campagnes mais pas le nombre de résultats', lv.length === 13 && lv.every((x) => x.shared_results === null));
  await as(MEMF);
  check('G17 finance d\'équipe : lit les campagnes', (await rpc(`assessment_campaigns_list('${ORG}')`)).length === 13);
  await as(ST1);
  await fails('G18 étudiant : liste des campagnes d\'organisation refusée', `select assessment_campaigns_list()`, ADMIN_ONLY);
  await as(null, 'anon');
  await fails('G19 anonyme : liste refusée', `select assessment_campaigns_list()`, /permission denied|Connexion requise/i);
  check('G20 aucun mécanisme de paiement ni de débit créé : aucune RPC de campagne ne passe une campagne à « ouverte »',
    (await qs(`select count(*)::int n from pg_proc where proname like 'assessment_%' and prosrc ilike '%update assessment_campaigns%' and prosrc ilike '%''ouverte''%'`))[0].n === 0);

  // invitations
  await as(MEMV);
  await fails('G21 lecteur d\'équipe : invitation refusée', `select assessment_campaign_invite('${K1}', '${mail(ST1)}')`, DENY);
  await as(ORG2);
  await fails('G22 autre organisation : invitation sur la campagne voisine refusée', `select assessment_campaign_invite('${K1}', '${mail(ST1)}')`, /Campagne introuvable/);
  await as(ORG);
  const nI = await notifs(ST1);
  check('G23 organisation : invite un étudiant par e-mail', (await rpc(`assessment_campaign_invite('${K1}', '${mail(ST1)}')`)) === 'invited' && (await qs(`select count(*)::int n from assessment_campaign_invites where campaign_id = '${K1}' and candidate_id = '${ST1}'`))[0].n === 1);
  check('G24 l\'étudiant est notifié (sans partage de résultat)', (await notifs(ST1)) === nI + 1 && /libre de la passer/.test((await qs(`select body from notifications where user_id = '${ST1}' and kind = 'assessment' order by created_at desc limit 1`))[0].body));
  check('G25 e-mail inconnu ou compte inéligible : même réponse, aucune invitation ni notification (pas d\'énumération)',
    (await rpc(`assessment_campaign_invite('${K1}', 'inconnu@nulle-part.cm')`)) === 'invited' && (await rpc(`assessment_campaign_invite('${K1}', '${mail(ORG2)}')`)) === 'invited'
    && (await qs(`select count(*)::int n from assessment_campaign_invites where campaign_id = '${K1}'`))[0].n === 1);
  await fails('G26 e-mail invalide refusé', `select assessment_campaign_invite('${K1}', 'pas-un-email')`, /e-mail/);
  await as(MEMA);
  check('G27 administrateur d\'équipe : invite aussi (ST2)', (await rpc(`assessment_campaign_invite('${K1}', '${mail(ST2)}')`)) === 'invited');
  await as(ST1);
  const inv = await rpc(`assessment_my_invitations()`);
  check('G28 candidat invité : voit l\'invitation (organisation, statut en attente)', inv.length === 1 && inv[0].campaign_id === K1 && inv[0].organization === 'Entreprise Une' && inv[0].status === 'en_attente_financement' && inv[0].requested === false);
  await as(CLI);
  check('G29 client non invité : aucune invitation', (await rpc(`assessment_my_invitations()`)).length === 0);
  await as(ST1);
  let r = await rpc(`assessment_request('soudure', 'ecrit', true, 'financee_organisation', null, '${K1}')`);
  check('G30 campagne non financée : aucune évaluation possible, rien d\'enregistré', r.ok === false && r.code === 'campaign_invalid' && (await qs(`select count(*)::int n from assessment_requests where campaign_id = '${K1}'`))[0].n === 0, JSON.stringify(r));

  // ouverture simulée (décision de financement du propriétaire : jeu de test)
  await sup();
  await db.exec(`update assessment_campaigns set status = 'ouverte' where id = '${K1}'`);
  await as(ST1);
  check('G31 campagne ouverte (simulée par le banc) : l\'invitation le montre', (await rpc(`assessment_my_invitations()`))[0].status === 'ouverte');
  await as(CLI);
  r = await rpc(`assessment_request('soudure', 'ecrit', true, 'financee_organisation', null, '${K1}')`);
  check('G32 client non invité : demande refusée', r.ok === false && r.code === 'campaign_invalid');
  await as(ST1);
  const qtBefore = await rpc(`assessment_quota()`);
  r = await rpc(`assessment_request('soudure', 'ecrit', true, 'financee_organisation', null, '${K1}')`);
  check('G33 candidat invité : demande financée par la campagne', r.ok === true && r.status === 'envoyee', JSON.stringify(r));
  const RQK = r.id;
  await as(ADM);
  await q(`select assessment_request_ack('${RQK}', 'acceptee')`);
  const RK = await rec(RQK, payloadOK);
  await as(ST1);
  check('G34 quota gratuit du candidat non consommé par une campagne', (await rpc(`assessment_quota()`)).remaining === qtBefore.remaining);
  await as(ORG);
  check('G35 organisation : voit le résultat partagé de SA campagne', (await q(`select count(*)::int n from assessment_results`))[0].n === 1 && (await q(`select count(*)::int n from assessment_requests`))[0].n === 1);
  let cr = await rpc(`assessment_campaign_results('${K1}')`);
  check('G36 résultats de campagne : candidat (prénom + initiale), compétences, limites, invités', cr.results.length === 1 && cr.results[0].candidate === 'Etu U.' && cr.results[0].limits && cr.invited === 2 && cr.results[0].reused === false, JSON.stringify(cr));
  await as(MEMA);
  check('G37 administrateur d\'équipe : voit les résultats partagés', (await rpc(`assessment_campaign_results('${K1}')`)).results.length === 1);
  await as(MEMV);
  check('G38 lecteur d\'équipe : ni demandes ni résultats (RLS)', (await q(`select (select count(*) from assessment_results) + (select count(*) from assessment_requests) n`))[0].n == 0);
  await fails('G39 lecteur d\'équipe : RPC des résultats refusée', `select assessment_campaign_results('${K1}')`, DENY);
  await as(MEMF);
  check('G40 finance d\'équipe : ni demandes ni résultats', (await q(`select (select count(*) from assessment_results) + (select count(*) from assessment_requests) n`))[0].n == 0);
  await as(ORG2);
  check('G41 autre organisation : aucun résultat, aucune demande, aucune invitation', (await q(`select (select count(*) from assessment_results) + (select count(*) from assessment_requests) + (select count(*) from assessment_campaign_invites) n`))[0].n == 0);
  await fails('G42 autre organisation : RPC des résultats refusée', `select assessment_campaign_results('${K1}')`, /Campagne introuvable/);
  await as(ST2);
  check('G43 autre candidat (invité) : ne voit ni la demande ni le résultat d\'ST1', (await q(`select (select count(*) from assessment_results where id = '${RK}') + (select count(*) from assessment_requests where id = '${RQK}') n`))[0].n == 0);
  await as(ORG);
  check('G44 les résultats non partagés de ST1 (résultat A, C…) restent invisibles de l\'organisation', (await q(`select count(*)::int n from assessment_results where id in ('${RA}', '${RC}')`))[0].n === 0);
  // retrait du partage
  await as(ST2);
  await fails('G45 un autre candidat ne retire pas le partage d\'autrui', `select assessment_share_set('${RQK}', false)`, /introuvable/);
  await as(ST1);
  check('G46 le candidat retire son accord de partage', (await rpc(`assessment_share_set('${RQK}', false)`)).share_with_org === false);
  await as(ORG);
  check('G47 partage retiré : l\'organisation ne voit plus ni demande ni résultat', (await q(`select (select count(*) from assessment_results) + (select count(*) from assessment_requests) n`))[0].n == 0 && (await rpc(`assessment_campaign_results('${K1}')`)).results.length === 0);
  await as(ST1);
  await q(`select assessment_share_set('${RQK}', true)`);
  await as(ORG);
  check('G48 partage rétabli : visible à nouveau', (await rpc(`assessment_campaign_results('${K1}')`)).results.length === 1);
  await as(ORG);
  check('G49 la liste de l\'organisation compte 1 résultat partagé pour la campagne', (await rpc(`assessment_campaigns_list()`)).find((x) => x.id === K1).shared_results === 1);
  await rpc(`assessment_campaign_close('${K1}')`).then(() => check('G50 organisation : clôture sa campagne', true), (e) => check('G50 clôture', false, e.message));
  await as(ST1);
  r = await rpc(`assessment_request('soudure', 'ecrit', true, 'financee_organisation', null, '${K1}')`);
  check('G51 campagne close : plus d\'évaluation', r.ok === false && r.code === 'campaign_invalid');
  await as(ORG);
  await fails('G52 campagne close : plus d\'invitation', `select assessment_campaign_invite('${K1}', '${mail(CLI)}')`, /close/);
  await as(ORG2);
  await fails('G53 autre organisation : ne ferme pas la campagne d\'autrui', `select assessment_campaign_close('${K1}')`, /Campagne introuvable/);
  await as(null, 'anon');
  for (const [n, sql] of [['résultats', `select assessment_campaign_results('${K1}')`], ['invitations', `select assessment_my_invitations()`], ['partage', `select assessment_share_set('${RQK}', true)`],
    ['clôture', `select assessment_campaign_close('${K1}')`], ['invite', `select assessment_campaign_invite('${K1}', 'a@b.cm')`]]) {
    await fails(`G54 anonyme : ${n} refusé`, sql, /permission denied|Connexion requise/i);
  }

  // ============================================================ H. Réutilisation d'une évaluation récente avec accord
  await as(ORG);
  const kr = await rpc(`assessment_campaign_create('Campagne plomberie (réutilisation)', 'plomberie', 'simulation')`);
  await q(`select assessment_campaign_invite('${kr.id}', '${mail(ST1)}')`);
  await sup();
  await db.exec(`update assessment_campaigns set status = 'ouverte' where id = '${kr.id}'`);
  await as(ST1);
  let opt = await rpc(`assessment_reuse_options('${kr.id}')`);
  check('H1 durée de validité absente : réutilisation indisponible (aucune valeur inventée)', opt.available === false && opt.reuse_days === null && opt.options.length === 0 && /pas encore été décidée/.test(opt.message), JSON.stringify(opt));
  r = await rpc(`assessment_reuse_grant('${RC}', '${kr.id}', true)`);
  check('H2 durée absente : partage refusé, rien enregistré', r.ok === false && r.code === 'reuse_unavailable' && (await qs(`select count(*)::int n from assessment_requests where reuse_of is not null`))[0].n === 0, JSON.stringify(r));
  for (const bad of ['"abc"', '0', '-5', '1.5', '{"days": "x"}', 'null']) {
    await sup();
    await db.exec(`delete from platform_settings where key = 'assessment.reuse_days'; insert into platform_settings (key, value) values ('assessment.reuse_days', '${bad}'::jsonb)`);
    await as(ST1);
    check(`H3 réglage invalide ${bad} : réutilisation indisponible`, (await rpc(`assessment_reuse_options('${kr.id}')`)).available === false);
  }
  await sup();
  await db.exec(`delete from platform_settings where key = 'assessment.reuse_days'; insert into platform_settings (key, value) values ('assessment.reuse_days', '{"days": 30}'::jsonb)`);
  await as(ST1);
  opt = await rpc(`assessment_reuse_options('${kr.id}')`);
  check('H4 durée décidée (banc : 30 jours) : le résultat récent est proposé', opt.available === true && opt.reuse_days === 30 && opt.options.length === 1 && opt.options[0].result_id === RC, JSON.stringify(opt));
  r = await rpc(`assessment_reuse_grant('${RC}', '${kr.id}', false)`);
  check('H5 sans accord explicite : refusé, rien enregistré', r.ok === false && r.code === 'consent_required' && (await qs(`select count(*)::int n from assessment_requests where reuse_of is not null`))[0].n === 0);
  await as(ORG);
  check('H6 avant l\'accord : l\'organisation ne voit pas le résultat', (await rpc(`assessment_campaign_results('${kr.id}')`)).results.length === 0 && (await q(`select count(*)::int n from assessment_results where id = '${RC}'`))[0].n === 0);
  await as(ST2);
  await fails('H7 autre candidat : ne partage pas le résultat d\'autrui', `select assessment_reuse_grant('${RC}', '${kr.id}', true)`, /introuvable/);
  await as(ST1);
  const quotaR = await rpc(`assessment_quota()`);
  r = await rpc(`assessment_reuse_grant('${RC}', '${kr.id}', true)`);
  check('H8 avec accord explicite : partage enregistré', r.ok === true && !!r.id, JSON.stringify(r));
  const RQR = r.id;
  check('H9 la réutilisation ne consomme pas le quota gratuit', (await rpc(`assessment_quota()`)).remaining === quotaR.remaining);
  r = await rpc(`assessment_reuse_grant('${RC}', '${kr.id}', true)`);
  check('H10 déjà partagé : refusé', r.ok === false && r.code === 'already_shared');
  check('H11 la demande de réutilisation trace le résultat d\'origine et l\'accord', (await qs(`select reuse_of is not null and reuse_consent and share_with_org and status = 'terminee' as ok, funding from assessment_requests where id = '${RQR}'`))[0].ok === true);
  check('H12 liste du candidat : la réutilisation apparaît avec le résultat', (await rpc(`assessment_my_list()`)).some((x) => x.id === RQR && x.reuse_of && x.result_id === RC));
  await as(ORG);
  cr = await rpc(`assessment_campaign_results('${kr.id}')`);
  check('H13 organisation : voit le résultat réutilisé (marqué « réutilisé ») après accord', cr.results.length === 1 && cr.results[0].reused === true && cr.results[0].result_id === RC);
  check('H14 organisation : lecture directe du résultat autorisée par RLS pour ce seul résultat', (await q(`select count(*)::int n from assessment_results`))[0].n === 2 && (await q(`select count(*)::int n from assessment_results where id = '${RA}'`))[0].n === 0);
  await as(ORG2);
  check('H15 autre organisation : ne voit rien', (await q(`select count(*)::int n from assessment_results`))[0].n === 0);
  await as(MEMV);
  check('H16 lecteur d\'équipe : ne voit pas le résultat réutilisé', (await q(`select count(*)::int n from assessment_results`))[0].n === 0);
  await as(ST1);
  await fails('H17 le candidat ne révoque pas la demande d\'un autre', `select assessment_reuse_revoke('${RQK}')`, /introuvable/);
  check('H18 révocation de l\'accord', (await rpc(`assessment_reuse_revoke('${RQR}')`)).ok === true && (await qs(`select status, share_with_org, reuse_consent from assessment_requests where id = '${RQR}'`))[0].status === 'annulee');
  await as(ORG);
  check('H19 accord révoqué : l\'organisation ne voit plus le résultat', (await rpc(`assessment_campaign_results('${kr.id}')`)).results.length === 0 && (await q(`select count(*)::int n from assessment_results where id = '${RC}'`))[0].n === 0);
  await as(ST1);
  check('H20 nouvel accord possible après révocation', (await rpc(`assessment_reuse_grant('${RC}', '${kr.id}', true)`)).ok === true);
  await as(ORG);
  check('H21 de nouveau visible', (await rpc(`assessment_campaign_results('${kr.id}')`)).results.length === 1);
  await as(ST1);
  r = await rpc(`assessment_reuse_grant('${RA}', '${kr.id}', true)`);
  check('H22 résultat d\'une autre famille : refusé (famille et mode de la campagne)', r.ok === false && r.code === 'mismatch');
  r = await rpc(`assessment_reuse_grant('${RC}', '${id(98)}', true)`);
  check('H23 campagne inconnue : refusé', r.ok === false && r.code === 'campaign_invalid');
  await as(ST2);
  const rqI = await mkReq(ST2, 'plomberie', 'simulation');
  await as(ADM);
  const RI = await rec(rqI, payloadOK);
  await as(ST2);
  r = await rpc(`assessment_reuse_grant('${RI}', '${kr.id}', true)`);
  check('H24 candidat non invité : refusé', r.ok === false && r.code === 'campaign_invalid');
  await sup();
  await db.exec(`update assessment_results set created_at = now() - interval '45 days' where id = '${RI}'; insert into assessment_campaign_invites (campaign_id, candidate_id) values ('${kr.id}', '${ST2}')`);
  await as(ST2);
  r = await rpc(`assessment_reuse_grant('${RI}', '${kr.id}', true)`);
  check('H25 évaluation plus ancienne que la durée décidée : refusée', r.ok === false && r.code === 'too_old' && r.reuse_days === 30, JSON.stringify(r));
  check('H26 options : l\'évaluation trop ancienne n\'est pas proposée', (await rpc(`assessment_reuse_options('${kr.id}')`)).options.length === 0);
  await sup();
  await db.exec(`update assessment_results set created_at = now() - interval '29 days' where id = '${RI}'`);
  await as(ST2);
  check('H27 29 jours (< 30) : acceptée', (await rpc(`assessment_reuse_grant('${RI}', '${kr.id}', true)`)).ok === true);
  await as(CLI);
  r = await rpc(`assessment_reuse_grant('${RC}', '${kr.id}', true)`).catch((e) => ({ err: e.message }));
  check('H28 client sans résultat : refusé', !!r.err || r.ok === false, JSON.stringify(r));
  await as(null, 'anon');
  await fails('H29 anonyme : options refusées', `select assessment_reuse_options('${kr.id}')`, /permission denied|Connexion requise/i);
  await fails('H30 anonyme : partage refusé', `select assessment_reuse_grant('${RC}', '${kr.id}', true)`, /permission denied|Connexion requise/i);
  await fails('H31 anonyme : révocation refusée', `select assessment_reuse_revoke('${RQR}')`, /permission denied|Connexion requise/i);
  await sup();
  await db.exec(`delete from platform_settings where key = 'assessment.reuse_days'`);
  await as(ST1);
  check('H32 réglage supprimé : indisponible de nouveau', (await rpc(`assessment_reuse_options('${kr.id}')`)).available === false);

  // ============================================================ I. Correspondance catalogue - familles
  const dom = (await qs(`select id from skill_catalog where domain = 'Informatique' and job = '' and skill = ''`))[0].id;
  const dom2 = (await qs(`select id from skill_catalog where domain = 'Génie civil' and job = '' and skill = ''`))[0].id;
  await sup();
  const prop = (await qs(`insert into skill_catalog (domain, job, skill, status) values ('Domaine proposé', '', '', 'proposed') returning id`))[0].id;
  check('I1 livraison : la correspondance est vide (aucune ligne inventée)', (await qs(`select count(*)::int n from assessment_family_skill_map`))[0].n === 0);
  await as(ST1);
  check('I2 lecture : vide au départ', (await rpc(`assessment_family_map()`)).length === 0);
  await fails('I3 étudiant : écriture refusée', `select assessment_family_map_set('${dom}', 'informatique_developpement', true)`, ADMIN_ONLY);
  await fails('I4 étudiant : écriture directe refusée', `insert into assessment_family_skill_map (catalog_id, family_code) values ('${dom}', 'data_ia')`, /permission denied/i);
  await as(ORG);
  await fails('I5 organisation : écriture refusée', `select assessment_family_map_set('${dom}', 'informatique_developpement', true)`, ADMIN_ONLY);
  await as(TECH);
  await fails('I6 agent technique : écriture refusée (administrateur global seulement)', `select assessment_family_map_set('${dom}', 'informatique_developpement', true)`, ADMIN_ONLY);
  await as(null, 'anon');
  await fails('I7 anonyme : lecture refusée', `select assessment_family_map()`, /permission denied|Connexion requise/i);
  await fails('I8 anonyme : table refusée', `select * from assessment_family_skill_map`, /permission denied/i);
  await as(ADM);
  await works('I9 administrateur : rattache « Informatique » à deux familles', `select assessment_family_map_set('${dom}', 'informatique_developpement', true), assessment_family_map_set('${dom}', 'data_ia', true)`);
  await works('I10 rattachement répété sans effet', `select assessment_family_map_set('${dom}', 'data_ia', true)`);
  await works('I11 « Génie civil » rattaché à BTP', `select assessment_family_map_set('${dom2}', 'btp_genie_civil', true)`);
  await fails('I12 entrée proposée (non validée) : refusée', `select assessment_family_map_set('${prop}', 'data_ia', true)`, /validée/);
  await fails('I13 famille inconnue refusée', `select assessment_family_map_set('${dom}', 'famille_x', true)`, /Famille inconnue/);
  await fails('I14 entrée inconnue refusée', `select assessment_family_map_set('${id(97)}', 'data_ia', true)`, /introuvable/);
  const un = await rpc(`assessment_family_map_unmapped()`);
  check('I15 contrôle : domaines validés encore sans famille listés (Informatique et Génie civil n\'y sont plus)', un.length > 0 && !un.some((x) => x.domain === 'Informatique' || x.domain === 'Génie civil') && !un.some((x) => x.domain === 'Domaine proposé'));
  await as(ST1);
  const mp = await rpc(`assessment_family_map('data_ia')`);
  check('I16 lecture filtrée par famille', mp.length === 1 && mp[0].domain === 'Informatique' && mp[0].family_code === 'data_ia');
  check('I17 lecture complète : 3 lignes', (await rpc(`assessment_family_map()`)).length === 3);
  await fails('I18 étudiant : contrôle des orphelins refusé', `select assessment_family_map_unmapped()`, ADMIN_ONLY);
  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${ADM2FA}', 'verified')`);
  await asAal(ADM2FA, 'aal1');
  await fails('I19 administrateur 2FA en session aal1 : écriture refusée', `select assessment_family_map_set('${dom2}', 'architecture_construction', true)`, /double authentification/);
  await as(ADM);
  await works('I20 retrait d\'un rattachement', `select assessment_family_map_set('${dom}', 'data_ia', false)`);
  check('I21 après retrait : 2 lignes', (await qs(`select count(*)::int n from assessment_family_skill_map`))[0].n === 2);
  check('I22 journal d\'audit des rattachements', (await qs(`select count(*)::int n from audit_log where category = 'Évaluations' and action like 'Correspondance catalogue%'`))[0].n >= 4);

  // ============================================================ J. Anonyme : toutes les RPC de ce lot refusées
  await as(null, 'anon');
  for (const [n, sql] of [['file évaluateur', `select assessment_review_queue()`], ['validation', `select assessment_human_validate('${RA}', 'validee_humainement', 'Geste observé en atelier')`],
    ['contestation', `select assessment_dispute_handle('${DID}', 'take')`], ['création campagne', `select assessment_campaign_create('x y', 'soudure', 'ecrit')`],
    ['liste campagnes', `select assessment_campaigns_list()`]]) {
    await fails(`J1 anonyme : ${n} refusé`, sql, /permission denied|Connexion requise/i);
  }
  for (const t of ['assessment_family_skill_map', 'assessment_campaigns', 'assessment_results', 'assessment_requests', 'assessment_disputes']) {
    await fails(`J2 anonyme : lecture de ${t} refusée`, `select * from ${t}`, /permission denied/i);
  }

  // ============================================================ K. Rejeu des migrations sans effet de bord
  await sup();
  const before = await snapshot();
  const modesBefore = (await qs(`select count(*)::int n from assessment_campaigns where status = 'en_attente_financement'`))[0].n;
  const fs = await import('fs'); const path = await import('path'); const { fileURLToPath } = await import('url');
  const dir = path.dirname(fileURLToPath(import.meta.url));
  for (const f of ['20261125095000_h9_eval_socle_fournisseur_agnostique.sql', '20261125096000_h9_eval_validation_humaine_contestations.sql', '20261125096100_h9_eval_campagnes_organisation_reutilisation.sql', '20261125096200_h9_eval_correspondance_catalogue_familles.sql']) {
    try { await db.exec(fs.readFileSync(path.join(dir, '..', '..', 'migrations', f), 'utf8')); check(`K1 rejeu sans erreur : ${f.slice(0, 14)}`, true); } catch (e) { check(`K1 rejeu sans erreur : ${f.slice(0, 14)}`, false, e.message); }
  }
  const after = await snapshot();
  check('K2 rejeu : aucune ligne ajoutée, supprimée ni dupliquée ; politiques, fonctions et déclencheurs identiques', JSON.stringify(before) === JSON.stringify(after), JSON.stringify([before, after]));
  check('K3 rejeu : statuts de campagne et décisions humaines conservés', (await qs(`select count(*)::int n from assessment_campaigns where status = 'en_attente_financement'`))[0].n === modesBefore
    && (await qs(`select count(*)::int n from assessment_results where validation_status in ('validee_humainement', 'non_verifiable_a_distance')`))[0].n === 3);
  check('K4 rejeu : la permission reste unique et hors jeux par défaut', Number(after.perm) === 1 && (await qs(`select count(*)::int n from (select unnest(_admin_team_defaults(t)) p from unnest(array['finance','support','security','tech']) t) x where p = 'tech.assessments'`))[0].n === 0);
  await as(REV);
  check('K5 rejeu : l\'évaluateur garde sa file (permission inchangée)', (await rpc(`assessment_review_queue()`)).disputes.length === 0);

  console.log(`h9_evaluation_suite : ${ok} OK, ${ko} ECHEC`);
  console.log(`${ok}/${ok + ko}`);
}
