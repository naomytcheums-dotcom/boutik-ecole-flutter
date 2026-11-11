"""Corrige le vocabulaire propre à l'application dans assets/i18n/en.json :
  1. règles par mot (le modèle généraliste choisit parfois un autre sens) ;
  2. corrections relues à la main (tool/i18n_overrides.py), qui l'emportent sur tout le reste.
Usage : python tool/i18n_glossary.py   (idempotent : peut être relancé après chaque génération)
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import i18n_overrides  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'i18n', 'en.json')

RULES = [
    (r'parrain|filleul', r'\bsponsor(?:ship|ships|s|ed|ing)?\b', 'referral'),
    (r'parrain|filleul', r'\bgod(?:father|mother|children|child|son|daughter)s?\b', 'referral'),
    (r'moyens? de paiement', r'\bmethods? of payment\b', 'payment methods'),
    (r'centre de confiance', r'\btrust centre\b', 'trust center'),
    (r'\bboutiques?\b', r'\bshops?\b', 'store'),
] + i18n_overrides.RULES

CJK = re.compile(r'[　-鿿＀-￯]')


def cap_like(src_word, rep):
    return rep[:1].upper() + rep[1:] if src_word[:1].isupper() else rep


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    d = json.load(io.open(OUT, encoding='utf-8'))
    n = 0
    for k, v in list(d.items()):
        tpl = k.startswith('§')
        src = k[1:] if tpl else k
        low = src.lower()
        new = CJK.sub('’', v)
        for fr, en, rep in RULES:
            if re.search(fr, low):
                sg, _, pl = rep.partition('|')
                pl = pl or sg
                plural = bool(re.search('(?:' + fr + r')\w*s\b', low)) or bool(re.search(r'\bles\b|\bdes\b|\baucun[es]?s\b', low))
                new = re.sub(en, lambda m: cap_like(m.group(0), pl if (plural or m.group(0).lower().endswith('s') and not sg.endswith('s')) else sg), new, flags=re.I)
        new = re.sub(r'\b([Aa])n (listing|review|quote|kiosk|locker|skill|referred)', r'\1 \2', new)
        if not tpl and src in i18n_overrides.EXACT:
            new = i18n_overrides.EXACT[src]
        elif not tpl and src.strip() in i18n_overrides.EXACT:
            new = src.replace(src.strip(), i18n_overrides.EXACT[src.strip()])
        if new != v:
            d[k] = new
            n += 1
    io.open(OUT, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=0, sort_keys=True))
    print('corrigés :', n, '/', len(d))


if __name__ == '__main__':
    main()
