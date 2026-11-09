-- Audit d'accès (qualification) : tentatives réelles d'élévation de droits et de lecture croisée, en anonyme puis en étudiant, sur la base locale miroir.
-- Résultat attendu : aucune ligne « FAILLE ». Les écritures sont exécutées dans une transaction annulée.
\pset format unaligned
\pset fieldsep ' | '
begin;
create temp table r (n serial, test text, result text);
grant all on r to public; grant usage on sequence r_n_seq to public;
do $$ declare t text; tot bigint; vis bigint; begin
  for t in select table_name from information_schema.role_table_grants where table_schema='public' and grantee='anon' and privilege_type='SELECT' order by 1 loop
    execute format('select count(*) from public.%I', t) into tot;
    set local role anon;
    begin execute format('select count(*) from public.%I', t) into vis; exception when others then vis := -1; end;
    reset role;
    insert into r(test, result) values ('anon lit '||t, vis||' / '||tot||' lignes');
  end loop;
end $$;
select set_config('request.jwt.claims', json_build_object('sub','a7ae1021-2bc7-437b-b7af-bd7d6422c5ab','role','authenticated')::text, false);
set role authenticated;
do $$ declare n int; begin
  begin update profiles set role='admin' where id='a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; get diagnostics n=row_count; insert into r(test,result) values ('élévation : profiles.role = admin (soi)', case when n>0 then 'FAILLE' else 'refusé' end); exception when others then insert into r(test,result) values ('élévation : profiles.role = admin (soi)','refusé: '||left(sqlerrm,60)); end;
  begin update profiles set role='admin' where id='c4dcc973-7b3a-40e8-ac60-c63abb47c6c4'; get diagnostics n=row_count; insert into r(test,result) values ('modifier le profil d''un autre', case when n>0 then 'FAILLE' else 'refusé' end); exception when others then insert into r(test,result) values ('modifier le profil d''un autre','refusé: '||left(sqlerrm,60)); end;
  begin update profiles set certification='approved' where id='a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; get diagnostics n=row_count; insert into r(test,result) values ('auto-certification', case when n>0 then 'FAILLE' else 'refusé' end); exception when others then insert into r(test,result) values ('auto-certification','refusé: '||left(sqlerrm,60)); end;
  begin update orders set paid=true where true; get diagnostics n=row_count; insert into r(test,result) values ('marquer une commande payée', case when n>0 then 'FAILLE ('||n||')' else 'refusé' end); exception when others then insert into r(test,result) values ('marquer une commande payée','refusé: '||left(sqlerrm,60)); end;
  begin delete from orders where true; get diagnostics n=row_count; insert into r(test,result) values ('supprimer des commandes', case when n>0 then 'FAILLE ('||n||')' else 'refusé' end); exception when others then insert into r(test,result) values ('supprimer des commandes','refusé: '||left(sqlerrm,60)); end;
  begin update listings set status='approved' where seller_id='a7ae1021-2bc7-437b-b7af-bd7d6422c5ab' and status<>'approved'; get diagnostics n=row_count; insert into r(test,result) values ('auto-approuver ses annonces', case when n>0 then 'FAILLE ('||n||')' else 'refusé' end); exception when others then insert into r(test,result) values ('auto-approuver ses annonces','refusé: '||left(sqlerrm,60)); end;
  begin update listings set price=1 where seller_id<>'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; get diagnostics n=row_count; insert into r(test,result) values ('modifier l''annonce d''un autre', case when n>0 then 'FAILLE ('||n||')' else 'refusé' end); exception when others then insert into r(test,result) values ('modifier l''annonce d''un autre','refusé: '||left(sqlerrm,60)); end;
  begin delete from audit_log where true; get diagnostics n=row_count; insert into r(test,result) values ('effacer le journal d''audit', case when n>0 then 'FAILLE ('||n||')' else 'refusé' end); exception when others then insert into r(test,result) values ('effacer le journal d''audit','refusé: '||left(sqlerrm,60)); end;
  begin insert into audit_log(actor,action,target,category) values ('faux','Action truquée','x','x'); insert into r(test,result) values ('écrire une fausse entrée d''audit','FAILLE'); exception when others then insert into r(test,result) values ('écrire une fausse entrée d''audit','refusé: '||left(sqlerrm,60)); end;
  begin select count(*) into n from audit_log; insert into r(test,result) values ('lire le journal d''audit (étudiant)', n||' lignes visibles'); exception when others then insert into r(test,result) values ('lire le journal d''audit (étudiant)','refusé'); end;
  begin select count(*) into n from orders where buyer_id<>'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; insert into r(test,result) values ('lire les commandes d''autres acheteurs', n||' lignes visibles'); exception when others then insert into r(test,result) values ('lire les commandes d''autres acheteurs','refusé'); end;
  begin select count(*) into n from profiles where id<>'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; insert into r(test,result) values ('lire les profils des autres', n||' profils visibles'); exception when others then insert into r(test,result) values ('lire les profils des autres','refusé'); end;
  begin select count(*) into n from payment_transactions where payer_id<>'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; insert into r(test,result) values ('lire les paiements des autres', n||' lignes visibles'); exception when others then insert into r(test,result) values ('lire les paiements des autres','refusé'); end;
  begin select count(*) into n from user_documents where owner_id<>'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; insert into r(test,result) values ('lire les documents privés des autres', n||' lignes visibles'); exception when others then insert into r(test,result) values ('lire les documents privés des autres','refusé'); end;
  begin select count(*) into n from notifications where user_id<>'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; insert into r(test,result) values ('lire les notifications des autres', n||' lignes visibles'); exception when others then insert into r(test,result) values ('lire les notifications des autres','refusé'); end;
  begin select count(*) into n from messages where conversation_id not in (select conversation_id from conversation_participants where user_id='a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'); insert into r(test,result) values ('lire les messages de conversations tierces', n||' lignes visibles'); exception when others then insert into r(test,result) values ('lire les messages de conversations tierces','refusé'); end;
  begin perform finance_overview(); insert into r(test,result) values ('finance_overview (étudiant)','FAILLE'); exception when others then insert into r(test,result) values ('finance_overview (étudiant)','refusé: '||left(sqlerrm,40)); end;
  begin perform staff_missions(); insert into r(test,result) values ('staff_missions (étudiant)','FAILLE'); exception when others then insert into r(test,result) values ('staff_missions (étudiant)','refusé: '||left(sqlerrm,40)); end;
  begin perform plan_set('vendeur_pro','x',1,true); insert into r(test,result) values ('plan_set (étudiant)','FAILLE'); exception when others then insert into r(test,result) values ('plan_set (étudiant)','refusé: '||left(sqlerrm,40)); end;
  begin perform setting_set('zz.test','1'::jsonb); insert into r(test,result) values ('setting_set (étudiant)','FAILLE'); exception when others then insert into r(test,result) values ('setting_set (étudiant)','refusé: '||left(sqlerrm,40)); end;
  begin perform payment_set_status('00000000-0000-0000-0000-000000000000','confirmed',null); insert into r(test,result) values ('payment_set_status (étudiant)','FAILLE'); exception when others then insert into r(test,result) values ('payment_set_status (étudiant)','refusé: '||left(sqlerrm,40)); end;
  begin truncate table orders; insert into r(test,result) values ('TRUNCATE orders (étudiant)','FAILLE'); exception when others then insert into r(test,result) values ('TRUNCATE orders (étudiant)','refusé: '||left(sqlerrm,40)); end;
end $$;
reset role;
select n, test, result from r order by n;
rollback;
