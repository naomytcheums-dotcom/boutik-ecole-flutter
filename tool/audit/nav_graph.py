"""Graphe de navigation réel de l'application, calculé sur le code actuel (lecture seule).

Sorties : tool/audit/out/graph.json, orphans.txt, demos.csv
Usage : python tool/audit/nav_graph.py
"""
import csv, glob, json, os, re
from collections import defaultdict, deque

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'tool', 'audit', 'out')
os.makedirs(OUT, exist_ok=True)

NAVCALL = re.compile(r"\b(?:gOpen|gTab)\s*\(")
TOK = re.compile(r"""['"]([0-9]+[a-z_0-9]*)['"]""")
DEMO = re.compile(r"""gToast\(\s*context\s*,\s*['"]D[ée]monstration\s*:\s*([^'"]*)['"]""")
FUNC = re.compile(r"^(?:[A-Za-z_<>?,\s]+?)\s+(\w+)\s*\([^;{]*\)\s*(?:async\s*)?\{", re.M)


def nav_targets(text):
    """Identifiants d'écran cités dans les appels gOpen/gTab (ternaires compris)."""
    out = set()
    for m in NAVCALL.finditer(text):
        seg = text[m.end(): m.end() + 160].split("\n")[0]
        depth, end = 1, len(seg)
        for i, ch in enumerate(seg):
            depth += {"(": 1, ")": -1}.get(ch, 0)
            if depth == 0:
                end = i
                break
        out.update(t.group(1) for t in TOK.finditer(seg[:end]))
    return out


screens = {os.path.basename(f)[2:-5]: f for f in sorted(glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart')))}
src = {sid: open(f, encoding='utf-8').read() for sid, f in screens.items()}

edges = defaultdict(set)
demos = []
for sid, s in src.items():
    edges[sid] |= {t for t in nav_targets(s) if t in screens}
    demos += [(sid, m.group(1)) for m in DEMO.finditer(s)]

# fonctions des modules métier : cibles de navigation contenues dans leur corps
func_targets = {}
for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'live', '*.dart')):
    s = open(f, encoding='utf-8').read()
    for m in FUNC.finditer(s):
        i, depth = m.end(), 1
        while i < len(s) and depth:
            depth += {'{': 1, '}': -1}.get(s[i], 0)
            i += 1
        t = {x for x in nav_targets(s[m.end():i]) if x in screens}
        if t:
            func_targets.setdefault(m.group(1), set()).update(t)
# menu du compte : ses entrées déclarent leur écran par « screen: 'id' » (le menu filtre ensuite par rôle)
_menu = open(os.path.join(ROOT, 'lib', 'figma', 'live', 'account_menu.dart'), encoding='utf-8').read()
func_targets.setdefault('accountMenu', set()).update(t for t in re.findall(r"screen:\s*'([0-9]+[a-z_0-9]*)'", _menu) if t in screens)
for sid, s in src.items():
    for name, t in func_targets.items():
        if re.search(r"\b" + re.escape(name) + r"\s*\(", s):
            edges[sid] |= t

reach, q = set(), deque(['01'])
while q:
    n = q.popleft()
    if n in reach:
        continue
    reach.add(n)
    q.extend(d for d in edges.get(n, ()) if d not in reach)


def key(x):
    d = re.sub(r"\D", "", x)
    return (int(d) if d else 10 ** 6, x)


orphans = sorted((s for s in screens if s not in reach), key=key)

json.dump({'screens': len(screens), 'reachable': sorted(reach, key=key), 'orphans': orphans,
           'edges': {k: sorted(v, key=key) for k, v in edges.items()}},
          open(os.path.join(OUT, 'graph.json'), 'w', encoding='utf-8'), ensure_ascii=False)
open(os.path.join(OUT, 'orphans.txt'), 'w', encoding='utf-8').write("\n".join(orphans))
with open(os.path.join(OUT, 'demos.csv'), 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['ecran', 'action'])
    w.writerows(demos)

by_screen = defaultdict(int)
for s, _ in demos:
    by_screen[s] += 1
print(f'ecrans : {len(screens)}')
print(f'atteignables depuis 01 par liens explicites : {len(reach)}')
print(f'non atteignables (orphelins) : {len(orphans)}')
print(f'actions Demonstration : {len(demos)} sur {len(by_screen)} ecrans')
