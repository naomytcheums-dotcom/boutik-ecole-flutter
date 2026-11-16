// Sonde de sécurité du profil Entreprise : chaque tentative d'accès non autorisé doit échouer.
// « FAILLE » = l'opération a réussi alors qu'elle ne le devrait pas. « INFO » = comportement à connaître.
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${n}`;
  const E = U('e1'), X = U('e2'), P = U('e3'), S = U('a1'), C = U('c1'), T = U('b1'), ADM = U('ad'), SUS = U('e4');
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const good = (name) => { ok++; console.log('OK', name); };
  const bad = (name, extra = '') => { ko++; console.log('FAILLE', name, extra); };
  // doit échouer
  const denied = async (name, sql) => { await db.exec('begin'); try { await db.query(sql); bad(name, 'a réussi'); } catch (e) { const m = String(e.message); if (/does not exist|invalid input|syntax error|violates not-null|violates check/.test(m)) bad(name, 'ERREUR DE SONDE : ' + m.slice(0, 90)); else good(name + ' [' + m.slice(0, 60) + ']'); } finally { await db.exec('rollback'); } };
  // doit réussir
  const allowed = async (name, sql) => { await db.exec('begin'); try { await db.query(sql); good(name); } catch (e) { bad(name, String(e.message).slice(0, 120)); } finally { await db.exec('rollback'); } };
  const info = async (name, sql) => { await db.exec('begin'); let r; try { const x = await db.query(sql); r = 'réussi (' + (x.rows.length ? JSON.stringify(x.rows[0]).slice(0, 80) : x.affectedRows ?? 0) + ')'; } catch (e) { r = 'refusé : ' + String(e.message).slice(0, 80); } finally { await db.exec('rollback'); } console.log('INFO', name, '->', r); };
  // lecture : renvoie le nombre de lignes visibles
  const count = async (sql) => { await db.exec('begin'); try { return (await db.query(sql)).rows.length; } catch (e) { return 0; } finally { await db.exec('rollback'); } };

  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange', 'company'], [X, 'Xena', 'company'], [P, 'Pending', 'company'], [S, 'Alice', 'student'], [C, 'Carl', 'client'], [T, 'Team', 'client'], [ADM, 'Admin', 'admin'], [SUS, 'Suspendu', 'company']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm}@t.cm')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${SUS}'`);
  for (const [id, nm, st] of [[E, 'Orange', 'approved'], [X, 'Xena', 'approved'], [P, 'Pending', 'draft'], [SUS, 'Suspendu', 'approved']]) {
    await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name) values ('${id}', '${nm}', '${st}', 'Telecoms', 'Douala', '699', 'M')`);
  }
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${E}', 'entreprise', 'active', now(), now() + interval '30 days')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${E}', '${T}', 'admin', 'active')`);
  // offre publiée de E, candidature de S
  const O1 = U('0f');
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status) values ('${O1}', '${E}', 'Orange', 'stage', 'Stage reseau', 'published')`);
  const OP = U('0e');
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status) values ('${OP}', '${E}', 'Orange', 'stage', 'Stage en attente', 'pending')`);
  const AP = U('0a');
  await db.exec(`insert into opportunity_applications (id, opportunity_id, applicant_id, message) values ('${AP}', '${O1}', '${S}', 'Bonjour')`);

  // ---- 1. Auto-promotion : écritures directes sur les tables
  await as(P);
  await denied('entreprise non verifiee ne se verifie pas elle-meme', `update company_profiles set status = 'approved' where owner_id = '${P}'`);
  await as(E);
  await denied('une offre en attente ne se publie pas par ecriture directe', `update opportunities set status = 'published' where id = '${OP}'`);
  await denied('une offre ne se marque pas verifiee', `update opportunities set verified = true where id = '${O1}'`);
  await denied('insertion directe d une offre', `insert into opportunities (poster_id, org_name, kind, title, status) values ('${E}', 'Orange', 'stage', 'Direct', 'published')`);
  await denied('abonnement entreprise actif par ecriture directe', `insert into company_subscriptions (owner_id, plan_code, status) values ('${E}', 'entreprise', 'active')`);
  await denied('membre ajoute par ecriture directe', `insert into company_members (owner_id, user_id, role, status) values ('${E}', '${C}', 'admin', 'active')`);
  await as(S);
  await denied('un candidat ne se declare pas recrute', `update opportunity_applications set status = 'hired' where id = '${AP}'`);
  await denied('un etudiant ne cree pas d offre directement', `insert into opportunities (poster_id, org_name, kind, title, status) values ('${S}', 'Moi', 'stage', 'Faux', 'published')`);
  await denied('un etudiant ne devient pas entreprise', `update profiles set role = 'company' where id = '${S}'`);
  await as(C);
  await denied('un client ne cree pas de fiche entreprise directement', `insert into company_profiles (owner_id, company_name, status) values ('${C}', 'Faux', 'approved')`);

  // ---- 2. Entre entreprises
  await as(X);
  await denied('autre entreprise : modifier une offre', `update opportunities set title = 'Pirate' where id = '${O1}'`);
  await denied('autre entreprise : supprimer une offre', `delete from opportunities where id = '${O1}'`);
  await denied('autre entreprise : fermer une offre', `select opp_close('${O1}')`);
  await denied('autre entreprise : decider une candidature', `select opp_application_decide('${AP}', 'hired')`);
  await denied('autre entreprise : voir les candidatures', `select * from opp_applications_for('${O1}')`);
  { const r = (await q(`select opp_stats('${O1}') r`))[0].r; (Array.isArray(r) && r.length === 0) ? good('autre entreprise : statistiques vides') : bad('autre entreprise : statistiques lisibles', JSON.stringify(r).slice(0, 80)); }
  await denied('autre entreprise : inviter', `select opp_invite('${O1}', '${S}', 'x')`);
  await denied('autre entreprise : media', `select opp_media_set('${O1}', '${X}/a.png', 'image')`);
  await denied('autre entreprise : tableau de bord', `select company_dashboard('${E}')`);
  await denied('autre entreprise : fiche privee', `select company_get('${E}')`);
  await denied('autre entreprise : rejoindre l equipe', `insert into company_members (owner_id, user_id, role, status) values ('${E}', '${X}', 'admin', 'active')`);
  await denied('autre entreprise : enregistrer la fiche d une autre', `select company_save('{"company_name":"Pirate"}'::jsonb, '${E}')`);
  const seeCand = await count(`select * from opportunity_applications where opportunity_id = '${O1}'`);
  seeCand === 0 ? good('autre entreprise : aucune candidature lisible') : bad('autre entreprise : candidatures lisibles', String(seeCand));
  const seeCp = await count(`select * from company_profiles where owner_id = '${E}'`);
  console.log('INFO lignes company_profiles de E visibles par X :', seeCp);
  const seeMem = await count(`select * from company_members where owner_id = '${E}'`);
  seeMem === 0 ? good('autre entreprise : membres illisibles') : bad('autre entreprise : membres lisibles', String(seeMem));
  const seeTl = await count(`select * from talent_lists where owner_id = '${E}'`);
  seeTl === 0 ? good('autre entreprise : listes de talents illisibles') : bad('autre entreprise : listes lisibles', String(seeTl));
  const seeInv = await count(`select * from opportunity_invites where opportunity_id = '${O1}'`);
  seeInv === 0 ? good('autre entreprise : invitations illisibles') : bad('autre entreprise : invitations lisibles', String(seeInv));

  // ---- 3. Étudiant et client sur des fonctions d'entreprise
  await as(S);
  await denied('etudiant : publier une offre', `select opp_save('Moi','stage','','Stage test','Douala','onsite','1 mois','unpaid',0,'',null::date,array['a']::text[],'Une description assez longue pour passer les controles.',array['m']::text[],'','','',array[]::text[],'',true,'',false)`);
  await denied('etudiant : enregistrer une fiche entreprise', `select company_save('{"company_name":"Moi"}'::jsonb, null)`);
  await denied('etudiant : candidatures d une offre', `select * from opp_applications_for('${O1}')`);
  await denied('etudiant : liste de talents', `select talent_list_create('Mes talents')`);
  await denied('etudiant : annonce de concours', `select ann_save('{"title":"Concours","organizer":"Moi"}'::jsonb)`);
  await as(C);
  await denied('client : publier une offre', `select opp_save('Moi','stage','','Stage test','Douala','onsite','1 mois','unpaid',0,'',null::date,array['a']::text[],'Une description assez longue pour passer les controles.',array['m']::text[],'','','',array[]::text[],'',true,'',false)`);
  await denied('client : candidatures', `select * from opp_applications_for('${O1}')`);

  // ---- 4. Entreprise non vérifiée / suspendue
  await as(P);
  await denied('entreprise non verifiee : publier une offre', `select opp_save('Pending','stage','','Stage test','Douala','onsite','1 mois','unpaid',0,'',null::date,array['a']::text[],'Une description assez longue pour passer les controles.',array['m']::text[],'','','',array[]::text[],'',true,'',false)`);
  await as(SUS);
  await info('entreprise suspendue : publier une offre', `select opp_save('Suspendu','stage','','Stage test','Douala','onsite','1 mois','unpaid',0,'',null::date,array['a']::text[],'Une description assez longue pour passer les controles.',array['m']::text[],'','','',array[]::text[],'',true,'',false)`);
  await info('entreprise suspendue : fermer une offre', `select opp_close('${O1}')`);

  // ---- 5. Équipe : ce qu'un membre peut faire sur les offres de son entreprise (20261118000100)
  const FIN = U('b2'), VIE = U('b3');
  await db.exec('reset role');
  for (const [id, nm, role] of [[FIN, 'Fin', 'client'], [VIE, 'Vie', 'client']]) await db.exec(`insert into auth.users(id,email) values ('${id}','${nm}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm}@t.cm')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status) values ('${E}', '${FIN}', 'finance', 'active'), ('${E}', '${VIE}', 'viewer', 'active')`);
  await as(T);
  await allowed('membre admin : candidatures de l offre', `select * from opp_applications_for('${O1}')`);
  await allowed('membre admin : statistiques', `select opp_stats('${O1}')`);
  { const r = (await q(`select opp_applications_for('${O1}') r`))[0].r; r[0].can_manage === true ? good('membre admin : can_manage vrai sur les candidatures') : bad('membre admin : can_manage', JSON.stringify(r[0]).slice(0, 120)); }
  await allowed('membre admin : decider une candidature', `select opp_application_decide('${AP}', 'shortlisted')`);
  await allowed('membre admin : recruter un candidat', `select opp_application_decide('${AP}', 'hired')`);
  await allowed('membre admin : fermer une offre', `select opp_close('${O1}')`);
  { const r = (await q(`select opp_my_posted() r`))[0].r; (Array.isArray(r) && r.length === 2) ? good('membre admin : voit les offres de l entreprise') : bad('membre admin : liste des offres', JSON.stringify(r).slice(0, 80)); }
  await denied('membre admin : pas de media avec un chemin au nom du proprietaire', `select opp_media_set('${O1}', '${E}/a.png', 'image')`);
  await as(FIN);
  await allowed('membre finance : lit les candidatures', `select * from opp_applications_for('${O1}')`);
  await allowed('membre finance : lit les statistiques', `select opp_stats('${O1}')`);
  { const r = (await q(`select opp_applications_for('${O1}') r`))[0].r; r[0].can_manage === false ? good('membre finance : can_manage faux') : bad('membre finance : can_manage', JSON.stringify(r[0]).slice(0, 120)); }
  { const r = (await q(`select opp_my_posted() r`))[0].r; (r.length === 2 && r.every(x => x.can_manage === false)) ? good('membre finance : offres listees en lecture seule') : bad('membre finance : liste', JSON.stringify(r).slice(0, 120)); }
  await denied('membre finance : ne decide pas une candidature', `select opp_application_decide('${AP}', 'rejected')`);
  await denied('membre finance : ne ferme pas une offre', `select opp_close('${O1}')`);
  await as(VIE);
  await allowed('membre lecteur : lit les candidatures', `select * from opp_applications_for('${O1}')`);
  await denied('membre lecteur : ne decide pas', `select opp_application_decide('${AP}', 'rejected')`);
  await denied('membre lecteur : ne ferme pas', `select opp_close('${O1}')`);
  await db.exec('reset role');
  await db.exec(`update company_members set status = 'invited' where user_id = '${T}'`);
  await as(T);
  await denied('membre non actif (invitation en attente) : aucun acces', `select opp_close('${O1}')`);
  // ---- 6. Lectures directes : donnees privees d'une entreprise visibles par un etudiant, un client ou un visiteur ?
  await db.exec('reset role');
  await db.exec(`insert into company_documents (owner_id, kind, name, path, mime, size_bytes) values ('${E}', 'registration', 'rccm.pdf', '${E}/rccm.pdf', 'application/pdf', 100)`);
  await db.exec(`insert into talent_lists (owner_id, name) values ('${E}', 'Favoris')`);
  for (const [who, uid, role] of [['etudiant', S, 'authenticated'], ['client', C, 'authenticated'], ['visiteur', '', 'anon']]) {
    await as(uid, role);
    for (const tb of ['company_documents', 'company_members', 'company_subscriptions', 'talent_lists', 'opportunity_invites', 'opportunity_views']) {
      const n = await count(`select * from ${tb}`);
      n === 0 ? good(`${who} : ${tb} illisible`) : bad(`${who} : ${tb} lisible`, String(n));
    }
    const cp = await count(`select phone, contact_name from company_profiles where owner_id = '${E}'`);
    cp === 0 ? good(`${who} : coordonnees privees de l entreprise illisibles`) : bad(`${who} : telephone et contact de l entreprise lisibles par lecture directe`, String(cp));
    const ap = await count(`select * from opportunity_applications where opportunity_id = '${O1}' and applicant_id <> '${uid || S}'`);
    ap === 0 ? good(`${who} : candidatures des autres illisibles`) : bad(`${who} : candidatures des autres lisibles`, String(ap));
  }
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
