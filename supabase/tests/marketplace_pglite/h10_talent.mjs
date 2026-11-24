// Lot H10 / TALENT : matching explicable, graphe de compétences, Passeport Talent 360°, vivier d'organisation, recrutement après présélection.
// Migrations 20261126060000 à 20261126060400. Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h10_talent.mjs
import fs from 'fs';
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000093${String(n).padStart(2, '0')}`;
  const ADM = id(1), ORG = id(2), ORG2 = id(3), MEMA = id(4), MEMV = id(5), MEMF = id(6), OUT = id(7), ST1 = id(8), ST2 = id(9), ST3 = id(10), ST4 = id(11), CLI = id(12), ORGX = id(13);
  const mail = (uid) => `u${uid.slice(-2)}@t.cm`;
  let cur = null;
  const as = async (uid) => { cur = { uid }; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claims', '', false); set role authenticated`); };
  const anon = async () => { cur = null; await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false); set role anon`); };
  const sup = async () => { await db.exec("reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claims', '', false)"); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { const save = cur; await sup(); const r = await q(sql); if (save) await as(save.uid); else await anon(); return r; };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql) => { try { const r = await q(sql); check(name, true); return r; } catch (e) { check(name, false, e.message); return null; } };
  const jq = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const DENY = /Réservé|réservé|Accès refusé|Connexion requise|permission denied|introuvable|Offre introuvable|Liste introuvable|non autorisé/i;

  // ============================================================ comptes
  await db.exec('reset role');
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [ORG, 'Org Une', 'company'], [ORG2, 'Org Deux', 'company'], [MEMA, 'Mem Admin', 'client'], [MEMV, 'Mem Lecteur', 'client'],
    [MEMF, 'Mem Finance', 'client'], [OUT, 'Out Siderr', 'client'], [ST1, 'Etu Un', 'student'], [ST2, 'Etu Deux', 'student'], [ST3, 'Etu Trois', 'student'], [ST4, 'Etu Quatre', 'student'],
    [CLI, 'Cli Client', 'client'], [ORGX, 'Org Nonvalide', 'company']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${ORG}', 'Orange', 'approved'), ('${ORG2}', 'Camtel', 'approved'), ('${ORGX}', 'Brouillon SA', 'draft')`);
  await db.exec(`insert into company_members (owner_id, user_id, role, status, joined_at) values ('${ORG}', '${MEMA}', 'admin', 'active', now()), ('${ORG}', '${MEMV}', 'viewer', 'active', now()), ('${ORG}', '${MEMF}', 'finance', 'active', now())`);
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) select id, 'student_card', 'c', id || '/c.pdf', 'application/pdf', 10, 'verified' from profiles where role = 'student'`);
  await db.exec(`update profiles set skills = 'Python', department = 'Génie informatique', bio = 'Etudiant' where id = '${ST3}'`);
  await db.exec(`update profiles set department = 'Génie informatique' where id in ('${ST1}', '${ST2}', '${ST4}')`);
  // preuves de ST1 : un justificatif vérifié, une réalisation, un certificat
  await db.exec(`insert into user_documents (id, owner_id, kind, name, path, mime, size_bytes, status) values ('00000000-0000-0000-0000-00000000d001', '${ST1}', 'certificate', 'cert flutter', '${ST1}/flutter.pdf', 'application/pdf', 10, 'verified'),
    ('00000000-0000-0000-0000-00000000d002', '${ST2}', 'certificate', 'cert', '${ST2}/cert2.pdf', 'application/pdf', 10, 'pending')`);
  await db.exec(`insert into talent_skills (owner_id, domain, job, skill, level, years, proof_document_id) values
    ('${ST1}', 'Informatique', 'Développeur mobile', 'Flutter', 'avance', 3, '00000000-0000-0000-0000-00000000d001'),
    ('${ST1}', 'Informatique', 'Développeur mobile', 'API REST', 'intermediaire', 2, null),
    ('${ST2}', 'Informatique', 'Développeur mobile', 'Flutter', 'intermediaire', 1, '00000000-0000-0000-0000-00000000d002'),
    ('${ST2}', 'Informatique', 'Développeur mobile', 'Swift / iOS', 'avance', 2, null)`);
  await db.exec(`insert into portfolio_items (owner_id, kind, title, category, description) values ('${ST1}', 'realisation', 'Appli de caisse Flutter', 'Mobile', 'Application Flutter publiée')`);
  await db.exec(`insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, issued_by, fingerprint) values ('BE-CERT-0000A001', 'talent', 'Certification Flutter', '${ST1}', 'Etu Un', '${ADM}', 'fp1'), ('BE-CERT-0000A002', 'talent', 'Ancien certificat', '${ST1}', 'Etu Un', '${ADM}', 'fp2')`);
  await db.exec(`update certificates set revoked = true, revoked_reason = 'test' where code = 'BE-CERT-0000A002'`);
  await db.exec(`insert into student_talent_prefs (user_id, visible_to_recruiters) values ('${ST4}', false) on conflict (user_id) do update set visible_to_recruiters = false`);
  await db.exec(`insert into student_availability (user_id, kinds) values ('${ST1}', array['internship'])`);
  const O = '00000000-0000-0000-0000-00000000f001';
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status, skills, department_target) values ('${O}', '${ORG}', 'Orange', 'stage', 'Stage Flutter', 'published', array['Flutter','API REST'], 'Génie informatique')`);
  await db.exec(`insert into opportunity_applications (opportunity_id, applicant_id, message) values ('${O}', '${ST1}', 'Je candidate a ce stage Flutter'), ('${O}', '${ST2}', 'Je candidate a ce stage Flutter'), ('${O}', '${ST3}', 'Je candidate a ce stage Flutter')`);

  // ============================================================ A. graphe de compétences
  await as(ADM);
  check('A1 graphe vide à la livraison', (await qs(`select count(*)::int n from skill_graph_edges`))[0].n === 0);
  const sid = async (name) => (await qs(`select id from skill_catalog where skill = '${name.replace(/'/g, "''")}' and status = 'approved' limit 1`))[0].id;
  const kotlin = await sid('Kotlin / Android'), swift = await sid('Swift / iOS'), flutter = await sid('Flutter'), rn = await sid('React Native'), api = await sid('API REST');
  const e1 = await rpc(`skill_graph_link('${kotlin}', '${swift}', 'proche_de', 0.8, 'Mobile natif')`);
  check('A2 l\'administrateur ajoute une relation « proche_de »', !!e1);
  await fails('A3 « proche_de » en double (sens inverse) refusé', `select skill_graph_link('${swift}', '${kotlin}', 'proche_de', 0.5, null)`, /existe déjà/);
  await works('A4 « prerequis_de » : API REST avant Flutter', `select skill_graph_link('${api}', '${flutter}', 'prerequis_de', 1, null)`);
  await fails('A5 cycle de prérequis refusé', `select skill_graph_link('${flutter}', '${api}', 'prerequis_de', 1, null)`, /cycle/);
  await fails('A6 relation avec soi-même refusée', `select skill_graph_link('${flutter}', '${flutter}', 'proche_de', 0.5, null)`, /différentes/);
  await fails('A7 poids hors bornes refusé', `select skill_graph_link('${rn}', '${flutter}', 'proche_de', 2, null)`, /poids/i);
  await fails('A8 compétence inconnue refusée', `select skill_graph_link('${rn}', '${ST1}', 'proche_de', 0.5, null)`, /introuvable/);
  check('A9 chaque ajout est dans le journal d\'audit', (await qs(`select count(*)::int n from audit_log where category = 'Talents'`))[0].n === 2);
  await as(ORG);
  await fails('A10 une entreprise ne modifie pas le graphe', `select skill_graph_link('${rn}', '${flutter}', 'proche_de', 0.5, null)`, /Réservé/);
  await fails('A11 une entreprise ne liste pas l\'administration du graphe', `select skill_graph_admin_list()`, /Réservé/);
  await as(ST2);
  const nb = await rpc(`skill_graph_neighbors('${kotlin}')`);
  check('A12 voisinage : Swift est proche de Kotlin', nb.close.length === 1 && nb.close[0].skill === 'Swift / iOS' && Number(nb.close[0].weight) === 0.8, JSON.stringify(nb));
  const nf = await rpc(`skill_graph_neighbors('${flutter}')`);
  check('A13 voisinage : API REST est prérequis de Flutter', nf.prerequisites.length === 1 && nf.prerequisites[0].skill === 'API REST', JSON.stringify(nf));
  const cl = await rpc(`my_close_skills()`);
  check('A14 pistes de progression de ST2 : Kotlin / Android (proche de Swift)', cl.length === 1 && cl[0].skill === 'Kotlin / Android' && cl[0].because === 'Swift / iOS', JSON.stringify(cl));
  await anon();
  await fails('A15 anonyme : graphe refusé', `select skill_graph_neighbors('${kotlin}')`, /Connexion requise|permission denied/);

  // ============================================================ B. critères structurés
  await as(ORG2);
  await fails('B1 une autre entreprise ne définit pas les critères', `select opp_criteria_set('${O}', '[]'::jsonb)`, /Offre introuvable/);
  await as(MEMV);
  await fails('B2 le lecteur d\'équipe ne définit pas les critères', `select opp_criteria_set('${O}', '[]'::jsonb)`, /Offre introuvable/);
  await as(MEMA);
  await fails('B3 critère invalide : niveau inconnu', `select opp_criteria_set('${O}', ${jq([{ skill: 'Flutter', min_level: 'gourou' }])})`, /Niveau minimal inconnu/);
  await fails('B4 critères en double refusés', `select opp_criteria_set('${O}', ${jq([{ skill: 'Flutter' }, { skill: 'flutter' }])})`, /double/);
  const crit = await rpc(`opp_criteria_set('${O}', ${jq([{ skill: 'Flutter', importance: 'obligatoire', min_level: 'avance', min_years: 2 }, { skill: 'API REST' }, { skill: 'Kotlin / Android' }, { skill: 'Python' }])})`);
  check('B5 l\'administrateur d\'équipe définit 4 critères', crit.structured === true && crit.criteria.length === 4 && crit.criteria[0].skill === 'Flutter' && crit.criteria[0].importance === 'obligatoire', JSON.stringify(crit));
  check('B6 les compétences historiques de l\'offre restent alignées', (await qs(`select cardinality(skills)::int n from opportunities where id = '${O}'`))[0].n === 4);
  await as(ST3);
  check('B7 un candidat lit les critères d\'une offre publiée', (await rpc(`opp_criteria_get('${O}')`)).criteria.length === 4);

  // ============================================================ C. matching explicable
  await as(ST1);
  const m1 = await rpc(`opp_match_explain('${O}')`);
  const c = (m, s) => m.criteria.find((x) => x.skill === s);
  check('C1 ST1 : Flutter satisfait (avancé, 3 ans), justificatif vérifié', c(m1, 'Flutter').status === 'satisfait' && c(m1, 'Flutter').proof.verified === true && c(m1, 'Flutter').level === 'avance', JSON.stringify(c(m1, 'Flutter')));
  check('C2 ST1 : API REST satisfait sans justificatif', c(m1, 'API REST').status === 'satisfait' && c(m1, 'API REST').proof.has === false);
  check('C3 ST1 : Kotlin et Python manquants, obligatoire respecté', m1.missing.length === 2 && m1.missing.includes('Python') && m1.mandatory_unmet.length === 0 && m1.meets_all_mandatory === true, JSON.stringify(m1.missing));
  check('C4 preuves utilisées : justificatif vérifié, réalisation, certificat (non révoqué)', m1.proofs_used.some((p) => p.kind === 'justificatif' && p.state === 'verifie') && m1.proofs_used.some((p) => p.kind === 'realisation') && m1.proofs_used.some((p) => p.kind === 'certificat' && p.count === 1), JSON.stringify(m1.proofs_used));
  check('C5 raisons et recommandations présentes, aucune décision automatique', m1.reasons.length >= 4 && m1.recommendations.some((r) => r.kind === 'competence_manquante') && m1.automatic_decision === false && /ne décide de rien/.test(m1.notice));
  check('C6 le score historique est renvoyé inchangé (clé legacy)', m1.legacy && typeof m1.legacy.score === 'number' && m1.calibrated === false && m1.engine === 'explicable_v1');
  check('C7 score = somme des parties affichées', m1.score === Math.min(100, m1.parts.competences.points + m1.parts.preuves.points + m1.parts.filiere.points + m1.parts.disponibilite.points), JSON.stringify(m1.parts));
  await as(ST2);
  const m2 = await rpc(`opp_match_explain('${O}')`);
  check('C8 ST2 : Flutter partiel (niveau insuffisant), obligatoire non satisfait', c(m2, 'Flutter').status === 'partiel' && c(m2, 'Flutter').level_ok === false && m2.mandatory_unmet.includes('Flutter') && m2.meets_all_mandatory === false, JSON.stringify(c(m2, 'Flutter')));
  check('C9 ST2 : Kotlin « proche » via Swift (graphe), pas satisfait', c(m2, 'Kotlin / Android').status === 'proche' && c(m2, 'Kotlin / Android').close_to.skill === 'Swift / iOS' && m2.close.includes('Kotlin / Android'));
  check('C10 ST2 : API REST (prérequis de Flutter) signalé manquant parmi les prérequis de Flutter', c(m2, 'Flutter').prerequisites_missing.includes('API REST'), JSON.stringify(c(m2, 'Flutter')));
  check('C11 ST2 : justificatif non vérifié ne compte pas comme preuve vérifiable', m2.parts.preuves.points === 0 && m2.proofs_used.some((p) => p.kind === 'justificatif' && p.state === 'depose_non_verifie'), JSON.stringify(m2.proofs_used));
  check('C12 le classement ST1 > ST2 est expliqué', m1.score > m2.score);
  await as(ST3);
  const m3 = await rpc(`opp_match_explain('${O}')`);
  check('C13 ST3 (texte libre) : Python retrouvé par le profil, niveau non demandé', c(m3, 'Python').status === 'satisfait' && c(m3, 'Python').source === 'profil_texte' && c(m3, 'Flutter').status === 'manquant', JSON.stringify(c(m3, 'Python')));
  const gaps = await rpc(`talent_skill_gaps('${O}')`);
  check('C14 lacunes de ST3 : Flutter, API REST, Kotlin', gaps.missing.length === 3 && gaps.gaps.length === 3 && gaps.automatic_decision === false, JSON.stringify(gaps.missing));
  // offre sans critère structuré : compétences de l'offre = critères souhaités (compatibilité)
  const O2 = '00000000-0000-0000-0000-00000000f002';
  await sup();
  await db.exec(`insert into opportunities (id, poster_id, org_name, kind, title, status, skills) values ('${O2}', '${ORG}', 'Orange', 'stage', 'Stage libre', 'published', array['Flutter'])`);
  await as(ST1);
  const m4 = await rpc(`opp_match_explain('${O2}')`);
  check('C15 sans critère structuré : critère souhaité tiré de opportunities.skills', m4.criteria.length === 1 && m4.criteria[0].importance === 'souhaite' && m4.criteria[0].status === 'satisfait');
  check('C16 compatibilité : opp_my_match et opp_applications_for inchangés', (await rpc(`opp_my_match('${O}')`)).skills_wanted === 4 && true);
  await as(ST3);
  await fails('C17 un candidat ne lit pas l\'explication d\'un autre', `select opp_match_explain('${O}', '${ST1}')`, /Offre introuvable/);
  // recruteur
  await as(ORG);
  const r1 = await rpc(`opp_match_explain('${O}', '${ST1}')`);
  check('C18 le recruteur voit le détail d\'un candidat (compétences nommées, manquantes)', r1.detail === true && r1.missing.length === 2 && r1.name === 'Etu U.', JSON.stringify([r1.detail, r1.missing, r1.name]));
  const rk = await rpc(`opp_applications_ranked('${O}')`);
  check('C19 classement des candidatures : ST1, ST2 puis ST3 (ST3 avec Python seulement)', rk.items.length === 3 && rk.items[0].applicant_id === ST1 && rk.automatic_decision === false, JSON.stringify(rk.items.map((x) => [x.applicant_id.slice(-2), x.score])));
  check('C20 le classement ne change AUCUN statut de candidature', (await qs(`select count(*)::int n from opportunity_applications where opportunity_id = '${O}' and status = 'sent'`))[0].n === 3);
  await as(MEMV);
  check('C21 le lecteur d\'équipe lit le classement (lecture seule)', (await rpc(`opp_applications_ranked('${O}')`)).items.length === 3);
  await as(ORG2);
  await fails('C22 une autre entreprise : classement refusé', `select opp_applications_ranked('${O}')`, /Offre introuvable/);
  await fails('C23 une autre entreprise : explication refusée', `select opp_match_explain('${O}', '${ST1}')`, /Offre introuvable/);
  await as(OUT);
  await fails('C24 un tiers : explication refusée', `select opp_match_explain('${O}', '${ST1}')`, /Offre introuvable/);
  await anon();
  await fails('C25 anonyme : explication refusée', `select opp_match_explain('${O}')`, /Connexion requise|permission denied/);
  // talent non candidat : détail seulement si la rubrique « competences » est partagée avec les organisations
  await as(ORG);
  const n1 = await rpc(`opp_match_explain('${O2}', '${ST1}')`);
  check('C26 talent non candidat, rubrique privée : noms seulement, niveaux ignorés', n1.detail === false && n1.criteria[0].status === 'satisfait' && n1.criteria[0].level === null && n1.criteria[0].source === 'profil_texte', JSON.stringify(n1.criteria[0]));
  await as(ST1);
  await q(`select talent_passport_share_set('competences', 'organisations')`);
  await as(ORG);
  const n2 = await rpc(`opp_match_explain('${O2}', '${ST1}')`);
  check('C27 rubrique partagée avec les organisations : niveaux et preuves utilisés', n2.detail === true && n2.criteria[0].level === 'avance' && n2.criteria[0].proof.verified === true);
  await as(MEMA);
  check('C28 un membre d\'équipe de l\'organisation voit le même détail', (await rpc(`opp_match_explain('${O2}', '${ST1}')`)).detail === true);
  await as(ST1);
  await q(`select talent_passport_share_set('competences', 'prive')`);
  await as(ORG);
  check('C29 retrait du partage : effet immédiat', (await rpc(`opp_match_explain('${O2}', '${ST1}')`)).detail === false);
  await fails('C30 talent invisible aux recruteurs : introuvable', `select opp_match_explain('${O2}', '${ST4}')`, /Talent introuvable/);
  await fails('C31 talent sans rapport (client) : introuvable', `select opp_match_explain('${O2}', '${CLI}')`, /Talent introuvable/);
  await sup();
  console.log('--- A à C terminés');

  const nt = async (uid, kind) => (await qs(`select count(*)::int n from notifications where user_id = '${uid}' and kind = '${kind}'`))[0].n;
  const sec = (p, s) => p.sections[s];

  // ============================================================ D. Passeport Talent 360° : partage par rubrique, défaut privé
  await as(ST1);
  const d1 = await rpc(`talent_passport_360()`);
  check('D1 le propriétaire voit tout son passeport', d1.own === true && sec(d1, 'competences').shared === true && sec(d1, 'competences').items.length === 2 && sec(d1, 'realisations').items.length === 1, JSON.stringify(sec(d1, 'competences')));
  check('D2 par défaut, toutes les rubriques sont privées', Object.values(d1.shares).every((v) => v === 'prive'), JSON.stringify(d1.shares));
  await as(ORG);
  const d3 = await rpc(`talent_passport_360('${ST1}')`);
  check('D3 une organisation approuvée ne voit aucune rubrique privée', Object.values(d3.sections).every((s) => s.shared === false) && d3.own === false && d3.shares === null, JSON.stringify(d3.sections));
  await as(CLI);
  check('D4 un client ne voit aucune rubrique privée', Object.values((await rpc(`talent_passport_360('${ST1}')`)).sections).every((s) => s.shared === false));
  await as(ADM);
  check('D5 l\'administrateur n\'a aucun droit particulier sur une rubrique privée', Object.values((await rpc(`talent_passport_360('${ST1}')`)).sections).every((s) => s.shared === false));
  await anon();
  await fails('D6 anonyme : passeport refusé', `select talent_passport_360('${ST1}')`, /Connexion requise|permission denied/);
  await fails('D7 anonyme : partage refusé', `select talent_passport_share_set('certificats', 'organisations')`, /Connexion requise|permission denied/);
  await as(ST1);
  await fails('D8 rubrique inconnue refusée', `select talent_passport_share_set('banque', 'organisations')`, /Rubrique inconnue/);
  await fails('D9 choix de partage inconnu refusé', `select talent_passport_share_set('certificats', 'public')`, /Choix de partage inconnu/);
  await works('D10 partage « organisations » des certificats', `select talent_passport_share_set('certificats', 'organisations')`);
  await as(ORG);
  const d11 = sec(await rpc(`talent_passport_360('${ST1}')`), 'certificats');
  check('D11 organisation approuvée : certificats partagés, certificat révoqué absent', d11.shared === true && d11.items.length === 1 && d11.items[0].code === 'BE-CERT-0000A001', JSON.stringify(d11));
  await as(ORG2);
  check('D12 une autre organisation approuvée voit aussi la rubrique partagée', sec(await rpc(`talent_passport_360('${ST1}')`), 'certificats').shared === true);
  await as(ORGX);
  check('D13 organisation non approuvée : rubrique non partagée', (await rpc(`talent_passport_360('${ST1}')`)) === null || sec(await rpc(`talent_passport_360('${ST1}')`), 'certificats').shared === false);
  await as(CLI);
  check('D14 client : la rubrique « organisations » reste fermée', sec(await rpc(`talent_passport_360('${ST1}')`), 'certificats').shared === false);
  await as(ST1);
  await q(`select talent_passport_share_set('competences', 'connectes')`);
  await as(CLI);
  const d15 = sec(await rpc(`talent_passport_360('${ST1}')`), 'competences');
  check('D15 « connectes » : un client voit les compétences, justificatif vérifié, description masquée', d15.shared === true && d15.items.length === 2 && d15.items.find((x) => x.skill === 'Flutter').proof_verified === true && d15.items.every((x) => x.description === ''), JSON.stringify(d15));
  await as(ST1);
  await q(`select talent_passport_identity_set('Développeur mobile junior', 'Je construis des applications Flutter.')`);
  await q(`select talent_passport_share_set('identite', 'organisations')`);
  await q(`select talent_passport_share_set('disponibilites', 'organisations')`);
  await as(ORG);
  const d16 = await rpc(`talent_passport_360('${ST1}')`);
  check('D16 identité professionnelle et disponibilités partagées avec les organisations', sec(d16, 'identite').headline === 'Développeur mobile junior' && sec(d16, 'disponibilites').availability.kinds[0] === 'internship', JSON.stringify(sec(d16, 'identite')));
  check('D17 la rubrique « missions » reste privée', sec(d16, 'missions').shared === false);
  await as(ST1);
  await q(`select talent_passport_share_set('certificats', 'prive')`);
  await as(ORG);
  check('D18 retrait du partage : effet immédiat', sec(await rpc(`talent_passport_360('${ST1}')`), 'certificats').shared === false);
  await as(ST4);
  await q(`select talent_passport_share_set('certificats', 'organisations')`);
  await as(ORG);
  const d19 = await rpc(`talent_passport_360('${ST4}')`);
  check('D19 talent non proposé aux recruteurs : rubrique « organisations » inaccessible', d19 === null || sec(d19, 'certificats').shared === false);
  await as(ST2);
  check('D20 isolation : les partages d\'un talent ne sont pas ceux d\'un autre', Object.values((await rpc(`talent_passport_share_get()`))).every((v) => v === 'prive'));
  await as(ST1);
  await q(`select talent_passport_share_set('competences', 'prive')`);
  await q(`select talent_passport_share_set('identite', 'prive')`);
  await q(`select talent_passport_share_set('disponibilites', 'prive')`);
  console.log('--- D terminé');

  // ============================================================ E. Vivier rattaché à l'organisation
  await as(ORG);
  const fav0 = await rpc(`pool_lists_get()`);
  check('E1 la liste « Favoris » est créée pour l\'organisation', fav0.length === 1 && fav0[0].name === 'Favoris' && fav0[0].count === 0);
  const L1 = await rpc(`pool_list_create('Stage 2027')`);
  await works('E2 ajout de ST1 avec une note', `select pool_list_add('${L1}', '${ST1}', 'Très bon profil mobile')`);
  await works('E3 ajout de ST2', `select pool_list_add('${L1}', '${ST2}', '')`);
  const m0 = await rpc(`pool_list_members_get('${L1}')`);
  check('E4 la note est réellement enregistrée et relue', m0.length === 2 && m0.find((x) => x.id === ST1).note === 'Très bon profil mobile', JSON.stringify(m0));
  check('E5 compatibilité : l\'ancien RPC renvoie la même liste', (await rpc(`talent_list_members_get('${L1}')`)).length === 2 && (await rpc(`talent_lists_get()`)).length === 2);
  await fails('E6 un étudiant invisible aux recruteurs ne s\'ajoute pas', `select pool_list_add('${L1}', '${ST4}', '')`, /Étudiant introuvable/);
  await fails('E7 un client ne s\'ajoute pas', `select pool_list_add('${L1}', '${CLI}', '')`, /Étudiant introuvable/);
  await fails('E8 nom de liste en double (casse ignorée)', `select pool_list_create('stage 2027')`, /déjà ce nom/);
  await fails('E9 la liste Favoris ne se supprime pas', `select pool_list_delete('${fav0[0].id}')`, /Favoris/);
  // équipe : le vivier est partagé
  await as(MEMA);
  const e10 = await rpc(`pool_lists_get('${ORG}')`);
  check('E10 l\'administrateur d\'équipe voit le vivier de l\'organisation', e10.length === 2 && e10.find((x) => x.name === 'Stage 2027').count === 2, JSON.stringify(e10));
  await works('E11 l\'administrateur d\'équipe écrit dans le vivier de l\'organisation', `select pool_list_add('${L1}', '${ST3}', 'Ajouté par l''équipe', '${ORG}')`);
  const e11 = await rpc(`pool_list_members_get('${L1}', '${ORG}')`);
  check('E12 les ajouts de l\'équipe sont visibles du propriétaire', e11.length === 3);
  await as(ORG);
  check('E13 le propriétaire voit l\'ajout de l\'équipe', (await rpc(`pool_list_members_get('${L1}')`)).length === 3);
  await as(MEMV);
  check('E14 le lecteur lit le vivier', (await rpc(`pool_list_members_get('${L1}', '${ORG}')`)).length === 3);
  await fails('E15 le lecteur n\'écrit pas', `select pool_list_create('Pirate', '${ORG}')`, /Réservé/);
  await fails('E16 le lecteur n\'ajoute pas de note', `select pool_note_add('${ST1}', 'note pirate', '${ORG}')`, /Réservé/);
  await as(MEMF);
  await fails('E17 « finance » n\'a aucun accès au vivier', `select pool_lists_get('${ORG}')`, /Accès refusé/);
  await as(OUT);
  await fails('E18 un tiers n\'accède pas au vivier d\'une organisation', `select pool_lists_get('${ORG}')`, /Accès refusé/);
  await fails('E19 un tiers n\'a pas de vivier propre', `select pool_lists_get()`, /./);
  await as(ORG2);
  await fails('E20 une autre organisation n\'accède pas au vivier', `select pool_list_members_get('${L1}', '${ORG}')`, /Accès refusé/);
  check('E21 une autre organisation a son propre vivier, vide', (await rpc(`pool_lists_get()`)).every((l) => l.count === 0));
  await fails('E22 une autre organisation ne lit pas la liste par son identifiant', `select pool_list_members_get('${L1}')`, /Liste introuvable/);
  await as(ORGX);
  await fails('E23 organisation non approuvée : pas de vivier', `select pool_lists_get()`, /./);
  await anon();
  await fails('E24 anonyme refusé', `select pool_lists_get()`, /Connexion requise|permission denied/);
  await fails('E25 anonyme refusé (anciens RPC)', `select talent_lists_get()`, /Connexion requise|permission denied/);

  // notes, étiquettes, étapes
  await as(MEMA);
  const N1 = await rpc(`pool_note_add('${ST1}', 'Entretien téléphonique très positif', '${ORG}')`);
  check('E26 note interne ajoutée par un membre d\'équipe', !!N1);
  await as(ORG);
  const nn = await rpc(`pool_notes_get('${ST1}')`);
  check('E27 le propriétaire lit la note signée et datée', nn.length === 1 && nn[0].body === 'Entretien téléphonique très positif' && /Mem/.test(nn[0].author) && !!nn[0].created_at, JSON.stringify(nn));
  await as(ORG2);
  await fails('E28 une autre organisation ne lit pas les notes', `select pool_notes_get('${ST1}', '${ORG}')`, /Accès refusé/);
  await fails('E29 les notes d\'un talent hors vivier sont introuvables', `select pool_notes_get('${ST1}')`, /introuvable/);
  await as(ST1);
  await fails('E30 le talent ne lit pas les notes qui le concernent (table fermée)', `select * from talent_pool_notes`, /permission denied|row-level security/);
  await as(ORG);
  await fails('E31 note sur un talent hors vivier refusée', `select pool_note_add('${CLI}', 'note', null)`, /introuvable/);
  const t1 = await rpc(`pool_talent_set('${ST1}', 'preselectionne', array['Mobile','Stage','mobile'])`);
  check('E32 étape et étiquettes enregistrées (doublons fusionnés)', t1.stage === 'preselectionne' && t1.tags.length === 2, JSON.stringify(t1));
  await fails('E33 étape inconnue refusée', `select pool_talent_set('${ST1}', 'embauche_auto', '{}')`, /Étape inconnue/);
  await fails('E34 plus de 8 étiquettes refusé', `select pool_talent_set('${ST1}', null, array['aa','bb','cc','dd','ee','ff','gg','hh','ii'])`, /8 étiquettes/);
  await works('E35 étape « favori » pour ST2', `select pool_talent_set('${ST2}', 'favori', array['Mobile'])`);
  const mm = await rpc(`pool_list_members_get('${L1}')`);
  check('E36 la liste renvoie étape, étiquettes, notes et rappels', mm.find((x) => x.id === ST1).stage === 'preselectionne' && mm.find((x) => x.id === ST1).notes_count === 1 && mm.find((x) => x.id === ST1).tags.length === 2);
  // recherche
  check('E37 recherche par étape', (await rpc(`pool_search(p_stage => 'preselectionne')`)).map((x) => x.id).join() === ST1);
  check('E38 recherche par étiquette (casse ignorée)', (await rpc(`pool_search(p_tag => 'MOBILE')`)).length === 2);
  check('E39 recherche par compétence', (await rpc(`pool_search(p_skill => 'python')`)).map((x) => x.id).join() === ST3);
  check('E40 recherche par disponibilité', (await rpc(`pool_search(p_available => true)`)).map((x) => x.id).join() === ST1);
  check('E41 niveau minimal : rubrique « compétences » privée => aucun résultat', (await rpc(`pool_search(p_skill => 'Flutter', p_min_level => 'avance')`)).length === 0);
  await as(ST1);
  await q(`select talent_passport_share_set('competences', 'organisations')`);
  await as(ORG);
  check('E42 niveau minimal : rubrique partagée => ST1 trouvé', (await rpc(`pool_search(p_skill => 'Flutter', p_min_level => 'avance')`)).map((x) => x.id).join() === ST1);
  check('E43 niveau minimal trop élevé : personne', (await rpc(`pool_search(p_skill => 'Flutter', p_min_level => 'expert')`)).length === 0);
  await fails('E44 niveau inconnu refusé', `select pool_search(p_min_level => 'gourou')`, /Niveau inconnu/);
  await as(MEMV);
  check('E45 le lecteur recherche dans le vivier de l\'organisation', (await rpc(`pool_search(p_org => '${ORG}', p_stage => 'favori')`)).map((x) => x.id).join() === ST2);
  // historique de contact
  await as(MEMA);
  await works('E46 contact manuel enregistré', `select pool_contact_log('${ST1}', 'appel', 'Appel de 10 minutes, disponible en juillet', '${ORG}')`);
  await fails('E47 contact dans le futur refusé', `select pool_contact_log('${ST1}', 'appel', 'Appel', '${ORG}', now() + interval '3 days')`, /futur/);
  await fails('E48 canal inconnu refusé', `select pool_contact_log('${ST1}', 'pigeon', 'Appel de test', '${ORG}')`, /Canal inconnu/);
  await db.exec(`reset role; insert into talent_contacts (sender_id, target_id, kind, message) values ('${ORG}', '${ST1}', 'contact', 'Bonjour via la plateforme')`);
  await as(ORG);
  const hc = await rpc(`pool_contacts_get('${ST1}')`);
  check('E49 historique : contact manuel + message de la plateforme', hc.length === 2 && hc.some((x) => x.source === 'manuel') && hc.some((x) => x.source === 'plateforme'), JSON.stringify(hc));
  await as(ORG2);
  await fails('E50 une autre organisation ne lit pas l\'historique', `select pool_contacts_get('${ST1}', '${ORG}')`, /Accès refusé/);
  // rappels
  await as(MEMA);
  const R1 = await rpc(`pool_reminder_set('${ST1}', current_date, 'Recontacter pour juillet', '${ORG}')`);
  await fails('E51 rappel dans le passé refusé', `select pool_reminder_set('${ST1}', current_date - 1, 'x', '${ORG}')`, /passée/);
  const rg = await rpc(`pool_reminders_get('${ORG}')`);
  check('E52 rappel échu listé', rg.length === 1 && rg[0].due === true && rg[0].note === 'Recontacter pour juillet');
  await q(`select pool_reminders_get('${ORG}')`);
  check('E53 une seule notification à l\'échéance, adressée à l\'auteur', (await nt(MEMA, 'talent_pool_reminder')) === 1);
  await as(MEMV);
  await fails('E54 le lecteur ne clôt pas un rappel', `select pool_reminder_done('${R1}', '${ORG}')`, /Réservé/);
  await as(MEMA);
  await works('E55 rappel clos', `select pool_reminder_done('${R1}', '${ORG}')`);
  check('E56 un rappel clos n\'est plus listé', (await rpc(`pool_reminders_get('${ORG}')`)).length === 0);
  // alertes de disponibilité
  await as(MEMV);
  await fails('E57 le lecteur ne crée pas d\'alerte', `select pool_alert_set('${ST2}', true, '${ORG}')`, /Réservé/);
  await as(MEMA);
  check('E58 alerte de disponibilité créée', (await rpc(`pool_alert_set('${ST2}', true, '${ORG}')`)) === true && (await rpc(`pool_alerts_get('${ORG}')`)).length === 1);
  await db.exec(`reset role; insert into student_availability (user_id, kinds) values ('${ST2}', array['job'])`);
  check('E59 le talent surveillé devient disponible : l\'auteur est notifié', (await nt(MEMA, 'talent_available')) === 1);
  await db.exec(`reset role; update student_availability set note = 'ok' where user_id = '${ST2}'`);
  check('E60 pas de nouvelle notification sans nouvelle disponibilité', (await nt(MEMA, 'talent_available')) === 1);
  await db.exec(`reset role; update student_availability set kinds = array['job', 'internship'] where user_id = '${ST2}'`);
  check('E61 nouvelle disponibilité : nouvelle notification', (await nt(MEMA, 'talent_available')) === 2);
  check('E62 les autres membres ne sont pas notifiés', (await nt(MEMV, 'talent_available')) === 0 && (await nt(ORG, 'talent_available')) === 0);
  await as(ORG);
  check('E63 alerte retirée', (await rpc(`pool_alert_set('${ST2}', false)`)) === false && (await rpc(`pool_alerts_get()`)).length === 0);
  // indicateurs, import, comparaison
  const ov = await rpc(`pool_overview()`);
  check('E64 tableau de bord : total, étapes, listes, disponibles, rappels, contacts', ov.total === 3 && ov.by_stage.preselectionne === 1 && ov.by_stage.favori === 1 && ov.by_stage.sans_etape === 1 && ov.lists === 2 && ov.available === 2 && ov.reminders_open === 0 && ov.contacts_30d === 1, JSON.stringify(ov));
  await as(ORG2);
  const ov2 = await rpc(`pool_overview()`);
  check('E65 isolation : l\'autre organisation voit un tableau de bord vide', ov2.total === 0 && ov2.contacts_30d === 0 && ov2.lists === 1);
  await as(ORG);
  const L2 = await rpc(`pool_list_create('Candidats Flutter')`);
  check('E66 import des candidats d\'une offre : 3 talents', (await rpc(`pool_import_applications('${O}', '${L2}')`)) === 3);
  check('E67 l\'import ne remplace pas une étape existante', (await rpc(`pool_search(p_stage => 'preselectionne')`)).map((x) => x.id).join() === ST1 && (await rpc(`pool_search(p_stage => 'candidat')`)).map((x) => x.id).join() === ST3);
  await as(ORG2);
  await fails('E68 une autre organisation n\'importe pas les candidats d\'une offre', `select pool_import_applications('${O}', '${L2}')`, /Offre introuvable/);
  await as(ORG);
  const cmp = await rpc(`pool_compare(array['${ST1}', '${ST2}']::uuid[], '${O}')`);
  check('E69 comparaison : 2 talents, 4 critères, aucune décision automatique', cmp.talents.length === 2 && cmp.criteria.length === 4 && cmp.automatic_decision === false && /ne décide de rien/.test(cmp.notice), JSON.stringify(cmp.criteria.map((x) => x.skill)));
  const fl = cmp.criteria.find((x) => x.skill === 'Flutter');
  check('E70 comparaison : niveaux et statuts par talent', fl.cells.find((x) => x.student_id === ST1).status === 'satisfait' && fl.cells.find((x) => x.student_id === ST2).status === 'partiel', JSON.stringify(fl));
  check('E71 comparaison : étapes et étiquettes du vivier', cmp.talents.find((x) => x.id === ST1).stage === 'preselectionne');
  await fails('E72 comparer un seul talent est refusé', `select pool_compare(array['${ST1}']::uuid[])`, /2 à 5/);
  await fails('E73 comparer un talent invisible est refusé', `select pool_compare(array['${ST1}', '${ST4}']::uuid[])`, /introuvable/);
  await fails('E74 comparer un doublon est refusé', `select pool_compare(array['${ST1}', '${ST1}']::uuid[])`, /double/);
  await as(ST1);
  await q(`select talent_passport_share_set('competences', 'prive')`);
  await as(ORG);
  const cmp2 = await rpc(`pool_compare(array['${ST1}', '${ST2}']::uuid[])`);
  check('E75 comparaison hors offre : rubrique privée => compétences non détaillées', cmp2.talents.find((x) => x.id === ST1).skills === null && cmp2.talents.find((x) => x.id === ST1).skills_shared === false);
  await as(ORG2);
  await fails('E76 une autre organisation ne compare pas ces talents', `select pool_compare(array['${ST1}', '${ST2}']::uuid[], null, '${ORG}')`, /Accès refusé/);
  // talent qui se retire
  await db.exec(`reset role; insert into student_talent_prefs (user_id, visible_to_recruiters) values ('${ST2}', false) on conflict (user_id) do update set visible_to_recruiters = false`);
  await as(ORG);
  check('E77 un talent qui se retire disparaît du vivier (ses notes restent privées)', (await rpc(`pool_list_members_get('${L1}')`)).every((x) => x.id !== ST2) && (await rpc(`pool_overview()`)).total === 2);
  await db.exec(`reset role; update student_talent_prefs set visible_to_recruiters = true where user_id = '${ST2}'`);
  await as(ORG);
  await works('E78 suppression d\'une liste', `select pool_list_delete('${L2}')`);
  // ancien appelant : liste créée sans organisation
  await as(ORG);
  await db.exec(`reset role; insert into talent_lists (owner_id, name) values ('${ORG}', 'Ancienne')`);
  check('E79 un ancien appelant (sans org_id) est rattaché à son propre compte', (await qs(`select count(*)::int n from talent_lists where name = 'Ancienne' and org_id = owner_id`))[0].n === 1);
  console.log('--- E terminé');

  // ============================================================ F. Recrutement après présélection
  const app = async (uid) => (await qs(`select id from opportunity_applications where opportunity_id = '${O}' and applicant_id = '${uid}'`))[0].id;
  const AP1 = await app(ST1), AP2 = await app(ST2), AP3 = await app(ST3);
  await as(MEMA);
  await fails('F1 entretien avant présélection refusé', `select opp_interview_set('${AP1}', now() + interval '2 days', 'visio')`, /suit la présélection/);
  await fails('F2 décision avant présélection refusée', `select opp_recruit_decide('${AP1}', 'retenu', 'Profil très complet et motivé')`, /présélectionnée/);
  await q(`select opp_application_decide('${AP1}', 'shortlisted')`);
  await q(`select opp_application_decide('${AP2}', 'shortlisted')`);
  await as(MEMV);
  await fails('F3 le lecteur ne planifie pas', `select opp_interview_set('${AP1}', now() + interval '2 days', 'visio')`, /Candidature introuvable/);
  await as(ORG2);
  await fails('F4 une autre organisation est refusée', `select opp_interview_set('${AP1}', now() + interval '2 days', 'visio')`, /Candidature introuvable/);
  await fails('F5 une autre organisation ne lit pas le dossier', `select opp_recruit_get('${AP1}')`, /Candidature introuvable/);
  await as(ST1);
  await fails('F6 le candidat ne planifie pas son propre entretien', `select opp_interview_set('${AP1}', now() + interval '2 days', 'visio')`, /Candidature introuvable/);
  await as(ST3);
  await fails('F7 un autre candidat ne lit pas le dossier', `select opp_recruit_get('${AP1}')`, /Candidature introuvable/);
  await as(MEMA);
  await fails('F8 entretien dans le passé refusé', `select opp_interview_set('${AP1}', now() - interval '1 day', 'visio')`, /à venir/);
  await fails('F9 mode inconnu refusé', `select opp_interview_set('${AP1}', now() + interval '2 days', 'hologramme')`, /Mode d'entretien inconnu/);
  const f10 = await rpc(`opp_interview_set('${AP1}', now() + interval '2 days', 'visio', 'Lien envoyé par message', 'Préparer des questions Flutter')`);
  check('F10 entretien planifié, journalisé', f10.interview.status === 'planifie' && f10.interview.mode === 'visio' && f10.events.some((e) => e.kind === 'entretien_planifie') && f10.can_manage === true, JSON.stringify(f10.interview));
  check('F11 le candidat est notifié', (await nt(ST1, 'opportunity_interview')) === 1);
  await as(ST1);
  const f12 = await rpc(`opp_recruit_get('${AP1}')`);
  check('F12 le candidat voit l\'entretien, sans note interne ni journal ni décision', f12.viewer === 'candidat' && f12.interview.status === 'planifie' && f12.interview.note === null && f12.events === null && f12.decision === null);
  await as(MEMA);
  await fails('F13 décision refusée tant qu\'un entretien est planifié', `select opp_recruit_decide('${AP1}', 'retenu', 'Profil très complet et motivé')`, /entretien est encore planifié/);
  await fails('F14 entretien non encore passé : pas « réalisé »', `select opp_interview_done('${AP1}')`, /Aucun entretien planifié/);
  await db.exec(`reset role; update opportunity_recruitment set interview_at = now() - interval '1 hour' where application_id = '${AP1}'`);
  await as(MEMA);
  const f15 = await rpc(`opp_interview_done('${AP1}', 'Très bon échange technique')`);
  check('F15 entretien réalisé', f15.interview.status === 'realise' && f15.interview.note === 'Très bon échange technique');
  await fails('F16 un entretien réalisé ne se replanifie pas', `select opp_interview_set('${AP1}', now() + interval '3 days', 'visio')`, /déjà eu lieu/);
  // évaluation liée
  await db.exec(`reset role; insert into assessment_requests (id, candidate_id, family_code, mode, status, funding, consent, accepted_at) values
      ('00000000-0000-0000-0000-0000000e0001', '${ST1}', 'mecanique', 'ecrit', 'acceptee', 'payee_candidat', true, now()),
      ('00000000-0000-0000-0000-0000000e0002', '${ST2}', 'mecanique', 'ecrit', 'acceptee', 'payee_candidat', true, now());
    insert into assessment_results (id, request_id, candidate_id, competences, limits, validation_status) values
      ('00000000-0000-0000-0000-0000000e1001', '00000000-0000-0000-0000-0000000e0001', '${ST1}', '[]', 'Évaluation à distance : geste non observé.', 'validation_humaine_requise'),
      ('00000000-0000-0000-0000-0000000e1002', '00000000-0000-0000-0000-0000000e0002', '${ST2}', '[]', 'Évaluation à distance : geste non observé.', 'automatique')`);
  const E1 = '00000000-0000-0000-0000-0000000e1001', E2 = '00000000-0000-0000-0000-0000000e1002';
  await as(MEMA);
  await fails('F17 l\'organisation ne lie pas un résultat non partagé', `select opp_recruit_evaluation_link('${AP1}', '${E1}')`, /pas partagé/);
  await as(ST1);
  await fails('F18 le candidat ne lie pas le résultat d\'un autre', `select opp_recruit_evaluation_link('${AP1}', '${E2}')`, /Résultat introuvable/);
  const f19 = await rpc(`opp_recruit_evaluation_link('${AP1}', '${E1}')`);
  check('F19 le candidat joint son résultat (consentement du candidat)', f19.linked === true && f19.consent === 'candidat');
  await as(MEMA);
  const f20 = await rpc(`opp_recruit_get('${AP1}')`);
  check('F20 l\'organisation lit l\'évaluation jointe, la validation humaine requise reste signalée', f20.evaluation.family_code === 'mecanique' && f20.evaluation.human_validation_required === true && !!f20.evaluation.limits, JSON.stringify(f20.evaluation));
  await as(ORG2);
  await fails('F21 une autre organisation ne lit pas l\'évaluation', `select opp_recruit_get('${AP1}')`, /Candidature introuvable/);
  await as(ST1);
  check('F22 le candidat détache son résultat', (await rpc(`opp_recruit_evaluation_link('${AP1}', null)`)).linked === false);
  await as(MEMA);
  check('F23 évaluation détachée : plus visible de l\'organisation', (await rpc(`opp_recruit_get('${AP1}')`)).evaluation === null);
  // décision humaine
  await as(MEMV);
  await fails('F24 le lecteur ne décide pas', `select opp_recruit_decide('${AP1}', 'retenu', 'Profil très complet et motivé')`, /Candidature introuvable/);
  await as(ST1);
  await fails('F25 le candidat ne décide pas', `select opp_recruit_decide('${AP1}', 'retenu', 'Je me retiens moi-même')`, /Candidature introuvable/);
  await as(MEMA);
  await fails('F26 décision sans motif refusée', `select opp_recruit_decide('${AP1}', 'retenu', 'ok')`, /Motivez/);
  await fails('F27 décision inconnue refusée', `select opp_recruit_decide('${AP1}', 'embauche_auto', 'Décision automatique par score')`, /Décision inconnue/);
  await fails('F28 proposition avant décision refusée', `select opp_offer_send('${AP1}', 'Nous vous proposons un stage de trois mois chez nous.')`, /suit une décision/);
  const f29 = await rpc(`opp_recruit_decide('${AP1}', 'retenu', 'Profil complet, entretien convaincant')`);
  check('F29 décision humaine tracée (auteur, motif, date) et jamais automatique', f29.decision.decision === 'retenu' && /Mem/.test(f29.decision.by) && f29.decision.automatic === false && !!f29.decision.at && f29.decision.reason === 'Profil complet, entretien convaincant');
  check('F30 « retenu » ne change pas le statut (pas d\'embauche implicite)', (await qs(`select status from opportunity_applications where id = '${AP1}'`))[0].status === 'shortlisted');
  await fails('F31 la décision ne se rejoue pas', `select opp_recruit_decide('${AP1}', 'non_retenu', 'Changement d''avis tardif')`, /déjà prise/);
  await as(ST1);
  check('F32 le candidat ne voit ni le motif ni la décision interne', (await rpc(`opp_recruit_get('${AP1}')`)).decision === null);
  // proposition
  await as(MEMA);
  await fails('F33 proposition trop courte refusée', `select opp_offer_send('${AP1}', 'Venez')`, /20 caractères/);
  await fails('F34 proposition sans décision (AP2) refusée', `select opp_offer_send('${AP2}', 'Nous vous proposons un stage de trois mois chez nous.')`, /suit une décision/);
  const f35 = await rpc(`opp_offer_send('${AP1}', 'Nous vous proposons un stage de trois mois à partir de juillet.')`);
  check('F35 la proposition est un message avec avertissement « sans engagement juridique »', /sans engagement juridique/.test(f35.offer.notice) && f35.offer.response === null);
  const nfo = (await qs(`select body, data from notifications where user_id = '${ST1}' and kind = 'opportunity_offer'`));
  check('F36 le candidat est notifié, avec l\'avertissement', nfo.length === 1 && /sans engagement juridique/.test(nfo[0].body) && nfo[0].data.legal_commitment === false);
  await as(ST2);
  await fails('F37 un autre candidat ne répond pas à cette proposition', `select opp_offer_respond('${AP1}', 'interesse')`, /Candidature introuvable/);
  await as(ST1);
  await fails('F38 réponse inconnue refusée', `select opp_offer_respond('${AP1}', 'signe')`, /Réponse inconnue/);
  const f39 = await rpc(`opp_offer_respond('${AP1}', 'interesse')`);
  check('F39 le candidat répond « intéressé » : aucune obligation créée', f39.offer.response === 'interesse' && f39.viewer === 'candidat');
  check('F40 l\'organisation est notifiée de la réponse', (await nt(ORG, 'opportunity_offer')) === 1);
  await fails('F41 une seule réponse', `select opp_offer_respond('${AP1}', 'decline')`, /déjà répondu/);
  await as(MEMA);
  await fails('F42 la proposition ne se renvoie pas après réponse', `select opp_offer_send('${AP1}', 'Nous vous proposons un stage de trois mois à partir de juillet.')`, /déjà répondu/);
  check('F43 le statut reste « présélectionné » : l\'embauche reste un acte humain distinct', (await qs(`select status from opportunity_applications where id = '${AP1}'`))[0].status === 'shortlisted');
  const f44 = await rpc(`opp_recruit_get('${AP1}')`);
  check('F44 journal complet de la candidature', ['entretien_planifie', 'entretien_realise', 'evaluation_liee', 'evaluation_detachee', 'decision_retenu', 'proposition_envoyee', 'proposition_interesse'].every((k) => f44.events.some((e) => e.kind === k)), JSON.stringify(f44.events.map((e) => e.kind)));
  // non retenu
  await as(ORG);
  const f45 = await rpc(`opp_recruit_decide('${AP2}', 'non_retenu', 'Niveau Flutter insuffisant pour ce stage')`);
  check('F45 « non retenu » : candidature rejetée par l\'organisation, motif tracé', f45.status === 'rejected' && f45.decision.decision === 'non_retenu');
  check('F46 le candidat non retenu est notifié par le circuit existant', (await nt(ST2, 'opportunity_application')) >= 1);
  await fails('F47 plus de proposition après « non retenu »', `select opp_offer_send('${AP2}', 'Nous vous proposons un stage de trois mois chez nous.')`, /suit une décision/);
  await as(ST3);
  await fails('F48 candidature non présélectionnée : pas d\'évaluation liée', `select opp_recruit_evaluation_link('${AP3}', '00000000-0000-0000-0000-0000000e1002')`, /après la présélection/);
  // accès direct et anonyme
  await as(ORG);
  await fails('F49 tables de recrutement fermées (accès direct)', `select * from opportunity_recruitment`, /permission denied|row-level security/);
  await fails('F50 journal fermé (accès direct)', `select * from opportunity_recruitment_events`, /permission denied|row-level security/);
  await anon();
  await fails('F51 anonyme : dossier refusé', `select opp_recruit_get('${AP1}')`, /Connexion requise|permission denied/);
  await fails('F52 anonyme : décision refusée', `select opp_recruit_decide('${AP1}', 'retenu', 'Profil très complet et motivé')`, /Connexion requise|permission denied/);
  await fails('F53 anonyme : proposition refusée', `select opp_offer_respond('${AP1}', 'interesse')`, /Connexion requise|permission denied/);
  console.log('--- F terminé');

  // ============================================================ G. Migration sans perte et rejeu
  await sup();
  const snap = async () => (await q(`select (select count(*) from talent_lists)::int l, (select count(*) from talent_list_members)::int m, (select count(*) from talent_pool_notes)::int n,
      (select count(*) from talent_pool_profiles)::int p, (select count(*) from talent_pool_contacts)::int c, (select count(*) from opportunity_recruitment)::int r, (select count(*) from opportunity_recruitment_events)::int e,
      (select count(*) from talent_passport_shares)::int s, (select count(*) from skill_graph_edges)::int g, (select count(*) from opportunity_criteria)::int k`))[0];
  const migs = fs.readdirSync(new URL('../../migrations/', import.meta.url)).filter((f) => /^2026112606\d*_h10_talent/.test(f)).sort();
  check('G1 les cinq migrations Talent sont présentes', migs.length === 5, migs.join());
  // état d'avant la migration du vivier : listes sans organisation, unicité par compte, aucun déclencheur
  const before = await snap();
  await db.exec(`drop trigger if exists trg_talent_lists_org on talent_lists; drop index if exists talent_lists_org_name; alter table talent_lists alter column org_id drop not null;
    update talent_lists set org_id = null; alter table talent_lists add constraint talent_lists_owner_id_name_key unique (owner_id, name)`);
  const preNull = (await q(`select count(*)::int n from talent_lists where org_id is null`))[0].n;
  check('G2 simulation de l\'état antérieur : listes sans organisation', preNull === before.l && before.l >= 3, JSON.stringify(before));
  const memberNotes = (await q(`select md5(string_agg(student_id::text || coalesce(note, ''), ',' order by list_id, student_id)) h from talent_list_members`))[0].h;
  for (const f of migs) await db.exec(fs.readFileSync(new URL('../../migrations/' + f, import.meta.url), 'utf8'));
  const after = await snap();
  check('G3 migration du vivier : aucune liste, membre, note ni donnée perdue', JSON.stringify(before) === JSON.stringify(after), JSON.stringify(after));
  check('G4 chaque liste existante est rattachée à son propriétaire (org_id = owner_id)', (await q(`select count(*)::int n from talent_lists where org_id is distinct from owner_id`))[0].n === 0);
  check('G5 les notes des membres de listes sont intactes', (await q(`select md5(string_agg(student_id::text || coalesce(note, ''), ',' order by list_id, student_id)) h from talent_list_members`))[0].h === memberNotes);
  check('G6 l\'unicité par organisation et nom est rétablie', (await q(`select count(*)::int n from pg_indexes where indexname = 'talent_lists_org_name'`))[0].n === 1 && (await q(`select count(*)::int n from pg_trigger where tgname = 'trg_talent_lists_org'`))[0].n === 1);
  for (const f of migs) await db.exec(fs.readFileSync(new URL('../../migrations/' + f, import.meta.url), 'utf8'));
  check('G7 rejeu des migrations : aucun effet de bord', JSON.stringify(await snap()) === JSON.stringify(before));
  check('G8 rejeu : aucune relation de graphe ni critère inventés', (await q(`select count(*)::int n from skill_graph_edges`))[0].n === 2);
  await as(ORG);
  check('G9 après rejeu : le vivier de l\'organisation fonctionne', (await rpc(`pool_lists_get()`)).length >= 2);
  await as(ST1);
  await fails('G10 après rejeu : un talent ne lit pas le vivier', `select pool_lists_get('${ORG}')`, /Accès refusé/);
  await sup();
  console.log(`\n${ok}/${ok + ko}`);
}
