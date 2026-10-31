"""Instantané des catalogues (lecture seule) pour comparer la production et la base isolée objet par objet.

Usage : python tool/audit/catalog_snapshot.py linked|local <fichier_sortie.json>
Aucune donnée personnelle : uniquement des définitions (empreintes MD5), des droits et des décomptes de lignes.
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(__file__))
from prod_readonly_probe import q  # noqa: E402

QUERIES = {
    "tables": """select c.relname as t, c.relrowsecurity as rls, c.relforcerowsecurity as force_rls
        from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' order by 1""",
    "columns": """select table_name as t, column_name as c, data_type as ty, is_nullable as n, coalesce(column_default, '') as d
        from information_schema.columns where table_schema = 'public' order by 1, 2""",
    "functions": """select p.proname as f, pg_get_function_identity_arguments(p.oid) as args, p.prosecdef as secdef,
        md5(p.prosrc) as body, coalesce(array_to_string(p.proconfig, ','), '') as cfg, coalesce(p.proacl::text, '') as acl,
        pg_get_function_result(p.oid) as res, p.provolatile as vol
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' order by 1, 2""",
    "policies": """select schemaname as s, tablename as t, policyname as p, cmd, array_to_string(roles, ',') as roles,
        md5(coalesce(qual, '')) as qual, md5(coalesce(with_check, '')) as chk
        from pg_policies where schemaname in ('public', 'storage') order by 1, 2, 3""",
    "triggers": """select c.relname as t, tg.tgname as g, p.proname as f, tg.tgenabled as en
        from pg_trigger tg join pg_class c on c.oid = tg.tgrelid join pg_namespace n on n.oid = c.relnamespace
        join pg_proc p on p.oid = tg.tgfoid where n.nspname = 'public' and not tg.tgisinternal order by 1, 2""",
    "constraints": """select cl.relname as t, co.conname as k, co.contype as ty, md5(pg_get_constraintdef(co.oid)) as def
        from pg_constraint co join pg_class cl on cl.oid = co.conrelid join pg_namespace n on n.oid = cl.relnamespace
        where n.nspname = 'public' order by 1, 2""",
    "indexes": """select tablename as t, indexname as i, md5(indexdef) as def from pg_indexes where schemaname = 'public' order by 1, 2""",
    "enums": """select t.typname as ty, string_agg(e.enumlabel, ',' order by e.enumsortorder) as labels
        from pg_type t join pg_enum e on e.enumtypid = t.oid join pg_namespace n on n.oid = t.typnamespace
        where n.nspname = 'public' group by 1 order by 1""",
    "buckets": """select id, public, file_size_limit as lim, coalesce(array_to_string(allowed_mime_types, ','), '') as mimes
        from storage.buckets order by 1""",
    "extensions": "select extname as e, extversion as v from pg_extension order by 1",
    "grants": """select table_name as t, grantee as g, string_agg(privilege_type, ',' order by privilege_type) as p
        from information_schema.role_table_grants where table_schema = 'public' and grantee in ('anon', 'authenticated')
        group by 1, 2 order by 1, 2""",
    "column_grants": """select table_name as t, column_name as c, grantee as g, privilege_type as p
        from information_schema.column_privileges where table_schema = 'public' and grantee in ('anon', 'authenticated')
        and table_name in ('api_keys') order by 1, 2, 3""",
    "fn_exec": """select p.proname as f, pg_get_function_identity_arguments(p.oid) as args,
        has_function_privilege('anon', p.oid, 'EXECUTE') as anon, has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' order by 1, 2""",
    "rowcounts": """select c.relname as t, c.reltuples::bigint as approx from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind = 'r' order by 1""",
    "auth_cfg": """select (select count(*) from auth.users) as users, (select count(*) from auth.users where email like 'zz-test-%@example.com') as test_users,
        (select count(*) from auth.mfa_factors) as mfa_factors""",
}

if __name__ == "__main__":
    target, out = sys.argv[1], sys.argv[2]
    snap = {}
    for k, sql in QUERIES.items():
        try:
            snap[k] = q(" ".join(sql.split()), target)
        except SystemExit as e:
            snap[k] = {"error": str(e)}
        print(k, len(snap[k]) if isinstance(snap[k], list) else snap[k])
    json.dump(snap, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
