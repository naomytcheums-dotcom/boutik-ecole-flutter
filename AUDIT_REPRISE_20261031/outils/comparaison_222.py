import csv, os, re, sys
from collections import Counter
sys.stdout.reconfigure(encoding='utf-8')
ROOT = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter'
OUT = os.path.join(ROOT, 'AUDIT_REPRISE_20261031', 'donnees')
hist = {}
for l in open(os.path.join(ROOT, 'docs', 'audit-boutik-ecole', '02_ROUTES_ET_PAGES.md'), encoding='utf-8'):
    c = [x.strip() for x in l.strip().strip('|').split('|')]
    if len(c) == 11 and c[1].startswith('/s/'):
        hist[c[0]] = dict(niveau=c[4], demos=int(c[8]), entrants=int(c[10]))
cur = {r['ecran'].lower().replace('-', '_'): r for r in csv.DictReader(open(os.path.join(OUT, 'inventaire_ecrans.csv'), encoding='utf-8-sig'))}
h222 = [k for k, v in hist.items() if v['entrants'] == 0]
print('historique: ecrans', len(hist), '; sans lien entrant', len(h222), '; demos', sum(v['demos'] for v in hist.values()), 'sur', sum(1 for v in hist.values() if v['demos']))
st = Counter()
rows = []
for k in h222:
    r = cur.get(k.lower().replace('-', '_'))
    cat = r['categorie'].split(' ;')[0] if r else 'introuvable'
    st[cat] += 1
    rows.append(dict(ecran=k, titre=r['titre'] if r else '', niveau_historique=hist[k]['niveau'], demos_historiques=hist[k]['demos'],
                     liens_entrants_aujourdhui=r['liens_entrants'] if r else '', profondeur=r['profondeur'] if r else '', categorie_actuelle=cat, roles=r['roles'] if r else ''))
with open(os.path.join(OUT, 'comparaison_222_historiques.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
for k, v in sorted(st.items()): print(f'{v:4d}  {k}')
print('historiques encore sans lien contextuel:', [r['ecran'] for r in rows if r['categorie_actuelle'].startswith('4')])
print('niveaux historiques:', Counter(v['niveau'] for v in hist.values()))

