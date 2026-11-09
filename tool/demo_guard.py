#!/usr/bin/env python3
"""Garde des données de maquette : les textes statiques des écrans (lib/figma/g/g_*.dart) qui décrivent une donnée
(personne, produit, montant, date, appareil, compteur…) ne sont affichés qu'hors connexion au serveur.

    python tool/demo_guard.py            # applique les gardes (idempotent)
    python tool/demo_guard.py --report   # liste seulement ce qui serait gardé

Un texte garde sa valeur en démonstration ; connecté il devient « — » (valeur numérique), vide (nom, titre) ou le nom du titulaire.
La même classification est reprise par test/journey/maquette_interdite_test.dart (qui échoue si un texte de maquette passe au travers).
"""
import glob, io, os, re, sys, json

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

_T = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'maquette_tokens.json'), encoding='utf-8'))
PERSONAS, ENTITIES = _T['personas'], _T['entities']
SELF, SELF_INST = set(_T['self']), set(_T['self_inst'])
# chiffres de politique, d'aide ou de saisie : décor de l'interface, pas des données
KEEP_DIGITS = re.compile(_T['keep_digits'])

TEXT_RE = re.compile(r"gText\(\s*'((?:[^'\\$]|\\.)*)'\s*,\s*([0-9.]+)")
RICH_RE = re.compile(r"\(\s*'((?:[^'\\$]|\\.)*)'\s*,\s*([0-9.]+)\s*,\s*([0-9]+)\s*,\s*Color\(")


def classify(lit, size=0.0):
    """None = décor ; sinon (type, valeur de remplacement)."""
    t = lit.strip()
    if not t or t in ('—', '–', '●'):
        return None
    if t in SELF:
        return ('self', t)
    if t in SELF_INST:
        return ('inst', t)
    for p in PERSONAS:
        if p in t:
            return ('name', '')
    for e in ENTITIES:
        if e in t:
            return ('name', '')
    if re.search(r'\d', t):
        if KEEP_DIGITS.search(t):
            # un compteur isolé grand (statistique) reste une donnée
            if re.fullmatch(r'\d{1,2}', t) and size >= 16:
                return ('num', '—')
            return None
        return ('num', '—')
    return None


CHIP_LINE = re.compile(r"^(\s*)Positioned\.fill\(child: GChoiceGroup\(chips: \[")
CHIP_LABEL = re.compile(r"GChip\([^']*'((?:[^'\\]|\\.)*)'")


def guard_chips(line):
    """Pastilles de choix portant des libellés de maquette (variantes, établissements d'exemple) : absentes connecté."""
    m = CHIP_LINE.match(line)
    if not m or 'if (demoContent)' in line:
        return line, 0
    labels = [l for l in CHIP_LABEL.findall(line) if '$' not in l]
    # pastilles : seuls les noms d'exemple et les compteurs entre parenthèses sont de la maquette (périodes, filtres : décor)
    if any((classify(l) and not re.search(r'\d', l)) or re.search(r'\(\d[\d ]*\)', l) for l in labels):
        return m.group(1) + 'if (demoContent) ' + line[len(m.group(1)):], 1
    return line, 0


def guard_expr(kind, lit):
    q = "'" + lit + "'"
    if kind == 'self':
        return f"gSelf(ref, {q})"
    if kind == 'inst':
        return f"gSelfInst(ref, {q})"
    blank = "'—'" if kind == 'num' else "''"
    return f"gm({q}, {blank})"


def process(path, apply):
    s = open(path, encoding='utf-8', newline='').read()
    n = 0
    log = []

    def rt(m):
        nonlocal n
        lit, size = m.group(1), float(m.group(2))
        c = classify(lit, size)
        if not c:
            return m.group(0)
        n += 1
        log.append((c[0], lit))
        return f"gText({guard_expr(c[0], lit)}, {m.group(2)}"

    s2 = TEXT_RE.sub(rt, s)

    def rr(m):
        nonlocal n
        lit = m.group(1)
        c = classify(lit, float(m.group(2)))
        if not c or c[0] == 'inst':
            return m.group(0)
        if c[0] == 'self':
            c = ('num', '')
        n += 1
        log.append((c[0], lit))
        return f"({guard_expr(c[0], lit)}, {m.group(2)}, {m.group(3)}, Color("

    # gRich : seules les lignes contenant gRich(
    out_lines = []
    for line in s2.split('\n'):
        if 'gRich(' in line:
            line = RICH_RE.sub(rr, line)
        line, k = guard_chips(line)
        if k:
            n += 1
            log.append(('chips', line.strip()[:60]))
        out_lines.append(line)
    s3 = '\n'.join(out_lines)
    if apply and s3 != s:
        open(path, 'w', encoding='utf-8', newline='').write(s3)
    return n, log


def main():
    apply = '--report' not in sys.argv
    total = 0
    kinds = {}
    for f in sorted(glob.glob('lib/figma/g/g_*.dart')):
        n, log = process(f, apply)
        total += n
        for k, l in log:
            kinds.setdefault(k, []).append(l)
    print('gardés :', total, {k: len(v) for k, v in kinds.items()})
    if not apply:
        for k, v in kinds.items():
            print('==', k)
            print(' ; '.join(sorted(set(x[:34] for x in v))[:400]))


if __name__ == '__main__':
    main()
