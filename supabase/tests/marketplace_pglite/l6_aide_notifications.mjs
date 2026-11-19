// Scénario PGlite du lot L6 (migration 20261115160000) : support, notifications, canaux, appareils, signalements, événements, département.
//   cd supabase/tests/marketplace_pglite && node replay.mjs all ./l6_aide_notifications.mjs
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
  const roles = { 21: 'client', 22: 'support', 23: 'admin', 24: 'student' };
  for (const [n, r] of Object.entries(roles)) {
    await db.exec(`insert into auth.users(id,email) values ('${U(n)}','l6u${n}@t.cm'); insert into profiles(id,name,role,email,phone) values ('${U(n)}','Profil L6 ${n}','${r}','l6u${n}@t.cm',${n === '21' ? "'677000021'" : 'null'})`);
  }
  // Équipes internes (lot H4) : l'agent de support de ce scénario traite aussi les signalements (équipe Sécurité et modération, droit explicite).
  // K1 : droits minimaux par défaut ; ses permissions de support sont attribuées explicitement.
  await db.exec(`update admin_team_members set permissions = array['support.tickets', 'support.claims'] where user_id = '${U(22)}' and team_code = 'support'`);
  await db.exec(`insert into admin_team_members (user_id, team_code, permissions) values ('${U(22)}', 'security', array['security.moderation', 'security.reports'])`);

  // 1. support : création, notification du support et de l'administration, lecture limitée, réponse
  await as(U(21));
  await fails('ticket : sujet trop court', `select support_ticket_create('ab', 'Un message assez long pour passer')`, /sujet/);
  await fails('ticket : message trop court', `select support_ticket_create('Sujet', 'court')`, /10 caractères/);
  const t1 = (await q(`select support_ticket_create('Colis non reçu', 'Ma commande n''est jamais arrivée au point de retrait')`))[0].support_ticket_create;
  await db.exec('reset role');
  const n1 = await q(`select user_id from notifications where kind = 'support_ticket'`);
  check('ticket : support et admin notifiés', n1.length === 2 && n1.some((r) => r.user_id === U(22)) && n1.some((r) => r.user_id === U(23)), JSON.stringify(n1));
  await as(U(24));
  check('ticket : un autre compte ne le voit pas', (await q(`select id from support_tickets`)).length === 0);
  await fails('ticket : réponse refusée à un non-support', `select support_ticket_reply('${t1}', 'Bonjour')`, /non autorisée/);
  await as(U(22));
  check('ticket : le support le voit', (await q(`select id from support_tickets`)).length === 1);
  await q(`select support_ticket_reply('${t1}', 'Nous retrouvons votre colis.')`);
  await as(U(21));
  const mine = await q(`select status, reply from support_tickets`);
  check('ticket : réponse lisible par la personne', mine[0].status === 'answered' && /colis/.test(mine[0].reply), JSON.stringify(mine));
  await db.exec('reset role');
  check('ticket : notification « support » envoyée à la personne', (await q(`select 1 from notifications where user_id = '${U(21)}' and kind = 'support'`)).length === 1);
  await as(U(21));
  for (let i = 0; i < 4; i++) await q(`select support_ticket_create('Sujet ${i}', 'Un message assez long numéro ${i}')`);
  await fails('ticket : plafond de 5 par jour', `select support_ticket_create('Sixième', 'Un message assez long pour la sixième')`, /5 demandes/);

  // 2. notification lue individuellement
  await db.exec('reset role');
  await db.exec(`insert into notifications(user_id, kind, title, body) values ('${U(21)}', 'follow', 'A', 'a'), ('${U(21)}', 'follow', 'B', 'b')`);
  await as(U(21));
  const ids = await q(`select id from notifications where user_id = '${U(21)}' and kind = 'follow' order by title`);
  await q(`select mark_notification_read('${ids[0].id}')`);
  const left = await q(`select count(*)::int n from notifications where user_id = '${U(21)}' and kind = 'follow' and read_at is null`);
  check('lecture individuelle : une seule notification marquée', left[0].n === 1);

  // 3. catégories : une catégorie coupée n'est plus reçue, les autres si
  await q(`select set_notification_preference('inapp', 'cat:promotions', false)`);
  await fails('catégorie inconnue refusée', `select set_notification_preference('inapp', 'cat:autre', false)`, /Catégorie inconnue/);
  await db.exec('reset role');
  await db.exec(`insert into notifications(user_id, kind, title, body) values ('${U(21)}', 'alert', 'Prix', 'baisse'), ('${U(21)}', 'order', 'Commande', 'ok')`);
  check('catégorie coupée : alerte non créée', (await q(`select 1 from notifications where user_id = '${U(21)}' and kind = 'alert'`)).length === 0);
  check('catégorie active : commande créée', (await q(`select 1 from notifications where user_id = '${U(21)}' and kind = 'order'`)).length === 1);

  // 4. canaux : consentement explicite et coordonnée valide, filtrage par type
  await as(U(24));
  await fails('SMS sans numéro valide refusé', `select set_notification_preference('sms', '*', true)`, /numéro de téléphone/);
  await fails('WhatsApp sans numéro refusé', `select set_notification_preference('whatsapp', '*', true)`, /WhatsApp/);
  await fails('numéro WhatsApp invalide refusé', `select set_whatsapp_number('12')`, /invalide/);
  await as(U(21));
  await fails('SMS refusé tant que le téléphone n\'est pas vérifié', `select set_notification_preference('sms', '*', true)`, /vérifié/);
  await db.exec('reset role');
  await db.exec(`update profiles set phone_verified = true where id = '${U(21)}'`);
  await as(U(21));
  await fails('WhatsApp : un autre numéro que le numéro vérifié est refusé', `select set_whatsapp_number('6 55 00 11 22')`, /vérifié/);
  check('numéro WhatsApp normalisé (numéro vérifié)', (await q(`select set_whatsapp_number('6 77 00 00 21') n`))[0].n === '+237677000021');
  await q(`select set_notification_preference('whatsapp', '*', true)`);
  await q(`select set_notification_preference('sms', '*', true)`);
  await db.exec('reset role');
  await db.exec(`delete from notification_outbox`);
  await db.exec(`insert into notifications(user_id, kind, title, body) values ('${U(21)}', 'message', 'Nouveau message', 'texte privé')`);
  check('message : ni SMS ni WhatsApp sans choix explicite pour ce type', (await q(`select 1 from notification_outbox where kind = 'message' and channel in ('sms','whatsapp','email')`)).length === 0);
  await db.exec(`insert into notifications(user_id, kind, title, body) values ('${U(21)}', 'order', 'Commande payée', 'ok')`);
  const out = await q(`select channel, to_address from notification_outbox where kind = 'order' order by channel`);
  check('commande : SMS et WhatsApp au numéro vérifié du profil', out.length === 2 && out.find((r) => r.channel === 'sms')?.to_address === '+237677000021' && out.find((r) => r.channel === 'whatsapp')?.to_address === '+237677000021', JSON.stringify(out));
  await as(U(21));
  await q(`select set_notification_preference('whatsapp', 'message', true)`);
  await db.exec('reset role');
  await db.exec(`delete from notification_outbox; insert into notifications(user_id, kind, title, body) values ('${U(21)}', 'message', 'Nouveau message', 'x')`);
  check('message : WhatsApp après choix explicite pour ce type', (await q(`select 1 from notification_outbox where kind = 'message' and channel = 'whatsapp'`)).length === 1);

  // 5. appareils web : hôtes de services push connus seulement
  await as(U(21));
  const sub = (host) => JSON.stringify({ endpoint: `https://${host}/wpush/abcdefghijklmnop`, keys: { p256dh: 'x', auth: 'y' } }).replace(/'/g, "''");
  check('appareil web : FCM accepté', (await q(`select register_device('${sub('fcm.googleapis.com')}', 'web') r`))[0].r === 'registered');
  await fails('appareil web : hôte arbitraire refusé', `select register_device('${sub('internal.example.com')}', 'web')`, /non reconnu/);
  await fails('appareil web : hôte à identifiants refusé', `select register_device('{"endpoint":"https://fcm.googleapis.com@evil.example/x","keys":{}}', 'web')`, /non reconnu/);
  await fails('appareil web : http refusé', `select register_device('{"endpoint":"http://fcm.googleapis.com/x","keys":{}}', 'web')`, /non reconnu/);

  // 6. signalement : support et admin notifiés, lecture réservée
  await db.exec('reset role');
  const cv = (await q(`insert into conversations(listing_id, created_by) values (null, '${U(21)}') returning id`))[0].id;
  await db.exec(`insert into conversation_participants(conversation_id, user_id) values ('${cv}', '${U(21)}'), ('${cv}', '${U(24)}')`);
  await db.exec(`insert into messages(conversation_id, sender_id, body) values ('${cv}', '${U(24)}', 'Message gênant')`);
  await as(U(21));
  await q(`select report_conversation('${cv}', 'Propos déplacés')`);
  await db.exec('reset role');
  check('signalement : support et admin notifiés', (await q(`select 1 from notifications where kind = 'message_report'`)).length === 2);
  await as(U(21));
  await fails('signalements : lecture refusée à un client', `select message_reports_list()`, /non autorisée/);
  await as(U(22));
  const rep = (await q(`select message_reports_list() l`))[0].l;
  check('signalements : le support lit le motif et les messages', rep.length === 1 && rep[0].reason === 'Propos déplacés' && rep[0].messages.length === 1, JSON.stringify(rep));
  await q(`select message_report_set_status('${rep[0].id}', 'closed')`);
  check('signalements : clos, la liste ouverte est vide', (await q(`select message_reports_list() l`))[0].l.length === 0);

  // 7. événements : inscription, notification, à venir, rappel
  await db.exec('reset role');
  const ev = (await q(`insert into events(title, kind, starts_at, place, price, capacity, status) values ('Atelier L6', 'atelier', now() + interval '10 hours', 'Salle B2', 0, 1, 'published') returning id`))[0].id;
  const far = (await q(`insert into events(title, kind, starts_at, status) values ('Salon lointain', 'salon', now() + interval '90 days', 'published') returning id`))[0].id;
  await as(U(21));
  check('événement : inscription', (await q(`select event_register('${ev}') r`))[0].r === 'registered');
  check('événement : déjà inscrit', (await q(`select event_register('${ev}') r`))[0].r === 'already');
  await as(U(24));
  await fails('événement : plus de places', `select event_register('${ev}')`, /Plus de places/);
  await db.exec('reset role');
  check('événement : notification de confirmation', (await q(`select 1 from notifications where user_id = '${U(21)}' and kind = 'event' and title = 'Inscription enregistrée'`)).length === 1);
  await as(U(21));
  const up = (await q(`select events_upcoming(10, null) l`))[0].l;
  check('à venir : événement lointain inclus, inscription reconnue', up.length === 2 && up.find((e) => e.id === ev)?.mine === true && up.some((e) => e.id === far), JSON.stringify(up));
  check('à venir : filtre par type', (await q(`select events_upcoming(10, 'salon') l`))[0].l.length === 1);
  await db.exec('reset role');
  check('rappel : envoyé la veille, une seule fois', (await q(`select send_event_reminders() n`))[0].n === 1 && (await q(`select send_event_reminders() n`))[0].n === 0);

  // 8. département : fiche réelle
  const inst = (await q(`insert into institutions(name, short_name, city, status) values ('Institut L6', 'IL6', 'Douala', 'verified') returning id`))[0].id;
  const dep = (await q(`insert into departments(institution_id, name, status) values ('${inst}', 'Génie L6', 'verified') returning id`))[0].id;
  await db.exec(`update profiles set department_id = '${dep}', skills = 'Flutter, SQL' where id = '${U(24)}'`);
  await db.exec(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${U(24)}', 'student_card', 'c', '${U(24)}/c.pdf', 'application/pdf', 10, 'verified')`);
  await as(null, 'anon');
  const dv = (await q(`select department_detail('${dep}') d`))[0].d;
  check('département : fiche visiteur sans étudiants à la une', dv.name === 'Génie L6' && dv.students === 1 && dv.featured.length === 0, JSON.stringify(dv));
  await as(U(21));
  const dc = (await q(`select department_detail('${dep}') d`))[0].d;
  check('département : étudiants à la une pour un compte connecté', dc.featured.length === 1 && dc.featured[0].name === 'Profil L6 24', JSON.stringify(dc));
  check('département : inconnu renvoie null', (await q(`select department_detail('${U(99)}') d`))[0].d === null);

  // 9. vitrine
  await db.exec('reset role');
  check('vitrine : appel sans erreur', Array.isArray((await q(`select showcase_listings(4) l`))[0].l));

  console.log(`${ok}/${ok + ko}`);
}
