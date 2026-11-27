// Validation CONNECTEE en LECTURE SEULE des acteurs de Boutik-Ecole : appelle l'API REST d'un projet Supabase avec de vraies sessions de comptes de TEST et verifie
// les droits attendus (autorise / refuse). Aucune ecriture : seules des fonctions de lecture ou des appels qui DOIVENT etre refuses sont executes. Aucun paiement.
//
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_ANON_KEY=<cle publique> node tool/connected/validate_actors.mjs
//   Comptes de test (optionnels, un par acteur ; a creer avec l'ecran « Comptes de test » de l'administrateur, jamais avec de vrais comptes) :
//   TEST_CLIENT=email:motdepasse  TEST_STUDENT=...  TEST_ORG=...  TEST_DEPT=...  TEST_ADMIN=...   (variables d'environnement, jamais dans un fichier du depot)
// Sans compte : seul l'acteur Visiteur est controle. Un acteur sans compte est signale « NON TESTE » (jamais « OK »).
// Sortie : lignes OK / ECHEC / NON TESTE, code de sortie 1 s'il y a un ECHEC.
//
// SCENARIOS D'ECRITURE (H13.1) : WRITE_TESTS=1 ajoute des parcours qui ECRIENT (profil, boutique, annonce, commande a la livraison, mission, evenement...). Ils exigent un projet de TEST :
// meme garde que create_test_accounts.mjs (refus si SUPABASE_URL contient la reference de production zxqcnmgwhtbxkdpjqtlr, si ALLOW_TEST_PROJECT n'est pas defini ou si l'hote n'est pas
// <ref>.supabase.co / localhost). La garde est evaluee AVANT tout appel reseau. Aucune commande n'est payee : seul le paiement a la livraison (confirme par l'acheteur) est joue.
//   WRITE_TESTS=1 ALLOW_TEST_PROJECT=1 SUPABASE_URL=... SUPABASE_ANON_KEY=... TEST_CLIENT=... TEST_STUDENT=... TEST_ORG=... TEST_DEPT=... TEST_ADMIN=... node tool/connected/validate_actors.mjs
import { assertTestEnvironment, GuardError } from './guards.mjs';
const WRITE = process.env.WRITE_TESTS === '1';
if (WRITE) {
  try { assertTestEnvironment(process.env, { keys: [process.env.SUPABASE_ANON_KEY] }); } catch (e) { console.log(e instanceof GuardError ? e.message : `REFUS : ${e.message}`); process.exit(2); }
}
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
// un refus est un 400 (RAISE), 401 ou 403 : un 404 (fonction ou signature inconnue) n'est JAMAIS compte comme un refus
const denied = (r) => [400, 401, 403].includes(r.status);
const PERIOD = new Date().toISOString().slice(0, 7);

