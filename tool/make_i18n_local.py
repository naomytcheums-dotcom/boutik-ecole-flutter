"""Traduction LOCALE français -> anglais de tout le texte statique de l'interface (aucun service en ligne, aucune limite de requêtes).

Moteur : Opus-MT fr-en (Helsinki-NLP, licence Apache 2.0) converti pour CTranslate2 (licence MIT), exécuté sur le processeur de la machine.
Le résultat est écrit dans assets/i18n/en.json, embarqué dans l'application : l'anglais marche ensuite hors connexion.

Préparation (une fois) :
  python -m venv C:\\BoutikEcole_Build\\i18n\\venv
  venv\\Scripts\\pip install ctranslate2 sentencepiece transformers huggingface_hub
  snapshot_download('michaelfeil/ct2fast-opus-mt-fr-en', local_dir='C:\\\\BoutikEcole_Build\\\\i18n\\\\model')
Usage : venv\\Scripts\\python tool\\make_i18n_local.py   (reprend : seuls les textes nouveaux sont traduits)
"""
import io
import json
import os
import re
import sys
import time

import ctranslate2
from transformers import MarianTokenizer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_i18n  # noqa: E402  (réutilise l'extraction des textes)

MODEL = os.environ.get('I18N_MODEL', r'C:\BoutikEcole_Build\i18n\model')
OUT = make_i18n.OUT


BRANDS = {'Boutik-École': 'Boutikecole', 'Boutik-Ecole': 'Boutikecole', 'Kéla': 'Kelaa', 'Mobile Money': 'Mobilemoney', 'Orange Money': 'Orangemoney', 'MTN MoMo': 'Mtnmomo'}
BACK = {'Boutikecole': 'Boutik-École', 'Kelaa': 'Kéla', 'Mobilemoney': 'Mobile Money', 'Orangemoney': 'Orange Money', 'Mtnmomo': 'MTN MoMo'}


def protect(t):
    """Les noms propres de l'application ne se traduisent pas : ils sont remplacés par un mot neutre pendant la traduction."""
    t = t.replace(chr(10), ' ')
    for k, v in BRANDS.items():
        t = t.replace(k, v)
    return t


def restore(src, out):
    for k, v in BACK.items():
        out = re.sub(re.escape(k), v, out, flags=re.I)
    # vocabulaire propre à l'application (le modèle généraliste choisit parfois un autre sens)
    low = src.lower()
    if 'parrain' in low or 'filleul' in low:
        out = re.sub(r'sponsor(?:ship|s|ed|ing)?', 'referral', out, flags=re.I)
        out = re.sub(r'godfather|godchildren|godchild', 'referral', out, flags=re.I)
    if 'étudiant' in low and 'student' not in out.lower():
        out = re.sub(r'pupil(s)?', 'student\1', out, flags=re.I)
    return out


def main():
    tok = MarianTokenizer.from_pretrained(MODEL)
    tr = ctranslate2.Translator(MODEL, device='cpu', compute_type='int8', inter_threads=1, intra_threads=max(1, (os.cpu_count() or 4) - 1))
    done = {}
    if os.path.exists(OUT):
        raw = io.open(OUT, encoding='utf-8').read().strip()
        done = json.loads(raw) if raw else {}
    todo = sorted((t for t in (set(make_i18n.extract()) | {'§' + x for x in make_i18n.extract_templates()}) if t not in done), key=len)
    print('à traduire :', len(todo), '· déjà faits :', len(done), flush=True)
    t0 = time.time()
    B = 48
    for i in range(0, len(todo), B):
        batch = todo[i:i + B]
        src = [tok.convert_ids_to_tokens(tok.encode(protect(t[1:] if t.startswith('§') else t).replace('{0}', 'Qa').replace('{1}', 'Qb').replace('{2}', 'Qc').replace('{3}', 'Qd'))) for t in batch]
        res = tr.translate_batch(src, beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
        for t, r in zip(batch, res):
            out = restore(t, tok.decode(tok.convert_tokens_to_ids(r.hypotheses[0]), skip_special_tokens=True).strip())
            if t.startswith('§'):
                for k, v in (('Qa', '{0}'), ('Qb', '{1}'), ('Qc', '{2}'), ('Qd', '{3}')):
                    out = out.replace(k, v)
                if any('{%d}' % i not in out for i in range(t.count('{'))):
                    continue  # un marqueur a été perdu : le modèle reste en français plutôt que de mal afficher une valeur
            if not out:
                continue
            # étiquettes d'interface : même ponctuation finale que la source
            if t.endswith('…') and not out.endswith('…'):
                out = out.rstrip('.') + '…'
            if not t.endswith('.') and out.endswith('.') and len(t) < 40:
                out = out[:-1]
            if t.endswith(' ›') and not out.endswith('›'):
                out += ' ›'
            done[t] = out
        if (i // B) % 20 == 0:
            io.open(OUT, 'w', encoding='utf-8').write(json.dumps(done, ensure_ascii=False, indent=0, sort_keys=True))
            print(i + len(batch), '/', len(todo), round(time.time() - t0), 's', flush=True)
    io.open(OUT, 'w', encoding='utf-8').write(json.dumps(done, ensure_ascii=False, indent=0, sort_keys=True))
    print('terminé :', len(done), 'textes en', round(time.time() - t0), 's', flush=True)


if __name__ == '__main__':
    main()
