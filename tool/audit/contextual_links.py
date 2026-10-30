"""Liens métier complémentaires (reprise du 30/10/2026) : zones tactiles posées sur des libellés existants.

Usage : python -I tool/audit/contextual_links.py [--dry]
 - chaque lien part d'un libellé qui désigne réellement l'action (aucune mise en page modifiée) ;
 - idempotent : les lignes portent le marqueur « // lien métier » et sont recalculées à chaque exécution ;
 - n'utilise PAS le marqueur « // parcours » de apply_journeys.py, dont les lignes ne sont jamais touchées ;
 - ne pas relancer apply_journeys.py sur le graphe actuel : il recalcule ses propositions à partir des liens déjà posés
   et en retirerait une quarantaine (constaté par un essai à blanc le 30/10/2026).
"""
import glob, io, json, os, re, sys, unicodedata

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MARK = '// lien métier'
DRY = '--dry' in sys.argv
GT = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), gText\('((?:[^'\\]|\\.)*)'")
TAP1 = re.compile(r"gTap\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+),")
TAP2 = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), [^\n]*?tap:")

# (source, début du libellé dans la source, cible) — l'action décrite par le libellé mène à la cible.
LINKS = [
    # acheteur : fiche produit -> fiche complète, passeport, disponibilité, matériaux, vendeur, question, 3D
    ('05', 'Éclairage LED', '32'),
    ('05', 'Fait main', '211'),
    ('05', 'Matériaux recyclés', '106'),
    ('05', 'Livraison et retrait', '35'),
    ('32', 'Dimensions', '225'),
    ('32', 'Mouanga Yannick', '38'),
    ('172', 'Avis positifs', '38'),
    ('35', 'Bambou', '39'),                       # variante en rupture : « la lampe est-elle disponible en bambou ? »
    ('211', 'Étapes de fabrication', '34'),
    ('225', 'Voir chez moi en réalité augmentée', '226'),
    ('283', 'BE-C-0412', '211'),
    ('251', 'Tendances', '22c'),
    ('22c', 'Coups de cœur de la semaine', '102'),
    ('151', 'Pour vous', '22d'),
    ('138', 'Carte de l’innovation', '104'),
    ('149', 'Langue par défaut', '185'),
    # créateurs : publications, lives, profils talents
    ('249', '2 publications non terminées', '255'),
    ('255', 'Contrôles automatiques', '256'),
    ('58', 'Jusqu’à 6 photos', '279'),
    ('246', 'Prochains lives', '224'),
    ('246', 'En direct maintenant', 'v1'),
    ('91', 'Aminata Bello', 'p1'),
    ('p1', '2 695 Abonnés', 'p2'),
    ('p3', 'Mes outils connectés', 'p5'),
    ('248', '8 articles', 'd1'),
    ('108', 'Assistante Kéla', 'a1'),
    # entreprises : candidatures, défis, briefs, packs, rapports
    ('97', '8 candidatures', '158'),
    ('187', 'Hackathons et défis', '96'),
    ('138', 'Espace B2B', '262'),
    ('187', 'Besoins publiés', '99'),
    ('198', 'Parfums Mbella', '199'),
    ('200', 'Pack lancement', '202'),
    ('215', 'MVP pour startup', '204'),
    # missions : suivi WhatsApp (l'espace projet 285, réservé aux entreprises, est dans le menu du compte)
    ('194', 'Propositions de logo', '233'),
    ('193', 'Jalon 2', '234'),
    ('193', 'Jalon 1', '235'),
    # administration, finance, kiosques
    ('128', 'Comptes et rôles', '180'),
    ('128', 'Comptes, rôles et permissions', '181'),
    ('180', 'Règles du rôle Jury', '281'),
    ('127', 'Réseau', '267'),
    ('267', 'Catalogue national', '270'),
    ('145', 'Hors ligne', '276'),
    ('145', 'Kiosque Bibliothèque', '277'),
    ('145', 'Retraits du jour', '268'),
    ('207', 'Mon QR', '282'),
    ('213', 'Registre des certificats', '283'),
    ('141', 'Encaissement #0142', '284'),
    ('139', 'des reversements', '143'),
    ('287', 'Catalogue du département MMI', '288'),
    ('288', 'Médiathèque', '263'),
    ('266', 'API', '280'),
    ('138', 'E-mail transactionnel', '265'),
    ('146_1', 'À remettre', '146_2'),
    ('240', 'Contacts', '241'),
    # recherche, vendeurs, mentors, duels, jury
    ('19', 'Produits', '20'),
    ('172', 'Yannick Mouanga', '24'),
    ('114', 'Dr Paul Tchoupo', '77'),
    ('220', 'Classement de la semaine', '221'),
    ('178', 'Projets à examiner', '167'),
    # icônes sans libellé : rectangle exact de l'icône dans la maquette
    ('20', (334.1, 57.6, 36.9, 36.9), '23'),      # icône « réglages » des résultats -> Filtres
]


