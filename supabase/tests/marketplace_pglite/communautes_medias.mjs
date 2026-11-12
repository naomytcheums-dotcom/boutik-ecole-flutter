let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b', M = '00000000-0000-0000-0000-0000000000ee';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm, role] of [[A, 'Awa Etudiante', 'student'], [B, 'Paul Membre', 'student'], [M, 'Mod Admin', 'admin']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','${role}','${nm.split(' ')[0]}@t.cm')`);
  }
  await as(A);
  const cid = (await q(`select create_community('Dev Flutter','Entraide autour de Flutter','','public','',null,'interest',null,'Flutter') id`))[0].id;
  await as(M);
  await q(`select community_decide('${cid}', true)`);
  await as(B);
  await q(`select join_community('${cid}')`);
  // --- pièces jointes
  await fails('photo : doit etre dans son dossier', `select create_community_post('${cid}', 'Voir ma photo', null, '${A}/x.jpg', 'image')`, /dossier/);
  await fails('media : type inconnu', `select create_community_post('${cid}', 'Voir', null, '${B}/x.jpg', 'audio')`, /Type de média/);
  await fails('media : pas de fond design avec une photo', `select create_community_post('${cid}', 'Voir', 'sunset', '${B}/x.jpg', 'image')`, /fond design/);
  await fails('lien : doit etre https', `select create_community_post('${cid}', 'Voir', null, null, null, 'javascript:alert(1)')`, /https/);
  await fails('lien : sans espace', `select create_community_post('${cid}', 'Voir', null, null, null, 'https://a.cm/ x')`, /https/);
  await q(`select create_community_post('${cid}', 'Ma photo du labo', null, '${B}/1.jpg', 'image')`);
  await q(`select create_community_post('${cid}', 'Ma video de demo', null, '${B}/2.mp4', 'video')`);
  await q(`select create_community_post('${cid}', 'Un lien utile', null, null, null, 'https://developer.mozilla.org/fr/')`);
  await q(`select create_community_post('${cid}', 'Publication simple')`);
  const feed = await q(`select * from community_feed('${cid}')`);
  const img = feed.find(x => x.body === 'Ma photo du labo'), vid = feed.find(x => x.body === 'Ma video de demo'), lnk = feed.find(x => x.body === 'Un lien utile'), txt = feed.find(x => x.body === 'Publication simple');
  check('fil : photo', img.media_kind === 'image' && img.media_path === `${B}/1.jpg` && img.link_url === null);
  check('fil : video', vid.media_kind === 'video' && vid.media_path.endsWith('2.mp4'));
  check('fil : lien', lnk.link_url === 'https://developer.mozilla.org/fr/' && lnk.media_path === null);
  check('fil : publication simple inchangee', txt.media_path === null && txt.link_url === null && txt.kind === 'text');
  // --- photo et couverture
  await fails('images : reservees au proprietaire ou admin', `select community_set_images('${cid}', '${B}/logo.png', null)`, /Réservé/);
  await as(A);
  await fails('images : dans son dossier', `select community_set_images('${cid}', '${B}/logo.png', null)`, /dossier/);
  await q(`select community_set_images('${cid}', '${A}/logo.png', '${A}/cover.jpg')`);
  await as(B);
  let im = (await q(`select community_images('${cid}') r`))[0].r;
  check('images : lisibles par les membres', im.logo_path === `${A}/logo.png` && im.cover_path === `${A}/cover.jpg`);
  await as(A);
  await q(`select community_set_images('${cid}', '${A}/logo2.png')`);
  im = (await q(`select community_images('${cid}') r`))[0].r;
  check('images : changer la photo garde la couverture', im.logo_path === `${A}/logo2.png` && im.cover_path === `${A}/cover.jpg`);
  await q(`select community_set_images('${cid}', null, null, false, true)`);
  im = (await q(`select community_images('${cid}') r`))[0].r;
  check('images : retirer la couverture', im.cover_path === null && im.logo_path !== null);
  await as(M);
  await q(`select community_set_images('${cid}', null, null, true, false)`);
  im = (await q(`select community_images('${cid}') r`))[0].r;
  check('images : l equipe peut retirer une image', im.logo_path === null);
  console.log(`\n${ok}/${ok + ko}`);
}
