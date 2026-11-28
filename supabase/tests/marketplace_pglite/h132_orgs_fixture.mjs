// H13.2 agent 5 (organisations / departements) - MATRICE acteur x objet deduite du catalogue (fonctions executables + tables lisibles + politiques RLS).
// Deux organisations (A, B), deux departements (A, B), leurs equipes et leurs etudiants sont crees par de VRAIS appels (parcours reels) ; puis chaque ligne appartenant a un camp recoit une marque
// « PRIV<type><camp>_<colonne> » dans ses colonnes texte, de sorte qu'une fuite revele exactement la table/colonne en cause. Ensuite :
//   (1) chaque table/vue lisible par `authenticated` est lue par chaque acteur (RLS reel) ;
//   (2) chaque fonction executable par `authenticated` est appelee (dans une transaction annulee) par chaque acteur avec des arguments pointant vers les objets de l'AUTRE camp, et les resultats sont fouilles.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_orgs_matrice.mjs
import fs from 'fs';
import { bench } from './h131_lib.mjs';

export const SIDES = ['A', 'B'];

export async function buildFixture(db, b, log = () => {}) {
  const { U, as, sup, q, qs, check, works, user } = b;
  await sup();
  await db.exec('grant all on storage.objects to authenticated');
  const putFile = async (path, mime = 'application/pdf', size = 5000) => { await qs(`insert into storage.objects (bucket_id, name, metadata) values ('profile-documents', '${path}', '${JSON.stringify({ mimetype: mime, size })}')`); };
  const I1 = U(800), G = { A: U(803), B: U(804) }, D = { A: U(801), B: U(802) };
  await db.exec(`insert into institutions (id, name, status) values ('${I1}', 'Etablissement Matrice', 'verified');
    insert into departments (id, institution_id, name, status) values ('${D.A}', '${I1}', 'Informatique', 'verified'), ('${D.B}', '${I1}', 'Gestion', 'verified');
    insert into programs (id, institution_id, department_id, name, active) values ('${G.A}', '${I1}', '${D.A}', 'Genie logiciel', true), ('${G.B}', '${I1}', '${D.B}', 'Comptabilite', true)`);
  const F = { ADM: await user(1, 'Ada Admin', 'admin'), CLI: await user(2, 'Cora Cliente', 'client') };
  const side = {};
  let n = 10;
  for (const s of SIDES) {
    const o = { s };
    o.O = await user(n++, `Societe ${s}`, 'company');
    o.OAD = await user(n++, `Admin Equipe ${s}`, 'client');
    o.OFI = await user(n++, `Finance Equipe ${s}`, 'client');
    o.OVW = await user(n++, `Lecteur Equipe ${s}`, 'client');
    o.H = await user(n++, `Chef Dept ${s}`, 'dept');
    o.S1 = await user(n++, `Sandra Talent${s}`, 'student');
    o.S2 = await user(n++, `Serge Invisible${s}`, 'student');
    o.D = D[s]; o.G = G[s]; o.dname = s === 'A' ? 'Informatique' : 'Gestion';
    side[s] = o;
    await db.exec(`insert into department_accounts (user_id, department_id) values ('${o.H}', '${o.D}');
      update profiles set institution_id='${I1}', department_id='${o.D}', department='${o.dname}' where id = '${o.H}';
      update profiles set phone='69013'||right(id::text,4), phone_verified=true, certification='approved', skills='Flutter, Dart', institution_id='${I1}', department_id='${o.D}', department='${o.dname}', city='Douala' where id in ('${o.S1}','${o.S2}')`);
    for (const st of [o.S1, o.S2]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${st}', 'student_card', 'c.pdf', '${st}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  }
  await b.raw(`select 1`);
  const adm = F.ADM;

  // -------- ranking publie (necessaire a la decouverte de talents), commun aux deux camps
  const P0 = (await qs(`select to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM') p`))[0].p;
  let fx = 0;
  for (const s of SIDES) for (const [st, pts] of [[side[s].S1, 500], [side[s].S2, 450]]) {
    await db.exec(`insert into student_affiliations (user_id, institution_id, department_id, program_id, promotion, status) values ('${st}', '${I1}', '${side[s].D}', '${side[s].G}', '2026', 'verified');
      insert into talent_visibility_settings (user_id, public_ranking, show_full_name, shared_sections) values ('${st}', true, false, array['rank','score','evolution','skills','badges','projects','passport']);
      insert into talent_skills (owner_id, domain, skill, level) values ('${st}', 'Informatique', 'Flutter', 'avance')`);
    const e = (await qs(`insert into talent_events (user_id, rule_code, source_kind, source_id) values ('${st}', 'sale_confirmed', 'fixture', 'fx-${++fx}') returning id`))[0].id;
    await db.exec(`select _talent_ledger_add(${e}, '${st}', 'award', ${pts}, 'sale_confirmed', 1, 'fixture');
      alter table talent_score_ledger disable trigger trg_talent_ledger_guard; update talent_score_ledger set period = '${P0}' where event_id = ${e}; alter table talent_score_ledger enable trigger trg_talent_ledger_guard`);
  }
  await as(adm);
  await works('F0a reglages du classement', `select admin_ranking_settings_set(50, null, 100, array['national','program','institution','department','domain'], 'Reglages du banc de la matrice') r`);
  await works('F0b regle de score', `select admin_talent_rule_set('sale_confirmed', 100, null, null, 0, true, 'Regle active pour le banc de la matrice') r`);
  await works('F0c cohorte minimale', `select admin_talent_setting_set('min_cohort', 3, 'Cohorte de test du banc de la matrice') r`);
  await works('F0d publication du classement', `select ranking_publish('${P0}') r`, (r) => r[0].r.ok === true);

  const detail = '{"domain":"agri","problem":"Arrosage manuel","solution":"Capteurs et pompe","progress":"prototype","contact_email":"a@b.cm"}';
  const IMG = 'https://abcdefgh.supabase.co/storage/v1/object/public/listing-images/u/p.jpg';
  const ids = { missions: {}, proposals: {}, opps: {}, events: {}, lists: {}, projects: {}, partnerships: {} };

  for (const s of SIDES) {
    const o = side[s];
    // ---- organisation : inscription, piece, verification, offre Organisation, equipe
    await as(o.O);
    await q(`insert into profiles (id, name, email, role) values ('${o.O}', 'Societe ${s}', 'h131-5-${s}@t.cm', 'company') on conflict (id) do nothing`).catch(() => {});
    await works(`F1${s} fiche organisation ${s}`, `select company_save('${JSON.stringify({ company_name: `Societe ${s}`, sector: 'Telecoms', city: 'Douala', phone: '699000000', contact_name: `Contact ${s}`, contact_role: 'DRH', registration_number: `RC/${s}/1`, description: `Presentation ${s}` })}'::jsonb) r`);
    await putFile(`${o.O}/company/rccm.pdf`);
    await as(o.O);
    await works(`F2${s} piece`, `select company_doc_add('registration', 'RCCM.pdf', '${o.O}/company/rccm.pdf', 'application/pdf', 1000) r`);
    await works(`F3${s} envoi`, `select company_submit() r`, (r) => r[0].r === 'pending');
    await as(adm);
    await works(`F4${s} approbation`, `select company_decide('${o.O}', true) r`, (r) => r[0].r === 'approved');
    await works(`F5${s} offre Organisation`, `select company_subscription_activate('${o.O}', 'partner', 30, 'Activation du banc de la matrice', false) r`);
    await as(o.O);
    for (const [u, role, k] of [[o.OAD, 'admin', 'AD'], [o.OFI, 'finance', 'FI'], [o.OVW, 'viewer', 'VW']]) {
      await works(`F6${s} invitation ${role}`, `select company_invite('${await emailOf(b, u)}', '${role}') r`);
      await as(u); await works(`F6${s} acceptation ${role}`, `select company_member_respond('${o.O}', true) r`); await as(o.O);
    }
    await works(`F7${s} facturation`, `select company_billing_set('{"legal_name":"Societe ${s} SARL","address":"Rue ${s}","tax_id":"M0${s}1"}'::jsonb, '${o.O}') r`).catch(() => {});
    // ---- besoin, proposition, choix
    ids.missions[s] = (await works(`F8${s} besoin publie`, `select save_mission(null, 'Besoin ${s}', 'Un besoin decrit avec plus de vingt caracteres ${s}', 50000, 100000, '2027-01-31', true, 'besoin', false, null) id`))?.[0]?.id;
    await as(o.S1);
    ids.proposals[s] = (await works(`F9${s} proposition du talent`, `select propose_on_mission('${ids.missions[s]}', 80000, 10, 'Message prive de proposition ${s}') id`))?.[0]?.id;
    await as(o.O);
    await works(`F10${s} choix`, `select decide_proposal('${ids.proposals[s]}', true) r`);
    // ---- vivier, contact, favoris
    await works(`F11${s} liste du vivier`, `select talent_list_create('Vivier ${s}') r`);
    ids.lists[s] = (await qs(`select id from talent_lists where owner_id = '${o.O}' and name = 'Vivier ${s}'`))[0]?.id;
    await works(`F12${s} ajout au vivier`, `select talent_list_add('${ids.lists[s]}', '${o.S1}', 'Note privee du vivier ${s}') r`);
    await works(`F13${s} favori`, `select discovery_favorite_set('${o.S1}', true, '${o.O}') r`);
    await works(`F14${s} demande de contact`, `select discovery_contact_request('${o.S1}', 'interview', 'Entretien prive ${s} jeudi a 10h', '${o.O}') r`);
    // ---- offre de stage
    ids.opps[s] = (await works(`F15${s} offre`, `select opp_save('Societe ${s}', 'stage', 'academique', 'Stagiaire ${s}', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', current_date + 10, array['Flutter'], 'Description complete de l offre pour les etudiants ${s}', array['Developper des ecrans','Tester'], 'Etudiant motive', 'Informatique', 'L3', array['Transport'], '', true, '', false) id`))?.[0]?.id;
    await as(adm);
    await works(`F16${s} validation offre`, `select opp_decide('${ids.opps[s]}', true, true) r`);
    await as(o.S1);
    await works(`F17${s} candidature`, `select opp_apply('${ids.opps[s]}', 'Lettre de motivation privee ${s} tres complete', 'https://cv.exemple.cm/${s}') id`);
    // ---- departement : identite, partenariat, evenement, production, projet, mise en avant, validation
    await as(o.H);
    await works(`F20${s} identite`, `select dept_identity_save('{"description":"Formation ${s}","contact_email":"gl${s}@iut.cm"}'::jsonb) r`);
    ids.partnerships[s] = (await works(`F21${s} partenariat`, `select dept_partnership_save('{"partner_name":"Partenaire ${s}","kind":"stage","status":"actif","contact_email":"rh${s}@x.cm","students":12}'::jsonb) id`))?.[0]?.id;
    ids.events[s] = (await works(`F22${s} evenement`, `select event_create('Evenement ${s}', 'Presentation ${s}', 'conference', now() + interval '10 days', now() + interval '10 days 3 hours', 'Amphi ${s}', 0, 50) r`))?.[0]?.r;
    await works(`F23${s} production`, `select production_create('Production ${s}', 'Equipe ${s}', null, null) r`);
    await qs(`insert into shops (owner_id, name, slug, status) values ('${o.S1}', 'Boutique ${s}', 'boutique-${s.toLowerCase()}-p5', 'active')`);
    await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images, shop_id) select '${o.S1}', 'Lampe ${s}', '${o.dname}', 'Maison', 5000, 3, 'pending', '{${IMG}}', id from shops where owner_id='${o.S1}'`);
    await as(o.S1);
    ids.projects[s] = (await works(`F24${s} projet`, `select project_save_full(null, 'projet', 'Projet ${s}', 'Une description suffisamment longue pour publier ce projet.', '${o.dname}', '${detail}'::jsonb, '[]'::jsonb, 'public', true) id`))?.[0]?.id;
    await as(o.H);
    await works(`F25${s} validation projet`, `select review_project('${ids.projects[s]}', true, 'Commentaire interne ${s}') r`);
    await works(`F26${s} mise en avant`, `select dept_highlight_set('project', '${ids.projects[s]}', 'Belle realisation ${s}') r`);
    await works(`F27${s} demande institutionnelle`, `select institutional_validation_request('other', 'Convention ${s}', 'Details de la convention ${s}', '${o.D}', null) r`);
    await works(`F28${s} invitation de responsable`, `select 1 r`);
    await as(adm);
    await works(`F29${s} invitation de responsable (admin)`, `select dept_invite_create('${o.D}', 'chef${s.toLowerCase()}@t.cm', 'Responsable', 7) r`);
  }
  await sup();
  return { I1, F, side, ids, D, G };
}

async function emailOf(b, u) { return (await b.qs(`select email from profiles where id = '${u}'`))[0].email; }


