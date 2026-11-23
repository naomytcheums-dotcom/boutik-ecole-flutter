// Scénario PGlite du lot L4 (20261122030000_l4_missions_campagnes_capacite.sql) : la capacité vendeur (seller_capable, K2) est imposée aux opérations COMMERCIALES
// des missions (proposer un devis, être retenu) et des campagnes publicitaires des étudiants ; le non commercial reste ouvert ; les organisations ne sont pas soumises à seller_capable.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h6_vendeur.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000070${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sup = () => db.exec('reset role');
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const PRESTATION = /prestation de service|Réservé aux étudiants|statut d.étudiant|téléphone|suspendu|pause/i;
  const CAMPAGNE = /opération commerciale|Réservé aux étudiants|statut d.étudiant|téléphone|suspendu|pause/i;

  await sup();
  // 1 client ; 2 étudiant non vérifié ; 3 étudiant ÉLIGIBLE (proposant) ; 4 étudiant éligible (campagnes) ; 5 étudiant vérifié sans téléphone vérifié ; 6 organisation (forfait + fiche approuvée) ;
  // 7 département ; 8 administrateur (compte de test) ; 9 étudiant suspendu ; 10 étudiant éligible (pause) ; 11 étudiant non vérifié avec forfait Vendeur pro ; 12 étudiant éligible (attribution)
  const roles = { 1: 'client', 2: 'student', 3: 'student', 4: 'student', 5: 'student', 6: 'company', 7: 'dept', 8: 'admin', 9: 'student', 10: 'student', 11: 'student', 12: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','l4${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte L4 ${n}','${r}','l4${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69070' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
  }
  for (const n of [3, 4, 5, 9, 10, 12]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified')`);
  await db.exec(`update profiles set phone_verified = false where id in ('${U(2)}', '${U(5)}', '${U(11)}')`);
  await db.exec(`update profiles set suspended = true where id = '${U(9)}'`);
  await db.exec(`update profiles set is_test = true where id = '${U(8)}'`);
  await db.exec(`insert into institutions (id, name, status) values ('00000000-0000-0000-0000-00000000c4a0', 'IUT L4', 'verified') on conflict (id) do nothing;
    insert into departments (id, institution_id, name, status) values ('00000000-0000-0000-0000-00000000c4a1', '00000000-0000-0000-0000-00000000c4a0', 'Génie logiciel', 'verified') on conflict (id) do nothing;
    insert into department_accounts (user_id, department_id) values ('${U(7)}', '00000000-0000-0000-0000-00000000c4a1') on conflict (user_id) do update set department_id = excluded.department_id;
    update profiles set department_id = '00000000-0000-0000-0000-00000000c4a1' where id in ('${U(1)}', '${U(3)}', '${U(12)}')`);
  await db.exec(`insert into company_profiles (owner_id, company_name, status, sector, city, phone, contact_name) values ('${U(6)}', 'Organisation L4', 'approved', 'Telecoms', 'Douala', '699', 'Mme N')`);
  for (const n of [4, 10, 11]) await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${U(n)}', 'vendeur_pro', 'active', now(), now() + interval '30 days')`);
  await db.exec(`insert into subscriptions (user_id, plan_code, status, started_at, current_period_end) values ('${U(6)}', 'entreprise', 'active', now(), now() + interval '30 days')`);
  const cap = async (n) => { await as(U(n)); const r = (await q(`select my_seller_capability() c`))[0].c; await sup(); return r; };
  for (const n of [3, 4, 10, 12]) check(`fixture : étudiant ${n} éligible`, (await cap(n)).can_sell === true);
  for (const n of [2, 5, 9, 11]) check(`fixture : étudiant ${n} non éligible`, (await cap(n)).can_sell === false);

  // ============================================================ 1. Besoin : publier est NON commercial (ouvert à tous les comptes, y compris étudiant non éligible)
  const need = (t) => `select save_mission(null, '${t}', 'Un besoin décrit avec plus de vingt caractères', 50000, 100000, '2027-01-31', true, 'mission') id`;
  await as(U(1));
  const M1 = (await q(need('Besoin L4 un')))[0].id;
  const M2 = (await q(need('Besoin L4 deux')))[0].id;
  const M3 = (await q(need('Besoin L4 trois')))[0].id;
  await as(U(2));
  await works('besoin : un étudiant NON éligible publie un besoin (non commercial)', need('Besoin etudiant non eligible'), (r) => r.length === 1);
  await works('besoin : un étudiant non éligible lit les besoins publiés', `select open_needs() r`, (r) => r.length === 1);

  // ============================================================ 2. propose_on_mission : prestation de service
  const refus = [[1, 'client', /Seuls les talents|talents/], [2, 'étudiant non vérifié', PRESTATION], [5, 'étudiant sans téléphone vérifié', PRESTATION], [9, 'étudiant suspendu (refusé dès la garde de rôle existante)', /Seuls les talents|suspendu/],
    [6, 'organisation', /Seuls les talents|talents/], [7, 'département', PRESTATION], [8, 'administrateur', PRESTATION]];
  for (const [n, nom, re] of refus) {
    await as(U(n));
    await fails(`propose_on_mission : ${nom} refusé`, `select propose_on_mission('${M1}', 80000, 10, 'Je propose')`, re);
  }
  await sup();
  check('propose_on_mission : aucune proposition enregistrée pour les refusés', (await q(`select count(*)::int n from mission_proposals`))[0].n === 0);
  await as(U(3));
  const P3 = (await q(`select propose_on_mission('${M1}', 80000, 10, 'Une équipe fiable') id`))[0].id;
  check('propose_on_mission : étudiant éligible accepté', !!P3);
  await as(U(10));
  await works('propose_on_mission : un second étudiant éligible', `select propose_on_mission('${M1}', 70000, 8, 'Seconde offre') id`, (r) => r.length === 1);
  // écriture directe : pas d'insertion hors RPC
  await as(U(2));
  await fails('mission_proposals : écriture directe refusée (pas de droit d\'insertion)', `insert into mission_proposals (mission_id, author_id, amount, delay_days) values ('${M1}', '${U(2)}', 1000, 3)`, /permission denied|row-level security|prestation/i);
  // pause : plus de nouvelle proposition, reprise : de nouveau possible
  await as(U(10));
  await q(`select seller_pause('vacances')`);
  await fails('propose_on_mission : boutique en pause refusée', `select propose_on_mission('${M2}', 50000, 5, 'En pause')`, PRESTATION);
  await q(`select seller_resume()`);
  await works('propose_on_mission : après la reprise', `select propose_on_mission('${M2}', 50000, 5, 'Après reprise') id`, (r) => r.length === 1);
  // un étudiant qui perd son éligibilité : plus de nouvelle proposition, MAIS retrait de sa proposition et lecture de ses propositions restent libres
  await sup();
  await db.exec(`update profiles set phone_verified = false where id = '${U(10)}'`);
  await as(U(10));
  await fails('propose_on_mission : éligibilité perdue : nouvelle proposition refusée', `select propose_on_mission('${M3}', 40000, 5, 'Perdue')`, PRESTATION);
  await works('non commercial : étudiant devenu non éligible lit ses propositions (my_proposals)', `select my_proposals() r`, (r) => r.length === 1);
  const mine = (await q(`select id from mission_proposals where author_id = '${U(10)}' and mission_id = '${M2}'`))[0].id;
  await works('non commercial : étudiant devenu non éligible retire sa proposition', `select withdraw_proposal('${mine}') r`, (r) => r.length === 1);
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(10)}'`);

  // ============================================================ 3. Être retenu : le prestataire doit être éligible au moment de l'engagement
  await sup();
  await db.exec(`update profiles set phone_verified = false where id = '${U(3)}'`);
  await as(U(1));
  await fails('decide_proposal : prestataire devenu non éligible : acceptation refusée', `select decide_proposal('${P3}', true)`, /plus éligible|acceptation impossible/);
  await sup();
  check('decide_proposal : le besoin reste publié', (await q(`select status from missions where id = '${M1}'`))[0].status === 'published');
  await as(U(1));
  await works('decide_proposal : refuser la proposition d\'un non éligible reste possible', `select decide_proposal('${P3}', false) r`, (r) => r[0].r === 'declined');
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(3)}'`);
  await as(U(3));
  const P3b = (await q(`select propose_on_mission('${M1}', 82000, 9, 'Nouvelle offre') id`))[0].id;
  await as(U(1));
  await works('decide_proposal : prestataire éligible : acceptation', `select decide_proposal('${P3b}', true) r`, (r) => r[0].r === 'accepted');
  // mission engagée : le prestataire qui perd son éligibilité garde l'accès à sa mission en cours (comme K2 pour les commandes engagées)
  await sup();
  await db.exec(`update profiles set phone_verified = false where id = '${U(3)}'`);
  await as(U(3));
  await works('mission engagée : le prestataire devenu non éligible livre toujours son jalon', `select submit_milestone('${M1}', 1::smallint, 'Brief rédigé et envoyé au client.') r`, (r) => r[0].r === 'submitted');
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(3)}'`);

  // département / administrateur : attribuent à un talent ÉLIGIBLE uniquement
  await as(U(7));
  await fails('assign_mission : le département refuse un talent non éligible', `select assign_mission('${M2}', null, null, '${U(2)}')`, /introuvable|indisponible|non éligible|pas éligible|prestation/i);
  await fails('assign_mission : le département refuse un talent sans téléphone vérifié', `select assign_mission('${M2}', null, null, '${U(5)}')`, /pas éligible|prestation|attribution impossible/);
  await works('assign_mission : le département attribue à un talent éligible', `select assign_mission('${M2}', null, null, '${U(12)}') r`, (r) => r[0].r === 'assigned');
  await as(U(8));
  await fails('assign_mission : l\'administrateur refuse un talent non éligible', `select assign_mission('${M3}', null, null, '${U(5)}')`, /pas éligible|prestation|attribution impossible/);
  await works('assign_mission : l\'administrateur attribue à un talent éligible', `select assign_mission('${M3}', null, null, '${U(4)}') r`, (r) => r[0].r === 'assigned');

  // ============================================================ 4. Campagnes publicitaires
  await sup();
  await db.exec(`insert into posts (id, author_id, media_path, media_kind, status) values
    ('00000000-0000-0000-0000-0000000070b2', '${U(2)}', '${U(2)}/a.jpg', 'image', 'published'),
    ('00000000-0000-0000-0000-0000000070b4', '${U(4)}', '${U(4)}/a.jpg', 'image', 'published'),
    ('00000000-0000-0000-0000-0000000070b6', '${U(6)}', '${U(6)}/a.jpg', 'image', 'published'),
    ('00000000-0000-0000-0000-0000000070b8', '${U(8)}', '${U(8)}/a.jpg', 'image', 'published'),
    ('00000000-0000-0000-0000-0000000070ba', '${U(10)}', '${U(10)}/a.jpg', 'image', 'published'),
    ('00000000-0000-0000-0000-0000000070bb', '${U(11)}', '${U(11)}/a.jpg', 'image', 'published')`);
  const P = (n) => `00000000-0000-0000-0000-0000000070b${n.toString(16)}`;
  const save = (post, t = 'Ma campagne') => `select ad_campaign_save(null, '${t}', 'Promo', '${post}', null, 5000, null, null, null) id`;
  await as(U(11));
  await fails('campagne : étudiant non éligible (même avec le forfait) refusé', save(P(11)), CAMPAGNE);
  await as(U(4));
  const C4 = (await q(save(P(4))))[0].id;
  check('campagne : étudiant éligible crée un brouillon', !!C4);
  await works('campagne : étudiant éligible soumet (paiement du budget)', `select ad_campaign_submit('${C4}') p`, (r) => r.length === 1);
  await as(U(6));
  const C6 = (await q(save(P(6), 'Campagne organisation')))[0].id;
  check('campagne : l\'organisation (non étudiante) crée sans seller_capable', !!C6);
  await works('campagne : l\'organisation soumet sans seller_capable', `select ad_campaign_submit('${C6}') p`, (r) => r.length === 1);
  await as(U(8));
  const C8 = (await q(save(P(8), 'Campagne admin')))[0].id;
  check('campagne : l\'administrateur (compte de test) crée sans seller_capable', !!C8);
  // droit au forfait inchangé : un client sans forfait reste refusé par le message du forfait
  await as(U(1));
  await fails('campagne : le forfait reste exigé (client)', save(P(4)), /Vendeur professionnel et Organisation/);
  // pause : pas de nouvelle campagne
  await as(U(10));
  await q(`select seller_pause()`);
  await fails('campagne : boutique en pause refusée', save(P(10), 'En pause'), CAMPAGNE);
  await q(`select seller_resume()`);
  await works('campagne : après la reprise', save(P(10), 'Après reprise'), (r) => r.length === 1);
  // écriture directe interdite
  await as(U(11));
  await fails('ad_campaigns : écriture directe refusée', `insert into ad_campaigns (owner_id, title, budget_xaf, post_id) values ('${U(11)}', 'Direct', 5000, '${P(11)}')`, /permission denied|row-level security|opération commerciale/i);

  // validation, reprise et diffusion
  await sup();
  await db.exec(`update ad_campaigns set status = 'pending_review' where id in ('${C4}', '${C6}')`);
  await db.exec(`update profiles set phone_verified = false where id = '${U(4)}'`);
  await as(U(8));
  await fails('ad_campaign_review : l\'administrateur ne lance pas la campagne d\'un étudiant devenu non éligible', `select ad_campaign_review('${C4}', true, null)`, /plus éligible|validation de la campagne impossible/);
  await works('ad_campaign_review : l\'administrateur valide la campagne d\'une organisation', `select ad_campaign_review('${C6}', true, null)`);
  check('ad_campaign_review : campagne d\'organisation active', (await q(`select status from ad_campaigns where id = '${C6}'`))[0].status === 'active');
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(4)}'`);
  await as(U(8));
  await works('ad_campaign_review : étudiant de nouveau éligible : validation', `select ad_campaign_review('${C4}', true, null)`);
  check('ad_campaign_review : campagne d\'étudiant active', (await q(`select status from ad_campaigns where id = '${C4}'`))[0].status === 'active');
  await as(U(1));
  const feed = async () => (await q(`select ad_feed(10) f`))[0].f.map((x) => x.id);
  check('ad_feed : campagnes de l\'étudiant éligible et de l\'organisation diffusées', (await feed()).includes(C4) && (await feed()).includes(C6));
  await sup();
  await db.exec(`update profiles set phone_verified = false where id = '${U(4)}'`);
  await as(U(1));
  const f2 = await feed();
  check('ad_feed : plus de diffusion pour un étudiant devenu non éligible', !f2.includes(C4));
  check('ad_feed : l\'organisation reste diffusée', f2.includes(C6));
  // désactiver reste libre, reprendre exige la capacité
  await as(U(4));
  await works('campagne : étudiant non éligible peut mettre en pause sa campagne', `select ad_campaign_toggle('${C4}') r`, (r) => r[0].r === 'paused');
  await fails('campagne : étudiant non éligible ne peut pas la reprendre', `select ad_campaign_toggle('${C4}')`, CAMPAGNE);
  await sup();
  await db.exec(`update profiles set phone_verified = true where id = '${U(4)}'`);
  await as(U(4));
  await works('campagne : après rétablissement la reprise est possible', `select ad_campaign_toggle('${C4}') r`, (r) => r[0].r === 'active');
  // annulation toujours possible
  await as(U(11));
  await sup();
  await db.exec(`update subscriptions set status = 'active' where user_id = '${U(11)}'`);
  await as(U(8));
  await works('campagne : l\'administrateur annule sa campagne en brouillon', `select ad_campaign_cancel('${C8}') r`);

  console.log(`\nL4 vendeur : ${ok} OK, ${ko} ECHEC`);
}
