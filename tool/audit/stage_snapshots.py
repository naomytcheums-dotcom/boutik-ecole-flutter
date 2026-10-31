"""Instantanés étape par étape sur la base ISOLÉE (Docker) : schema.sql, puis chaque migration dans l'ordre des noms.
Le delta entre deux instantanés donne exactement les objets créés ou modifiés par une migration.

Usage : python tool/audit/stage_snapshots.py <dossier_sortie>
Pré-requis : base locale réinitialisée (npx supabase db reset dans %USERPROFILE%\\boutik_local) — JAMAIS la production.
"""
import glob, json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(__file__))
from catalog_snapshot import QUERIES  # noqa: E402
from prod_readonly_probe import q  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DB = os.environ.get("BE_DB", "supabase_db_boutik_local")
SKIP = {"rowcounts", "auth_cfg"}


def apply(path):
    r = subprocess.run(["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-q", "-v", "ON_ERROR_STOP=1"],
                       input=open(path, "rb").read(), capture_output=True)  # binaire : sous Windows, le mode texte changerait \n en \r\n dans les corps de fonctions
    return r.returncode, r.stderr.decode(errors='replace').strip()[-600:]


def snap():
    return {k: q(" ".join(v.split()), "local") for k, v in QUERIES.items() if k not in SKIP}


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    steps = [os.path.join(ROOT, "supabase", "schema.sql")] + sorted(glob.glob(os.path.join(ROOT, "supabase", "migrations", "*.sql")))
    json.dump(snap(), open(os.path.join(out, "00_baseline.json"), "w", encoding="utf-8"), ensure_ascii=False, default=str)
    log = []
    for i, p in enumerate(steps, 1):
        rc, err = apply(p)
        name = os.path.basename(p)
        log.append({"step": i, "file": name, "rc": rc, "stderr": err})
        print(i, name, "rc", rc, err[:200] if rc else "")
        json.dump(snap(), open(os.path.join(out, f"{i:02d}_{name}.json"), "w", encoding="utf-8"), ensure_ascii=False, default=str)
    json.dump(log, open(os.path.join(out, "log.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
