"""Inventaire exhaustif des écrans (lecture seule). Sortie : FINALISATION_LANCEMENT_PROJET_1/donnees/inventaire_ecrans_lancement.csv"""
import csv, glob, json, os, re, sys
from collections import Counter, defaultdict
sys.stdout.reconfigure(encoding='utf-8')
ROOT = r'C:\Users\NITROV15\Downloads\boutik_ecole_flutter'
OUT = os.path.join(ROOT, 'FINALISATION_LANCEMENT_PROJET_1', 'donnees')
G = os.path.join(ROOT, 'lib', 'figma', 'g')
LIVE = os.path.join(ROOT, 'lib', 'figma', 'live')
prev = {r['ecran']: r for r in csv.DictReader(open(os.path.join(ROOT, 'AUDIT_REPRISE_20261031', 'donnees', 'inventaire_ecrans.csv'), encoding='utf-8-sig'))}
keymap = {k.lower().replace('-', '_'): k for k in prev}

# --- fonctions et providers de lib/figma/live : serveur (touche Supabase, y compris indirectement) ou local
SRV = re.compile(r"Backend\.|\bsupabase\b|\.rpc\(|\b_run\(|\b_load\(|functions\.invoke|engageAction\(|\brpc\(")
HEAD = re.compile(r"^\s*(?:static\s+)?(?:Future<[^\n]*?>|void|bool|String|Future|[A-Z]\w*(?:<[^\n]*?>)?\??)\s+(\w+)\s*\(", re.M)
bodies = {}
for f in glob.glob(os.path.join(LIVE, '*.dart')):
    s = open(f, encoding='utf-8').read()
    for m in HEAD.finditer(s):
        i, d = m.end(), 1
        while i < len(s) and d:
            d += {'(': 1, ')': -1}.get(s[i], 0); i += 1
        mm = re.match(r"\s*(?:async\s*)?(\{|=>)", s[i:i + 40])
        if not mm: continue
        j = i + mm.end()
        if mm.group(1) == '{':
            d = 1
            while j < len(s) and d:
                d += {'{': 1, '}': -1}.get(s[j], 0); j += 1
        else:
            j = s.find(';\n', j) + 1
        bodies[m.group(1)] = s[i:j]
# providers : nom -> corps (classe Notifier ou Provider(...))
provsrc = {}
for f in glob.glob(os.path.join(LIVE, '*.dart')):
    s = open(f, encoding='utf-8').read()
    for m in re.finditer(r"^final (\w+Provider)\s*=\s*(\w+)", s, re.M):
        name, kind = m.group(1), m.group(2)
        # corps : définition du provider + classe Notifier référencée
        seg = s[m.start(): s.find(';\n', m.start()) + 1]
        cls = re.search(r"<(\w+),", seg) or re.search(r"\((\w+)\.new\)", seg)
        if cls:
            cm = re.search(r"class " + re.escape(cls.group(1)) + r"\b[^{]*\{", s)
            if cm:
                j, d = cm.end(), 1
                while j < len(s) and d:
                    d += {'{': 1, '}': -1}.get(s[j], 0); j += 1
                seg += s[cm.start():j]
        provsrc[name] = seg
names = set(bodies) | set(provsrc)
txt = {**bodies, **provsrc}
calls = {n: {c for c in re.findall(r"\b(\w+)\s*[\(\.]", t) if c in names and c != n} for n, t in txt.items()}
srv = {n for n, t in txt.items() if SRV.search(t)}
ch = True
while ch:
    ch = False
    for n in names - srv:
        if calls[n] & srv:
            srv.add(n); ch = True
# journal d'audit seul : ne compte pas comme action métier serveur
auditonly = {n for n in bodies if 'auditProvider' in bodies[n] and not SRV.search(bodies[n]) and not (calls[n] & (srv - {'auditProvider'}))}

# --- tests : écrans ouverts ou importés par les tests fonctionnels (hors goldens)
tested = Counter()
for f in glob.glob(os.path.join(ROOT, 'test', '**', '*_test.dart'), recursive=True):
    if 'golden' in f: continue
    s = open(f, encoding='utf-8').read()
    for m in re.finditer(r"figma/g/g_(\w+)\.dart", s): tested[m.group(1)] += 1
    for m in re.finditer(r"(?:gOpen|openScreen|screenPath|/s/)\(?\s*context?,?\s*['\"]?([0-9]+[a-z_0-9]*|[A-Za-z][0-9])['\"]", s): tested[m.group(1).lower().replace('-', '_')] += 1

