"""Génère assets/i18n/en.json : traduction française -> anglaise de tous les textes statiques de l'interface.

Les textes sont extraits du code (lib/figma) puis traduits une fois pour toutes avec le service public de Google Traduction ; le résultat est
un fichier embarqué dans l'application : l'anglais fonctionne ensuite sans connexion et sans appel externe.
Usage : python tool/make_i18n.py   (reprend là où il s'était arrêté : seuls les textes nouveaux sont traduits)
"""
import glob
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'i18n', 'en.json')
LIT = re.compile(r"'((?:[^'\\$\n]|\\['nrt\\])+)'")


def clean(raw):
    return raw.replace("\\'", "'").replace('\\n', '\n').replace('\\\\', '\\')


def extract():
    found = set()
    for p in glob.glob(os.path.join(ROOT, 'lib', 'figma', '**', '*.dart'), recursive=True):
        s = io.open(p, encoding='utf-8').read()
        for m in LIT.finditer(s):
            t = clean(m.group(1))
            if len(t) < 2 or len(t) > 400:
                continue
            if not re.search(r'[A-Za-zÀ-ÿ]{3}', t):
                continue
            if ' ' not in t and re.fullmatch(r'[A-Za-z0-9_./:#@%+=?&-]+', t) and t == t.lower():
                continue  # identifiant technique
            if re.fullmatch(r'(assets|packages|http|https|/s/).*', t):
                continue
            if not (re.search(r'[À-ÿ]', t) or ' ' in t or t[:1].isupper()):
                continue
            found.add(t)
    return found


TPL = re.compile(r"""'((?:[^'\\\n$]|\\['nrt\\$])*(?:\$(?:\{[^}'"\n]*\}|[A-Za-z_]\w*)(?:[^'\\\n$]|\\['nrt\\$])*)+)'""")
VAR = re.compile(r"\$(?:\{[^}'\"\n]*\}|[A-Za-z_]\w*)")


def extract_templates():
    """Textes composés avec des valeurs (« Bonjour ${nom} ») : renvoie {modèle avec {0}, {1}…}. Les valeurs sont conservées à l'affichage."""
    found = set()
    for p in glob.glob(os.path.join(ROOT, 'lib', 'figma', '**', '*.dart'), recursive=True):
        s = io.open(p, encoding='utf-8').read()
        for m in TPL.finditer(s):
            raw = clean(m.group(1))
            n = [0]

            def sub(_):
                i = n[0]
                n[0] += 1
                return '{%d}' % i

            t = VAR.sub(sub, raw)
            if n[0] == 0 or n[0] > 4:
                continue
            letters = re.sub(r'\{\d\}', '', t)
            if not re.search(r'[A-Za-zÀ-ÿ]{3}', letters):
                continue
            if len(t) < 6 or len(t) > 300 or ' ' not in t.strip():
                continue
            found.add(t)
    return found


def translate(text):
    url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=fr&tl=en&dt=t&q=' + urllib.parse.quote(text)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=25) as r:
                data = json.loads(r.read().decode('utf-8'))
            return ''.join(seg[0] for seg in data[0] if seg and seg[0])
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return None


def translate_chunk(chunk):
    """Traduit un lot de textes en une seule requête (un texte par ligne) ; en cas d'écart, retombe sur la traduction une à une."""
    nl = chr(10)
    joined = nl.join(t.replace(nl, ' ') for t in chunk)
    url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=fr&tl=en&dt=t&q=' + urllib.parse.quote(joined)
    for attempt in range(8):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=40) as r:
                data = json.loads(r.read().decode('utf-8'))
            out = ''.join(seg[0] for seg in data[0] if seg and seg[0]).split(nl)
            if len(out) == len(chunk):
                return out
            break
        except Exception:
            time.sleep(60 * (attempt + 1))  # limite de débit du service : on patiente
    return [translate(t) for t in chunk]


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    done = {}
    if os.path.exists(OUT):
        raw = io.open(OUT, encoding='utf-8').read().strip()
        done = json.loads(raw) if raw else {}
    todo = sorted(t for t in extract() if t not in done)
    print('à traduire :', len(todo), '· déjà faits :', len(done), flush=True)
    chunks, cur, size = [], [], 0
    for t in todo:
        if cur and (len(cur) >= 25 or size + len(t) > 2200):
            chunks.append(cur)
            cur, size = [], 0
        cur.append(t)
        size += len(t) + 3
    if cur:
        chunks.append(cur)
    n = 0
    with ThreadPoolExecutor(max_workers=2) as ex:
        for chunk, res in zip(chunks, ex.map(translate_chunk, chunks)):
            for src, dst in zip(chunk, res):
                if dst:
                    done[src] = dst
            n += 1
            if n % 20 == 0:
                io.open(OUT, 'w', encoding='utf-8').write(json.dumps(done, ensure_ascii=False, indent=0, sort_keys=True))
                print(n, '/', len(chunks), flush=True)
    io.open(OUT, 'w', encoding='utf-8').write(json.dumps(done, ensure_ascii=False, indent=0, sort_keys=True))
    print('terminé :', len(done), 'textes', flush=True)


if __name__ == "__main__":
    print("Ce script extrait seulement les textes. La traduction se fait localement : python tool/make_i18n_local.py")
