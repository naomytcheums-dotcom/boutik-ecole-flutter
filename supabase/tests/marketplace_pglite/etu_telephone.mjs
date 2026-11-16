// Scénario PGlite de 20261117990100_verification_telephone.sql : un numéro non vérifié n'a aucun pouvoir et ne bloque pas son vrai propriétaire.
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  for (const n of [61, 62, 63]) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','t${n}@t.cm')`);
  // 61 : le squatteur déclare le numéro de la victime à l'inscription
  await as(U(61));
  await q(`insert into profiles(id, name, role, email, phone) values ('${U(61)}', 'Squatteur', 'student', 't61@t.cm', '690000111')`);
  await db.exec('reset role');
  const sq = (await q(`select phone, phone_verified from profiles where id = '${U(61)}'`))[0];
  check('inscription : le numéro déclaré n\'est pas vérifié', sq.phone === '690000111' && sq.phone_verified === false);
  // 62 : la vraie propriétaire enregistre son numéro : le simple squat est évincé
  await as(U(62));
  await q(`insert into profiles(id, name, role, email) values ('${U(62)}', 'Victime', 'student', 't62@t.cm')`);
  await q(`select profile_set_phone('690000111')`);
  await db.exec('reset role');
  check('numéro déclaré : le vrai propriétaire n\'est pas bloqué', (await q(`select phone from profiles where id = '${U(62)}'`))[0].phone === '690000111');
  check('numéro déclaré : le squatteur perd le numéro', (await q(`select phone from profiles where id = '${U(61)}'`))[0].phone === null);
  // vérification par le service
  await as(null, 'service_role');
  await q(`select phone_verify_apply('${U(62)}', '690000111')`);
  await db.exec('reset role');
  check('vérification : le numéro est marqué vérifié', (await q(`select phone_verified from profiles where id = '${U(62)}'`))[0].phone_verified === true);
  await as(U(61));
  await fails('numéro vérifié : plus personne ne peut le déclarer', `select profile_set_phone('690000111')`, /déjà utilisé/);
  await fails('phone_verify_apply : non appelable par un utilisateur', `select phone_verify_apply('${U(61)}', '690000222')`, /permission denied/);
  await fails('phone_verified : non modifiable directement', `update profiles set phone_verified = true where id = '${U(61)}'`, /permission denied/);
  await as(U(62));
  await fails('numéro vérifié : se change par le support seulement', `select profile_set_phone('690000333')`, /contactez le support/);
  console.log(`etu_telephone: ${ok} OK, ${ko} KO`);
}
