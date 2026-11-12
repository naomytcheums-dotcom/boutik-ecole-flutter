let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', C = '00000000-0000-0000-0000-00000000000c', D = '00000000-0000-0000-0000-00000000000d', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role, dept, skills] of [
    [A, 'Awa Etudiante', 'student', 'Génie informatique', 'Flutter, Python'],
    [B, 'Boris Etudiant', 'student', 'Génie civil', 'Figma, design graphique'],
    [C, 'Cora Etudiante', 'student', 'Gestion', 'Marketing, vente'],
    [D, 'Dan SansCompetence', 'student', 'Gestion', ''],
    [M, 'Mod Admin', 'admin', 'Direction', ''],
  ]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,department,skills) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm','${dept}','${skills}')`);
  }
  // --- catégories : les 4 d'origine, lisibles par tous
  await as(null, 'anon');
  let cats = (await q(`select mate_categories_list() r`))[0].r;
  check('categories : les 4 d origine existent', cats.length === 4 && cats[0].label === 'Développeurs' && cats[3].label === 'IA et data');
  await as(A);
  const dev = cats.find(c => c.label === 'Développeurs').id, des = cats.find(c => c.label === 'Designers').id, biz = cats.find(c => c.label === 'Business').id;
  await fails('categories : creation reservee a l admin', `select mate_category_save(null, 'Juristes', array['droit'])`, /Réservé/);
  await fails('categories : suppression reservee a l admin', `select mate_category_delete('${dev}')`, /Réservé/);
  // --- recherche
  let r = (await q(`select mates_search('') r`))[0].r;
  check('recherche : jamais soi-meme, ni etudiant sans competence', r.length === 2 && !r.some(x => x.id === A || x.id === D));
  r = (await q(`select mates_search('flutter') r`))[0].r;
  check('recherche : texte libre sans soi-meme', r.length === 0);
  await as(B);
  r = (await q(`select mates_search('flutter') r`))[0].r;
  check('recherche : par competence', r.length === 1 && r[0].id === A && r[0].skills === 'Flutter, Python');
  r = (await q(`select mates_search('civil') r`))[0].r;
  check('recherche : ne trouve pas son propre profil', r.length === 0);
  r = (await q(`select mates_search('', '${dev}') r`))[0].r;
  check('categorie Developpeurs : Awa (Flutter)', r.length === 1 && r[0].id === A);
  r = (await q(`select mates_search('', '${biz}') r`))[0].r;
  check('categorie Business : Cora (Marketing)', r.length === 1 && r[0].id === C);
  r = (await q(`select mates_search('', null, 'gestion') r`))[0].r;
  check('filtre filiere', r.length === 1 && r[0].id === C);
  await as(null, 'anon');
  await fails('recherche : connexion requise', `select mates_search('x')`, /permission|Connexion/);
  // --- admin gère les catégories
  await as(M);
  const jur = (await q(`select mate_category_save(null, 'Juristes', array['droit', 'Juridique', 'droit']) id`))[0].id;
  await fails('categories : nom unique', `select mate_category_save(null, 'juristes', array['loi'])`, /déjà/);
  await fails('categories : mot-cle obligatoire', `select mate_category_save(null, 'Vide', array[]::text[])`, /mot-clé/);
  await fails('categories : nom obligatoire', `select mate_category_save(null, ' ', array['x'])`, /nom/);
  cats = (await q(`select mate_categories_list() r`))[0].r;
  const j = cats.find(c => c.id === jur);
  check('categories : mots-cles nettoyes et dedoublonnes', cats.length === 5 && j.keywords.length === 2 && j.keywords.includes('juridique'));
  await q(`select mate_category_save('${jur}', 'Juristes et droit', array['droit'], 9, false)`);
  await as(A);
  cats = (await q(`select mate_categories_list() r`))[0].r;
  check('categories : desactivee invisible des etudiants', cats.length === 4);
  await as(M);
  cats = (await q(`select mate_categories_list() r`))[0].r;
  check('categories : l admin voit aussi les desactivees', cats.length === 5);
  await q(`select mate_category_save('${des}', 'Designers', array['design', 'figma'], 2, true)`);
  await q(`select mate_category_delete('${jur}')`);
  await fails('categories : suppression d une categorie absente', `select mate_category_delete('${jur}')`, /introuvable/);
  cats = (await q(`select mate_categories_list() r`))[0].r;
  check('categories : supprimee', cats.length === 4);
  await as(A);
  r = (await q(`select mates_search('', '${des}') r`))[0].r;
  check('categorie modifiee par l admin : filtre applique', r.length === 1 && r[0].id === B);
  // --- invitations
  await as(A);
  await fails('invitation : pas soi-meme', `select teammate_invite('${A}')`, /vous-même/);
  await fails('invitation : etudiant inconnu', `select teammate_invite('${M}')`, /introuvable/);
  const inv = (await q(`select teammate_invite('${B}', 'On monte une equipe pour le hackathon') id`))[0].id;
  await fails('invitation : pas de doublon en attente', `select teammate_invite('${B}')`, /déjà en attente/);
  r = (await q(`select mates_search('Figma') r`))[0].r;
  check('recherche : etat de l invitation visible', r.length === 1 && r[0].invite === 'pending');
  await as(B);
  check('invitation : notifiee a l etudiant invite', (await q(`select count(*)::int n from notifications where user_id='${B}' and kind='teammate_invite'`))[0].n === 1);
  let rec = (await q(`select my_teammate_invites('received') r`))[0].r;
  check('invitation : recue avec le nom de l expediteur', rec.length === 1 && rec[0].other === 'Awa E.' && rec[0].status === 'pending');
  await as(C);
  await fails('invitation : seul le destinataire repond', `select teammate_invite_decide('${inv}', true)`, /introuvable/);
  await as(B);
  check('invitation : acceptee', (await q(`select teammate_invite_decide('${inv}', true) r`))[0].r === 'accepted');
  await fails('invitation : une seule reponse', `select teammate_invite_decide('${inv}', false)`, /déjà reçu/);
  await as(A);
  check('invitation : l expediteur est notifie de la reponse', (await q(`select count(*)::int n from notifications where user_id='${A}' and title='Invitation acceptée'`))[0].n === 1);
  const sent = (await q(`select my_teammate_invites('sent') r`))[0].r;
  check('invitation : liste des envoyees', sent.length === 1 && sent[0].status === 'accepted' && sent[0].other === 'Boris E.');
  const inv2 = (await q(`select teammate_invite('${C}') id`))[0].id;
  await as(C);
  check('invitation : declinee', (await q(`select teammate_invite_decide('${inv2}', false) r`))[0].r === 'declined');
  await as(A);
  check('invitation : nouvelle invitation possible apres reponse', (await q(`select teammate_invite('${C}') id`))[0].id !== undefined);
  // --- pas d'accès direct aux tables
  await fails('tables : aucun acces direct aux invitations', `select * from teammate_invites`, /permission/);
  await fails('tables : aucun acces direct aux categories', `insert into mate_categories(label, keywords) values ('Pirate', array['x'])`, /permission/);
  console.log(`\n${ok}/${ok + ko}`);
}
