// Lot K4 (Partenariats et Organisation) : migrations 20261121040000 (rattachement d'une organisation aux partenariats) et 20261121040100 (libellés).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./fin_k4.mjs  (attendu : aucune ligne ECHEC)
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000040${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const n = async (sql) => (await q(sql))[0].n;
  const j = async (sql) => (await q(sql))[0].r;
  const notifs = async (uid, title) => { await db.exec('reset role'); return n(`select count(*)::int n from notifications where user_id = '${U(uid)}' and title = '${title.replace(/'/g, "''")}'`); };

  await db.exec('reset role');
  // 1 direction, 2 direction suspendue, 3 dept Info, 4 dept Gestion, 5 dept non rattaché, 6 client, 7 Orange (approuvée), 8 admin, 9 finance, 10 support, 11 étudiant,
  // 12 organisation en vérification, 13 organisation approuvée mais suspendue, 14 admin de l'équipe Orange, 15 lecteur Orange, 16 association (rôle other), 17 organisation rivale,
  // 18 admin d'équipe Orange suspendu, 19 organisation en brouillon, 20 finance d'équipe Orange
  const users = [[1, 'Directrice K4', 'direction'], [2, 'Direction Suspendue', 'direction'], [3, 'Doua Dept Info', 'dept'], [4, 'Gaby Dept Gestion', 'dept'], [5, 'Dept Sans Rattachement', 'dept'],
    [6, 'Kim Cliente', 'client'], [7, 'Orange Cameroun', 'company'], [8, 'Mod Admin', 'admin'], [9, 'Fin Agent', 'finance'], [10, 'Sup Agent', 'support'], [11, 'Gil Etudiant', 'student'],
    [12, 'Pending Corp', 'company'], [13, 'Suspendue SARL', 'company'], [14, 'Adm Orange', 'client'], [15, 'Lecteur Orange', 'client'], [16, 'Association Les Amis', 'other'],
    [17, 'Rival SA', 'company'], [18, 'Adm Orange Suspendu', 'client'], [19, 'Brouillon Org', 'company'], [20, 'Fin Orange', 'client']];
  for (const [id, nm, role] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${U(id)}','k4u${id}@t.cm'); insert into profiles(id,name,role,email) values ('${U(id)}','${nm}','${role}','k4u${id}@t.cm')`);
  }
  const I1 = '00000000-0000-0000-0000-00000000a401', D1 = '00000000-0000-0000-0000-00000000a411', D2 = '00000000-0000-0000-0000-00000000a412';
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'IUT test K4', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified'), ('${D2}', '${I1}', 'Gestion', 'verified');
    update profiles set department_id = '${D1}', department = 'Informatique' where id = '${U(3)}';
    update profiles set department_id = '${D2}', department = 'Gestion' where id = '${U(4)}';
    insert into department_accounts (user_id, department_id) values ('${U(3)}', '${D1}'), ('${U(4)}', '${D2}');
    update profiles set suspended = true where id in ('${U(2)}', '${U(13)}', '${U(18)}');
    insert into company_profiles (owner_id, company_name, status, org_type, city, phone, registration_number, contact_name) values
      ('${U(7)}', 'Orange Cameroun', 'approved', 'entreprise_commerciale', 'Douala', '699000111', 'RC-SECRET-1', 'Contact Secret'),
      ('${U(12)}', 'Pending Corp', 'pending', 'entreprise_commerciale', 'Yaoundé', '', '', ''),
      ('${U(13)}', 'Suspendue SARL', 'approved', 'entreprise_commerciale', 'Douala', '', '', ''),
      ('${U(16)}', 'Association Les Amis', 'approved', 'association', 'Bafoussam', '', '', ''),
      ('${U(17)}', 'Rival SA', 'approved', 'entreprise_commerciale', 'Douala', '', '', ''),
      ('${U(19)}', 'Brouillon Org', 'draft', 'entreprise_commerciale', '', '', '', '');
    insert into company_members (owner_id, user_id, role, status) values
      ('${U(7)}', '${U(14)}', 'admin', 'active'), ('${U(7)}', '${U(15)}', 'viewer', 'active'), ('${U(7)}', '${U(18)}', 'admin', 'active'), ('${U(7)}', '${U(20)}', 'finance', 'active')`);

  // ============================================================ 1. Recherche d'une organisation approuvée
  const search = async (who, qq = '') => { await as(U(who)); return j(`select partnership_org_search('${qq}', 20) r`); };
  let s = await search(1);
  check('K4-1 : direction : voit les organisations approuvées (3) et seulement celles-là', s.length === 3 && ['Orange Cameroun', 'Association Les Amis', 'Rival SA'].every((x) => s.some((o) => o.name === x)), JSON.stringify(s));
  check('K4-1 : ni brouillon, ni vérification, ni suspendue dans la recherche', !s.some((o) => ['Pending Corp', 'Suspendue SARL', 'Brouillon Org'].includes(o.name)));
  check('K4-1 : fiche publique minimale (id, nom, type, libellé du type, ville) sans téléphone, RCCM ni contact', s.every((o) => Object.keys(o).sort().join() === 'city,id,name,org_type,type_label') && !JSON.stringify(s).match(/699000111|RC-SECRET|Contact Secret/));
  check('K4-1 : le libellé du type vient du référentiel', s.find((o) => o.name === 'Association Les Amis').type_label === 'Association' && s.find((o) => o.name === 'Orange Cameroun').type_label === 'Entreprise commerciale');
  s = await search(1, 'orang');
  check('K4-1 : recherche par fragment de nom (insensible à la casse)', s.length === 1 && s[0].name === 'Orange Cameroun');
  check('K4-1 : joker % traité comme un caractère (aucune énumération)', (await search(1, '%')).length === 0 && (await search(1, '_')).length === 0);
  check('K4-1 : administrateur : même recherche', (await search(8, 'amis')).length === 1);
  check('K4-1 : département rattaché : même recherche', (await search(3, 'rival')).length === 1);
  await as(U(1));
  await fails('K4-1 : recherche trop longue refusée', `select partnership_org_search('${'x'.repeat(81)}', 10)`, /trop longue/);
  check('K4-1 : plafond de résultats (limite 1)', (await j(`select partnership_org_search('', 1) r`)).length === 1);
  for (const [id, who] of [[5, 'département non rattaché'], [6, 'client'], [7, 'organisation'], [9, 'finance'], [10, 'support'], [11, 'étudiant'], [2, 'direction suspendue'], [16, 'organisation (rôle other)']]) {
    await as(U(id));
    await fails(`K4-1 : ${who} : recherche refusée`, `select partnership_org_search('', 10)`, /non autorisée|rattaché/);
  }
  await as(null, 'anon');
  await fails('K4-1 : visiteur : recherche refusée', `select partnership_org_search('', 10)`, /permission|Connexion/);

  // ============================================================ 2. Enregistrement : organisation inscrite ou externe
  await as(U(1));
  const P1 = await j(`select partnership_save(null, 'nom ignoré', 'autre', '${D1}', '${U(7)}', 'M. Contact', 'contact@orange.cm', '', 'Stages et recrutement', array['stages'], '2026-12-01', '2027-12-01') r`);
  await db.exec('reset role');
  let row = (await q(`select name, kind, organization_id, organization_name, company_owner_id, org_response, status from institutional_partnerships where id = '${P1}'`))[0];
  check('K4-2 : direction : organisation inscrite : nom et type imposés par la fiche, lien enregistré', row.name === 'Orange Cameroun' && row.kind === 'entreprise' && row.organization_id === U(7) && row.organization_name === 'Orange Cameroun' && row.company_owner_id === U(7), JSON.stringify(row));
  check('K4-2 : proposé : réponse de l\'organisation « aucune » (elle ne voit pas encore le dossier)', row.status === 'proposed' && row.org_response === 'none');
  await as(U(1));
  const P2 = await j(`select partnership_save(null, 'Association Locale Ndogbong', 'association', null, null, '', '', '', 'Ateliers', null, null, null) r`);
  await db.exec('reset role');
  row = (await q(`select name, kind, organization_id, organization_name, org_response from institutional_partnerships where id = '${P2}'`))[0];
  check('K4-2 : organisation externe : nom et type libres, aucun lien, clairement distinguée', row.organization_id === null && row.organization_name === 'Association Locale Ndogbong' && row.kind === 'association' && row.org_response === 'none', JSON.stringify(row));
  await as(U(1));
  const P3 = await j(`select partnership_save(null, 'x', 'entreprise', null, '${U(16)}', '', '', '', '', null, null, null) r`);
  await db.exec('reset role');
  check('K4-2 : le type du partenaire suit le type de l\'organisation (association, rôle other)', (await n(`select count(*)::int n from institutional_partnerships where id = '${P3}' and kind = 'association' and name = 'Association Les Amis'`)) === 1);
  await as(U(1));
  await fails('K4-2 : organisation en vérification refusée', `select partnership_save(null, 'Pending Corp', 'entreprise', null, '${U(12)}', '', '', '', '', null, null, null)`, /introuvable ou non approuvée/);
  await fails('K4-2 : organisation en brouillon refusée', `select partnership_save(null, 'Brouillon Org', 'entreprise', null, '${U(19)}', '', '', '', '', null, null, null)`, /introuvable ou non approuvée/);
  await fails('K4-2 : organisation suspendue refusée', `select partnership_save(null, 'Suspendue SARL', 'entreprise', null, '${U(13)}', '', '', '', '', null, null, null)`, /introuvable ou non approuvée/);
  await fails('K4-2 : compte sans fiche d\'organisation (client) refusé', `select partnership_save(null, 'Kim', 'entreprise', null, '${U(6)}', '', '', '', '', null, null, null)`, /introuvable ou non approuvée/);
  await fails('K4-2 : identifiant inconnu refusé', `select partnership_save(null, 'Inconnue', 'entreprise', null, '${U(99)}', '', '', '', '', null, null, null)`, /introuvable ou non approuvée/);
  await fails('K4-2 : organisation externe : type invalide refusé', `select partnership_save(null, 'Externe X', 'mafia', null, null, '', '', '', '', null, null, null)`, /Type de partenaire/);
  await fails('K4-2 : organisation externe : nom trop court refusé', `select partnership_save(null, 'A', 'ong', null, null, '', '', '', '', null, null, null)`, /Nom du partenaire/);
  // département : propose pour SON département
  await as(U(3));
  const P4 = await j(`select partnership_save(null, 'Rival SA', 'entreprise', '${D2}', '${U(17)}', '', '', '', 'Visites', null, null, null) r`);
  await db.exec('reset role');
  check('K4-2 : département : sa proposition avec organisation inscrite est rattachée à SON département', (await n(`select count(*)::int n from institutional_partnerships where id = '${P4}' and department_id = '${D1}' and organization_id = '${U(17)}' and status = 'proposed'`)) === 1);
  check('K4-2 : la direction est notifiée (organisation inscrite)', (await n(`select count(*)::int n from notifications where user_id = '${U(1)}' and title = 'Partenariat à valider' and body like '%organisation inscrite%'`)) === 1);
  await as(U(3));
  await fails('K4-2 : département : organisation non approuvée refusée aussi', `select partnership_save(null, 'Pending Corp', 'entreprise', null, '${U(12)}', '', '', '', '', null, null, null)`, /introuvable ou non approuvée/);
  const P5 = await j(`select partnership_save(null, 'Cabinet Externe', 'autre', null, null, '', '', '', '', null, null, null) r`);
  await q(`select partnership_save('${P5}', 'Cabinet Externe', 'autre', null, '${U(7)}', '', '', '', '', null, null, null)`);
  await db.exec('reset role');
  check('K4-2 : département : transforme son externe en organisation inscrite (tant que proposé)', (await n(`select count(*)::int n from institutional_partnerships where id = '${P5}' and organization_id = '${U(7)}' and name = 'Orange Cameroun'`)) === 1);
  await as(U(3));
  await fails('K4-2 : département : ne décide pas', `select partnership_decide('${P4}', 'approve', null)`, /Réservé à la direction/);
  await fails('K4-2 : département : ne modifie pas le dossier de la direction', `select partnership_save('${P1}', 'x', 'entreprise', null, '${U(17)}', '', '', '', '', null, null, null)`, /Seule votre proposition/);
  await as(U(5));
  await fails('K4-2 : département non rattaché : ne propose rien', `select partnership_save(null, 'Externe X', 'ong', null, null, '', '', '', '', null, null, null)`, /rattaché/);
  for (const [id, who] of [[6, 'client'], [7, 'organisation'], [9, 'finance'], [10, 'support'], [11, 'étudiant'], [2, 'direction suspendue'], [16, 'organisation (rôle other)']]) {
    await as(U(id));
    await fails(`K4-2 : ${who} : ne crée aucun partenariat`, `select partnership_save(null, 'Externe X', 'ong', null, '${U(7)}', '', '', '', '', null, null, null)`, /non autorisée/);
  }
  await as(null, 'anon');
  await fails('K4-2 : visiteur : ne crée aucun partenariat', `select partnership_save(null, 'Externe X', 'ong', null, null, '', '', '', '', null, null, null)`, /permission|Connexion/);

  // ============================================================ 3. Rien n'est visible ni notifié côté organisation avant la décision
  for (const id of [7, 14, 15, 20, 17]) check(`K4-3 : avant décision : aucune notification pour le compte ${id}`, (await notifs(id, 'Partenariat validé')) === 0 && (await notifs(id, 'Partenariat avec l\'établissement')) === 0);
  await as(U(7));
  check('K4-3 : l\'organisation ne voit pas un partenariat encore proposé', (await j(`select org_partnerships_list() r`)).length === 0 && (await j(`select partnerships_list() r`)).length === 0);

  // ============================================================ 4. Décision de la direction -> notification de l'organisation
  await as(U(1));
  check('K4-4 : direction valide le partenariat Orange', (await j(`select partnership_decide('${P1}', 'approve', 'Convention signée') r`)) === 'active');
  await db.exec('reset role');
  row = (await q(`select org_response from institutional_partnerships where id = '${P1}'`))[0];
  check('K4-4 : réponse de l\'organisation : en attente', row.org_response === 'pending');
  check('K4-4 : le titulaire d\'Orange est notifié (validé)', (await notifs(7, 'Partenariat validé')) === 1);
  check('K4-4 : l\'administrateur de l\'équipe est notifié', (await notifs(14, 'Partenariat validé')) === 1);
  check('K4-4 : le lecteur, le membre finance, l\'administrateur suspendu et l\'organisation rivale ne sont pas notifiés', (await notifs(15, 'Partenariat validé')) === 0 && (await notifs(20, 'Partenariat validé')) === 0 && (await notifs(18, 'Partenariat validé')) === 0 && (await notifs(17, 'Partenariat validé')) === 0);
  check('K4-4 : la notification pointe le partenariat et l\'organisation', (await n(`select count(*)::int n from notifications where user_id = '${U(7)}' and kind = 'org_partnership' and data->>'partnership' = '${P1}' and data->>'owner' = '${U(7)}'`)) === 1);
  await as(U(1));
  check('K4-4 : refus d\'une proposition liée à l\'organisation rivale', (await j(`select partnership_decide('${P4}', 'reject', 'Périmètre à préciser') r`)) === 'rejected');
  check('K4-4 : un refus n\'est JAMAIS communiqué à l\'organisation concernée (elle n\'a pas vu le dossier)', (await notifs(17, 'Partenariat refusé')) === 0);
  check('K4-4 : le proposant (département) est notifié du refus', (await notifs(3, 'Partenariat refusé')) === 1);
  // l'organisation perd son approbation avant la validation
  await db.exec('reset role');
  await db.exec(`update company_profiles set status = 'rejected' where owner_id = '${U(7)}'`);
  await as(U(1));
  await fails('K4-4 : valider un dossier dont l\'organisation n\'est plus approuvée est refusé', `select partnership_decide('${P5}', 'approve', null)`, /n'est plus approuvée/);
  await db.exec('reset role');
  await db.exec(`update company_profiles set status = 'approved' where owner_id = '${U(7)}'`);
  await as(U(1));
  check('K4-4 : organisation de nouveau approuvée : validation possible', (await j(`select partnership_decide('${P5}', 'approve', null) r`)) === 'active');
  check('K4-4 : validation du dossier externe (Association Ndogbong) : aucune notification d\'organisation', (await j(`select partnership_decide('${P2}', 'approve', null) r`)) === 'active' && (await notifs(16, 'Partenariat validé')) === 0);
  await db.exec('reset role');
  check('K4-4 : l\'organisation externe n\'attend aucune réponse', (await n(`select count(*)::int n from institutional_partnerships where id = '${P2}' and org_response = 'none' and organization_id is null`)) === 1);

  // ============================================================ 5. Espace de l'organisation : voir et répondre
  await as(U(7));
  let ol = await j(`select org_partnerships_list() r`);
  check('K4-5 : le titulaire voit SES partenariats (Orange : 2), pas ceux des autres', ol.length === 2 && ol.every((x) => x.source === 'institution' && x.name === 'Orange Cameroun'), JSON.stringify(ol));
  check('K4-5 : le titulaire peut répondre à un partenariat actif', ol.every((x) => x.can_respond === true && x.org_response === 'pending'));
  check('K4-5 : aucune donnée interne exposée (contacts, auteur de la proposition)', !JSON.stringify(ol).match(/contact@orange|proposer|Doua|Directrice/));
  await as(U(14));
  ol = await j(`select org_partnerships_list('${U(7)}') r`);
  check('K4-5 : l\'administrateur de l\'équipe voit et peut répondre', ol.length === 2 && ol[0].can_respond === true);
  await as(U(15));
  ol = await j(`select org_partnerships_list('${U(7)}') r`);
  check('K4-5 : le lecteur voit mais ne répond pas (can_respond faux)', ol.length === 2 && ol.every((x) => x.can_respond === false));
  await fails('K4-5 : le lecteur ne répond pas', `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /Réservé au propriétaire et aux administrateurs/);
  await as(U(20));
  await fails('K4-5 : le membre finance ne répond pas', `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /Réservé au propriétaire et aux administrateurs/);
  check('K4-5 : le membre finance voit la liste (lecture)', (await j(`select org_partnerships_list('${U(7)}') r`)).length === 2);
  await as(U(17));
  check('K4-5 : l\'organisation rivale ne voit rien d\'Orange', (await j(`select org_partnerships_list() r`)).length === 0);
  await fails('K4-5 : ni en visant l\'identifiant d\'Orange', `select org_partnerships_list('${U(7)}')`, /Accès refusé à cette organisation/);
  await fails('K4-5 : ni en répondant à un partenariat d\'Orange', `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /Réservé au propriétaire et aux administrateurs/);
  await as(U(18));
  await fails('K4-5 : administrateur d\'équipe suspendu : plus d\'accès', `select org_partnerships_list('${U(7)}')`, /Accès refusé/);
  await as(U(6));
  check('K4-5 : un client sans organisation : liste vide, jamais celle d\'un autre', (await j(`select org_partnerships_list() r`)).length === 0);
  await fails('K4-5 : un client ne répond pas', `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /Réservé au propriétaire et aux administrateurs/);
  for (const [id, who] of [[1, 'direction'], [3, 'département']]) {
    await as(U(id));
    await fails(`K4-5 : ${who} : ne répond pas au nom de l'organisation`, `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /Réservé au propriétaire et aux administrateurs/);
  }
  await as(null, 'anon');
  await fails('K4-5 : visiteur : ni liste ni réponse', `select org_partnerships_list()`, /permission|Connexion/);
  await fails('K4-5 : visiteur : pas de réponse', `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /permission|Connexion/);
  await as(U(7));
  await fails('K4-5 : contester sans motif refusé', `select org_partnership_respond('institution', '${P1}', 'contest', 'non')`, /motif/);
  await fails('K4-5 : réponse inconnue refusée', `select org_partnership_respond('institution', '${P1}', 'ignorer', null)`, /Réponse inconnue/);
  await fails('K4-5 : source inconnue refusée', `select org_partnership_respond('autre', '${P1}', 'accept', null)`, /Source de partenariat inconnue/);
  await fails('K4-5 : partenariat externe (sans organisation liée) : introuvable', `select org_partnership_respond('institution', '${P2}', 'accept', null)`, /introuvable ou non actif/);
  check('K4-5 : le titulaire conteste avec motif', (await j(`select org_partnership_respond('institution', '${P1}', 'contest', 'Les dates ne correspondent pas à la convention') r`)) === 'contested');
  await db.exec('reset role');
  check('K4-5 : la direction est notifiée de la contestation (motif inclus)', (await n(`select count(*)::int n from notifications where user_id = '${U(1)}' and title = 'Partenariat contesté' and body like '%dates ne correspondent pas%'`)) === 1);
  check('K4-5 : le département lié au dossier (Informatique) est notifié de la contestation, une seule fois', (await notifs(3, 'Partenariat contesté')) === 1);
  check('K4-5 : la direction suspendue n\'est pas notifiée', (await notifs(2, 'Partenariat contesté')) === 0);
  check('K4-5 : journal d\'audit de la contestation (Sensible)', (await n(`select count(*)::int n from audit_log where action like 'Partenariat contesté par l''organisation%' and level = 'Sensible'`)) === 1);
  await as(U(1));
  const dl = await j(`select partnerships_list('active') r`);
  const d1 = dl.find((x) => x.id === P1);
  check('K4-5 : la direction voit la réponse de l\'organisation, son motif et le lien inscrit', d1 && d1.org_response === 'contested' && d1.org_response_note.includes('dates') && d1.organization_registered === true && d1.organization_id === U(7), JSON.stringify(d1));
  check('K4-5 : la direction distingue l\'organisation non inscrite', dl.find((x) => x.id === P2).organization_registered === false && dl.find((x) => x.id === P2).organization_id === null);
  await as(U(14));
  check('K4-5 : l\'administrateur d\'équipe accepte ensuite (changement de réponse permis)', (await j(`select org_partnership_respond('institution', '${P1}', 'accept', null) r`)) === 'accepted');
  await db.exec('reset role');
  check('K4-5 : le proposant de P5 n\'est pas confondu : acceptation notifie le créateur du dossier P1 (direction)', (await notifs(1, 'Partenariat accepté')) === 1);
  // suspension / reprise / clôture : l'organisation est prévenue, ne peut plus répondre
  await as(U(1));
  await q(`select partnership_decide('${P1}', 'suspend', 'Convention à renouveler')`);
  check('K4-5 : suspension : titulaire et administrateur notifiés avec le motif', (await notifs(7, 'Partenariat suspendu')) === 1 && (await notifs(14, 'Partenariat suspendu')) === 1);
  await as(U(7));
  await fails('K4-5 : un partenariat suspendu ne reçoit plus de réponse', `select org_partnership_respond('institution', '${P1}', 'accept', null)`, /introuvable ou non actif/);
  ol = await j(`select org_partnerships_list() r`);
  check('K4-5 : suspendu : toujours visible, motif visible, réponse impossible', ol.find((x) => x.id === P1).status === 'suspended' && ol.find((x) => x.id === P1).can_respond === false && ol.find((x) => x.id === P1).decision_note === 'Convention à renouveler');
  await as(U(1));
  await q(`select partnership_decide('${P1}', 'resume', null)`);
  const resumed = (await j(`select partnerships_list('active') r`)).find((x) => x.id === P1);
  check('K4-5 : reprise : organisation notifiée, réponse conservée (acceptée)', (await notifs(7, 'Partenariat repris')) === 1 && resumed.org_response === 'accepted');
  await as(U(1));
  await q(`select partnership_decide('${P1}', 'end', 'Fin de convention')`);
  check('K4-5 : clôture : organisation notifiée', (await notifs(7, 'Partenariat clos')) === 1);
  // changement d'organisation sur un dossier actif : l'ancienne est prévenue, la nouvelle doit répondre
  await as(U(1));
  await q(`select partnership_save('${P5}', 'x', 'entreprise', null, '${U(17)}', '', '', '', '', null, null, null)`);
  await db.exec('reset role');
  check('K4-5 : changement d\'organisation d\'un dossier actif : ancienne organisation prévenue (dissocié)', (await notifs(7, 'Partenariat dissocié')) === 1);
  check('K4-5 : nouvelle organisation prévenue et réponse remise en attente', (await notifs(17, 'Partenariat avec l\'établissement')) === 1 && (await n(`select count(*)::int n from institutional_partnerships where id = '${P5}' and org_response = 'pending' and organization_id = '${U(17)}'`)) === 1);
  await as(U(7));
  check('K4-5 : l\'ancienne organisation ne voit plus le dossier P5', !(await j(`select org_partnerships_list() r`)).some((x) => x.id === P5));
  // organisation suspendue : plus d'accès
  await as(U(13));
  await fails('K4-5 : organisation suspendue : plus d\'accès à l\'espace partenariats', `select org_partnerships_list()`, /Accès refusé/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = true where id = '${U(17)}'`);
  await as(U(17));
  await fails('K4-5 : organisation suspendue en cours de route : ne répond plus', `select org_partnership_respond('institution', '${P5}', 'accept', null)`, /suspendu|Réservé/);
  await db.exec('reset role');
  await db.exec(`update profiles set suspended = false where id = '${U(17)}'`);

  // ============================================================ 6. Partenariats des départements
  await as(U(3));
  const DP = await j(`select dept_partnership_save(jsonb_build_object('partner_name', 'nom ignoré', 'organization_id', '${U(16)}', 'kind', 'stage', 'status', 'negociation', 'students', 3)) r`);
  await db.exec('reset role');
  row = (await q(`select partner_name, organization_id, organization_name, org_response, department_id from department_partnerships where id = '${DP}'`))[0];
  check('K4-6 : département : partenariat rattaché à une organisation inscrite (nom imposé par la fiche), en négociation : rien n\'est notifié', row.partner_name === 'Association Les Amis' && row.organization_id === U(16) && row.org_response === 'none' && row.department_id === D1 && (await notifs(16, 'Partenariat avec l\'établissement')) === 0, JSON.stringify(row));
  await as(U(3));
  await fails('K4-6 : département : organisation en vérification refusée', `select dept_partnership_save(jsonb_build_object('partner_name', 'Pending Corp', 'organization_id', '${U(12)}'))`, /introuvable ou non approuvée/);
  await fails('K4-6 : département : organisation suspendue refusée', `select dept_partnership_save(jsonb_build_object('partner_name', 'Suspendue SARL', 'organization_id', '${U(13)}'))`, /introuvable ou non approuvée/);
  await q(`select dept_partnership_save(jsonb_build_object('id', '${DP}', 'partner_name', 'x', 'kind', 'stage', 'status', 'actif', 'students', 3))`);
  await db.exec('reset role');
  check('K4-6 : mise à jour sans organization_id : le lien est conservé ; passage à actif : l\'organisation est notifiée', (await n(`select count(*)::int n from department_partnerships where id = '${DP}' and organization_id = '${U(16)}' and org_response = 'pending'`)) === 1 && (await notifs(16, 'Partenariat avec l\'établissement')) === 1);
  check('K4-6 : la direction est notifiée du partenariat de département actif (existant)', (await n(`select count(*)::int n from notifications where user_id = '${U(1)}' and title = 'Partenariat de département'`)) === 1);
  await as(U(16));
  ol = await j(`select org_partnerships_list() r`);
  check('K4-6 : l\'association (rôle other) voit le partenariat de département (source department, département, effectif)', ol.length === 1 && ol[0].source === 'department' && ol[0].department === 'Informatique' && ol[0].students === 3 && ol[0].can_respond === true, JSON.stringify(ol));
  await fails('K4-6 : contester sans motif refusé', `select org_partnership_respond('department', '${DP}', 'contest', '')`, /motif/);
  check('K4-6 : l\'association accepte', (await j(`select org_partnership_respond('department', '${DP}', 'accept', null) r`)) === 'accepted');
  await db.exec('reset role');
  check('K4-6 : le responsable de département auteur est notifié de l\'acceptation (une fois)', (await n(`select count(*)::int n from notifications where user_id = '${U(3)}' and title = 'Partenariat accepté' and body like 'Association Les Amis%'`)) === 1);
  await as(U(4));
  check('K4-6 : un autre département ne voit rien', (await j(`select dept_partnerships() r`)).partnerships.length === 0);
  await as(U(3));
  const dp = (await j(`select dept_partnerships() r`)).partnerships.find((x) => x.id === DP);
  check('K4-6 : le département voit l\'organisation liée et sa réponse', dp.organization_registered === true && dp.org_response === 'accepted' && dp.organization_name === 'Association Les Amis');
  await as(U(1));
  const dd = (await j(`select direction_dept_partnerships() r`)).find((x) => x.id === DP);
  check('K4-6 : la direction voit l\'organisation liée et sa réponse', dd.organization_registered === true && dd.org_response === 'accepted');
  await as(U(3));
  await q(`select dept_partnership_save(jsonb_build_object('id', '${DP}', 'partner_name', 'Association Les Amis', 'kind', 'stage', 'status', 'actif', 'organization_id', null))`);
  await db.exec('reset role');
  check('K4-6 : dissociation (organization_id nul) : plus de lien, réponse effacée, ancienne organisation prévenue', (await n(`select count(*)::int n from department_partnerships where id = '${DP}' and organization_id is null and org_response = 'none' and organization_name = 'Association Les Amis'`)) === 1 && (await notifs(16, 'Partenariat dissocié')) === 1);
  await as(U(16));
  check('K4-6 : l\'association ne le voit plus', (await j(`select org_partnerships_list() r`)).length === 0);
  await as(U(4));
  await fails('K4-6 : un autre département ne le modifie pas', `select dept_partnership_save(jsonb_build_object('id', '${DP}', 'partner_name', 'x', 'organization_id', '${U(7)}'))`, /introuvable dans ce département/);
  await as(U(5));
  await fails('K4-6 : département non rattaché : refusé', `select dept_partnership_save(jsonb_build_object('partner_name', 'Externe X'))`, /Indiquez le département|rattaché/);
  for (const [id, who] of [[6, 'client'], [7, 'organisation'], [9, 'finance'], [10, 'support'], [11, 'étudiant']]) {
    await as(U(id));
    await fails(`K4-6 : ${who} : ne crée pas de partenariat de département`, `select dept_partnership_save(jsonb_build_object('partner_name', 'Externe X', 'organization_id', '${U(7)}'), '${D1}')`, /non autorisée/);
  }

  // ============================================================ 7. Garde de base : aucun chemin ne contourne la règle
  await db.exec('reset role');
  let blocked = false;
  try { await db.exec(`update department_partnerships set organization_id = '${U(12)}' where id = '${DP}'`); } catch (e) { blocked = /introuvable ou non approuvée/.test(e.message); }
  check('K4-7 : même en écriture directe, une organisation non approuvée ne peut pas être rattachée (trigger)', blocked);
  blocked = false;
  try { await db.exec(`update institutional_partnerships set organization_id = '${U(13)}' where id = '${P2}'`); } catch (e) { blocked = /introuvable ou non approuvée/.test(e.message); }
  check('K4-7 : idem pour une organisation suspendue (partenariats institutionnels)', blocked);
  await as(U(7));
  await fails('K4-7 : aucun accès direct aux partenariats institutionnels', `select count(*) from institutional_partnerships`, /permission/);
  check('K4-7 : aucune ligne de partenariats de département visible pour une organisation (RLS)', (await n(`select count(*)::int n from department_partnerships`)) === 0);
  await fails('K4-7 : une organisation ne peut pas écrire dans les partenariats', `update department_partnerships set org_response = 'accepted'`, /permission/);

  // ============================================================ 8. Libellés (migration 040100)
  await db.exec('reset role');
  const src = async (fn) => (await q(`select string_agg(prosrc, ' ') s from pg_proc where proname = '${fn}' and pronamespace = 'public'::regnamespace`))[0].s || '';
  check('K4-8 : company_effective_owner : « organisation »', /Accès refusé à cette organisation/.test(await src('company_effective_owner')));
  check('K4-8 : _talent_guard : « Réservé aux organisations »', /Réservé aux organisations/.test(await src('_talent_guard')));
  check('K4-8 : company_billing_context_set : « Cette organisation n\'a pas de fiche »', /Cette organisation n''a pas de fiche/.test(await src('company_billing_context_set')));
  check('K4-8 : forfaits : « Vendeur professionnel et Organisation »', /Vendeur professionnel et Organisation/.test(await src('ad_campaign_save')) && /Vendeur professionnel et Organisation/.test(await src('ad_campaign_submit')));
  check('K4-8 : expiration du forfait : « accueil de l\'organisation »', /accueil de l''organisation/.test(await src('expire_company_subscriptions')));
  check('K4-8 : proposition de stage : organisations vérifiées', /réservée aux organisations vérifiées et au département/.test(await src('talent_contact_request')));
  check('K4-8 : plus de libellé d\'acteur « Entreprise » dans opp_save / save_mission / company_billing_set', !/'Entreprise'/.test(await src('opp_save')) && !/'Entreprise'/.test(await src('save_mission')) && !/'Entreprise'/.test(await src('company_billing_set')));
  check('K4-8 : équipes internes : plus de « réservé à la finance » (virements Mobile Money, parrainage) ni de « Réservé au support » (kiosque)', !/réservés à la finance/.test(await src('momo_prepare_transfer')) && !/Réservé à la finance/.test(await src('referral_payout_decide')) && !/Réservé au support/.test(await src('kiosk_provision')));
  const anyLeft = await q(`select proname from pg_proc where pronamespace = 'public'::regnamespace and prosrc ~ '(Accès refusé à cette entreprise|Réservé aux entreprises|Réservé à la finance|Réservé au support ou|Vendeur professionnel et Entreprise)'`);
  check('K4-8 : aucune fonction ne porte encore l\'ancien libellé', anyLeft.length === 0, JSON.stringify(anyLeft));
  check('K4-8 : forfait : « Organisations et partenaires »', (await n(`select count(*)::int n from plans where code = 'entreprise' and audience = 'Organisations et partenaires'`)) === 1);
  check('K4-8 : les identifiants techniques restent (company_profiles, code de forfait, org_type)', (await n(`select count(*)::int n from plans where code = 'entreprise'`)) === 1 && (await n(`select count(*)::int n from org_types where code = 'entreprise_commerciale' and label = 'Entreprise commerciale'`)) === 1);
  await as(U(11));
  await fails('K4-8 : un étudiant lit le message « Réservé aux organisations » (vivier)', `select talent_lists_get()`, /Réservé aux organisations/);

  // ============================================================ 10. Parcours Organisation : forfaits par type dans le bon contexte, permissions propres à chaque organisation (migration 040200)
  await db.exec('reset role');
  await db.exec(`insert into company_profiles (owner_id, company_name, status, org_type, city) values ('${U(20)}', 'Fin Orange Asso perso', 'approved', 'association', 'Douala')`);
  const planCodes = async (uid, owner) => { await as(U(uid)); return (await j(`select company_plans_list(${owner ? `'${U(owner)}'` : 'null'}) r`)).map((p) => p.code); };
  check('K4-10 : entreprise commerciale (propriétaire) : pas de forfait « solidaire »', !(await planCodes(7)).includes('solidaire') && (await planCodes(7)).includes('pro'));
  check('K4-10 : association (propriétaire) : forfait « solidaire » proposé', (await planCodes(16)).includes('solidaire'));
  check('K4-10 : administrateur d\'équipe sans fiche, dans l\'espace Orange : forfaits de l\'entreprise commerciale', !(await planCodes(14, 7)).includes('solidaire') && (await planCodes(14, 7)).includes('pro'));
  check('K4-10 : membre finance ayant sa propre fiche d\'association : sa liste personnelle = association, la liste d\'Orange = entreprise commerciale',
    (await planCodes(20)).includes('solidaire') && !(await planCodes(20, 7)).includes('solidaire'));
  check('K4-10 : administrateur global : tous les forfaits', (await planCodes(8)).includes('solidaire') && (await planCodes(8)).includes('pro'));
  await as(U(17));
  await fails('K4-10 : organisation rivale : forfaits d\'Orange refusés', `select company_plans_list('${U(7)}')`, /Accès refusé/);
  await as(U(18));
  await fails('K4-10 : membre suspendu : refusé', `select company_plans_list('${U(7)}')`, /Accès refusé/);
  await as(null, 'anon');
  await fails('K4-10 : visiteur : refusé', `select company_plans_list(null)`, /permission|Connexion/);
  await as(U(20));
  await fails('K4-10 : paiement d\'un forfait étranger au type refusé même par la finance de l\'équipe', `select company_plan_checkout('solidaire', '${U(7)}')`, /ne concerne pas ce type/);
  await as(U(15));
  await fails('K4-10 : lecteur : ne paie pas de forfait', `select company_plan_checkout('pro', '${U(7)}')`, /Réservé au propriétaire/);
  await fails('K4-10 : lecteur : n\'invite personne', `select company_invite('x@t.cm', 'viewer', '${U(7)}')`, /Réservé|propriétaire|administrateur/);
  // cloisonnement : une organisation tierce n'atteint rien d'une autre, quel que soit le point d'entrée
  await as(U(17));
  for (const [name, sql] of [['fiche', `company_get('${U(7)}')`], ['tableau de bord', `company_dashboard('${U(7)}')`], ['équipe', `company_members_list('${U(7)}')`], ['état du forfait', `company_plan_status('${U(7)}')`],
    ['facturation', `company_billing_get('${U(7)}')`], ['invitation', `company_invite('z@t.cm', 'viewer', '${U(7)}')`], ['partenariats', `org_partnerships_list('${U(7)}')`],
    ['paiement de forfait', `company_plan_checkout('pro', '${U(7)}')`], ['demande de forfait', `company_subscription_request('pro', '${U(7)}')`], ['enregistrement de la fiche', `company_save('{"company_name":"Pirate"}'::jsonb, '${U(7)}')`]]) {
    await fails(`K4-10 : organisation tierce : ${name} d'Orange refusé(e)`, `select ${sql}`, /Accès refusé|Réservé/);
  }
  // informations légales et représentant : visibles du propriétaire et de l'administrateur de l'équipe, jamais du lecteur ni de la fiche publique
  const fiche = async (uid) => { await as(U(uid)); return j(`select company_get('${U(7)}') r`); };
  check('K4-10 : propriétaire : immatriculation et interlocuteur visibles', (await fiche(7)).registration_number === 'RC-SECRET-1' && (await fiche(7)).contact_name === 'Contact Secret');
  check('K4-10 : administrateur d\'équipe : mêmes informations légales', (await fiche(14)).registration_number === 'RC-SECRET-1');
  const lect = await fiche(15);
  check('K4-10 : lecteur : ni immatriculation, ni téléphone, ni interlocuteur', !('registration_number' in lect) && !('phone' in lect) && !('contact_name' in lect));
  const fin = await fiche(20);
  check('K4-10 : finance d\'équipe : ni immatriculation ni interlocuteur', !('registration_number' in fin) && !('contact_name' in fin));
  await as(U(11));
  await fails('K4-10 : étudiant : pas d\'accès à la fiche privée', `select company_get('${U(7)}')`, /Accès refusé/);
  await as(U(6));
  check('K4-10 : page publique : aucune donnée légale', !/RC-SECRET|Contact Secret|699000111/.test(JSON.stringify(await j(`select company_profile_view('${U(7)}') r`))));

  // ============================================================ 9. Rejeu idempotent
  await db.exec('reset role');
  const fs = await import('fs');
  const dir = new URL('../../migrations/', import.meta.url);
  let replay = true;
  for (const f of ['20261121040000_k4_partenariats_organisation.sql', '20261121040100_k4_libelles_organisation_equipes.sql', '20261121040200_k4_forfaits_organisation_visee.sql']) {
    try { await db.exec(fs.readFileSync(new URL(f, dir), 'utf8')); } catch (e) { replay = false; console.log('   rejeu', f, e.message.slice(0, 200)); }
  }
  check('K4-9 : les trois migrations se rejouent sans erreur (idempotence)', replay);
  await as(U(1));
  check('K4-9 : après rejeu, la recherche fonctionne toujours', (await j(`select partnership_org_search('amis', 5) r`)).length === 1);

  console.log(`\nK4 : ${ok} OK, ${ko} ECHEC`);
}
