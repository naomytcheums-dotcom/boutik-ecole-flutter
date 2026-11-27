// Creation de COMPTES DE TEST (5 acteurs) dans un projet Supabase de TEST explicitement fourni. Ne tourne JAMAIS sur la production.
//
//   SUPABASE_URL=https://<ref-de-test>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<cle service du projet de TEST> \
//   ALLOW_TEST_PROJECT=1 TEST_PASSWORD=<mot de passe choisi, 12 caracteres au moins> node tool/connected/create_test_accounts.mjs [--dry-run]
//
// Garde-fous : refuse si SUPABASE_URL contient la reference de production zxqcnmgwhtbxkdpjqtlr, si ALLOW_TEST_PROJECT n'est pas defini, si l'hote n'est pas
// <ref>.supabase.co ou localhost. --dry-run : affiche ce qui serait cree, sans aucun appel reseau.
// Cree 5 acteurs (client, etudiant-vendeur, organisation, responsable de departement, administrateur) avec des e-mails en @test.invalid et leurs affiliations
// (etablissement et departements de test, filiere, rattachement verifie de l'etudiant, compte de departement, organisation verifiee). Idempotent : relancer ne duplique rien.
// Le mot de passe vient de l'environnement ; il n'est jamais ecrit ni affiche. Aucun numero de telephone reel : l'etudiant recoit un numero fictif.
import { pathToFileURL } from 'node:url';
import { assertTestEnvironment, GuardError, TEST_DOMAIN } from './guards.mjs';

const id = (n) => `00000000-0000-4131-8000-${String(n).padStart(12, '0')}`;
export const FIXTURES = {
  institution: id(0xa1), deptA: id(0xa2), deptB: id(0xa3), program: id(0xa4), affiliation: id(0xa5), document: id(0xa6),
};

export const ACTORS = [
  { key: 'client', role: 'client', name: 'Test H131 Client', email: `client-h131@${TEST_DOMAIN}` },
  { key: 'student', role: 'student', name: 'Test H131 Etudiant', email: `etudiant-h131@${TEST_DOMAIN}`, phone: '600000131' },
  { key: 'org', role: 'company', name: 'Test H131 Organisation', email: `organisation-h131@${TEST_DOMAIN}` },
  { key: 'dept', role: 'dept', name: 'Test H131 Departement', email: `departement-h131@${TEST_DOMAIN}` },
  { key: 'admin', role: 'admin', name: 'Test H131 Administrateur', email: `admin-h131@${TEST_DOMAIN}` },
];

export const validPassword = (p) => typeof p === 'string' && p.length >= 12 && p.length <= 72 && /[A-Za-z]/.test(p) && /[0-9]/.test(p);

