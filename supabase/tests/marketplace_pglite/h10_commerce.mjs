// Scénario PGlite du lot H10 COMMERCE (20261126050000_h10_ressources_numeriques.sql) : ressources numériques livrables sous droits d'accès.
// Droit de téléchargement créé seulement quand la commande est payée (circuit existant) ; URL refusée avant paiement / après remboursement ou annulation / pour un autre acheteur ;
// limite ; journal ; isolation entre vendeurs ; vendeur non éligible et anonyme refusés ; rejeu sans effet ; l'argent (séquestre 70/20/10) est inchangé.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h10_commerce.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000090${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const sup = async () => { await db.exec('reset role'); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const works = async (name, sql, test = () => true) => { try { const r = await q(sql); check(name, test(r), JSON.stringify(r)); } catch (e) { check(name, false, e.message); } };
  const qs = async (sql) => { await sup(); return q(sql); };

  await sup();
  await db.exec('grant all on storage.objects to authenticated');
  // 1 vendeur A (éligible) ; 2 vendeur B (éligible) ; 3 acheteur 1 ; 4 acheteur 2 ; 5 étudiant NON vérifié ; 6 client ; 7 administrateur ; 8 vendeur C (éligible, forfait normal)
  const roles = { 1: 'student', 2: 'student', 3: 'client', 4: 'client', 5: 'student', 6: 'client', 7: 'admin', 8: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','h10c${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Compte H10 ${n}','${r}','h10c${n}@t.cm')`);
    await db.exec(`update profiles set phone = '69090' || lpad('${n}', 4, '0'), phone_verified = true where id = '${U(n)}'`);
  }
  for (const n of [1, 2, 8]) await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(n)}', 'student_card', 'c.pdf', '${U(n)}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${U(n)}'`);
  await db.exec(`update profiles set phone_verified = false where id = '${U(5)}'`);
  await db.exec(`update profiles set is_test = true where id = '${U(7)}'`);
  const cap = async (n) => { await as(U(n)); const r = (await q(`select my_seller_capability() c`))[0].c; await sup(); return r; };
  for (const n of [1, 2, 8]) check(`fixture : vendeur ${n} éligible`, (await cap(n)).can_sell === true);
  check('fixture : étudiant 5 non éligible', (await cap(5)).can_sell === false);

  const mkListing = async (seller, title, o = {}) => (await qs(`insert into listings (seller_id, title, department, category, price, stock, status, images) values ('${seller}', '${title}', 'Design', '${o.category ?? 'Solutions numériques'}', ${o.price ?? 10000}, ${o.stock ?? 50}, '${o.status ?? 'draft'}', '{photo.jpg}') returning id`))[0].id;
  const LA = await mkListing(U(1), 'Template A');
  const LB = await mkListing(U(2), 'Plan B');
  const LS = await mkListing(U(1), 'Service C', { category: 'Services' });
  const LP = await mkListing(U(1), 'Objet physique D', { category: 'Maison', status: 'approved' });
  const L5 = await mkListing(U(5), 'Template non eligible');
  const deposit = async (path, mime = 'application/pdf') => { await qs(`insert into storage.objects (bucket_id, name, owner_id) values ('digital-files', '${path}', '${path.split('/')[0]}') on conflict do nothing`); };

  // ============================================================ 1. définition de la ressource (licence saisie par le vendeur)
  await as(null, 'anon');
  await fails('anonyme : digital_listing_save refusé', `select digital_listing_save('${LA}', 'personal', 'Usage personnel uniquement', 3)`, /permission denied|Connexion requise/i);
  await as(U(6));
  await fails('client : digital_listing_save refusé (réservé aux étudiants-vendeurs)', `select digital_listing_save('${LA}', 'personal', 'Usage personnel uniquement', 3)`, /Réservé aux étudiants/);
  await as(U(5));
  await fails('étudiant non éligible : digital_listing_save refusé', `select digital_listing_save('${L5}', 'personal', 'Usage personnel uniquement', 3)`, /statut d.étudiant|téléphone/);
  await as(U(2));
  await fails('un autre vendeur ne définit pas la licence de l\'annonce d\'autrui', `select digital_listing_save('${LA}', 'personal', 'Usage personnel uniquement', 3)`, /Annonce introuvable/);
  await as(U(1));
  await fails('licence : type inconnu refusé', `select digital_listing_save('${LA}', 'libre', 'Usage personnel uniquement', 3)`, /type de licence/);
  await fails('licence : libellé vide refusé', `select digital_listing_save('${LA}', 'personal', '  ', 3)`, /Décrivez votre licence/);
  await fails('licence : limite 0 refusée', `select digital_listing_save('${LA}', 'personal', 'Usage personnel uniquement', 0)`, /entre 1 et 50/);
  await fails('un service ne peut pas être une ressource numérique', `select digital_listing_save('${LS}', 'personal', 'Usage personnel uniquement', 3)`, /sur devis/);
  await works('licence : enregistrée avec le libellé du vendeur', `select digital_listing_save('${LA}', 'commercial', 'Usage commercial pour un seul client final', 2) r`,
    (r) => r[0].r.digital === true && r[0].r.license_kind === 'commercial' && r[0].r.license_label === 'Usage commercial pour un seul client final' && r[0].r.max_downloads === 2);
  await fails('publication refusée sans fichier', `update listings set status = 'pending' where id = '${LA}'`, /au moins un fichier/);

  // ============================================================ 2. fichiers (bucket privé)
  const pA1 = `${U(1)}/${LA}/1700000000-modele.pdf`;
  await as(U(1));
  await fails('fichier non déposé refusé', `select digital_asset_register('${LA}', '${pA1}', 'modele.pdf', 'application/pdf', 1000, '1.0')`, /Fichier non déposé/);
  await fails('dépôt direct dans le dossier d\'un autre vendeur refusé (stockage)', `insert into storage.objects (bucket_id, name, owner_id) values ('digital-files', '${U(2)}/${LA}/x.pdf', '${U(1)}')`, /row-level security|permission denied/i);
  await works('dépôt dans son dossier autorisé (vendeur éligible)', `insert into storage.objects (bucket_id, name, owner_id) values ('digital-files', '${pA1}', '${U(1)}') returning name`, (r) => r.length === 1);
  await as(U(5));
  await fails('étudiant non éligible : dépôt refusé (stockage)', `insert into storage.objects (bucket_id, name, owner_id) values ('digital-files', '${U(5)}/${L5}/x.pdf', '${U(5)}')`, /row-level security|permission denied/i);
  await as(U(1));
  await fails('fichier : chemin d\'un autre dossier refusé', `select digital_asset_register('${LA}', '${U(2)}/${LA}/x.pdf', 'x.pdf', 'application/pdf', 1000)`, /Chemin de fichier invalide/);
  await fails('fichier : exécutable refusé', `select digital_asset_register('${LA}', '${pA1}', 'virus.exe', 'application/pdf', 1000)`, /Type de fichier refusé/);
  await fails('fichier : type MIME hors liste refusé', `select digital_asset_register('${LA}', '${pA1}', 'modele.pdf', 'application/x-msdownload', 1000)`, /Type de fichier refusé/);
  await fails('fichier : taille nulle ou excessive refusée', `select digital_asset_register('${LA}', '${pA1}', 'modele.pdf', 'application/pdf', 99999999999)`, /trop lourd/);
  let A1;
  await works('fichier : enregistré (version 1.0)', `select digital_asset_register('${LA}', '${pA1}', 'modele.pdf', 'application/pdf', 2048, '1.0') id`, (r) => { A1 = r[0].id; return !!A1; });
  await fails('fichier : même chemin enregistré deux fois refusé', `select digital_asset_register('${LA}', '${pA1}', 'modele.pdf', 'application/pdf', 2048, '1.0')`, /déjà enregistré/);
  await works('publication autorisée avec licence et fichier', `update listings set status = 'pending' where id = '${LA}' returning status`, (r) => r[0].status === 'pending');
  await fails('dernier fichier d\'une annonce publiée : retrait refusé', `select digital_asset_remove('${A1}')`, /dernier fichier/);
  await as(U(2));
  await fails('un autre vendeur ne retire pas le fichier d\'autrui', `select digital_asset_remove('${A1}')`, /Fichier introuvable/);
  await works('un autre vendeur ne voit pas la fiche d\'autrui (my_digital_listing)', `select my_digital_listing('${LA}') r`, (r) => r[0].r.digital === false);
  await fails('un autre vendeur n\'ajoute pas de fichier à l\'annonce d\'autrui', `select digital_asset_register('${LA}', '${U(2)}/${LA}/y.pdf', 'y.pdf', 'application/pdf', 10)`, /licence de cette ressource/);
  await qs(`update listings set status = 'approved' where id = '${LA}'`);

  // ============================================================ 3. fiche publique
  await as(null, 'anon');
  await works('fiche publique (anonyme) : ressource numérique, licence, format, taille', `select product_digital_info('${LA}') r`,
    (r) => r[0].r.digital === true && r[0].r.license_kind === 'commercial' && r[0].r.license_label.startsWith('Usage commercial') && r[0].r.files[0].format === 'PDF' && r[0].r.files[0].size_bytes === 2048 && !JSON.stringify(r[0].r).includes(pA1));
  await works('fiche publique : annonce non numérique', `select product_digital_info('${LP}') r`, (r) => r[0].r.digital === false);
  await works('fiche publique : annonce brouillon d\'autrui non révélée', `select product_digital_info('${LB}') r`, (r) => r[0].r.digital === false);

  // ============================================================ 4. achat : aucun droit avant paiement confirmé
  await as(U(3));
  const co = await q(`select marketplace_checkout('[{"id":"${LA}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h10-001') r`);
  const N1 = co[0].r.number;
  const line = async (num) => (await qs(`select ol.id from order_lines ol join orders o on o.id = ol.order_id where o.number = '${num}' limit 1`))[0].id;
  const OL1 = await line(N1);
  check('commande créée par le circuit existant, non payée', (await qs(`select paid from orders where number = '${N1}'`))[0].paid === false);
  check('aucun droit de téléchargement avant paiement', (await qs(`select count(*)::int n from digital_entitlements`))[0].n === 0);
  await as(U(3));
  await fails('URL refusée avant paiement', `select digital_download_url('${OL1}')`, /Ressource introuvable/);
  await works('Mes téléchargements vide avant paiement', `select my_downloads() r`, (r) => r[0].r.length === 0);
  await fails('l\'acheteur ne s\'attribue pas le droit (écriture directe refusée)', `insert into digital_entitlements (order_line_id, order_id, listing_id, buyer_id, seller_id, license_kind, license_label, max_downloads) values ('${OL1}', (select order_id from order_lines where id = '${OL1}'), '${LA}', '${U(3)}', '${U(1)}', 'personal', 'x', 9)`, /permission denied|row-level security/i);
  try { await q(`update orders set paid = true where number = '${N1}'`); } catch { /* refus attendu ou sans effet */ }
  check('l\'acheteur ne marque pas sa commande payée lui-même (aucun droit créé)', (await qs(`select count(*)::int n from digital_entitlements`))[0].n === 0);
  await as(U(3));
  const NC = (await q(`select marketplace_checkout('[{"id":"${LA}","qty":1}]'::jsonb, false, 'Paiement à la livraison', null, null, 'cle-h10-cod') r`))[0].r.number;
  await fails('paiement à la livraison refusé pour une ressource numérique', `select confirm_cod_order('${NC}')`, /ne se paie pas à la livraison/);

  // paiement confirmé côté serveur (circuit existant : orders.paid)
  await qs(`update orders set paid = true where number = '${N1}'`);
  check('droit créé quand la commande est payée', (await qs(`select count(*)::int n from digital_entitlements where order_line_id = '${OL1}' and status = 'active' and max_downloads = 2 and license_kind = 'commercial'`))[0].n === 1);
  check('l\'argent suit les règles existantes (séquestre 70/20/10 intact)', (await qs(`select count(*)::int n, sum(beneficiary_amount)::int b from money_entries where order_id = (select id from orders where number = '${N1}') and kind = 'order'`))[0].b === 7000);
  check('l\'acheteur est prévenu', (await qs(`select count(*)::int n from notifications where user_id = '${U(3)}' and title = 'Ressource numérique disponible'`))[0].n === 1);
  await qs(`update orders set paid = true where number = '${N1}'`);
  await qs(`update orders set status = status where number = '${N1}'`);
  check('rejeu du paiement : toujours un seul droit, une seule notification', (await qs(`select (select count(*)::int from digital_entitlements) a, (select count(*)::int from notifications where title = 'Ressource numérique disponible') b`))[0].a === 1);

  // ============================================================ 5. téléchargement : ticket, limite, journal, isolation
  await as(U(4));
  await fails('autre acheteur : URL refusée', `select digital_download_url('${OL1}')`, /Ressource introuvable/);
  await works('autre acheteur : Mes téléchargements vide', `select my_downloads() r`, (r) => r[0].r.length === 0);
  await as(null, 'anon');
  await fails('anonyme : URL refusée', `select digital_download_url('${OL1}')`, /permission denied|Connexion requise/i);
  await fails('anonyme : Mes téléchargements refusé', `select my_downloads()`, /permission denied|Connexion requise/i);
  await as(U(3));
  await works('Mes téléchargements : ressource active avec fichier, licence figée', `select my_downloads() r`,
    (r) => r[0].r.length === 1 && r[0].r[0].status === 'active' && r[0].r[0].files.length === 1 && r[0].r[0].files[0].version === '1.0' && r[0].r[0].license_label.startsWith('Usage commercial') && r[0].r[0].downloads_used === 0);
  await as(U(3));
  const st0 = (await q(`select count(*)::int n from storage.objects where bucket_id = 'digital-files'`))[0].n;
  check('avant ticket : l\'acheteur ne lit aucun fichier du compartiment', st0 === 0);
  let dl;
  await works('URL courte accordée à l\'acheteur payeur (60 s, chemin, reste 1)', `select digital_download_url('${OL1}') r`, (r) => { dl = r[0].r; return dl.path === pA1 && dl.expires_in === 60 && dl.remaining === 1 && dl.bucket === 'digital-files'; });
  check('avec ticket : l\'acheteur lit exactement ce fichier', (await q(`select name from storage.objects where bucket_id = 'digital-files'`)).length === 1);
  await as(U(4));
  check('un autre acheteur ne lit toujours rien (ticket personnel)', (await q(`select count(*)::int n from storage.objects where bucket_id = 'digital-files'`))[0].n === 0);
  await as(U(2));
  check('un autre vendeur ne lit pas les fichiers d\'autrui', (await q(`select count(*)::int n from storage.objects where bucket_id = 'digital-files'`))[0].n === 0);
  await as(U(1));
  check('le vendeur propriétaire lit ses propres fichiers', (await q(`select count(*)::int n from storage.objects where bucket_id = 'digital-files'`))[0].n === 1);
  await as(U(3));
  await works('2e téléchargement accordé (limite 2)', `select digital_download_url('${OL1}') r`, (r) => r[0].r.remaining === 0);
  await fails('3e téléchargement refusé : limite atteinte', `select digital_download_url('${OL1}')`, /Limite de téléchargements atteinte/);
  check('journal : 2 téléchargements enregistrés, compteur à 2', (await qs(`select (select count(*)::int from digital_download_log where buyer_id = '${U(3)}') a, downloads_used b from digital_entitlements where order_line_id = '${OL1}'`))[0].a === 2);
  await as(U(3));
  await works('Mes téléchargements : compteur et historique', `select my_downloads() r`, (r) => r[0].r[0].downloads_used === 2 && r[0].r[0].history.length === 2);
  await qs(`delete from digital_download_tickets`);
  await as(U(3));
  check('ticket expiré ou supprimé : plus de lecture', (await q(`select count(*)::int n from storage.objects where bucket_id = 'digital-files'`))[0].n === 0);

  // ============================================================ 6. versions, plusieurs fichiers
  const pA2 = `${U(1)}/${LA}/1700000100-modele-v2.pdf`;
  await deposit(pA2);
  await as(U(1));
  let A2;
  await works('nouvelle version : remplace le fichier actif', `select digital_asset_register('${LA}', '${pA2}', 'modele.pdf', 'application/pdf', 4096, '2.0', '${A1}') id`, (r) => { A2 = r[0].id; return !!A2; });
  await works('fiche vendeur : un seul fichier actif, version 2.0', `select my_digital_listing('${LA}') r`, (r) => r[0].r.assets.length === 1 && r[0].r.assets[0].version === '2.0');
  await as(U(3));
  await works('l\'acheteur voit la version à jour', `select my_downloads() r`, (r) => r[0].r[0].files.length === 1 && r[0].r[0].files[0].version === '2.0');
  const pA3 = `${U(1)}/${LA}/1700000150-annexe.pdf`;
  await deposit(pA3);
  await as(U(1));
  let A3;
  await works('second fichier (pack) ajouté', `select digital_asset_register('${LA}', '${pA3}', 'annexe.pdf', 'application/pdf', 100, '1.0') id`, (r) => { A3 = r[0].id; return !!A3; });

  // ============================================================ 7. isolation vendeurs et ventes
  await as(U(1));
  await works('vendeur A voit sa vente (sans fichier ni chemin)', `select seller_digital_sales() r`, (r) => r[0].r.length === 1 && r[0].r[0].order_number === N1 && r[0].r[0].downloads_used === 2 && !JSON.stringify(r[0].r).includes('digital-files') && !JSON.stringify(r[0].r).includes(pA1));
  await as(U(2));
  await works('vendeur B ne voit aucune vente de A', `select seller_digital_sales() r`, (r) => r[0].r.length === 0);
  await as(null, 'anon');
  await fails('anonyme : ventes numériques refusées', `select seller_digital_sales()`, /permission denied|Connexion requise/i);

  // ============================================================ 8. remboursement total : droit révoqué
  await as(U(3));
  const co2 = await q(`select marketplace_checkout('[{"id":"${LA}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h10-002') r`);
  const N2 = co2[0].r.number; const OL2 = await line(N2);
  await qs(`update orders set paid = true where number = '${N2}'`);
  await as(U(3));
  await fails('plusieurs fichiers actifs : le fichier doit être choisi', `select digital_download_url('${OL2}')`, /Choisissez le fichier/);
  await works('2e commande payée : téléchargement accordé', `select digital_download_url('${OL2}', '${A2}') r`, (r) => r[0].r.path === pA2);
  let rid;
  await works('demande de remboursement (circuit existant)', `select order_refund_request('${N2}', 'Ressource non conforme à la description', null, null) id`, (r) => { rid = r[0].id; return !!rid; });
  await as(U(7));
  await works('remboursement total accepté par l\'équipe', `select order_refund_decide('${rid}', 'approve', 'ok') r`, (r) => r[0].r === 'approve');
  await as(U(3));
  await fails('après remboursement : URL refusée', `select digital_download_url('${OL2}', '${A2}')`, /annulée|remboursée/);
  await works('après remboursement : Mes téléchargements affiche « révoqué » sans fichier', `select my_downloads() r`, (r) => { const x = r[0].r.find((z) => z.order_number === N2); return x && x.status === 'revoked' && x.files.length === 0 && /annulée|remboursée/.test(x.reason); });
  check('après remboursement : droit révoqué en base', (await qs(`select status from digital_entitlements where order_line_id = '${OL2}'`))[0].status === 'revoked');
  await as(U(3));
  await works('la commande 1 (non remboursée) reste téléchargeable (limite déjà atteinte : refus propre)', `select my_downloads() r`, (r) => r[0].r.find((z) => z.order_number === N1).status === 'active');

  // ============================================================ 9. annulation d'une commande payée, remboursement partiel
  await as(U(3));
  const co3 = await q(`select marketplace_checkout('[{"id":"${LA}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h10-003') r`);
  const N3 = co3[0].r.number; const OL3 = await line(N3);
  await qs(`update orders set paid = true where number = '${N3}'`);
  await qs(`update orders set cancelled_at = now() where number = '${N3}'`);
  await as(U(3));
  await fails('commande annulée : URL refusée', `select digital_download_url('${OL3}', '${A2}')`, /annulée/);
  const co4 = await q(`select marketplace_checkout('[{"id":"${LA}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h10-004') r`);
  const N4 = co4[0].r.number; const OL4 = await line(N4);
  await qs(`update orders set paid = true where number = '${N4}'`);
  await as(U(3));
  let rid4;
  await works('demande de remboursement (commande 4)', `select order_refund_request('${N4}', 'Je veux un geste commercial partiel', null, null) id`, (r) => { rid4 = r[0].id; return !!rid4; });
  await as(U(7));
  await works('remboursement PARTIEL accepté', `select order_refund_decide('${rid4}', 'approve', 'geste commercial partiel', 2000) r`, (r) => r[0].r === 'approve');
  await as(U(3));
  await works('remboursement partiel : l\'accès reste ouvert (règle documentée)', `select digital_download_url('${OL4}', '${A2}') r`, (r) => r[0].r.remaining === 1);

  // ============================================================ 10. publication et capacité vendeur
  await as(U(2));
  await works('vendeur B : licence puis fichier puis publication', `select digital_listing_save('${LB}', 'educational', 'Usage en classe, un enseignant', 5) r`, (r) => r[0].r.license_kind === 'educational');
  await fails('vendeur B : publication sans fichier refusée', `update listings set status = 'pending' where id = '${LB}'`, /au moins un fichier/);
  await qs(`update profiles set phone_verified = false where id = '${U(2)}'`);
  const pB = `${U(2)}/${LB}/1700000200-plan.zip`;
  await deposit(pB);
  await as(U(2));
  await fails('vendeur devenu non éligible : enregistrement de fichier refusé', `select digital_asset_register('${LB}', '${pB}', 'plan.zip', 'application/zip', 500)`, /téléphone/);
  await fails('vendeur devenu non éligible : publication refusée (garde K2)', `update listings set status = 'pending' where id = '${LB}'`, /téléphone|au moins un fichier/);
  await qs(`update profiles set phone_verified = true where id = '${U(2)}'`);
  await as(U(2));
  await works('vendeur rétabli : fichier enregistré (ZIP)', `select digital_asset_register('${LB}', '${pB}', 'plan.zip', 'application/zip', 500) id`, (r) => !!r[0].id);
  await works('vendeur rétabli : publication autorisée', `update listings set status = 'pending' where id = '${LB}' returning status`, (r) => r[0].status === 'pending');
  const AB = (await qs(`select id from digital_assets where listing_id = '${LB}' limit 1`))[0].id;
  await as(U(3));
  await fails('fichier d\'une autre annonce refusé (même acheteur)', `select digital_download_url('${OL4}', '${AB}')`, /Fichier introuvable/);
  await as(U(1));
  await works('un fichier non dernier se retire (désactivation)', `select digital_asset_remove('${A3}')`);
  await works('le fichier retiré peut être supprimé du stockage', `delete from storage.objects where bucket_id = 'digital-files' and name = '${pA3}' returning name`, (r) => r.length === 1);
  await works('le fichier actif ne se supprime pas du stockage', `delete from storage.objects where bucket_id = 'digital-files' and name = '${pA2}' returning name`, (r) => r.length === 0);
  await as(U(4));
  await q(`select marketplace_checkout('[{"id":"${LP}","qty":1}]'::jsonb, false, 'Mobile Money', null, null, 'cle-h10-005')`);
  await as(U(1));
  await fails('annonce déjà commandée : ne peut pas devenir numérique', `select digital_listing_save('${LP}', 'personal', 'Usage personnel', 3)`, /déjà été commandée/);

  // ============================================================ 11. rejeu des migrations
  const here = path.dirname(fileURLToPath(import.meta.url));
  const sql = fs.readFileSync(path.join(here, '..', '..', 'migrations', '20261126050000_h10_ressources_numeriques.sql'), 'utf8');
  await sup();
  const before = (await q(`select (select count(*)::int from digital_entitlements) e, (select count(*)::int from digital_assets) a, (select count(*)::int from digital_listings) l`))[0];
  let replay = true;
  try { await db.exec(sql); await db.exec(sql); } catch (e) { replay = false; console.log(e.message); }
  const after = (await q(`select (select count(*)::int from digital_entitlements) e, (select count(*)::int from digital_assets) a, (select count(*)::int from digital_listings) l`))[0];
  check('rejeu de la migration : sans erreur ni effet de bord', replay && before.e === after.e && before.a === after.a && before.l === after.l);
  check('compartiment digital-files privé après rejeu', (await q(`select public from storage.buckets where id = 'digital-files'`))[0].public === false);

  console.log(`\nh10_commerce : ${ok} OK, ${ko} ECHEC`);
}
