// Scénario SQL : compétences, portfolio, fiche projet complète (migration 20261110000000).
//   Rejeu PGlite : voir supabase/tests/marketplace_pglite/README.md ; node replay.mjs all <ce fichier>
let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-0000000000a1', B = '00000000-0000-0000-0000-0000000000b1';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  for (const [id, n] of [[A, 'a'], [B, 'b']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${n}@t.cm') on conflict do nothing`);
    await db.exec(`insert into profiles(id,name,role,email) values ('${id}','${n}','student','${n}@t.cm') on conflict (id) do update set role='student'`);
  }
  await as(A);
  let r = await q(`select count(*)::int c from skill_catalog where domain = 'Génie civil' and job = '' and skill = ''`);
  check('domaine Génie civil au catalogue', r[0].c === 1);
  r = await q(`select count(*)::int c from skill_catalog where domain = 'Génie civil' and job = 'Topographe' and skill <> ''`);
  check('compétences du topographe', r[0].c >= 4, JSON.stringify(r));
  await q(`select catalog_propose('Génie civil', 'Métreur', 'Avant-métré')`);
  r = await q(`select count(*)::int c from skill_catalog where status = 'proposed'`);
  check('proposition visible de son auteur (2 lignes)', r[0].c === 2, JSON.stringify(r));
  await as(B);
  r = await q(`select count(*)::int c from skill_catalog where status = 'proposed'`);
  check('proposition invisible pour un autre compte', r[0].c === 0);

  await as(A);
  const s1 = (await q(`select skill_save(null, 'Génie civil', 'Topographe', 'Levé topographique', 'avance', 3.5, 'Chantiers de voirie', null) id`))[0].id;
  r = await q(`select skills from profiles where id = '${A}'`);
  check('profil : compétences synchronisées', r[0].skills === 'Levé topographique', JSON.stringify(r));
  await fails('doublon refusé', `select skill_save(null, 'Génie civil', 'Topographe', 'Levé topographique', 'debutant', 0, '', null)`, /déjà/);
  await fails('niveau invalide', `select skill_save(null, 'Génie civil', '', 'Béton armé', 'dieu', 0, '', null)`, /niveau/);
  await fails('justificatif inconnu refusé', `select skill_save(null, 'Génie civil', '', 'Béton armé', 'avance', 1, '', gen_random_uuid())`, /Justificatif/);
  await q(`select skill_save('${s1}', 'Génie civil', 'Topographe', 'Levé topographique', 'expert', 5, 'Mise à jour', null)`);
  r = await q(`select level from talent_skills where id = '${s1}'`);
  check('modification du niveau', r[0].level === 'expert');
  await as(B);
  await fails('B ne peut pas supprimer la compétence de A', `select skill_delete('${s1}')`, /introuvable/);
  await as(A);
  await q(`select skill_delete('${s1}')`);
  r = await q(`select skills from profiles where id = '${A}'`);
  check('suppression : profil resynchronisé', r[0].skills === '');

  const p1 = (await q(`select portfolio_save(null, 'realisation', 'Pont de Bonaberi', 'Étude', 'Génie civil', '2026', '', null, true) id`))[0].id;
  await q(`select portfolio_save(null, 'link', 'Mon site', '', '', '', 'https://exemple.cm', null, true)`);
  r = await q(`select count(*)::int c from portfolio_items where owner_id = '${A}' and featured`);
  check('un seul élément phare', r[0].c === 1);
  await fails('lien invalide refusé', `select portfolio_save(null, 'link', 'xy', '', '', '', 'javascript:alert(1)', null, false)`, /http/);
  await fails('fichier d un autre dossier refusé', `select portfolio_save(null, 'image', 'photo', '', '', '', '', '${B}/x.png', false)`, /non autorisé/);
  await as(null, 'anon');
  r = await q(`select count(*)::int c from portfolio_items`);
  check('portfolio lisible publiquement', r[0].c === 2);
  await as(B);
  await fails('B ne supprime pas le portfolio de A', `select portfolio_delete('${p1}')`, /introuvable/);
  await as(A);
  await q(`select portfolio_delete('${p1}')`);

  await fails('publication incomplète refusée', `select project_save_full(null, 'innovation', 'Filtre à sable', 'court', '', '{}', '[]', 'public', true)`, /complétez/);
  const j1 = (await q(`select project_save_full(null, 'innovation', 'Filtre à sable', '', '', '{}', '[]', 'public', false) id`))[0].id;
  r = await q(`select status from projects where id = '${j1}'`);
  check('brouillon enregistré sans champs obligatoires', r[0].status === 'draft');
  const det = JSON.stringify({ domain: 'Génie civil', problem: 'Eau non potable en zone rurale', solution: 'Filtre modulaire à sable', progress: 'Prototype', contact_email: 'a@t.cm' });
  await q(`select project_save_full('${j1}', 'innovation', 'Filtre à sable', 'Un filtre modulaire pour rendre l eau potable en zone rurale.', 'Génie civil', '${det}', '[]', 'public', true)`);
  r = await q(`select status from projects where id = '${j1}'`);
  check('publication complète : envoyé pour examen', r[0].status === 'submitted');
  await fails('projet en examen non modifiable', `select project_save_full('${j1}', 'innovation', 'Autre', '', '', '{}', '[]', 'public', false)`, /examen/);
  await as(B);
  r = await q(`select count(*)::int c from projects`);
  check('projet non approuvé invisible pour un autre', r[0].c === 0);
  await fails('B ne modifie pas le projet de A', `select project_save_full('${j1}', 'innovation', 'Pirate', '', '', '{}', '[]', 'public', false)`, /introuvable/);
  const j2 = (await q(`select project_save_full(null, 'projet', 'Brouillon B', '', '', '{}', '[]', 'private', false) id`))[0].id;
  await q(`select project_delete('${j2}')`);
  await as(A);
  await fails('projet envoyé non supprimable', `select project_delete('${j1}')`, /brouillons/);
  console.log(`\n${ok}/${ok + ko}`);
}
