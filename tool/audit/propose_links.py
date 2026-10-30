"""Propose, pour chaque écran non atteignable, un lien contextuel issu d'un libellé existant d'un écran déjà relié.

Lecture seule. Sortie : tool/audit/out/proposals.json  {cible: [(source, x, y, w, h, texte, score)]}
Principe : un écran est atteint depuis un texte (bouton, ligne, carte) dont les mots recoupent son titre, de préférence dans la même famille
(même centaine) et dans un écran déjà atteignable ; on itère jusqu'à stabilité pour que les chaînes de parcours se referment.
"""
import glob, json, os, re, unicodedata

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'tool', 'audit', 'out')
G = json.load(open(os.path.join(OUT, 'graph.json'), encoding='utf-8'))
L = json.load(open(os.path.join(OUT, 'label_links.json'), encoding='utf-8'))
titles = L['titles']
GT = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), gText\('((?:[^'\\]|\\.)*)', ([\d.]+)")
STOP = set('de du des la le les un une et en a au aux pour sur mon ma mes votre vos ce cet cette par dans avec d l'.split())


def norm(t):
    t = unicodedata.normalize('NFKD', t).encode('ascii', 'ignore').decode().lower()
    return re.sub(r"[^a-z0-9 ]+", " ", t)


def toks(t):
    return {w for w in norm(t).split() if w not in STOP and len(w) > 2}


texts = {}
for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart')):
    sid = os.path.basename(f)[2:-5]
    s = open(f, encoding='utf-8').read()
    texts[sid] = [(float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)), m.group(5).replace("\\'", "'"), float(m.group(6)))
                  for m in GT.finditer(s)]


def fam(i):
    m = re.match(r'\d+', i)
    return int(m.group(0)) // 10 if m else -1


reach = set(G['reachable']) if 'reachable' in G else set(G['nodes']) - set(G['orphans'])
orph = set(G['orphans'])
props = {}
edges = []
changed = True
while changed:
    changed = False
    for tgt in sorted(orph - set(p for p in props)):
        tt = toks(titles.get(tgt, ''))
        if not tt:
            continue
        best = None
        for src in reach:
            if src == tgt:
                continue
            for (x, y, w, h, txt, sz) in texts.get(src, []):
                if y < 100 or y > 800 or sz < 11 or len(txt) < 4:
                    continue
                ot = toks(txt)
                if not ot:
                    continue
                inter = len(tt & ot)
                if inter == 0:
                    continue
                score = inter / len(tt | ot) + (0.25 if fam(src) == fam(tgt) else 0) + (0.1 if abs(fam(src) - fam(tgt)) == 1 else 0)
                if best is None or score > best[0]:
                    best = (score, src, x, y, w, h, txt)
        if best and best[0] >= 0.45:
            props[tgt] = best
            reach.add(tgt)
            edges.append((best[1], tgt))
            changed = True
json.dump({t: list(v) for t, v in props.items()}, open(os.path.join(OUT, 'proposals.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
print('propositions :', len(props), '/', len(orph))
left = sorted(orph - set(props))
print('sans proposition :', len(left))
print(' '.join(f"{t}:{titles.get(t, '?')}" for t in left).encode('ascii', 'replace').decode()[:3000])
