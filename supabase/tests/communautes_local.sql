-- Tests serveur de la migration 20261103000100 (communautés, rôles, modération, notifications sociales).
-- BASE LOCALE ISOLÉE UNIQUEMENT (Docker supabase_db_boutik_local), comptes fictifs « Test … ». Les données créées sont supprimées à la fin.
-- Usage : docker exec -i supabase_db_boutik_local psql -U postgres < supabase/tests/communautes_local.sql

create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;

-- A = propriétaire (étudiant), B = membre (étudiant), C et D = clients extérieurs, S = support (personnel de la plateforme)
create or replace function pg_temp.as_user(p_id text) returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, false);
  set role authenticated;
end $$;
create or replace function pg_temp.as_anon() returns void language plpgsql as $$
begin reset role; perform set_config('request.jwt.claims', '{"role":"anon"}', false); set role anon; end $$;
-- attend une erreur dont le message commence par p_like
create or replace function pg_temp.refuse(p_test text, p_sql text, p_like text) returns void language plpgsql as $$
begin
  begin execute p_sql; insert into res(test, ok, detail) values (p_test, false, 'accepté');
  exception when others then insert into res(test, ok, detail) values (p_test, sqlerrm like p_like, sqlerrm); end;
end $$;
create or replace function pg_temp.ok(p_test text, p_cond boolean, p_detail text default '') returns void language plpgsql as $$
begin insert into res(test, ok, detail) values (p_test, coalesce(p_cond, false), p_detail); end $$;
-- lecture des notifications d'une personne SANS passer par la politique de lecture (le test vérifie l'événement, pas l'accès)
create or replace function pg_temp.notif(p_user text, p_kind text, p_data_user text default null) returns integer language sql security definer as $$
  select count(*)::int from public.notifications where user_id = p_user::uuid and kind = p_kind and (p_data_user is null or (data->>'user') = p_data_user)
$$;
grant execute on all functions in schema pg_temp to public;

\set A 'c05948bb-3ef0-491e-be5a-93e92f6a19aa'
\set B '74197c6c-3b42-48b1-b1e7-fe21b9d2b651'
\set C '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set D '41c9e35e-cdee-4c1f-8068-817dccd55867'
\set S 'fbee9999-a07e-4700-be3f-caf5977b77a5'

-- ------------------------------------------------------------------ création
select pg_temp.as_user(:'A');
select set_config('t.pub', create_community('Développeurs du Cameroun (test)', 'Échanges entre développeurs', 'tech', 'public', 'Respect et entraide')::text, false);
select set_config('t.apr', create_community('Designers et créatifs (test)', 'Design', 'design', 'approval')::text, false);
select set_config('t.inv', create_community('Cercle fermé (test)', 'Sur invitation', 'business', 'invite')::text, false);
select pg_temp.ok('C1 création : le créateur est propriétaire actif', (select role = 'owner' and status = 'active' from community_members where community_id = current_setting('t.pub')::uuid and user_id = :'A'));
select pg_temp.refuse('C2 nom en double refusé (insensible à la casse)', $$select create_community('  développeurs du cameroun (TEST) ')$$, 'Une communauté porte déjà ce nom%');
select pg_temp.refuse('C3 nom trop court refusé', $$select create_community('ab')$$, 'Le nom doit contenir%');
select pg_temp.refuse('C4 confidentialité inconnue refusée', $$select create_community('Nom valide test', '', '', 'secret')$$, 'Confidentialité inconnue');
select create_community('Quatrième (test)', '', '', 'public'); select create_community('Cinquième (test)', '', '', 'public');
select pg_temp.refuse('C5 plus de 5 communautés par personne', $$select create_community('Sixième (test)')$$, 'Vous ne pouvez pas créer plus de 5%');
select pg_temp.as_anon();
select pg_temp.refuse('C6 anonyme ne peut pas créer', $$select create_community('Visiteur test')$$, 'permission denied%');
select pg_temp.ok('C7 anonyme voit l''annuaire public et sur approbation, pas l''invitation', (select count(*) from communities_list('(test)', 50) where privacy = 'invite') = 0 and (select count(*) from communities_list('(test)', 50) where privacy in ('public','approval')) = 4);

