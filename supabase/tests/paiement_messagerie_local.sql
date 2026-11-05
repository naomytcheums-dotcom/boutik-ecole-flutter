create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
create temp table ids (k text, v text); grant all on ids to public;
delete from payment_transactions where subject like 'ZZ test%';

-- paiement par messagerie
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; j jsonb; begin
  p := payment_start('order', 'ZZ test commande', 25000, 'manual');
  insert into ids values ('pay', p::text);
  j := payment_thread(p);
  insert into res values (default, 'P1 la demande génère deux messages système', jsonb_array_length(j->'messages') = 2 and j->>'status' = 'created', '');
  begin perform payment_start('order', 'x', 0, 'manual'); insert into res values (default, 'P2 montant nul refusé', false, 'accepté'); exception when others then insert into res values (default, 'P2 montant nul refusé', sqlerrm = 'Montant invalide', sqlerrm); end;
  begin perform payment_start('order', 'x', 1000, 'dikalo'); insert into res values (default, 'P3 prestataire non activé refusé', false, 'accepté'); exception when others then insert into res values (default, 'P3 prestataire non activé refusé', sqlerrm like 'Ce prestataire%', sqlerrm); end;
  begin perform payment_declare(p, 'ab'); insert into res values (default, 'P4 référence trop courte refusée', false, 'accepté'); exception when others then insert into res values (default, 'P4 référence trop courte refusée', sqlerrm like 'Référence%', sqlerrm); end;
  perform payment_declare(p, 'MP240101.1234');
  insert into res values (default, 'P5 déclaré : en attente', payment_thread(p)->>'status' = 'pending', '');
  begin perform payment_set_status(p, 'confirmed', null); insert into res values (default, 'P6 le payeur ne confirme pas', false, 'accepté'); exception when others then insert into res values (default, 'P6 le payeur ne confirme pas', sqlerrm = 'Action non autorisée', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; begin
  select v::uuid into p from ids where k = 'pay';
  begin perform payment_thread(p); insert into res values (default, 'P7 un tiers ne lit pas le fil', false, 'accepté'); exception when others then insert into res values (default, 'P7 un tiers ne lit pas le fil', sqlerrm = 'Paiement introuvable', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; begin
  select v::uuid into p from ids where k = 'pay';
  perform payment_set_status(p, 'confirmed', null);
  insert into res values (default, 'P8 la finance confirme', payment_thread(p)->>'status' = 'confirmed' and jsonb_array_length(payment_thread(p)->'messages') = 5, '');
  begin perform payment_set_status(p, 'failed', null); insert into res values (default, 'P9 un paiement confirmé ne change plus', false, 'accepté'); exception when others then insert into res values (default, 'P9 un paiement confirmé ne change plus', sqlerrm = 'Paiement déjà confirmé', sqlerrm); end;
end $$;
reset role;

delete from payment_transactions where subject like 'ZZ test%';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