NAV = re.compile(r"\b(gOpen|gTab|gBack|gEspace)\s*\(|context\.(push|go|pop)")
HAND = re.compile(r"(?:tap:\s*\(\)\s*(?:=>|\{)|gTap\([^,]+,[^,]+,[^,]+,[^,]+,\s*\(\)\s*(?:=>|\{))(.*)$")
rows = []
for f in sorted(glob.glob(os.path.join(G, 'g_*.dart'))):
    sid = os.path.basename(f)[2:-5]
    s = open(f, encoding='utf-8').read()
    lines = s.split('\n')
    p = prev.get(keymap.get(sid, sid), {})
    acts = Counter(); fn_used = set()
    for l in lines:
        m = HAND.search(l)
        if not m: continue
        h = m.group(1)
        used = [c for c in re.findall(r"\b(\w+)\s*\(", h) if c in names]
        fn_used.update(used)
        if 'unavailableAction' in h or 'bientôt' in h or 'bientot' in h: acts['attente'] += 1
        elif any(u in srv and u not in auditonly for u in used): acts['serveur'] += 1
        elif used: acts['local'] += 1
        elif NAV.search(h): acts['navigation'] += 1
        elif 'gToast(' in h: acts['message'] += 1
        elif re.search(r"\.notifier\)\.\w+\(|\.set\(|\.toggle\(|\.bump\(", h): acts['état_local_UI'] += 1
        else: acts['autre'] += 1
    fields = len(re.findall(r"\bGField\(", s))
    prov = set(re.findall(r"ref\.watch\((\w+Provider)", s))
    prov_srv = sorted(x for x in prov if x in srv); prov_loc = sorted(x for x in prov if x not in srv)
    demo_gated = len(re.findall(r"show:\s*demoContent", s))
    # contenu de maquette visible en production : textes littéraux porteurs de données (montants, nombres, dates, noms propres)
    lit = []
    for l in lines:
        if 'show: demoContent' in l: continue
        for t in re.findall(r"gText\('((?:[^'\\]|\\.)*)'", l):
            if t in ('9:41',) or '${' in t: continue
            if re.search(r"\d", t) and re.search(r"FCFA|%|\d{2,}|\b\d+ ?(h|j|min|jours|places|pts)\b|\d+[.,]\d", t):
                lit.append(t)
    rows.append(dict(ecran=p.get('ecran', sid), titre=p.get('titre', '?'), module=p.get('module', ''), format=p.get('format', ''),
                     roles=p.get('roles', ''), categorie_31_10=p.get('categorie', '')[:2].strip(' ·'), entrants=p.get('liens_entrants', ''),
                     interactions=sum(acts.values()), act_serveur=acts['serveur'], act_navigation=acts['navigation'], act_local=acts['local'],
                     act_etat_ui=acts['état_local_UI'], act_message=acts['message'], act_attente=acts['attente'], act_autre=acts['autre'],
                     champs=fields, providers_serveur=' '.join(prov_srv), providers_locaux=' '.join(prov_loc)[:200],
                     masque_hors_demo=demo_gated, donnees_litterales=len(lit), exemples_litteraux=' | '.join(lit[:4])[:180],
                     fonctions=' '.join(sorted(fn_used))[:200], tests_fonctionnels=tested.get(sid, 0)))
json.dump({'serveur': sorted(srv), 'audit_seul': sorted(auditonly)}, open(os.path.join(OUT, 'classement_fonctions.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
with open(os.path.join(OUT, 'inventaire_brut.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
tot = Counter()
for r in rows:
    for k in ('interactions', 'act_serveur', 'act_navigation', 'act_local', 'act_etat_ui', 'act_message', 'act_attente', 'act_autre', 'champs'):
        tot[k] += int(r[k])
print('écrans', len(rows)); print(dict(tot))
print('écrans avec données littérales visibles (≥3):', sum(1 for r in rows if r['donnees_litterales'] >= 3), '; ≥1:', sum(1 for r in rows if r['donnees_litterales'] >= 1))
print('écrans avec tests fonctionnels:', sum(1 for r in rows if r['tests_fonctionnels']))
print('écrans avec action locale (hors UI):', [r['ecran'] for r in rows if r['act_local']][:80])
