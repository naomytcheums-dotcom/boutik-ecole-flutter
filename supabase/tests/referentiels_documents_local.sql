-- Tests des référentiels, du profil académique, des documents privés et de la photo de profil sur la base LOCALE isolée.
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
\set ADMIN 'c8332c75-ae70-4685-8589-d6ab77667e16'
\set A 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'
\set B 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4'
-- nettoyage d'une exécution précédente (lignes créées par ce test uniquement)
delete from user_documents where owner_id in (:'A', :'B');
delete from departments where name like 'ZZ test%'; delete from institutions where name like 'ZZ test%';
update profiles set matricule = null, institution_id = null, department_id = null where id in (:'A', :'B');

set role anon;
do $$ declare j jsonb; begin j := institutions_search('douala'); insert into res(test,ok,detail) values ('R1 un visiteur cherche douala', jsonb_array_length(j) >= 2, jsonb_array_length(j)::text); end $$;
do $$ begin begin perform institution_propose('ZZ test école', 'Douala', 'ecole'); insert into res values (default,'R2 un visiteur ne propose pas', false, 'accepté'); exception when others then insert into res values (default,'R2 un visiteur ne propose pas', sqlerrm in ('Connexion requise') or sqlerrm like 'permission denied%', sqlerrm); end; end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, false);
set role authenticated;
create temp table ids (k text, v uuid); grant all on ids to public;
do $$ declare i1 uuid; i2 uuid; d uuid; begin
  i1 := institution_propose('ZZ test école', 'Douala', 'ecole'); i2 := institution_propose('zz TEST école', 'Douala', 'ecole');
  insert into res values (default,'R3 proposition : un seul enregistrement malgré la casse', i1 = i2, '');
  insert into ids values ('inst', i1);
  insert into res values (default,'R4 le proposeur la retrouve', jsonb_array_length(institutions_search('ZZ test')) = 1, '');
  d := department_propose(i1, 'ZZ test département');
  insert into ids values ('dept', d);
  insert into res values (default,'R5 département proposé visible du proposeur', jsonb_array_length(departments_list(i1)) = 1, '');
end $$;
-- matricule : valeur invalide refusée, vide acceptée, valeur réelle enregistrée telle que saisie (sans espaces)
do $$ declare i uuid := (select v from ids where k='inst'); d uuid := (select v from ids where k='dept'); begin
  begin perform profile_set_academic(i, d, 'a b!', null); insert into res values (default,'R6 matricule invalide refusé', false, 'accepté'); exception when others then insert into res values (default,'R6 matricule invalide refusé', sqlerrm='Matricule invalide', sqlerrm); end;
  perform profile_set_academic(i, d, '', 'Licence 2');
  insert into res values (default,'R7 matricule vide : reste nul', (select matricule is null and institution = 'ZZ test école' and department = 'ZZ test département' and study_level = 'Licence 2' from profiles where id = auth.uid()), '');
  perform profile_set_academic(i, d, '20 A/0412', null);
  insert into res values (default,'R8 matricule saisi enregistré', (select matricule = '20A/0412' from profiles where id = auth.uid()), '');
  begin perform profile_set_academic(null, d, null, null); insert into res values (default,'R9 département sans son établissement refusé', false, 'accepté'); exception when others then insert into res values (default,'R9 département sans son établissement refusé', sqlerrm like 'Département introuvable%', sqlerrm); end;
