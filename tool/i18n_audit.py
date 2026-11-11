"""Contrôle qualité de assets/i18n/en.json par rétro-traduction (anglais -> français) : les traductions dont le retour s'éloigne trop du texte
d'origine sont listées pour relecture. Écrit le rapport dans build/i18n_audit.txt.
Usage : venv\\Scripts\\python tool\\i18n_audit.py
"""
import difflib
import io
import json
import os
import re
import sys
import unicodedata

import ctranslate2
from transformers import MarianTokenizer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, 'assets', 'i18n', 'en.json')
MODEL = os.environ.get('I18N_MODEL_BACK', r'C:\BoutikEcole_Build\i18n\model_enfr')


def norm(s):
    s = unicodedata.normalize('NFD', s.lower())
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9 ]+', ' ', s).split()


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    d = json.load(io.open(EN, encoding='utf-8'))
    items = [(k, v) for k, v in d.items() if not k.startswith('§')]
    tok = MarianTokenizer.from_pretrained(MODEL)
    tr = ctranslate2.Translator(MODEL, device='cpu', compute_type='int8', intra_threads=max(1, (os.cpu_count() or 4) - 1))
    flagged = []
    B = 64
    for i in range(0, len(items), B):
        batch = items[i:i + B]
        src = [tok.convert_ids_to_tokens(tok.encode(v)) for _, v in batch]
        res = tr.translate_batch(src, beam_size=2, max_decoding_length=200)
        for (k, v), r in zip(batch, res):
            back = tok.decode(tok.convert_tokens_to_ids(r.hypotheses[0]), skip_special_tokens=True)
            a, b = norm(k), norm(back)
            sim = difflib.SequenceMatcher(None, a, b).ratio() if a or b else 1
            if sim < 0.55:
                flagged.append((sim, k, v, back))
    flagged.sort()
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    out = os.path.join(ROOT, 'build', 'i18n_audit.txt')
    io.open(out, 'w', encoding='utf-8').write('\n'.join('%.2f | %s | %s | (retour) %s' % f for f in flagged))
    print('traductions :', len(items), '· à relire :', len(flagged), '·', out)


if __name__ == '__main__':
    main()
