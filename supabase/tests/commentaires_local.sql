-- Tests serveur de la migration 20261103000000 (commentaires, enregistrements, partages) sur la base LOCALE ISOLÉE (Docker
-- supabase_db_boutik_local). Données fictives uniquement ; tout est supprimé à la fin. Ne jamais exécuter sur une autre base.
-- Usage : docker exec -i supabase_db_boutik_local psql -U postgres -v ON_ERROR_STOP=0 < supabase/tests/commentaires_local.sql

\set A '''c05948bb-3ef0-491e-be5a-93e92f6a19aa'''
\set B '''74197c6c-3b42-48b1-b1e7-fe21b9d2b651'''
\set DEPT '''612763ab-8c63-432b-a6b5-2b23ab7d5590'''

create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;

-- jeu fictif : 1 publication publiée de B, 1 publication en attente de B
insert into posts (id, author_id, media_path, media_kind, caption, status, published_at)
values ('00000000-0000-0000-0000-0000000000a1', :B, 'test/a.jpg', 'image', 'Publication de test publiée', 'published', now()),
       ('00000000-0000-0000-0000-0000000000a2', :B, 'test/b.jpg', 'image', 'Publication de test en attente', 'pending', null);

-- T1 : anonyme ----------------------------------------------------------------------------------
set role anon;
do $$ begin
  begin perform add_post_comment('00000000-0000-0000-0000-0000000000a1', 'bonjour'); insert into res(test,ok,detail) values ('T1a anonyme ne peut pas commenter', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T1a anonyme ne peut pas commenter', true, sqlerrm); end;
  begin insert into post_comments (post_id, author_id, body) values ('00000000-0000-0000-0000-0000000000a1', gen_random_uuid(), 'x'); insert into res(test,ok,detail) values ('T1b insertion directe refusée (anonyme)', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T1b insertion directe refusée (anonyme)', true, sqlerrm); end;
  insert into res(test,ok,detail) values ('T1c anonyme lit la liste (vide)', (select count(*) from post_comment_list('00000000-0000-0000-0000-0000000000a1')) = 0, '');
end $$;
reset role;

-- T2 : utilisateur A --------------------------------------------------------------------------------
select set_config('request.jwt.claims', json_build_object('sub', 'c05948bb-3ef0-491e-be5a-93e92f6a19aa', 'role', 'authenticated')::text, false);
set role authenticated;
do $$
declare c1 uuid; c2 uuid; n int; r text;
begin
  c1 := add_post_comment('00000000-0000-0000-0000-0000000000a1', '  Superbe réalisation !  ');
  insert into res(test,ok,detail) values ('T2a commentaire créé', c1 is not null, '');
  insert into res(test,ok,detail) values ('T2b texte rogné', (select body from post_comments where id = c1) = 'Superbe réalisation !', '');
  c2 := add_post_comment('00000000-0000-0000-0000-0000000000a1', 'Réponse', c1);
  insert into res(test,ok,detail) values ('T2c réponse à un commentaire', (select parent_id from post_comments where id = c2) = c1, '');
  begin perform add_post_comment('00000000-0000-0000-0000-0000000000a1', 'x', c2); insert into res(test,ok,detail) values ('T2d réponse à une réponse refusée', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T2d réponse à une réponse refusée', true, sqlerrm); end;
  begin perform add_post_comment('00000000-0000-0000-0000-0000000000a1', '   '); insert into res(test,ok,detail) values ('T2e commentaire vide refusé', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T2e commentaire vide refusé', true, sqlerrm); end;
  begin perform add_post_comment('00000000-0000-0000-0000-0000000000a1', repeat('a', 501)); insert into res(test,ok,detail) values ('T2f 501 caractères refusés', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T2f 501 caractères refusés', true, sqlerrm); end;
  begin perform add_post_comment('00000000-0000-0000-0000-0000000000a2', 'x'); insert into res(test,ok,detail) values ('T2g publication non publiée refusée', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T2g publication non publiée refusée', true, sqlerrm); end;
  begin insert into post_comments (post_id, author_id, body) values ('00000000-0000-0000-0000-0000000000a1', 'c05948bb-3ef0-491e-be5a-93e92f6a19aa', 'direct'); insert into res(test,ok,detail) values ('T2h insertion directe refusée (connecté)', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T2h insertion directe refusée (connecté)', true, sqlerrm); end;
  -- anti-spam : 10 par minute au total (2 déjà créés)
  for i in 1..8 loop perform add_post_comment('00000000-0000-0000-0000-0000000000a1', 'spam ' || i); end loop;
  begin perform add_post_comment('00000000-0000-0000-0000-0000000000a1', 'onzième'); insert into res(test,ok,detail) values ('T2i limite de 10 par minute', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T2i limite de 10 par minute', sqlerrm like 'Trop de commentaires%', sqlerrm); end;
  -- enregistrement
  insert into res(test,ok,detail) values ('T2j enregistrer', toggle_post_save('00000000-0000-0000-0000-0000000000a1') = true, '');
  select saved::text into r from reels_feed(10) where id = '00000000-0000-0000-0000-0000000000a1';
  insert into res(test,ok,detail) values ('T2k feed : saved vrai pour A', r = 'true', coalesce(r,'(absent)'));
  select saves into n from reels_feed(10) where id = '00000000-0000-0000-0000-0000000000a1';
  insert into res(test,ok,detail) values ('T2l feed : 1 enregistrement', n = 1, n::text);
  insert into res(test,ok,detail) values ('T2m retirer', toggle_post_save('00000000-0000-0000-0000-0000000000a1') = false, '');
  select comments into n from reels_feed(10) where id = '00000000-0000-0000-0000-0000000000a1';
  insert into res(test,ok,detail) values ('T2n feed : 10 commentaires', n = 10, n::text);
  perform record_post_share('00000000-0000-0000-0000-0000000000a1'); perform record_post_share('00000000-0000-0000-0000-0000000000a1');
  select shares into n from reels_feed(10) where id = '00000000-0000-0000-0000-0000000000a1';
  insert into res(test,ok,detail) values ('T2o partage compté une fois par personne', n = 1, n::text);
end $$;
reset role;

-- T3 : utilisateur B (auteur de la publication) ---------------------------------------------------
select set_config('request.jwt.claims', json_build_object('sub', '74197c6c-3b42-48b1-b1e7-fe21b9d2b651', 'role', 'authenticated')::text, false);
set role authenticated;
do $$
declare c uuid; n int; r text; owner uuid;
begin
  select id into c from post_comments where body = 'Superbe réalisation !';
  begin perform delete_post_comment(c); insert into res(test,ok,detail) values ('T3a B ne peut pas supprimer le commentaire de A', false, 'accepté');
  exception when others then insert into res(test,ok,detail) values ('T3a B ne peut pas supprimer le commentaire de A', sqlerrm = 'Action non autorisée', sqlerrm); end;
  select saved::text into r from reels_feed(10) where id = '00000000-0000-0000-0000-0000000000a1';
  insert into res(test,ok,detail) values ('T3b feed : saved faux pour B', r = 'false', coalesce(r,'(absent)'));
  select count(*) into n from post_comment_list('00000000-0000-0000-0000-0000000000a1');
  insert into res(test,ok,detail) values ('T3c B voit les 10 commentaires', n = 10, n::text);
  select count(*) into n from post_comment_list('00000000-0000-0000-0000-0000000000a1') where mine;
  insert into res(test,ok,detail) values ('T3d aucun n''est « mine » pour B', n = 0, n::text);
end $$;
reset role;

-- T4 : modération (département) et suppression par l'auteur ------------------------------------
select set_config('request.jwt.claims', json_build_object('sub', '612763ab-8c63-432b-a6b5-2b23ab7d5590', 'role', 'authenticated')::text, false);
set role authenticated;
do $$
declare c uuid; r text; n int;
begin
  select id into c from post_comments where body = 'spam 1';
  r := delete_post_comment(c);
  insert into res(test,ok,detail) values ('T4a le département masque', r = 'masqué', r);
  select count(*) into n from post_comment_list('00000000-0000-0000-0000-0000000000a1');
  insert into res(test,ok,detail) values ('T4b le commentaire masqué disparaît de la liste', n = 9, n::text);
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c05948bb-3ef0-491e-be5a-93e92f6a19aa', 'role', 'authenticated')::text, false);
set role authenticated;
do $$
declare c uuid; r text; n int;
begin
  select id into c from post_comments where body = 'Superbe réalisation !';
  r := delete_post_comment(c);
  insert into res(test,ok,detail) values ('T4c l''auteur supprime son commentaire', r = 'supprimé', r);
  select count(*) into n from post_comments where parent_id = c;
  insert into res(test,ok,detail) values ('T4d ses réponses sont supprimées avec lui (cascade)', n = 0, n::text);
  select count(*) into n from post_comments where body = 'spam 1';
  insert into res(test,ok,detail) values ('T4e A voit encore son commentaire masqué (lecture propriétaire)', n = 1, n::text);
end $$;
reset role;

-- T5 : visiteur et lecture du fil -----------------------------------------------------------------
set role anon;
do $$ declare n int; r text; begin
  select saved::text into r from reels_feed(10) where id = '00000000-0000-0000-0000-0000000000a1';
  insert into res(test,ok,detail) values ('T5a visiteur : fil lisible, saved faux', r = 'false', coalesce(r,'(absent)'));
end $$;
do $$ declare n int; begin
  begin select count(*) into n from post_saves; insert into res(test,ok,detail) values ('T5b visiteur ne lit pas les enregistrements', false, 'lecture permise');
  exception when others then insert into res(test,ok,detail) values ('T5b visiteur ne lit pas les enregistrements', true, sqlerrm); end;
end $$;
reset role;

select n, case when ok then 'PASS' else 'FAIL' end as resultat, test, detail from res order by n;
select count(*) filter (where ok) as reussis, count(*) filter (where not ok) as echoues, count(*) as total from res;

-- nettoyage des données fictives
delete from posts where id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');
select 'reste après nettoyage' as controle, (select count(*) from post_comments) as commentaires, (select count(*) from post_saves) as enregistrements, (select count(*) from post_shares) as partages, (select count(*) from posts) as publications;