// ------------------------------------------------------------ Visiteur (sans compte)
console.log('== Visiteur');
let r = await rpc('top100_national', {});
check('V1 le classement public est lisible sans compte (liste, eventuellement vide)', allowed(r), `HTTP ${r.status}`);
r = await rpc('ranking_history', {});
check('V2 l\'historique des classements est lisible sans compte', allowed(r), `HTTP ${r.status}`);
r = await rpc('verify_certificate', { p_code: 'BE-XXXX-0000' });
check('V3 un code de certificat inconnu est declare inconnu (jamais valide)', allowed(r) && r.body?.valide === false, JSON.stringify(r.body));
for (const fn of ['creator_analytics', 'my_downloads', 'my_talent_dashboard', 'assessment_my_list', 'discovery_search', 'admin_ranking_readiness', 'my_admin_access']) {
  r = await rpc(fn, fn === 'admin_ranking_readiness' ? { p_period: PERIOD } : {}); check(`V4 ${fn} est refuse sans session`, denied(r), `HTTP ${r.status}`);
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
  r = await rpc('my_talent_dashboard', {}, tk); check('C1 un client n\'a pas de tableau de bord de score (reserve aux etudiants)', denied(r), `HTTP ${r.status}`);
  r = await rpc('admin_ranking_readiness', { p_period: PERIOD }, tk); check('C2 un client ne lit pas la preparation de publication du classement', denied(r), `HTTP ${r.status}`);
  r = await rpc('discovery_search', {}, tk); check('C3 un client n\'accede pas a la decouverte de talents (organisations)', denied(r), `HTTP ${r.status}`);
  r = await rpc('assessment_my_list', {}, tk); check('C4 un client lit sa propre liste d\'evaluations', allowed(r) && Array.isArray(r.body), `HTTP ${r.status}`);
  r = await rpc('my_admin_access', {}, tk); check('C5 un client n\'a aucun droit d\'administration', denied(r) || r.body?.is_admin !== true, JSON.stringify(r.body));
}
if (sessions.student) {
  console.log('== Etudiant');
  const tk = sessions.student.token;
  r = await rpc('my_talent_dashboard', {}, tk); check('S1 l\'etudiant lit son tableau de bord de score', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  r = await rpc('my_student_affiliation', {}, tk); check('S2 l\'etudiant lit son rattachement', allowed(r), `HTTP ${r.status}`);
  r = await rpc('assessment_quota', {}, tk); check('S3 l\'etudiant lit son quota d\'evaluation gratuite', allowed(r), `HTTP ${r.status}`);
  r = await rpc('discovery_search', {}, tk); check('S4 un etudiant n\'accede pas a la decouverte de talents', denied(r), `HTTP ${r.status}`);
  r = await rpc('admin_talent_rules_list', {}, tk); check('S5 un etudiant ne lit pas les regles d\'administration du score', denied(r), `HTTP ${r.status}`);
  r = await rpc('assessment_dispatch_claim', { p_limit: 1, p_providers: null }, tk); check('S6 un etudiant ne peut pas reclamer des envois d\'evaluation (service seulement)', denied(r), `HTTP ${r.status}`);
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
  r = await rpc('my_talent_dashboard', {}, tk); check('O2 une organisation n\'a pas de score de talent', denied(r), `HTTP ${r.status}`);
  r = await rpc('admin_ranking_readiness', { p_period: PERIOD }, tk); check('O3 une organisation ne publie pas de classement', denied(r), `HTTP ${r.status}`);
}
if (sessions.dept) {
  console.log('== Responsable de departement');
  const tk = sessions.dept.token;
  r = await rpc('my_ranking_scopes', {}, tk); check('D1 le responsable lit ses perimetres', allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_ranking_readiness', { p_period: PERIOD }, tk); check('D2 le responsable de departement ne publie pas de classement', denied(r), `HTTP ${r.status}`);
  r = await rpc('admin_talent_rules_list', {}, tk); check('D3 le responsable de departement ne lit pas les regles de score', denied(r), `HTTP ${r.status}`);
}
if (sessions.admin) {
  console.log('== Administrateur');
  const tk = sessions.admin.token;
  r = await rpc('my_admin_access', {}, tk); check('A1 l\'administrateur lit ses droits', allowed(r) && r.body?.is_admin === true, JSON.stringify(r.body).slice(0, 120));
  r = await rpc('admin_ranking_readiness', { p_period: PERIOD }, tk); check('A2 l\'administrateur lit la preparation de publication', allowed(r), `HTTP ${r.status}`);
  r = await rpc('admin_talent_rules_list', {}, tk); check('A3 l\'administrateur lit les regles de score', allowed(r), `HTTP ${r.status}`);
}

// ------------------------------------------------------------ Scenarios d'ECRITURE (WRITE_TESTS=1 : projet de TEST uniquement, garde evaluee en tete de fichier)
if (WRITE) {
  console.log('== ECRITURE (projet de test)');
  const tag = `H131-${Date.now().toString(36)}`;
  const MEDIA = process.env.MEDIA_BASE ?? `${URL_}/storage/v1/object/public`; // les medias d'annonce doivent venir du stockage de l'application
  const rest = async (method, path, body, token, prefer = 'return=representation') => {
    const r = await fetch(`${URL_}/rest/v1/${path}`, { method, headers: { apikey: KEY, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Prefer: prefer }, body: body === undefined ? undefined : JSON.stringify(body) });
    let j = null; try { j = await r.json(); } catch { /* corps vide */ }
    return { status: r.status, body: j };
  };
  const refused = (res) => res.status >= 400 || (Array.isArray(res.body) && res.body.length === 0);
  const need = (label, ...keys) => { const miss = keys.filter((k) => !sessions[k]); if (miss.length) { skipped++; out('NON TESTE', `${label} : comptes de test manquants (${miss.join(', ')})`); return false; } return true; };
  const T = (k) => sessions[k].token;

  if (need('W-Client (profil, preferences)', 'client')) {
    const uid = sessions.client.uid;
    r = await rest('PATCH', `profiles?id=eq.${uid}`, { bio: `Bio de test ${tag}` }, T('client'));
    check('W1 le client modifie sa propre bio', r.status === 200 && r.body?.[0]?.bio === `Bio de test ${tag}`, `HTTP ${r.status}`);
    r = await rest('PATCH', `profiles?id=eq.${uid}`, { role: 'admin' }, T('client'));
    check('W2 le client ne s\'attribue pas le role administrateur', refused(r), `HTTP ${r.status}`);
    r = await rest('PATCH', `profiles?id=eq.${uid}`, { certification: 'approved' }, T('client'));
    check('W3 le client ne s\'attribue pas la certification', refused(r), `HTTP ${r.status}`);
    r = await rpc('set_notification_preference', { p_channel: 'inapp', p_kind: 'cat:orders', p_enabled: true }, T('client'));
    check('W4 le client regle ses preferences de notification', allowed(r), `HTTP ${r.status}`);
    r = await rpc('mark_notifications_read', {}, T('client'));
    check('W5 le client marque ses notifications comme lues', allowed(r), `HTTP ${r.status}`);
    r = await rpc('save_mission', { p_id: null, p_title: `Besoin ${tag}`, p_description: 'Un besoin decrit avec plus de vingt caracteres', p_budget_min: 1000, p_budget_max: 2000, p_deadline: '2030-01-31', p_publish: true, p_kind: 'besoin', p_unpublish: false, p_owner: null }, T('client'));
    check('W6 un client (compte non organisation) peut publier un besoin', allowed(r), `HTTP ${r.status}`);
  }

  if (need('W-Chaine etudiant -> administrateur -> client (boutique, annonce, commande a la livraison)', 'student', 'admin', 'client')) {
    const sUid = sessions.student.uid;
    r = await rpc('my_seller_capability', {}, T('student'));
    check('W10 l\'etudiant de test a la capacite de vente (rattachement, piece, telephone fictif)', allowed(r) && r.body?.can_sell === true, JSON.stringify(r.body).slice(0, 160));
    const mine = await rpc('my_shop', {}, T('student'));
    const status = mine.body?.status ?? mine.body?.shop?.status ?? null;
    if (status !== 'active') {
      r = await rpc('shop_save', { p: { name: `Boutique ${tag}`, description: 'Boutique de test', logo_url: `${MEDIA}/listing-images/${sUid}/boutique/logo.png`, categories: ['Maison'] } }, T('student'));
      check('W11 l\'etudiant cree sa boutique', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
      r = await rpc('shop_submit', {}, T('student'));
      check('W12 il la soumet a la moderation', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
      const sid = (await rest('GET', `shops?owner_id=eq.${sUid}&select=id`, undefined, T('student'))).body?.[0]?.id;
      r = await rpc('shop_decide', { p_shop: sid, p_action: 'approve' }, T('client'));
      check('W13 un client ne valide pas une boutique', denied(r), `HTTP ${r.status}`);
      r = await rpc('shop_decide', { p_shop: sid, p_action: 'approve' }, T('admin'));
      check('W14 l\'administrateur valide la boutique', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
    } else { out('OK', 'W11-14 la boutique de test est deja active (reutilisee)'); ok++; }
    const shopId = (await rest('GET', `shops?owner_id=eq.${sUid}&select=id`, undefined, T('student'))).body?.[0]?.id;
    r = await rest('POST', 'listings', { seller_id: sUid, title: `Lampe ${tag}`, department: 'Departement de TEST A', category: 'Maison', price: 7000, stock: 3, description: 'Annonce de test', status: 'pending', shop_id: shopId, images: [`${MEDIA}/listing-images/${sUid}/${tag}.jpg`] }, T('student'));
    const lid = r.body?.[0]?.id;
    check('W15 l\'etudiant publie une annonce (en moderation)', r.status === 201 && !!lid, `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 160)}`);
    r = await rest('PATCH', `listings?id=eq.${lid}`, { status: 'approved' }, T('student'));
    check('W16 il ne se valide pas lui-meme l\'annonce', refused(r) || r.body?.[0]?.status !== 'approved', `HTTP ${r.status}`);
    r = await rest('PATCH', `listings?id=eq.${lid}`, { status: 'approved' }, T('admin'));
    check('W17 l\'administrateur valide l\'annonce', r.status === 200 && r.body?.[0]?.status === 'approved', `HTTP ${r.status}`);
    r = await rpc('marketplace_checkout', { p_items: [{ id: lid, qty: 1 }], p_home: false, p_method: 'Paiement à la livraison', p_address: null, p_code: null, p_key: `cle-${tag}-0001` }, T('client'));
    const num = r.body?.number;
    check('W18 le client commande (paiement a la livraison, aucun argent encaisse)', allowed(r) && !!num, `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 160)}`);
    r = await rpc('marketplace_checkout', { p_items: [{ id: lid, qty: 1 }], p_home: false, p_method: 'Paiement à la livraison', p_address: null, p_code: null, p_key: `cle-${tag}-0001` }, T('client'));
    check('W19 le double envoi (meme cle) renvoie la meme commande', allowed(r) && r.body?.number === num, `HTTP ${r.status}`);
    r = await rpc('confirm_cod_order', { p_number: num }, T('client'));
    check('W20 le client confirme sa commande a la livraison', allowed(r), `HTTP ${r.status}`);
    r = await rpc('seller_orders', {}, T('student'));
    check('W21 le vendeur voit la commande', allowed(r) && JSON.stringify(r.body).includes(num), `HTTP ${r.status}`);
    r = await rpc('set_seller_order_status', { p_order: num, p_status: 1 }, T('client'));
    check('W22 l\'acheteur ne fait pas avancer sa propre commande', denied(r), `HTTP ${r.status}`);
    r = await rpc('set_seller_order_status', { p_order: num, p_status: 1 }, T('student'));
    check('W23 le vendeur fait avancer la commande', allowed(r), `HTTP ${r.status}`);
    r = await rpc('order_tracking', { p_number: num }, T('client'));
    check('W24 l\'acheteur suit sa commande', allowed(r), `HTTP ${r.status}`);
    if (sessions.dept) {
      const o = await rest('GET', `orders?number=eq.${encodeURIComponent(num)}&select=number`, undefined, T('dept'));
      check('W25 le responsable de departement ne lit pas la commande d\'un client', refused(o), `HTTP ${o.status}`);
    }
  }

  if (need('W-Organisation (vivier, mission)', 'org', 'client')) {
    r = await rpc('talent_list_create', { p_name: `Liste ${tag}` }, T('org'));
    check('W30 l\'organisation verifiee cree une liste de vivier', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
    r = await rpc('talent_list_create', { p_name: `Liste ${tag}` }, T('client'));
    check('W31 un client ne cree pas de vivier', denied(r), `HTTP ${r.status}`);
    r = await rpc('save_mission', { p_id: null, p_title: `Besoin ${tag}`, p_description: 'Un besoin decrit avec plus de vingt caracteres', p_budget_min: 1000, p_budget_max: 2000, p_deadline: '2030-01-31', p_publish: true, p_kind: 'besoin', p_unpublish: false, p_owner: null }, T('org'));
    check('W32 l\'organisation verifiee publie un besoin', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
  }

  if (need('W-Departement (productions, evenements)', 'dept', 'student')) {
    r = await rpc('production_create', { p_title: `Production ${tag}`, p_team: 'Equipe de test', p_mentor: null, p_due: null }, T('dept'));
    check('W40 le responsable cree une production de son departement', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
    r = await rpc('production_create', { p_title: `Production ${tag}`, p_team: 'x', p_mentor: null, p_due: null }, T('student'));
    check('W41 un etudiant ne cree pas de production', denied(r), `HTTP ${r.status}`);
    const when = new Date(Date.now() + 10 * 864e5).toISOString();
    r = await rpc('event_create', { p_title: `Evenement ${tag}`, p_description: 'Evenement de test', p_kind: 'atelier', p_starts: when, p_ends: null, p_place: 'Salle de test', p_price: 0, p_capacity: 20 }, T('dept'));
    check('W42 le responsable cree un evenement', allowed(r), `HTTP ${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
    r = await rpc('event_create', { p_title: `Evenement ${tag}`, p_description: 'x', p_kind: 'atelier', p_starts: when, p_ends: null, p_place: 'x', p_price: 0, p_capacity: 20 }, T('student'));
    check('W43 un etudiant ne cree pas d\'evenement', denied(r), `HTTP ${r.status}`);
    r = await rpc('dept_overview', {}, T('dept'));
    check('W44 le responsable lit la vue d\'ensemble de son departement', allowed(r), `HTTP ${r.status}`);
  }

  if (need('W-Administrateur (utilisateurs, audit)', 'admin', 'client')) {
    r = await rpc('admin_users', { p_roles: null, p_limit: 20 }, T('admin'));
    check('W50 l\'administrateur liste les utilisateurs', allowed(r) && Array.isArray(r.body), `HTTP ${r.status}`);
    r = await rpc('admin_users', { p_roles: null, p_limit: 20 }, T('client'));
    check('W51 un client ne liste pas les utilisateurs', denied(r), `HTTP ${r.status}`);
    r = await rpc('admin_orders', { p_limit: 20 }, T('admin'));
    check('W52 l\'administrateur lit les commandes de la plateforme', allowed(r), `HTTP ${r.status}`);
    const a = await rest('GET', 'audit_log?select=id&limit=5', undefined, T('admin'));
    check('W53 l\'administrateur lit le journal d\'audit', a.status === 200 && Array.isArray(a.body), `HTTP ${a.status}`);
    const c = await rest('GET', 'audit_log?select=id&limit=5', undefined, T('client'));
    check('W54 un client ne lit aucune ligne du journal d\'audit', refused(c), `HTTP ${c.status}`);
  }
}

console.log(`validate_actors : ${ok} OK, ${ko} ECHEC, ${skipped} acteur(s) NON TESTE(S)`);
process.exit(ko ? 1 : 0);



