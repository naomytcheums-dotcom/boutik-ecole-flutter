// Validation CONNECTEE en LECTURE SEULE des acteurs de Boutik-Ecole : appelle l'API REST d'un projet Supabase avec de vraies sessions de comptes de TEST et verifie
// les droits attendus (autorise / refuse). Aucune ecriture : seules des fonctions de lecture ou des appels qui DOIVENT etre refuses sont executes. Aucun paiement.
//
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<cle publique> node tool/connected/validate_actors.mjs
//   Comptes de test (optionnels, un par acteur ; a creer avec l'ecran « Comptes de test » de l'administrateur, jamais avec de vrais comptes) :
//   TEST_CLIENT=email:motdepasse  TEST_STUDENT=...  TEST_ORG=...  TEST_DEPT=...  TEST_ADMIN=...   (variables d'environnement, jamais dans un fichier du depot)
// Sans compte : seul l'acteur Visiteur est controle. Un acteur sans compte est signale « NON TESTE » (jamais « OK »).
// Sortie : lignes OK / ECHEC / NON TESTE, code de sortie 1 s'il y a un ECHEC.
const URL_ = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
const KEY = process.env.SUPABASE_ANON_KEY ?? '';
if (!URL_ || !KEY) { console.log('SUPABASE_URL et SUPABASE_ANON_KEY sont obligatoires'); process.exit(2); }

let ok = 0, ko = 0, skipped = 0;
const out = (kind, name, extra = '') => console.log(kind, name, extra);
const check = (name, cond, extra = '') => { if (cond) { ok++; out('OK', name); } else { ko++; out('ECHEC', name, extra); } };

async function rpc(fn, args = {}, token = null) {
  const r = await fetch(`${URL_}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { apikey: KEY, Authorization: `Bearer ${token ?? KEY}`, 'Content-Type': 'application/json' }, body: JSON.stringify(args) });
  let body = null; try { body = await r.json(); } catch { /* corps vide */ }
  return { status: r.status, body };
}
async function login(spec) {
  const [email, ...rest] = spec.split(':'); const password = rest.join(':');
  const r = await fetch(`${URL_}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
  const j = await r.json().catch(() => ({}));
  return r.ok ? { token: j.access_token, uid: j.user?.id } : null;
}
const allowed = (r) => r.status === 200;

// ------------------------------------------------------------ Visiteur (sans compte)
console.log('== Visiteur');
let r = await rpc('top100_national', {});
check('V1 le classement public est lisible sans compte (liste, eventuellement vide)', allowed(r), `HTTP ${r.status}`);
r = await rpc('ranking_history', {});
check('V2 l\'historique des classements est lisible sans compte', allowed(r), `HTTP ${r.status}`);
r = await rpc('verify_certificate', { p_code: 'BE-XXXX-0000' });
check('V3 un code de certificat inconnu est declare inconnu (jamais valide)', allowed(r) && r.body?.valide === false, JSON.stringify(r.body));
for (const fn of ['creator_analytics', 'my_downloads', 'my_talent_dashboard', 'assessment_my_list', 'discovery_search', 'admin_ranking_readiness', 'my_admin_access']) {
  r = await rpc(fn, {}); check(`V4 ${fn} est refuse sans session`, !allowed(r), `HTTP ${r.status}`);
}
const t = await fetch(`${URL_}/rest/v1/profiles?select=*`, { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } });
const rows = await t.json().catch(() => []);
check('V5 la table profiles n\'est pas lisible en entier sans session', !(t.ok && Array.isArray(rows) && rows.length > 1), `HTTP ${t.status}, ${Array.isArray(rows) ? rows.length : '?'} lignes`);

// ------------------------------------------------------------ Acteurs connectes
const actors = { client: process.env.TEST_CLIENT, student: process.env.TEST_STUDENT, org: process.env.TEST_ORG, dept: process.env.TEST_DEPT, admin: process.env.TEST_ADMIN };
const sessions = {};
for (const [k, spec] of Object.entries(actors)) {
  if (!spec) { skipped++; out('NON TESTE', `acteur ${k} : aucun compte de test fourni (TEST_${k.toUpperCase()})`); continue; }
  const s = await login(spec);
  if (!s) { ko++; out('ECHEC', `connexion du compte de test ${k}`, 'refusee'); continue; }
  sessions[k] = s; ok++; out('OK', `connexion du compte de test ${k}`);
}

