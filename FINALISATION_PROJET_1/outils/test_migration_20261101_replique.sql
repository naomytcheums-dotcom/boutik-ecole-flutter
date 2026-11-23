-- Tests de la migration 20261101000000 sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE (aucune donnée conservée).
-- Chaque cas affiche « RESULT|cas|PASS|détail » ou « RESULT|cas|FAIL|détail ». Rôles simulés comme PostgREST (role + request.jwt.claims).
\set ON_ERROR_STOP off
\set A1 'c8332c75-ae70-4685-8589-d6ab77667e16'
\set A2 'f16e0765-2b18-45ee-a967-b46a6b1b9117'
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set C2 '41c9e35e-cdee-4c1f-8068-817dccd55867'
\set S1 'fbee9999-a07e-4700-be3f-caf5977b77a5'
\set D1 '612763ab-8c63-432b-a6b5-2b23ab7d5590'
\set L1 '19f1709b-a543-4752-be96-984fb93958b7'
begin;
\ir ../../supabase/migrations/20261101000000_administration_comptes_signalements.sql
create temp table t_ctx as select :'C2'::uuid as c2, :'L1'::uuid as l1, :'A1'::uuid as a1, :'A2'::uuid as a2;
grant select on t_ctx to authenticated, anon;
-- session factice du compte C2 (pour vérifier sa fermeture à la suspension)
insert into auth.sessions (id, user_id, created_at, updated_at, aal) values (gen_random_uuid(), :'C2', now(), now(), 'aal1');
-- signalement factice (annulé à la fin) sur une annonce existante
insert into listing_reports (id, listing_id, reporter_id, reason, status) values ('00000000-0000-4000-8000-000000000001', :'L1', :'C1', 'fraud', 'open');

-- T1 un client ne peut pas modifier un compte
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform admin_set_account((select c2 from t_ctx), 'student', false); raise notice 'RESULT|T1 client refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T1 client refusé|PASS|%', sqlerrm; end $$;
-- T10b RLS : un client ne lit que son profil
do $$ declare n int; begin select count(*) into n from profiles; if n = 1 then raise notice 'RESULT|T10b RLS client : 1 profil visible|PASS|%', n; else raise notice 'RESULT|T10b RLS client : 1 profil visible|FAIL|%', n; end if; end $$;
-- T9a un client ne peut pas changer le statut d'un signalement
do $$ begin perform set_report_status('00000000-0000-4000-8000-000000000001', 'closed'); raise notice 'RESULT|T9a client refusé (signalement)|FAIL|accepté';
exception when others then raise notice 'RESULT|T9a client refusé (signalement)|PASS|%', sqlerrm; end $$;
reset role;

