"""Relie les écrans par de vrais parcours : menus latéraux des consoles, menu du compte, liens contextuels issus des libellés existants.

Usage : python -I tool/audit/apply_journeys.py [--dry]
 - ajoute des zones tactiles (gTap) invisibles au-dessus de libellés déjà présents dans la maquette ; aucune mise en page n'est modifiée ;
 - idempotent : les lignes ajoutées portent le marqueur « // parcours » et sont recalculées à chaque exécution ;
 - les écrans modifiés sont ajoutés à _frozen (bindings.json) pour ne pas être écrasés par une régénération.
"""
import glob, io, json, os, re, sys, unicodedata

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'tool', 'audit', 'out')
G = json.load(open(os.path.join(OUT, 'graph.json'), encoding='utf-8'))
T = json.load(open(os.path.join(OUT, 'label_links.json'), encoding='utf-8'))['titles']
GT = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), gText\('((?:[^'\\]|\\.)*)', ([\d.]+)")
TAP1 = re.compile(r"gTap\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+),")
TAP2 = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), [^\n]*?tap:")
MARK = '// parcours'
DRY = '--dry' in sys.argv

# ---- menus latéraux des consoles (écrans web) : libellé -> cible, appliqué sur chaque écran de la famille
SIDEBARS = [
    dict(name='département', screens=[str(n) for n in range(108, 117)], x=(40, 60), map={
        'Tableau de bord': '108', 'Étudiants et vendeurs': '109', 'Validations': '110', 'Projets': '111', 'Statistiques': '112',
        'Productions': '113', 'Mentors': '114', 'Événements': '115', 'Rapports': '116'}),
    dict(name='direction', screens=[str(n) for n in range(117, 127)], x=(40, 60), map={
        'Tableau de bord': '117', 'Établissement': '118', 'Départements': '119', 'Utilisateurs': '120', 'Responsables': '121',
        'Circuits de validation': '122', 'Activité et ventes': '123', 'Événements': '124', 'Rapports': '125', "Journal d'audit": '126'}),
    dict(name='administration globale', screens=[str(n) for n in range(127, 139)], x=(40, 60), map={
        'Tableau de bord': '127', 'Établissements': '129', 'Utilisateurs': '128', 'Modération': '130', 'Circuits de validation': '122',
        'Finances': '139', 'Kiosques': '145', 'Sécurité': '136', 'Paramètres': '138', "Journal d'audit": '137'}),
    dict(name='finance et support', screens=['139', '140', '141', '142', '143', '144', '145', '146_1', '146_2', '147_1', '147_2', '147_3'], x=(40, 60), map={
        'Tableau de bord': '139', 'Paiements déclarés': '140', 'Journal financier': '141', 'Rapports': '142', 'Points de retrait': '145',
        'Incidents kiosques': '147_2', 'Tickets support': '147_1', 'Interventions': '147_3', 'Paramètres': '148_1'}),
    dict(name='impact', screens=['237', '238', '239'], x=(90, 110), map={
        'Tableau de bord': '238', 'Impact territorial': '237'}),
]

# ---- cibles du menu du compte (écran 10) : points d'entrée réels par rôle
MENU_TARGETS = ['59', '69', '100', '160', '151', '103', '214', '216', '223', '245', '253', '240', '191', '238', '179', '236', '261', '273', '272', '274', '45', '25', '25b', '27', '26', '52', '50', '155', '57', '58', '63', '62', '66', '67', '73', '75', '227', '187', '90', '93', '91',
                '108', '117', '127', '139', '145', '148_1', '174', '49', '22b', '78']

# ---- propositions par libellé écartées après relecture (le texte de la source ne désigne pas vraiment la cible)
EXCLUDE = set('''22d 32 35 46 47 51 55 59 84 99 117 127 139 154 176 178 196 233 234 235 238 247 267 272 273 274 276 279 281 283 285 28 45 150_4 183 d1 p4 p5 a1'''.split())
# 193 et 19x : paiement et mission relèvent d'un parcours propre (hors périmètre sans paiement réel)

