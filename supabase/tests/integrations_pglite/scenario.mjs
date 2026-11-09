// Scénario SQL du hub d'intégrations (migration 20261109000000) — à exécuter avec le rejeu PGlite de la marketplace :
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ../integrations_pglite/scenario.mjs
// Vérifie la RLS, l'étanchéité des jetons, l'anti-doublon des envois, la vérification des numéros et l'unicité des contenus importés.
let ok = 0, ko = 0;
export async function run(db) {
  const A = '00000000-0000-0000-0000-0000000000a1', B = '00000000-0000-0000-0000-0000000000b1';
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql, params) => (await db.query(sql, params)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };

  await db.exec('reset role');
  for (const [id, n] of [[A, 'a'], [B, 'b']]) await db.exec(`insert into auth.users(id,email) values ('${id}','${n}@t.cm') on conflict do nothing`);

  // ------------------------------------------------------------ catalogue
  await as(A);
  let r = await q(`select count(*)::int c from integration_providers`);
  check('21 fournisseurs au catalogue', r[0].c === 21, JSON.stringify(r));
  r = await q(`select id from integration_providers where family = 'telecom' order by id`);
  check('famille télécoms : MTN et Orange', r.map(x => x.id).join() === 'mtn_momo,orange_money');
  r = await q(`select can_publish from integration_providers where id = 'tiktok'`);
  check('TikTok : publication non proposée (audit)', r[0].can_publish === false);
  r = await q(`select can_import from integration_providers where id = 'linkedin'`);
  check('LinkedIn : import non proposé (approbation)', r[0].can_import === false);
  await as(null, 'anon');
  try { r = await q(`select * from integration_providers`); check('anonyme : catalogue non lisible', r.length === 0 || false, JSON.stringify(r.length)); } catch (e) { check('anonyme : catalogue non lisible', /permission|denied/i.test(e.message), e.message); }

  // ------------------------------------------------------------ jetons : étanchéité
  await as(null);
  await db.exec('reset role');
  await db.exec(`insert into integration_connections(id,user_id,provider,external_id,display_name) values ('10000000-0000-0000-0000-00000000000a','${A}','github','gh1','mariam')`);
  await db.exec(`insert into integration_tokens(connection_id,access_enc) values ('10000000-0000-0000-0000-00000000000a','v1.xx.yy')`);
  for (const [who, name] of [[A, 'propriétaire'], [B, 'autre compte']]) {
    await as(who);
    await fails(`jetons illisibles pour le ${name}`, `select * from integration_tokens`, /permission denied/i);
    await fails(`états OAuth illisibles pour le ${name}`, `select * from integration_oauth_states`, /permission denied/i);
    await fails(`codes de vérification illisibles pour le ${name}`, `select * from momo_verifications`, /permission denied/i);
  }
  await as(A);
  r = await q(`select count(*)::int c from integration_connections`);
  check('A voit sa connexion', r[0].c === 1);
  await as(B);
  r = await q(`select count(*)::int c from integration_connections`);
  check('B ne voit pas la connexion de A', r[0].c === 0);
  await as(A);
  await fails('A ne peut pas créer une connexion directement', `insert into integration_connections(user_id,provider,external_id) values ('${A}','github','x')`, /row-level security|permission/i);
  r = await q(`update integration_connections set status = 'revoked' where id = '10000000-0000-0000-0000-00000000000a' returning id`);
  check('A ne peut pas modifier sa connexion (service seulement)', r.length === 0);

  // ------------------------------------------------------------ contenus importés : unicité, visibilité
  await db.exec('reset role');
  await db.exec(`insert into integration_imported_items(id,connection_id,user_id,provider,external_id,title) values ('20000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','${A}','github','r1','depot')`);
  try { await db.exec(`insert into integration_imported_items(connection_id,user_id,provider,external_id,title) values ('10000000-0000-0000-0000-00000000000a','${A}','github','r1','doublon')`); check('même contenu importé deux fois refusé', false); }
  catch (e) { check('même contenu importé deux fois refusé', /unique|duplicate/i.test(e.message), e.message); }
  await db.exec(`insert into integration_imported_items(connection_id,user_id,provider,external_id,title) values ('10000000-0000-0000-0000-00000000000a','${A}','github','r1','doublon') on conflict (connection_id, external_id) do nothing`);
  r = await q(`select count(*)::int c from integration_imported_items`);
  check('import idempotent (on conflict do nothing)', r[0].c === 1);
  await as(B);
  r = await q(`select count(*)::int c from integration_imported_items`);
  check('contenu privé invisible aux autres', r[0].c === 0);
  await fails('B ne peut pas changer la visibilité d’un contenu de A', `select integrations_set_item_visibility('20000000-0000-0000-0000-00000000000a','public')`, /introuvable/);
  await as(A);
  await q(`select integrations_set_item_visibility('20000000-0000-0000-0000-00000000000a','public')`);
  await fails('visibilité invalide refusée', `select integrations_set_item_visibility('20000000-0000-0000-0000-00000000000a','tous')`, /invalide/);
  await as(B);
  r = await q(`select count(*)::int c from integration_imported_items`);
  check('contenu public visible aux autres comptes', r[0].c === 1);
  await as(A);
  await q(`select integrations_delete_item('20000000-0000-0000-0000-00000000000a')`);
  r = await q(`select count(*)::int c from integration_imported_items`);
  check('A supprime son contenu', r[0].c === 0);

  // ------------------------------------------------------------ lien de portfolio (Behance)
  await fails('lien http:// refusé', `select integrations_save_link('behance','http://behance.net/x')`, /https/);
  await fails('fournisseur OAuth refusé pour un lien libre', `select integrations_save_link('github','https://github.com/x')`, /autorisation officielle/);
  r = await q(`select integrations_save_link('behance','https://www.behance.net/mariam') id`);
  check('lien Behance enregistré', !!r[0].id);
  await q(`select integrations_save_link('behance','https://www.behance.net/mariam')`);
  r = await q(`select count(*)::int c from integration_connections where provider = 'behance'`);
  check('même lien enregistré une seule fois', r[0].c === 1);

  // ------------------------------------------------------------ publications : idempotence
  await db.exec('reset role');
  await db.exec(`insert into integration_publications(user_id,content,idempotency_key) values ('${A}','Bonjour','clef-unique-1')`);
  try { await db.exec(`insert into integration_publications(user_id,content,idempotency_key) values ('${A}','Bonjour','clef-unique-1')`); check('même clé de publication refusée', false); }
  catch (e) { check('même clé de publication refusée', /unique|duplicate/i.test(e.message)); }
  await as(B);
  r = await q(`select count(*)::int c from integration_publications`);
  check('publications de A invisibles pour B', r[0].c === 0);

  // ------------------------------------------------------------ Mobile Money : numéros
  await as(A);
  await fails('opérateur inconnu refusé', `select momo_add_number('WAVE','677000001','x')`, /Opérateur/);
  await fails('numéro invalide refusé', `select momo_add_number('MTN','12345','x')`, /Numéro/);
  const n1 = (await q(`select momo_add_number('MTN','6 77 00 00 01','Boutique') id`))[0].id;
  const n2 = (await q(`select momo_add_number('ORANGE','+237 690 00 00 02','Perso') id`))[0].id;
  r = await q(`select id, is_primary, phone, verification_status from momo_numbers order by created_at`);
  check('premier numéro = compte principal', r[0].id === n1 && r[0].is_primary === true && r[1].is_primary === false);
  check('numéro normalisé (237…)', r[0].phone === '237677000001' && r[1].phone === '237690000002');
  check('nouveau numéro non vérifié', r.every(x => x.verification_status === 'unverified'));
  await fails('numéro déjà enregistré refusé', `select momo_add_number('MTN','677000001','y')`, /déjà enregistré/);
  await q(`select momo_rename_number('${n2}', 'Épargne')`);
  await q(`select momo_set_primary('${n2}')`);
  r = await q(`select id from momo_numbers where is_primary`);
  check('un seul compte principal à la fois', r.length === 1 && r[0].id === n2);
  r = await q(`update momo_numbers set verification_status = 'verified' where id = '${n1}' returning id`);
  check('A ne peut pas se déclarer « vérifié » lui-même', r.length === 0);
  await as(B);
  r = await q(`select count(*)::int c from momo_numbers`);
  check('B ne voit aucun numéro de A', r[0].c === 0);
  await fails('B ne peut pas changer le compte principal de A', `select momo_set_primary('${n1}')`, /introuvable/);
  await fails('B ne peut pas supprimer un numéro de A', `select momo_remove_number('${n1}')`, /introuvable/);

  // ------------------------------------------------------------ vérification par SMS
  await as(A);
  await fails('pas de code demandé : vérification impossible', `select momo_confirm_verification('${n1}','123456')`, /expiré/);
  await db.exec('reset role');
  await db.exec(`insert into momo_verifications(number_id,user_id,code_hash) values ('${n1}','${A}', encode(digest('482915','sha256'),'hex'))`);
  await as(B);
  await fails('B ne peut pas vérifier le numéro de A', `select momo_confirm_verification('${n1}','482915')`, /expiré/);
  await as(A);
  r = await q(`select momo_confirm_verification('${n1}','000000') ok`);
  check('mauvais code : refusé, numéro toujours non vérifié', r[0].ok === false && (await q(`select verification_status s from momo_numbers where id = '${n1}'`))[0].s === 'unverified');
  r = await q(`select momo_confirm_verification('${n1}','482915') ok`);
  check('bon code : numéro vérifié', r[0].ok === true && (await q(`select verification_status s from momo_numbers where id = '${n1}'`))[0].s === 'verified');
  await fails('un code ne sert qu’une fois', `select momo_confirm_verification('${n1}','482915')`, /expiré/);
  await db.exec('reset role');
  await db.exec(`insert into momo_verifications(number_id,user_id,code_hash) values ('${n2}','${A}', encode(digest('111111','sha256'),'hex'))`);
  await as(A);
  for (let i = 0; i < 5; i++) await q(`select momo_confirm_verification('${n2}','999999')`);
  await fails('5 essais maximum', `select momo_confirm_verification('${n2}','111111')`, /Trop d’essais|Trop d'essais/);

  // ------------------------------------------------------------ envoi : préparation, anti-doublon, annulation
  await fails('numéro non vérifié : envoi refusé', `select momo_prepare_transfer('${n2}','677123456',1000,'x','cle-envoi-000001')`, /Vérifiez/);
  await fails('montant nul refusé', `select momo_prepare_transfer('${n1}','677123456',0,'x','cle-envoi-000002')`, /Montant/);
  await fails('montant au-dessus du plafond refusé', `select momo_prepare_transfer('${n1}','677123456',600000,'x','cle-envoi-000003')`, /Montant/);
  await fails('envoi à soi-même refusé', `select momo_prepare_transfer('${n1}','677000001',1000,'x','cle-envoi-000004')`, /différent/);
  await fails('clé d’unicité trop courte refusée', `select momo_prepare_transfer('${n1}','677123456',1000,'x','abc')`, /Clé/);
  const ref1 = (await q(`select momo_prepare_transfer('${n1}','6 77 12 34 56',2500,'Loyer','cle-envoi-000010') ref`))[0].ref;
  check('référence MM…', /^MM\d{6}\d{6}$/.test(ref1), ref1);
  const ref1b = (await q(`select momo_prepare_transfer('${n1}','677123456',2500,'Loyer','cle-envoi-000010') ref`))[0].ref;
  check('même clé : même transaction, jamais un second envoi', ref1b === ref1);
  await fails('envoi identique déjà en cours refusé (autre clé)', `select momo_prepare_transfer('${n1}','677123456',2500,'Loyer','cle-envoi-000011')`, /identique/);
  r = await q(`select status, amount, counterparty_phone, confirmed_by_user_at from momo_transactions where reference = '${ref1}'`);
  check('envoi préparé = à confirmer, rien d’engagé', r.length === 1 && r[0].status === 'awaiting_confirmation' && r[0].confirmed_by_user_at === null && r[0].amount === 2500);
  r = await q(`update momo_transactions set status = 'confirmed' where reference = '${ref1}' returning id`);
  check('A ne peut pas se marquer un paiement « réussi »', r.length === 0);
  await fails('A ne peut pas créer de transaction directement', `insert into momo_transactions(reference,user_id,operator,counterparty_phone,amount,idempotency_key) values ('MMX','${A}','MTN','237677123456',1,'cle-direct-001')`, /row-level security|permission/i);
  await as(B);
  await fails('B ne peut pas annuler l’envoi de A', `select momo_cancel_transfer('${ref1}')`, /introuvable/);
  await as(A);
  await q(`select momo_cancel_transfer('${ref1}')`);
  r = await q(`select status from momo_transactions where reference = '${ref1}'`);
  check('annulation avant confirmation : aucun débit', r[0].status === 'cancelled');
  await fails('une transaction annulée ne peut plus être annulée', `select momo_cancel_transfer('${ref1}')`, /introuvable|déjà engagée/);

  // ------------------------------------------------------------ tableau de bord, suppression protégée
  await db.exec('reset role');
  await db.exec(`insert into momo_transactions(reference,user_id,number_id,operator,direction,counterparty_phone,amount,status,idempotency_key) values
    ('MM-T1','${A}','${n1}','MTN','out','237677123456',5000,'confirmed','cle-test-000001'),
    ('MM-T2','${A}','${n1}','MTN','in','237677123456',3000,'confirmed','cle-test-000002'),
    ('MM-T3','${A}','${n1}','MTN','out','237677123457',9000,'failed','cle-test-000003'),
    ('MM-T4','${A}','${n1}','MTN','out','237677123458',700,'pending','cle-test-000004')`);
  await as(A);
  r = (await q(`select momo_dashboard() d`))[0].d;
  check('tableau de bord : envoyé = seulement les réussis', r.sent_month === 5000 && r.received_month === 3000, JSON.stringify(r));
  check('tableau de bord : en cours et échecs comptés', r.pending === 1 && r.failed_month === 1 && r.count_month === 2, JSON.stringify(r));
  await fails('suppression refusée pendant une transaction en cours', `select momo_remove_number('${n1}')`, /en cours/);
  await q(`select momo_remove_number('${n2}')`);
  r = await q(`select count(*)::int c from momo_numbers`);
  check('numéro supprimé', r[0].c === 1);
  await as(B);
  r = (await q(`select momo_dashboard() d`))[0].d;
  check('tableau de bord de B : vide', r.sent_month === 0 && r.pending === 0, JSON.stringify(r));

  console.log(`\nRésultat : ${ok}/${ok + ko}`);
  if (ko) process.exitCode = 1;
}
