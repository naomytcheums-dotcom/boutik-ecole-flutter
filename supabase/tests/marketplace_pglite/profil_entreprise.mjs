let ok = 0, ko = 0;
export async function run(db) {
  const E = '00000000-0000-0000-0000-0000000000e1', S = '00000000-0000-0000-0000-0000000000a1', C = '00000000-0000-0000-0000-0000000000c1';
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role authenticated`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[E, 'Orange Cameroun', 'company'], [S, 'Sara Etudiante', 'student'], [C, 'Carl Client', 'client']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, description) values ('${E}', 'Orange Cameroun', 'approved', 'Telecoms', 'Douala', 'Operateur')`);
  await db.exec(`insert into opportunities (poster_id, org_name, kind, title, status) values ('${E}', 'Orange Cameroun', 'stage', 'Stage developpeur', 'published'), ('${E}', 'Orange Cameroun', 'emploi', 'Brouillon cache', 'pending')`);
  // couverture
  await as(E);
  await fails('couverture : dossier d un autre refuse', `select company_cover_set('${S}/cover.jpg')`, /Image invalide/);
  await q(`select company_cover_set('${E}/cover.jpg')`);
  await as(S);
  await fails('couverture : un tiers ne la change pas', `select company_cover_set('${S}/x.jpg', '${E}')`, /Accès refusé/);
  // vue
  const v = (await q(`select company_profile_view('${E}') r`))[0].r;
  check('vue publique : fiche et couverture', v.company_name === 'Orange Cameroun' && v.cover_path === `${E}/cover.jpg` && v.verified === true && v.mine === false);
  check('vue publique : seulement les offres publiees', v.offers.length === 1 && v.offers[0].title === 'Stage developpeur');
  check('vue publique : pas d interlocuteur ni de numero', v.contact_name === undefined && v.registration_number === undefined && v.status === null);
  await as(E);
  const m = (await q(`select company_profile_view() r`))[0].r;
  check('vue du proprietaire : mine et statut', m.mine === true && m.status === 'approved');
  await as(null);
  await fails('vue : connexion requise', `select company_profile_view('${E}')`, /Connexion requise|permission/);
  // boutique reservee aux etudiants
  await as(C);
  await fails('boutique : un client ne peut pas en creer', `select shop_save(jsonb_build_object('name','Ma Boutique','slug','ma-boutique'))`, /réservée aux étudiants/);
  await as(E);
  await fails('boutique : une entreprise ne peut pas en creer', `select shop_save(jsonb_build_object('name','Boutique E','slug','boutique-e'))`, /réservée aux étudiants/);
  await as(S);
  check('boutique : un etudiant peut en creer', (await q(`select shop_save(jsonb_build_object('name','Boutique Sara','slug','boutique-sara')) r`)).length === 1);
  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}
