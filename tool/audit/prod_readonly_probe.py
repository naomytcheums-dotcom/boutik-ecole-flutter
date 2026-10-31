"""Inspection en LECTURE SEULE d'une base Supabase (production liée ou base locale), pour l'audit des migrations.

Garde-fous :
 - n'accepte qu'une requête unique commençant par SELECT ou WITH (aucun point-virgule interne) ;
 - l'exécute dans « begin transaction read only; … ; commit; » : PostgreSQL refuse toute écriture ;
 - n'affiche jamais de secret (aucune lecture de vault, auth.users limitée aux décomptes).

Usage (module) : from prod_readonly_probe import q ; q("select ...", target="linked")   # ou target="local"
Usage (CLI)    : python tool/audit/prod_readonly_probe.py linked "select 1"
"""
import json, os, re, subprocess, sys

CLI = ["npx", "-y", "supabase@2.122.0", "db", "query", "--output-format", "json"]
FORBIDDEN = re.compile(r"\b(insert|update|delete|drop|alter|create|grant|revoke|truncate|comment|vacuum|copy|call|do|set|reset|lock|refresh|cluster|reindex|security|execute)\b", re.I)


def q(sql: str, target: str = "linked"):
    s = sql.strip().rstrip(";")
    s = " ".join(s.splitlines())  # cmd.exe (npx.cmd) coupe la commande au premier retour à la ligne
    if ";" in s or not re.match(r"^\s*(select|with)\b", s, re.I):
        raise SystemExit("Refusé : une seule requête SELECT/WITH est autorisée.")
    # mots-clés d'écriture hors chaînes littérales
    bare = re.sub(r"'(?:[^']|'')*'", "''", s)
    if FORBIDDEN.search(re.sub(r"\b(pg_get_functiondef|security_definer|prosecdef|current_setting)\b", "", bare)):
        raise SystemExit("Refusé : mot-clé d'écriture détecté dans la requête.")
    full = f"begin transaction read only; {s}; commit;"
    if target == "local":
        db = os.environ.get("BE_DB", "supabase_db_boutik_local")
        r = subprocess.run(["docker", "exec", "-i", db, "psql", "-U", "postgres", "-t", "-A", "-q", "-v", "ON_ERROR_STOP=1"],
                           input=f"begin transaction read only; select coalesce(json_agg(x), '[]'::json) from ({s}) x; commit;",
                           capture_output=True, text=True, encoding="utf-8")
        if r.returncode:
            raise SystemExit(f"Échec de la requête locale : {r.stderr.strip()[-400:]}")
        return json.loads(r.stdout.strip() or "[]")
    args = CLI + ["--linked", full]
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", shell=(os.name == "nt"),
                       cwd=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")) if target == "linked" else os.path.expanduser("~/boutik_local"))
    out = r.stdout[r.stdout.find("{"):] if "{" in r.stdout else ""
    if r.returncode or not out:
        raise SystemExit(f"Échec de la requête ({r.returncode}) : {r.stderr.strip()[-400:]}")
    return json.loads(out)["rows"]


if __name__ == "__main__":
    print(json.dumps(q(sys.argv[2], sys.argv[1]), ensure_ascii=False, indent=1, default=str))
