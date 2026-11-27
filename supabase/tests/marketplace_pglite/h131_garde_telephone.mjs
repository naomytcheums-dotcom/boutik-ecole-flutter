// H13.1 · Garde temporaire des numeros verifies (migration 20261129900100) : etat de production reproduit (deux comptes verifies, meme numero sous deux formes),
// la garde ne bloque pas les comptes existants mais refuse tout NOUVEAU doublon, y compris par ecriture directe ; les procedures normales gardent leur message.
// Usage (depuis supabase/tests/marketplace_pglite) : node replay.mjs all ./h131_garde_telephone.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-00000000b9${String(n).padStart(2, '0')}`;
  const A = id(1), B = id(2), C = id(3), D = id(4);
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await db.exec(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const q = async (sql) => (await db.query(sql)).rows;
  await db.exec('reset role');
  // la production n'a PAS l'index unique (il ne peut pas y etre cree : doublon existant) : on reproduit cet etat
  await db.exec('drop index if exists profiles_phone_verified_uk');
  for (const [i, nm, role] of [[A, 'Admin Test', 'admin'], [B, 'Etu Test', 'student'], [C, 'Etu Trois', 'student'], [D, 'Etu Quatre', 'student']]) {
    await db.exec(`insert into auth.users(id,email) values ('${i}','p${i.slice(-2)}@t.cm'); insert into profiles(id,name,role,email) values ('${i}','${nm}','${role}','p${i.slice(-2)}@t.cm')`);
  }
  // etat de production : le doublon existe deja (cree AVANT la garde : on la retire le temps de le fabriquer, puis on la remet)
  await db.exec(`alter table profiles disable trigger profiles_phone_verified_guard`);
  await db.exec(`update profiles set phone = '+237677000111', phone_verified = true where id = '${A}'; update profiles set phone = '677000111', phone_verified = true where id = '${B}'`);
  await db.exec(`alter table profiles enable trigger profiles_phone_verified_guard`);
  const dup = (await q(`select count(*)::int n from profiles where phone_verified and right(regexp_replace(phone, '\\D', '', 'g'), 9) = '677000111'`))[0].n;
  check('A1 le doublon de production est reproduit (2 comptes verifies, meme numero, deux formats)', dup === 2);

  // les comptes existants ne sont pas bloques
  await db.exec(`update profiles set name = 'Admin Renomme' where id = '${A}'`);
  await db.exec(`update profiles set phone = '677000111', phone_verified = true where id = '${B}'`);
  check('B1 modifier un autre champ d\'un compte en doublon reste possible', (await q(`select name from profiles where id = '${A}'`))[0].name === 'Admin Renomme');
  check('B2 reecrire la meme valeur (ni numero ni drapeau ne change) ne declenche pas la garde', true);

  // un nouveau doublon est refuse
  await db.exec(`update profiles set phone = '677000999' where id = '${C}'`);
  await fails('C1 un troisieme compte ne peut pas devenir verifie sur le numero deja verifie (ecriture directe)', `update profiles set phone = '677000111', phone_verified = true where id = '${C}'`, /déjà utilisé/);
  await fails('C2 meme avec le prefixe +237', `update profiles set phone = '+237677000111', phone_verified = true where id = '${C}'`, /déjà utilisé/);
  await fails('C3 meme avec le prefixe 00237', `update profiles set phone = '00237677000111', phone_verified = true where id = '${C}'`, /déjà utilisé/);
  // profiles.phone est unique a la lettre : le meme numero s'ecrit sous une autre forme
  await db.exec(`update profiles set phone = '0677000111' where id = '${C}'`);
  check('C4 declarer le numero SANS le verifier reste possible (il n\'a aucun pouvoir)', (await q(`select phone_verified from profiles where id = '${C}'`))[0].phone_verified === false);
  await fails('C5 le marquer verifie ensuite est refuse', `update profiles set phone_verified = true where id = '${C}'`, /déjà utilisé/);
  await fails('C6 insertion directe d\'un profil verifie sur ce numero refusee', `insert into auth.users(id,email) values ('${id(9)}','x@t.cm'); insert into profiles(id,name,role,email,phone,phone_verified) values ('${id(9)}','X','student','x@t.cm','677000111',true)`, /déjà utilisé/);

  // un numero libre se verifie normalement ; un numero deja verifie ailleurs ne l'est pas
  await db.exec(`update profiles set phone = '677000222', phone_verified = true where id = '${D}'`);
  check('D1 un numero libre se verifie normalement', (await q(`select phone_verified from profiles where id = '${D}'`))[0].phone_verified === true);
  // la procedure normale conserve son message
  await db.exec(`set role service_role; select set_config('request.jwt.claim.role', 'service_role', false)`).catch(() => {});
  await db.exec('reset role');
  await fails('D2 phone_verify_apply refuse le numero deja verifie ailleurs (message existant)', `select phone_verify_apply('${C}', '677000111')`, /déjà utilisé/);

  // une fois le doublon resolu par le proprietaire (ici : on retire la verification de l'etudiant), l'index unique peut etre cree
  await db.exec(`update profiles set phone_verified = false where id = '${B}'`);
  let created = true;
  try { await db.exec(`create unique index if not exists profiles_phone_verified_uk on profiles ((right(regexp_replace(phone, '\\D', '', 'g'), 9))) where phone is not null and phone <> '' and phone_verified`); } catch (e) { created = false; }
  check('E1 apres decision du proprietaire (un seul compte garde la verification), l\'index unique se cree', created);
  await db.exec('drop index if exists profiles_phone_verified_uk');
  console.log(`h131_garde_telephone : ${ok} OK, ${ko} ECHEC`);
}
