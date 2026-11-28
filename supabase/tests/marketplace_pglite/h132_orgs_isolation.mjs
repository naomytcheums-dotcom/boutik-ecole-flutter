// H13.2 agent 5 - isolation organisation / departement : un acteur du camp A tente de lire ou d'ecrire chez le camp B (et inversement) par les fonctions ET par les tables.
// Un cas reussit si l'appel est refuse OU si sa reponse ne contient aucun texte prive de l'autre camp ; une sonde positive montre que la meme requete atteint bien les donnees du camp de l'acteur.
// Parcours : organisation non approuvee (ne publie pas, ne voit pas les talents), departement (rattachement, etudiants de SON departement, rapport).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h132_orgs_isolation.mjs   (compter les lignes ECHEC)
import { bench } from './h131_lib.mjs';
import { buildFixture, SIDES } from './h132_orgs_fixture.mjs';

// textes prives saisis par le camp s dans le parcours de la fixture
const PRIV = (s) => [`Message prive de proposition ${s}`, `Note privee du vivier ${s}`, `Entretien prive ${s} jeudi`, `Lettre de motivation privee ${s}`, `Commentaire interne ${s}`,
  `Details de la convention ${s}`, `rh${s}@x.cm`, `Societe ${s} SARL`, `Rue ${s}`, `M0${s}1`, `chef${s.toLowerCase()}@t.cm`, `Vivier ${s}`, `Partenaire ${s}`, `Convention ${s}`, `gl${s}@iut.cm`, `Equipe ${s}`];

