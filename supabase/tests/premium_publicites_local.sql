create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
create temp table ids (k text, v text); grant all on ids to public;
delete from ad_campaigns where title like 'ZZ test%';
delete from posts where caption like 'ZZ test%';
delete from subscriptions where user_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab';
delete from payment_transactions where subject in ('plan:vendeur_pro') or subject like 'campagne:%';
delete from platform_settings where key = 'ads.cost_per_click';
update plans set price_xaf = null where code = 'vendeur_pro';
insert into posts (id, author_id, media_path, media_kind, caption, status, published_at) values ('55555555-5555-5555-5555-555555555555', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'zz/p.jpg', 'image', 'ZZ test post pub', 'published', now());

set role anon;
do $$ begin insert into res values (default, 'A1 un visiteur lit les plans', (select count(*) from plans) >= 5, ''); end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform subscription_start('vendeur_pro'); insert into res values (default, 'A2 plan sans prix non souscriptible', false, 'accepté'); exception when others then insert into res values (default, 'A2 plan sans prix non souscriptible', sqlerrm like 'Ce plan n''est pas encore disponible%', sqlerrm); end;
  begin perform plan_set('vendeur_pro', 'x', 5000, true); insert into res values (default, 'A3 un étudiant ne fixe pas les prix', false, 'accepté'); exception when others then insert into res values (default, 'A3 un étudiant ne fixe pas les prix', sqlerrm = 'Action non autorisée', sqlerrm); end;
end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
select plan_set('vendeur_pro', 'Vendeur professionnel', 5000, true);
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; begin
  p := subscription_start('vendeur_pro');
  insert into ids values ('subpay', p::text);
  insert into res values (default, 'A4 la souscription crée un paiement en attente', (payment_thread(p)->>'amount')::int = 5000 and payment_thread(p)->>'status' = 'created', '');
  begin perform subscription_start('vendeur_pro'); insert into res values (default, 'A5 double souscription refusée', false, 'accepté'); exception when others then insert into res values (default, 'A5 double souscription refusée', sqlerrm like 'Vous avez déjà%', sqlerrm); end;
  insert into res values (default, 'A6 aucun droit avant la confirmation du paiement', jsonb_array_length(my_entitlements()->'features') = 0, '');
  perform payment_declare(p, 'MP.123456');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; begin select v::uuid into p from ids where k = 'subpay'; perform payment_set_status(p, 'confirmed', null); end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare c uuid; pay uuid; begin
  insert into res values (default, 'A7 le paiement confirmé active les droits du plan', my_entitlements()->'features' @> '"boost_campagnes"'::jsonb, my_entitlements()::text);
  perform subscription_cancel();
  insert into res values (default, 'A8 annulation : droits conservés jusqu''à la fin de période', my_entitlements()->'features' @> '"boost_campagnes"'::jsonb, '');
  begin perform ad_campaign_save(null, 'ZZ test pub', 'x', null, null, 5000, null, null, null); insert into res values (default, 'B1 campagne sans contenu refusée', false, 'accepté'); exception when others then insert into res values (default, 'B1 campagne sans contenu refusée', sqlerrm like 'Choisissez une publication%', sqlerrm); end;
  c := ad_campaign_save(null, 'ZZ test pub', 'Promotion', '55555555-5555-5555-5555-555555555555', null, 5000, 2000, current_date, current_date + 5);
  insert into ids values ('ad', c::text);
  pay := ad_campaign_submit(c);
  insert into ids values ('adpay', pay::text);
  insert into res values (default, 'B2 la soumission attend le paiement du budget', (select status from ad_campaigns where id = c) = 'awaiting_payment', '');
  perform payment_declare(pay, 'MP.654321');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; c uuid; begin
  select v::uuid into p from ids where k = 'adpay'; select v::uuid into c from ids where k = 'ad';
  perform payment_set_status(p, 'confirmed', null);
  insert into res values (default, 'B3 paiement confirmé : en attente de validation', (select status from ad_campaigns where id = c) = 'pending_review', '');
  begin perform ad_campaign_review(c, false, null); insert into res values (default, 'B4 refus sans motif impossible', false, 'accepté'); exception when others then insert into res values (default, 'B4 refus sans motif impossible', sqlerrm = 'Motif de refus obligatoire', sqlerrm); end;
  perform ad_campaign_review(c, true, null);
  insert into res values (default, 'B5 campagne validée et active', (select status from ad_campaigns where id = c) = 'active', '');
  perform setting_set('ads.cost_per_click', '100'::jsonb);
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare c uuid; begin
  select v::uuid into c from ids where k = 'ad';
  insert into res values (default, 'B6 la pub est servie aux autres, marquée Sponsorisé', exists (select 1 from jsonb_array_elements(ad_feed(5)) e where e->>'id' = c::text and (e->>'sponsored')::boolean), '');
  perform ad_event_record(c, 'impression'); perform ad_event_record(c, 'impression'); perform ad_event_record(c, 'click'); perform ad_event_record(c, 'click');
  begin perform ad_campaign_toggle(c); insert into res values (default, 'B9 un tiers ne met pas en pause', false, 'accepté'); exception when others then insert into res values (default, 'B9 un tiers ne met pas en pause', sqlerrm = 'Campagne non modifiable', sqlerrm); end;
end $$;
reset role;
insert into res (test, ok, detail) select 'B8 le clic débite le coût par clic du réglage', (select spent_xaf from ad_campaigns where id = (select v::uuid from ids where k = 'ad')) = 100, '';
insert into res (test, ok, detail) select 'B7 événements dédoublonnés par personne et par jour', (select count(*) from ad_events where campaign_id = (select v::uuid from ids where k = 'ad')) = 2, '';
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare c uuid; begin
  select v::uuid into c from ids where k = 'ad';
  insert into res values (default, 'B10 la pub n''est pas servie à son propriétaire', not exists (select 1 from jsonb_array_elements(ad_feed(5)) e where e->>'id' = c::text), '');
  insert into res values (default, 'B11 les statistiques du propriétaire sont exactes', (select (e->>'clicks')::int from jsonb_array_elements(my_ad_campaigns()) e where e->>'id' = c::text) = 1, '');
  insert into res values (default, 'B12 pause puis reprise', ad_campaign_toggle(c) = 'paused' and ad_campaign_toggle(c) = 'active', '');
end $$;
reset role;

delete from ad_campaigns where title like 'ZZ test%';
delete from posts where caption like 'ZZ test%';
delete from subscriptions where user_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab';
delete from payment_transactions where subject in ('plan:vendeur_pro') or subject like 'campagne:%';
delete from platform_settings where key = 'ads.cost_per_click';
update plans set price_xaf = null where code = 'vendeur_pro';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
