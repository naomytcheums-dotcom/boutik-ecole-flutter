// Lot S1 (profil étudiant-vendeur) : migrations 20261117010000 (étudiant vérifié, pièces, certification par périmètre) et 20261117010100 (2FA, suppression de compte).
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s1.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated', aal = null) => {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '${uid && aal ? JSON.stringify({ sub: uid, aal }) : ''}', false)`);
    if (role) await db.exec(`set role ${role}`);
  };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const I1 = '00000000-0000-0000-0000-00000000a101', I2 = '00000000-0000-0000-0000-00000000a102', D1 = '00000000-0000-0000-0000-00000000b101', D2 = '00000000-0000-0000-0000-00000000b102';

  await db.exec('reset role');
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test S1', 'verified'), ('${I2}', 'Autre école S1', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I1}', 'Gestion', 'verified')`);
  // 41 étudiante D1 · 42 étudiant D1 sans pièce · 43 admin · 44 chef D1 · 45 chef D2 · 46 support · 47 client · 48 entreprise · 49 étudiant D2 · 50 chef sans département
  const roles = { 41: 'student', 42: 'student', 43: 'admin', 44: 'dept', 45: 'dept', 46: 'support', 47: 'client', 48: 'company', 49: 'student', 50: 'dept' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','s${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','s${n}@t.cm')`);
  }
  await db.exec(`update profiles set institution_id='${I1}', department_id='${D1}', skills='Flutter' where id in ('${U(41)}','${U(42)}','${U(44)}')`);
  await db.exec(`update profiles set institution_id='${I1}', department_id='${D2}', skills='Compta' where id in ('${U(45)}','${U(49)}')`);
  await db.exec(`update profiles set institution_id='${I2}' where id = '${U(50)}'`);
  // H2 : les comptes Département sont rattachés à UN département (44 : D1 ; 45 : D2) ; 50 reste non rattaché.
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${U(44)}', '${D1}'), ('${U(45)}', '${D2}')`);

  // --- étudiant vérifié : rien tant qu'aucune pièce n'est validée
  await db.exec(`insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${U(41)}/student_card/a.pdf', '{"mimetype":"application/pdf","size":1000}'),
     ('profile-documents', '${U(41)}/student_card/b.pdf', '{"mimetype":"application/pdf","size":1000}'), ('profile-documents', '${U(49)}/enrollment/c.pdf', '{"mimetype":"application/pdf","size":1000}')`);
  check('S1-4 : un étudiant auto-déclaré n\'est pas vérifié', (await q(`select is_verified_student('${U(41)}') v`))[0].v === false);
  await as(U(48));
  check('S1-4/S1-87 : l\'annuaire des talents n\'expose aucun étudiant non vérifié', (await q(`select talents_list('') t`))[0].t.length === 0);
  await as(U(41));
  const d1 = (await q(`select document_register('student_card', '${U(41)}/student_card/a.pdf', 'carte.pdf', 'application/pdf', 1000) id`))[0].id;
  const st0 = (await q(`select my_student_status() s`))[0].s;
  check('statut : pièce en attente, non vérifié, certification possible', st0.verified === false && st0.has_identity_document === true && st0.can_request_certification === true && st0.documents.length === 1, JSON.stringify(st0));
  await db.exec('reset role');
  const notif = async (uid, kind = 'verification') => (await q(`select count(*)::int n from notifications where user_id='${uid}' and kind='${kind}'`))[0].n;
  check('S1-27 : l\'admin, le support et le chef du département de l\'étudiante sont prévenus', await notif(U(43)) === 1 && await notif(U(46)) === 1 && await notif(U(44)) === 1);
  check('S1-27 : le chef d\'un autre département n\'est pas prévenu', await notif(U(45)) === 0);
  await as(U(41));
  check('verification_submit : une seule notification par 12 h', (await q(`select verification_submit() n`))[0].n === 1);
  await db.exec('reset role');
  check('verification_submit : pas de doublon', await notif(U(44)) === 1);

  // --- décisions sur les pièces : périmètre
  await as(U(45));
  check('S1-24 : le chef d\'un autre département ne voit pas la pièce', (await q(`select documents_to_review() r`))[0].r.length === 0);
  await fails('S1-24 : ni ne la décide', `select document_decide('${d1}', 'verified')`, /non autorisée/);
  await as(U(44));
  const list = (await q(`select documents_to_review() r`))[0].r;
  check('S1-24 : le chef du bon département voit la pièce', list.length === 1 && list[0].id === d1 && list[0].owner_name === 'Personne 41', JSON.stringify(list));
  await fails('S1-24 : refus sans motif', `select document_decide('${d1}', 'rejected')`, /motif/);
  await q(`select document_decide('${d1}', 'rejected', 'Photo illisible')`);
  await db.exec('reset role');
  check('S1-24 : l\'étudiant est notifié du refus avec le motif', (await q(`select count(*)::int n from notifications where user_id='${U(41)}' and kind='verification' and title='Pièce refusée' and body like '%Photo illisible%'`))[0].n === 1);
  check('S1-24 : un refus ne rend pas vérifié', (await q(`select is_verified_student('${U(41)}') v`))[0].v === false);
  await as(U(44));
  await fails('S1-24 : décision déjà prise', `select document_decide('${d1}', 'rejected', 'Encore')`, /déjà reçu/);
  await as(U(41));
  await fails('S1-24 : un étudiant ne décide pas de sa pièce', `select document_decide('${d1}', 'verified')`, /non autorisée/);
  const d2 = (await q(`select document_register('student_card', '${U(41)}/student_card/b.pdf', 'carte2.pdf', 'application/pdf', 1000) id`))[0].id;
  await as(U(46));
  check('S1-24 : le support voit toutes les pièces en attente', (await q(`select documents_to_review() r`))[0].r.length === 1);
  await q(`select document_decide('${d2}', 'verified')`);
  await db.exec('reset role');
  check('S1-25 : une carte validée rend « étudiant vérifié »', (await q(`select is_verified_student('${U(41)}') v`))[0].v === true);
  check('S1-24 : notification « étudiant vérifié »', (await q(`select count(*)::int n from notifications where user_id='${U(41)}' and title='Pièce validée' and body like '%étudiant vérifié%'`))[0].n === 1);
  check('S1-24 : audit de la décision', (await q(`select count(*)::int n from audit_log where category='Vérification'`))[0].n === 2);

  // --- surfaces réservées aux vérifiés
  await db.exec('reset role');
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${U(48)}', 'Orange', 'approved') on conflict (owner_id) do update set status = 'approved'`);
  await as(U(48));
  const tl = (await q(`select talents_list('') t`))[0].t;
  check('S1-4 : l\'annuaire ne montre que l\'étudiante vérifiée', tl.length === 1 && tl[0].id === U(41), JSON.stringify(tl.map((x) => x.id)));
  await db.exec('reset role');
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status, skills) values ('00000000-0000-0000-0000-00000000f101', '${U(48)}', 'Orange', 'stage', 'Stage', 'published', array['Flutter'])`);
  await as(U(48));
  await fails('S1-87 : invitation d\'un étudiant non vérifié refusée', `select opp_invite('00000000-0000-0000-0000-00000000f101', '${U(42)}', 'x')`, /Étudiant introuvable/);
  check('S1-87 : invitation d\'un étudiant vérifié acceptée', (await q(`select opp_invite('00000000-0000-0000-0000-00000000f101', '${U(41)}', 'x') r`))[0].r === 'invited');
  await as(U(48));
  const dd = (await q(`select department_detail('${D1}') d`))[0].d;
  check('S1-87 : la fiche du département ne compte que les vérifiés', dd.students === 1, JSON.stringify(dd));
  await as(U(43));
  const po = (await q(`select platform_overview() p`))[0].p;
  check('S1-87 : tableau de bord : vérifiés et total déclaré', po.students === 1 && po.students_declared === 3, JSON.stringify(po));

  // --- certification : qui demande, qui décide
  await as(U(47));
  await fails('S1-83 : un client ne demande pas la certification', `select submit_certification_request('Je voudrais être certifié pour publier', '')`, /réservée aux étudiants/);
  await as(U(42));
  await fails('S1-83 : un étudiant sans pièce ne peut pas', `select submit_certification_request('Je voudrais être certifié pour publier', '')`, /justificatif/);
  await db.exec(`reset role; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(42)}', 'other', 'x.pdf', '${U(42)}/o/x.pdf', 'application/pdf', 10, 'pending')`);
  await as(U(42));
  await fails('S1-83 : une pièce « autre » ne suffit pas à un étudiant', `select submit_certification_request('Je voudrais être certifié pour publier', '')`, /carte d'étudiant ou certificat/);
  await db.exec(`reset role; insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(42)}', 'student_card', 'c.pdf', '${U(42)}/c/c.pdf', 'application/pdf', 10, 'rejected')`);
  await as(U(42));
  await fails('S1-83 : une carte refusée ne suffit pas', `select submit_certification_request('Je voudrais être certifié pour publier', '')`, /carte d'étudiant ou certificat/);
  await as(U(41));
  check('S1-83 : une étudiante avec carte valable demande', (await q(`select submit_certification_request('Je voudrais être certifiée pour publier', 'x') r`))[0].r === 'pending');
  await db.exec('reset role');
  check('S1-84 : la demande prévient l\'admin et le chef du bon département seulement', await notif(U(43), 'certification') === 1 && await notif(U(44), 'certification') === 1 && await notif(U(45), 'certification') === 0);
  await as(U(45));
  check('S1-84 : la file du chef d\'un autre département est vide', (await q(`select certification_queue() r`))[0].r.length === 0);
  await fails('S1-82 : un chef ne décide pas pour un autre département', `select decide_certification('${U(41)}', 'approved')`, /n'appartient pas à votre département/);
  await as(U(50));
  await fails('S1-82 : un chef sans département ne décide pas', `select decide_certification('${U(41)}', 'approved')`, /n'appartient pas à votre département/);
  await as(U(46));
  await fails('S1-82 : le support ne décide pas', `select decide_certification('${U(41)}', 'approved')`, /Réservé au département/);
  await as(U(44));
  const cq = (await q(`select certification_queue() r`))[0].r;
  check('S1-84 : la file du chef contient la demande avec motif et pièces', cq.length === 1 && cq[0].id === U(41) && cq[0].motive.includes('certifiée') && cq[0].documents.length === 2, JSON.stringify(cq));
  check('S1-84 : le chef examine', (await q(`select decide_certification('${U(41)}', 'review') r`))[0].r === 'review');
  check('S1-82 : le chef décide pour son département', (await q(`select decide_certification('${U(41)}', 'approved') r`))[0].r === 'approved');
  await as(U(43));
  check('S1-82 : l\'admin décide pour tous (retrait)', (await q(`select decide_certification('${U(41)}', 'revoked', 'Pièce falsifiée') r`))[0].r === 'revoked');
  await db.exec('reset role');
  check('retrait de certification : la pièce validée garde le statut vérifié', (await q(`select is_verified_student('${U(41)}') v`))[0].v === true);

  // --- référentiel
  await as(U(42));
  const ip = (await q(`select institution_propose('Institut Z', 'Douala') id`))[0].id;
  await db.exec('reset role');
  check('S1-19 : la proposition prévient l\'admin et le support', await notif(U(43), 'reference') === 1 && await notif(U(46), 'reference') === 1);
  await as(U(44));
  await fails('S1-19 : un chef ne relit pas le référentiel', `select references_to_review()`, /non autorisée/);
  await as(U(46));
  const rr = (await q(`select references_to_review() r`))[0].r;
  check('S1-19 : le support liste les propositions', rr.length === 1 && rr[0].name === 'Institut Z' && rr[0].kind === 'institution', JSON.stringify(rr));
  await q(`select reference_review('institution', '${ip}', true)`);
  await fails('S1-19 : proposition déjà traitée', `select reference_review('institution', '${ip}', true)`, /déjà traitée/);
  await db.exec('reset role');
  check('S1-19 : le proposant est notifié', (await q(`select count(*)::int n from notifications where user_id='${U(42)}' and kind='reference' and title='Établissement publié'`))[0].n === 1);

  // --- matricule
  await as(U(42));
  await q(`select profile_set_academic('${I1}', '${D1}', 'MAT-001', 'L2')`);
  await as(U(49));
  await fails('S1-80 : matricule déjà pris dans le même établissement', `select profile_set_academic('${I1}', '${D2}', 'mat-001', 'L2')`, /déjà enregistré/);
  check('S1-80 : même matricule dans un autre établissement accepté', (await q(`select profile_set_academic('${ip}', null, 'MAT-001', 'L2') r`)).length === 1);

  // --- stockage
  await db.exec('reset role; grant select, delete on storage.objects to authenticated');
  await as(U(41));
  check('S1-81 : le fichier d\'une pièce enregistrée ne se supprime pas directement', (await q(`delete from storage.objects where bucket_id='profile-documents' and name='${U(41)}/student_card/b.pdf' returning id`)).length === 0);
  await db.exec(`reset role; insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${U(41)}/libre.pdf', '{}')`);
  await as(U(41));
  check('S1-81 : un fichier non enregistré se supprime', (await q(`delete from storage.objects where bucket_id='profile-documents' and name='${U(41)}/libre.pdf' returning id`)).length === 1);
  await as(U(44));
  check('stockage : le chef du département lit la pièce de son étudiante', (await q(`select count(*)::int n from storage.objects where bucket_id='profile-documents' and name='${U(41)}/student_card/b.pdf'`))[0].n === 1);
  await as(U(45));
  check('stockage : le chef d\'un autre département ne la lit pas', (await q(`select count(*)::int n from storage.objects where bucket_id='profile-documents' and name='${U(41)}/student_card/b.pdf'`))[0].n === 0);

  // --- 2FA : codes de secours
  await db.exec(`reset role; insert into auth.mfa_factors (user_id, status) values ('${U(48)}', 'verified'), ('${U(49)}', 'verified'), ('${U(43)}', 'verified')`);
  await as(U(47));
  await fails('S1-51 : sans 2FA, pas de codes de secours', `select mfa_backup_codes_generate()`, /Activez d'abord/);
  await as(U(48), 'authenticated', 'aal1');
  await fails('S1-51 : codes refusés en aal1', `select mfa_backup_codes_generate()`, /double authentification/);
  await as(U(48), 'authenticated', 'aal2');
  const codes = (await q(`select mfa_backup_codes_generate() c`))[0].c;
  check('S1-51 : 8 codes distincts de 12 caractères', codes.length === 8 && new Set(codes).size === 8 && codes.every((c) => /^[0-9A-F]{6}-[0-9A-F]{6}$/.test(c)), JSON.stringify(codes));
  check('S1-51 : état : 8 codes restants', (await q(`select mfa_backup_codes_status() s`))[0].s.remaining === 8);
  await db.exec('reset role');
  check('S1-51 : les codes ne sont pas stockés en clair', (await q(`select count(*)::int n from mfa_backup_codes where code_hash = '${codes[0]}'`))[0].n === 0
    && (await q(`select count(*)::int n from mfa_backup_codes where user_id = '${U(48)}'`))[0].n === 8);
  await as(U(48), 'authenticated', 'aal2');
  await fails('S1-51 : une table de codes n\'est pas lisible par le client', `select * from mfa_backup_codes`, /permission denied/);
  await as(U(48), 'authenticated', 'aal1');
  check('S1-51 : un code faux est refusé', (await q(`select mfa_use_backup_code('AAAAAA-BBBBBB') r`))[0].r === 'invalid');
  check('S1-51 : le bon code récupère le compte', (await q(`select mfa_use_backup_code('${codes[0].toLowerCase()}') r`))[0].r === 'ok');
  await db.exec('reset role');
  check('S1-51 : la 2FA est retirée', (await q(`select count(*)::int n from auth.mfa_factors where user_id='${U(48)}'`))[0].n === 0);
  await as(U(48));
  await fails('S1-51 : plus de facteur : rien à récupérer', `select mfa_use_backup_code('${codes[1]}')`, /Aucune double authentification/);
  await as(U(49), 'authenticated', 'aal1');
  for (let i = 0; i < 5; i++) await q(`select mfa_use_backup_code('FAUX-${i}')`);
  check('S1-51 : 5 essais ratés verrouillent', (await q(`select mfa_use_backup_code('FAUX-9') r`))[0].r === 'locked');
  await db.exec('reset role');
  // Depuis le centre d'administration par équipes, la réinitialisation 2FA exige la permission explicite security.accounts.
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${U(46)}', 'security', array['security.accounts']) on conflict (user_id, team_code) do update set permissions = excluded.permissions`);
  await as(U(46), 'authenticated', 'aal1');
  await fails('S1-51 : le support ne réinitialise pas un compte de l\'équipe', `select admin_mfa_reset('${U(44)}', 'identité vérifiée par visio')`, /Seul l'administrateur/);
  await fails('S1-51 : motif de vérification obligatoire', `select admin_mfa_reset('${U(49)}', 'ok')`, /identité a été vérifiée/);
  check('S1-51 : le support réinitialise un compte étudiant', (await q(`select admin_mfa_reset('${U(49)}', 'identité vérifiée par visio et carte') r`))[0].r === 'reset');
  await db.exec('reset role');
  check('S1-51 : réinitialisation : facteur retiré, notification, audit', (await q(`select count(*)::int n from auth.mfa_factors where user_id='${U(49)}'`))[0].n === 0
    && await notif(U(49), 'security') === 1 && (await q(`select count(*)::int n from audit_log where action like 'Réinitialisation 2FA%'`))[0].n === 1);
  await as(U(43), 'authenticated', 'aal1');
  await fails('S1-51 : l\'admin avec 2FA doit être en aal2', `select admin_mfa_reset('${U(47)}', 'identité vérifiée en agence')`, /double authentification/);
  await as(U(47));
  await fails('S1-51 : un client ne réinitialise pas', `select admin_mfa_reset('${U(42)}', 'identité vérifiée en agence')`, /non autorisée/);

  // --- suppression de compte : commandes en cours puis anonymisation
  await as(null, null);
  await db.exec(`insert into listings (id, seller_id, title, department, price, status, stock) values ('00000000-0000-0000-0000-00000000c101', '${U(42)}', 'Lampe', 'Genie', 5000, 'approved', 3)`);
  await db.exec(`insert into orders (id, number, buyer_id, subtotal, method, paid) values ('00000000-0000-0000-0000-00000000d101', 'BE-S1-1', '${U(47)}', 5000, 'cod', true);
                 insert into order_lines (order_id, listing_id, title, unit_price, qty, fulfillment) values ('00000000-0000-0000-0000-00000000d101', '00000000-0000-0000-0000-00000000c101', 'Lampe', 5000, 1, 1)`);
  await as(U(42));
  await fails('S1-56 : le vendeur avec une commande en cours ne peut pas demander la suppression', `select request_account_deletion('je pars')`, /commande\(s\) en cours/);
  await as(U(47));
  await fails('S1-56 : ni l\'acheteur', `select request_account_deletion('je pars')`, /commande\(s\) en cours/);
  await db.exec(`reset role; update order_lines set fulfillment = 4 where order_id = '00000000-0000-0000-0000-00000000d101'`);
  await as(U(47));
  check('S1-56 : commande livrée : la demande passe', (await q(`select request_account_deletion('je pars') r`))[0].r.status === 'pending');
  await as(U(42));
  check('S1-56 : vendeur sans commande ouverte : la demande passe', (await q(`select request_account_deletion('je pars') r`))[0].r.status === 'pending');
  await db.exec(`reset role; insert into orders (id, number, buyer_id, subtotal, method, paid) values ('00000000-0000-0000-0000-00000000d102', 'BE-S1-2', '${U(49)}', 5000, 'cod', true);
                 insert into order_lines (order_id, listing_id, title, unit_price, qty, fulfillment) values ('00000000-0000-0000-0000-00000000d102', '00000000-0000-0000-0000-00000000c101', 'Lampe', 5000, 1, 2)`);
  await as(U(43), 'authenticated', 'aal2');
  const ap = (await q(`select account_deletions_pending() r`))[0].r;
  check('S1-55 : la file de suppression indique les commandes ouvertes', ap.length === 2 && ap.find((x) => x.user_id === U(42)).open_orders === 1, JSON.stringify(ap));
  let pr = (await q(`select admin_process_account_deletions() r`))[0].r;
  check('S1-55 : rien avant l\'échéance de 30 jours', pr.processed === 0 && pr.blocked.length === 0, JSON.stringify(pr));
  await db.exec(`reset role; update account_deletion_requests set scheduled_for = now() - interval '1 day'`);
  await as(U(47));
  await fails('S1-55 : un client ne lance pas le traitement', `select admin_process_account_deletions()`, /Réservé à l'administrateur/);
  await as(U(43), 'authenticated', 'aal2');
  pr = (await q(`select admin_process_account_deletions() r`))[0].r;
  check('S1-55/56 : le vendeur avec commande en cours est épargné, le client est anonymisé', pr.processed === 1 && pr.blocked.length === 1 && pr.blocked[0] === U(42), JSON.stringify(pr));
  await db.exec('reset role');
  const gone = (await q(`select name, email, phone, suspended, bio from profiles where id = '${U(47)}'`))[0];
  check('S1-55 : profil anonymisé et désactivé', gone.name === 'Compte supprimé' && gone.email === null && gone.phone === null && gone.suspended === true, JSON.stringify(gone));
  check('S1-55 : la commande et ses lignes sont conservées', (await q(`select count(*)::int n from orders where id = '00000000-0000-0000-0000-00000000d101' and buyer_id = '${U(47)}'`))[0].n === 1
    && (await q(`select count(*)::int n from order_lines where order_id = '00000000-0000-0000-0000-00000000d101'`))[0].n === 1);
  check('S1-55 : accès bloqué (adresse inutilisable, connexion interdite)', (await q(`select email, banned_until from auth.users where id = '${U(47)}'`))[0].email.endsWith('@supprime.invalid'));
  check('S1-55 : demande marquée traitée', (await q(`select status from account_deletion_requests where user_id = '${U(47)}'`))[0].status === 'done');
  await db.exec(`update order_lines set fulfillment = 4 where order_id = '00000000-0000-0000-0000-00000000d102'`);
  await as(U(43), 'authenticated', 'aal2');
  pr = (await q(`select admin_process_account_deletions() r`))[0].r;
  await db.exec('reset role');
  check('S1-55 : vendeur anonymisé quand la commande est livrée ; ses annonces retirées, pièces effacées', pr.processed === 1
    && (await q(`select status from listings where id = '00000000-0000-0000-0000-00000000c101'`))[0].status === 'removed'
    && (await q(`select count(*)::int n from user_documents where owner_id = '${U(42)}'`))[0].n === 0);

  // --- CGU / CGV
  await as(U(48));
  check('S1-60 : les CGV s\'enregistrent séparément des CGU', (await q(`select accept_terms('cgu-2026-10') a`))[0].a === 'recorded' && (await q(`select accept_terms('cgv-2026-11') a`))[0].a === 'recorded');
  check('S1-61 : my_terms / my_sales_terms distinguent les documents', (await q(`select my_terms() t`))[0].t === 'cgu-2026-10' && (await q(`select my_sales_terms() t`))[0].t === 'cgv-2026-11');
  await fails('S1-60 : version inconnue refusée', `select accept_terms('xxx-2026-11')`, /inconnue/);

  // --- export
  await as(U(41));
  const ex = (await q(`select export_my_data() e`))[0].e;
  check('S1-57 : l\'export contient les ventes ou signale leur absence', Array.isArray(ex.donnees.ventes) && ex.tables_non_lues.indexOf('ventes') < 0, JSON.stringify(ex.tables_non_lues));
  await db.exec('reset role');
  console.log(`\netu_s1: ${ok} OK, ${ko} KO`);
}
