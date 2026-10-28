"""Compare côte à côte la capture Figma (gauche) et le golden Flutter (droite).
Usage : python tool/compare_figma.py <dossier_captures_figma> [ids...]"""
import os, sys
from PIL import Image
caps = sys.argv[1]; ids = sys.argv[2:]
gold = 'test/golden/goldens'; out = 'build/compare'; os.makedirs(out, exist_ok=True)
for f in sorted(os.listdir(gold)):
    i = f[:-4]
    if ids and i not in ids: continue
    g = Image.open(os.path.join(gold, f)).convert('RGB')
    cp = os.path.join(caps, i + '.png')
    if not os.path.exists(cp): continue
    c = Image.open(cp).convert('RGB')
    c = c.resize((g.width, int(c.height * g.width / c.width)))
    h = max(c.height, g.height)
    sheet = Image.new('RGB', (g.width * 2 + 10, h), 'white')
    sheet.paste(c, (0, 0)); sheet.paste(g, (g.width + 10, 0))
    if g.width > 800: sheet = sheet.resize((sheet.width // 2, sheet.height // 2))
    sheet.save(os.path.join(out, i + '.jpg'), quality=82)
    print('ok', i)
