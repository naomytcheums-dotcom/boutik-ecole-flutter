"""Inventaire LECTURE SEULE des comptes zz-test en production (transaction read only, via tool/audit/prod_readonly_probe.q)."""
import json, os, sys
sys.path.insert(0, r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter\tool\audit')
sys.stdout.reconfigure(encoding='utf-8')
from prod_readonly_probe import q
OUT = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter\FINALISATION_PROJET_1\donnees'
ZZ = "(select id from auth.users where email ~ '^zz-test-[a-z0-9-]+@example\\.com$')"
res = {}
res['comptes'] = q(f"""select left(u.id::text, 8) as id8, u.email, u.created_at, u.last_sign_in_at, u.email_confirmed_at is not null as confirme,
  p.role, p.name, (select count(*) from auth.mfa_factors f where f.user_id = u.id) as facteurs_mfa,
  (select count(*) from auth.sessions s where s.user_id = u.id) as sessions,
  (select count(*) from auth.identities i where i.user_id = u.id) as identites
  from auth.users u left join public.profiles p on p.id = u.id where u.id in {ZZ} order by u.created_at""")
res['totaux'] = q(f"select (select count(*) from auth.users) as comptes_total, (select count(*) from {ZZ} z) as comptes_zz, (select count(*) from auth.users where email like '%@example.com') as comptes_example_com, (select count(*) from public.profiles) as profils_total")
# toutes les clés étrangères vers auth.users ou public.profiles, puis décompte des lignes rattachées aux comptes zz
res['dependances'] = q(f"""with fk as (
  select n.nspname as sch, c.relname as tab, a.attname as col, ft.relname as cible, con.confdeltype as suppr
  from pg_constraint con join pg_class c on c.oid = con.conrelid join pg_namespace n on n.oid = c.relnamespace
  join pg_class ft on ft.oid = con.confrelid join pg_namespace fn on fn.oid = ft.relnamespace
  join pg_attribute a on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
  where con.contype = 'f' and array_length(con.conkey, 1) = 1 and ((fn.nspname = 'auth' and ft.relname = 'users') or (fn.nspname = 'public' and ft.relname = 'profiles')))
  select sch, tab, col, cible, case suppr when 'c' then 'cascade' when 'n' then 'set null' when 'a' then 'aucune action' when 'r' then 'restrict' else suppr::text end as a_la_suppression,
  (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from %I.%I where %I in {ZZ.replace("'", "''")}', sch, tab, col), false, true, '')))[1]::text::int as lignes_zz
  from fk order by lignes_zz desc, sch, tab""")
res['commandes'] = q(f"select left(o.id::text,8) as id8, o.created_at, o.paid, o.cancelled_at is not null as annulee , (select count(*) from public.order_lines ol where ol.order_id = o.id) as lignes from public.orders o where o.buyer_id in {ZZ} order by o.created_at")
res['annonces'] = q(f"select left(l.id::text,8) as id8, l.title, l.status, l.created_at from public.listings l where l.seller_id in {ZZ}")
res['lignes_reelles_sur_annonces_zz'] = q(f"select count(*) as n from public.order_lines ol where ol.listing_id in (select id from public.listings where seller_id in {ZZ}) and ol.order_id not in (select id from public.orders where buyer_id in {ZZ})")
res['fichiers'] = q(f"select bucket_id, count(*) as n, coalesce(sum((metadata->>'size')::bigint),0) as octets from storage.objects where owner in {ZZ} group by bucket_id")
res['fichiers_sans_proprietaire'] = q("select bucket_id, count(*) as n, coalesce(sum((metadata->>'size')::bigint),0) as octets from storage.objects where owner is null group by bucket_id")
res['buckets'] = q("select b.id, b.public, b.file_size_limit, (select count(*) from storage.objects o where o.bucket_id = b.id) as objets, (select coalesce(sum((o.metadata->>'size')::bigint),0) from storage.objects o where o.bucket_id = b.id) as octets from storage.buckets b order by b.id")
json.dump(res, open(os.path.join(OUT, 'zz_test_inventaire_production.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1, default=str)
print(json.dumps({k: v for k, v in res.items() if k != 'dependances'}, ensure_ascii=False, indent=1, default=str))
print('dependances non nulles:', [d for d in res['dependances'] if d['lignes_zz']])
print('nb FK examinees:', len(res['dependances']))