-- ------------------------------------------------------------------ communauté publique
select pg_temp.as_user(:'B');
select pg_temp.ok('P1 B rejoint la communauté publique', join_community(current_setting('t.pub')::uuid) = 'joined');
select pg_temp.ok('P2 rejoindre deux fois renvoie already', join_community(current_setting('t.pub')::uuid) = 'already');
select pg_temp.ok('P3 B publie dans la communauté', create_community_post(current_setting('t.pub')::uuid, 'Bonjour à tous, voici mon projet.') is not null);
select pg_temp.refuse('P4 publication vide refusée', format($$select create_community_post(%L, '   ')$$, current_setting('t.pub')), 'La publication doit contenir%');
select pg_temp.as_user(:'C');
select pg_temp.refuse('P5 un extérieur ne peut pas publier', format($$select create_community_post(%L, 'intrus')$$, current_setting('t.pub')), 'Réservé aux membres%');
select pg_temp.ok('P6 un extérieur lit le fil d''une communauté publique', (select count(*) from community_feed(current_setting('t.pub')::uuid)) = 1);
select pg_temp.as_anon();
select pg_temp.ok('P7 anonyme lit la publication d''une communauté publique (table)', (select count(*) from posts where community_id = current_setting('t.pub')::uuid) = 1);
select pg_temp.ok('P8 les publications de communauté ne passent pas dans le fil des reels', (select count(*) from reels_feed(50) where id in (select id from posts where community_id is not null)) = 0);

-- ------------------------------------------------------------------ sur approbation
select pg_temp.as_user(:'B');
select pg_temp.ok('Q1 demande d''adhésion : en attente', join_community(current_setting('t.apr')::uuid) = 'pending');
select pg_temp.ok('Q2 le propriétaire est notifié', pg_temp.notif(:'A', 'community_request', :'B') = 1);
select pg_temp.refuse('Q3 en attente : ne peut pas publier', format($$select create_community_post(%L, 'x')$$, current_setting('t.apr')), 'Réservé aux membres%');
select pg_temp.refuse('Q4 B ne peut pas décider de sa propre demande', format($$select decide_join_request(%L, %L, true)$$, current_setting('t.apr'), :'B'), 'Action non autorisée');
select pg_temp.as_user(:'D');
select join_community(current_setting('t.apr')::uuid);
select pg_temp.as_user(:'A');
select pg_temp.ok('Q5 le propriétaire voit 2 demandes', (select count(*) from community_requests(current_setting('t.apr')::uuid)) = 2);
select pg_temp.ok('Q6 acceptation', decide_join_request(current_setting('t.apr')::uuid, :'B', true) = 'accepted');
select pg_temp.ok('Q7 refus', decide_join_request(current_setting('t.apr')::uuid, :'D', false) = 'rejected');
select pg_temp.ok('Q8 B est notifié de l''acceptation', pg_temp.notif(:'B', 'community_accept') = 1);
select pg_temp.ok('Q9 D est notifié du refus', pg_temp.notif(:'D', 'community_reject') = 1);
select pg_temp.refuse('Q10 aucune demande en attente', format($$select decide_join_request(%L, %L, true)$$, current_setting('t.apr'), :'D'), 'Aucune demande en attente');
select pg_temp.as_user(:'B');
select pg_temp.ok('Q11 B (accepté) publie dans la communauté sur approbation', create_community_post(current_setting('t.apr')::uuid, 'Premier message') is not null);

