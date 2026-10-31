"""Compare les objets introduits par chaque migration (deltas d'instantanés étape par étape) avec le catalogue de production.

Usage : python tool/audit/migration_audit.py <dossier_etapes> <snap_prod.json> <sortie.json>
Statuts par objet :
  identique   — même clé et même définition en production que juste après la migration ;
  ulterieure  — présent, avec la définition d'une étape POSTÉRIEURE (la migration a été appliquée, puis remplacée) ;
  anterieure  — présent, avec la définition d'une étape ANTÉRIEURE (la migration ne l'a pas encore modifié en production) ;
  different   — présent, définition ne correspondant à aucune étape (modification manuelle) ;
  absent      — n'existe pas en production ;
  non_retire  — supprimé par la migration mais encore présent en production ;
  retire      — supprimé par la migration et absent en production.
"""
import glob, json, os, sys

KEYS = {
    "tables": (("t",), ("rls",)),
    "columns": (("t", "c"), ("ty", "n", "d")),
    "functions": (("f", "args"), ("body", "secdef", "cfg", "res", "vol")),
    "fn_exec": (("f", "args"), ("anon", "auth")),
    "policies": (("s", "t", "p"), ("cmd", "roles", "qual", "chk")),
    "triggers": (("t", "g"), ("f", "en")),
    "constraints": (("t", "k"), ("ty", "def")),
    "indexes": (("t", "i"), ("def",)),
    "enums": (("ty",), ("labels",)),
    "buckets": (("id",), ("public", "lim", "mimes")),
    "extensions": (("e",), ()),
    "grants": (("t", "g"), ("p",)),
    "column_grants": (("t", "c", "g", "p"), ()),
}


def index(snap, cat):
    kf, df = KEYS[cat]
    rows = snap.get(cat, [])
    if isinstance(rows, dict):
        return {}
    return {tuple(str(r[k]) for k in kf): tuple(str(r.get(d)) for d in df) for r in rows}


def main(stage_dir, prod_path, out_path):
    files = sorted(glob.glob(os.path.join(stage_dir, "[0-9][0-9]_*.json")))
    stages = [(os.path.basename(f)[3:-5], json.load(open(f, encoding="utf-8"))) for f in files]
    prod = json.load(open(prod_path, encoding="utf-8"))
    idx = [{c: index(s, c) for c in KEYS} for _, s in stages]
    pidx = {c: index(prod, c) for c in KEYS}
    report = []
    for i in range(1, len(stages)):
        name = stages[i][0]
        objs = []
        for cat in KEYS:
            before, after, p = idx[i - 1][cat], idx[i][cat], pidx[cat]
            for k, v in after.items():
                if before.get(k) == v:
                    continue
                kind = "ajout" if k not in before else "modif"
                if k not in p:
                    st = "absent"
                elif p[k] == v:
                    st = "identique"
                else:
                    later = [j for j in range(i + 1, len(stages)) if idx[j][cat].get(k) == p[k]]
                    earlier = [j for j in range(0, i) if idx[j][cat].get(k) == p[k]]
                    st = "ulterieure" if later else ("anterieure" if earlier else "different")
                objs.append({"cat": cat, "key": "|".join(k), "kind": kind, "prod": st})
            for k in before:
                if k not in after:
                    objs.append({"cat": cat, "key": "|".join(k), "kind": "suppression", "prod": "non_retire" if k in p else "retire"})
        counts = {}
        for o in objs:
            counts[o["prod"]] = counts.get(o["prod"], 0) + 1
        report.append({"migration": name, "objects": objs, "counts": counts})
    final = idx[-1]
    drift = [{"cat": c, "key": "|".join(k)} for c in KEYS for k in pidx[c] if k not in final[c]]
    json.dump({"migrations": report, "prod_only": drift}, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for r in report:
        print(f"{r['migration'][:58]:58} {r['counts']}")
    print("objets présents en production mais absents après toutes les migrations :", len(drift))
    for d in drift:
        print("   ", d["cat"], d["key"])


if __name__ == "__main__":
    main(*sys.argv[1:4])
