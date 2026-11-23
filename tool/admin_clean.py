#!/usr/bin/env python3
"""Espace admin propre (H6, lot L2) : retire des écrans web du back-office (lib/figma/g) les éléments d'EN-TÊTE de la maquette qui décrivent
une donnée inexistante quand l'application est connectée au serveur :
  - pastille « +3 » et trois photos d'équipe fictives, bouton « Exporter » d'en-tête sans action, point sombre ;
  - sous-titre « Vue d'ensemble · mise à jour aujourd'hui » (fausse fraîcheur) ;
  - nom figé « Super admin » / « Finance » du pied de menu (remplacé par le nom du compte : `gSelf`).
Hors connexion (aperçu), la maquette est inchangée (`show: demoContent`).

    python tool/admin_clean.py            # applique (idempotent)
    python tool/admin_clean.py --report   # liste seulement
"""
import io, os, re, sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib', 'figma', 'g')
IDS = '127 128 129 130 131 132 133 134 135 136 137 138 145 147_1 147_2 147_3 180 181 264 265 266 267 268 269 281'.split()

AVATAR = re.compile(r"^\s*gP\([\d.]+, 1[0-9], 28, 28, gBox\(image: 'assets/figma/img/(182e32fd|ebf23a96|c15478a4)")
DOT = re.compile(r"^\s*gP\(10(18|26), 1[67], 24, 24, gBox\(color: Color\(0xFF111015\), oval: true\)\),")
SIDE_AVATAR = re.compile(r"^\s*gP\([\d.]+, \d+, 36, 36, gBox\(image: 'assets/figma/img/d902a4aa")
EXPORT_ICON = re.compile(r"^\s*gP\([\d.]+, 20\.125, 15\.75, 15\.75, gImg\('assets/figma/v/c7f198a8ce01e5\.svg'\)\),")
CHIPS = re.compile(r"^(\s*)Positioned\.fill\(child: GChoiceGroup\(chips: \[GChip\([\d.]+, 10, 170, 36, '\+3'")
FRESH = re.compile(r"^\s*gP\(268, 110, 226, 15, gText\('Vue d’ensemble · mise à jour aujourd’hui'")
NAME = re.compile(r"gText\('(Super admin|Finance)', 11\.5, Color\(0xFF111015\)")


def add_show(line):
    s = line.rstrip()
    if 'show:' in s or not s.endswith('),'):
        return line
    return s[:-2] + ', show: demoContent),' + line[len(s):]


# Zones de maquette à retirer connecté (x0, y0, x1, y1, largeur max d'un élément) : tout élément `gP(...)` entièrement contenu dans la zone
# et sans donnée réelle (`Consumer(`, `show:`, `gTap(`) n'est affiché qu'hors connexion. Le contenu réel est ajouté par un widget `live/`.
REGIONS = {
    '127': [(236, 140, 420, 180, 200), (1140, 144, 1252, 176, 100), (610, 176, 1252, 376, 640), (660, 404, 850, 440, 100), (236, 480, 850, 760, 620),
            (880, 400, 1252, 544, 360), (880, 562, 1252, 760, 360), (150, 410, 190, 440, 40), (610, 360, 1252, 380, 640), (260, 450, 850, 476, 100)],
    # 128 : panneau « permissions » statique (quatre interrupteurs sans effet) ; 130 : lignes d'exemple de la file de modération.
    '128': [(928, 134, 1252, 400, 330)],
    '130': [(268, 222, 1252, 420, 984)],
    # 180 : règles du rôle « Jury » inventées + bouton « Créer un rôle » ; 181 / 281 : matrices de droits figées (plus larges que le réel).
    '180': [(760, 130, 1252, 340, 500), (268, 340, 450, 400, 200)],
    '181': [(268, 130, 1252, 510, 984)],
    '281': [(24, 215, 370, 650, 346)],
}
# Écrans dont les lignes de tableau sont remplacées, connecté, par une liste défilante réelle (live/admin_consoles.dart) : les lignes figées
# (fixées sur les trois ou quatre premières entrées) et leurs zones de toucher ne s'affichent plus qu'hors connexion.
LIST_SCREENS = {'128', '131', '132', '137'}
ROW_SHOW = re.compile(r"show: \(ref\.watch\((adminUsersProvider|allReportsProvider|orderRowsProvider|globalAuditProvider)\)")
ROW_TAP = re.compile(r"^(\s*)gTap\(([^\n]*)(adminUsersProvider|allReportsProvider|orderRowsProvider|globalAuditProvider)")
GP_RE = re.compile(r"^\s*gP\((-?[\d.]+), (-?[\d.]+), ([\d.]+), ([\d.]+), ")


def in_region(line, regions):
    m = GP_RE.match(line)
    if not m or 'Consumer(' in line or 'gTap(' in line or ' tap:' in line:
        return False
    x, y, w, h = (float(v) for v in m.groups())
    return any(x >= x0 and y >= y0 and x + w <= x1 + 0.01 and y + h <= y1 + 0.01 and w <= mw for (x0, y0, x1, y1, mw) in regions)


def clean(line, rows=False):
    if rows:
        if ROW_SHOW.search(line) and 'demoContent &&' not in line:
            return ROW_SHOW.sub(lambda m: "show: demoContent && (ref.watch(%s)" % m.group(1), line)
        m = ROW_TAP.match(line)
        if m and 'if (demoContent)' not in line:
            return m.group(1) + 'if (demoContent) ' + line.lstrip()
    if AVATAR.match(line) or DOT.match(line) or SIDE_AVATAR.match(line) or EXPORT_ICON.match(line) or FRESH.match(line):
        return add_show(line)
    m = CHIPS.match(line)
    if m and 'if (demoContent)' not in line:
        return m.group(1) + 'if (demoContent) ' + line[len(m.group(1)):]
    m = NAME.search(line)
    if m and 'show:' not in line and 'gSelf(' not in line:
        return line.replace("gText('%s', 11.5" % m.group(1), "gText(gSelf(ref, '%s'), 11.5" % m.group(1))
    return line


def main():
    report = '--report' in sys.argv
    total = 0
    for i in IDS:
        p = os.path.join(G, 'g_%s.dart' % i)
        raw = open(p, encoding='utf-8', newline='').read()
        eol = '\r\n' if '\r\n' in raw else '\n'
        lines = raw.split(eol)
        regs = REGIONS.get(i, [])
        out = [add_show(clean(l, i in LIST_SCREENS)) if (regs and in_region(l, regs)) else clean(l, i in LIST_SCREENS) for l in lines]
        n = sum(1 for a, b in zip(lines, out) if a != b)
        total += n
        if n:
            print('g_%s : %d ligne(s)' % (i, n))
            if not report:
                open(p, 'w', encoding='utf-8', newline='').write(eol.join(out))
    print('total', total)


main()