# ---- liens manuels (source, libellé exact dans la source, cible)
MANUAL = [
    # espace client : ses commandes, devis et avis
    ('261', 'Suivre ma commande', '46'), ('261', 'Tout voir', '45'), ('261', 'Mes devis et collaborations', '192'), ('261', 'Donner un avis', '30'),
    # notifications -> la ressource concernée
    ('50', 'Commande exp', '51'), ('50', 'Nouveau message', '54'), ('50', 'Laissez un avis', '30'), ('50', 'Nouveauté dans vos favoris', '25'),
    ('50', 'Événement', '101'), ('50', 'Compte vérifié', '18'),
    ('51', 'Suivre ma commande', '46'), ('51', 'Contacter le vendeur', '54'), ('46', 'Contacter le vendeur', '54'),
    # paramètres
    ('148_1', 'Notifications', '56'), ('148_1', 'Informations personnelles', '273'), ('148_1', 'Adresses', '27'), ('148_1', 'Langue et affichage', '149'),
    ('148_1', 'Aide et support', '49'),
    # opportunités et alertes
    ('151', 'Voir tout', '152'), ('151', '2 dossiers', '154'), ('151', 'Assistant Opportunités', '157'), ('155', 'Voir', '153'),
    ('155', 'Dossier incomplet', '154'), ('155', 'Nouvelle offre compatible', '151'),
    # concours et hackathons
    ('160', 'Trouver une équipe', '163'), ('160', 'Hackathon Orange', '161'), ('161', 'Règlement', '166'),
    # marché des vœux
    ('216', 'Lampe en bois', '217'), ('216', 'Jus de bissap', '217'),
    # ateliers en direct et lives
    ('223', 'En direct maintenant', '222'), ('246', 'Regarder', '222'), ('253', 'Mes badges', '253b'),
    # fiche produit : vendeur et avis
    ('05', 'Créée par', '172'), ('29', 'Voir le reçu', '260'), ('29', 'Adresse de livraison', '46'), ('36', 'Note', '31'), ('36', 'Paiement', '171'),
    # boutique de créateur
    ('248', 'Ajouter un article', '249'), ('249', 'Article de boutique', '275'), ('249', 'Publication', '250'), ('249', 'Live', 'l1'),
    # communauté
    ('103', 'Explorer', '105'),
]


def norm(t):
    t = unicodedata.normalize('NFKD', t).encode('ascii', 'ignore').decode().lower()
    return re.sub(r"[^a-z0-9 ]+", ' ', t).strip()


def toks(t):
    stop = set('de du des la le les un une et en a au aux pour sur mon ma mes votre vos ce cet cette par dans avec d l'.split())
    return {w for w in norm(t).split() if w not in stop and len(w) > 2}


def fam(i):
    m = re.match(r'\d+', i)
    return int(m.group(0)) // 10 if m else -1


texts, taps, src_text = {}, {}, {}
for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart')):
    sid = os.path.basename(f)[2:-5]
    s = io.open(f, encoding='utf-8').read()
    src_text[sid] = s
    texts[sid] = [(float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)), m.group(5).replace("\\'", "'"), float(m.group(6))) for m in GT.finditer(s)]
    body = '\n'.join(l for l in s.split('\n') if MARK not in l)
    taps[sid] = [(float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))) for m in TAP1.finditer(body)] + \
                [(float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))) for m in TAP2.finditer(body)]


def overlaps(src, r):
    x, y, w, h = r
    for (a, b, c, d) in taps.get(src, []):
        ix = max(0, min(x + w, a + c) - max(x, a))
        iy = max(0, min(y + h, b + d) - max(y, b))
        if ix * iy > 0.3 * min(w * h, c * d):
            return True
    return False


plan = {}      # source -> [(x, y, w, h, target, texte)]
edges = []     # (source, cible)
skipped = []


def add(src, rect, tgt, label):
    if src == tgt:
        return False
    if overlaps(src, rect):
        skipped.append((src, tgt, label, 'zone déjà interactive'))
        return False
    plan.setdefault(src, []).append((*rect, tgt, label))
    taps.setdefault(src, []).append(rect)
    edges.append((src, tgt))
    return True


# 1) menus latéraux
for fam_cfg in SIDEBARS:
    for src in fam_cfg['screens']:
        for (x, y, w, h, txt, sz) in texts.get(src, []):
            if not (fam_cfg['x'][0] <= x <= fam_cfg['x'][1]) or y > 620 or y < 100:
                continue
            for label, tgt in fam_cfg['map'].items():
                if norm(txt) == norm(label):
                    add(src, (x - 12, y - 10, 232, 36), tgt, txt)