export async function run(db) {
  const b = bench(db, 5);
  const { as, anon, sup, q, qs, check, works } = b;
  const fx = await buildFixture(db, b);
  const { side, ids } = fx;
  await sup();
  const other = (s) => (s === 'A' ? 'B' : 'A');
  const j = (x) => JSON.stringify(x ?? null);

  const apps = {};
  for (const s of SIDES) apps[s] = (await qs(`select id from opportunity_applications where opportunity_id = '${ids.opps[s]}'`))[0]?.id;

  // meme requete visant son propre camp : sonde positive (l'appel est bien forme et atteint des donnees)
  const swap = (sql, t) => {
    const s = other(t), x = side[t], o = side[s];
    let r = sql;
    for (const [a, c] of [[x.O, o.O], [x.OAD, o.OAD], [x.OVW, o.OVW], [x.OFI, o.OFI], [x.D, o.D], [x.H, o.H], [x.S1, o.S1], [x.S2, o.S2], [ids.proposals[t], ids.proposals[s]], [ids.lists[t], ids.lists[s]],
      [ids.opps[t], ids.opps[s]], [apps[t], apps[s]], [ids.missions[t], ids.missions[s]], [ids.projects[t], ids.projects[s]], [ids.partnerships[t], ids.partnerships[s]]]) r = r.replaceAll(a, c);
    return r;
  };
  // un appel de lecture : refuse, ou reponse sans texte prive de la cible
  const noLeak = async (name, uid, sql, tgt, control = false, emptyOk = false) => {
    await as(uid);
    let text = '', denied = false;
    try { text = j(await q(sql)); } catch (e) { denied = true; text = e.message; }
    const hit = PRIV(tgt).filter((p) => text.includes(p));
    check(name, hit.length === 0, `fuite: ${hit.join(' | ')}`);
    if (control) {
      await as(uid);
      let t2 = '', err = false;
      try { t2 = j(await q(swap(sql, tgt))); } catch (e) { err = true; t2 = e.message; }
      check(`${name} (sonde positive sur son propre camp)`, !err && (emptyOk || (!/^\[\{"r":(null|\[\]|\{\})\}\]$/.test(t2.trim()) && t2.length > 20)), t2.slice(0, 160));
    }
    return denied;
  };
  // une ecriture visant l'autre camp : refusee ou sans effet (verifie ensuite sur la base)
  const denied = async (name, uid, sql) => {
    await as(uid);
    let err = null, rows = null;
    try { rows = await q(sql); } catch (e) { err = e; }
    check(name, err !== null || rows === null || rows.length === 0 || (rows.length === 1 && Object.values(rows[0]).every((v) => v === false || v === null || v === 0)), err ? '' : `effet: ${j(rows).slice(0, 150)}`);
  };

  for (const s of SIDES) {
    const t = other(s), o = side[s], x = side[t];
    // ------------------------------------------------ organisation s -> organisation t
    for (const [lbl, uid] of [[`Org${s}.proprietaire`, o.O], [`Org${s}.admin`, o.OAD], [`Org${s}.lecteur`, o.OVW]]) {
      const R = (name, sql, ctl = 'oui') => noLeak(`${lbl} lit ${name} de l'organisation ${t}`, uid, sql, t, lbl.endsWith('proprietaire') && ctl !== 'non', ctl === 'vide');
      await R('equipe', `select company_members_list('${x.O}') r`);
      await R('fiche privee', `select company_get('${x.O}') r`);
      await R('facturation', `select company_billing_get('${x.O}') r`);
      await R('commandes', `select company_orders_list('${x.O}', 20, 0) r`, 'vide');
      await R('propositions', `select company_proposals('${x.O}') r`);
      await R('besoins', `select company_missions('${x.O}') r`);
      await R('missions', `select org_missions('${x.O}') r`);
      await R('favoris', `select discovery_favorites('${x.O}') r`);
      await R('partenariats', `select org_partnerships_list('${x.O}') r`, 'vide');
      await R('forfait', `select company_plan_status('${x.O}') r`);
      await R('tableau de bord', `select company_dashboard('${x.O}') r`);
      await R('proposition', `select company_proposal_detail('${ids.proposals[t]}') r`);
      await R('vivier', `select talent_list_members_get('${ids.lists[t]}') r`);
      await R('candidatures', `select opp_applications_for('${ids.opps[t]}') r`);
      await R('candidatures classees', `select opp_applications_ranked('${ids.opps[t]}') r`);
      await R('statistiques de l offre', `select opp_stats('${ids.opps[t]}') r`);
      await R('recrutement', `select opp_recruit_get('${apps[t]}') r`);
      await R('prestataires du besoin (fonction du personnel)', `select staff_mission_proposals('${ids.missions[t]}') r`, 'non');
      // tables : RLS
      for (const tb of ['talent_lists', 'talent_list_members', 'talent_contacts', 'mission_proposals', 'mission_agreements', 'company_members', 'company_billing', 'company_documents', 'opportunity_applications', 'order_billing']) {
        await as(uid);
        let text = '';
        try { text = j(await q(`select x::text v from public.${tb} x limit 500`)); } catch (e) { text = ''; }
        const hit = PRIV(t).filter((p) => text.includes(p));
        check(`${lbl} lit la table ${tb} sans texte prive de l'organisation ${t}`, hit.length === 0, hit.join(' | '));
      }
      // ecritures
      await denied(`${lbl} ne peut pas decider la proposition de l'organisation ${t}`, uid, `select decide_proposal('${ids.proposals[t]}', true) r`);
      await denied(`${lbl} ne peut pas ajouter au vivier de l'organisation ${t}`, uid, `select talent_list_add('${ids.lists[t]}', '${x.S2}', 'intrusion') r`);
      await denied(`${lbl} ne peut pas inviter dans l'equipe de l'organisation ${t}`, uid, `select company_invite('intrus${s}@t.cm', 'admin', '${x.O}') r`);
      await denied(`${lbl} ne peut pas modifier la fiche de l'organisation ${t}`, uid, `select company_save('{"company_name":"Intrus ${s}"}'::jsonb, '${x.O}') r`);
      await denied(`${lbl} ne peut pas changer le role d'un membre de l'organisation ${t}`, uid, `select company_member_set_role('${x.OVW}', 'admin', '${x.O}') r`);
      await denied(`${lbl} ne peut pas retirer un membre de l'organisation ${t}`, uid, `select company_member_remove('${x.OAD}', '${x.O}') r`);
      await denied(`${lbl} ne peut pas se faire passer pour l'organisation ${t} (contact)`, uid, `select discovery_contact_request('${x.S1}', 'interview', 'Usurpation ${s}', '${x.O}') r`);
      await denied(`${lbl} ne peut pas decider une candidature de l'organisation ${t}`, uid, `select opp_application_decide('${apps[t]}', 'accepted') r`);
      await denied(`${lbl} ne peut pas fermer l'offre de l'organisation ${t}`, uid, `select opp_close('${ids.opps[t]}') r`);
      await denied(`${lbl} ne peut pas annuler le besoin de l'organisation ${t}`, uid, `select mission_cancel('${ids.missions[t]}') r`);
      await denied(`${lbl} ne peut pas facturer au nom de l'organisation ${t}`, uid, `select company_billing_set('{"legal_name":"Usurpe ${s}"}'::jsonb, '${x.O}') r`);
      await as(uid);
      for (const tb of ['talent_lists', 'mission_proposals', 'company_profiles', 'company_members', 'missions']) {
        let n = 0;
        try { n = (await q(`with u as (update public.${tb} set id = id where ${tb === 'company_profiles' ? 'owner_id' : tb === 'missions' ? 'client_id' : tb === 'talent_lists' || tb === 'company_members' ? 'owner_id' : 'mission_id'} = '${tb === 'mission_proposals' ? ids.missions[t] : x.O}' returning 1) select count(*)::int n from u`))[0].n; } catch (e) { n = 0; }
        check(`${lbl} ne peut pas modifier ${tb} de l'organisation ${t} par ecriture directe`, n === 0, `${n} ligne(s)`);
      }
    }
    // ------------------------------------------------ departement s -> departement t
    {
      const lbl = `Dept${s}.responsable`, uid = o.H;
      const R = (name, sql, ctl = 'oui') => noLeak(`${lbl} lit ${name} du departement ${t}`, uid, sql, t, ctl !== 'non', ctl === 'vide');
      await R('apercu', `select dept_overview('${x.D}') r`);
      await R('liste des etudiants', `select dept_students_list('', 50, 0, '${x.D}') r`);
      await R('identite', `select dept_identity_get('${x.D}') r`);
      await R('partenariats', `select dept_partnerships('${x.D}') r`);
      await R('validations', `select dept_validations('${x.D}') r`);
      await R('opportunites', `select dept_opportunities('${x.D}') r`);
      await R('competences', `select dept_skills('${x.D}') r`);
      await R('certificats', `select dept_certificates('${x.D}') r`, 'vide');
      await R('mises en avant', `select dept_highlights('${x.D}') r`);
      await R('activite', `select dept_activity('${x.D}', 50) r`);
      await R('projets', `select dept_projects('projet', 'approved', 50, '${x.D}') r`);
      for (const kind of ['synthese', 'etudiants', 'projets', 'competences', 'opportunites', 'partenariats', 'ventes']) await R(`rapport ${kind}`, `select dept_report('${kind}', null, null, '${x.D}') r`);
      await R('detail d un etudiant', `select dept_student_detail('${x.S2}') r`);
      await R('invitations (reservees a l administrateur)', `select dept_invites_list() r`, 'non');
      await R('validations institutionnelles', `select institutional_validations_list('', 100) r`, 'vide');
      await R('propres partenariats (sans argument)', `select dept_partnerships() r`);
      await R('propres etudiants (sans argument)', `select dept_students(200) r`);
      await R('propres rapports (sans argument)', `select dept_report('etudiants', null, null, null) r`);
      for (const tb of ['department_partnerships', 'department_highlights', 'institutional_validations', 'department_invites', 'department_accounts', 'events', 'productions', 'projects', 'student_affiliations']) {
        await as(uid);
        let text = '';
        try { text = j(await q(`select x::text v from public.${tb} x limit 500`)); } catch (e) { text = ''; }
        const hit = PRIV(t).filter((p) => text.includes(p));
        check(`${lbl} lit la table ${tb} sans texte prive du departement ${t}`, hit.length === 0, hit.join(' | '));
      }
      await denied(`${lbl} ne peut pas modifier l'identite du departement ${t}`, uid, `select dept_identity_save('{"description":"Intrusion ${s}"}'::jsonb, '${x.D}') r`);
      await denied(`${lbl} ne peut pas creer de partenariat pour le departement ${t}`, uid, `select dept_partnership_save('{"partner_name":"Intrus ${s}"}'::jsonb, '${x.D}') r`);
      await denied(`${lbl} ne peut pas supprimer le partenariat du departement ${t}`, uid, `select dept_partnership_delete('${ids.partnerships[t]}') r`);
      await denied(`${lbl} ne peut pas valider le projet d'un etudiant du departement ${t}`, uid, `select review_project('${ids.projects[t]}', false, 'Intrusion ${s}') r`);
      await denied(`${lbl} ne peut pas mettre en avant un projet du departement ${t}`, uid, `select dept_highlight_set('project', '${ids.projects[t]}', 'Intrusion ${s}', true, '${x.D}') r`);
      await denied(`${lbl} ne peut pas inviter pour le departement ${t}`, uid, `select dept_invite_create('${x.D}', 'intrus${s}@t.cm', 'Responsable', 7) r`);
      await denied(`${lbl} ne peut pas decider une validation institutionnelle du departement ${t}`, uid, `select institutional_validation_decide('${(await qs(`select id from institutional_validations where department_id = '${x.D}' limit 1`))[0]?.id}', true, 'Intrusion') r`);
      await as(uid);
      for (const [tb, col, val] of [['departments', 'id', x.D], ['department_partnerships', 'department_id', x.D], ['profiles', 'department_id', x.D]]) {
        let n = 0;
        try { n = (await q(`with u as (update public.${tb} set ${tb === 'departments' ? 'name' : tb === 'profiles' ? 'bio' : 'partner_name'} = 'Intrusion ${s}' where ${col} = '${val}' returning 1) select count(*)::int n from u`))[0].n; } catch (e) { n = 0; }
        check(`${lbl} ne peut pas modifier ${tb} du departement ${t} par ecriture directe`, n === 0, `${n} ligne(s)`);
      }
    }
    // ------------------------------------------------ l'etudiant du camp s ne voit pas l'espace d'un departement ni d'une organisation
    for (const fnc of [`dept_students(50)`, `dept_overview(null)`, `dept_report('etudiants', null, null, null)`, `company_dashboard(null)`, `company_billing_get(null)`, `discovery_favorites(null)`]) {
      await as(o.S1);
      let err = false, text = '';
      try { text = j(await q(`select ${fnc} r`)); } catch (e) { err = true; }
      // les fonctions « mon organisation » reviennent a l'identite de l'appelant : refus ou reponse vide, jamais les donnees d'une organisation
      const names = ['Societe A', 'Societe B', ...PRIV('A'), ...PRIV('B')];
      check(`Etudiant${s} n'a pas acces aux donnees d'organisation via ${fnc.split('(')[0]}`, err || !names.some((p) => text.includes(p)), text.slice(0, 160));
    }
  }

  // ------------------------------------------------ une organisation non approuvee ne publie pas et ne voit pas les talents
  await sup();
  const C = await b.user(60, 'Societe en attente', 'company');
  await as(C);
  await works('N1 fiche enregistree', `select company_save('{"company_name":"Societe en attente","sector":"Telecoms","city":"Douala"}'::jsonb) r`);
  const talents = async (uid) => { await as(uid); return (await q(`select talents_search('', '', '{}'::text[], 20, 0) r`))[0].r; };
  const t0 = await talents(C);
  check('N2 organisation non approuvee : liste des talents verrouillee et vide', t0.locked === true && t0.total === 0 && t0.items.length === 0, j(t0).slice(0, 200));
  const t1 = await talents(side.A.O);
  check('N2b sonde : l organisation approuvee voit des talents', t1.locked === false && t1.total >= 2, j(t1).slice(0, 200));
  await as(C);
  const tl = (await q(`select talents_list('', 20) r`))[0].r;
  check('N3 talents_list vide pour une organisation non approuvee', Array.isArray(tl) && tl.length === 0, j(tl).slice(0, 100));
  await b.fails('N4 recherche de talents (decouverte) refusee a une organisation non approuvee', `select discovery_search('${C}', null, null, null, null, null, null, null, null, 10, 0) r`, /./).catch(() => {});
  await b.fails('N5 besoin non publiable par une organisation non approuvee', `select save_mission(null, 'Besoin en attente', 'Un besoin decrit avec plus de vingt caracteres', 50000, 100000, '2027-01-31', true, 'besoin', false, null) id`, /v[ée]rifi|approuv|autoris/i);
  await as(C);
  await b.fails('N6 contact d un talent refuse a une organisation non approuvee', `select discovery_contact_request('${side.A.S1}', 'interview', 'Bonjour', '${C}') r`, /./);
  await b.fails('N7 vivier refuse a une organisation non approuvee', `select talent_list_create('Vivier en attente') r`, /v[ée]rifi/i);
  const ctx = (await q(`select company_publish_status('${C}') r`))[0].r;
  check('N8 statut de publication : organisation non approuvee', ctx.status !== 'approved' && ctx.can_publish !== true, JSON.stringify(ctx).slice(0, 250));
  const mine = await qs(`select count(*)::int n from missions where client_id = '${C}' and status = 'published'`);
  check('N9 aucune mission publiee par l organisation non approuvee', mine[0].n === 0);
  await as(C);
  await b.fails('N10 offre : une organisation non approuvee ne publie pas', `select opp_save('Societe en attente', 'stage', 'academique', 'Stagiaire', 'Douala', 'onsite', '3 mois', 'paid', 50000, '', current_date + 10, array['Flutter'], 'Description complete de l offre pour les etudiants', array['Developper'], 'Etudiant motive', 'Informatique', 'L3', array['Transport'], '', true, '', false) id`, /v[ée]rifi|approuv/i);

  // ------------------------------------------------ departement : rattachement et etudiants de SON departement
  for (const s of SIDES) {
    const o = side[s];
    await as(o.H);
    const md = (await q(`select my_department() r`))[0].r;
    check(`D1 ${s} my_department : rattache, departement et etablissement nommes`, md.attached === true && md.department_id === o.D && md.department === o.dname && md.institution === 'Etablissement Matrice', j(md).slice(0, 200));
    const st = (await q(`select dept_students_list('', 100, 0, null) r`))[0].r;
    const names = j(st);
    check(`D2 ${s} etudiants de son departement seulement`, names.includes(`Sandra Talent${s}`) && !names.includes(`Sandra Talent${other(s)}`) && !names.includes(`Serge Invisible${other(s)}`), names.slice(0, 200));
    const ov = (await q(`select dept_overview(null) r`))[0].r;
    check(`D3 ${s} apercu : 2 etudiants declares, 2 verifies`, ov.students === 2 && ov.students_verified === 2, j(ov).slice(0, 200));
    const rp = (await q(`select dept_report('synthese', null, null, null) r`))[0].r;
    check(`D4 ${s} rapport de synthese : calcule sur son departement`, rp.department === o.dname && rp.rows.length > 5, j(rp).slice(0, 200));
    await b.fails(`D5 ${s} rapport demande pour l autre departement refuse`, `select dept_report('synthese', null, null, '${side[other(s)].D}') r`, /pas le v[ôo]tre/);
    await b.fails(`D6 ${s} detail d'un etudiant de l autre departement refuse`, `select dept_student_detail('${side[other(s)].S1}') r`, /introuvable/i);
  }
  // un compte departement non rattache ne voit aucune donnee (pas de repli sur « tout l'etablissement »)
  await sup();
  const Z = await b.user(61, 'Chef sans departement', 'dept');
  await sup();
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${Z}', '${side.A.D}')`).catch(() => {});
  await db.exec(`update profiles set department_id = null, department = '' where id = '${Z}'`);
  await as(Z);
  let zs = [];
  try { zs = (await q(`select dept_students(100) r`))[0].r; } catch (e) { zs = []; }
  check('D7 un responsable dont le departement n est pas verifie ne voit aucun etudiant des autres departements', !j(zs).includes('Sandra TalentB'), j(zs).slice(0, 150));

  await sup();
  b.summary('h132_orgs_isolation');
}
