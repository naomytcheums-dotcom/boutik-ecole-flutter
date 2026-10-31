"""Construit sur la base ISOLÉE (Docker) une réplique exacte du schéma de production, puis la compare à la production.

Production : lecture seule uniquement (pg_dump du schéma « public » sans données, requêtes SELECT sur les catalogues).
Base locale : réinitialisée puis reconstruite (jamais la production).

Usage : python tool/audit/build_prod_replica.py [dossier_de_travail]
Résultat attendu : « écarts réplique / production : 0 ».
"""
import json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(__file__))
from catalog_snapshot import QUERIES  # noqa: E402
from migration_audit import KEYS, index  # noqa: E402
from prod_readonly_probe import q  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOCAL = os.path.expanduser("~/boutik_local")
DB = os.environ.get("BE_DB", "supabase_db_boutik_local")
NPX = ["npx", "-y", "supabase@2.122.0"]


def run(args, cwd=ROOT):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", shell=(os.name == "nt"))
    if r.returncode:
        raise SystemExit(f"échec : {' '.join(args)}\n{r.stderr[-600:]}")
    return r.stdout


def psql(path):
    r = subprocess.run(["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-q", "-v", "ON_ERROR_STOP=1"],
                       input=open(path, "rb").read(), capture_output=True)  # binaire : sous Windows, le mode texte changerait \n en \r\n dans les corps de fonctions
    if r.returncode:
        raise SystemExit(f"échec d'application de {path} : {r.stderr.decode(errors='replace')[-600:]}")


def snapshot(target):
    return {k: q(" ".join(v.split()), target) for k, v in QUERIES.items() if k not in ("rowcounts", "auth_cfg")}


def main(work):
    os.makedirs(work, exist_ok=True)
    schema, storage, grants = (os.path.join(work, n) for n in ("prod_public_schema.sql", "prod_storage.sql", "prod_grants.sql"))
    for attempt in range(3):  # le rôle temporaire de la CLI met parfois quelques secondes à être accepté par le pooler
        try:
            run(NPX + ["db", "dump", "--linked", "--schema", "public", "-f", schema])
            break
        except SystemExit:
            if attempt == 2:
                raise
    prod = snapshot("linked")
    b = q("select id, name, public, file_size_limit as lim, allowed_mime_types::text as mimes from storage.buckets order by 1", "linked")
    p = q("select policyname as p, cmd, array_to_string(roles, ',') as roles, qual, with_check as chk, permissive from pg_policies where schemaname = 'storage' order by 1", "linked")
    with open(storage, "w", encoding="utf-8") as f:
        for x in b:
            m = "'" + x["mimes"] + "'::text[]" if x["mimes"] else "null"
            f.write(f"insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('{x['id']}', '{x['name']}', {str(x['public']).lower()}, {x['lim'] or 'null'}, {m}) on conflict (id) do nothing;\n")
        for x in p:
            s = f'create policy "{x["p"]}" on storage.objects as {x["permissive"].lower()} for {x["cmd"].lower()} to {x["roles"]}'
            s += f" using ({x['qual']})" if x["qual"] else ""
            s += f" with check ({x['chk']})" if x["chk"] else ""
            f.write(s + ";\n")
    with open(grants, "w", encoding="utf-8") as f:
        for r in prod["tables"]:
            f.write(f'revoke all on table public."{r["t"]}" from anon, authenticated;\n')
        for r in prod["grants"]:
            f.write(f'grant {r["p"].replace(",", ", ")} on table public."{r["t"]}" to {r["g"]};\n')
        for r in prod["fn_exec"]:
            sig = f'public."{r["f"]}"({r["args"]})'
            f.write(f"revoke all on function {sig} from public, anon, authenticated;\n")
            f.write("".join(f"grant execute on function {sig} to {role};\n" for role, k in (("anon", "anon"), ("authenticated", "auth")) if r[k]))
    run(NPX + ["db", "reset", "--local"], cwd=LOCAL)
    for path in (schema, storage, grants):
        psql(path)
    rep = snapshot("local")
    total = 0
    for c in KEYS:
        a, b2 = index(prod, c), index(rep, c)
        diff = [k for k in set(a) | set(b2) if a.get(k) != b2.get(k)]
        total += len(diff)
        if diff:
            print(c, len(diff), sorted(diff)[:5])
    json.dump(prod, open(os.path.join(work, "snap_prod.json"), "w", encoding="utf-8"), ensure_ascii=False, default=str)
    print("écarts réplique / production :", total)
    if total == 0 and "--with-pending" in sys.argv:
        # état futur : graine de test puis migrations absentes de l'historique de production, dans l'ordre
        applied = {r["version"] for r in q("select version from supabase_migrations.schema_migrations", "linked")}
        pending = sorted(f for f in os.listdir(os.path.join(ROOT, "supabase", "migrations"))
                         if f.endswith(".sql") and f.split("_", 1)[0].isdigit() and f.split("_", 1)[0] not in applied)
        psql(os.path.join(ROOT, "tool", "audit", "replica_seed.sql"))
        for m in pending:
            psql(os.path.join(ROOT, "supabase", "migrations", m))
            print("appliquée sur la réplique :", m)
        subprocess.run(["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-q"], input=b"notify pgrst, 'reload schema';", capture_output=True)
    return total


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sys.exit(1 if main(args[0] if args else os.path.join(os.environ.get("TEMP", "/tmp"), "replica_prod")) else 0)
