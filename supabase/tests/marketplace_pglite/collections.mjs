let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-00000000000a', B = '00000000-0000-0000-0000-00000000000b';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [id, nm] of [[A, 'Awa Etudiante'], [B, 'Boris Etudiant']]) {
    await db.exec(`insert into auth.users(id,email) values ('${id}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email) values ('${id}','${nm}','student','${nm.split(' ')[0]}@t.cm')`);
  }
  await as(A);
  await fails('nom trop court', `select collection_save(null, 'a')`, /nom/);
  await fails('visibilite inconnue', `select collection_save(null, 'Maison', 'secret')`, /Visibilité/);
  const c1 = (await q(`select collection_save(null, 'Maison et déco', 'private') id`))[0].id;
  await fails('nom unique par compte', `select collection_save(null, 'maison et déco')`, /déjà/);
  const c2 = (await q(`select collection_save(null, 'Cadeaux', 'shared') id`))[0].id;
  check('liste : mes collections', (await q(`select collections_list() r`))[0].r.length === 2);
  check('ajout produit', (await q(`select collection_item_toggle('${c1}', 'Lampe de bureau') r`))[0].r === true);
  await q(`select collection_item_toggle('${c1}', 'Tapis')`);
  let l = (await q(`select collections_list() r`))[0].r.find(x => x.id === c1);
  check('compteur et produits', l.count === 2 && l.items.includes('Lampe de bureau'));
  check('retrait produit (second appel)', (await q(`select collection_item_toggle('${c1}', 'Tapis') r`))[0].r === false);
  await q(`select collection_save('${c1}', 'Salon', 'public')`);
  l = (await q(`select collections_list() r`))[0].r.find(x => x.id === c1);
  check('renommer et changer la visibilite', l.name === 'Salon' && l.visibility === 'public' && l.count === 1);
  await as(B);
  check('privee/partagee : B ne voit pas la liste de A', (await q(`select collections_list() r`))[0].r.length === 0);
  check('collection publique lisible par B', (await q(`select collection_get('${c1}') r`))[0].r.items[0] === 'Lampe de bureau');
  check('collection partagee lisible par lien', (await q(`select collection_get('${c2}') r`))[0].r.mine === false);
  await fails('B ne modifie pas la collection de A', `select collection_item_toggle('${c1}', 'X')`, /introuvable/);
  await fails('B ne supprime pas la collection de A', `select collection_delete('${c1}')`, /introuvable/);
  await as(A);
  await q(`select collection_save('${c2}', 'Cadeaux', 'private')`);
  await as(B);
  check('privee : illisible par B', (await q(`select collection_get('${c2}') r`))[0].r === null);
  await as(A);
  await q(`select collection_delete('${c1}')`);
  check('suppression', (await q(`select collections_list() r`))[0].r.length === 1);
  await fails('aucun acces direct', `select * from user_collections`, /permission/);
  console.log(`\n${ok}/${ok + ko}`);
}