-- T2..T6 en administrateur A1
select set_config('request.jwt.claims', json_build_object('sub', :'A1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from profiles; raise notice 'RESULT|T10a RLS admin : tous les profils visibles|%|%', case when n > 1 then 'PASS' else 'FAIL' end, n; end $$;
do $$ declare r jsonb; begin r := admin_set_account((select c2 from t_ctx), 'student', false);
  if (select role::text from profiles where id = (select c2 from t_ctx)) = 'student' and (r->>'changed')::boolean then raise notice 'RESULT|T2 admin change le rôle|PASS|%', r;
  else raise notice 'RESULT|T2 admin change le rôle|FAIL|%', r; end if;
exception when others then raise notice 'RESULT|T2 admin change le rôle|FAIL|%', sqlerrm; end $$;
do $$ declare r jsonb; begin r := admin_set_account((select c2 from t_ctx), 'student', true); raise notice 'RESULT|T3 admin suspend (appel)|PASS|%', r;
exception when others then raise notice 'RESULT|T3 admin suspend (appel)|FAIL|%', sqlerrm; end $$;
do $$ begin perform admin_set_account((select a1 from t_ctx), 'client', false); raise notice 'RESULT|T5 modification de soi refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|T5 modification de soi refusée|PASS|%', sqlerrm; end $$;
do $$ begin perform admin_set_account((select c2 from t_ctx), 'visitor', false); raise notice 'RESULT|T6 rôle visitor refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T6 rôle visitor refusé|PASS|%', sqlerrm; end $$;
reset role;
-- T3 vérifications (en postgres) : profil suspendu, connexion bloquée, sessions fermées, journal
select 'RESULT|T3 suspension effective|' || case when p.suspended and u.banned_until > now() and (select count(*) from auth.sessions s where s.user_id = p.id) = 0 then 'PASS' else 'FAIL' end
  || '|suspendu=' || p.suspended || ' banned_until=' || coalesce(u.banned_until::text, 'null') || ' sessions=' || (select count(*) from auth.sessions s where s.user_id = p.id)
from profiles p join auth.users u on u.id = p.id where p.id = :'C2';
select 'RESULT|T2b journal d''audit|' || case when count(*) >= 2 then 'PASS' else 'FAIL' end || '|' || string_agg(action, ', ') from audit_log where category = 'Comptes' and created_at >= now() - interval '1 minute';

-- T4 réactivation
select set_config('request.jwt.claims', json_build_object('sub', :'A1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform admin_set_account((select c2 from t_ctx), 'student', false); exception when others then raise notice 'RESULT|T4 appel|FAIL|%', sqlerrm; end $$;
reset role;
select 'RESULT|T4 réactivation lève le blocage|' || case when not p.suspended and u.banned_until is null then 'PASS' else 'FAIL' end || '|banned_until=' || coalesce(u.banned_until::text, 'null')
from profiles p join auth.users u on u.id = p.id where p.id = :'C2';

-- T7 dernier administrateur actif : A1 suspendu, autres admins rétrogradés (en postgres, annulé), A1 tente de rétrograder A2
update profiles set role = 'client' where role = 'admin' and id not in (:'A1', :'A2');
alter table profiles disable trigger trg_protect_profile;
update profiles set suspended = true where id = :'A1';
alter table profiles enable trigger trg_protect_profile;
select set_config('request.jwt.claims', json_build_object('sub', :'A1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform admin_set_account((select a2 from t_ctx), 'client', false); raise notice 'RESULT|T7 dernier admin actif protégé|FAIL|accepté';
exception when others then raise notice 'RESULT|T7 dernier admin actif protégé|PASS|%', sqlerrm; end $$;
reset role;

-- T8 anonyme : aucun droit d'exécution
select set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
do $$ begin perform admin_set_account((select c2 from t_ctx), 'client', false); raise notice 'RESULT|T8 anonyme refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T8 anonyme refusé|PASS|%', sqlerrm; end $$;
do $$ begin perform set_report_status('00000000-0000-4000-8000-000000000001', 'closed'); raise notice 'RESULT|T8b anonyme refusé (signalement)|FAIL|accepté';
exception when others then raise notice 'RESULT|T8b anonyme refusé (signalement)|PASS|%', sqlerrm; end $$;
reset role;

-- T9 support : changement de statut, statut invalide refusé, lecture des signalements
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from listing_reports where id = '00000000-0000-4000-8000-000000000001'; raise notice 'RESULT|T9b support lit le signalement (RLS)|%|%', case when n = 1 then 'PASS' else 'FAIL' end, n; end $$;
do $$ declare r text; begin r := set_report_status('00000000-0000-4000-8000-000000000001', 'reviewing'); raise notice 'RESULT|T9c support passe en traitement|%|%', case when r = 'reviewing' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T9c support passe en traitement|FAIL|%', sqlerrm; end $$;
do $$ begin perform set_report_status('00000000-0000-4000-8000-000000000001', 'supprimé'); raise notice 'RESULT|T9d statut invalide refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T9d statut invalide refusé|PASS|%', sqlerrm; end $$;
reset role;
select 'RESULT|T9e statut enregistré et journalisé|' || case when (select status from listing_reports where id = '00000000-0000-4000-8000-000000000001') = 'reviewing'
  and exists (select 1 from audit_log where category = 'Modération' and action like 'Signalement : open → reviewing' and created_at >= now() - interval '1 minute') then 'PASS' else 'FAIL' end || '|';

-- T11 département : peut modérer, mais pas administrer les comptes
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform admin_set_account((select c2 from t_ctx), 'client', false); raise notice 'RESULT|T11 département refusé (comptes)|FAIL|accepté';
exception when others then raise notice 'RESULT|T11 département refusé (comptes)|PASS|%', sqlerrm; end $$;
reset role;
rollback;
select 'RESULT|T12 réplique inchangée après ROLLBACK|' || case when (select count(*) from pg_proc where proname in ('admin_set_account', 'set_report_status')) = 0
  and (select count(*) from listing_reports where id = '00000000-0000-4000-8000-000000000001') = 0 then 'PASS' else 'FAIL' end || '|';