-- ------------------------------------------------------------------ sur invitation
select pg_temp.as_user(:'C');
select pg_temp.refuse('I1 rejoindre sans invitation refusé', format($$select join_community(%L)$$, current_setting('t.inv')), 'Cette communauté est accessible sur invitation%');
select pg_temp.ok('I2 l''invitation est invisible dans l''annuaire pour un extérieur', (select count(*) from communities_list('Cercle', 10)) = 0);
select pg_temp.ok('I3 la table communities masque la communauté invitation', (select count(*) from communities where id = current_setting('t.inv')::uuid) = 0);
select pg_temp.as_user(:'B');
select pg_temp.refuse('I4 un simple membre ne peut pas inviter', format($$select invite_member(%L, %L)$$, current_setting('t.pub'), :'C'), 'Action non autorisée');
select pg_temp.as_user(:'A');
select pg_temp.ok('I5 le propriétaire invite C', invite_member(current_setting('t.inv')::uuid, :'C') = 'invited');
select pg_temp.refuse('I6 inviter deux fois refusé', format($$select invite_member(%L, %L)$$, current_setting('t.inv'), :'C'), 'Cette personne est déjà liée%');
select pg_temp.ok('I7 C est notifié', pg_temp.notif(:'C', 'community_invite') = 1);
select pg_temp.as_user(:'C');
select pg_temp.ok('I8 C voit la communauté invitée', (select count(*) from communities_list('Cercle', 10)) = 1);
select pg_temp.ok('I9 C accepte l''invitation', join_community(current_setting('t.inv')::uuid) = 'joined');
select pg_temp.ok('I10 C publie dans le cercle fermé', create_community_post(current_setting('t.inv')::uuid, 'Message privé du cercle') is not null);
select pg_temp.as_user(:'D');
select pg_temp.ok('I11 un extérieur ne lit pas le fil du cercle fermé', (select count(*) from community_feed(current_setting('t.inv')::uuid)) = 0);
select pg_temp.ok('I12 ni la table posts (RLS)', (select count(*) from posts where community_id = current_setting('t.inv')::uuid) = 0);
select pg_temp.as_anon();
select pg_temp.ok('I13 anonyme : rien non plus', (select count(*) from posts where community_id = current_setting('t.inv')::uuid) = 0);
select pg_temp.as_user(:'S');
select pg_temp.ok('I14 le personnel de la plateforme y a accès', (select count(*) from community_feed(current_setting('t.inv')::uuid)) = 1);

-- ------------------------------------------------------------------ rôles et bannissement
select pg_temp.as_user(:'A');
select pg_temp.ok('R1 le propriétaire nomme B modérateur', set_member_role(current_setting('t.pub')::uuid, :'B', 'moderator') = 'moderator');
select pg_temp.as_user(:'B');
select pg_temp.refuse('R2 un modérateur ne change pas les rôles', format($$select set_member_role(%L, %L, 'admin')$$, current_setting('t.pub'), :'A'), 'Action non autorisée');
select pg_temp.as_user(:'C');
select join_community(current_setting('t.pub')::uuid);
select pg_temp.as_user(:'A');
select pg_temp.ok('R3 le propriétaire nomme C administrateur', set_member_role(current_setting('t.pub')::uuid, :'C', 'admin') = 'admin');
select pg_temp.as_user(:'C');
select pg_temp.refuse('R4 un administrateur ne touche pas au propriétaire', format($$select set_member_role(%L, %L, 'member')$$, current_setting('t.pub'), :'A'), 'Vous ne pouvez pas modifier%');
select pg_temp.refuse('R5 un administrateur ne nomme pas d''administrateur', format($$select set_member_role(%L, %L, 'admin')$$, current_setting('t.pub'), :'B'), 'Seul le propriétaire%');
select pg_temp.as_user(:'B');
select pg_temp.refuse('R6 un modérateur ne bannit pas un administrateur', format($$select ban_member(%L, %L)$$, current_setting('t.pub'), :'C'), 'Vous ne pouvez pas bannir%');
select pg_temp.as_user(:'D');
select join_community(current_setting('t.pub')::uuid);
select pg_temp.as_user(:'B');
select pg_temp.ok('R7 un modérateur bannit un membre', ban_member(current_setting('t.pub')::uuid, :'D') = 'banned');
select pg_temp.as_user(:'D');
select pg_temp.refuse('R8 un banni ne peut pas revenir', format($$select join_community(%L)$$, current_setting('t.pub')), 'Accès refusé%');
select pg_temp.refuse('R9 un banni ne peut pas publier', format($$select create_community_post(%L, 'x')$$, current_setting('t.pub')), 'Réservé aux membres%');
select leave_community(current_setting('t.pub')::uuid);
select pg_temp.ok('R10 quitter ne lève pas le bannissement', (select status from community_members where community_id = current_setting('t.pub')::uuid and user_id = :'D') = 'banned');
select pg_temp.as_user(:'A');
select pg_temp.refuse('R11 le propriétaire ne peut pas quitter', format($$select leave_community(%L)$$, current_setting('t.pub')), 'Le propriétaire ne peut pas quitter%');
select pg_temp.as_user(:'B');
select pg_temp.refuse('R12 personne ne peut bannir le propriétaire', format($$select ban_member(%L, %L)$$, current_setting('t.pub'), :'A'), 'Vous ne pouvez pas bannir%');
select pg_temp.refuse('R13 insertion directe dans community_members refusée', format($$insert into community_members (community_id, user_id, role) values (%L, %L, 'owner')$$, current_setting('t.pub'), :'D'), 'permission denied%');
select pg_temp.refuse('R14 insertion directe dans communities refusée', format($$insert into communities (name, owner_id) values ('Pirate test', %L)$$, :'B'), 'permission denied%');

