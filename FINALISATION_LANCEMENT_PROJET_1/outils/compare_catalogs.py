"""Compare deux instantanés de catalogue (catalog_snapshot.py) et liste les écarts objet par objet.

Usage : python compare_catalogs.py <a.json> <b.json> [--detail]
"""
import json, os, sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tool", "audit"))
from migration_audit import KEYS, index  # noqa: E402


def diff(a, b):
    out = {}
    for c in KEYS:
        x, y = index(a, c), index(b, c)
        only_a = sorted(set(x) - set(y))
        only_b = sorted(set(y) - set(x))
        changed = sorted(k for k in set(x) & set(y) if x[k] != y[k])
        if only_a or only_b or changed:
            out[c] = {"seulement_a": only_a, "seulement_b": only_b, "modifies": changed}
    return out


if __name__ == "__main__":
    a = json.load(open(sys.argv[1], encoding="utf-8"))
    b = json.load(open(sys.argv[2], encoding="utf-8"))
    d = diff(a, b)
    total = sum(len(v["seulement_a"]) + len(v["seulement_b"]) + len(v["modifies"]) for v in d.values())
    print("écarts :", total)
    for c, v in d.items():
        print(f" {c} : +a {len(v['seulement_a'])} / +b {len(v['seulement_b'])} / modifiés {len(v['modifies'])}")
        if "--detail" in sys.argv:
            for k in ("seulement_a", "seulement_b", "modifies"):
                for e in v[k][:40]:
                    print(f"    {k}: {e}")
