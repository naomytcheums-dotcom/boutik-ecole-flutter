"""Propose des liens fondés sur les libellés : un écran T est lié depuis un texte (bouton, ligne de menu, carte) qui porte son titre.

Lecture seule. Sortie : tool/audit/out/label_links.json  (cible -> [(écran source, x, y, w, h, texte)])
"""
import glob, json, os, re, unicodedata

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'tool', 'audit', 'out')
G = json.load(open(os.path.join(OUT, 'graph.json'), encoding='utf-8'))
orph = set(G['orphans'])
GT = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), gText\('((?:[^'\\]|\\.)*)', ([\d.]+)")


def norm(t):
    t = unicodedata.normalize('NFKD', t).encode('ascii', 'ignore').decode().lower()
    t = re.sub(r"[›>→↗·•]+", " ", t)
    return re.sub(r"[^a-z0-9 ]+", " ", t).strip()


texts = {}   # écran -> liste (x,y,w,h,texte,taille)
for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart')):
    sid = os.path.basename(f)[2:-5]
    s = open(f, encoding='utf-8').read()
    texts[sid] = [(float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)), m.group(5).replace("\\'", "'"), float(m.group(6))) for m in GT.finditer(s)]

titles = {}
for sid, ts in texts.items():
    c = [t for t in ts if 50 <= t[1] <= 140 and t[5] >= 13 and len(t[4]) >= 4]
    if c:
        titles[sid] = sorted(c, key=lambda t: (-t[5], t[1]))[0][4]

by_title = {}
for sid, t in titles.items():
    by_title.setdefault(norm(t), []).append(sid)

links = {}
for src, ts in texts.items():
    for (x, y, w, h, txt, sz) in ts:
        n = norm(txt)
        if len(n) < 4:
            continue
        for tgt in by_title.get(n, []):
            if tgt in orph and tgt != src:
                links.setdefault(tgt, []).append((src, x, y, w, h, txt))

json.dump({'titles': titles, 'links': links}, open(os.path.join(OUT, 'label_links.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print('orphelins avec un titre détecté :', sum(1 for o in orph if o in titles), '/', len(orph))
print('orphelins pouvant être reliés par libellé :', len(links))
for t, l in list(links.items())[:15]:
    print(t, '<-', [(a[0], a[5]) for a in l[:3]])
