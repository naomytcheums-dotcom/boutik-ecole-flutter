"""Génère docs/final-audit/MATRICE_315_ECRANS.md à partir du code (analyse statique) — aucune valeur inventée.

Préalable : python tool/audit/nav_graph.py
Usage    : python tool/audit/gen_matrix.py
"""
import csv, glob, json, os, re
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'tool', 'audit', 'out')
DOC = os.path.join(ROOT, 'docs', 'final-audit')
os.makedirs(DOC, exist_ok=True)

graph = json.load(open(os.path.join(OUT, 'graph.json'), encoding='utf-8'))
by_links = set(graph['reachable'])
demos = defaultdict(list)
for r in csv.DictReader(open(os.path.join(OUT, 'demos.csv'), encoding='utf-8')):
    demos[r['ecran']].append(r['action'].strip())

# titres du registre
titles = {}
for f in glob.glob(os.path.join(ROOT, 'lib', 'features', '**', '*.dart'), recursive=True):
    s = open(f, encoding='utf-8').read()
    for m in re.finditer(r"ScreenEntry\(\s*'([^']+)',\s*'((?:[^'\\]|\\.)*)'", s):
        titles.setdefault(m.group(1), m.group(2).replace("\\'", "'"))

# rubriques (miroir de lib/figma/live/espace.dart)
RUB = [('A', 'Démarrage et navigation', 1, 10), ('B', 'Compte et authentification', 11, 18), ('C', 'Découverte et achats', 19, 31),
       ('D', 'Fiches produits et services', 32, 39), ('E', 'Commandes et livraison', 40, 49), ('F', 'Messages et communication', 50, 56),
       ('G', 'Espace étudiant-vendeur', 57, 69), ('H', 'Talents étudiants', 70, 77), ('I', 'Projets et financement', 78, 87),
       ('J', 'Espace entreprise', 88, 99), ('K', 'Événements et communautés', 100, 107), ('L', 'Département', 108, 116),
       ('M', 'Administration institutionnelle', 117, 126), ('N', 'Administration globale', 127, 138), ('O', 'Finance', 139, 144),
       ('P', 'Kiosques et support', 145, 147), ('Q', 'Paramètres et états du système', 148, 150), ('S', 'Opportunités et alertes', 151, 159),
       ('T', 'Hackathons et concours', 160, 169), ('U', 'Confiance, sécurité et partage', 170, 174), ('V', 'Onboarding et rôles', 175, 181),
       ('W', 'Faible connexion et langues', 182, 186), ('X', 'Web entreprise', 187, 190), ('Y', 'Missions sur mesure', 191, 205),
       ('AA', 'Borne phygitale', 206, 210), ('AD', 'Innovations', 211, 229), ('AI', 'Kéla et canaux', 230, 237),
       ('AM', 'Cercle, parrainage et publication', 238, 255), ('Z', 'Services complémentaires', 256, 999)]


def num(i):
    m = re.match(r'\d+', i)
    return int(m.group(0)) if m else None


def rub(i):
    n = num(i)
    if n is None:
        return 'S+', 'Studio créateur et assistants'
    for c, t, a, b in RUB:
        if a <= n <= b:
            return c, t
    return 'Z', 'Services complémentaires'


def roles(i):
    """Miroir de allowedRoles() (lib/figma/live/access.dart)."""
    n = num(i)
    if n is None:
        return 'tous'
    if 57 <= n <= 69: return 'étudiant, dépt, admin'
    if 88 <= n <= 99 or 187 <= n <= 190: return 'entreprise, admin'
    if 108 <= n <= 116: return 'dépt, direction, admin'
    if 117 <= n <= 126: return 'direction, admin'
    if 127 <= n <= 138:
        if 131 <= n <= 133: return 'support, admin'
        if n in (134, 135): return 'finance, admin'
        return 'admin'
    if 139 <= n <= 144: return 'finance, direction, admin'
    if 145 <= n <= 147: return 'support, admin'
    if n in (167, 168, 169, 198, 199, 200, 213): return 'dépt, admin'
    if n == 239: return 'direction, dépt, admin'
    if n in (262, 285): return 'entreprise, admin'
    if n in (263, 286, 287, 288, 283): return 'dépt, admin'
    if n in (264, 265, 266, 267, 269, 280, 281): return 'admin'
    if n in (268, 277): return 'support, admin'
    if n == 284: return 'finance, direction, admin'
    return 'tous'


