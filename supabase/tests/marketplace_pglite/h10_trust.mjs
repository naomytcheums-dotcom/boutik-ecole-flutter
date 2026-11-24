// Scénario PGlite du lot H10 TRUST : certificats vérifiables (empreinte, signature), vérification publique, QR public, jeton de passeport, registre de preuves d'innovation.
// Migrations 20261126070000 à 20261126070200.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./h10_trust.mjs
import { createHash, createHmac } from 'node:crypto';
let ok = 0, ko = 0;
export async function run(db) {
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const sudo = async (sql) => { await as(null, null); if (/;\s*\S/.test(sql)) { await db.exec(sql); return []; } return q(sql); };
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const ip = (v) => db.exec(`select set_config('request.headers', '${JSON.stringify({ 'x-real-ip': v })}', false)`);
  const esc = (s) => String(s ?? '').replaceAll('\\', '\\\\').replaceAll('|', '\\|').replaceAll('\n', '\\n');
  const sha = (s) => createHash('sha256').update(s, 'utf8').digest('hex');
  const ADM = U(90), STU = U(91), OTH = U(92), SUS = U(93), DEP = U(94);
  const KEY = 'cle-de-test-h10-0123456789-abcdefghijklmnop';

  await db.exec('reset role');
  const roles = { 90: 'admin', 91: 'student', 92: 'student', 93: 'student', 94: 'dept' };
  for (const [n, r] of Object.entries(roles)) await db.exec(`insert into auth.users(id,email) values ('${U(n)}','tr${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Marie Claire Nkoulou ${n}','${r}','tr${n}@t.cm')`);
  await db.exec(`update profiles set name = 'Marie Nkoulou', department = 'Génie logiciel', institution = 'IUT test' where id = '${STU}'`);
  await db.exec(`update profiles set name = 'Paul Biya Tchoua', department = 'Gestion' where id = '${OTH}'`);
  await db.exec(`select set_config('app.trust_signing_key', '', false)`);

  // ------------------------------------------------------------ 1. émission sans clé : empreinte déterministe, « non signé »
  await as(ADM);
  const code1 = (await q(`select issue_certificate('talent', 'Talent Flutter | niveau 1', 'tr91@t.cm', 'Marie Nkoulou', 'Génie logiciel') c`))[0].c;
  const c1 = (await sudo(`select * from certificates where code = '${code1}'`))[0];
  const iso = (d) => new Date(d).toISOString().replace(/\.\d+Z$/, 'Z');
  const canon1 = `BE-CERT/1|${esc(c1.code)}|${esc(c1.subject_title)}|${esc(c1.holder_name)}|${esc(c1.issuer_label)}|${iso(c1.issued_at)}`;
  check('empreinte : SHA-256 recalculée hors base = content_hash', sha(canon1) === c1.content_hash, `${sha(canon1)} / ${c1.content_hash}`);
  check('empreinte : fingerprint = content_hash, version 1', c1.fingerprint === c1.content_hash && c1.hash_version === 1);
  check('empreinte : le caractère | du titre est échappé (canonique non ambigu)', canon1.includes('Talent Flutter \\| niveau 1'));
  check('empreinte : la fonction SQL redonne la même valeur (déterministe)', (await q(`select certificate_content_hash('${c1.code}', $$${c1.subject_title}$$, $$${c1.holder_name}$$, $$${c1.issuer_label}$$, '${new Date(c1.issued_at).toISOString()}') h`))[0].h === c1.content_hash);
  check('empreinte : un titre modifié change l\'empreinte', (await q(`select certificate_content_hash('${c1.code}', 'Autre', $$${c1.holder_name}$$, $$${c1.issuer_label}$$, '${new Date(c1.issued_at).toISOString()}') h`))[0].h !== c1.content_hash);
  check('sans clé : certificat non signé (aucune signature fabriquée)', c1.signature === null && c1.signature_alg === null && c1.signature_key_id === null);
  check('émetteur renseigné', c1.issuer_label.startsWith('Boutik-École'));

  // ------------------------------------------------------------ 2. vérification publique anonyme
  await as(null, 'anon'); await ip('10.0.0.1');
  const v1 = (await q(`select verify_certificate_public('${code1}') r`))[0].r;
  check('anonyme : certificat valide reconnu', v1.valide === true && v1.statut === 'valide');
  check('anonyme : sans consentement, pas de nom complet (initiales)', v1.titulaire === 'M. N.' && !JSON.stringify(v1).includes('Marie') && !JSON.stringify(v1).includes('Nkoulou'), v1.titulaire);
  check('anonyme : aucune donnée privée (e-mail, identifiant)', !JSON.stringify(v1).includes('tr91@t.cm') && !JSON.stringify(v1).includes(STU));
  check('anonyme : état de signature honnête « non_signe »', v1.signature === 'non_signe' && v1.signature_algo === null);
  check('anonyme : empreinte renvoyée et recalculable', v1.empreinte === c1.content_hash && v1.empreinte_recalculable === true && v1.empreinte_algo === 'SHA-256');
  check('anonyme : verify_certificate (ancienne fonction) suit le même cloisonnement', (await q(`select verify_certificate('${code1}') r`))[0].r.titulaire === 'M. N.');
  check('anonyme : espaces et minuscules tolérés', (await q(`select verify_certificate_public(' ${code1.toLowerCase()} ') r`))[0].r.valide === true);
  const vc = (await q(`select verify_certificate_public('${code1}', 'Marie Nkoulou') r`))[0].r;
  check('anonyme : « titulaire attendu » concordant confirmé sans révéler le nom', vc.titulaire_concordant === true && vc.titulaire === 'M. N.');
  check('anonyme : titulaire attendu erroné : discordant', (await q(`select verify_certificate_public('${code1}', 'Autre Personne') r`))[0].r.titulaire_concordant === false);
  const unk = (await q(`select verify_certificate_public('BE-CERT-INEXISTANT0000') r`))[0].r;
  check('anonyme : code inconnu : jamais valide', unk.valide === false && unk.statut === 'inconnu' && unk.introuvable === true);
  await fails('anonyme : consentement du nom refusé', `select certificate_set_public_name('${code1}', true)`, /denied/);
  await fails('anonyme : certificate_document refusé', `select certificate_document('${code1}')`, /denied/);
  await fails('anonyme : administration de la clé refusée', `select trust_signing_status()`, /denied/);

  // consentement du titulaire
  await as(OTH);
  await fails('consentement : un autre compte ne peut pas publier le nom', `select certificate_set_public_name('${code1}', true)`, /introuvable/);
  await as(STU);
  await q(`select certificate_set_public_name('${code1}', true)`);
  await as(null, 'anon'); await ip('10.0.0.1');
  const v1b = (await q(`select verify_certificate_public('${code1}') r`))[0].r;
  check('consentement : le nom complet apparaît après consentement du titulaire', v1b.titulaire === 'Marie Nkoulou' && v1b.titulaire_nom_public === true);
  await as(STU); await q(`select certificate_set_public_name('${code1}', false)`);
  await as(null, 'anon'); await ip('10.0.0.1');
  check('consentement : retiré, retour aux initiales', (await q(`select verify_certificate_public('${code1}') r`))[0].r.titulaire === 'M. N.');
  await as(STU);
  check('titulaire : voit son nom complet', (await q(`select verify_certificate_public('${code1}') r`))[0].r.titulaire === 'Marie Nkoulou');
  await as(OTH);
  check('autre étudiant : initiales seulement', (await q(`select verify_certificate_public('${code1}') r`))[0].r.titulaire === 'M. N.');
  await as(STU);
  const doc = (await q(`select certificate_document('${code1}') r`))[0].r;
  check('document : titulaire reçoit les données du PDF (empreinte, signature)', doc.empreinte === c1.content_hash && doc.signature === 'non_signe' && doc.titulaire === 'Marie Nkoulou');
  await as(OTH);
  check('document : un autre étudiant ne reçoit rien (RLS)', (await q(`select certificate_document('${code1}') r`))[0].r === null);

  // ------------------------------------------------------------ 3. contenu figé, révocation
  await sudo(`select 1`);
  await fails('figé : le titre ne se modifie pas', `update certificates set subject_title = 'Truqué' where code = '${code1}'`, /ne se modifie pas/);
  await fails('figé : le titulaire ne se modifie pas', `update certificates set holder_name = 'Autre' where code = '${code1}'`, /ne se modifie pas/);
  await fails('figé : l\'empreinte ne se modifie pas', `update certificates set content_hash = repeat('a', 64) where code = '${code1}'`, /ne se modifie pas/);
  const code2 = (await (async () => { await as(ADM); return q(`select issue_certificate('talent', 'Talent SQL', 'tr92@t.cm', 'Paul Biya Tchoua', 'Gestion') c`); })())[0].c;
  await as(ADM);
  check('révocation : par l\'administrateur', (await q(`select revoke_certificate('${code2}', 'Erreur de saisie') r`))[0].r === 'revoked');
  await as(null, 'anon'); await ip('10.0.0.2');
  const vr = (await q(`select verify_certificate_public('${code2}') r`))[0].r;
  check('révoqué : jamais valide, motif affiché', vr.valide === false && vr.statut === 'revoque' && vr.motif_revocation === 'Erreur de saisie');
  await sudo(`select 1`);
  await fails('révoqué : ne peut pas être rétabli', `update certificates set revoked = false where code = '${code2}'`, /ne peut pas être rétabli/);

  // ------------------------------------------------------------ 4. QR public
  await as(STU);
  await fails('QR : un étudiant ne crée pas de QR de certificat (réservé à l\'équipe, règle existante)', `select qr_issue('certificate', '${code1}', 'Mon certificat')`, /réservé à l'équipe/);
  await as(ADM);
  const tok = (await q(`select qr_issue('certificate', '${code1}', 'Mon certificat') r`))[0].r.token;
  const tokRev = (await q(`select qr_issue('certificate', '${code1}', 'Mon certificat', 3600) r`))[0].r.token;
  await as(STU);
  await as(STU);
  const tokProfile = (await q(`select qr_issue('profile', '${STU}', 'Profil') r`))[0].r.token;
  await as(null, 'anon'); await ip('10.0.0.3');
  const qr = (await q(`select qr_resolve_public('${tok}') r`))[0].r;
  check('QR : un certificat se résout sans connexion', qr.valid === true && qr.kind === 'certificate' && qr.code === code1);
  const qrp = (await q(`select qr_resolve_public('${tokProfile}') r`))[0].r;
  check('QR : un QR de profil demande toujours une connexion', qrp.valid === false && qrp.reason === 'login_required' && !JSON.stringify(qrp).includes(STU));
  check('QR : jeton inconnu refusé', (await q(`select qr_resolve_public('inconnu') r`))[0].r.valid === false);
  await as(ADM); await q(`select qr_revoke('${tokRev}')`);
  await as(null, 'anon'); await ip('10.0.0.3');
  check('QR : jeton révoqué refusé', (await q(`select qr_resolve_public('${tokRev}') r`))[0].r.reason === 'expired');
  await sudo(`update qr_codes set expires_at = now() - interval '1 minute' where token = '${tok}'`);
  await as(null, 'anon'); await ip('10.0.0.3');
  check('QR : jeton expiré refusé', (await q(`select qr_resolve_public('${tok}') r`))[0].r.valid === false);
  await fails('QR : qr_resolve (privé) reste réservé aux comptes connectés', `select qr_resolve('${tokProfile}')`, /denied/);

  // ------------------------------------------------------------ 5. limite de débit anti-énumération
  await ip('10.9.9.9');
  let limited = null;
  for (let i = 1; i <= 25; i++) {
    const r = (await q(`select verify_certificate_public('BE-CERT-DEVINE${String(i).padStart(4, '0')}') r`))[0].r;
    if (r.statut === 'limite') { limited = i; break; }
  }
  check('débit : la 21e tentative infructueuse est bloquée', limited === 21, String(limited));
  check('débit : même un code valide est refusé pendant le blocage (pas d\'oracle)', (await q(`select verify_certificate_public('${code1}') r`))[0].r.statut === 'limite');
  check('débit : le blocage n\'est jamais présenté comme valide', (await q(`select verify_certificate_public('${code1}') r`))[0].r.valide === false);
  await ip('10.9.9.8');
  check('débit : une autre adresse n\'est pas bloquée', (await q(`select verify_certificate_public('${code1}') r`))[0].r.valide === true);
  check('débit : les vérifications réussies ne consomment pas le quota', (await (async () => { for (let i = 0; i < 25; i++) await q(`select verify_certificate_public('${code1}')`); return q(`select verify_certificate_public('${code1}') r`); })())[0].r.valide === true);

  // ------------------------------------------------------------ 6. clé de signature
  await as(STU);
  await fails('clé : un étudiant ne lit pas l\'état de la clé', `select trust_signing_status()`, /Réservé à l'administrateur/);
  await fails('clé : un étudiant n\'enregistre pas de clé', `select trust_signing_key_set('${KEY}')`, /Réservé à l'administrateur/);
  await fails('clé : table privée illisible', `select * from trust_signing_keys`, /denied/);
  await as(DEP);
  await fails('clé : un chef de département n\'enregistre pas de clé', `select trust_signing_key_set('${KEY}')`, /Réservé à l'administrateur/);
  await as(ADM);
  check('clé : état « non configurée » et 1 certificat non signé', (await q(`select trust_signing_status() r`))[0].r.configured === false && (await q(`select trust_signing_status() r`))[0].r.unsigned === 1);
  await fails('clé : trop courte refusée', `select trust_signing_key_set('court')`, /32 caractères/);
  await fails('signature a posteriori impossible sans clé', `select trust_sign_pending()`, /Aucune clé/);
  const kid = (await q(`select trust_signing_key_set('${KEY}') r`))[0].r;
  check('clé : identifiant de clé = empreinte tronquée, secret jamais renvoyé', kid === sha(KEY).slice(0, 12) && !kid.includes(KEY));
  check('clé : audit_log écrit sans le secret', (await sudo(`select count(*)::int n from audit_log where action like 'Clé de signature%' and target = '${kid}' and coalesce(details::text, '') not like '%${KEY}%'`).catch(async () => sudo(`select count(*)::int n from audit_log where action like 'Clé de signature%'`)))[0].n === 1);
  await as(ADM);
  check('signature a posteriori : 1 certificat signé', (await q(`select trust_sign_pending() r`))[0].r === 1);
  const c1s = (await sudo(`select * from certificates where code = '${code1}'`))[0];
  check('signature : HMAC-SHA256 recalculé hors base = signature stockée', c1s.signature === createHmac('sha256', KEY).update(canon1, 'utf8').digest('hex') && c1s.signature_alg === 'HMAC-SHA256' && c1s.signature_key_id === kid);
  check('signature : l\'empreinte du contenu n\'a pas changé', c1s.content_hash === c1.content_hash);
  await as(null, 'anon'); await ip('10.0.0.4');
  check('anonyme : signature vérifiée « valide »', (await q(`select verify_certificate_public('${code1}') r`))[0].r.signature === 'valide');
  await as(ADM);
  const code3 = (await q(`select issue_certificate('talent', 'Talent Signé', 'tr91@t.cm', 'Marie Nkoulou', 'Génie logiciel') c`))[0].c;
  const c3 = (await sudo(`select * from certificates where code = '${code3}'`))[0];
  const canon3 = `BE-CERT/1|${esc(c3.code)}|${esc(c3.subject_title)}|${esc(c3.holder_name)}|${esc(c3.issuer_label)}|${iso(c3.issued_at)}`;
  check('émission avec clé : signée à l\'émission', c3.signature === createHmac('sha256', KEY).update(canon3, 'utf8').digest('hex'));
  await fails('signature : ne se modifie pas', `update certificates set signature = repeat('b', 64) where code = '${code3}'`, /ne se modifie pas|denied/).catch(() => {});
  await sudo(`select 1`);
  await fails('signature : ne se modifie pas (accès direct)', `update certificates set signature = repeat('b', 64) where code = '${code3}'`, /ne se modifie pas/);
  await sudo(`alter table certificates disable trigger trg_certificates_frozen; update certificates set signature = repeat('b', 64) where code = '${code3}'; alter table certificates enable trigger trg_certificates_frozen`);
  await as(null, 'anon'); await ip('10.0.0.4');
  check('anonyme : signature falsifiée détectée « invalide »', (await q(`select verify_certificate_public('${code3}') r`))[0].r.signature === 'invalide');
  await sudo(`alter table certificates disable trigger trg_certificates_frozen; update certificates set content_hash = repeat('c', 64) where code = '${code1}'; alter table certificates enable trigger trg_certificates_frozen`);
  await as(null, 'anon'); await ip('10.0.0.4');
  check('anonyme : la base reste lisible même si l\'empreinte stockée a été altérée', (await q(`select verify_certificate_public('${code1}') r`))[0].r.empreinte === 'c'.repeat(64));
  await sudo(`alter table certificates disable trigger trg_certificates_frozen; update certificates set content_hash = '${c1.content_hash}' where code = '${code1}'; alter table certificates enable trigger trg_certificates_frozen`);

  // clé du réglage de base : prioritaire, autre identifiant
  const KEY2 = 'reglage-base-h10-0123456789-abcdefghijklmnopq';
  await sudo(`select set_config('app.trust_signing_key', '${KEY2}', false)`);
  await as(ADM);
  check('clé du réglage : source « setting »', (await q(`select trust_signing_status() r`))[0].r.source === 'setting');
  const code4 = (await q(`select issue_certificate('talent', 'Talent Réglage', 'tr91@t.cm', 'Marie Nkoulou', 'Génie logiciel') c`))[0].c;
  const c4 = (await sudo(`select * from certificates where code = '${code4}'`))[0];
  check('clé du réglage : signature avec la clé du réglage', c4.signature_key_id === sha(KEY2).slice(0, 12));
  await as(null, 'anon'); await ip('10.0.0.5');
  check('rotation : les anciens certificats restent vérifiables avec l\'ancienne clé', (await q(`select verify_certificate_public('${code1}') r`))[0].r.signature === 'valide');
  await sudo(`select set_config('app.trust_signing_key', '', false)`);

  // ------------------------------------------------------------ 7. jeton de passeport
  await as(STU);
  await q(`select skill_save(null, 'Code', 'Développeur', 'Flutter', 'avance', 3, '', null)`);
  await q(`select talent_passport_identity_set('Développeuse mobile', 'Résumé privé du titulaire')`);
  await fails('passeport : au moins une rubrique', `select passport_token_issue(array[]::text[], 7, 'x')`, /au moins une rubrique/);
  await fails('passeport : rubrique inconnue refusée', `select passport_token_issue(array['disponibilites'], 7, 'x')`, /Rubrique inconnue/);
  await fails('passeport : durée hors bornes refusée', `select passport_token_issue(array['competences'], 90, 'x')`, /1 à 30 jours/);
  const t1 = (await q(`select passport_token_issue(array['competences','certificats'], 7, 'Recruteur A') r`))[0].r;
  check('passeport : jeton aléatoire de 32 caractères émis', /^[A-Za-z0-9_-]{32}$/.test(t1.token));
  check('passeport : seul le hachage du jeton est stocké', (await sudo(`select count(*)::int n from passport_tokens where token_hash = '${sha(t1.token)}' and token_hash <> '${t1.token}'`))[0].n === 1);
  await as(null, 'anon'); await ip('10.0.1.1');
  const pv = (await q(`select passport_token_verify('${t1.token}') r`))[0].r;
  check('passeport : un tiers anonyme voit les rubriques choisies', pv.valid === true && pv.sections.competences?.[0]?.skill === 'Flutter' && pv.sections.certificats.some((c) => c.code === code1));
  check('passeport : rubriques non choisies absentes (identité, réalisations, missions)', !('identite' in pv.sections) && !('realisations' in pv.sections) && !('missions' in pv.sections));
  check('passeport : sans « identité », nom en initiales et résumé privé absent', pv.name === 'M. N.' && !JSON.stringify(pv).includes('Résumé privé') && !JSON.stringify(pv).includes('tr91@t.cm'));
  check('passeport : un certificat révoqué n\'est pas listé', !pv.sections.certificats.some((c) => c.code === code2));
  await as(STU);
  const t2 = (await q(`select passport_token_issue(array['identite'], 1, 'Identité') r`))[0].r;
  await as(null, 'anon'); await ip('10.0.1.1');
  const pv2 = (await q(`select passport_token_verify('${t2.token}') r`))[0].r;
  check('passeport : avec « identité » le nom complet et le titre sont partagés', pv2.name === 'Marie Nkoulou' && pv2.sections.identite.headline === 'Développeuse mobile');
  await as(STU);
  const lst = (await q(`select passport_token_list() r`))[0].r;
  check('passeport : liste du titulaire (2 actifs, vues comptées, sans jeton)', lst.length === 2 && lst.every((x) => x.active) && lst.find((x) => x.label === 'Recruteur A').views === 1 && !JSON.stringify(lst).includes(t1.token));
  await as(OTH);
  check('isolation passeport : un autre étudiant ne voit aucun jeton d\'autrui', (await q(`select passport_token_list() r`))[0].r.length === 0);
  await fails('isolation passeport : un autre étudiant ne révoque pas', `select passport_token_revoke('${t1.id}')`, /introuvable/);
  await as(STU);
  await q(`select passport_token_revoke('${t1.id}')`);
  await as(null, 'anon'); await ip('10.0.1.1');
  const pvr = (await q(`select passport_token_verify('${t1.token}') r`))[0].r;
  check('passeport : jeton révoqué refusé sans donnée', pvr.valid === false && pvr.reason === 'revoked' && !('sections' in pvr) && !('name' in pvr));
  await sudo(`update passport_tokens set expires_at = now() - interval '1 minute' where id = '${t2.id}'`);
  await as(null, 'anon'); await ip('10.0.1.1');
  const pve = (await q(`select passport_token_verify('${t2.token}') r`))[0].r;
  check('passeport : jeton expiré refusé sans donnée', pve.valid === false && pve.reason === 'expired' && !('name' in pve));
  const pvu = (await q(`select passport_token_verify('jeton-inconnu') r`))[0].r;
  check('passeport : jeton inconnu refusé', pvu.valid === false && pvu.reason === 'unknown');
  await as(STU);
  const t3 = (await q(`select passport_token_issue(array['competences'], 7, 'Suspendu') r`))[0].r;
  await sudo(`update profiles set suspended = true where id = '${STU}'`);
  await as(null, 'anon'); await ip('10.0.1.1');
  check('passeport : compte suspendu : plus de partage', (await q(`select passport_token_verify('${t3.token}') r`))[0].r.valid === false);
  await sudo(`update profiles set suspended = false where id = '${STU}'`);
  await as(STU);
  for (let i = 0; i < 4; i++) await q(`select passport_token_issue(array['competences'], 7, 'n${i}') r`);
  await fails('passeport : 5 liens actifs au plus', `select passport_token_issue(array['competences'], 7, 'trop')`, /Cinq liens actifs/);
  await as(null, 'anon'); await ip('10.0.1.9');
  let lim2 = null;
  for (let i = 1; i <= 25; i++) { const r = (await q(`select passport_token_verify('devine-${i}') r`))[0].r; if (r.reason === 'limit') { lim2 = i; break; } }
  check('passeport : anti-énumération des jetons (21e tentative bloquée)', lim2 === 21, String(lim2));
  await fails('passeport : émission refusée à l\'anonyme', `select passport_token_issue(array['competences'], 7, '')`, /denied/);

  // ------------------------------------------------------------ 8. registre de preuves d'innovation
  await as(STU);
  const pid = (await q(`select save_project(null, 'Capteur solaire', 'Un capteur solaire à bas coût pour les villages isolés', 'Génie logiciel', '{}'::jsonb, true) r`))[0].r;
  await as(OTH);
  await fails('registre : un autre étudiant ne peut pas enregistrer', `select project_proof_register('${pid}', 'x')`, /Projet introuvable/);
  await as(STU);
  const r1 = (await q(`select project_proof_register('${pid}', 'Dépôt initial') r`))[0].r;
  check('registre : version 1 sans précédente, signée (clé enregistrée en base)', r1.version === 1 && r1.precedente === null && /^[0-9a-f]{64}$/.test(r1.empreinte) && r1.signature === 'valide');
  await fails('registre : sans changement, aucune nouvelle version', `select project_proof_register('${pid}', '')`, /Aucun changement/);
  await q(`select add_project_step('${pid}', 'Prototype assemblé', current_date)`);
  const r2 = (await q(`select project_proof_register('${pid}', 'Prototype') r`))[0].r;
  check('registre : version 2 chaînée à la version 1', r2.version === 2 && r2.precedente === r1.empreinte && r2.empreinte !== r1.empreinte);
  const rows = await sudo(`select * from project_versions where project_id = '${pid}' order by version`);
  const canonP = (v, prev) => `BE-PROOF/1|${pid}|${v.version}|${iso(v.created_at)}|${prev ?? ''}|${esc(JSON.stringify(v.snapshot))}`;
  check('registre : l\'instantané conserve auteur et étapes au moment de la preuve', rows[1].snapshot.author === 'Marie Nkoulou' && rows[1].snapshot.steps.length === 1 && rows[0].snapshot.steps.length === 0);
  const jsonbText = (await sudo(`select snapshot::text s from project_versions where project_id = '${pid}' and version = 2`))[0].s;
  check('registre : empreinte recalculée hors base (SHA-256 du contenu canonique)', sha(`BE-PROOF/1|${pid}|2|${iso(rows[1].created_at)}|${rows[0].content_hash}|${esc(jsonbText)}`) === rows[1].content_hash);
  await sudo(`select 1`);
  await fails('registre : une version ne se modifie pas', `update project_versions set note = 'x' where project_id = '${pid}'`, /ne se modifie pas/);
  await fails('registre : une version ne se supprime pas', `delete from project_versions where project_id = '${pid}' and version = 1`, /ne se supprime pas/);
  await as(STU);
  const lp = (await q(`select project_proof_list('${pid}') r`))[0].r;
  check('registre : le porteur voit 2 versions intègres (plus récente d\'abord)', lp.length === 2 && lp[0].version === 2 && lp.every((x) => x.integre === true));
  await as(OTH);
  check('isolation registre : un autre étudiant ne liste rien', (await q(`select project_proof_list('${pid}') r`))[0].r.length === 0);
  await as(null, 'anon'); await ip('10.0.2.1');
  const pb0 = (await q(`select project_proof_verify('${pid}') r`))[0].r;
  check('registre : projet non approuvé : inconnu pour un tiers (rien révélé)', pb0.statut === 'inconnu' && pb0.valide === false && !JSON.stringify(pb0).includes('Capteur'));
  await as(ADM); await q(`select review_project('${pid}', true, '')`);
  await as(null, 'anon'); await ip('10.0.2.2');
  const pb = (await q(`select project_proof_verify('${pid}') r`))[0].r;
  check('registre : projet approuvé : un tiers recalcule et voit 2 versions intègres', pb.valide === true && pb.versions.length === 2 && pb.versions.every((x) => x.integre) && pb.projet === 'Capteur solaire');
  check('registre : auteur en initiales, mention « ni brevet » honnête', pb.auteur === 'M. N.' && /ni un brevet/.test(pb.mention) && !JSON.stringify(pb).includes('Marie'));
  await sudo(`alter table project_versions disable trigger trg_project_versions_guard; update project_versions set snapshot = jsonb_set(snapshot, '{title}', '"Truqué"') where project_id = '${pid}' and version = 1; alter table project_versions enable trigger trg_project_versions_guard`);
  await as(null, 'anon'); await ip('10.0.2.2');
  const pbt = (await q(`select project_proof_verify('${pid}') r`))[0].r;
  check('registre : altération d\'une version détectée (non intègre, chaîne rompue)', pbt.valide === false && pbt.versions.find((x) => x.version === 1).integre === false);
  await as(ADM);
  check('registre : l\'administrateur lit les versions de n\'importe quel projet', (await q(`select project_proof_list('${pid}') r`))[0].r.length === 2);
  await as(null, 'anon'); await ip('10.0.2.3');
  check('registre : identifiant inconnu : inconnu', (await q(`select project_proof_verify('${U(99)}') r`))[0].r.statut === 'inconnu');
  await fails('registre : enregistrement refusé à l\'anonyme', `select project_proof_register('${pid}', '')`, /denied/);

  // ------------------------------------------------------------ 9. rejeu : appliquer une seconde fois les migrations TRUST ne change rien
  const before = (await sudo(`select count(*)::int c, count(content_hash)::int h from certificates`))[0];
  const fs = await import('node:fs'); const path = await import('node:path');
  const dir = path.resolve(process.cwd(), '..', '..', 'migrations');
  for (const f of ['20261126070000_h10_trust_certificats_verifiables.sql', '20261126070100_h10_trust_jeton_passeport.sql', '20261126070200_h10_trust_registre_innovation.sql']) {
    try { await db.exec(fs.readFileSync(path.join(dir, f), 'utf8')); check('rejeu : ' + f + ' sans erreur', true); } catch (e) { check('rejeu : ' + f + ' sans erreur', false, e.message); }
  }
  const after = (await sudo(`select count(*)::int c, count(content_hash)::int h from certificates`))[0];
  check('rejeu : aucun certificat perdu ni recalculé', before.c === after.c && before.h === after.h);
  check('rejeu : l\'empreinte de la version 2 du registre est intacte', (await sudo(`select content_hash h from project_versions where project_id = '${pid}' and version = 2`))[0].h === rows[1].content_hash);
  check('rejeu : l\'empreinte du certificat 1 est inchangée', (await sudo(`select content_hash h from certificates where code = '${code1}'`))[0].h === c1.content_hash);

  console.log(`h10_trust : ${ok} OK, ${ko} ECHEC`);
}
