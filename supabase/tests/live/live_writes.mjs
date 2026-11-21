// Écritures RÉELLES sur le serveur Supabase avec les comptes de test (données marquées « [TEST ECRITURE] », supprimées ou annulées en fin de scénario).
// Usage : LIVE_PASSWORD=... node supabase/tests/live/live_writes.mjs
const url = process.env.LIVE_URL || 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co', key = process.env.LIVE_KEY || 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01', PW = process.env.LIVE_PASSWORD;
if (!PW) { console.error('Définir LIVE_PASSWORD (mot de passe des comptes test-<rôle>@boutik-ecole.test).'); process.exit(2); }
const F = async (u, o, n = 4) => { for (let i = 0; i < n; i++) { try { return await fetch(u, o); } catch (e) { await new Promise(r => setTimeout(r, 2500)); } } throw new Error('reseau'); };
async function login(r) { const res = await F(url + '/auth/v1/token?grant_type=password', { method: 'POST', headers: { apikey: key, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `test-${r}@boutik-ecole.test`, password: PW }) }); const j = await res.json(); return { tok: j.access_token, uid: j.user.id }; }
const H = (t, x = {}) => ({ apikey: key, Authorization: 'Bearer ' + t, 'Content-Type': 'application/json', ...x });
const rpc = async (t, fn, a) => { const r = await F(url + '/rest/v1/rpc/' + fn, { method: 'POST', headers: H(t), body: JSON.stringify(a || {}) }); let b; try { b = await r.json(); } catch { b = null; } return { s: r.status, b }; };
const rest = async (t, m, path, body) => { const r = await F(url + '/rest/v1/' + path, { method: m, headers: H(t, { Prefer: 'return=representation' }), body: body ? JSON.stringify(body) : undefined }); let b; try { b = await r.json(); } catch { b = null; } return { s: r.status, b }; };
const msg = x => x.b && x.b.message ? String(x.b.message).slice(0, 90) : (x.s >= 400 ? JSON.stringify(x.b).slice(0, 90) : '');
const out = [];
const T = (n, ok, d = '') => { out.push((ok ? 'OK    ' : 'ECHEC ') + n + (d ? '  -> ' + d : '')); };
const I = (n, d) => out.push('INFO  ' + n + '  -> ' + d);
const S = {};
for (const r of ['client', 'student', 'company', 'dept', 'admin', 'support']) S[r] = await login(r);
const empty = x => Array.isArray(x.b) && x.b.length === 0;
// 1. client : carnet d'adresses
{
  const t = S.client.tok;
  let x = await rpc(t, 'save_address', { p_id: null, p_recipient: '[TEST ECRITURE] Client', p_phone: '690000001', p_city: 'Douala', p_district: 'Akwa', p_line: 'Rue test 1', p_landmark: '' });
  T('client : creer une adresse', x.s === 200, msg(x));
  const id = x.b;
  let g = await rest(t, 'GET', 'addresses?select=id,recipient,city&id=eq.' + id);
  T('client : adresse relue', Array.isArray(g.b) && g.b.length === 1 && g.b[0].city === 'Douala');
  x = await rpc(t, 'save_address', { p_id: id, p_recipient: '[TEST ECRITURE] Client', p_phone: '690000001', p_city: 'Yaoundé', p_district: 'Bastos', p_line: 'Rue test 2', p_landmark: '' });
  T('client : modifier l adresse', x.s === 200, msg(x));
  g = await rest(t, 'GET', 'addresses?select=city&id=eq.' + id);
  T('client : modification persistee', g.b && g.b[0] && g.b[0].city === 'Yaoundé');
  const g2 = await rest(S.student.tok, 'GET', 'addresses?select=id&id=eq.' + id);
  T('isolation : l etudiant ne lit pas l adresse du client', empty(g2));
  x = await rpc(S.student.tok, 'delete_address', { p_id: id });
  T('isolation : l etudiant ne supprime pas l adresse du client', x.s >= 400, msg(x));
  x = await rpc(t, 'delete_address', { p_id: id });
  T('client : supprimer l adresse', x.s === 200, msg(x));
  g = await rest(t, 'GET', 'addresses?select=id&id=eq.' + id);
  T('client : adresse bien supprimee', empty(g));
}
// 2. client : ecritures interdites
{
  const t = S.client.tok;
  let x = await rest(t, 'PATCH', 'profiles?id=eq.' + S.client.uid, { role: 'admin' });
  T('client : ne se donne pas le role admin', x.s >= 400 || empty(x) || (Array.isArray(x.b) && x.b[0].role !== 'admin'), x.s + ' ' + msg(x));
  x = await rest(t, 'PATCH', 'profiles?id=eq.' + S.student.uid, { name: 'Pirate' });
  T('client : ne modifie pas le profil d un autre', x.s >= 400 || empty(x), x.s + ' ' + msg(x));
  x = await rest(t, 'POST', 'orders', { buyer_id: S.client.uid, subtotal: 1, total: 1, paid: true });
  T('client : pas de commande payee ecrite directement', x.s >= 400, x.s + ' ' + msg(x));
  x = await rpc(t, 'admin_set_account', { p_user: S.student.uid, p_role: 'admin', p_suspended: false });
  T('client : admin_set_account refuse', x.s >= 400, msg(x));
  x = await rpc(t, 'company_decide', { p_owner: S.company.uid, p_approve: true, p_note: '' });
  T('client : company_decide refuse', x.s >= 400, msg(x));
  x = await rest(t, 'POST', 'notifications', { user_id: S.student.uid, kind: 'x', title: 'faux', body: 'faux' });
  T('client : pas de fausse notification chez un autre', x.s >= 400, x.s + ' ' + msg(x));
}
// 3. etudiant : annonce (une photo au moins est exigee : une annonce sans photo doit etre refusee avec un message clair)
{
  const t = S.student.tok;
  const x = await rest(t, 'POST', 'listings', { seller_id: S.student.uid, title: '[TEST ECRITURE] Annonce ' + Date.now(), department: 'IUT de Douala', category: 'Autre', price: 1500, stock: 3, description: 'Annonce de test creee par le controle automatique.' });
  if (x.s >= 400) T('etudiant : annonce sans photo refusee avec un message clair', /photo/i.test(msg(x)), x.s + ' ' + msg(x));
  else {
    T('etudiant : annonce creee', true, 'statut ' + (x.b[0] && x.b[0].status));
    T('etudiant : annonce non publiee sans validation', x.b[0].status !== 'approved', x.b[0].status);
    await rest(t, 'DELETE', 'listings?id=eq.' + x.b[0].id);
  }
}
// 4. etudiant : live reel (create_live -> start_live -> jeton LiveKit -> spectateur -> message -> fin)
{
  const t = S.student.tok, c = S.client.tok;
  let x = await rpc(t, 'create_live', { p_title: '[TEST ECRITURE] Live', p_description: 'test', p_cover_path: null, p_scheduled_at: null });
  if (x.s === 200) {
    const id = x.b;
    T('etudiant : creer un live', true);
    x = await rpc(t, 'start_live', { p_live: id });
    const cooldown = x.s >= 400 && /15 minutes/.test(msg(x));
    if (cooldown) { I('live : demarrage refuse par le delai de 15 minutes entre deux directs (regle du serveur) ; suite du scenario ignoree', msg(x)); await rpc(t, 'end_live', { p_live: id }); }
    else T('etudiant : demarrer le live', x.s < 300, msg(x));
    if (!cooldown) {
    let y = await F(url + '/functions/v1/live-token', { method: 'POST', headers: H(t), body: JSON.stringify({ live_id: id }) });
    let j = await y.json();
    T('live : jeton LiveKit de l hote', y.status === 200 && j.role === 'host' && !!j.token, y.status + ' ' + (j.error || ''));
    x = await rpc(c, 'join_live', { p_live: id });
    T('live : le client rejoint', x.s === 200, msg(x));
    y = await F(url + '/functions/v1/live-token', { method: 'POST', headers: H(c), body: JSON.stringify({ live_id: id }) });
    j = await y.json();
    T('live : jeton LiveKit du spectateur', y.status === 200 && j.role === 'viewer', y.status + ' ' + (j.error || ''));
    x = await rpc(c, 'post_live_message', { p_live: id, p_body: 'bonjour test' });
    T('live : message du spectateur', x.s === 200, msg(x));
    x = await rpc(c, 'end_live', { p_live: id });
    T('isolation : le client ne termine pas le live d un autre', x.s >= 400, msg(x));
    x = await rpc(t, 'end_live', { p_live: id });
    T('etudiant : terminer son live', x.s < 300, msg(x));
    }
  } else T('etudiant : creer un live', false, msg(x));
}
// 5. entreprise : besoin et offre
{
  const t = S.company.tok;
  let x = await rpc(t, 'save_mission', { p_id: null, p_title: '[TEST ECRITURE] Besoin', p_description: 'Besoin de test cree par le controle automatique des ecritures.', p_budget_min: 1000, p_budget_max: 2000, p_deadline: '2027-01-31', p_publish: false });
  if (x.s === 200) {
    T('entreprise : enregistrer un besoin (brouillon)', true);
    const id = x.b;
    const y = await rpc(S.client.tok, 'mission_cancel', { p_id: id });
    T('isolation : un tiers n annule pas le besoin', y.s >= 400, msg(y));
    const z = await rpc(t, 'mission_cancel', { p_id: id });
    T('entreprise : annuler son besoin de test', z.s === 200, msg(z));
  } else T('entreprise : enregistrer un besoin', false, msg(x));
  x = await rpc(t, 'opp_save', { p_org: '[TEST ECRITURE] Org', p_kind: 'stage', p_contract: '', p_title: '[TEST ECRITURE] Stage', p_location: 'Douala', p_mode: 'onsite', p_duration: '1 mois', p_pay_kind: 'unpaid', p_pay_amount: 0, p_pay_note: '', p_deadline: null, p_skills: ['test'], p_description: 'Offre de test creee par le controle automatique des ecritures.', p_missions: ['test'], p_profile: '', p_department: '', p_level: '', p_gains: [], p_whatsapp: '', p_in_app: true, p_about: '', p_iut_only: false });
  if (x.s === 200) {
    T('entreprise : deposer une offre', true);
    const id = x.b;
    const l = await rpc(t, 'opp_my_posted', {});
    T('entreprise : l offre apparait dans Mes offres', Array.isArray(l.b) && l.b.some(o => o.id === id));
    const pub = await rpc(S.student.tok, 'opp_detail', { p_id: id });
    T('isolation : offre non validee invisible aux etudiants', pub.s >= 400, msg(pub));
    const bad = await rpc(S.student.tok, 'opp_close', { p_id: id });
    T('isolation : un etudiant ne ferme pas l offre', bad.s >= 400, msg(bad));
    const cl = await rpc(t, 'opp_close', { p_id: id });
    T('entreprise : cloturer son offre de test', cl.s < 300, msg(cl));
  } else T('entreprise : deposer une offre', false, msg(x));
}
// 6. personnel
{
  let x = await rpc(S.dept.tok, 'platform_overview', {});
  T('departement : tableau de bord lisible', x.s === 200, msg(x));
  x = await rpc(S.admin.tok, 'admin_teams_overview', {});
  T('admin : equipes d administration lisibles', x.s === 200, msg(x));
  x = await rpc(S.dept.tok, 'finance_overview', {});
  T('departement : pas d acces a la finance', x.s >= 400, msg(x));
  x = await rpc(S.support.tok, 'finance_overview', {});
  I('support : finance_overview', x.s + ' ' + msg(x));
}
// 7. invitations de responsables de departement (creation, lecture publique, revocation ; l acceptation change un role : prouvee en SQL, pas ici)
{
  const dep = '956bb7cd-1289-40e5-b985-ec4f16200f6c';
  let x = await rpc(S.client.tok, 'dept_invite_create', { p_department: dep });
  T('invitation : un client ne cree pas de lien', x.s >= 400, msg(x));
  x = await rpc(S.admin.tok, 'dept_invite_create', { p_department: dep, p_email: null, p_title: '[TEST ECRITURE] Responsable', p_days: 1 });
  if (x.s === 200 && x.b && x.b.token) {
    T('invitation : l administrateur cree un lien', true);
    const tok = x.b.token, id = x.b.id;
    const info = async () => (await (await F(url + '/rest/v1/rpc/dept_invite_info', { method: 'POST', headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_token: tok }) })).json());
    const j = await info();
    T('invitation : un visiteur voit le departement et la validite', j.valid === true && !!j.department, JSON.stringify(j).slice(0, 80));
    const l = await rpc(S.admin.tok, 'dept_invites_list', {});
    T('invitation : la liste n expose pas le jeton', l.s === 200 && !JSON.stringify(l.b).includes(tok));
    const bad = await rpc(S.student.tok, 'dept_invite_accept', { p_token: tok });
    T('invitation : un etudiant ne peut pas accepter', bad.s >= 400, msg(bad));
    const rv = await rpc(S.client.tok, 'dept_invite_revoke', { p_id: id });
    T('invitation : un client ne revoque pas', rv.s >= 400, msg(rv));
    const ok2 = await rpc(S.admin.tok, 'dept_invite_revoke', { p_id: id });
    T('invitation : l administrateur revoque son lien de test', ok2.s < 300, msg(ok2));
    T('invitation : le lien revoque est refuse', (await info()).state === 'revoked');
  } else T('invitation : l administrateur cree un lien', false, msg(x));
}
console.log(out.join('\n'));
console.log(`\n${out.filter(l => l.startsWith('OK')).length} OK, ${out.filter(l => l.startsWith('ECHEC')).length} ECHEC`);
