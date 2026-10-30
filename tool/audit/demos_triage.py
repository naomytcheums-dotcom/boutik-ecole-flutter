"""Liste les actions « Démonstration » restantes avec le titre de leur écran (lecture seule)."""
import csv, glob, os, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
titles = {}
pat = re.compile(r"ScreenEntry\(\s*'([^']+)',\s*'((?:[^'\\]|\\.)*)'")
for f in glob.glob(os.path.join(ROOT, 'lib', 'features', '**', '*.dart'), recursive=True):
    for m in pat.finditer(open(f, encoding='utf-8').read()):
        titles.setdefault(m.group(1), m.group(2))
rows = list(csv.DictReader(open(os.path.join(ROOT, 'tool', 'audit', 'out', 'demos.csv'), encoding='utf-8')))
out = os.path.join(ROOT, 'tool', 'audit', 'out', 'demos_triage.txt')
with open(out, 'w', encoding='utf-8') as fh:
    for r in rows:
        fh.write(f"{r['ecran']}\t{titles.get(r['ecran'], '?')}\t{r['action'].strip()}\n")
print(len(rows), 'actions ->', out)
