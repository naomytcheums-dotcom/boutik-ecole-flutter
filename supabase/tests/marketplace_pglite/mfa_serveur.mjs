// 2FA côté serveur : la garde db_pre_request refuse les opérations sensibles à une session aal1 dont le compte a un facteur vérifié.
export async function run(db) {
  let ok = 0, ko = 0;
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const q = async (sql) => (await db.query(sql)).rows;
  const call = async (path, uid, aal) => {
    const claims = uid ? JSON.stringify({ sub: uid, ...(aal ? { aal } : {}) }) : '';
    await db.exec(`select set_config('request.path', '${path}', false), set_config('request.jwt.claims', '${claims}', false)`);
    try { await db.exec('select enforce_mfa_on_sensitive()'); return 'ok'; } catch (e) { return e.message; }
  };
  for (const n of [31, 32, 33]) {
    await db.exec(`insert into auth.users (id, email) values ('${U(n)}', 'mfa${n}@test.local') on conflict do nothing`);
  }
  await db.exec(`insert into auth.mfa_factors (user_id, status) values ('${U(31)}', 'verified'), ('${U(32)}', 'unverified')`);

  check('opération sensible refusée en aal1 avec un facteur vérifié', /double authentification/.test(await call('/rpc/payment_start', U(31), 'aal1')));
  check('absence de claim aal = aal1 : refusée', /double authentification/.test(await call('/rpc/marketplace_checkout', U(31), null)));
  check('suppression de compte refusée en aal1', /double authentification/.test(await call('/rpc/request_account_deletion', U(31), 'aal1')));
  check('aal2 : autorisée', (await call('/rpc/payment_start', U(31), 'aal2')) === 'ok');
  check('facteur non vérifié : autorisée', (await call('/rpc/payment_start', U(32), 'aal1')) === 'ok');
  check('compte sans facteur : autorisée', (await call('/rpc/payment_start', U(33), 'aal1')) === 'ok');
  check('fonction non sensible : jamais bloquée', (await call('/rpc/marketplace_search', U(31), 'aal1')) === 'ok');
  check('lecture de table : jamais bloquée', (await call('/profiles', U(31), 'aal1')) === 'ok');
  check('requête anonyme : jamais bloquée', (await call('/rpc/payment_start', null, null)) === 'ok');
  check('jeton illisible : la garde laisse passer (API jamais coupée)', await (async () => {
    await db.exec(`select set_config('request.path', '/rpc/payment_start', false), set_config('request.jwt.claims', 'pas-du-json', false)`);
    try { await db.exec('select enforce_mfa_on_sensitive()'); return true; } catch { return false; }
  })());
  check('préfixe de nom : payment_start_x non confondu', (await call('/rpc/payment_start_x', U(31), 'aal1')) === 'ok');
  console.log(`mfa_serveur: ${ok} OK, ${ko} KO`);
}
