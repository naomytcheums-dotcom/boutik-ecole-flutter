// Scénario PGlite du lot S2 (profil étudiant : sécurité, confidentialité, compétences, Talent Passport, CV, liens).
//   cd supabase/tests/marketplace_pglite && npm i @electric-sql/pglite && node replay.mjs all ./etu_s2.mjs
let ok = 0, ko = 0;
export async function run(db) {
  const rawExec = db.exec.bind(db);
  db.exec = (s) => (s === 'reset role' ? rawExec("reset role; select set_config('request.jwt.claim.sub', '', false)") : rawExec(s));
  const U = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  const A = U(31), B = U(32), C = U(33), D = U(34), E = U(35);

  await db.exec('reset role');
  const roles = { 31: 'student', 32: 'student', 33: 'company', 34: 'dept', 35: 'company' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','s${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Personne ${n}','${r}','s${n}@t.cm')`);
  }
  await db.exec(`update profiles set email = 'recrute@boite.cm' where id = '${C}'`);
  // Lot F1 : seule une entreprise dont la fiche est approuvée reçoit un CV.
  await db.exec(`insert into company_profiles (owner_id, company_name, status) values ('${C}', 'Boite SARL', 'approved')`);

  // ---------------------------------------------------------------- S2-55 : envoi du CV à une entreprise
  await as(A);
  await fails('S2-55 : sans lien de CV, refus', `select send_cv_to_recruiter('recrute@boite.cm', '')`, /Créez d'abord le lien/);
  await q(`select cv_link_save(true, 0, true, true, true, true)`);
  const r1 = (await q(`select send_cv_to_recruiter('recrute@boite.cm', '') r`))[0].r;
  const r2 = (await q(`select send_cv_to_recruiter('inconnue@nulle-part.cm', '') r`))[0].r;
  check('S2-55 : réponse identique adresse existante / inexistante', r1 === 'sent' && r2 === 'sent', `${r1} ${r2}`);
  await fails('S2-55 : adresse mal formée refusée', `select send_cv_to_recruiter('pas-une-adresse', '')`, /Adresse e-mail invalide/);
  await db.exec('reset role');
  check('S2-55 : l\'entreprise reçoit une seule notification', (await q(`select count(*)::int n from notifications where user_id = '${C}' and kind = 'cv_shared'`))[0].n === 1);
  check('S2-55 : un seul envoi enregistré', (await q(`select count(*)::int n from cv_sends where sender_id = '${A}'`))[0].n === 1);
  check('S2-55 : les deux tentatives sont comptées', (await q(`select count(*)::int n from cv_send_attempts where sender_id = '${A}'`))[0].n === 2);
  await as(A);
  await q(`select send_cv_to_recruiter('recrute@boite.cm', '')`);
  await db.exec('reset role');
  check('S2-55 : pas de doublon de notification dans la journée', (await q(`select count(*)::int n from notifications where user_id = '${C}' and kind = 'cv_shared'`))[0].n === 1);
  await as(A);
  await q(`select send_cv_to_recruiter('a1@x.cm', '')`);
  await q(`select send_cv_to_recruiter('a2@x.cm', '')`);
  await fails('S2-55 : la 6e tentative de la journée est refusée même sans entreprise', `select send_cv_to_recruiter('a3@x.cm', '')`, /Cinq envois de CV par jour/);
  await as(B);
  await q(`select cv_link_save(true, 0, true, true, true, true)`);
  check('S2-55 : la limite est propre à chaque utilisateur', (await q(`select send_cv_to_recruiter('a3@x.cm', '') r`))[0].r === 'sent');

  // ---------------------------------------------------------------- S2-5 : couvertures et fichiers orphelins
  await as(A);
  check('S2-5 : première couverture, rien à supprimer', (await q(`select profile_cover_set(0, '${A}/a.jpg', 'image') r`))[0].r === '');
  check('S2-5 : le remplacement renvoie l\'ancien chemin', (await q(`select profile_cover_set(0, '${A}/b.jpg', 'image') r`))[0].r === `${A}/a.jpg`);
  check('S2-5 : même chemin ré-enregistré : rien à supprimer', (await q(`select profile_cover_set(0, '${A}/b.jpg', 'image') r`))[0].r === '');
  await q(`select profile_cover_set(1, '${A}/c.jpg', 'image')`);
  check('S2-5 : la suppression renvoie le chemin à purger', (await q(`select profile_cover_clear(1) r`))[0].r === `${A}/c.jpg`);
  check('S2-5 : suppression d\'un emplacement vide : rien', (await q(`select profile_cover_clear(2) r`))[0].r === '');
  await q(`select set_my_cover('${A}/d.jpg', 'image')`);
  await q(`select profile_cover_set(2, '${A}/d.jpg', 'image')`);
  check('S2-5 : un chemin encore utilisé ailleurs n\'est pas à supprimer', (await q(`select profile_cover_clear(2) r`))[0].r === '');
  check('S2-5 : set_my_cover renvoie l\'ancienne couverture orpheline', (await q(`select set_my_cover('${A}/e.jpg', 'image') r`))[0].r === `${A}/d.jpg`);
  await as(B);
  check('S2-5 : la couverture d\'autrui n\'est pas supprimable', (await q(`select profile_cover_clear(0) r`))[0].r === '');
  await as(A);
  check('S2-5 : la couverture d\'Alice est intacte', (await q(`select profile_covers_get() r`))[0].r.length === 1);

  // ---------------------------------------------------------------- S2-66 : certificats à 24 caractères
  await db.exec('reset role');
  await db.exec(`insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, issued_by, fingerprint) values ('BE-CERT-0123456789ABCDEF', 'talent', 'Talent test', '${A}', 'Alice', '${D}', 'f'), ('BE-CERT-0A1B2C3D', 'talent', 'Ancien', '${A}', 'Alice', '${D}', 'f2')`);
  await as(null, 'anon');
  check('S2-66 : code à 24 caractères reconnu', (await q(`select verify_certificate('BE-CERT-0123456789ABCDEF') r`))[0].r.valide === true);
  check('S2-66 : espaces et minuscules tolérés', (await q(`select verify_certificate(' be-cert-0123 456789abcdef ') r`))[0].r.valide === true);
  check('S2-66 : ancien code à 16 caractères toujours reconnu', (await q(`select verify_certificate('BE-CERT-0A1B2C3D') r`))[0].r.valide === true);
  check('S2-66 : code inconnu : introuvable', (await q(`select verify_certificate('BE-CERT-FFFFFFFFFFFFFFFF') r`))[0].r.introuvable === true);

  // ---------------------------------------------------------------- S2-1 : compétences non écrasées
  await db.exec('reset role');
  await db.exec(`update profiles set skills = 'Python, React' where id = '${A}'`);
  await as(A);
  await q(`select skill_save(null, 'Design', 'Graphiste', 'Logo', 'avance', 2, 'Identités', null)`);
  const sk = async () => (await q(`select skills s from profiles where id = '${A}'`))[0].s;
  check('S2-1 : compétence du Passport ajoutée sans effacer le texte libre', (await sk()) === 'Python, React, Logo', await sk());
  const logoId = (await q(`select id from talent_skills where owner_id = '${A}' and skill = 'Logo'`))[0].id;
  await q(`select skill_save('${logoId}', 'Design', 'Graphiste', 'Logotype', 'expert', 3, '', null)`);
  check('S2-1 : renommer ne retire que l\'ancienne compétence', (await sk()) === 'Python, React, Logotype', await sk());
  await q(`select skill_save(null, 'Informatique', 'Développeur web', 'python', 'debutant', 1, '', null)`);
  check('S2-1 : pas de doublon insensible à la casse', (await sk()) === 'Python, React, Logotype', await sk());
  await q(`select skill_delete('${logoId}')`);
  check('S2-1 : supprimer ne retire que cette compétence', (await sk()) === 'Python, React', await sk());
  await db.exec('reset role');
  await db.exec(`update profiles set skills = 'Python' where id = '${A}'`);
  await as(A);
  await q(`select skill_save(null, 'Informatique', 'Développeur web', 'Flutter', 'avance', 2, 'Appli mobile', null)`);
  check('S2-1 : une compétence retirée du texte libre revient seulement si elle est dans le Passport', (await sk()) === 'Python, Flutter', await sk());

  // ---------------------------------------------------------------- S2-32 / S2-21 : Talent Passport
  await db.exec('reset role');
  await db.exec(`update profiles set certification = 'approved' where id = '${A}'`);
  const doc = (await q(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${A}', 'diploma', 'Diplôme', '${A}/diploma/d.pdf', 'application/pdf', 100, 'verified') returning id`))[0].id;
  await as(A);
  await q(`select skill_save(null, 'Informatique', 'Développeur web', 'React', 'expert', 4, 'Beaucoup de React', '${doc}')`);
  const own = (await q(`select talent_passport() r`))[0].r;
  const rk = own.skills.find((x) => x.skill === 'React');
  check('S2-32 : le Passport renvoie niveau, années et justificatif', rk && rk.level === 'expert' && Number(rk.years) === 4 && rk.has_proof && rk.proof_verified);
  check('S2-32 : le propriétaire voit la description', rk.description === 'Beaucoup de React');
  check('S2-32 : tri par niveau décroissant', own.skills[0].level === 'expert');
  const codes = own.badges.map((b) => b.code);
  check('S2-32 : badges calculés (certifié, pièces vérifiées, compétence prouvée, expert)', ['certified', 'verified_documents', 'proven_skills', 'expert_skills'].every((c) => codes.includes(c)), JSON.stringify(codes));
  await as(B);
  const other = (await q(`select talent_passport('${A}') r`))[0].r;
  const ro = other.skills.find((x) => x.skill === 'React');
  check('S2-21 : un tiers voit le niveau', ro && ro.level === 'expert');
  check('S2-21 : un tiers ne voit pas la description ni le fichier du justificatif', ro.description === '' && !JSON.stringify(other).includes('diploma/d.pdf'));
  await as(null, 'anon');
  check('S2-21 : un visiteur voit le Passport d\'un profil public', (await q(`select talent_passport('${A}') r`))[0].r?.skills.length === 3);

  // ---------------------------------------------------------------- S2-9 / S2-13 : visibilité et annuaire
  await as(A);
  const pg = (await q(`select profile_privacy_get() r`))[0].r;
  check('S2-9 : réglage par défaut public + annuaire', pg.visibility === 'public' && pg.directory === true && pg.student === true);
  await fails('S2-9 : visibilité inconnue refusée', `select profile_privacy_set('secret', true)`, /Visibilité inconnue/);
  await as(null, 'anon');
  await fails('S2-9 : un visiteur ne règle rien', `select profile_privacy_set('private', false)`, /permission|Connexion/);
  // Application proposée au chef : public_profile et talents_list testent profile_visible / profile_in_directory.
  await db.exec('reset role');
  await db.exec(`
    create or replace function public_profile(p_user uuid) returns jsonb language sql stable security definer set search_path = public as $$
      select jsonb_build_object('id', p.id, 'name', p.name) from profiles p
      where p.id = p_user and not coalesce(p.suspended, false) and profile_visible(p.id)
        and (p.id = auth.uid() or p.role::text in ('student', 'company', 'other'));
    $$;`);
  await as(A);
  await q(`select profile_privacy_set('members', true)`);
  await as(null, 'anon');
  check('S2-9 : profil « connectés » : invisible pour un visiteur', (await q(`select public_profile('${A}') p`))[0].p === null);
  check('S2-9 : profil « connectés » : portfolio invisible pour un visiteur', (await q(`select count(*)::int n from portfolio_items where owner_id = '${A}'`))[0].n === 0);
  check('S2-9 : Passport invisible pour un visiteur', (await q(`select talent_passport('${A}') r`))[0].r === null);
  await as(B);
  check('S2-9 : profil « connectés » : visible pour un compte connecté', (await q(`select public_profile('${A}') p`))[0].p?.id === A);
  await as(A);
  await q(`select portfolio_save(null, 'realisation', 'Projet A', 'desc', 'Web', '2026', 'https://exemple.cm/a', null, false)`);
  await q(`select profile_privacy_set('private', false)`);
  check('S2-9 : le propriétaire se voit toujours', (await q(`select public_profile('${A}') p`))[0].p?.id === A && (await q(`select count(*)::int n from portfolio_items where owner_id = '${A}'`))[0].n === 1);
  await as(B);
  check('S2-9 : profil privé : invisible pour un autre compte', (await q(`select public_profile('${A}') p`))[0].p === null);
  check('S2-9 : profil privé : portfolio invisible', (await q(`select count(*)::int n from portfolio_items where owner_id = '${A}'`))[0].n === 0);
  check('S2-9 : profil privé : couvertures invisibles', (await q(`select profile_covers_get('${A}') r`))[0].r.length === 0);
  check('S2-9 : profil privé : CV d\'un talent non consultable par identifiant', (await q(`select cv_public('${A}') r`))[0].r === null);
  check('S2-9 : profil privé : Passport invisible', (await q(`select talent_passport('${A}') r`))[0].r === null);
  await db.exec('reset role');
  check('S2-13 : un profil privé sort de l\'annuaire',  (await q(`select profile_in_directory('${A}') r`))[0].r === false);
  await as(A);
  await q(`select profile_privacy_set('public', false)`);
  await db.exec('reset role');
  check('S2-13 : retrait explicite de l\'annuaire (profil public)', (await q(`select profile_in_directory('${A}') r`))[0].r === false);
  await as(A);
  await q(`select profile_privacy_set('public', true)`);
  await db.exec('reset role');
  check('S2-13 : de nouveau dans l\'annuaire', (await q(`select profile_in_directory('${A}') r`))[0].r === true);
  await as(B);
  check('S2-9 : profil public rétabli : visible', (await q(`select public_profile('${A}') p`))[0].p?.id === A);
  await as(A);
  const before = (await q(`select cv_link_get() r`))[0].r.token;
  await q(`select profile_privacy_set('private', false)`);
  await as(null, 'anon');
  check('S2-9 : shared_cv (jeton) reste lisible : le lien est un partage explicite', (await q(`select shared_cv('${before}') r`))[0].r?.nom === 'Personne 31');
  await as(A);
  await q(`select profile_privacy_set('public', true)`);

  // ---------------------------------------------------------------- S2-71 / S2-78 : CV vivant
  await q(`select portfolio_save(null, 'image', 'Affiche', 'visuel', 'Design', '2026', '', null, false) `).catch(() => null);
  await db.exec('reset role');
  await db.exec(`update profiles set links = '[{"label":"GitHub","url":"https://github.com/a1"},{"label":"Piège","url":"http://pas-https.cm"},{"label":"JS","url":"javascript:alert(1)"}]'::jsonb where id = '${A}'`);
  await as(A);
  const cv = (await q(`select cv_preview() r`))[0].r;
  check('S2-71 : le CV reprend les réalisations de tous types', cv.realisations.length >= 1 && cv.realisations.every((x) => 'type' in x));
  check('S2-78 : le CV ne publie que des liens https', cv.liens.length === 1 && cv.liens[0].url === 'https://github.com/a1');
  check('S2-71 : le CV porte les niveaux de compétence', cv.competences_niveaux.some((x) => x.competence === 'React' && x.niveau === 'expert'));
  check('S2-71 : aucun e-mail ni téléphone dans le CV', !/@t\.cm|phone/.test(JSON.stringify(cv)));

  // ---------------------------------------------------------------- S2-44 : réseaux connectés → liens du profil
  await db.exec('reset role');
  await db.exec(`update profiles set links = '[]'::jsonb where id = '${A}'`);
  const conn = (await q(`insert into integration_connections (user_id, provider, external_id, display_name, profile_url, status) values ('${A}', 'instagram', 'ig1', '@alice', 'https://www.instagram.com/alice', 'connected') returning id`))[0].id;
  const links = async () => (await q(`select links l from profiles where id = '${A}'`))[0].l;
  check('S2-44 : la connexion ajoute le lien du réseau au profil', (await links()).some((l) => l.url === 'https://www.instagram.com/alice' && l.label === 'Instagram'));
  await db.exec(`update integration_connections set last_sync_at = now() where id = '${conn}'`);
  check('S2-44 : une synchronisation ne duplique pas le lien', (await links()).length === 1);
  await db.exec(`update profiles set links = '[]'::jsonb where id = '${A}'; update integration_connections set last_sync_at = now() where id = '${conn}'`);
  check('S2-44 : une synchronisation ne rétablit pas un lien retiré à la main', (await links()).length === 0);
  await db.exec(`update integration_connections set status = 'expired' where id = '${conn}'; update integration_connections set status = 'connected' where id = '${conn}'`);
  check('S2-44 : la reconnexion rétablit le lien', (await links()).length === 1);
  await db.exec(`update integration_connections set status = 'revoked' where id = '${conn}'`);
  check('S2-44 : la déconnexion retire le lien', (await links()).length === 0);
  await db.exec(`update integration_connections set status = 'connected' where id = '${conn}'`);
  await db.exec(`delete from integration_connections where id = '${conn}'`);
  check('S2-44 : la suppression de la connexion retire le lien', (await links()).length === 0);
  await db.exec(`insert into integration_connections (user_id, provider, external_id, display_name, profile_url, status) values ('${A}', 'google_drive', 'gd1', 'Drive', 'https://drive.google.com/u/0', 'connected')`);
  check('S2-44 : un outil de productivité n\'ajoute pas de lien', (await links()).length === 0);
  await db.exec(`insert into integration_connections (user_id, provider, external_id, display_name, profile_url, status) values ('${A}', 'github', 'gh1', 'alice', 'http://github.com/alice', 'connected')`);
  check('S2-44 : une adresse non https n\'est jamais ajoutée', (await links()).length === 0);

  // ---------------------------------------------------------------- S2-45 : liens publics
  await db.exec(`update profiles set links = '[{"label":"Site","url":"https://alice.cm"},{"label":"X","url":"http://x.cm"}]'::jsonb where id = '${A}'`);
  await as(null, 'anon');
  const pl = (await q(`select profile_links_public('${A}') r`))[0].r;
  check('S2-45 : les liens https sont publics, pas les autres', pl.length === 1 && pl[0].url === 'https://alice.cm');
  await as(A);
  await q(`select profile_privacy_set('private', false)`);
  await as(B);
  check('S2-45 : profil privé : aucun lien public', (await q(`select profile_links_public('${A}') r`))[0].r.length === 0);
  await as(A);
  await q(`select profile_privacy_set('public', true)`);

  // ---------------------------------------------------------------- S2-43 : contenus importés
  await db.exec('reset role');
  await db.exec(`insert into integration_connections (id, user_id, provider, external_id, display_name, status) values ('00000000-0000-0000-0000-00000000c0c1', '${A}', 'youtube', 'yt1', 'Chaîne', 'connected')`);
  await db.exec(`insert into integration_imported_items (connection_id, user_id, provider, external_id, kind, title, url, visibility) values
    ('00000000-0000-0000-0000-00000000c0c1', '${A}', 'youtube', 'v1', 'video', 'Vidéo privée', 'https://youtu.be/1', 'private'),
    ('00000000-0000-0000-0000-00000000c0c1', '${A}', 'youtube', 'v2', 'video', 'Vidéo portfolio', 'https://youtu.be/2', 'portfolio'),
    ('00000000-0000-0000-0000-00000000c0c1', '${A}', 'youtube', 'v3', 'video', 'Vidéo publique', 'https://youtu.be/3', 'public')`);
  await as(B);
  const ii = (await q(`select profile_imported_items('${A}') r`))[0].r;
  check('S2-43 : un tiers voit les contenus « portfolio » et « public », jamais « privé »', ii.length === 2 && !ii.some((x) => x.title === 'Vidéo privée'));
  await as(A);
  check('S2-43 : le propriétaire voit tout', (await q(`select profile_imported_items() r`))[0].r.length === 3);
  await as(null, 'anon');
  check('S2-43 : un visiteur voit les contenus partagés d\'un profil public', (await q(`select profile_imported_items('${A}') r`))[0].r.length === 2);
  await as(A);
  await q(`select profile_privacy_set('private', false)`);
  await as(B);
  check('S2-43 : profil privé : contenus importés masqués', (await q(`select profile_imported_items('${A}') r`))[0].r.length === 0);
  await as(A);
  await q(`select profile_privacy_set('public', true)`);

  // ---------------------------------------------------------------- patch proposé au chef : talents_list (définition S1 + annuaire + jokers échappés)
  await db.exec('reset role');
  await db.exec(`
    create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
    language plpgsql stable security definer set search_path = public as $$
    declare v_q text := replace(replace(replace(trim(coalesce(p_query, '')), '\\', '\\\\'), '%', '\\%'), '_', '\\_');
    begin
      if auth.uid() is null then raise exception 'Connexion requise'; end if;
      return coalesce((
        select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'skills', coalesce(t.skills, '')))
        from (
          select * from profiles
          where role::text = 'student' and not suspended and nullif(trim(coalesce(skills, '')), '') is not null and is_verified_student(id) and profile_in_directory(id)
            and (v_q = '' or name ilike '%' || v_q || '%' or skills ilike '%' || v_q || '%' or coalesce(department, '') ilike '%' || v_q || '%')
          order by (certification::text = 'approved') desc, created_at desc
          limit least(greatest(p_limit, 1), 50)
        ) t
      ), '[]'::jsonb);
    end $$;`);
  await as(B);
  check('patch talents_list : un étudiant dans l\'annuaire est listé', (await q(`select talents_list('', 20) r`))[0].r.some((x) => x.id === A));
  check('patch talents_list : « % » ne liste plus tout', (await q(`select talents_list('%', 20) r`))[0].r.length === 0);
  await as(A);
  await q(`select profile_privacy_set('public', false)`);
  await as(B);
  check('patch talents_list : retrait de l\'annuaire respecté', !(await q(`select talents_list('', 20) r`))[0].r.some((x) => x.id === A));
  await as(A);
  await q(`select profile_privacy_set('public', true)`);

  // ---------------------------------------------------------------- S2-95 : le département lit les pièces (lot S1)
  await db.exec('reset role');
  const inst = (await q(`insert into institutions(name, short_name, city, status) values ('Institut S2', 'IS2', 'Douala', 'verified') returning id`))[0].id;
  const dep = (await q(`insert into departments(institution_id, name, status) values ('${inst}', 'Génie S2', 'verified') returning id`))[0].id;
  await db.exec(`update profiles set department_id = '${dep}', institution_id = '${inst}' where id in ('${A}', '${D}')`);
  await db.exec(`insert into department_accounts (user_id, department_id) values ('${D}', '${dep}')`); // H2 : le responsable est rattaché à son département
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${A}', 'student_card', 'Carte', '${A}/student_card/c.pdf', 'application/pdf', 100, 'pending')`);
  await as(D);
  const rev = (await q(`select documents_to_review('pending', 50) r`))[0].r;
  check('S2-95 : le responsable de département reçoit le chemin des pièces de son périmètre', rev.some((x) => x.path === `${A}/student_card/c.pdf`));
  check('S2-95 : politique de lecture du stockage pour le département', (await q(`select count(*)::int n from pg_policies where schemaname = 'storage' and policyname = 'documents profil : lecture par le département'`))[0].n === 1);
  await as(B);
  await fails('S2-95 : un étudiant ne lit pas la file des pièces', `select documents_to_review('pending', 50)`, /non autorisée/);

  await db.exec('reset role');
  console.log(`\n${ok}/${ok + ko}`);
}