end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  insert into res values (default,'R10 un autre compte ne voit pas la proposition', jsonb_array_length(institutions_search('ZZ test')) = 0, '');
  begin perform reference_review('institution', (select v from ids where k='inst'), true); insert into res values (default,'R11 un étudiant ne relit pas', false, 'accepté'); exception when others then insert into res values (default,'R11 un étudiant ne relit pas', sqlerrm='Action non autorisée', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'ADMIN', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin perform reference_review('institution', (select v from ids where k='inst'), true); end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin insert into res values (default,'R12 après relecture, tout le monde la voit', jsonb_array_length(institutions_search('ZZ test')) = 1, ''); end $$;
reset role;

-- documents : dépôt simulé dans le stockage (les objets sont créés avec les droits complets, comme le ferait l'API de stockage)
insert into storage.objects (bucket_id, name, owner_id) values ('profile-documents', :'A' || '/certificat/1-cert.pdf', :'A'), ('avatars', :'A' || '/1-photo.jpg', :'A') on conflict do nothing;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare id1 uuid; begin
  begin perform document_register('certificate', current_setting('request.jwt.claims')::json->>'sub' || 'x', 'x.pdf', 'application/pdf', 100); exception when others then null; end;
  begin perform document_register('certificate', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4/x/1.pdf', 'x.pdf', 'application/pdf', 100); insert into res values (default,'D1 dépôt dans le dossier d''un autre refusé', false, 'accepté'); exception when others then insert into res values (default,'D1 dépôt dans le dossier d''un autre refusé', sqlerrm='Chemin de fichier non autorisé', sqlerrm); end;
  begin perform document_register('certificate', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab/x/absent.pdf', 'x.pdf', 'application/pdf', 100); insert into res values (default,'D2 fichier absent du stockage refusé', false, 'accepté'); exception when others then insert into res values (default,'D2 fichier absent du stockage refusé', sqlerrm='Fichier absent du stockage', sqlerrm); end;
  id1 := document_register('certificate', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab/certificat/1-cert.pdf', 'cert.pdf', 'application/pdf', 1234);
  insert into res values (default,'D3 document enregistré en attente', (select status = 'pending' from user_documents where id = id1), '');
  insert into res values (default,'D4 historique initial', (select count(*) = 1 from user_document_history where document_id = id1), '');
  insert into ids values ('doc', id1);
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  insert into res values (default,'D5 un autre compte ne voit pas le document', (select count(*) = 0 from user_documents where name = 'cert.pdf'), '');
  begin perform document_review((select v from ids where k='doc'), 'verified', null); insert into res values (default,'D6 un étudiant ne valide pas', false, 'accepté'); exception when others then insert into res values (default,'D6 un étudiant ne valide pas', sqlerrm='Action non autorisée', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'ADMIN', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  insert into res values (default,'D7 l''équipe voit le document', (select count(*) = 1 from user_documents where name = 'cert.pdf'), '');
  perform document_review((select v from ids where k='doc'), 'verified', 'conforme');
  insert into res values (default,'D8 validation historisée', (select count(*) = 2 from user_document_history where document_id = (select v from ids where k='doc')), '');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform document_delete((select v from ids where k='doc')); insert into res values (default,'D9 document vérifié non supprimable', false, 'accepté'); exception when others then insert into res values (default,'D9 document vérifié non supprimable', sqlerrm like 'Un document vérifié%', sqlerrm); end;
  perform profile_set_avatar('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab/1-photo.jpg', 'http://x/storage/v1/object/public/avatars/a7ae1021-2bc7-437b-b7af-bd7d6422c5ab/1-photo.jpg');
  insert into res values (default,'P1 photo de profil enregistrée', (select avatar_url like '%1-photo.jpg' from profiles where id = auth.uid()), '');
  begin perform profile_set_avatar('c4dcc973-7b3a-40e8-ac60-c63abb47c6c4/1.jpg', 'http://x/c4dcc973-7b3a-40e8-ac60-c63abb47c6c4/1.jpg'); insert into res values (default,'P2 photo d''un autre dossier refusée', false, 'accepté'); exception when others then insert into res values (default,'P2 photo d''un autre dossier refusée', sqlerrm='Chemin de fichier non autorisé', sqlerrm); end;
  perform profile_set_avatar('', '');
  insert into res values (default,'P3 suppression de la photo', (select avatar_url is null from profiles where id = auth.uid()), '');
end $$;
reset role;
-- nettoyage
delete from user_documents where owner_id in (:'A', :'B');
delete from departments where name like 'ZZ test%'; delete from institutions where name like 'ZZ test%';
update profiles set matricule = null, institution_id = null, department_id = null where id in (:'A', :'B');
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