-- ------------------------------------------------------------------ modération des publications
select pg_temp.as_user(:'B');
select set_config('t.post', (select id::text from posts where community_id = current_setting('t.pub')::uuid and author_id = :'B' limit 1), false);
select pg_temp.as_user(:'C');
select pg_temp.ok('M1 un administrateur masque une publication', moderate_community_post(current_setting('t.post')::uuid, true) = 'hidden');
select pg_temp.as_user(:'D');
select pg_temp.ok('M2 le fil ne la montre plus', (select count(*) from community_feed(current_setting('t.pub')::uuid)) = 0);
select pg_temp.refuse('M3 un banni ne modère pas', format($$select moderate_community_post(%L, false)$$, current_setting('t.post')), 'Action non autorisée');
select pg_temp.as_user(:'B');
select pg_temp.ok('M4 l''auteur voit encore sa publication masquée (RLS)', (select count(*) from posts where id = current_setting('t.post')::uuid) = 1);

-- ------------------------------------------------------------------ notifications sociales
select pg_temp.as_user(:'B');
select engage('follow', :'A');
select pg_temp.ok('N1 suivre crée une notification « Nouvel abonné »', pg_temp.notif(:'A', 'follow', :'B') = 1);
select engage('follow', :'B');
select pg_temp.ok('N2 se suivre soi-même ne notifie personne', pg_temp.notif(:'B', 'follow') = 0);
reset role;
insert into posts (id, author_id, media_path, media_kind, caption, status, published_at) values ('00000000-0000-0000-0000-0000000000b1', :'A', 'test/c.jpg', 'image', 'Reel de test', 'published', now());
select pg_temp.as_user(:'B');
select add_post_comment('00000000-0000-0000-0000-0000000000b1', 'Bravo !');
select pg_temp.as_user(:'A');
select add_post_comment('00000000-0000-0000-0000-0000000000b1', 'Merci à moi-même');
select pg_temp.ok('N3 un commentaire notifie l''auteur de la publication, pas soi-même', pg_temp.notif(:'A', 'comment') = 1);
reset role;
select pg_temp.ok('N4 aucun envoi réel : e-mail et SMS désactivés par défaut, aucun appareil push', (select count(*) from notification_outbox o join notifications n on n.id = o.notification_id where n.kind in ('follow','comment','community_request','community_accept','community_reject','community_invite')) = 0);

select n, case when ok then 'PASS' else 'FAIL' end as resultat, test, detail from res order by n;
select count(*) filter (where ok) as reussis, count(*) filter (where not ok) as echoues, count(*) as total from res;

-- nettoyage : toutes les données de test
reset role;
delete from posts where id = '00000000-0000-0000-0000-0000000000b1' or community_id in (select id from communities where name like '%(test)');
delete from communities where name like '%(test)';
delete from notifications where kind in ('follow','comment','community_request','community_accept','community_reject','community_invite') and created_at > now() - interval '1 hour';
delete from engagements where kind = 'follow' and user_id in (:'B') and ref in (:'A', :'B');
select 'reste après nettoyage' as controle, (select count(*) from communities) as communautes, (select count(*) from community_members) as membres, (select count(*) from post_comments) as commentaires;
