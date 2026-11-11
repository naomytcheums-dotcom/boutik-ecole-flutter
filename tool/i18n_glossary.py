"""Corrige le vocabulaire propre à l'application dans assets/i18n/en.json (le modèle généraliste choisit parfois un autre sens).
Usage : python tool/i18n_glossary.py   (idempotent : peut être relancé après chaque génération)
"""
import io
import json
import os
import random
import re
import sys

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'i18n', 'en.json')

# (motif dans le texte français, motif anglais, remplacement) : appliqué seulement si le texte source contient le motif français
RULES = [
    (r'parrain|filleul', r'\bsponsor(?:ship|ships|s|ed|ing)?\b', 'referral'),
    (r'parrain|filleul', r'\bgod(?:father|mother|children|child|son|daughter)s?\b', 'referral'),
    (r'moyens? de paiement', r'\bmethods? of payment\b', 'payment methods'),
    (r'centre de confiance', r'\btrust centre\b', 'trust center'),
    (r'étudiant', r'\bpupils?\b', 'student'),
    (r'\bboutiques?\b', r'\bshops?\b', 'store'),
    (r'annonce', r'\badvertisements?\b|\bads?\b', 'listing'),
    (r'vendeur', r'\bseller(s)?\b', 'seller'),
    (r'\bvœux?\b|\bvoeux?\b', r'\bwishes\b', 'wishes'),
]
EXACT = {
    'Parrainer et gagner': 'Refer and earn',
    'J’ai un code de parrainage': 'I have a referral code',
    'Se connecter': 'Log in',
    'Créer un compte': 'Create an account',
    'Mot de passe oublié ?': 'Forgot password?',
    'Voir tout': 'See all',
    'Accueil': 'Home',
}


def main():
    d = json.load(io.open(OUT, encoding='utf-8'))
    n = 0
    for k, v in list(d.items()):
        src = k[1:] if k.startswith('§') else k
        low = src.lower()
        new = v
        for fr, en, rep in RULES:
            if re.search(fr, low):
                new = re.sub(en, lambda m: rep.capitalize() if m.group(0)[:1].isupper() else rep, new, flags=re.I)
        if src in EXACT and not k.startswith('§'):
            new = EXACT[src]
        if new != v:
            d[k] = new
            n += 1
    io.open(OUT, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=0, sort_keys=True))
    print('corrigés :', n, '/', len(d))
    random.seed(3)
    for k in random.sample([x for x in d if not x.startswith('§')], 25):
        print('  ', k, '=>', d[k])


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
