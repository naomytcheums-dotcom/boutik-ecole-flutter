// H13.1 lot ACTORS - l'outil tool/connected/create_test_accounts.mjs est joue contre la VRAIE base rejouee (PGlite) : ses requetes REST (profils, referentiel, rattachement, compte de
// departement, organisation) sont traduites en INSERT ... ON CONFLICT executes avec les triggers du schema. Prouve que les donnees des 5 comptes de test sont acceptees par le schema,
// que le relancer est sans effet de bord, puis que chaque acteur obtient les droits attendus (vendeur eligible, departement rattache, organisation verifiee, administrateur).
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h131_outils_comptes_test.mjs
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';
import { bench } from './h131_lib.mjs';

export async function run(db) {
  const b = bench(db, 6);
  const { as, sup, qs, rows, check, works, fails, DENY } = b;
  const here = path.dirname(fileURLToPath(import.meta.url));
  const tool = await import(pathToFileURL(path.resolve(here, '..', '..', '..', 'tool', 'connected', 'create_test_accounts.mjs')).href);
  await sup();
  const json = (code, obj) => ({ ok: code < 300, status: code, json: async () => obj, text: async () => JSON.stringify(obj) });
  let n = 0;
  const fetchImpl = async (url, opts = {}) => {
    const u = new URL(url);
    const method = opts.method ?? 'GET';
    if (u.pathname === '/auth/v1/admin/users' && method === 'POST') {
      const body = JSON.parse(opts.body);
      const have = await rows(`select id from auth.users where email = '${body.email}'`);
      if (have.length) return json(422, { code: 'email_exists' });
      const id = (await rows(`insert into auth.users (id, email) values (gen_random_uuid(), '${body.email}') returning id`))[0].id;
      return json(200, { id, email: body.email });
    }
    if (u.pathname === '/auth/v1/admin/users' && method === 'GET') return json(200, { users: await rows('select id, email from auth.users') });
    if (/^\/auth\/v1\/admin\/users\//.test(u.pathname) && method === 'PUT') return json(200, {});
    const t = /^\/rest\/v1\/([a-z_]+)$/.exec(u.pathname);
    if (t && method === 'POST') {
      const conflict = u.searchParams.get('on_conflict');
      const data = JSON.parse(opts.body);
      const cols = [...new Set(data.flatMap((r) => Object.keys(r)))];
      const set = cols.filter((c) => c !== conflict).map((c) => `${c} = excluded.${c}`).join(', ');
      try {
        await db.query(`insert into ${t[1]} (${cols.join(', ')}) select ${cols.join(', ')} from json_populate_recordset(null::${t[1]}, $1::json) on conflict (${conflict}) do update set ${set}`, [JSON.stringify(data)]);
      } catch (e) { return json(400, { message: e.message }); }
      return json(201, {});
    }
    return json(404, { message: 'route inconnue' });
  };
  const env = { SUPABASE_URL: 'http://127.0.0.1:1', ALLOW_TEST_PROJECT: '1', SUPABASE_SERVICE_ROLE_KEY: 'service-test-key', TEST_PASSWORD: 'Motdepasse1234' };
  const silent = () => {};
  let first;
  try { first = await tool.run({ env, argv: [], fetchImpl, log: silent }); check('T1 l\'outil cree les 5 comptes et leurs affiliations sans erreur de schema', true); } catch (e) { check('T1 l\'outil cree les 5 comptes et leurs affiliations sans erreur de schema', false, e.message); return b.summary('h131_outils_comptes_test'); }
  const ids = first.ids;
  check('T2 cinq comptes d\'authentification en @test.invalid', Number((await qs(`select count(*) c from auth.users where email like '%@test.invalid'`))[0].c) === 5);
  check('T3 cinq profils marques is_test avec les roles attendus', JSON.stringify((await qs(`select role::text r from profiles where is_test order by 1`)).map((x) => x.r)) === JSON.stringify(['admin', 'client', 'company', 'dept', 'student']));
  const before = JSON.stringify(await qs(`select (select count(*) from profiles) p, (select count(*) from institutions) i, (select count(*) from departments) d, (select count(*) from programs) g, (select count(*) from student_affiliations) a, (select count(*) from department_accounts) da, (select count(*) from company_profiles) c, (select count(*) from user_documents) u`));
  await tool.run({ env, argv: [], fetchImpl, log: silent });
  check('T4 relancer l\'outil ne duplique rien (profils, referentiel, rattachement, comptes)', JSON.stringify(await qs(`select (select count(*) from profiles) p, (select count(*) from institutions) i, (select count(*) from departments) d, (select count(*) from programs) g, (select count(*) from student_affiliations) a, (select count(*) from department_accounts) da, (select count(*) from company_profiles) c, (select count(*) from user_documents) u`)) === before);
  check('T5 l\'etablissement et les departements de test sont les seuls du referentiel', Number((await qs('select count(*) c from institutions'))[0].c) === 1 && Number((await qs('select count(*) c from departments'))[0].c) === 2);

  await as(ids.student);
  await works('A1 etudiant de test : capacite de vente complete', `select my_seller_capability() r`, (r) => r[0].r.can_sell === true);
  await works('A2 etudiant de test : rattachement verifie', `select my_student_affiliation() r`, (r) => r[0].r.current?.status === 'verified');
  await as(ids.dept);
  await works('A3 responsable de test : rattache a son departement', `select my_department() r`, (r) => JSON.stringify(r[0].r).includes('Departement de TEST A'));
  await works('A4 responsable de test : vue d\'ensemble', `select dept_overview() r`);
  await works('A5 responsable de test : voit l\'etudiant de test dans sa liste', `select dept_students_list('', 50, 0) r`, (r) => JSON.stringify(r[0].r).includes(ids.student));
  await fails('A6 responsable de test : vue d\'ensemble de l\'autre departement refusee', `select dept_overview('00000000-0000-4131-8000-0000000000a3')`, /pas le vôtre/);
  await as(ids.org);
  await works('A7 organisation de test : verifiee', `select my_organizations() r`, (r) => r[0].r.length === 1 && r[0].r[0].verified === true);
  await as(ids.admin);
  await works('A8 administrateur de test : droits d\'administration', `select my_admin_access() r`, (r) => r[0].r.is_admin === true);
  await as(ids.client);
  await works('A9 client de test : aucun droit d\'administration', `select my_admin_access() r`, (r) => r[0].r.is_admin !== true);
  await fails('A10 client de test : pas de decouverte de talents', `select discovery_search()`, DENY);
  await b.replayMigrations();
  await as(ids.student);
  await works('R1 apres rejeu : l\'etudiant de test reste vendeur eligible', `select my_seller_capability() r`, (r) => r[0].r.can_sell === true);
  b.summary('h131_outils_comptes_test');
}