if (sessions.client) {
  console.log('== Client');
  const tk = sessions.client.token;
  r = await rpc('my_talent_dashboard', {}, tk); check('C1 un client n\'a pas de tableau de bord de score (reserve aux etudiants)', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_ranking_readiness', {}, tk); check('C2 un client ne lit pas la preparation de publication du classement', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('discovery_search', {}, tk); check('C3 un client n\'accede pas a la decouverte de talents (organisations)', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('assessment_my_list', {}, tk); check('C4 un client lit sa propre liste d\'evaluations', allowed(r) && Array.isArray(r.body), `HTTP ${r.status}`);
  r = await rpc('my_admin_access', {}, tk); check('C5 un client n\'a aucun droit d\'administration', !allowed(r) || r.body?.is_admin !== true, JSON.stringify(r.body));
}
if (sessions.student) {
  console.log('== Etudiant');
  const tk = sessions.student.token;
  r = await rpc('my_talent_dashboard', {}, tk); check('S1 l\'etudiant lit son tableau de bord de score', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await rpc('my_student_affiliation', {}, tk); check('S2 l\'etudiant lit son rattachement', allowed(r), `HTTP ${r.status}`);
  r = await rpc('assessment_quota', {}, tk); check('S3 l\'etudiant lit son quota d\'evaluation gratuite', allowed(r), `HTTP ${r.status}`);
  r = await rpc('discovery_search', {}, tk); check('S4 un etudiant n\'accede pas a la decouverte de talents', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_talent_rules_list', {}, tk); check('S5 un etudiant ne lit pas les regles d\'administration du score', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('assessment_dispatch_claim', { p_limit: 1, p_providers: null }, tk); check('S6 un etudiant ne peut pas reclamer des envois d\'evaluation (service seulement)', !allowed(r), `HTTP ${r.status}`);
  if (sessions.client) {
    const mine = await rpc('assessment_my_list', {}, tk); const theirs = await rpc('assessment_my_list', {}, sessions.client.token);
    const a = new Set((mine.body ?? []).map((x) => x.id)); const overlap = (theirs.body ?? []).filter((x) => a.has(x.id));
    check('S7 isolation : aucune demande d\'evaluation commune entre l\'etudiant et le client', overlap.length === 0, `${overlap.length} en commun`);
  }
}
if (sessions.org) {
  console.log('== Organisation');
  const tk = sessions.org.token;
  r = await rpc('discovery_favorites', {}, tk); check('O1 l\'organisation lit ses favoris de talents', allowed(r), `HTTP ${r.status}`);
  r = await rpc('my_talent_dashboard', {}, tk); check('O2 une organisation n\'a pas de score de talent', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_ranking_readiness', {}, tk); check('O3 une organisation ne publie pas de classement', !allowed(r), `HTTP ${r.status}`);
}
if (sessions.dept) {
  console.log('== Responsable de departement');
  const tk = sessions.dept.token;
  r = await rpc('my_ranking_scopes', {}, tk); check('D1 le responsable lit ses perimetres', allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_ranking_readiness', {}, tk); check('D2 le responsable de departement ne publie pas de classement', !allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_talent_rules_list', {}, tk); check('D3 le responsable de departement ne lit pas les regles de score', !allowed(r), `HTTP ${r.status}`);
}
if (sessions.admin) {
  console.log('== Administrateur');
  const tk = sessions.admin.token;
  r = await rpc('my_admin_access', {}, tk); check('A1 l\'administrateur lit ses droits', allowed(r) && r.body?.is_admin === true, JSON.stringify(r.body).slice(0, 120));
  r = await rpc('admin_ranking_readiness', {}, tk); check('A2 l\'administrateur lit la preparation de publication', allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_talent_rules_list', {}, tk); check('A3 l\'administrateur lit les regles de score', allowed(r), `HTTP ${r.status}`);
}

console.log(`validate_actors : ${ok} OK, ${ko} ECHEC, ${skipped} acteur(s) NON TESTE(S)`);
process.exit(ko ? 1 : 0);
