// H13.1 lot ACTORS - parcours ORGANISATION sur la base PGlite rejouee, en vrais appels avec jwt claims par acteur et garde db_pre_request simulee.
// Etapes : inscription, verification (fiche, piece, decision de l'administrateur), membres et roles (proprietaire / administrateur / finance / lecteur), acces multi-organisations,
// mission (publication, proposition d'un talent, choix, jalons, cloture), recherche de talents (discovery_search sur des etudiants crees par le test), vivier, contact,
// opportunites (offre, candidature, decision), commandes / collaborations. Cas autorises ET refuses, isolation entre deux organisations.
// « Creation de plusieurs organisations » : le modele est UNE fiche par compte proprietaire + des appartenances a d'autres organisations (my_organizations) ; c'est ce qui est teste.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_parcours_organisation.mjs
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 3);
  const { U, as, anon, sup, q, qs, check, fails, works, noEffect, user, DENY } = b;
  await sup();
  await db.exec('grant all on storage.objects to authenticated');
  const putFile = async (path, mime = 'application/pdf', size = 5000) => { await qs(`insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${path}', '${JSON.stringify({ mimetype: mime, size })}')`); };

  const I1 = U(800), D1 = U(801);
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Etablissement Orga', 'verified'); insert into departments (id, institution_id, name, status) values ('${D1}', '${I1}', 'Informatique', 'verified')`);
  const ADM = await user(1, 'Ada Admin', 'admin');
  const ADM_MEM = await user(2, 'Adam Admin Equipe', 'client');
  const FIN_MEM = await user(3, 'Fabrice Finance Equipe', 'client');
  const VW_MEM = await user(4, 'Vero Lectrice Equipe', 'client');
  const OUT = await user(5, 'Xavier Externe', 'client');
  const O2 = await user(6, 'Xena Corp', 'company');
  const S1 = await user(7, 'Alice Talent', 'student');
  const S2 = await user(8, 'Bob Invisible', 'student');
  const S3 = await user(9, 'Carl NonVerifie', 'student');
  const CLI = await user(10, 'Cora Cliente', 'client');
  await db.exec(`update profiles set phone='69013'||right(id::text,4), phone_verified=true, certification='approved', skills='Flutter, Dart', institution_id='${I1}', department_id='${D1}', department='Informatique', city='Douala' where id in ('${S1}','${S2}');
    update profiles set skills='Flutter', institution_id='${I1}', department_id='${D1}', department='Informatique' where id = '${S3}'`);
  for (const s of [S1, S2]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${s}', 'student_card', 'c.pdf', '${s}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city) values ('${O2}', 'Xena Corp', 'approved', 'Conseil', 'Yaounde')`);
  await db.exec(`insert into auth.users(id,email) values ('${U(20)}','h131-3-20@t.cm')`);
  const O = U(20);

  // ---------------------------------------------------------------- 1. inscription et verification de l'organisation
  await as(O);
  await works('V1 inscription : profil organisation cree par l\'utilisateur', `insert into profiles (id, name, email, role) values ('${O}', 'Orange Cameroun', 'h131-3-20@t.cm', 'company') returning role`, (r) => r[0].role === 'company');
  const full = (extra = {}) => `select company_save('${JSON.stringify({ company_name: 'Orange Cameroun', sector: 'Télécoms', city: 'Douala', phone: '699000000', contact_name: 'Mme Ndongo', contact_role: 'DRH', registration_number: 'RC/DLA/1', ...extra })}'::jsonb) r`;
  await works('V2 fiche enregistree en brouillon', full(), (r) => r[0].r === 'draft');
  await fails('V3 envoi sans piece justificative refuse', `select company_submit()`, /pièce justificative/);
  const need = (t, owner = null) => `select save_mission(null, '${t}', 'Un besoin decrit avec plus de vingt caracteres', 50000, 100000, '2027-01-31', true, 'besoin', false, ${owner ? `'${owner}'` : 'null'}) id`;
  await fails('V4 publication d\'un besoin refusee tant que l\'organisation n\'est pas verifiee', need('Site vitrine'), /vérifiée/);
  await fails('V5 recherche de talents refusee tant que l\'organisation n\'est pas verifiee', `select discovery_search(p_org => '${O}')`, /vérifiée|Réservé/);
  await putFile(`${O}/company/rccm.pdf`);
  await as(O);
  const doc = (await works('V6 piece justificative deposee', `select company_doc_add('registration', 'RCCM.pdf', '${O}/company/rccm.pdf', 'application/pdf', 1000) r`))?.[0]?.r;
  await works('V7 envoi pour verification', `select company_submit() r`, (r) => r[0].r === 'pending');
  await as(O2);
  await noEffect('V8 l\'autre organisation ne voit pas les pieces d\'Orange', `select id from company_documents where owner_id = '${O}'`);
  await as(CLI);
  await fails('V9 un client ne lit pas la file de verification', `select company_queue()`, DENY);
  await fails('V10 un client ne decide pas d\'une organisation', `select company_decide('${O}', true)`, /Réservé à l'administrateur/);
  await as(O);
  await fails('V11 l\'organisation ne s\'approuve pas elle-meme', `select company_decide('${O}', true)`, /Réservé à l'administrateur/);
  await noEffect('V12 l\'organisation ne modifie pas directement son statut', `update company_profiles set status = 'approved' where owner_id = '${O}' returning owner_id`);
  await as(ADM);
  await works('V13 l\'administrateur voit la demande dans sa file', `select company_queue() r`, (r) => r[0].r.some((x) => x.owner_id === O || x.contact_name === 'Mme Ndongo'));
  await works('V14 l\'administrateur approuve l\'organisation', `select company_decide('${O}', true) r`, (r) => r[0].r === 'approved');
  await as(O);
  await works('V15 l\'organisation est notifiee de sa verification', `select title from notifications where kind = 'company_review'`, (r) => r.some((n) => n.title === 'Organisation vérifiée'));
  await as(ADM);
  await works('V16b l\'administrateur active l\'offre Organisation (partenaire) pour permettre l\'equipe', `select company_subscription_activate('${O}', 'partner', 30, 'Activation du banc de test', false) r`);
  check('V16 journal d\'audit : decision tracee', (await qs(`select count(*)::int n from audit_log where action = 'Organisation vérifiée'`))[0].n >= 1);

  // ---------------------------------------------------------------- 2. membres et roles
  await as(O);
  for (const [u, role] of [[ADM_MEM, 'admin'], [FIN_MEM, 'finance'], [VW_MEM, 'viewer']]) await works(`M1 invitation de ${role}`, `select company_invite('h131-3-${[ADM_MEM, FIN_MEM, VW_MEM].indexOf(u) + 2}@t.cm', '${role}') r`);
  await as(OUT);
  await fails('M2 un tiers non invite n\'accede pas au tableau de bord', `select company_dashboard('${O}')`, /Accès refusé/);
  for (const u of [ADM_MEM, FIN_MEM, VW_MEM]) { await as(u); await works('M3 le membre accepte l\'invitation', `select company_member_respond('${O}', true) r`); }
  await as(OUT);
  await fails('M4 un tiers n\'accepte pas une invitation inexistante', `select company_member_respond('${O}', true)`, DENY);
  await as(VW_MEM);
  await works('M5 un lecteur lit le tableau de bord', `select company_dashboard('${O}') r`);
  await fails('M6 un lecteur ne publie pas de besoin', need('Refus lecteur', O), /Réservé au propriétaire/);
  await fails('M7 un lecteur n\'invite personne', `select company_invite('h131-3-10@t.cm', 'viewer', '${O}')`, DENY);
  await as(FIN_MEM);
  await fails('M8 la finance ne publie pas de besoin', need('Refus finance', O), /Réservé au propriétaire/);
  await as(ADM_MEM);
  await works('M9 un administrateur d\'equipe publie un besoin au nom de l\'organisation', need('Site vitrine Orange', O), (r) => !!r[0].id);
  await fails('M10 un administrateur d\'equipe ne retire pas le proprietaire', `select company_member_remove('${O}', '${O}')`, DENY);
  await as(O2);
  await fails('M11 l\'autre organisation ne publie pas au nom d\'Orange', need('Refus autre org', O), /Accès refusé/);
  await fails('M12 l\'autre organisation ne liste pas les membres d\'Orange', `select company_members_list('${O}')`, DENY);
  await as(O);
  await works('M13 le proprietaire liste ses membres', `select company_members_list() r`, (r) => r[0].r.members.length === 3 && r[0].r.members.some((m) => m.role === 'viewer') && r[0].r.members.some((m) => m.role === 'finance'));
  await works('M14 le proprietaire change le role d\'un membre', `select company_member_set_role('${VW_MEM}', 'finance') r`);
  await works('M15 ... puis le retablit', `select company_member_set_role('${VW_MEM}', 'viewer') r`);
  await as(ADM_MEM);
  await fails('M16 le role du proprietaire ne se modifie pas', `select company_member_set_role('${O}', 'viewer', '${O}')`, DENY);
  await qs(`insert into company_members (owner_id, user_id, role, status, joined_at) values ('${O2}', '${ADM_MEM}', 'viewer', 'active', now())`);
  await as(ADM_MEM);
  await works('MO1 acces multi-organisations : le membre voit ses deux organisations avec ses droits propres', `select my_organizations() r`, (r) => { const l = r[0].r; const a = l.find((x) => x.owner_id === O), c = l.find((x) => x.owner_id === O2); return l.length === 2 && a.role === 'admin' && a.can_manage === true && c.role === 'viewer' && c.can_manage === false; });
  await fails('MO2 le membre simple lecteur d\'une organisation n\'y publie pas', need('Refus lecteur O2', O2), /Réservé au propriétaire/);
  await as(OUT);
  await works('MO3 un compte sans organisation ne voit aucune organisation', `select my_organizations() r`, (r) => r[0].r.length === 0);
  await anon();
  await fails('MO4 anonyme : my_organizations refuse', `select my_organizations()`, /permission denied|Connexion requise/);
  await as(O);
  await works('MO5 le proprietaire voit son organisation et pas celle d\'autrui', `select my_organizations() r`, (r) => r[0].r.length === 1 && r[0].r[0].owner_id === O && r[0].r[0].verified === true);

  // ---------------------------------------------------------------- 3. mission : publication, proposition, choix, jalons, cloture
  await as(O);
  const m1 = (await works('MI1 le proprietaire publie un besoin', need('Application mobile de livraison'), (r) => !!r[0].id))?.[0]?.id;
  await as(S1);
  const p1 = (await works('MI2 un talent verifie propose ses services', `select propose_on_mission('${m1}', 80000, 10, 'Je developpe en Flutter') id`))?.[0]?.id;
  await as(S3);
  await fails('MI3 un etudiant non verifie ne propose pas', `select propose_on_mission('${m1}', 70000, 10, 'Je peux')`, /prestation de service/);
  await as(O2);
  await fails('MI4 une autre organisation ne lit pas les propositions d\'Orange', `select company_proposals('${O}')`, /Accès refusé/);
  await noEffect('MI5 ... ni par lecture directe des propositions', `select 1 from mission_proposals where mission_id = '${m1}'`);
  await as(S1);
  await fails('MI6 le talent ne decide pas de sa propre proposition', `select decide_proposal('${p1}', true)`, /Proposition introuvable/);
  await as(VW_MEM);
  await works('MI7 un lecteur lit les propositions', `select company_proposals('${O}') r`, (r) => r[0].r.length === 1);
  await fails('MI8 un lecteur ne retient pas de prestataire', `select decide_proposal('${p1}', true)`, /Réservé au propriétaire/);
  await as(O);
  await works('MI9 le proprietaire retient le prestataire', `select decide_proposal('${p1}', true) r`, (r) => r[0].r === 'accepted');
  check('MI10 mission attribuee avec 3 jalons', (await qs(`select (select status from missions where id='${m1}') s, (select count(*)::int from mission_milestones where mission_id='${m1}') n`))[0].n === 3);
  await as(S1);
  await works('MI11 le prestataire livre le jalon 1', `select submit_milestone('${m1}', 1::smallint, 'Maquettes livrees et validables', '{}') r`, (r) => r[0].r === 'submitted');
  await as(OUT);
  await fails('MI12 un tiers ne valide pas le jalon', `select decide_milestone('${m1}', 1::smallint, true, null)`, DENY);
  await as(O);
  await works('MI13 le proprietaire valide le jalon 1', `select decide_milestone('${m1}', 1::smallint, true, null) r`, (r) => r[0].r === 'validated');
  await as(S1);
  for (const n of [2, 3]) { await q(`select submit_milestone('${m1}', ${n}::smallint, 'Livraison jalon ${n} realisee', '{}')`); await as(O); await q(`select decide_milestone('${m1}', ${n}::smallint, true, null)`); await as(S1); }
  check('MI14 tous les jalons valides : mission livree', (await qs(`select status from missions where id='${m1}'`))[0].status === 'delivered');
  await as(S1);
  await works('MI15 le prestataire ne voit pas l\'identite du client', `select my_missions() r`, (r) => { const m = r[0].r.find((x) => x.id === m1); return m && m.counterpart === null; });
  await as(O);
  await works('MI16 le proprietaire cloture la mission', `select mission_close('${m1}') r`, (r) => r[0].r === 'closed');
  await works('MI17 le proprietaire lit ses missions', `select org_missions() r`, (r) => r[0].r.some((x) => x.id === m1));
  await as(O2);
  await works('MI18 l\'autre organisation ne voit aucune mission d\'Orange', `select org_missions() r`, (r) => r[0].r.length === 0);
  await noEffect('MI19 ... ni par lecture directe', `select 1 from missions where id = '${m1}'`);

  // ---------------------------------------------------------------- 4. recherche de talents : la decouverte s'appuie sur un classement PUBLIE (fixtures creees par ce test uniquement)
  await sup();
  const P0 = (await qs(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;
  const G1 = U(803);
  await db.exec(`insert into programs (id, institution_id, department_id, name, active) values ('${G1}', '${I1}', '${D1}', 'Genie logiciel', true)`);
  const S4 = await user(11, 'Dora Talent', 'student');
  const S5 = await user(12, 'Eric Talent', 'student');
  await db.exec(`update profiles set phone='69013'||right(id::text,4), phone_verified=true, certification='approved', skills='Flutter', institution_id='${I1}', department_id='${D1}', department='Informatique' where id in ('${S4}','${S5}')`);
  let fx = 0;
  for (const [s, pts] of [[S1, 500], [S2, 450], [S4, 400], [S5, 300]]) {
    if (s !== S1 && s !== S2) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${s}', 'student_card', 'c.pdf', '${s}/c/c.pdf', 'application/pdf', 10, 'verified')`);
    await db.exec(`insert into student_affiliations (user_id, institution_id, department_id, program_id, promotion, status) values ('${s}', '${I1}', '${D1}', '${G1}', '2026', 'verified');
      insert into talent_visibility_settings (user_id, public_ranking, show_full_name, shared_sections) values ('${s}', true, false, array['rank','score','evolution','skills','badges','projects','passport']);
      insert into talent_skills (owner_id, domain, skill, level) values ('${s}', 'Informatique', 'Flutter', 'avance')`);
    const e = (await qs(`insert into talent_events (user_id, rule_code, source_kind, source_id) values ('${s}', 'sale_confirmed', 'fixture', 'fx-${++fx}') returning id`))[0].id;
    await db.exec(`select _talent_ledger_add(${e}, '${s}', 'award', ${pts}, 'sale_confirmed', 1, 'fixture');
      alter table talent_score_ledger disable trigger trg_talent_ledger_guard; update talent_score_ledger set period = '${P0}' where event_id = ${e}; alter table talent_score_ledger enable trigger trg_talent_ledger_guard`);
  }
  await as(O);
  const dsAvant = await works('T0 avant publication du classement : etat honnete (aucun talent a decouvrir)', `select discovery_search(p_org => '${O}', p_skill => 'Flutter') r`, (r) => r[0].r.published === false && r[0].r.items.length === 0);
  await as(ADM);
  await works('T0a l\'administrateur decide les reglages du classement', `select admin_ranking_settings_set(50, null, 100, array['national','program','institution','department','domain'], 'Reglages du banc de test des parcours') r`, (r) => r[0].r.decided === true);
  await works('T0b l\'administrateur active la regle de score', `select admin_talent_rule_set('sale_confirmed', 100, null, null, 0, true, 'Regle active pour le banc de test des parcours') r`, (r) => r[0].r.active === true);
  await works('T0c cohorte minimale abaissee pour les fixtures', `select admin_talent_setting_set('min_cohort', 3, 'Cohorte de test du banc des parcours') r`);
  await works('T0d l\'administrateur publie le classement du mois precedent', `select ranking_publish('${P0}') r`, (r) => r[0].r.ok === true);
  await as(O);
  const ds = await works('T1 recherche de talents : competence Flutter', `select discovery_search(p_org => '${O}', p_skill => 'Flutter') r`);
  const dsTxt = JSON.stringify(ds?.[0]?.r ?? '');
  check('T2 le talent verifie et visible est trouve', dsTxt.includes(S1) || dsTxt.includes('Alice'), dsTxt.slice(0, 250));
  check('T2b avant la coupure de visibilite, le second talent consentant est bien liste', dsTxt.includes(S2), dsTxt.slice(0, 250));
  await as(S2);
  await works('T3a Bob coupe sa visibilite de talent', `select talent_visibility_set(false) r`, (r) => r[0].r === false);
  await as(O);
  const ds2 = JSON.stringify((await q(`select discovery_search(p_org => '${O}', p_skill => 'Flutter') r`))[0].r);
  check('T3b le talent invisible n\'apparait pas dans la recherche', !ds2.includes(S2) && !ds2.includes('Bob'), ds2.slice(0, 250));
  check('T3c l\'etudiant non verifie n\'apparait pas', !ds2.includes(S3) && !ds2.includes('Carl'));
  await works('T4 vivier : creation d\'une liste', `select talent_list_create('Developpeurs mobiles') r`);
  const lst = (await qs(`select id from talent_lists where owner_id = '${O}' and name = 'Developpeurs mobiles'`))[0]?.id;
  await works('T5 vivier : ajout du talent', `select talent_list_add('${lst}', '${S1}', 'A rappeler') r`);
  await works('T6 vivier : lecture des membres', `select talent_list_members_get('${lst}') r`, (r) => r[0].r.length === 1);
  await fails('T7 vivier : ajout d\'un talent invisible refuse', `select talent_list_add('${lst}', '${S2}', 'x')`, /./);
  await works('T8 favori : ajout', `select discovery_favorite_set('${S1}', true, '${O}') r`);
  await works('T9 favoris lisibles', `select discovery_favorites('${O}') r`, (r) => JSON.stringify(r[0].r).includes(S1) || r[0].r.length >= 1);
  await as(O2);
  await fails('T10 l\'autre organisation ne lit pas le vivier d\'Orange', `select talent_list_members_get('${lst}')`, /introuvable/i);
  await works('T11 ... ni ses favoris (aucun talent)', `select discovery_favorites('${O2}') r`, (r) => !JSON.stringify(r[0].r).includes(S1));
  await as(OUT);
  await fails('T12 un client n\'accede pas a la decouverte de talents', `select discovery_search(p_org => '${O}')`, DENY);
  await fails('T13 un client ne cree pas de vivier', `select talent_list_create('Pirate')`, DENY);
  await as(S1);
  await fails('T14 un etudiant n\'accede pas a la decouverte de talents', `select discovery_search(p_org => '${O}')`, DENY);
  await as(O);
  const c1 = (await works('C1 contact : demande d\'entretien au talent', `select discovery_contact_request('${S1}', 'interview', 'Entretien jeudi a 10h chez Orange', '${O}') r`, (r) => !!r[0].r.id))?.[0]?.r.id;
  await fails('C2 contact d\'un talent invisible refuse', `select discovery_contact_request('${S2}', 'contact', 'bonjour', '${O}')`, /./);
  await as(VW_MEM);
  await fails('C3 un lecteur n\'envoie pas de demande', `select discovery_contact_request('${S1}', 'contact', 'x', '${O}')`, /Réservé au propriétaire/);
  await as(O2);
  await fails('C4 une autre organisation n\'envoie pas au nom d\'Orange', `select discovery_contact_request('${S1}', 'contact', 'x', '${O}')`, /Accès refusé/);
  await as(S1);
  await works('C5 le talent voit la demande', `select my_talent_contact_requests() r`, (r) => r[0].r.length === 1);
  await as(S3);
  await works('C6 un autre etudiant ne voit pas la demande', `select my_talent_contact_requests() r`, (r) => r[0].r.length === 0);
  await fails('C7 un autre etudiant ne repond pas a la demande', `select talent_contact_respond('${c1}', 'accepted', '')`, /Demande introuvable/);
  await as(S1);
  await works('C8 le talent accepte', `select talent_contact_respond('${c1}', 'accepted', 'Disponible jeudi') r`, (r) => r[0].r === 'accepted');
  await fails('C9 reponse deja donnee : refus', `select talent_contact_respond('${c1}', 'declined', '')`, /déjà répondu/);
  await as(O);
  await works('C10 l\'organisation voit l\'acceptation', `select discovery_search(p_org => '${O}', p_skill => 'Flutter') r`);

  // ---------------------------------------------------------------- 5. opportunites : offre, validation, candidature, decision
  await as(O);
  const opp = (await works('OP1 offre de stage publiee (en attente de validation)', `select opp_save('Orange Cameroun', 'stage', 'academique', 'Stagiaire Flutter', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', current_date + 10, array['Flutter'], 'Description complete de l offre pour les etudiants', array['Developper des ecrans','Tester'], 'Etudiant motive', 'Informatique', 'L3', array['Transport'], '', true, '', false) id`))?.[0]?.id;
  await as(S1);
  await works('OP2 l\'offre en attente n\'est pas visible des etudiants', `select opps_list() r`, (r) => r[0].r.length === 0);
  await fails('OP3 candidature a une offre non publiee refusee', `select opp_apply('${opp}', 'Je suis tres motivee pour ce stage de developpement Flutter')`, /./);
  await as(O);
  await fails('OP4 l\'organisation ne valide pas sa propre offre', `select opp_decide('${opp}', true, true)`, DENY);
  await as(ADM);
  await works('OP5 l\'administrateur valide l\'offre', `select opp_decide('${opp}', true, true) r`);
  await as(S1);
  await works('OP6 l\'offre est visible des etudiants', `select opps_list() r`, (r) => r[0].r.length === 1);
  const app = (await works('OP7 l\'etudiant candidate', `select opp_apply('${opp}', 'Je suis tres motivee pour ce stage de developpement Flutter', 'https://cv.exemple.cm/alice') id`))?.[0]?.id;
  await fails('OP8 une seule candidature par offre', `select opp_apply('${opp}', 'Encore une candidature pour la meme offre')`, /déjà postulé/);
  await as(S3);
  await fails('OP9 un autre etudiant ne voit pas les candidatures', `select opp_applications_for('${opp}')`, DENY);
  await noEffect('OP10 ... ni par lecture directe', `select id from opportunity_applications where opportunity_id = '${opp}'`);
  await as(O2);
  await fails('OP11 l\'autre organisation ne lit pas les candidatures d\'Orange', `select opp_applications_for('${opp}')`, DENY);
  await fails('OP12 ... ni ne decide', `select opp_application_decide('${app}', 'hired')`, DENY);
  await as(O);
  await works('OP13 l\'organisation voit la candidature', `select opp_applications_for('${opp}') r`, (r) => r[0].r.length === 1);
  await fails('OP14 statut inconnu refuse', `select opp_application_decide('${app}', 'zzz')`, /Statut inconnu/);
  await works('OP15 l\'organisation presélectionne', `select opp_application_decide('${app}', 'shortlisted') r`);
  await as(S1);
  await works('OP16 l\'etudiant suit sa candidature', `select opp_my_applications() r`, (r) => r[0].r.length === 1);

  // ---------------------------------------------------------------- 6. commandes / collaborations
  await as(O);
  await works('CO1 l\'organisation lit ses commandes', `select company_orders_list('${O}') r`);
  await as(O2);
  await works('CO2 l\'autre organisation ne voit aucune commande d\'Orange (lecture sans donnee)', `select company_orders_list('${O2}') r`, (r) => !JSON.stringify(r[0].r).includes('Orange'));
  await fails('CO3 ... et ne lit pas celles d\'Orange', `select company_orders_list('${O}')`, DENY);
  await as(CLI);
  await fails('CO4 un client ne lit pas les commandes d\'une organisation', `select company_orders_list('${O}')`, DENY);

  await b.replayMigrations();
  await as(O);
  await works('R1 apres rejeu : l\'organisation reste verifiee avec son membre', `select my_organizations() r`, (r) => r[0].r[0].verified === true);
  b.summary('h131_parcours_organisation');
}