# 4) liens manuels (avant les propositions automatiques : ils sont prioritaires)
reach = set(G['reachable']) | set(MENU_TARGETS) | {t for s_ in SIDEBARS for t in s_['map'].values()}
for src, label, tgt in MANUAL:
    for (x, y, w, h, txt, sz) in texts.get(src, []):
        if norm(txt).startswith(norm(label)):
            add(src, (x - 8, y - 8, max(w + 16, 44), max(h + 16, 32)), tgt, txt)
            reach.add(tgt)
            break


# 2) graphe d'atteinte : écrans déjà reliés + menu du compte + cibles des menus latéraux et liens posés
reach |= {e[1] for e in edges}

# 3) propositions par libellé, de proche en proche
orph = set(G['orphans']) - reach
changed = True
while changed:
    changed = False
    for tgt in sorted(orph - set(e[1] for e in edges)):
        if tgt in EXCLUDE:
            continue
        tt = toks(T.get(tgt, ''))
        if not tt:
            continue
        best = None
        for src in sorted(reach):
            for (x, y, w, h, txt, sz) in texts.get(src, []):
                if y < 100 or y > 800 or sz < 11 or len(txt) < 4 or x > 400:
                    continue
                ot = toks(txt)
                inter = len(tt & ot)
                if not inter:
                    continue
                score = inter / len(tt | ot) + (0.25 if fam(src) == fam(tgt) else 0) + (0.1 if abs(fam(src) - fam(tgt)) == 1 else 0)
                if score >= 0.5 and (best is None or score > best[0]):
                    best = (score, src, x, y, w, h, txt)
        if best:
            _, src, x, y, w, h, txt = best
            if add(src, (x - 8, y - 8, max(w + 16, 44), max(h + 16, 32)), tgt, txt):
                reach.add(tgt)
                changed = True

left = sorted(set(G['orphans']) - reach)
print('liens ajoutés :', len(edges), 'sur', len(plan), 'écrans ;', 'écrans encore sans entrée :', len(left), '; zones ignorées :', len(skipped))
json.dump({'edges': edges, 'left': left, 'skipped': skipped}, open(os.path.join(OUT, 'journeys_plan.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
if DRY:
    sys.exit(0)

# 5) écriture : retire les anciennes lignes « parcours », ajoute les nouvelles avant la fermeture de la liste d'enfants
changed_ids = []
for sid, s in src_text.items():
    lines = s.split('\n')
    cleaned = [l for l in lines if MARK not in l]
    add_lines = []
    for (x, y, w, h, tgt, label) in plan.get(sid, []):
        add_lines.append("      gTap(%g, %g, %g, %g, () { gOpen(context, '%s'); }), %s %s -> %s" % (round(x, 1), round(y, 1), round(w, 1), round(h, 1), tgt, MARK, sid, tgt))
    if not add_lines and len(cleaned) == len(lines):
        continue
    # dernière ligne « ]); » de la liste d'enfants
    idx = max(i for i, l in enumerate(cleaned) if l.strip() == ']);')
    new = cleaned[:idx] + add_lines + cleaned[idx:]
    path = os.path.join(ROOT, 'lib', 'figma', 'g', f'g_{sid}.dart')
    raw = io.open(path, encoding='utf-8', newline='').read()
    crlf = '\r\n' in raw
    io.open(path, 'w', encoding='utf-8', newline='').write(('\r\n' if crlf else '\n').join(new))
    changed_ids.append(sid)

bp = os.path.join(ROOT, 'tool', 'figma_export', 'bindings.json')
raw = io.open(bp, encoding='utf-8', newline='').read()
nl = '\r\n' if '\r\n' in raw else '\n'
frozen = set(json.loads(raw)['_frozen'])
add_ids = [i for i in changed_ids if i not in frozen]
if add_ids:
    k = '"_frozen": ['
    i = raw.index(k) + len(k)
    raw = raw[:i] + ''.join(nl + '  "%s",' % a for a in add_ids) + raw[i:]
    io.open(bp, 'w', encoding='utf-8', newline='').write(raw)
print('écrans modifiés :', len(changed_ids), '; ajoutés à _frozen :', len(add_ids))
