// Scénario PGlite du lot H1 (Organisation) : migrations 20261120010000 à 20261120010400.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./act_h1.mjs
// Prouve : types d'organisation (référentiel public), choix du type à l'inscription, « other » non attribuable à l'inscription, justificatifs et champs
// exigés PAR TYPE (association, ONG, commerciale…), refus des pièces étrangères au type, décision de l'administrateur, changement de type d'une fiche approuvée,
// page publique (type, mission, jamais RCCM/NIU), forfaits par type (solidaire), fusion des profils « other » dans Organisation (migration rejouable),
// refus pour anonyme / suspendu / autres rôles, libellés « Organisation ».
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => { if (s === 'reset role') return rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)"); return rawExec(s); };
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const C1 = U(71), ASSO = U(72), ONG = U(73), STU = U(74), KLI = U(75), ADM = U(76), DEP = U(77), SUSP = U(78), OLD = U(79), OLD2 = U(80), NEWC = U(81), NEWK = U(82), NEWO = U(83), INST = U(84);
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const putFile = async (p, mime = 'application/pdf', size = 4000) => { await db.exec('reset role'); await db.exec(`insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${p}', '${JSON.stringify({ mimetype: mime, size })}')`); };
  const save = (uid, extra = {}) => `select company_save('${JSON.stringify({ company_name: 'Organisation Test', sector: 'Éducation', city: 'Douala', phone: '699000000', contact_name: 'Mme Ndongo', contact_role: 'Présidente', ...extra }).replace(/'/g, "''")}'::jsonb) r`;
  const addDoc = (uid, kind, name) => `select company_doc_add('${kind}', '${name}.pdf', '${uid}/company/${name}.pdf', 'application/pdf', 1000) r`;

  await db.exec('reset role');
  const users = [[C1, 'Orange Cameroun', 'company'], [ASSO, 'Association Espoir', 'company'], [ONG, 'ONG Verte', 'company'], [STU, 'Awa Etudiante', 'student'], [KLI, 'Kevin Client', 'client'],
    [ADM, 'Admin Global', 'admin'], [DEP, 'Dept Info', 'dept'], [SUSP, 'Suspendue Asso', 'company'], [INST, 'Institution Pub', 'company']];
  for (const [id, nm, role] of users) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${SUSP}'`);

  // ============================================================ référentiel public
  await as(null, 'anon');
  const types = (await q(`select org_types_list() r`))[0].r;
  check('référentiel : 8 types lisibles sans connexion', types.length === 8 && ['entreprise_commerciale', 'association', 'ong', 'cooperative', 'fondation', 'institution', 'structure_partenaire', 'autre_reconnue'].every((c) => types.some((t) => t.code === c)));
  check('référentiel : chaque type exige au moins une pièce', types.every((t) => t.docs.some((d) => d.required)));
  check('référentiel : seule l\'entreprise commerciale est commerciale', types.filter((t) => t.commercial).length === 1 && types.find((t) => t.commercial).code === 'entreprise_commerciale');
  check('référentiel : association exige récépissé et statuts', (() => { const a = types.find((t) => t.code === 'association'); return a.docs.find((d) => d.kind === 'receipt').required && a.docs.find((d) => d.kind === 'statutes').required && a.registration_required && a.mission_required; })());
  await fails('référentiel : tables fermées en lecture directe', `select * from org_types`, /permission denied/);
  await fails('anonyme : pas de choix de type', `select company_set_type('association')`, /permission denied|Connexion requise/);
  await fails('anonyme : pas de lecture du type', `select company_org_type()`, /permission denied|Connexion requise/);

  // ============================================================ inscription : « other » n'est plus attribuable
  await db.exec('reset role');
  await db.exec(`insert into auth.users(id,email) values ('${NEWC}','nc@t.cm'), ('${NEWK}','nk@t.cm'), ('${NEWO}','no@t.cm')`);
  await as(NEWO);
  await fails('inscription : le rôle « other » est refusé', `insert into profiles(id, name, role, email) values ('${NEWO}', 'Nouvelle Asso', 'other', 'no@t.cm')`, /row-level security/);
  await fails('inscription : le rôle administrateur reste refusé', `insert into profiles(id, name, role, email) values ('${NEWO}', 'Pirate', 'admin', 'no@t.cm')`, /row-level security/);
  await as(NEWC);
  check('inscription : le rôle « company » (Organisation) est accepté', (await q(`insert into profiles(id, name, role, email) values ('${NEWC}', 'Nouvelle Association', 'company', 'nc@t.cm') returning role::text r`))[0].r === 'company');
  await as(NEWK);
  check('inscription : le rôle client est accepté', (await q(`insert into profiles(id, name, role, email) values ('${NEWK}', 'Nouveau Client', 'client', 'nk@t.cm') returning role::text r`))[0].r === 'client');

  // ============================================================ choix du type à l'inscription
  await as(NEWC);
  check('type choisi à l\'inscription : fiche brouillon créée avec le type', (await q(`select company_set_type('association') r`))[0].r === 'draft');
  const nt = (await q(`select company_org_type() r`))[0].r;
  check('lecture du type : association, brouillon, exigences non satisfaites', nt.org_type === 'association' && nt.label === 'Association' && nt.requirements.length === 2 && nt.requirements.every((r) => !r.satisfied) && nt.missing_fields.length >= 3);
  await fails('type inconnu refusé', `select company_set_type('startup')`, /Type d'organisation inconnu/);
  check('même type : sans effet', (await q(`select company_set_type('association') r`))[0].r === 'draft');
  check('changement de type d\'un brouillon', (await q(`select company_set_type('ong') r`))[0].r === 'draft' && (await q(`select company_set_type('association') r`))[0].r === 'draft');
  for (const [name, uid] of [['étudiant', STU], ['client', KLI], ['département', DEP], ['suspendu', SUSP]]) {
    await as(uid);
    await fails(`${name} : ne choisit pas de type d'organisation`, `select company_set_type('association')`, /Réservé aux organisations/);
  }
  await as(STU);
  await fails('étudiant : n\'enregistre pas de fiche d\'organisation', save(STU), /Réservé aux organisations/);
  await as(SUSP);
  await fails('suspendu : n\'enregistre pas de fiche', save(SUSP), /Réservé aux organisations/);

  // ============================================================ association : champs et pièces exigés par type
  await as(ASSO);
  check('association : fiche enregistrée avec son type', (await q(save(ASSO, { org_type: 'association' })))[0].r === 'draft');
  await fails('association : récépissé et mission exigés avant l\'envoi', `select company_submit()`, /Numéro du récépissé[\s\S]*mission/);
  check('association : numéro de récépissé et mission enregistrés', (await q(save(ASSO, { org_type: 'association', registration_number: 'N°123/RDA/J06', mission: 'Insertion des jeunes diplômés' })))[0].r === 'draft');
  await fails('association : sans pièce, envoi refusé', `select company_submit()`, /pièce justificative[\s\S]*Récépissé de déclaration/);
  await putFile(`${ASSO}/company/recepisse.pdf`); await putFile(`${ASSO}/company/statuts.pdf`); await putFile(`${ASSO}/company/niu.pdf`); await putFile(`${ASSO}/company/rccm.pdf`);
  await as(ASSO);
  await fails('association : le NIU n\'est pas une pièce de ce type', addDoc(ASSO, 'tax', 'niu'), /ne correspond pas au type/);
  await fails('association : le RCCM n\'est pas une pièce de ce type', addDoc(ASSO, 'registration', 'rccm'), /ne correspond pas au type/);
  await fails('pièce de nature inconnue refusée', addDoc(ASSO, 'passeport', 'recepisse'), /Type de pièce inconnu/);
  check('association : récépissé accepté', !!(await q(addDoc(ASSO, 'receipt', 'recepisse')))[0].r);
  let req = (await q(`select company_org_type() r`))[0].r.requirements;
  check('association : exigence récépissé satisfaite, statuts encore manquants', req.find((r) => r.kinds.includes('receipt')).satisfied === true && req.find((r) => r.kinds.includes('statutes')).satisfied === false);
  await fails('association : sans les statuts, envoi refusé', `select company_submit()`, /Statuts/);
  check('association : statuts acceptés', !!(await q(addDoc(ASSO, 'statutes', 'statuts')))[0].r);
  check('association : envoi pour vérification accepté', (await q(`select company_submit() r`))[0].r === 'pending');
  await fails('association : type non modifiable pendant l\'examen', `select company_set_type('ong')`, /en cours de vérification/);
  await fails('association : fiche non modifiable pendant l\'examen', save(ASSO, { org_type: 'association', city: 'Yaoundé' }), /en cours de vérification/);
  await db.exec('reset role');
  check('notification à l\'administrateur : « Organisation à vérifier »', (await q(`select count(*)::int n from notifications where user_id = '${ADM}' and title = 'Organisation à vérifier'`))[0].n === 1);

  // ============================================================ ONG et institution : pièces propres
  await as(ONG);
  await q(save(ONG, { org_type: 'ong', registration_number: 'AGR-2026-77', mission: 'Santé communautaire' }));
  await putFile(`${ONG}/company/agrement.pdf`); await putFile(`${ONG}/company/statuts.pdf`); await putFile(`${ONG}/company/recepisse.pdf`);
  await as(ONG);
  check('ONG : le récépissé seul ne suffit pas (agrément requis)', !!(await q(addDoc(ONG, 'receipt', 'recepisse')))[0].r);
  await fails('ONG : récépissé seul : envoi refusé (agrément et statuts)', `select company_submit()`, /Agrément ou autorisation d'exercer/);
  await q(addDoc(ONG, 'authorization', 'agrement')); await q(addDoc(ONG, 'statutes', 'statuts'));
  check('ONG : agrément + statuts : envoi accepté', (await q(`select company_submit() r`))[0].r === 'pending');

  await as(INST);
  await q(save(INST, { org_type: 'institution' }));
  await putFile(`${INST}/company/decret.pdf`); await putFile(`${INST}/company/mandat.pdf`);
  await as(INST);
  await fails('institution : pas de mission obligatoire mais acte de création exigé', `select company_submit()`, /pièce justificative[\s\S]*Acte de création/);
  await q(addDoc(INST, 'decree', 'decret'));
  await fails('institution : le mandat du représentant est aussi exigé', `select company_submit()`, /Mandat du représentant/);
  await q(addDoc(INST, 'mandate', 'mandat'));
  check('institution : acte + mandat : envoi accepté', (await q(`select company_submit() r`))[0].r === 'pending');

  // ============================================================ entreprise commerciale : RCCM ou NIU, comportement historique conservé
  await as(C1);
  check('commerciale : fiche par défaut de type entreprise commerciale', (await q(save(C1, { company_name: 'Orange Cameroun', sector: 'Télécoms', registration_number: 'RC/DLA/1', tax_number: 'M0123456789' })))[0].r === 'draft');
  check('commerciale : type par défaut', (await q(`select company_org_type() r`))[0].r.org_type === 'entreprise_commerciale');
  await putFile(`${C1}/company/niu.pdf`); await putFile(`${C1}/company/statuts.pdf`);
  await as(C1);
  await fails('commerciale : les statuts ne sont pas une pièce de ce type', addDoc(C1, 'statutes', 'statuts'), /ne correspond pas au type/);
  await fails('commerciale : sans pièce, envoi refusé', `select company_submit()`, /pièce justificative/);
  await q(addDoc(C1, 'tax', 'niu'));
  check('commerciale : le NIU suffit (RCCM ou NIU), envoi accepté', (await q(`select company_submit() r`))[0].r === 'pending');

  // ============================================================ décision de l'administrateur et page publique
  await as(ASSO);
  await fails('un compte non admin ne décide pas', `select company_decide('${ASSO}', true)`, /Réservé à l'administrateur/);
  await as(DEP);
  await fails('le département ne décide pas', `select company_decide('${ASSO}', true)`, /Réservé à l'administrateur/);
  await as(ADM);
  const queue = (await q(`select company_queue() r`))[0].r;
  check('file admin : type et exigences visibles', queue.length === 4 && queue.find((x) => x.owner_id === ASSO).org_type === 'association' && queue.find((x) => x.owner_id === ASSO).org_config.label === 'Association' && queue.find((x) => x.owner_id === ASSO).requirements.every((r) => r.satisfied));
  check('décision : association approuvée', (await q(`select company_decide('${ASSO}', true) r`))[0].r === 'approved');
  await db.exec('reset role');
  check('notification « Organisation vérifiée »', (await q(`select count(*)::int n from notifications where user_id = '${ASSO}' and title = 'Organisation vérifiée'`))[0].n === 1);
  check('audit : « Organisation vérifiée »', (await q(`select count(*)::int n from audit_log where action = 'Organisation vérifiée' and target = 'Organisation Test'`))[0].n >= 1);
  check('la certification du compte suit la vérification', (await q(`select certification::text c from profiles where id = '${ASSO}'`))[0].c === 'approved');
  await as(null, 'anon');
  const pub = (await q(`select company_public('${ASSO}') r`))[0].r;
  check('page publique (visiteur) : type, libellé du type et mission', pub.org_type === 'association' && pub.org_type_label === 'Association' && pub.mission === 'Insertion des jeunes diplômés' && pub.commercial === false && pub.sector_label === 'Domaine d\'action');
  check('page publique : jamais RCCM, NIU, téléphone ni interlocuteur', !('registration_number' in pub) && !('tax_number' in pub) && !('phone' in pub) && !('contact_name' in pub));
  check('page publique : fiche non approuvée invisible au visiteur', (await q(`select company_public('${C1}') r`))[0].r === null);
  await as(KLI);
  check('page publique : un client voit la fiche approuvée', (await q(`select company_public('${ASSO}') r`))[0].r.verified === true);
  check('page publique : un client ne voit pas une fiche non approuvée', (await q(`select company_public('${ONG}') r`))[0].r === null);
  await as(ASSO);
  const mine = (await q(`select company_get() r`))[0].r;
  check('fiche : le titulaire voit son type, ses numéros et la configuration', mine.org_type === 'association' && mine.registration_number === 'N°123/RDA/J06' && mine.org_config.code === 'association' && mine.requirements.length === 2);
  const dash = (await q(`select company_dashboard() r`))[0].r;
  check('tableau de bord : type d\'organisation et statut', dash.org_type === 'association' && dash.org_type_label === 'Association' && dash.commercial === false && dash.status === 'approved');

  // ============================================================ changement de nature d'une fiche approuvée
  await as(ASSO);
  check('fiche approuvée : changement de type => nouvelle vérification', (await q(`select company_set_type('fondation') r`))[0].r === 'pending');
  await db.exec('reset role');
  check('changement de type : certification retirée et administrateur prévenu', (await q(`select certification::text c from profiles where id = '${ASSO}'`))[0].c === 'revoked'
    && (await q(`select count(*)::int n from notifications where user_id = '${ADM}' and title = 'Organisation à revérifier'`))[0].n === 1);
  await as(ADM);
  check('décision : la fondation est approuvée à son tour', (await q(`select company_decide('${ASSO}', true) r`))[0].r === 'approved');
  await as(ASSO);
  check('modifier le NIU d\'une fiche approuvée : nouvelle vérification', (await q(save(ASSO, { org_type: 'fondation', registration_number: 'N°123/RDA/J06', mission: 'Insertion des jeunes diplômés', tax_number: 'M999' })))[0].r === 'pending');

  // ============================================================ forfaits par type
  await as(ADM);
  await q(`select company_decide('${C1}', true)`);
  await q(`select company_decide('${ONG}', true)`);
  await as(ONG);
  const planOng = (await q(`select company_plans_list() r`))[0].r.map((p) => p.code);
  check('forfaits : une ONG voit le forfait solidaire', planOng.includes('solidaire') && planOng.includes('free') && planOng.includes('partner'));
  await as(C1);
  const planC = (await q(`select company_plans_list() r`))[0].r.map((p) => p.code);
  check('forfaits : une entreprise commerciale ne voit pas le forfait solidaire', !planC.includes('solidaire') && planC.includes('pro') && planC.includes('partner'));
  await fails('forfaits : demande refusée à une entreprise commerciale', `select company_subscription_request('solidaire')`, /ne concerne pas ce type d'organisation/);
  await fails('forfaits : paiement refusé à une entreprise commerciale', `select company_plan_checkout('solidaire')`, /ne concerne pas ce type d'organisation/);
  await as(ONG);
  check('forfaits : l\'ONG demande le forfait solidaire', (await q(`select company_subscription_request('solidaire') r`))[0].r === 'requested');
  await as(C1);
  check('forfaits : l\'entreprise commerciale demande le forfait Organisation', (await q(`select company_subscription_request('pro') r`))[0].r === 'requested');
  await db.exec('reset role');
  await db.exec(`delete from company_subscriptions`);
  try { await db.exec(`insert into company_subscriptions (owner_id, plan_code) values ('${C1}', 'solidaire')`); check('forfaits : déclencheur de sécurité sur l\'audience', false, 'aurait dû échouer'); } catch (e) { check('forfaits : déclencheur de sécurité sur l\'audience', /ne concerne pas/.test(e.message), e.message); }
  check('forfait historique renommé « Organisation »', (await q(`select name from company_plans where code = 'pro'`))[0].name === 'Organisation');
  check('quotas : le forfait solidaire n\'est pas inférieur au forfait Organisation', (await q(`select (s.max_needs >= p.max_needs and s.max_offers >= p.max_offers and s.max_contests >= p.max_contests and s.price_fcfa <= p.price_fcfa) ok from company_plans s, company_plans p where s.code = 'solidaire' and p.code = 'pro'`))[0].ok === true);
  await as(ADM);
  await fails('forfait : type inconnu refusé à l\'édition', `select company_plan_save('{"code":"test_h1","name":"Test","audience_types":["startup"]}'::jsonb)`, /Type d'organisation inconnu/);
  check('forfait : l\'administrateur cible des types', (await q(`select company_plan_save('{"code":"test_h1","name":"Test H1","price_fcfa":5000,"audience_types":["ong"]}'::jsonb) r`))[0].r === 'test_h1');
  await as(ASSO);
  await fails('forfait : édition réservée à l\'administrateur', `select company_plan_save('{"code":"x1","name":"X1"}'::jsonb)`, /Réservé à l'administrateur/);

  // ============================================================ publication : même porte de vérification pour tous les types
  await as(ONG);
  check('ONG vérifiée : publie un besoin', (await q(`select save_mission(null, 'Besoin ONG', 'Nous cherchons un appui pour cartographier nos activités', 50000, 100000, '2027-01-31', true) id`)).length === 1);
  await db.exec('reset role');
  check('étiquette de besoin : « Organisation non vérifiée » pour un compte company sans fiche approuvée', (await q(`select _need_poster('${INST}') p`))[0].p.label.endsWith('Organisation non vérifiée'));

  // ============================================================ fusion du rôle « other » (migration rejouable)
  await db.exec(`insert into auth.users(id,email) values ('${OLD}','old1@t.cm'), ('${OLD2}','old2@t.cm');
    insert into profiles(id,name,role,email) values ('${OLD}', 'Université de Canada', 'other', 'old1@t.cm'), ('${OLD2}', 'Collectif Sans Fiche', 'other', 'old2@t.cm');
    insert into company_profiles (owner_id, company_name, status) values ('${OLD}', 'Université de Canada', 'approved');`);
  const here = path.dirname(fileURLToPath(import.meta.url));
  const mig = fs.readFileSync(path.join(here, '..', '..', 'migrations', '20261120010300_h1_fusion_autre_dans_organisation.sql'), 'utf8');
  await db.exec(mig);
  const old = await q(`select p.id, p.role::text r, c.org_type, c.status from profiles p left join company_profiles c on c.owner_id = p.id where p.id in ('${OLD}', '${OLD2}') order by p.id`);
  check('fusion : « other » devient Organisation (role company)', old.every((x) => x.r === 'company'));
  check('fusion : type « autre_reconnue » pour la fiche existante (statut conservé)', old[0].org_type === 'autre_reconnue' && old[0].status === 'approved');
  check('fusion : fiche brouillon créée pour le compte sans fiche', old[1].org_type === 'autre_reconnue' && old[1].status === 'draft');
  check('fusion : aucun profil « other » ne subsiste', (await q(`select count(*)::int n from profiles where role::text = 'other'`))[0].n === 0);
  await db.exec(mig);
  check('fusion : rejouable sans effet', (await q(`select count(*)::int n from company_profiles where owner_id in ('${OLD}', '${OLD2}')`))[0].n === 2);
  await as(OLD2);
  check('ancien « other » : fonctions d\'organisation conservées (fiche lisible, type autre_reconnue)', (await q(`select company_org_type() r`))[0].r.org_type === 'autre_reconnue');
  await putFile(`${OLD2}/company/att.pdf`);
  await as(OLD2);
  await q(save(OLD2, { company_name: 'Collectif Sans Fiche' }));
  check('ancien « other » : toutes les pièces reconnues sont acceptées (autre organisation reconnue)', !!(await q(addDoc(OLD2, 'attestation', 'att')))[0].r);
  check('ancien « other » : envoi accepté avec une attestation', (await q(`select company_submit() r`))[0].r === 'pending');
  await as(ADM);
  await q(`select admin_set_account('${KLI}', 'other', false)`);
  await db.exec('reset role');
  const viaAdmin = (await q(`select p.role::text r, c.org_type, c.status from profiles p left join company_profiles c on c.owner_id = p.id where p.id = '${KLI}'`))[0];
  check('administration : attribuer « other » donne Organisation (type autre_reconnue, fiche brouillon)', viaAdmin.r === 'company' && viaAdmin.org_type === 'autre_reconnue' && viaAdmin.status === 'draft');
  await as(STU);
  await fails('un non-admin ne change pas de rôle (garde conservée)', `update profiles set role = 'other' where id = '${STU}'`, /permission denied|réservée à l'administrateur|Modification du rôle/);

  // ============================================================ messages « Organisation »
  await as(C1);
  await db.exec('reset role');
  const msgs = (await q(`select count(*)::int n from pg_proc where pronamespace = 'public'::regnamespace and prosrc ilike '%Votre entreprise doit%'`))[0].n;
  check('libellés : plus de « Votre entreprise doit être vérifiée » dans les fonctions', msgs === 0);

  console.log(`\nH1 : ${ok} OK, ${ko} ECHEC`);
}
