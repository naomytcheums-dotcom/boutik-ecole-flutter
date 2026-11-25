// H12 · Atelier en direct : réglages de préparation, Action Unique, entreprises taguées, fiches enrichies, gestion d'un live programmé, statistiques d'audience
// (migration 20261127500000).
// Prouve : refus non-hôte / anonyme / compte suspendu ; 4 entreprises refusées ; entreprise non vérifiée refusée ; action sans cible refusée ; cible d'un autre vendeur refusée ;
// co-hôte limité aux champs descriptifs ; live terminé ou annulé non modifiable ; lecture publique sans champs privés ; live privé invisible ; compteurs réels (inscrits, vues totales, spectateurs) ;
// commentaires / participation / rappels désactivés respectés ; modification et annulation d'un live programmé (inscrits prévenus) ; statistiques réservées à l'hôte ; rejeu des migrations.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h12_atelier.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000096${String(n).padStart(2, '0')}`;
  const ADM = id(1), HOST = id(2), H2 = id(3), CO = id(4), V1 = id(5), V2 = id(6), V3 = id(7), SUSP = id(8), INV = id(9);
  const OA = id(21), OB = id(22), OC = id(23), OD = id(24), OP = id(25);
  const mail = (uid) => `a${uid.slice(-2)}@t.cm`;
  const claims = (o) => `set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`;
  const as = async (uid) => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false), set_config('request.jwt.claim.role', '', false), ${claims({})}; set role ${uid ? 'authenticated' : 'anon'}`); };
  const sup = async () => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', '', false), ${claims({})}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const qs = async (sql) => { await sup(); return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const rpc = async (sql) => (await q(`select ${sql} r`))[0].r;
  const arpc = async (uid, sql) => { await as(uid); return rpc(sql); };
  const J = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;
  const set = (uid, live, o) => arpc(uid, `live_set_settings('${live}', ${J(o)})`);
  const setFails = async (name, uid, live, o, re) => { await as(uid); await fails(name, `select live_set_settings('${live}', ${J(o)})`, re); };
  const DENY = /permission denied|Connexion requise/i;

  // ------------------------------------------------------------ fixtures (base de test uniquement)
  await sup();
  for (const [i, nm, role] of [[ADM, 'Ada Admin', 'admin'], [HOST, 'Hugo Hote', 'student'], [H2, 'Hana Autre', 'student'], [CO, 'Coco Cohote', 'student'], [V1, 'Vera Un', 'student'],
    [V2, 'Vic Deux', 'student'], [V3, 'Vera Trois', 'student'], [SUSP, 'Suzie Suspendue', 'student'], [INV, 'Ines Invitee', 'student'],
    [OA, 'Orga A', 'company'], [OB, 'Orga B', 'company'], [OC, 'Orga C', 'company'], [OD, 'Orga D', 'company'], [OP, 'Orga en attente', 'company']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','${mail(i)}'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','${mail(i)}')`);
  }
  await db.exec(`update profiles set suspended = true where id = '${SUSP}'`);
  for (const [o, nm, st] of [[OA, 'Entreprise Alpha', 'approved'], [OB, 'Entreprise Beta', 'approved'], [OC, 'Entreprise Gamma', 'approved'], [OD, 'Entreprise Delta', 'approved'], [OP, 'Entreprise en attente', 'pending']]) {
    await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${o}', '${nm}', '${st}')`);
  }
  const L = (n) => `00000000-0000-0000-0000-00000000a6${String(n).padStart(2, '0')}`;
  await db.exec(`insert into shops (id, owner_id, name, slug, status) values ('${L(90)}', '${HOST}', 'Boutique Hugo', 'boutique-hugo', 'active'), ('${L(91)}', '${H2}', 'Boutique Hana', 'boutique-hana', 'active')`);
  await db.exec(`insert into listings (id, seller_id, shop_id, title, department, price, status, category) values
    ('${L(1)}', '${HOST}', '${L(90)}', 'Lampe artisanale', 'Informatique', 5000, 'approved', 'Maison'),
    ('${L(2)}', '${HOST}', '${L(90)}', 'Logo sur mesure', 'Informatique', 20000, 'approved', 'Services'),
    ('${L(3)}', '${HOST}', '${L(90)}', 'Application mobile', 'Informatique', 90000, 'approved', 'Solutions numériques'),
    ('${L(4)}', '${H2}', '${L(91)}', 'Sac de Hana', 'Informatique', 7000, 'approved', 'Maison'),
    ('${L(5)}', '${HOST}', '${L(90)}', 'Brouillon', 'Informatique', 1000, 'pending', 'Maison')`);
  const ev = (await q(`insert into events (title, kind, starts_at, price, status, created_by) values ('Atelier Hugo', 'atelier', now() + interval '3 days', 0, 'published', '${HOST}') returning id`))[0].id;
  const evPaid = (await q(`insert into events (title, kind, starts_at, price, status, created_by) values ('Masterclass Hugo', 'conference', now() + interval '4 days', 5000, 'published', '${HOST}') returning id`))[0].id;
  const evOther = (await q(`insert into events (title, kind, starts_at, price, status, created_by) values ('Atelier Hana', 'atelier', now() + interval '3 days', 0, 'published', '${H2}') returning id`))[0].id;
  const opp = (await q(`insert into opportunities (poster_id, org_name, kind, title, description, status) values ('${HOST}', 'Hugo SARL', 'stage', 'Stage de soudure', 'Stage', 'published') returning id`))[0].id;
  const oppOther = (await q(`insert into opportunities (poster_id, org_name, kind, title, description, status) values ('${H2}', 'Hana SARL', 'stage', 'Stage de Hana', 'Stage', 'published') returning id`))[0].id;
  const mis = (await q(`insert into missions (number, client_id, kind, description, total, title, status) values ('M-H12-A1', '${HOST}', 'web', 'Site web', 100000, 'Site vitrine', 'published') returning id`))[0].id;
  const misOther = (await q(`insert into missions (number, client_id, kind, description, total, title, status) values ('M-H12-A2', '${H2}', 'web', 'Logo', 50000, 'Logo Hana', 'published') returning id`))[0].id;
  const prj = (await q(`insert into projects (owner_id, title, summary, department, status, kind, visibility) values ('${HOST}', 'Projet solaire', 'Un kit', 'Informatique', 'approved', 'innovation', 'public') returning id`))[0].id;
  const prjDraft = (await q(`insert into projects (owner_id, title, summary, department, status, kind, visibility) values ('${HOST}', 'Projet brouillon', 'x', 'Informatique', 'draft', 'innovation', 'public') returning id`))[0].id;
  const prjOther = (await q(`insert into projects (owner_id, title, summary, department, status, kind, visibility) values ('${H2}', 'Projet de Hana', 'x', 'Informatique', 'approved', 'innovation', 'public') returning id`))[0].id;
  const mkLive = async (host, title, o = {}) => (await q(`insert into lives (host_id, title, status, scheduled_at, started_at, ended_at, visibilite, live_type, viewer_count, peak_viewers) values
    ('${host}', '${title}', '${o.status ?? 'scheduled'}', ${o.status === 'live' || o.status === 'ended' ? 'null' : `now() + interval '${o.hours ?? 48} hours'`},
     ${o.status === 'live' ? 'now()' : o.status === 'ended' ? `now() - interval '2 hours'` : 'null'}, ${o.status === 'ended' ? `now() - interval '1 hour'` : 'null'},
     '${o.vis ?? 'public'}', '${o.vis === 'prive' ? 'prive' : 'public'}', ${o.viewers ?? 0}, ${o.peak ?? 0}) returning id`))[0].id;
  const LA = await mkLive(HOST, 'Atelier de soudure', { hours: 30 });
  const LB = await mkLive(HOST, 'Atelier prive', { vis: 'prive', hours: 40 });
  const LC = await mkLive(HOST, 'Atelier termine', { status: 'ended', peak: 3 });
  const LD = await mkLive(HOST, 'Atelier a annuler', { hours: 60 });
  const LE = await mkLive(H2, 'Atelier de Hana', { hours: 20 });
  const LL = await mkLive(HOST, 'Direct en cours', { status: 'live', viewers: 2, peak: 5 });
  const LF = await mkLive(HOST, 'Atelier a reprogrammer', { hours: 70 });
  await db.exec(`insert into live_invites (live_id, user_id) values ('${LB}', '${INV}');
    insert into live_cohosts (live_id, user_id, status) values ('${LA}', '${CO}', 'approved'), ('${LA}', '${V3}', 'requested')`);

  // ============================================================ A. Écriture : droits
  await as(null);
  await fails('A1 anonyme : live_set_settings refusé', `select live_set_settings('${LA}', ${J({ category: 'x' })})`, DENY);
  await setFails('A2 un autre compte (non hôte) refusé', V1, LA, { category: 'Soudure' }, /non autorisée/);
  await setFails('A3 compte suspendu refusé', SUSP, LA, { category: 'Soudure' }, /suspendu/);
  await setFails('A3b live inexistant refusé', HOST, L(77), { category: 'Soudure' }, /introuvable/);
  await setFails('A4 live terminé non modifiable', HOST, LC, { category: 'Soudure' }, /terminé/);
  await setFails('A5 réglages non objet refusés', HOST, LA, [1, 2], /invalides/);

  // ============================================================ B. Descriptif : catégorie, filière, secteur, hashtags
  let s = await set(HOST, LA, { category: 'Atelier technique', filiere: 'Génie civil', sector: 'BTP', hashtags: ['#Soudure', 'soudure', ' Bois ', '#bois'] });
  check('B1 réglages enregistrés (catégorie, filière, secteur)', s.category === 'Atelier technique' && s.filiere === 'Génie civil' && s.sector === 'BTP', JSON.stringify(s));
  check('B2 hashtags normalisés, sans doublon', JSON.stringify(s.hashtags) === JSON.stringify(['bois', 'soudure']), JSON.stringify(s.hashtags));
  await setFails('B3 hashtag avec espace ou lien refusé', HOST, LA, { hashtags: ['bonjour tout le monde'] }, /Hashtag invalide/);
  await setFails('B3b hashtag trop court refusé', HOST, LA, { hashtags: ['a'] }, /Hashtag invalide/);
  await setFails('B4 plus de 8 hashtags refusés', HOST, LA, { hashtags: ['aa', 'bb', 'cc', 'dd', 'ee', 'ff', 'gg', 'hh', 'ii'] }, /8 hashtags/);
  await setFails('B4b hashtags de mauvais type refusés', HOST, LA, { hashtags: 'soudure' }, /invalides/);
  await setFails('B5 catégorie trop longue refusée', HOST, LA, { category: 'x'.repeat(61) }, /60 caractères/);
  s = await set(HOST, LA, { duration_min: 90, comments_mode: 'all', participation_mode: 'on_request', frequency: 'weekly', video_quality: '720p', clips_allowed: false, audio_only: true, reminders_enabled: true });
  check('B6 durée, fréquence, qualité, clips, audio seul', s.duration_min === 90 && s.frequency === 'weekly' && s.clips_allowed === false && s.audio_only === true && s.video_quality === '720p', JSON.stringify(s));
  check('B7 mise à jour partielle : le reste est conservé', s.category === 'Atelier technique' && s.hashtags.length === 2, JSON.stringify(s));
  await setFails('B8 durée hors bornes refusée', HOST, LA, { duration_min: 3 }, /Durée/);
  await setFails('B8b durée de mauvais type refusée', HOST, LA, { duration_min: '90' }, /Durée/);
  await setFails('B9 fréquence inconnue refusée', HOST, LA, { frequency: 'daily' }, /Fréquence/);
  await setFails('B10 qualité inconnue refusée', HOST, LA, { video_quality: '4k' }, /Qualité/);
  await setFails('B11 booléen de mauvais type refusé', HOST, LA, { clips_allowed: 'oui' }, /invalide/);
  await setFails('B12 mode de commentaires inconnu refusé', HOST, LA, { comments_mode: 'amis' }, /commentaires/);
  s = await set(HOST, LA, { notify_message: 'Rejoignez-nous sur https://exemple.cm/x <b>vite</b> !' });
  check('B13 message de notification nettoyé (sans lien ni balise)', s.main_action_raw === null && !(await qs(`select notify_message from live_settings where live_id = '${LA}'`))[0].notify_message.match(/http|<|>/), JSON.stringify(s));
  s = await set(HOST, LA, { notify_message: 'm'.repeat(300) });
  check('B13b message limité à 200 caractères', (await qs(`select char_length(notify_message) n from live_settings where live_id = '${LA}'`))[0].n === 200);
  await set(HOST, LA, { notify_message: null });

  // ============================================================ C. Entreprises taguées (3 au plus, vérifiées)
  s = await set(HOST, LA, { tagged_orgs: [OA, OB, OC] });
  check('C1 trois entreprises vérifiées acceptées', s.tagged_orgs.length === 3 && s.tagged_orgs.map((x) => x.name).sort().join() === 'Entreprise Alpha,Entreprise Beta,Entreprise Gamma', JSON.stringify(s.tagged_orgs));
  await setFails('C2 quatre entreprises refusées', HOST, LA, { tagged_orgs: [OA, OB, OC, OD] }, /Trois entreprises/);
  check('C2b après refus : toujours trois entreprises', (await qs(`select cardinality(tagged_orgs) n from live_settings where live_id = '${LA}'`))[0].n === 3);
  await setFails('C3 entreprise non vérifiée refusée', HOST, LA, { tagged_orgs: [OP] }, /non vérifiée/);
  await setFails('C4 compte qui n\'est pas une entreprise refusé', HOST, LA, { tagged_orgs: [V1] }, /non vérifiée/);
  await setFails('C5 identifiant invalide refusé', HOST, LA, { tagged_orgs: ['pas-un-uuid'] }, /invalide/);
  s = await set(HOST, LA, { tagged_orgs: [OA, OA] });
  check('C6 doublons fusionnés', s.tagged_orgs.length === 1);
  await sup(); await db.exec(`update profiles set suspended = true where id = '${OB}'`);
  await setFails('C7 entreprise suspendue refusée', HOST, LA, { tagged_orgs: [OB] }, /non vérifiée/);
  await sup(); await db.exec(`update profiles set suspended = false where id = '${OB}'`);
  s = await set(HOST, LA, { tagged_orgs: [] });
  check('C8 on peut retirer toutes les entreprises', s.tagged_orgs.length === 0);
  s = await set(HOST, LA, { tagged_orgs: [OA, OB] });

  // ============================================================ D. Action Unique
  await setFails('D1 action sans cible refusée (acheter)', HOST, LA, { main_action: 'acheter' }, /exige une cible/);
  await setFails('D1b action sans cible refusée (postuler)', HOST, LA, { main_action: 'postuler' }, /exige une cible/);
  await setFails('D1c action sans cible refusée (s\'inscrire)', HOST, LA, { main_action: 's_inscrire', action_target_kind: 'event' }, /exige une cible/);
  await setFails('D2 action inconnue refusée', HOST, LA, { main_action: 'pirater' }, /(inconnue|violates|check)/i);
  await setFails('D3 cible d\'un autre vendeur refusée (annonce)', HOST, LA, { main_action: 'acheter', action_target_kind: 'listing', action_target_id: L(4) }, /n'appartient pas/);
  await setFails('D3b cible d\'un autre vendeur refusée (événement)', HOST, LA, { main_action: 's_inscrire', action_target_kind: 'event', action_target_id: evOther }, /n'appartient pas/);
  await setFails('D3c cible d\'un autre vendeur refusée (opportunité)', HOST, LA, { main_action: 'postuler', action_target_kind: 'opportunity', action_target_id: oppOther }, /n'appartient pas/);
  await setFails('D3d cible d\'un autre vendeur refusée (mission)', HOST, LA, { main_action: 'postuler', action_target_kind: 'mission', action_target_id: misOther }, /n'appartient pas/);
  await setFails('D3e cible d\'un autre vendeur refusée (projet)', HOST, LA, { main_action: 'voter', action_target_kind: 'project', action_target_id: prjOther }, /n'appartient pas/);
  await setFails('D4 annonce non approuvée refusée', HOST, LA, { main_action: 'acheter', action_target_kind: 'listing', action_target_id: L(5) }, /introuvable/);
  await setFails('D4b projet non publié refusé', HOST, LA, { main_action: 'soutenir', action_target_kind: 'project', action_target_id: prjDraft }, /non publié/);
  await setFails('D5 mauvais genre de cible (acheter un événement)', HOST, LA, { main_action: 'acheter', action_target_kind: 'event', action_target_id: ev }, /annonce/);
  await setFails('D5b mauvais genre de cible (s\'inscrire à une annonce)', HOST, LA, { main_action: 's_inscrire', action_target_kind: 'listing', action_target_id: L(1) }, /événement/);
  await setFails('D6 réserver un produit refusé', HOST, LA, { main_action: 'reserver', action_target_kind: 'listing', action_target_id: L(1) }, /ne correspond pas/);
  await setFails('D6b demander un devis pour un produit refusé', HOST, LA, { main_action: 'demander_devis', action_target_kind: 'listing', action_target_id: L(1) }, /ne correspond pas/);
  await setFails('D6c télécharger un produit physique refusé', HOST, LA, { main_action: 'telecharger', action_target_kind: 'listing', action_target_id: L(1) }, /ne correspond pas/);
  await setFails('D7 parrainer avec une cible refusé', HOST, LA, { main_action: 'parrainer', action_target_kind: 'listing', action_target_id: L(1) }, /ne prend pas de cible/);
  await setFails('D7b offrir avec une cible refusé', HOST, LA, { main_action: 'offrir', action_target_kind: 'event', action_target_id: ev }, /ne prend pas de cible/);
  const okActions = [
    ['acheter', 'listing', L(1)], ['reserver', 'listing', L(2)], ['demander_devis', 'listing', L(2)], ['demander_devis', 'listing', L(3)], ['telecharger', 'listing', L(3)], ['noter', 'listing', L(1)],
    ['s_inscrire', 'event', ev], ['postuler', 'opportunity', opp], ['postuler', 'mission', mis], ['voter', 'project', prj], ['soutenir', 'project', prj], ['encourager', 'project', prj],
    ['parrainer', null, null], ['offrir', null, null],
  ];
  for (const [a, k, t] of okActions) {
    s = await set(HOST, LA, { main_action: a, action_target_kind: k, action_target_id: t });
    check(`D9 action « ${a} » valide${k ? ` sur ${k}` : ' sans cible'}`, s.main_action === a && s.action_available === true && (k === null || s.action_target_id === t), JSON.stringify(s));
  }
  s = await set(HOST, LA, { main_action: 'acheter', action_target_kind: 'listing', action_target_id: L(1) });
  check('D10 une seule action à la fois : changer remplace l\'ancienne', s.main_action === 'acheter' && s.action_target_kind === 'listing' && s.action_target_title === 'Lampe artisanale', JSON.stringify(s));
  check('D10b une seule action en base (un enregistrement par live)', (await qs(`select count(*)::int n from live_settings where live_id = '${LA}'`))[0].n === 1);
  s = await set(HOST, LA, { main_action: null });
  check('D11 retirer l\'action efface aussi la cible', s.main_action === null && s.action_target_id === null && s.action_available === false, JSON.stringify(s));
  s = await set(HOST, LA, { main_action: 'acheter', action_target_kind: 'listing', action_target_id: L(1) });

  // ============================================================ E. Co-hôte et administrateur
  s = await set(CO, LA, { hashtags: ['atelier', 'soudure'], category: 'Atelier technique' });
  check('E1 le co-hôte approuvé modifie les champs descriptifs', s.hashtags.includes('atelier'), JSON.stringify(s));
  await setFails('E2 le co-hôte ne change pas l\'Action Unique', CO, LA, { main_action: 'offrir', action_target_kind: null, action_target_id: null }, /Réservé à l'hôte/);
  await setFails('E2b ni les entreprises taguées', CO, LA, { tagged_orgs: [OC] }, /Réservé à l'hôte/);
  await setFails('E2c ni l\'enregistrement du replay', CO, LA, { record_replay: true }, /Réservé à l'hôte/);
  await setFails('E3 une demande de co-hôte non approuvée n\'a aucun droit', V3, LA, { category: 'x' }, /non autorisée/);
  s = await set(ADM, LA, { sector: 'Industrie' });
  check('E4 l\'administration peut corriger un live', s.sector === 'Industrie');
  await setFails('E5 le co-hôte d\'un autre live n\'a aucun droit ici', CO, LE, { category: 'x' }, /non autorisée/);

  // ============================================================ F. Lecture publique
  await as(null);
  s = await rpc(`live_settings_get('${LA}')`);
  check('F1 anonyme : fiche publique d\'un live public', s.title === 'Atelier de soudure' && s.hashtags.length === 2 && s.main_action === 'acheter' && s.action_available === true && s.action_target_title === 'Lampe artisanale', JSON.stringify(s));
  check('F2 anonyme : aucun réglage privé (message de notification, qualité, cibles brutes)', !('notify_message' in s) && !('video_quality' in s) && !('main_action_raw' in s) && s.can_edit === false && s.mine === false, JSON.stringify(Object.keys(s)));
  check('F3 entreprises taguées : nom public, sans coordonnées', s.tagged_orgs.length === 2 && Object.keys(s.tagged_orgs[0]).sort().join() === 'logo_path,name,owner_id', JSON.stringify(s.tagged_orgs));
  check('F4 anonyme : live privé introuvable', (await rpc(`live_settings_get('${LB}')`)) === null);
  await as(V1);
  check('F5 membre non invité : live privé introuvable', (await rpc(`live_settings_get('${LB}')`)) === null);
  await as(INV);
  check('F6 membre invité : voit le live privé', (await rpc(`live_settings_get('${LB}')`)).title === 'Atelier prive');
  await as(HOST);
  s = await rpc(`live_settings_get('${LA}')`);
  check('F7 hôte : réglages privés visibles', s.can_edit === true && s.mine === true && s.video_quality === '720p' && s.main_action_raw === 'acheter', JSON.stringify(s));
  await as(CO);
  check('F7b co-hôte : peut éditer', (await rpc(`live_settings_get('${LA}')`)).can_edit === true);
  await sup(); await db.exec(`update listings set status = 'removed' where id = '${L(1)}'`);
  await as(null);
  s = await rpc(`live_settings_get('${LA}')`);
  check('F8 cible retirée de la vente : l\'action n\'est plus proposée (jamais un bouton mort)', s.main_action === null && s.action_available === false, JSON.stringify(s));
  await sup(); await db.exec(`update listings set status = 'approved' where id = '${L(1)}'`);
  check('F9 live annulé ou inexistant : rien', (await rpc(`live_settings_get('${L(77)}')`)) === null);
  const [kind, tid] = ['listing', L(1)];
  void kind; void tid;

  // ============================================================ G. Fiches de l'Atelier : compteurs réels et prix existant
  await sup();
  await db.exec(`insert into live_viewers (live_id, user_id, joined_at, last_seen_at, left_at) values
    ('${LL}', '${V1}', now(), now(), null), ('${LL}', '${V2}', now() - interval '1 hour', now() - interval '30 minutes', now() - interval '30 minutes'), ('${LL}', '${V3}', now() - interval '2 hours', now() - interval '1 hour', now() - interval '1 hour')`);
  await db.exec(`insert into live_reminders (live_id, user_id) values ('${LA}', '${V1}'), ('${LA}', '${V2}')`);
  await sup(); await db.exec(`update lives set event_id = '${evPaid}' where id = '${LA}'`);
  await db.exec(`insert into event_registrations (event_id, user_id, status) values ('${evPaid}', '${V2}', 'confirmed'), ('${evPaid}', '${V3}', 'confirmed'), ('${evPaid}', '${INV}', 'pending_payment')`);
  await as(null);
  let ex = await rpc(`lives_atelier_extras(array['${LA}', '${LL}', '${LB}', '${LC}']::uuid[])`);
  const byId = (id) => ex.find((x) => x.id === id);
  check('G1 inscrits réels : rappels et inscriptions confirmées, personnes distinctes (V1, V2, V3 ; la place en attente de paiement ne compte pas)', byId(LA)?.registered === 3, JSON.stringify(byId(LA)));
  check('G2 prix = prix de l\'événement lié (aucune règle financière nouvelle)', byId(LA)?.price === 5000 && byId(LA)?.free === false, JSON.stringify(byId(LA)));
  check('G3 direct : spectateurs en direct (viewer_count) distincts des vues totales (personnes ayant rejoint)', byId(LL)?.viewers === 2 && byId(LL)?.total_views === 3, JSON.stringify(byId(LL)));
  check('G4 live programmé : 0 spectateur en direct', byId(LA)?.viewers === 0);
  check('G5 live privé absent pour l\'anonyme', byId(LB) === undefined);
  check('G6 live terminé : vues totales réelles, 0 en direct', byId(LC)?.viewers === 0 && byId(LC)?.total_views === 0);
  check('G7 type de profil de l\'hôte exposé (filtre), sans e-mail', byId(LA)?.host_role === 'student' && !/@t\.cm/.test(JSON.stringify(ex)));
  check('G8 sans réglage : valeurs par défaut honnêtes (pas de catégorie inventée)', byId(LL)?.category === null && byId(LL)?.hashtags.length === 0 && byId(LL)?.action_available === false && byId(LL)?.free === true, JSON.stringify(byId(LL)));
  await as(INV);
  ex = await rpc(`lives_atelier_extras(array['${LB}']::uuid[])`);
  check('G9 invité : voit le live privé', ex.length === 1);
  await as(V1);
  ex = await rpc(`lives_atelier_extras(null)`);
  check('G10 liste nulle : tableau vide', Array.isArray(ex) && ex.length === 0);
  await sup(); await db.exec(`update lives set status = 'cancelled' where id = '${LE}'`);
  await as(null);
  ex = await rpc(`lives_atelier_extras(array['${LE}']::uuid[])`);
  check('G11 live annulé absent', ex.length === 0);
  await sup(); await db.exec(`update lives set status = 'scheduled' where id = '${LE}'`);
  await sup(); await db.exec(`update lives set event_id = null where id = '${LA}'`);

  // ============================================================ H. Garde-fous issus des réglages
  await sup(); await db.exec(`update lives set status = 'live', started_at = now() where id = '${LE}'`);
  await sup(); await db.exec(`update lives set status = 'ended', ended_at = now(), started_at = now() - interval '1 hour' where id = '${LL}'`); // un seul direct par hôte
  await sup(); await db.exec(`update lives set status = 'live', started_at = now() where id = '${LA}'`);
  await as(V1);
  check('H1 commentaires ouverts : message accepté', (await rpc(`post_live_message('${LA}', 'Bonjour')`)) > 0);
  await set(HOST, LA, { comments_mode: 'off' });
  await as(V1);
  await fails('H2 commentaires désactivés : message refusé', `select post_live_message('${LA}', 'Salut')`, /commentaires sont désactivés/);
  await as(HOST);
  check('H3 l\'hôte peut toujours écrire', (await rpc(`post_live_message('${LA}', 'Bienvenue')`)) > 0);
  await as(V1);
  await rpc(`react_live('${LA}', 'heart')`);
  check('H4 les réactions restent ouvertes', true);
  await sup(); await db.exec(`update live_settings set comments_mode = 'all' where live_id = '${LA}'`);
  await sup(); await db.exec(`delete from live_cohosts where live_id = '${LA}' and user_id = '${V2}'`);
  await set(HOST, LA, { participation_mode: 'off' });
  await as(V2);
  await fails('H5 participation désactivée : demande de co-diffusion refusée', `select request_cohost('${LA}')`, /participation en direct est désactivée/);
  await set(HOST, LA, { participation_mode: 'on_request' });
  await as(V2);
  check('H6 participation sur demande : demande acceptée', (await rpc(`request_cohost('${LA}')`)) === 'demandée');
  await sup(); await db.exec(`update lives set status = 'scheduled', started_at = null where id = '${LA}'`);
  await set(HOST, LA, { reminders_enabled: false });
  await as(V3);
  await fails('H7 rappels désactivés : rappel refusé', `select live_remind_set('${LA}', true)`, /rappels sont désactivés/);
  await set(HOST, LA, { reminders_enabled: true });
  await as(V3);
  check('H8 rappels activés : rappel enregistré', (await rpc(`live_remind_set('${LA}', true)`)) === true);
  await rpc(`live_remind_set('${LA}', true)`);
  check('H9 rappel unique : pas de doublon', (await qs(`select count(*)::int n from live_reminders where live_id = '${LA}' and user_id = '${V3}'`))[0].n === 1);
  // message de notification dans le rappel
  await set(HOST, LF, { notify_message: 'Apportez votre casque.' });
  await sup(); await db.exec(`insert into live_reminders (live_id, user_id) values ('${LF}', '${V1}'); update lives set scheduled_at = now() + interval '20 minutes' where id = '${LF}'`);
  await sup(); await db.exec(`select send_live_reminders()`);
  const nt = await qs(`select body from notifications where user_id = '${V1}' and kind = 'live_reminder' and data->>'live' = '${LF}'`);
  check('H10 le rappel envoyé reprend le message de l\'hôte', nt.length === 1 && /Apportez votre casque/.test(nt[0].body), JSON.stringify(nt));
  await sup();
  await db.exec(`update lives set scheduled_at = now() + interval '70 hours' where id = '${LF}'`);
  await db.exec(`delete from live_reminders where live_id = '${LF}'; insert into live_reminders (live_id, user_id) values ('${LF}', '${V2}'), ('${LF}', '${V3}')`);

  // ============================================================ I. Modifier / annuler un live programmé
  const inDays = (d) => new Date(Date.now() + d * 86400000).toISOString();
  await as(null);
  await fails('I1 anonyme : modification refusée', `select live_update('${LF}', 'Nouveau titre', null, '${inDays(3)}')`, DENY);
  await as(V1);
  await fails('I2 non-hôte : modification refusée', `select live_update('${LF}', 'Nouveau titre', null, '${inDays(3)}')`, /non autorisée/);
  await as(HOST);
  await fails('I3 titre trop court refusé', `select live_update('${LF}', 'ab', null, null)`, /titre/);
  await fails('I3b titre réduit à rien par le nettoyage des liens refusé', `select live_update('${LF}', 'https://x.cm/abc', null, null)`, /titre/);
  await fails('I4 date passée refusée', `select live_update('${LF}', 'Nouveau titre', null, '${new Date(Date.now() - 3600000).toISOString()}')`, /à venir/);
  await fails('I5 date au-delà de 90 jours refusée', `select live_update('${LF}', 'Nouveau titre', null, '${inDays(120)}')`, /90 jours/);
  await fails('I6 live non programmé : non modifiable ici', `select live_update('${LL}', 'Nouveau titre', null, null)`, /programmé/);
  await fails('I6b live terminé : non modifiable', `select live_update('${LC}', 'Nouveau titre', null, null)`, /programmé/);
  await sup(); await db.exec(`delete from notifications where kind = 'live'`); await db.exec(`update live_reminders set notified = true where live_id = '${LF}'`);
  await as(HOST);
  check('I7 l\'hôte modifie titre, description et date', (await rpc(`live_update('${LF}', 'Atelier reprogrammé', 'Nouvelle description', '${inDays(4)}')`)) === 'ok');
  const lf = (await qs(`select title, description, scheduled_at > now() + interval '3 days' later from lives where id = '${LF}'`))[0];
  check('I8 modification persistée', lf.title === 'Atelier reprogrammé' && lf.description === 'Nouvelle description' && lf.later === true, JSON.stringify(lf));
  const nn = await qs(`select user_id from notifications where kind = 'live' and title = 'Live reprogrammé'`);
  check('I9 les inscrits (rappels) sont prévenus du nouvel horaire', nn.length === 2 && nn.some((x) => x.user_id === V2) && nn.some((x) => x.user_id === V3), JSON.stringify(nn));
  check('I10 les rappels sont réarmés pour le nouvel horaire', (await qs(`select count(*)::int n from live_reminders where live_id = '${LF}' and not notified`))[0].n === 2);
  await sup(); await db.exec(`delete from notifications where kind = 'live'`);
  await as(HOST);
  await rpc(`live_update('${LF}', 'Atelier reprogrammé bis', null, null)`);
  check('I11 titre seul : pas de notification d\'horaire, description conservée', (await qs(`select count(*)::int n from notifications where kind = 'live'`))[0].n === 0 && (await qs(`select description from lives where id = '${LF}'`))[0].description === 'Nouvelle description');

  await sup(); await db.exec(`insert into live_reminders (live_id, user_id) values ('${LD}', '${V1}'), ('${LD}', '${V2}')`);
  await as(null);
  await fails('I12 anonyme : annulation refusée', `select live_cancel('${LD}', 'x')`, DENY);
  await as(V1);
  await fails('I13 non-hôte : annulation refusée', `select live_cancel('${LD}', 'x')`, /non autorisée/);
  await as(HOST);
  await fails('I14 live terminé : annulation refusée', `select live_cancel('${LC}', 'x')`, /programmé/);
  await fails('I14b direct en cours : annulation refusée (il se termine depuis la régie)', `select live_cancel('${LE}', 'x')`, /non autorisée|programmé/);
  check('I15 l\'hôte annule un live programmé', (await rpc(`live_cancel('${LD}', 'Indisponibilité de l''intervenant https://x.cm')`)) === 'cancelled');
  check('I16 statut annulé en base', (await qs(`select status from lives where id = '${LD}'`))[0].status === 'cancelled');
  const nc = await qs(`select user_id, body from notifications where kind = 'live' and title = 'Live annulé'`);
  check('I17 les inscrits sont prévenus (motif sans lien)', nc.length === 2 && nc.every((x) => /Indisponibilité/.test(x.body) && !/http/.test(x.body)), JSON.stringify(nc));
  await as(V1);
  check('I18 le live annulé disparaît de l\'agenda', !(await rpc(`lives_agenda('all', 100)`)).some((x) => x.id === LD));
  await as(HOST);
  await fails('I19 un live annulé ne peut plus être annulé ni réglé', `select live_cancel('${LD}', null)`, /introuvable/);
  await setFails('I19b réglages d\'un live annulé refusés', HOST, LD, { category: 'x' }, /introuvable/);

  // ============================================================ J. Statistiques d'audience de l'hôte
  await sup();
  await db.exec(`insert into live_messages (live_id, user_id, author, kind, body) values ('${LC}', '${V1}', 'Vera', 'chat', 'Super'), ('${LC}', '${V2}', 'Vic', 'chat', 'Merci'), ('${LC}', '${V1}', 'Vera', 'reaction', 'heart'), ('${LC}', null, '', 'system', 'Fin')`);
  await db.exec(`insert into live_viewers (live_id, user_id, left_at) values ('${LC}', '${V1}', now()), ('${LC}', '${V2}', now())`);
  await as(HOST);
  let st = await rpc(`live_host_stats('${LC}')`);
  check('J1 hôte : audience réelle (pic, vues totales, messages, réactions)', st.peak_viewers === 3 && st.total_views === 2 && st.chat_messages === 2 && st.reactions === 1 && st.viewers_now === 0, JSON.stringify(st));
  check('J2 aucune donnée commerciale ni financière dans les statistiques', !/revenue|price|amount|credits|sales|montant/i.test(JSON.stringify(st)), JSON.stringify(Object.keys(st)));
  await as(V1);
  await fails('J3 un autre compte ne lit pas les statistiques', `select live_host_stats('${LC}')`, /non autorisée/);
  await as(null);
  await fails('J4 anonyme refusé', `select live_host_stats('${LC}')`, DENY);
  await as(ADM);
  check('J5 l\'administration lit les statistiques', (await rpc(`live_host_stats('${LC}')`)).total_views === 2);
  await as(HOST);
  await fails('J6 live inconnu : refus', `select live_host_stats('${L(77)}')`, /introuvable/);

  // ============================================================ J2. Aides au formulaire : recherche d'entreprises, cibles de l'Action Unique
  await as(null);
  await fails('J7 anonyme : recherche d\'entreprises refusée', `select live_orgs_search('', 10)`, DENY);
  await fails('J7b anonyme : cibles refusées', `select live_action_targets('listing')`, DENY);
  await as(HOST);
  let orgs = await rpc(`live_orgs_search('', 20)`);
  check('J8 recherche d\'entreprises : seulement les vérifiées (4), noms publics', orgs.length === 4 && !orgs.some((o) => o.name === 'Entreprise en attente') && Object.keys(orgs[0]).sort().join() === 'logo_path,name,owner_id,sector', JSON.stringify(orgs));
  orgs = await rpc(`live_orgs_search('alp', 20)`);
  check('J9 recherche par nom (insensible à la casse)', orgs.length === 1 && orgs[0].name === 'Entreprise Alpha');
  check('J9b caractères spéciaux traités comme du texte', (await rpc(`live_orgs_search('%', 20)`)).length === 0);
  let tg = await rpc(`live_action_targets('listing')`);
  check('J10 cibles « annonce » : uniquement celles de l\'hôte, approuvées', tg.length === 3 && !tg.some((x) => x.id === L(4) || x.id === L(5)), JSON.stringify(tg));
  check('J11 cibles « événement » : les siens seulement', (await rpc(`live_action_targets('event')`)).every((x) => [ev, evPaid].includes(x.id)));
  check('J12 cibles opportunité / mission / projet : les siennes, publiées', (await rpc(`live_action_targets('opportunity')`)).length === 1 && (await rpc(`live_action_targets('mission')`)).length === 1 && (await rpc(`live_action_targets('project')`)).length === 1);
  await as(H2);
  tg = await rpc(`live_action_targets('project')`);
  check('J13 isolation : un autre vendeur ne voit que ses propres projets', tg.length === 1 && tg[0].id === prjOther);
  await fails('J14 type de cible inconnu refusé', `select live_action_targets('boutique')`, /inconnu/);

  // ============================================================ K. RLS et rejeu des migrations
  await as(V1);
  check('K1 table des réglages : aucune lecture directe par un tiers (RLS)', (await q(`select * from live_settings`)).length === 0);
  await as(HOST);
  check('K2 l\'hôte lit ses propres réglages (RLS)', (await q(`select live_id from live_settings`)).some((x) => x.live_id === LA));
  await as(CO);
  check('K2b le co-hôte lit les réglages du live qu\'il co-anime, pas les autres', (await q(`select live_id from live_settings`)).every((x) => x.live_id === LA));
  await as(null);
  await fails('K3 anonyme : aucune lecture de la table', `select * from live_settings`, DENY);
  await as(HOST);
  await fails('K4 écriture directe refusée (passer par live_set_settings)', `insert into live_settings (live_id, category) values ('${LE}', 'x')`, DENY);
  await fails('K4b mise à jour directe refusée', `update live_settings set main_action = 'offrir' where live_id = '${LA}'`, DENY);
  await fails('K5 fonctions internes inaccessibles', `select _live_action_check('${HOST}', 'offrir', null, null)`, DENY);
  await fails('K5b droits internes inaccessibles', `select _live_can_edit('${LA}', '${HOST}', false)`, DENY);
  await sup();
  const before = (await q(`select (select count(*)::int from live_settings) a, (select count(*)::int from live_reminders) b`))[0];
  let err = '';
  try { await db.exec(fs.readFileSync(path.join(repo, 'migrations', '20261127500000_h12_atelier_reglages_live.sql'), 'utf8')); } catch (e) { err = e.message; }
  check('K6 rejeu de la migration 20261127500000 : sans erreur', err === '', err);
  const after = (await q(`select (select count(*)::int from live_settings) a, (select count(*)::int from live_reminders) b`))[0];
  check('K7 après rejeu : données conservées', before.a === after.a && before.b === after.b, JSON.stringify([before, after]));
  console.log(`\n${ok}/${ok + ko}`);
}
