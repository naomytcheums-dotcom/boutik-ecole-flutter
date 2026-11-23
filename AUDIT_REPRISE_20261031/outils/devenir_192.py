"""Devenir des 192 actions « Démonstration » (état b3160af) dans le code actuel. Lecture seule (git show)."""
import csv, glob, os, re, subprocess, sys
from collections import Counter
sys.stdout.reconfigure(encoding='utf-8')
ROOT = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter'
OUT = os.path.join(ROOT, 'AUDIT_REPRISE_20261031', 'donnees')
GIT = r'C:\Program Files\Git\cmd\git.exe'
BASE = 'b3160af'
DEMO = re.compile(r"gToast\(\s*context\s*,\s*'D[ée]monstration\s*:\s*((?:[^'\\]|\\.)*)'\)")
BOX = re.compile(r"\bg(?:P|Tap)\(\s*([\d.\-]+),\s*([\d.\-]+),\s*([\d.]+),\s*([\d.]+)")
live_funcs = set()
for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'live', '*.dart')):
    for m in re.finditer(r"^(?:Future<[^>]*>|void|Future|[A-Z]\w*(?:<[^>]*>)?\??)\s+(\w+)\s*\(", open(f, encoding='utf-8').read(), re.M):
        live_funcs.add(m.group(1))
files = subprocess.run([GIT, '-C', ROOT, 'ls-tree', '--name-only', BASE, 'lib/figma/g/'], capture_output=True, text=True, encoding='utf-8').stdout.split()
rows = []
for path in files:
    old = subprocess.run([GIT, '-C', ROOT, 'show', f'{BASE}:{path}'], capture_output=True, text=True, encoding='utf-8').stdout
    if 'monstration' not in old: continue
    sid = os.path.basename(path)[2:-5]
    cur_path = os.path.join(ROOT, path)
    cur = open(cur_path, encoding='utf-8').read().split('\n') if os.path.exists(cur_path) else []
    for l in old.split('\n'):
        m = DEMO.search(l)
        if not m: continue
        b = BOX.search(l)
        box = tuple(float(x) for x in b.groups()) if b else None
        hits = []
        if box:
            for cl in cur:
                cb = BOX.search(cl)
                if cb and all(abs(float(x) - y) < 0.6 for x, y in zip(cb.groups(), box)):
                    hits.append(cl.strip())
        handlers = [h for h in hits if re.search(r'tap:|gTap\(', h)]
        txt = ' '.join(handlers)
        if not hits: st = "élément introuvable à la même position (écran remanié)"
        elif not handlers: st = "4 · plus aucune action (bouton inerte)"
        elif re.search(r"gOpen|gTab|gEspace|gBack|context\.(push|go)", txt) and not re.search(r"\b(" + '|'.join(sorted(live_funcs)) + r")\s*\(", txt): st = "navigation vers un écran"
        elif re.search(r"\b(" + '|'.join(sorted(live_funcs)) + r")\s*\(", txt): st = "1 · appel d'un module métier (lib/figma/live)"
        elif re.search(r"gToast\(", txt): st = "message seulement (gToast sans « Démonstration »)"
        else: st = "autre gestionnaire (à examiner)"
        fn = re.findall(r"\b(" + '|'.join(sorted(live_funcs)) + r")\s*\(", txt)
        toast = re.findall(r"gToast\(\s*context\s*,\s*'((?:[^'\\]|\\.)*)'", txt)
        rows.append(dict(ecran=sid, libelle_historique=m.group(1), statut_actuel=st, fonctions=' '.join(sorted(set(fn))[:5]), message_actuel=' | '.join(toast)[:160], extrait=(handlers[0] if handlers else (hits[0] if hits else ''))[:220]))
with open(os.path.join(OUT, 'devenir_192_demonstrations.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
print('actions historiques:', len(rows), 'sur', len({r['ecran'] for r in rows}), 'écrans')
for k, v in Counter(r['statut_actuel'] for r in rows).most_common(): print(f'{v:4d}  {k}')
print('messages actuels les plus fréquents:', Counter(r['message_actuel'] for r in rows if r['message_actuel']).most_common(12))
