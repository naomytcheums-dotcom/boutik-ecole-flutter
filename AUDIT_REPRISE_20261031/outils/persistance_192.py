import csv, glob, os, re, sys
from collections import Counter, defaultdict
sys.stdout.reconfigure(encoding='utf-8')
ROOT = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter'
OUT = os.path.join(ROOT, 'AUDIT_REPRISE_20261031', 'donnees')
# corps des fonctions de lib/figma/live (accolades équilibrées)
bodies, where = {}, {}
HEAD = re.compile(r"^\s*(?:static\s+)?(?:Future<[^\n]*?>|void|Future|[A-Z]\w*(?:<[^\n]*?>)?\??)\s+(\w+)\s*\(", re.M)
for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'live', '*.dart')):
    s = open(f, encoding='utf-8').read()
    for m in HEAD.finditer(s):
        i, d = m.end(), 1
        while i < len(s) and d:
            d += {'(': 1, ')': -1}.get(s[i], 0); i += 1
        rest = s[i:i + 40]
        mm = re.match(r"\s*(?:async\s*)?(\{|=>)", rest)
        if not mm: continue
        j = i + mm.end()
        if mm.group(1) == '{':
            d = 1
            while j < len(s) and d:
                d += {'{': 1, '}': -1}.get(s[j], 0); j += 1
        else:
            j = s.find(';\n', j) + 1
        bodies[m.group(1)] = s[i:j]; where[m.group(1)] = os.path.basename(f) + ':' + str(s[:m.start()].count('\n') + 1)
SRV = re.compile(r"Backend\.|\bsupabase\b|\.rpc\(|\brpc\(|\.from\('|functions\.invoke|_db\b|Supabase\.instance")
# fermeture transitive : une fonction est « serveur » si elle (ou une fonction qu'elle appelle) touche Supabase
names = set(bodies)
calls = {n: {c for c in re.findall(r"\b(\w+)\s*\(", b) if c in names and c != n} for n, b in bodies.items()}
srv = {n for n, b in bodies.items() if SRV.search(b)}
changed = True
while changed:
    changed = False
    for n in names - srv:
        if calls[n] & srv: srv.add(n); changed = True
rows = list(csv.DictReader(open(os.path.join(OUT, 'devenir_192_demonstrations.csv'), encoding='utf-8-sig')))
out = []
for r in rows:
    fns = r['fonctions'].split()
    if r['statut_actuel'].startswith('1'):
        kind = 'serveur (Supabase)' if any(f in srv for f in fns) else 'local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur)'
    else:
        kind = ''
    r['persistance'] = kind; r['ou'] = ' '.join(where.get(f, '') for f in fns[:3]); out.append(r)
with open(os.path.join(OUT, 'devenir_192_demonstrations.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(Counter((r['statut_actuel'][:40], r['persistance']) for r in out).most_common())
loc = Counter(f for r in out if r['persistance'].startswith('local') for f in r['fonctions'].split())
print('fonctions locales:', loc.most_common(25))
print('fonctions serveur:', Counter(f for r in out if r['persistance'].startswith('serveur') for f in r['fonctions'].split()).most_common(40))
for r in out:
    if r['statut_actuel'][0] in '4' or r['statut_actuel'].startswith(('message', 'autre')):
        print('-', r['ecran'], '|', r['libelle_historique'][:60], '|', r['statut_actuel'], '|', r['message_actuel'][:70], '|', r['extrait'][:110])