export async function run({ env = process.env, argv = process.argv.slice(2), fetchImpl = fetch, log = console.log } = {}) {
  const dry = argv.includes('--dry-run');
  const { url } = assertTestEnvironment(env, { keys: [env.SUPABASE_SERVICE_ROLE_KEY] });
  const key = env.SUPABASE_SERVICE_ROLE_KEY ?? '';
  const password = env.TEST_PASSWORD ?? '';
  if (!dry) {
    if (!key) throw new GuardError('REFUS : SUPABASE_SERVICE_ROLE_KEY est obligatoire (cle service du projet de TEST).');
    if (!validPassword(password)) throw new GuardError('REFUS : TEST_PASSWORD (12 caracteres au moins, avec une lettre et un chiffre) est obligatoire.');
  }
  log(`${dry ? '[DRY-RUN] ' : ''}Projet de test : ${new URL(url).host}`);
  const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
  const rest = async (table, rows, onConflict) => {
    const r = await fetchImpl(`${url}/rest/v1/${table}?on_conflict=${onConflict}`, { method: 'POST', headers: { ...headers, Prefer: 'resolution=merge-duplicates,return=minimal' }, body: JSON.stringify(rows) });
    if (!r.ok) throw new Error(`${table} : HTTP ${r.status} ${(await r.text()).slice(0, 200)}`);
  };
  const authUser = async (a) => {
    const r = await fetchImpl(`${url}/auth/v1/admin/users`, { method: 'POST', headers, body: JSON.stringify({ email: a.email, password, email_confirm: true, user_metadata: { name: a.name, test_account: true } }) });
    const j = await r.json().catch(() => ({}));
    if (r.ok && j.id) return { id: j.id, created: true };
    if (r.status === 422 || r.status === 409) {
      for (let page = 1; page <= 20; page++) {
        const l = await fetchImpl(`${url}/auth/v1/admin/users?page=${page}&per_page=200`, { headers });
        const lj = await l.json().catch(() => ({}));
        const found = (lj.users ?? []).find((u) => String(u.email).toLowerCase() === a.email);
        if (found) {
          // le mot de passe est realigne : un compte de test deja present reste utilisable avec le mot de passe fourni
          await fetchImpl(`${url}/auth/v1/admin/users/${found.id}`, { method: 'PUT', headers, body: JSON.stringify({ password, email_confirm: true }) });
          return { id: found.id, created: false };
        }
        if ((lj.users ?? []).length < 200) break;
      }
    }
    throw new Error(`creation de ${a.email} : HTTP ${r.status} ${JSON.stringify(j).slice(0, 160)}`);
  };

  const ids = {};
  for (const a of ACTORS) {
    if (dry) { log(`[DRY-RUN] compte ${a.key} : ${a.email} (role ${a.role})`); ids[a.key] = `<id-${a.key}>`; continue; }
    const r = await authUser(a);
    ids[a.key] = r.id;
    log(`${r.created ? 'cree  ' : 'existe'} ${a.key.padEnd(8)} ${a.email}`);
  }
  const plan = [];
  const step = async (label, fn) => { plan.push(label); if (dry) { log(`[DRY-RUN] ${label}`); return; } await fn(); log(`ok     ${label}`); };

  await step('referentiel de test : etablissement et deux departements', async () => {
    await rest('institutions', [{ id: FIXTURES.institution, name: 'Etablissement de TEST H131', status: 'verified' }], 'id');
    await rest('departments', [{ id: FIXTURES.deptA, institution_id: FIXTURES.institution, name: 'Departement de TEST A', status: 'verified' }, { id: FIXTURES.deptB, institution_id: FIXTURES.institution, name: 'Departement de TEST B', status: 'verified' }], 'id');
    await rest('programs', [{ id: FIXTURES.program, institution_id: FIXTURES.institution, department_id: FIXTURES.deptA, name: 'Filiere de TEST', active: true }], 'id');
  });
  await step('profils des 5 acteurs (is_test = true, affiliations)', async () => {
    const rows = ACTORS.map((a) => ({
      id: ids[a.key], name: a.name, email: a.email, role: a.role, is_test: true, city: 'Douala',
      ...(a.key === 'student' ? { phone: a.phone, phone_verified: true, certification: 'approved', institution_id: FIXTURES.institution, department_id: FIXTURES.deptA, department: 'Departement de TEST A' } : {}),
      ...(a.key === 'dept' ? { institution_id: FIXTURES.institution, department_id: FIXTURES.deptA, department: 'Departement de TEST A' } : {}),
    }));
    // une requete par profil : un lot aux colonnes differentes mettrait NULL (et non la valeur par defaut) dans les colonnes absentes
    for (const row of rows) await rest('profiles', [row], 'id');
  });
  await step('etudiant : rattachement verifie a la filiere et carte d\'etudiant verifiee', async () => {
    await rest('student_affiliations', [{ id: FIXTURES.affiliation, user_id: ids.student, institution_id: FIXTURES.institution, department_id: FIXTURES.deptA, program_id: FIXTURES.program, promotion: '2026', status: 'verified' }], 'id');
    await rest('user_documents', [{ id: FIXTURES.document, owner_id: ids.student, kind: 'student_card', name: 'carte-test.pdf', path: `${ids.student}/student_card/carte-test.pdf`, mime: 'application/pdf', size_bytes: 10, status: 'verified' }], 'id');
  });
  await step('responsable : compte de departement rattache au departement de test A', async () => {
    await rest('department_accounts', [{ user_id: ids.dept, department_id: FIXTURES.deptA, title: 'Responsable de TEST', assigned_by: ids.admin }], 'user_id');
  });
  await step('organisation : fiche verifiee (organisation de test)', async () => {
    await rest('company_profiles', [{ owner_id: ids.org, company_name: 'Organisation de TEST H131', status: 'approved', sector: 'Test', city: 'Douala', contact_name: 'Contact de test', contact_role: 'Test' }], 'owner_id');
  });

  log(dry ? '[DRY-RUN] aucun appel reseau effectue.' : `Termine : ${ACTORS.length} acteurs de test prets (e-mails @${TEST_DOMAIN}).`);
  log('Variables pour validate_actors.mjs (le mot de passe est celui de TEST_PASSWORD) :');
  for (const a of ACTORS) log(`  TEST_${a.key.toUpperCase()}=${a.email}:<TEST_PASSWORD>`);
  return { ids, plan, dry };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run().catch((e) => { console.error(e instanceof GuardError ? e.message : `ECHEC : ${e.message}`); process.exit(e instanceof GuardError ? 2 : 1); });
}