SERVEUR = ('authProvider', 'profileAccountProvider', 'favoritesProvider', 'profileAvatar', 'profileNameBadge', 'submitLogin', 'submitSignup', 'startPayment',
           'listingsProvider', 'visibleListingsProvider', 'allProductsProvider', 'filteredProductsProvider', 'publicListingsProvider', 'submitListing',
           'reviewQueueProvider', 'allReviewsProvider', 'pendingReviewsProvider', 'visibleReviewsProvider', 'notificationsPanel', 'notifsProvider')
LOCAL = ('listingsProvider', 'ordersProvider', 'ordersAllProvider', 'cartProvider', 'teamMembersProvider', 'missionsProvider', 'auditProvider', 'adminProvider',
         'formProvider', 'chatProvider', 'notificationsProvider', 'ref.watch(', 'ref.read(')

rows, stats = [], defaultdict(int)
ids = sorted({os.path.basename(f)[2:-5] for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart'))},
             key=lambda x: (num(x) if num(x) is not None else 10 ** 6, x))
for i in ids:
    raw_src = open(os.path.join(ROOT, 'lib', 'figma', 'g', f'g_{i}.dart'), encoding='utf-8').read()
    s = chr(10).join(l for l in raw_src.split(chr(10)) if not l.startswith('import '))
    taps = len(re.findall(r'\btap:|gTap\(|GField\(|GChoiceGroup|GToggle|GCheck', s))
    nd = len(demos.get(i, []))
    if any(k in s for k in SERVEUR):
        pers = 'serveur (Supabase)'
    elif any(k in s for k in LOCAL):
        pers = 'mémoire locale (non persistée)'
    else:
        pers = 'statique'
    liens = 'oui' if i in by_links else 'non'
    if taps == 0 and nd == 0:
        etat = 'STATIQUE (aucune interaction)'
    elif nd:
        etat = f'PARTIEL ({nd} action(s) de démonstration)'
    elif pers == 'serveur (Supabase)':
        etat = 'IMPLÉMENTÉ — serveur ; comportement non vérifié en navigateur'
    else:
        etat = 'IMPLÉMENTÉ MAIS NON PERSISTÉ' if pers.startswith('mémoire') else 'NAVIGATION SEULE'
    stats[etat.split(' (')[0].split(' —')[0]] += 1
    rows.append((i, titles.get(i, '—'), f'/s/{i}', roles(i), rub(i)[0], taps, nd, liens, pers, etat))

md = ['# Matrice des écrans (315)', '',
      'Générée par `tool/audit/gen_matrix.py` à partir du code (analyse statique). **Aucun écran n\'est déclaré « terminé et testé »** : le seul test exécuté sur chaque écran est son rendu (test golden) ; le comportement n\'a pas été vérifié écran par écran dans un navigateur.', '',
      f'- Écrans : **{len(rows)}**',
      f'- Atteignables depuis le démarrage par liens explicites (liens contextuels, menus latéraux des consoles, menu du compte par rôle) : **{sum(1 for r in rows if r[7] == "oui")}** ; les autres sont listés dans `RESTE_A_FAIRE.md` et ne sont atteignables que par « Toutes les rubriques » (secondaire).',
      f'- Actions « Démonstration » restantes : **{sum(r[6] for r in rows)}** sur **{sum(1 for r in rows if r[6])}** écrans.', '',
      '| Statut | Écrans |', '|---|---|'] + [f'| {k} | {v} |' for k, v in sorted(stats.items(), key=lambda kv: -kv[1])] + ['',
      '| Id | Titre | Route | Rôles autorisés | Rubrique | Éléments interactifs | Démos restantes | Lien contextuel | Données | Tests | Statut |',
      '|---|---|---|---|---|---|---|---|---|---|---|']
for r in rows:
    md.append(f'| {r[0]} | {r[1]} | `{r[2]}` | {r[3]} | {r[4]} | {r[5]} | {r[6]} | {r[7]} | {r[8]} | golden (rendu) | {r[9]} |')
open(os.path.join(DOC, 'MATRICE_315_ECRANS.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')

with open(os.path.join(DOC, 'ACTIONS_DEMONSTRATION.md'), 'w', encoding='utf-8') as fh:
    fh.write('# Actions « Démonstration » restantes\n\nChaque ligne est un bouton qui n\'affiche qu\'un message « Démonstration : … » et ne fait rien d\'autre. Source : `tool/audit/demos.csv` (analyse du code).\n\n| Écran | Titre | Action |\n|---|---|---|\n')
    for i in ids:
        for a in demos.get(i, []):
            fh.write(f'| {i} | {titles.get(i, "—")} | {a} |\n')
print(len(rows), dict(stats))
