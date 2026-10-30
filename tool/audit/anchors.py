"""Affiche les libellés fixes d'écrans (y: texte) pour choisir des ancres de liens. Usage : python -I tool/audit/anchors.py 10 03 57"""
import io, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
GT = re.compile(r"gP\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), gText\('((?:[^'\\]|\\.)*)', ([\d.]+)")
for sid in sys.argv[1:]:
    s = io.open(os.path.join(ROOT, 'lib', 'figma', 'g', f'g_{sid}.dart'), encoding='utf-8').read()
    ts = [(round(float(m.group(1))), round(float(m.group(2))), m.group(5)[:30]) for m in GT.finditer(s) if 100 < float(m.group(2)) < 800 and float(m.group(6)) >= 11]
    print(sid, ' | '.join(f'{x},{y}:{t}' for x, y, t in ts).encode('ascii', 'replace').decode())
    print()
