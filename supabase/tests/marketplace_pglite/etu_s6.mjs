// Lot S6 : annuaire de coéquipiers sur consentement, concours (frais, règlement, jurés, sortie d'équipe), vœux (précommandeurs, clôture), duels, lives.
// Usage : node replay.mjs all ./etu_s6.mjs  (attendu : aucune ligne ECHEC)
let ok = 0, ko = 0;
export async function run(db) {
  const id = (n) => `00000000-0000-0000-0000-0000000000${n}`;
  const A = id('a1'), B = id('b1'), C = id('c1'), D = id('d1'), K = id('e1'), M = id('ee'), J = id('f1'), P = id('f2'), N = id('f3');
  const as = async (uid, role = 'authenticated') => { await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false)`); if (role) await db.exec(`set role ${role}`); };
  const q = async (sql) => (await db.query(sql)).rows;
  const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
  const fails = async (name, sql, re) => { try { await q(sql); check(name, false, 'aurait du echouer'); } catch (e) { check(name, re.test(e.message), e.message); } };
  await db.exec('reset role');
  for (const [uid, nm, role, skills] of [
    [A, 'Awa Etudiante', 'student', 'Flutter, Python'], [B, 'Boris Etudiant', 'student', 'Figma, design'], [C, 'Cora Etudiante', 'student', 'Marketing'],
    [D, 'Dan SansCompetence', 'student', ''], [K, 'Kim Cliente', 'client', ''], [M, 'Mod Admin', 'admin', ''], [J, 'Jean Juge', 'client', ''],
    [P, 'Paul Precommande', 'client', ''], [N, 'Nina Nouvelle', 'student', 'Dessin'],
  ]) {
    await db.exec(`insert into auth.users(id,email) values ('${uid}','${nm.split(' ')[0]}@t.cm'); insert into profiles(id,name,role,email,skills) values ('${uid}','${nm}','${role}','${nm.split(' ')[0]}@t.cm','${skills}')`);
  }
  // comptes anciens (vote et diffusion demandent 24 h d'ancienneté) sauf Nina
  await db.exec(`update profiles set created_at = now() - interval '3 days' where id <> '${N}'`);

  // ============================================================ S6-15 : annuaire sur consentement
  await as(A);
  let r = (await q(`select mates_search('') r`))[0].r;
  check('S6-15 : sans consentement, personne n est liste', r.length === 0);
  let v = (await q(`select mates_visibility_get() r`))[0].r;
  check('S6-15 : reglage par defaut = non visible, competences renseignees', v.visible === false && v.has_skills === true && v.eligible === true);
  await as(D);
  await fails('S6-15 : opt-in refuse sans competences', `select mates_visibility_set(true)`, /compétences/);
  await as(K);
  await fails('S6-15 : opt-in reserve aux etudiants', `select mates_visibility_set(true)`, /réservé aux étudiants/);
  await as(null, 'anon');
  await fails('S6-15 : reglage inaccessible aux visiteurs', `select mates_visibility_get()`, /permission|Connexion/);
  await as(B);
  check('S6-15 : B active son opt-in', (await q(`select mates_visibility_set(true) r`))[0].r === true);
  await as(A);
  r = (await q(`select mates_search('') r`))[0].r;
  check('S6-15 : seul B (consentant) est liste', r.length === 1 && r[0].id === B);
  await fails('S6-15 : invitation refusee vers un etudiant non consentant', `select teammate_invite('${C}')`, /pas dans l'annuaire/);
  const inv = (await q(`select teammate_invite('${B}', 'Hackathon ?') id`))[0].id;
  check('S6-15 : invitation autorisee vers un consentant', !!inv);
  await as(B);
  await q(`select mates_visibility_set(false)`);
  await as(A);
  r = (await q(`select mates_search('') r`))[0].r;
  check('S6-15 : retrait du consentement = disparait de l annuaire', r.length === 0);
  await as(B);
  await q(`select teammate_invite('${A}', 'Reponds-moi')`).catch(() => null);
  await as(C);
  await q(`select mates_visibility_set(true)`);
  await as(M);
  r = (await q(`select mates_search('') r`))[0].r;
  check('S6-15 : l admin voit seulement les consentants', r.length === 1 && r[0].id === C);
  await as(A);
  await fails('S6-15 : table de consentement fermee', `select * from mate_consents`, /permission/);

  // ============================================================ S6-65 : concours (frais, règlement, dates)
  await as(K);
  await fails('S6-65 : publication reservee au departement', `select save_contest(null, 'Concours X', 'Une description assez longue pour passer', 'IA', 'Regle 1', 'Douala', now() + interval '10 days', now() + interval '20 days', null, null, 1000, 10, true, 5000)`, /réservée au département/);
  await as(M);
  const cid = (await q(`select save_contest(null, 'Hackathon Eau', 'Une description assez longue pour passer le controle', 'Eau potable', 'Article 1 : equipes de 5 au plus.', 'Douala', now() + interval '10 days', now() + interval '20 days', current_date + 12, current_date + 14, 500000, 20, true, 5000) id`))[0].id;
  let row = (await q(`select theme, rules, entry_fee, starts_on is not null s, ends_on is not null e from contests where id = '${cid}'`))[0];
  check('S6-65 : theme, reglement, frais et dates enregistres', row.theme === 'Eau potable' && row.rules.startsWith('Article 1') && row.entry_fee === 5000 && row.s && row.e);
  await fails('S6-65 : frais non augmentables apres publication', `select save_contest('${cid}', 'Hackathon Eau', 'Une description assez longue pour passer le controle', 'Eau potable', 'Article 1', 'Douala', now() + interval '10 days', now() + interval '20 days', current_date + 12, current_date + 14, 500000, 20, true, 9000)`, /frais d'inscription ne peuvent qu'être réduits/);
  await q(`select save_contest('${cid}', 'Hackathon Eau', 'Une description assez longue pour passer le controle', 'Eau potable', 'Article 1 revu', 'Douala', now() + interval '10 days', now() + interval '20 days', current_date + 12, current_date + 14, 500000, 20, true, 2000)`);
  row = (await q(`select rules, entry_fee from contests where id = '${cid}'`))[0];
  check('S6-65 : frais reduits et reglement modifie', row.entry_fee === 2000 && row.rules === 'Article 1 revu');
  await q(`select save_contest('${cid}', 'Hackathon Eau', 'Une description assez longue pour passer le controle', 'Eau potable', 'Article 1 revu', 'Douala', now() + interval '10 days', now() + interval '20 days', current_date + 12, current_date + 14, 500000, 20, true)`);
  check('S6-65 : sans p_entry_fee, les frais restent', (await q(`select entry_fee from contests where id = '${cid}'`))[0].entry_fee === 2000);
  await fails('S6-65 : fin avant debut refusee', `select save_contest(null, 'Hackathon Faux', 'Une description assez longue pour passer le controle', '', '', 'Douala', now() + interval '10 days', now() + interval '20 days', current_date + 14, current_date + 12, 0, 10, false)`, /date de fin/);
  await fails('S6-65 : frais hors bornes refuses', `select save_contest(null, 'Hackathon Faux', 'Une description assez longue pour passer le controle', '', '', 'Douala', now() + interval '10 days', now() + interval '20 days', null, null, 0, 10, false, -1)`, /Frais/);
  await fails('S6-65 : reglement trop long refuse', `select save_contest(null, 'Hackathon Faux', 'Une description assez longue pour passer le controle', '', repeat('x', 8001), 'Douala', now() + interval '10 days', now() + interval '20 days', null, null, 0, 10, false)`, /Règlement/);

  // ============================================================ S6-64 : juré désigné (rôle client) + S6-11 : sortie d'équipe
  await db.exec(`reset role;
    insert into contest_teams (id, contest_id, name, captain_id, rules_accepted_at) values ('00000000-0000-0000-0000-0000000000c1', '${cid}', 'Equipe Awa', '${A}', now()), ('00000000-0000-0000-0000-0000000000c2', '${cid}', 'Equipe Jean', '${J}', now());
    insert into contest_members (team_id, user_id, status) values ('00000000-0000-0000-0000-0000000000c1', '${A}', 'captain'), ('00000000-0000-0000-0000-0000000000c1', '${B}', 'member'), ('00000000-0000-0000-0000-0000000000c2', '${J}', 'captain');
    insert into contest_submissions (team_id, title, description, original_certified, submitted) values
      ('00000000-0000-0000-0000-0000000000c1', 'Filtre solaire', 'Un filtre a eau solaire pour les villages sans reseau electrique.', true, true),
      ('00000000-0000-0000-0000-0000000000c2', 'Puits connecte', 'Un puits connecte qui previent quand le niveau baisse trop bas.', true, true);
    update contests set status = 'judging', reg_close_at = now() - interval '2 days', submit_close_at = now() - interval '1 day' where id = '${cid}'`);
  await as(M);
  await q(`select assign_contest_juror('${cid}', 'Jean@t.cm', true)`);
  await as(J);
  let jc = (await q(`select my_juror_contests() r`))[0].r;
  check('S6-64 : un juge de role client voit son concours', jc.length === 1 && jc[0].id === cid && jc[0].status === 'judging');
  check('S6-64 : son propre projet est exclu du compte', jc[0].projects === 1);
  let jp = (await q(`select my_judging_projects() r`))[0].r;
  check('S6-64 : projets a noter = ceux des autres equipes', jp.length === 1 && jp[0].title === 'Filtre solaire' && jp[0].my_total === null);
  await fails('S6-64 : conflit d interet toujours refuse par le serveur', `select score_contest_submission((select id from contest_submissions where title = 'Puits connecte'), 5::smallint, 5::smallint, 5::smallint, 5::smallint, null)`, /Conflit/);
  await q(`select score_contest_submission('${jp[0].submission_id}', 8::smallint, 7::smallint, 9::smallint, 6::smallint, null)`);
  jp = (await q(`select my_judging_projects() r`))[0].r;
  check('S6-64 : la note du juge est reflétée', jp[0].my_total === 30);
  await as(K);
  check('S6-64 : un non-juge n a aucun concours a noter', (await q(`select my_juror_contests() r`))[0].r.length === 0 && (await q(`select my_judging_projects() r`))[0].r.length === 0);
  await as(null, 'anon');
  await fails('S6-64 : visiteur refuse', `select my_juror_contests()`, /permission|Connexion/);
  // sortie d'équipe : avant la clôture des dépôts uniquement
  await db.exec(`reset role; update contests set status = 'published', submit_close_at = now() + interval '5 days', reg_close_at = now() + interval '1 day' where id = '${cid}'; update contest_submissions set submitted = false`);
  await as(A);
  await fails('S6-11 : le capitaine ne peut pas quitter', `select contest_team_leave('00000000-0000-0000-0000-0000000000c1')`, /capitaine/);
  await as(C);
  await fails('S6-11 : un non-membre ne quitte rien', `select contest_team_leave('00000000-0000-0000-0000-0000000000c1')`, /pas membre/);
  await as(B);
  check('S6-11 : un membre quitte l equipe', (await q(`select contest_team_leave('00000000-0000-0000-0000-0000000000c1') r`))[0].r === 'left');
  await db.exec('reset role');
  check('S6-11 : membre retire et capitaine notifie', (await q(`select count(*)::int n from contest_members where user_id = '${B}'`))[0].n === 0 && (await q(`select count(*)::int n from notifications where user_id = '${A}' and title like 'Un membre a quitté%'`))[0].n === 1);

  // ============================================================ S6-42 / S6-43 : vœux
  await db.exec(`insert into wishes (id, author_id, title, description, price, threshold, duration_days, status, opened_at) values
      ('00000000-0000-0000-0000-0000000000d1', '${K}', 'Lampe en bois recyclé', 'Une lampe de chevet', 15000, 2, 5, 'approved', now() - interval '10 days'),
      ('00000000-0000-0000-0000-0000000000d2', '${K}', 'Sac en tissu wax', 'Un sac solide', 8000, 5, 30, 'approved', now() - interval '1 day'),
      ('00000000-0000-0000-0000-0000000000d3', '${K}', 'Brouillon envoye', 'x', 1000, 2, 10, 'submitted', null);
    insert into wish_preorders (wish_id, user_id) values ('00000000-0000-0000-0000-0000000000d1', '${P}'), ('00000000-0000-0000-0000-0000000000d1', '${A}'), ('00000000-0000-0000-0000-0000000000d2', '${P}');
    insert into user_blocks (blocker_id, blocked_id) values ('${A}', '${K}')`);
  const W1 = '00000000-0000-0000-0000-0000000000d1', W2 = '00000000-0000-0000-0000-0000000000d2', W3 = '00000000-0000-0000-0000-0000000000d3';
  await as(P);
  await fails('S6-43 : un precommandeur ne voit pas la liste', `select wish_preorderers('${W1}')`, /Réservé au créateur/);
  await fails('S6-43 : un precommandeur ne peut pas ecrire aux autres', `select wish_contact_preorderers('${W1}', 'Bonjour a tous les amis')`, /Réservé au créateur/);
  await as(K);
  let pl = (await q(`select wish_preorderers('${W1}') r`))[0].r;
  check('S6-43 : l auteur voit les precommandeurs (prenom + initiale)', pl.count === 2 && pl.reached === true && pl.ended === true && pl.can_contact === true && pl.preorderers.some(x => x.name === 'Paul P.') && !JSON.stringify(pl).includes('@'));
  await fails('S6-43 : seuil non atteint = pas de message', `select wish_contact_preorderers('${W2}', 'Bonjour, ou en est-on ?')`, /seuil/);
  await fails('S6-43 : lien interdit', `select wish_contact_preorderers('${W1}', 'Commandez sur https://exemple.com maintenant')`, /liens/);
  await fails('S6-43 : message trop court', `select wish_contact_preorderers('${W1}', 'Salut')`, /10 à 500/);
  const sent = (await q(`select wish_contact_preorderers('${W1}', 'Le seuil est atteint : je lance la fabrication la semaine prochaine.') n`))[0].n;
  check('S6-43 : message envoye aux precommandeurs non bloques', sent === 1);
  await db.exec('reset role');
  check('S6-43 : notification recue par Paul seulement', (await q(`select count(*)::int n from notifications where kind = 'wish' and user_id = '${P}' and title like 'Du créateur du vœu%' and body like 'Kim C. :%'`))[0].n === 1
    && (await q(`select count(*)::int n from notifications where user_id = '${A}' and title like 'Du créateur du vœu%'`))[0].n === 0);
  await as(K);
  await q(`select wish_contact_preorderers('${W1}', 'Deuxieme nouvelle : premier prototype pret.')`);
  await q(`select wish_contact_preorderers('${W1}', 'Troisieme nouvelle : livraison prevue bientot.')`);
  await fails('S6-43 : trois messages par semaine au plus', `select wish_contact_preorderers('${W1}', 'Quatrieme message de trop pour la semaine')`, /Trois messages/);
  // clôture
  await db.exec('reset role');
  check('S6-42 : la campagne echue a ete cloturee une seule fois', (await q(`select count(*)::int n from wish_closures where wish_id = '${W1}' and reached and preorders = 2`))[0].n === 1
    && (await q(`select count(*)::int n from notifications where title = 'Campagne de précommandes terminée' and user_id = '${K}'`))[0].n === 1
    && (await q(`select count(*)::int n from notifications where title = 'Campagne de précommandes terminée' and user_id = '${P}' and body like '%seuil est atteint%'`))[0].n === 1);
  check('S6-42 : wish_close_expired idempotente', (await q(`select wish_close_expired() n`))[0].n === 0 && (await q(`select count(*)::int n from notifications where title = 'Campagne de précommandes terminée'`))[0].n === 3);
  await db.exec(`update wishes set opened_at = now() - interval '40 days' where id = '${W2}'`);
  check('S6-42 : seuil non atteint = cloture sans fabrication', (await q(`select wish_close_expired() n`))[0].n === 1
    && (await q(`select count(*)::int n from notifications where user_id = '${P}' and body like '%seuil n''a pas été atteint%'`))[0].n === 1);
  await as(P);
  const mine = (await q(`select my_wish_preorders() r`))[0].r;
  check('S6-42 : Mes precommandes garde les campagnes echues', mine.length === 2 && mine.every(x => x.ended === true));
  await as(null, 'anon');
  await fails('S6-43 : lecture des precommandes interdite aux visiteurs', `select my_wish_preorders()`, /permission|Connexion/);
  await as(K);
  const mw = (await q(`select my_wishes() r`))[0].r;
  check('S6-44 : mes voeux par RPC', mw.length === 3);
  check('S6-44 : brouillon lu par son auteur', (await q(`select wish_draft_get('${W3}') r`))[0].r.title === 'Brouillon envoye');
  await as(P);
  check('S6-44 : brouillon invisible pour un tiers', (await q(`select wish_draft_get('${W3}') r`))[0].r === null);
  await fails('S6-44 : file de validation reservee au departement', `select wishes_to_review()`, /Réservé/);
  await as(M);
  check('S6-44 : le departement voit les voeux a valider', (await q(`select wishes_to_review() r`))[0].r.length === 1);
  await as(P);
  await fails('S6-47 : retrait d un voeu qui n est pas le mien', `select withdraw_wish('${W3}')`, /Aucun vœu/);
  await as(K);
  check('S6-47 : l auteur retire son voeu envoye', (await q(`select withdraw_wish('${W3}') r`))[0].r === 'draft');

  // ============================================================ S6-48/49/50/51 : duels
  await as(K);
  const duel = (await q(`select duel_create('Logo pour ma marque', 'Un sac cadeau', 48) id`))[0].id;
  await as(A);
  await fails('S6-48 : lien invalide refuse', `select duel_enter('${duel}', 'Mon logo', 'javascript:alert(1)')`, /https/);
  const eA = (await q(`select duel_enter('${duel}', 'Mon logo', 'https://exemple.cm/mon-logo.png') id`))[0].id;
  await as(B);
  const eB = (await q(`select duel_enter('${duel}', 'Mon autre logo') id`))[0].id;
  await fails('S6-49 : un participant ne vote pas pour un concurrent', `select duel_vote('${eA}')`, /participants du duel ne votent pas/);
  await as(C);
  await q(`select duel_vote('${eA}')`);
  let dl = (await q(`select duels_list('open') r`))[0].r;
  const dd = dl.find(x => x.id === duel);
  check('S6-49 : votes masques tant que le duel est ouvert', dd.entries.every(e => e.votes === null) && dd.entries.find(e => e.id === eA).my_vote === true);
  check('S6-48 : le lien de la proposition est expose', dd.entries.find(e => e.id === eA).link === 'https://exemple.cm/mon-logo.png' && dd.entries.find(e => e.id === eB).link === null);
  check('S6-50 : repere de ma proposition (my_entry/mine)', dd.my_entry === false);
  await as(A);
  dl = (await q(`select duels_list('open') r`))[0].r;
  check('S6-50 : l auteur voit my_entry et sa ligne', dl[0].my_entry === true && dl[0].entries.find(e => e.id === eA).mine === true);
  await as(B);
  check('S6-49 : retrait de sa proposition', (await q(`select duel_withdraw('${duel}') r`))[0].r === 'withdrawn');
  await fails('S6-49 : retrait sans participation refuse', `select duel_withdraw('${duel}')`, /ne participez pas/);
  await db.exec(`reset role; update duels set ends_at = now() - interval '1 hour' where id = '${duel}'`);
  await as(C);
  check('S6-51 : portee open vide / done contient le duel', (await q(`select duels_list('open') r`))[0].r.length === 0 && (await q(`select duels_list('done') r`))[0].r.some(x => x.id === duel));
  dl = (await q(`select duels_list('done') r`))[0].r;
  check('S6-49 : votes visibles une fois le duel termine', dl.find(x => x.id === duel).entries.find(e => e.id === eA).votes === 1);
  check('S6-51 : pagination', (await q(`select jsonb_array_length(duels_list('all', 1, 5)) n`))[0].n === 0);
  await as(null, 'anon');
  check('S6-51 : visiteur lit la liste (sans parametres)', Array.isArray((await q(`select duels_list() r`))[0].r));

  // ============================================================ S6-55 / S6-69 / S6-68 : lives
  await db.exec(`reset role; update profiles set certification = 'approved' where id = '${A}'`);
  await db.exec(`insert into lives (id, host_id, title, status, scheduled_at, created_at) values
      ('00000000-0000-0000-0000-0000000000a1', '${A}', 'Atelier a venir', 'scheduled', now() + interval '1 day', now()),
      ('00000000-0000-0000-0000-0000000000a2', '${A}', 'Live sans date', 'scheduled', null, now() - interval '8 hours'),
      ('00000000-0000-0000-0000-0000000000a3', '${A}', 'Live date passee', 'scheduled', now() - interval '5 hours', now() - interval '2 days'),
      ('00000000-0000-0000-0000-0000000000a4', '${A}', 'Live recent sans date', 'scheduled', null, now() - interval '10 minutes')`);
  await as(null, 'anon');
  let ln = await q(`select title from lives_now(30)`);
  check('S6-55 : Prochains lives masque les lives sans date et les dates depassees', ln.length === 1 && ln[0].title === 'Atelier a venir', JSON.stringify(ln));
  await db.exec('reset role');
  check('S6-69 : lives_expire_stale annule les fantomes (2) et garde le live recent', (await q(`select lives_expire_stale() n`))[0].n === 2
    && (await q(`select status from lives where id = '00000000-0000-0000-0000-0000000000a4'`))[0].status === 'scheduled');
  await as(N);
  await fails('S6-68 : un compte etudiant de moins de 24 h ne diffuse pas encore', `select create_live('Mon premier atelier', '', null)`, /24 heures/);
  await db.exec(`reset role; update profiles set created_at = now() - interval '2 days' where id = '${N}'`);
  await as(N);
  check('S6-68 : apres 24 h, la creation est possible', !!(await q(`select create_live('Mon premier atelier', '', null) id`))[0].id);
  await as(K);
  await fails('S6-68 : un client non certifie reste refuse', `select create_live('Live client', '', null)`, /réservée/);
  console.log(`\n${ok}/${ok + ko}`);
}
