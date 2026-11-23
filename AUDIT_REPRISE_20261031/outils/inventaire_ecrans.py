"""Inventaire des écrans de Boutik-École (lecture seule). Écrit uniquement dans AUDIT_REPRISE_20261031/donnees."""
import csv, glob, hashlib, json, os, re, subprocess
from collections import defaultdict, deque
ROOT = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter'
OUT = os.path.join(ROOT, 'AUDIT_REPRISE_20261031', 'donnees')
GIT = r'C:\Program Files\Git\cmd\git.exe'
g = json.load(open(os.path.join(OUT, 'graph.json'), encoding='utf-8'))
edges = {k: set(v) for k, v in g['edges'].items()}
screens = sorted({os.path.basename(f)[2:-5] for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart'))})

# Manifeste : ScreenEntry(id, titre, builder, section, node, format) + fichier feature
entries = {}
ent = re.compile(r"ScreenEntry\(\s*'([^']+)',\s*'((?:[^'\\]|\\.)*)',\s*\(_\)\s*=>\s*(?:const\s+)?(\w+)", re.S)
for f in glob.glob(os.path.join(ROOT, 'lib', 'features', '**', 'screens.dart'), recursive=True):
    s = open(f, encoding='utf-8').read()
    sec = re.search(r"const _s = '([^']*)'", s)
    for m in ent.finditer(s):
        entries[m.group(1)] = dict(titre=m.group(2).replace("\\'", "'"), classe=m.group(3), section=sec.group(1) if sec else '?',
                                   module=os.path.basename(os.path.dirname(f)), fmt='')
cls_file = {}
for f in glob.glob(os.path.join(ROOT, 'lib', 'features', '**', '*.dart'), recursive=True):
    for m in re.finditer(r"class (\w+) extends", open(f, encoding='utf-8').read()):
        cls_file.setdefault(m.group(1), os.path.relpath(f, ROOT).replace('\\', '/'))
def key_of(eid): return eid.lower().replace('-', '_')
man = {key_of(k): (k, v) for k, v in entries.items()}

def allowed(i):
    m = re.match(r'^\d+', i)
    if not m: return None
    n = int(m.group(0)); A = 'admin'
    if i == '95b': return {'client','student','company','other','dept',A}
    if 57 <= n <= 69: return {'student','dept',A}
    if 88 <= n <= 99 or 187 <= n <= 190: return {'company',A}
    if 108 <= n <= 116: return {'dept','direction',A}
    if 117 <= n <= 126: return {'direction',A}
    if 127 <= n <= 138:
        if 131 <= n <= 133: return {'support',A}
        if n in (134,135): return {'finance',A}
        return {A}
    if 139 <= n <= 144: return {'finance','direction',A}
    if 145 <= n <= 147: return {'support',A}
    if n in (167,168,169) or 198 <= n <= 200 or n == 213: return {'dept',A}
    if n == 239: return {'direction','dept',A}
    return {262:{'company',A},285:{'company',A},263:{'dept',A},286:{'dept',A},287:{'dept',A},288:{'dept',A},283:{'dept',A},
            264:{A},265:{A},266:{A},267:{A},269:{A},280:{A},281:{A},180:{A},181:{A},268:{'support',A},277:{'support',A},284:{'finance','direction',A}}.get(n)

# profondeur depuis 01 (liens contextuels) et liens entrants
depth, q = {'01': 0}, deque(['01'])
while q:
    n = q.popleft()
    for d in edges.get(n, ()):
        if d not in depth: depth[d] = depth[n] + 1; q.append(d)
indeg = defaultdict(set)
for a, ds in edges.items():
    for d in ds:
        if d != a: indeg[d].add(a)

# boutons de la barre d'onglets / accueil : cibles de 03 (accueil) = accès direct
home = edges.get('03', set()) | edges.get('01', set()) | {'01','03'}
# doublons de rendu : contenu identique des fichiers générés (hors nom de classe)
hashes = defaultdict(list)
for sid in screens:
    t = open(os.path.join(ROOT, 'lib', 'figma', 'g', f'g_{sid}.dart'), encoding='utf-8').read()
    t = re.sub(r'\bG\w+\b', 'G', t)
    hashes[hashlib.sha1(t.encode()).hexdigest()].append(sid)
dup = {s: grp for grp in hashes.values() if len(grp) > 1 for s in grp}

widths = {k: float(v) for k, v in re.findall(r"'([^']+)': (\d+(?:\.\d+)?),", open(os.path.join(ROOT,'lib','figma','registry.dart'),encoding='utf-8').read())}
def fmt_of(w): return '' if w is None else ('borne' if w == 720 else 'tablette' if w == 768 else 'web' if w >= 1000 else 'mobile')
rows = []
for sid in sorted(screens, key=lambda x: (int(re.sub(r'\D.*', '', x) or 10**6), x)):
    eid, e = man.get(sid, (sid, {}))
    roles = allowed(eid)
    if sid not in depth:
        cat = '4 · sans lien contextuel (URL /s/ et index « Mes rubriques » uniquement)'
    elif roles is not None:
        cat = '3 · conditionnel (rôle)'
    elif sid in home:
        cat = '1 · direct (démarrage/accueil)'
    else:
        cat = '2 · indirect'
    if sid in dup: cat += ' ; 6? rendu identique à ' + ','.join(x for x in dup[sid] if x != sid)
    rows.append(dict(ecran=eid, fichier_genere=f'lib/figma/g/g_{sid}.dart', classe=e.get('classe',''), fichier_feature=cls_file.get(e.get('classe',''),''),
                     titre=e.get('titre','?'), module=e.get('module','?'), section=e.get('section','?'), format=fmt_of(widths.get(eid, widths.get(sid))), route=f'/s/{eid}',
                     roles='tous' if roles is None else ','.join(sorted(roles)), profondeur=depth.get(sid,''), liens_entrants=len(indeg.get(sid,())),
                     exemples_entrants=' '.join(sorted(indeg.get(sid,()))[:6]), categorie=cat))
with open(os.path.join(OUT, 'inventaire_ecrans.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

from collections import Counter
c = Counter(r['categorie'].split(' ;')[0] for r in rows)
import sys; sys.stdout.reconfigure(encoding='utf-8')
print('formats', Counter(r['format'] for r in rows))
print('ecrans', len(rows), 'manifeste', len(entries))
for k, v in sorted(c.items()): print(f'{v:4d}  {k}')
print('doublons de rendu (groupes):', [grp for grp in hashes.values() if len(grp) > 1])
print('sans aucun lien entrant (methode historique, hors 01):', sum(1 for r in rows if r['liens_entrants'] == 0 and r['ecran'] != '01'))
print('profondeur max', max(v for v in depth.values()), 'repartition', sorted(Counter(depth.values()).items()))
print('manifeste sans fichier genere:', sorted(set(map(key_of, entries)) - set(screens)))
print('fichiers generes sans manifeste:', sorted(set(screens) - set(map(key_of, entries))))

