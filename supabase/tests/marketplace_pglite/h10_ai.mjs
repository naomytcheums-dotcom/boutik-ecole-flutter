// Lot H10 / AI : socle IA fournisseur-agnostique (migrations 20261126030000, 20261126030100, 20261126030200).
// Prouve : registre VIDE à la livraison ; activation réservée à l'administrateur (2FA, audit) et refusée sans test réussi ; un seul fournisseur actif par capacité ;
// traduction : appartenance à la conversation, « not_configured » sans fournisseur (jamais un texte), cache, écriture réservée au service ;
// consentement audio/vidéo révocable ; file de transcription « en attente de fournisseur » ; kela_context limité au compte connecté ;
// agents « non actif » ; confirmation humaine des actions sensibles ; anonyme refusé ; isolation entre comptes ; rejeu des migrations.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h10_ai.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000103${String(n).padStart(2, '0')}`;
  const ADM = id(1), ADM2FA = id(2), U1 = id(3), U2 = id(4), U3 = id(5), TECH = id(6);
  const mail = (uid) => `u${uid.slice(-2)}@t.cm`;
  let cur = null;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { cur = { uid }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims({})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const asAal = async (uid, aal) => { cur = { uid }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false), set_config('request.jwt.claim.role', '', false), ${claims({ sub: uid, aal })}; set role authenticated`); };
  const svc = async () => { cur = { svc: true }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', 'service_role', false), ${claims({ role: 'service_role' })}; set role service_role`); };
  const sup = async () => { cur = null; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save?.uid) await as(save.uid); else if (save?.svc) await svc(); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const jq = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;
  const ADMIN_ONLY = /Réservé|Accès refusé|Connexion requise|permission denied/i;
  const snapshot = async () => (await qs(`select
      (select count(*) from ai_providers) p, (select count(*) from ai_provider_tests) t, (select count(*) from ai_translations) tr, (select count(*) from ai_consents) c,
      (select count(*) from ai_consent_history) h, (select count(*) from ai_transcription_jobs) j, (select count(*) from ai_agents) a, (select count(*) from ai_action_log) l,
      (select count(*) from pg_policies where tablename like 'ai\\_%') pol, (select count(*) from pg_proc where proname like 'ai\\_%' or proname like '\\_ai\\_%' or proname in ('kela_context', 'translate_request', 'translate_store') or proname like 'transcription\\_%') fn,
      (select count(*) from pg_trigger where tgname like 'trg\\_ai\\_%') trg`))[0];

  // ============================================================ comptes + conversation
  await db.exec('reset role');
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [ADM2FA, 'Mfa Admin', 'admin'], [U1, 'Util Un', 'student'], [U2, 'Util Deux', 'client'], [U3, 'Util Trois', 'client'], [TECH, 'Tech Agent', 'support']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }
  const CONV = (await q(`insert into conversations (created_by) values ('${U1}') returning id`))[0].id;
  const CONV3 = (await q(`insert into conversations (created_by) values ('${U3}') returning id`))[0].id;
  await db.exec(`insert into conversation_participants (conversation_id, user_id) values ('${CONV}', '${U1}'), ('${CONV}', '${U2}'), ('${CONV3}', '${U3}')`);
  const M1 = (await q(`insert into messages (conversation_id, sender_id, body) values ('${CONV}', '${U1}', 'Bonjour, le devis est prêt.') returning id`))[0].id;
  const M3 = (await q(`insert into messages (conversation_id, sender_id, body) values ('${CONV3}', '${U3}', 'Message privé de la conversation 3') returning id`))[0].id;
  await db.exec(`insert into notifications (user_id, kind, title) values ('${U1}', 'x', 'n1'), ('${U1}', 'x', 'n2'), ('${U2}', 'x', 'n3')`);

  // ============================================================ A. Livraison : rien d'inventé
  const s0 = await snapshot();
  check('A1 livraison : registre des fournisseurs, tests, traductions, consentements, transcriptions, actions : VIDES', ['p', 't', 'tr', 'c', 'h', 'j', 'l'].every((k) => Number(s0[k]) === 0), JSON.stringify(s0));
  check('A2 livraison : 20 agents déclarés, tous « non_actif »', Number(s0.a) === 20 && (await qs(`select count(*)::int n from ai_agents where status <> 'non_actif'`))[0].n === 0);
  check('A3 les 5 capacités du serveur', (await qs(`select ai_capabilities() c`))[0].c.join() === 'chat,translate_text,stt,tts,vision');
  check('A4 aucune clé ni réglage « ai.* » inventé dans les paramètres', (await qs(`select count(*)::int n from platform_settings where key like 'ai.%'`))[0].n === 0);

  // ============================================================ B. Anonyme refusé partout
  await as(null);
  for (const [n, sql] of [
    ['translate_request', `select translate_request(${M1}, 'en')`], ['kela_context', `select kela_context()`], ['ai_capability_status', `select ai_capability_status()`],
    ['ai_consent_set', `select ai_consent_set('transcription', true)`], ['ai_consent_my', `select ai_consent_my()`], ['transcription_request', `select transcription_request('message_vocal')`],
    ['transcription_my_list', `select transcription_my_list()`], ['ai_agents_list', `select ai_agents_list()`], ['ai_action_propose', `select ai_action_propose('talent', 'resume')`],
    ['ai_action_my_list', `select ai_action_my_list()`], ['ai_provider_register', `select ai_provider_register('chat', 'x_prov', 'X')`], ['ai_agent_set_status', `select ai_agent_set_status('talent', 'actif')`]]) {
    await fails(`B1 anonyme : ${n} refusé`, sql, /permission denied|Connexion requise/i);
  }
  for (const t of ['ai_providers', 'ai_provider_tests', 'ai_translations', 'ai_consents', 'ai_consent_history', 'ai_transcription_jobs', 'ai_agents', 'ai_action_log']) {
    await fails(`B2 anonyme : lecture de ${t} refusée`, `select * from ${t}`, /permission denied/i);
  }

  // ============================================================ C. Registre : administration, 2FA, test obligatoire
  for (const [who, uid] of [['étudiant', U1], ['agent technique', TECH]]) {
    await as(uid);
    await fails(`C1 ${who} : enregistrement d'un fournisseur refusé`, `select ai_provider_register('translate_text', 'trad_a', 'Traducteur A')`, ADMIN_ONLY);
    await fails(`C2 ${who} : activation refusée`, `select ai_provider_set_status('translate_text', 'trad_a', 'actif')`, ADMIN_ONLY);
    await fails(`C3 ${who} : liste d'administration refusée`, `select ai_providers_admin_list()`, ADMIN_ONLY);
  }
  await as(ADM);
  await fails('C4 capacité inconnue refusée', `select ai_provider_register('hologramme', 'trad_a', 'Traducteur A')`, /Capacité inconnue/);
  await fails('C5 code invalide refusé', `select ai_provider_register('translate_text', 'A B', 'Traducteur A')`, /Code fournisseur invalide/);
  await works('C6 enregistrement : candidat', `select ai_provider_register('translate_text', 'trad_a', 'Traducteur A (banc)')`);
  await fails('C7 activation REFUSÉE sans test d\'intégration enregistré', `select ai_provider_set_status('translate_text', 'trad_a', 'actif')`, /aucun test d'intégration réussi/);
  await q(`select ai_provider_record_test('translate_text', 'trad_a', false, 'appel de test échoué (banc)')`);
  await fails('C8 activation REFUSÉE après un test échoué', `select ai_provider_set_status('translate_text', 'trad_a', 'actif')`, /aucun test d'intégration réussi/);
  check('C9 un test enregistré fait passer « candidat » à « en_test »', (await qs(`select status from ai_providers where code = 'trad_a'`))[0].status === 'en_test');
  await fails('C10 statut inconnu refusé', `select ai_provider_set_status('translate_text', 'trad_a', 'magique')`, /Statut de fournisseur inconnu/);
  await fails('C11 test sur un fournisseur inexistant refusé', `select ai_provider_record_test('translate_text', 'absent', true, '')`, /introuvable/);
  check('C12 le journal d\'audit trace les opérations d\'administration', (await qs(`select count(*)::int n from audit_log where category = 'Intelligence artificielle'`))[0].n === 2);
  check('C13 aucune activation en base : le registre ne contient aucun fournisseur actif', (await qs(`select count(*)::int n from ai_providers where status = 'actif'`))[0].n === 0);

  await sup();
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${ADM2FA}', 'verified')`);
  await asAal(ADM2FA, 'aal1');
  await fails('C14 administrateur 2FA en session aal1 : enregistrement refusé', `select ai_provider_register('chat', 'chat_a', 'Chat A')`, /double authentification/);
  await fails('C15 administrateur 2FA en session aal1 : test refusé', `select ai_provider_record_test('translate_text', 'trad_a', true, 'ok')`, /double authentification/);
  await fails('C16 administrateur 2FA en session aal1 : activation d\'agent refusée', `select ai_agent_set_status('talent', 'actif')`, /double authentification/);
  await asAal(ADM2FA, 'aal2');
  await works('C17 administrateur 2FA en session aal2 : enregistrement accepté', `select ai_provider_register('chat', 'chat_a', 'Chat A (banc)')`);
  check('C18 la liste d\'administration contient 2 fournisseurs, dernier test visible', (await rpc(`ai_providers_admin_list()`)).length === 2);

  // ============================================================ D. Traduction : pas de fournisseur => not_configured ; appartenance ; cache ; service
  await as(U1);
  let r = await rpc(`translate_request(${M1}, 'en')`);
  check('D1 aucun fournisseur actif : statut « not_configured », AUCUN texte', r.status === 'not_configured' && !('text' in r), JSON.stringify(r));
  check('D2 ai_capability_status : toutes les capacités à false, aucun nom de fournisseur', Object.values(await rpc(`ai_capability_status()`)).every((v) => v === false));
  await as(U3);
  await fails('D3 non-participant : message d\'une autre conversation refusé', `select translate_request(${M1}, 'en')`, /Message introuvable/);
  await fails('D4 message inexistant : même réponse que D3 (pas de fuite)', `select translate_request(99999999, 'en')`, /Message introuvable/);
  await as(U1);
  await fails('D5 le participant ne lit pas les messages d\'une conversation étrangère', `select translate_request(${M3}, 'en')`, /Message introuvable/);
  await fails('D6 langue cible invalide refusée', `select translate_request(${M1}, 'x; drop')`, /Langue cible invalide/);
  await fails('D7 langue cible vide refusée', `select translate_request(${M1}, '')`, /Langue cible invalide/);

  await as(ADM);
  await q(`select ai_provider_record_test('translate_text', 'trad_a', true, 'appel de test réussi (faux serveur local)')`);
  await works('D8 activation acceptée avec un test réussi enregistré', `select ai_provider_set_status('translate_text', 'trad_a', 'actif')`);
  await q(`select ai_provider_register('translate_text', 'trad_b', 'Traducteur B')`);
  await q(`select ai_provider_record_test('translate_text', 'trad_b', true, 'ok')`);
  await fails('D9 un second fournisseur actif pour la même capacité est refusé', `select ai_provider_set_status('translate_text', 'trad_b', 'actif')`, /déjà actif/);
  await q(`select ai_provider_register('stt', 'stt_a', 'Transcripteur A')`);
  await fails('D10 un fournisseur d\'une autre capacité ne s\'active pas sans son propre test', `select ai_provider_set_status('stt', 'stt_a', 'actif')`, /aucun test d'intégration réussi/);
  check('D11 audit : activation journalisée au niveau Critique', (await qs(`select count(*)::int n from audit_log where category = 'Intelligence artificielle' and level = 'Critique'`))[0].n === 1);

  await as(U1);
  r = await rpc(`translate_request(${M1}, 'EN')`);
  check('D12 fournisseur actif : « pending » avec le texte du message (participant) et le fournisseur', r.status === 'pending' && r.text === 'Bonjour, le devis est prêt.' && r.provider === 'trad_a' && r.target_lang === 'en', JSON.stringify(r));
  check('D13 ai_capability_status : translate_text = true, chat = false', (await rpc(`ai_capability_status()`)).translate_text === true && (await rpc(`ai_capability_status()`)).chat === false);
  await fails('D14 translate_store refusé à un utilisateur', `select translate_store('${U1}', ${M1}, 'en', 'fr', 'trad_a', 'Hello, the quote is ready.')`, /permission denied|Réservé/i);
  await as(null);
  await fails('D15 translate_store refusé à l\'anonyme', `select translate_store('${U1}', ${M1}, 'en', 'fr', 'trad_a', 'x')`, /permission denied/i);
  await svc();
  await fails('D16 service : utilisateur hors conversation refusé', `select translate_store('${U3}', ${M1}, 'en', 'fr', 'trad_a', 'Hello')`, /Message introuvable/);
  await fails('D17 service : fournisseur non actif refusé', `select translate_store('${U1}', ${M1}, 'en', 'fr', 'trad_b', 'Hello')`, /Aucun fournisseur de traduction actif/);
  await fails('D18 service : traduction vide refusée', `select translate_store('${U1}', ${M1}, 'en', 'fr', 'trad_a', '   ')`, /vide/);
  await works('D19 service : enregistrement de la traduction', `select translate_store('${U1}', ${M1}, 'en', 'fr', 'trad_a', 'Hello, the quote is ready.')`);
  await as(U2);
  r = await rpc(`translate_request(${M1}, 'en')`);
  check('D20 l\'autre participant reçoit le cache (« translated », texte, cached)', r.status === 'translated' && r.text === 'Hello, the quote is ready.' && r.cached === true, JSON.stringify(r));
  check('D21 le participant lit la traduction en cache (RLS)', (await q(`select count(*)::int n from ai_translations`))[0].n === 1);
  await as(U3);
  check('D22 isolation : un non-participant ne voit aucune traduction', (await q(`select count(*)::int n from ai_translations`))[0].n === 0);
  await fails('D23 un non-participant ne lit pas le cache via la RPC', `select translate_request(${M1}, 'en')`, /Message introuvable/);
  await fails('D24 écriture directe dans le cache refusée', `insert into ai_translations (message_id, target_lang, provider_code, body) values (${M1}, 'de', 'trad_a', 'Hallo')`, /permission denied/i);
  await as(ADM);
  await q(`select ai_provider_record_test('translate_text', 'trad_a', false, 'régression')`);
  check('D25 un test échoué suspend le fournisseur actif', (await qs(`select status from ai_providers where code = 'trad_a'`))[0].status === 'suspendu');
  await as(U2);
  r = await rpc(`translate_request(${M1}, 'de')`);
  check('D26 fournisseur suspendu : de nouveau « not_configured »', r.status === 'not_configured', JSON.stringify(r));

  // ============================================================ E. Consentement révocable et file de transcription
  await as(U1);
  check('E1 aucun consentement accordé par défaut', Object.values(await rpc(`ai_consent_my()`)).every((v) => v === false));
  await fails('E2 transcription refusée sans consentement', `select transcription_request('message_vocal', 'audio-1')`, /Consentement à la transcription requis/);
  await q(`select ai_consent_set('transcription', true)`);
  await fails('E3 transcription refusée sans consentement à l\'enregistrement', `select transcription_request('message_vocal', 'audio-1')`, /Consentement à l'enregistrement requis/);
  await fails('E4 type de consentement inconnu refusé', `select ai_consent_set('espionnage', true)`, /Type de consentement inconnu/);
  await q(`select ai_consent_set('enregistrement_audio', true)`);
  r = await rpc(`transcription_request('message_vocal', 'audio-1', 'fr')`);
  check('E5 sans fournisseur « stt » actif : « en_attente_fournisseur », aucun texte', r.status === 'en_attente_fournisseur', JSON.stringify(r));
  const J1 = r.id;
  await fails('E6 appel vidéo : le consentement vidéo manque', `select transcription_request('appel_video', 'v-1')`, /Consentement à l'enregistrement requis/);
  await fails('E7 source inconnue refusée', `select transcription_request('espion')`, /Source inconnue/);
  await fails('E8 langue invalide refusée', `select transcription_request('message_vocal', 'a', 'fr; --')`, /Langue invalide/);
  let list = await rpc(`transcription_my_list()`);
  check('E9 la liste montre la demande en attente, sans texte', list.length === 1 && list[0].status === 'en_attente_fournisseur' && list[0].result_text === null);
  await as(U2);
  check('E10 isolation : U2 ne voit pas les demandes de U1', (await rpc(`transcription_my_list()`)).length === 0 && (await q(`select count(*)::int n from ai_transcription_jobs`))[0].n === 0);
  await fails('E11 U2 ne peut pas annuler la demande de U1', `select transcription_cancel('${J1}')`, /introuvable/);
  await fails('E12 U2 ne peut pas supprimer la demande de U1', `select transcription_delete('${J1}')`, /introuvable/);
  check('E13 isolation : U2 ne voit pas les consentements de U1', (await q(`select count(*)::int n from ai_consents`))[0].n === 0 && (await q(`select count(*)::int n from ai_consent_history`))[0].n === 0);
  await as(U1);
  await q(`select ai_consent_set('enregistrement_video', true)`);
  const J2 = (await rpc(`transcription_request('appel_video', 'v-1')`)).id;
  r = await rpc(`ai_consent_set('enregistrement_audio', false)`);
  check('E14 révoquer l\'audio annule les demandes audio en attente (1), pas la vidéo', r.cancelled_jobs === 1
    && (await qs(`select status from ai_transcription_jobs where id = '${J1}'`))[0].status === 'annulee' && (await qs(`select status from ai_transcription_jobs where id = '${J2}'`))[0].status === 'en_attente_fournisseur');
  await fails('E15 après révocation, nouvelle demande audio refusée', `select transcription_request('message_vocal', 'audio-2')`, /Consentement à l'enregistrement requis/);
  r = await rpc(`ai_consent_set('transcription', false)`);
  check('E16 révoquer la transcription annule le reste', r.cancelled_jobs === 1 && (await qs(`select status from ai_transcription_jobs where id = '${J2}'`))[0].status === 'annulee');
  check('E17 le consentement révoqué garde sa date de révocation', (await q(`select revoked_at is not null r, granted from ai_consents where kind = 'transcription'`))[0].r === true);
  await fails('E18 l\'historique est en ajout seul (suppression refusée)', `delete from ai_consent_history`, /permission denied/i);
  await sup();
  await fails('E19 l\'historique est en ajout seul même pour le superutilisateur (déclencheur)', `update ai_consent_history set granted = true`, /ajout seul/);
  check('E20 historique : 5 lignes (3 accords, 2 révocations)', (await qs(`select count(*)::int n from ai_consent_history where user_id = '${U1}'`))[0].n === 5);

  // Fournisseur stt actif : la file passe à « en_file » ; seul le service enregistre un résultat
  await as(ADM);
  await q(`select ai_provider_record_test('stt', 'stt_a', true, 'ok (faux serveur local)')`);
  await q(`select ai_provider_set_status('stt', 'stt_a', 'actif')`);
  await as(U1);
  await q(`select ai_consent_set('transcription', true)`);
  await q(`select ai_consent_set('enregistrement_audio', true)`);
  const J3 = (await rpc(`transcription_request('appel_audio', 'a-1')`)).id;
  check('E21 fournisseur « stt » actif : la demande passe « en_file »', (await qs(`select status from ai_transcription_jobs where id = '${J3}'`))[0].status === 'en_file');
  await fails('E22 un utilisateur ne peut pas enregistrer de résultat', `select transcription_job_ack('${J3}', 'terminee', 'stt_a', 'Bonjour')`, /permission denied|Réservé/i);
  await svc();
  await fails('E23 service : résultat refusé d\'un fournisseur non actif', `select transcription_job_ack('${J3}', 'terminee', 'stt_x', 'Bonjour')`, /Aucun fournisseur de transcription actif/);
  await fails('E24 service : transcription vide refusée', `select transcription_job_ack('${J3}', 'terminee', 'stt_a', ' ')`, /vide/);
  await works('E25 service : résultat enregistré', `select transcription_job_ack('${J3}', 'terminee', 'stt_a', 'Bonjour à tous')`);
  await fails('E26 service : une demande terminée ne se ré-écrit pas', `select transcription_job_ack('${J3}', 'terminee', 'stt_a', 'Autre')`, /déjà traitée/);
  await as(U1);
  check('E27 le propriétaire lit sa transcription', (await rpc(`transcription_my_list()`)).find((x) => x.id === J3)?.result_text === 'Bonjour à tous');
  await works('E28 conservation : le propriétaire supprime sa transcription', `select transcription_delete('${J3}')`);
  check('E29 transcription supprimée', (await q(`select count(*)::int n from ai_transcription_jobs where id = '${J3}'`))[0].n === 0);
  const J4 = (await rpc(`transcription_request('appel_audio', 'a-2')`)).id;
  await works('E30 annulation par le propriétaire', `select transcription_cancel('${J4}')`);
  await fails('E31 annulation d\'une demande déjà annulée refusée', `select transcription_cancel('${J4}')`, /introuvable|déjà traitée/);
  const J5 = (await rpc(`transcription_request('appel_audio', 'a-3')`)).id;
  await q(`select ai_consent_set('transcription', false)`);
  await svc();
  await fails('E32 service : demande annulée par révocation, résultat refusé', `select transcription_job_ack('${J5}', 'terminee', 'stt_a', 'texte')`, /déjà traitée|annulée/);
  await as(U1);
  await q(`select ai_consent_set('clonage_vocal', true)`);
  check('E33 clonage vocal : seul le consentement explicite s\'enregistre (aucune fonction ne l\'exploite)', (await rpc(`ai_consent_my()`)).clonage_vocal === true
    && (await qs(`select count(*)::int n from pg_proc where prosrc ilike '%clonage_vocal%' and proname not in ('ai_consent_set', 'ai_consent_my')`))[0].n === 0);

  // ============================================================ F. kela_context : le compte connecté seulement
  await as(U1);
  let ctx = await rpc(`kela_context()`);
  check('F1 kela_context : nom, rôle, compteurs du compte U1', ctx.user_id === U1 && ctx.name === 'Util Un' && ctx.role === 'student' && ctx.unread_notifications === 2 && ctx.conversations === 1, JSON.stringify(ctx));
  await as(U2);
  ctx = await rpc(`kela_context()`);
  check('F2 isolation : U2 ne reçoit que ses données (ses notifications, rôle client)', ctx.user_id === U2 && ctx.unread_notifications === (await qs(`select count(*)::int n from notifications where user_id = '${U2}' and read_at is null`))[0].n && ctx.unread_notifications >= 1 && ctx.role === 'client' && ctx.pending_transcriptions === 0, JSON.stringify(ctx));
  check('F3 aucune donnée d\'un autre compte dans le contexte (pas de nom, d\'e-mail ni d\'identifiant étranger)', !JSON.stringify(ctx).includes('Util Un') && !JSON.stringify(ctx).includes(U1) && !JSON.stringify(ctx).includes('@'));
  check('F4 kela_context ne prend aucun paramètre « utilisateur »', (await qs(`select pronargs from pg_proc where proname = 'kela_context'`))[0].pronargs === 0);
  check('F5 le contexte annonce les capacités sans fournisseur actif (chat = false)', ctx.capabilities.chat === false);

  // ============================================================ G. Agents « non actif » et confirmation humaine
  await as(U1);
  const agents = await rpc(`ai_agents_list()`);
  check('G1 la liste des agents : 20, tous non actifs', agents.length === 20 && agents.every((a) => a.status === 'non_actif'));
  await fails('G2 un agent non actif ne propose aucune action', `select ai_action_propose('talent', 'resume_profil')`, /Agent non actif/);
  await fails('G3 un utilisateur ne peut pas activer un agent', `select ai_agent_set_status('talent', 'actif')`, ADMIN_ONLY);
  await fails('G4 écriture directe dans le catalogue refusée', `update ai_agents set status = 'actif'`, /permission denied/i);
  await as(ADM);
  await fails('G5 activation d\'un agent REFUSÉE sans fournisseur « chat » actif', `select ai_agent_set_status('talent', 'actif')`, /aucun fournisseur de conversation/);
  await q(`select ai_provider_record_test('chat', 'chat_a', true, 'ok (faux serveur local)')`);
  await q(`select ai_provider_set_status('chat', 'chat_a', 'actif')`);
  await works('G6 activation d\'un agent (chat actif, administrateur)', `select ai_agent_set_status('talent', 'actif')`);
  await fails('G7 agent inconnu refusé', `select ai_agent_set_status('magicien', 'actif')`, /Agent introuvable/);
  await as(U1);
  r = await rpc(`ai_action_propose('talent', 'resume_profil', ${jq({ cible: 'mon profil' })})`);
  check('G8 action non sensible : « autorisee » d\'emblée, journalisée', r.status === 'autorisee' && r.sensitive === false, JSON.stringify(r));
  const A1 = r.id;
  r = await rpc(`ai_action_propose('talent', 'paiement', ${jq({ montant: 5000 })}, false)`);
  check('G9 « paiement » est sensible même si l\'agent déclare le contraire : attend la confirmation humaine', r.status === 'en_attente_confirmation' && r.sensitive === true, JSON.stringify(r));
  const A2 = r.id;
  r = await rpc(`ai_action_propose('talent', 'brouillon', '{}', true)`);
  check('G10 action déclarée sensible : attend la confirmation', r.status === 'en_attente_confirmation');
  const A3 = r.id;
  await fails('G11 inconnu : agent introuvable', `select ai_action_propose('fantome', 'x1')`, /Agent introuvable/);
  await svc();
  await fails('G12 l\'orchestrateur ne peut pas exécuter une action sensible non confirmée', `select ai_action_record_result('${A2}', true, 'fait')`, /Exécution sans autorisation refusée/);
  await works('G13 l\'orchestrateur enregistre l\'exécution d\'une action autorisée', `select ai_action_record_result('${A1}', true, 'fait')`);
  await as(U2);
  await fails('G14 un autre compte ne peut pas confirmer l\'action de U1', `select ai_action_confirm('${A2}', true)`, /introuvable/);
  check('G15 isolation : U2 ne voit aucune action de U1', (await rpc(`ai_action_my_list()`)).length === 0 && (await q(`select count(*)::int n from ai_action_log`))[0].n === 0);
  await as(U1);
  await fails('G16 un utilisateur ne peut pas écrire dans le journal directement', `update ai_action_log set status = 'executee' where id = '${A2}'`, /permission denied/i);
  r = await rpc(`ai_action_confirm('${A2}', true)`);
  check('G17 la personne concernée confirme : « autorisee »', r.status === 'autorisee');
  await fails('G18 une action confirmée ne se re-confirme pas', `select ai_action_confirm('${A2}', false)`, /déjà traitée/);
  r = await rpc(`ai_action_confirm('${A3}', false)`);
  check('G19 refus humain : « refusee »', r.status === 'refusee');
  await svc();
  await fails('G20 une action refusée ne s\'exécute pas', `select ai_action_record_result('${A3}', true, 'x')`, /Exécution sans autorisation refusée|clôturée/);
  await works('G21 l\'action confirmée peut ensuite être exécutée', `select ai_action_record_result('${A2}', true, 'fait')`);
  await sup();
  await fails('G22 le journal est protégé même pour un accès direct : modification d\'une action clôturée refusée', `update ai_action_log set status = 'autorisee' where id = '${A3}'`, /clôturée/);
  await fails('G23 le journal est protégé : champs immuables', `update ai_action_log set action = 'autre' where id = '${A1}'`, /immuables/);
  await as(U1);
  list = await rpc(`ai_action_my_list()`);
  check('G24 journal de U1 : 3 actions, statuts executee / executee / refusee', list.length === 3 && list.filter((x) => x.status === 'executee').length === 2 && list.filter((x) => x.status === 'refusee').length === 1);
  for (let i = 0; i < 27; i++) await q(`select ai_action_propose('talent', 'resume_${i}')`);
  await fails('G25 quota : 31e action de l\'heure refusée', `select ai_action_propose('talent', 'une_de_trop')`, /Quota/);
  await as(ADM);
  await q(`select ai_agent_set_status('talent', 'suspendu')`);
  await as(U2);
  await fails('G26 agent suspendu : aucune action', `select ai_action_propose('talent', 'resume_profil')`, /Agent non actif/);

  // ============================================================ H. Rejeu des migrations sans effet de bord
  await sup();
  const before = await snapshot();
  const fs = await import('fs'); const path = await import('path'); const { fileURLToPath } = await import('url');
  const dir = path.dirname(fileURLToPath(import.meta.url));
  for (const f of ['20261126030000_h10_ai_fournisseurs_traduction.sql', '20261126030100_h10_ai_transcription_consentement.sql', '20261126030200_h10_ai_kela_agents.sql']) {
    try { await db.exec(fs.readFileSync(path.join(dir, '..', '..', 'migrations', f), 'utf8')); check(`H1 rejeu sans erreur : ${f.slice(0, 14)}`, true); } catch (e) { check(`H1 rejeu sans erreur : ${f.slice(0, 14)}`, false, e.message); }
  }
  const after = await snapshot();
  check('H2 rejeu : aucune ligne ajoutée, supprimée ni dupliquée ; politiques, fonctions et déclencheurs identiques', JSON.stringify(before) === JSON.stringify(after), JSON.stringify([before, after]));
  check('H3 rejeu : fournisseurs actifs, agent suspendu et traduction en cache conservés', (await qs(`select count(*)::int n from ai_providers where status = 'actif'`))[0].n === 2
    && (await qs(`select status from ai_agents where code = 'talent'`))[0].status === 'suspendu' && (await qs(`select count(*)::int n from ai_translations`))[0].n === 1);
  check('H4 rejeu : les 19 autres agents restent « non_actif »', (await qs(`select count(*)::int n from ai_agents where status = 'non_actif'`))[0].n === 19);

  console.log(`h10_ai : ${ok} OK, ${ko} ECHEC`);
  console.log(`${ok}/${ok + ko}`);
}