def norm(t):
    t = unicodedata.normalize('NFKD', t.replace("\\'", "'")).encode('ascii', 'ignore').decode().lower()
    return re.sub(r"[^a-z0-9#]+", ' ', t).strip()


def rects(rx, body):
    return [tuple(float(m.group(i)) for i in range(1, 5)) for m in rx.finditer(body)]


def overlaps(r, taps):
    x, y, w, h = r
    for (a, b, c, d) in taps:
        ix = max(0, min(x + w, a + c) - max(x, a))
        iy = max(0, min(y + h, b + d) - max(y, b))
        if ix * iy > 0.3 * min(w * h, c * d):
            return True
    return False


src = {os.path.basename(f)[2:-5]: f for f in glob.glob(os.path.join(ROOT, 'lib', 'figma', 'g', 'g_*.dart'))}
plan, report = {}, []
for s, label, tgt in LINKS:
    if s not in src or tgt not in src:
        report.append((s, label, tgt, 'écran inconnu'))
        continue
    text = io.open(src[s], encoding='utf-8').read()
    body = '\n'.join(l for l in text.split('\n') if MARK not in l)
    taps = rects(TAP1, body) + rects(TAP2, body) + [p[:4] for p in plan.get(s, [])]
    hit = None
    if isinstance(label, tuple):
        hit = label
    for m in ([] if hit else GT.finditer(body)):
        if norm(m.group(5)).startswith(norm(label)):
            x, y, w, h = (float(m.group(i)) for i in range(1, 5))
            hit = (x - 8, y - 8, max(w + 16, 44), max(h + 16, 32))
            break
    if hit is None:
        report.append((s, label, tgt, 'libellé introuvable'))
    elif overlaps(hit, taps):
        report.append((s, label, tgt, 'zone déjà interactive'))
    else:
        plan.setdefault(s, []).append((*hit, tgt, label))

print('liens posés :', sum(len(v) for v in plan.values()), 'sur', len(plan), 'écrans ; écartés :', len(report))
for r in report:
    print('  écarté', r)
if DRY:
    sys.exit(0)

changed = []
for sid, path in src.items():
    raw = io.open(path, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    lines = raw.split(nl)
    cleaned = [l for l in lines if MARK not in l]
    add = ["      gTap(%g, %g, %g, %g, () { gOpen(context, '%s'); }), %s %s -> %s" % (round(x, 1), round(y, 1), round(w, 1), round(h, 1), t, MARK, sid, t)
           for (x, y, w, h, t, _) in plan.get(sid, [])]
    if not add and len(cleaned) == len(lines):
        continue
    idx = max(i for i, l in enumerate(cleaned) if l.strip() == ']);')
    io.open(path, 'w', encoding='utf-8', newline='').write(nl.join(cleaned[:idx] + add + cleaned[idx:]))
    changed.append(sid)

bp = os.path.join(ROOT, 'tool', 'figma_export', 'bindings.json')
raw = io.open(bp, encoding='utf-8', newline='').read()
nl = '\r\n' if '\r\n' in raw else '\n'
frozen = set(json.loads(raw)['_frozen'])
new = [i for i in changed if i not in frozen]
if new:
    k = '"_frozen": ['
    i = raw.index(k) + len(k)
    raw = raw[:i] + ''.join(nl + '  "%s",' % a for a in new) + raw[i:]
    io.open(bp, 'w', encoding='utf-8', newline='').write(raw)
print('écrans modifiés :', len(changed), '; ajoutés à _frozen :', len(new))
