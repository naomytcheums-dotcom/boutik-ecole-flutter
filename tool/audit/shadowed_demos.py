"""Détecte les gestionnaires « Démonstration » masqués par un vrai bouton posé par-dessus (gTap sur la même zone) et les retire.

Usage : python tool/audit/shadowed_demos.py          (rapport)
        python tool/audit/shadowed_demos.py --apply  (retire les gestionnaires factices et fige les écrans touchés)
"""
import glob, json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
apply = '--apply' in sys.argv
GP = re.compile(r"gP\(([\d.\-]+), ([\d.\-]+), ([\d.]+), ([\d.]+), ")
GTAP = re.compile(r"gTap\(([\d.\-]+), ([\d.\-]+), ([\d.]+), ([\d.]+), ")
DEMO = re.compile(r", tap: \(\) => gToast\(context, 'D[ée]monstration : [^']*'\)")


def iou(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ix = max(0, min(ax + aw, bx + bw) - max(ax, bx))
    iy = max(0, min(ay + ah, by + bh) - max(ay, by))
    inter = ix * iy
    union = aw * ah + bw * bh - inter
    return inter / union if union else 0


total = shadowed = 0
touched = []
for f in sorted(glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart'))):
    sid = os.path.basename(f)[2:-5]
    lines = open(f, encoding='utf-8').read().split('\n')
    taps = []
    for l in lines:
        m = GTAP.search(l)
        if m and 'Démonstration' not in l:
            taps.append(tuple(float(m.group(i)) for i in range(1, 5)))
    changed = False
    for i, l in enumerate(lines):
        if not DEMO.search(l):
            continue
        total += 1
        m = GP.search(l)
        if not m:
            continue
        box = tuple(float(m.group(k)) for k in range(1, 5))
        if any(iou(box, t) >= 0.6 for t in taps):
            shadowed += 1
            if apply:
                lines[i] = DEMO.sub('', l, count=1)
                changed = True
    if changed:
        open(f, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
        touched.append(sid)

print(f'actions « Démonstration » détectées : {total} ; masquées par un vrai bouton : {shadowed} ; réellement factices : {total - shadowed}')
if apply and touched:
    p = os.path.join(ROOT, 'tool', 'figma_export', 'bindings.json')
    b = json.load(open(p, encoding='utf-8'))
    b['_frozen'] = sorted(set(b.get('_frozen', [])) | set(touched))
    open(p, 'w', encoding='utf-8', newline='\n').write(json.dumps(b, ensure_ascii=False, indent=1) + '\n')
    print('écrans figés :', ' '.join(touched))
