"""Convertit les écrans Figma (JSON de cache) en code Flutter fidèle (lib/figma/g/*.dart).

Usage : python tool/figma_export/convert.py [id ...]     (sans argument : tous les écrans du registre)
Le registre est lu dans lib/features/**/screens.dart (id d'écran + nodeId Figma).
"""
import hashlib, json, math, os, re, sys, glob, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CACHE = os.path.join(HERE, 'cache')
FILE = 'q3uvJnUobbPfhLbcaj0PzJ'
TOKEN = open(os.path.join(HERE, '.figma_token')).read().strip()
ASSET = os.path.join(ROOT, 'assets', 'figma')
OUT = os.path.join(ROOT, 'lib', 'figma', 'g')
for d in ('img', 'v', 'r'):
    os.makedirs(os.path.join(ASSET, d), exist_ok=True)
os.makedirs(OUT, exist_ok=True)
IMAGEREFS = json.load(open(os.path.join(CACHE, 'imagerefs.json')))

# ---------- registre : id d'écran <-> nodeId ----------
def read_registry():
    reg = {}
    for f in glob.glob(os.path.join(ROOT, 'lib', 'features', '**', 'screens.dart'), recursive=True):
        s = open(f, encoding='utf-8').read()
        for m in re.finditer(r"ScreenEntry\(\s*'([^']+)',.*?node:\s*'([^']+)'", s, re.S):
            reg[m.group(1)] = m.group(2)
    return reg

REG = read_registry()
NODE2ID = {v: k for k, v in REG.items()}
SIZES = {}
LINKS = {}
CUR = {'root': '', 'sid': ''}
BINDINGS = {}
_bf = os.path.join(HERE, 'bindings.json')
if os.path.exists(_bf):
    BINDINGS = json.load(open(_bf, encoding='utf-8'))
for _l in open(os.path.join(HERE, 'links.txt'), encoding='utf-8'):
    _l = _l.strip()
    if not _l:
        continue
    _f, _rest = _l.split('>', 1)
    for _item in _rest.split(';'):
        _parts = _item.split('>')
        if len(_parts) == 2:
            LINKS.setdefault(_f, []).append((_parts[0], _parts[1]))
        else:  # première entrée : "x,y,w,h>dest"
            pass
CERCLE = {'152:17', '152:125', '152:191', '153:16', '153:124', '153:205', '154:96', '156:16', '156:130', '157:16', '157:124'}
NAV_DEST = {'icon/search': '152:17', 'icon/chat': '36:709', 'icon/mic': '106:89', 'icon/user': '15:96', 'icon/home': '3:3', 'Accueil': '3:3'}
NAV_DEST_CERCLE = {'icon/search': '154:96', 'icon/chat': '36:709', 'icon/mic': '106:89', 'icon/user': '153:16', 'icon/home': '152:17', 'Accueil': '152:17'}

# ---------- utilitaires ----------
def num(v):
    s = ('%.3f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s

def dq(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n').replace('\r', '') + "'"

def color(c, op=1.0):
    a = c.get('a', 1.0) * op
    return 'Color(0x%02X%02X%02X%02X)' % (round(a * 255), round(c['r'] * 255), round(c['g'] * 255), round(c['b'] * 255))

def hexcol(c):
    return '#%02x%02x%02x' % (round(c['r'] * 255), round(c['g'] * 255), round(c['b'] * 255))

def vis(lst):
    return [p for p in (lst or []) if p.get('visible', True)]

def mat_mul(a, b):
    return [[a[0][0] * b[0][0] + a[0][1] * b[1][0], a[0][0] * b[0][1] + a[0][1] * b[1][1], a[0][0] * b[0][2] + a[0][1] * b[1][2] + a[0][2]],
            [a[1][0] * b[0][0] + a[1][1] * b[1][0], a[1][0] * b[0][1] + a[1][1] * b[1][1], a[1][0] * b[0][2] + a[1][1] * b[1][2] + a[1][2]]]

PAD = 3
VECTORS = {'VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'LINE', 'REGULAR_POLYGON'}

def has_image_paint(n):
    for p in vis(n.get('fills')) + vis(n.get('strokes')):
        if p['type'] == 'IMAGE':
            return True
    return any(has_image_paint(c) for c in n.get('children', []) if c.get('visible', True))

def paint_types(n):
    return {p['type'] for p in vis(n.get('fills')) + vis(n.get('strokes'))}

class Ctx:
    def __init__(self, sid):
        self.sid = sid
        self.rasters = []   # nodeIds à exporter en PNG
        self.images = set()  # imageRef à télécharger
        self.need_rasters = {}

# ---------- remplissages ----------
def gradient_expr(p, w, h, op):
    t = p['type']
    hp = p['gradientHandlePositions']
    stops = p['gradientStops']
    cols = ', '.join(color(s['color'], op * p.get('opacity', 1)) for s in stops)
    pos = ', '.join(num(s['position']) for s in stops)
    al = lambda q: 'Alignment(%s, %s)' % (num(q['x'] * 2 - 1), num(q['y'] * 2 - 1))
    if t == 'GRADIENT_LINEAR':
        return 'LinearGradient(begin: %s, end: %s, colors: [%s], stops: [%s])' % (al(hp[0]), al(hp[1]), cols, pos)
    if t in ('GRADIENT_RADIAL', 'GRADIENT_DIAMOND'):
        d = math.hypot((hp[1]['x'] - hp[0]['x']) * w, (hp[1]['y'] - hp[0]['y']) * h)
        r = d / max(1.0, min(w, h))
        return 'RadialGradient(center: %s, radius: %s, colors: [%s], stops: [%s])' % (al(hp[0]), num(r), cols, pos)
    if t == 'GRADIENT_ANGULAR':
        st = math.atan2((hp[1]['y'] - hp[0]['y']) * h, (hp[1]['x'] - hp[0]['x']) * w)
        return 'SweepGradient(center: %s, startAngle: %s, endAngle: %s, colors: [%s], stops: [%s])' % (al(hp[0]), num(st), num(st + 2 * math.pi), cols, pos)
    return None

def fill_args(ctx, n, w, h, op):
    """-> liste d'arguments gBox pour le remplissage."""
    fl = vis(n.get('fills'))
    if not fl:
        return []
    p = fl[-1]
    t = p['type']
    if t == 'SOLID':
        return ['color: ' + color(p['color'], op * p.get('opacity', 1))]
    if t.startswith('GRADIENT'):
        g = gradient_expr(p, w, h, op)
        return ['gradient: ' + g] if g else []
    if t == 'IMAGE' and p.get('imageRef'):
        ctx.images.add(p['imageRef'])
        fit = {'FILL': 'cover', 'FIT': 'contain', 'STRETCH': 'fill'}.get(p.get('scaleMode'), 'cover')
        return ['image: ' + dq('assets/figma/img/%s.png' % p['imageRef']), 'fit: BoxFit.' + fit]
    return []

def stroke_args(n):
    st = vis(n.get('strokes'))
    if not st or not n.get('strokeWeight'):
        return []
    p = st[-1]
    if p['type'] == 'SOLID':
        c = color(p['color'], p.get('opacity', 1))
    elif p['type'].startswith('GRADIENT'):
        c = color(p['gradientStops'][0]['color'], p.get('opacity', 1))
    else:
        return []
    return ['border: ' + c, 'bw: ' + num(n['strokeWeight'])]

def effect_args(n):
    sh, lb, bb = [], 0, 0
    for e in vis(n.get('effects')):
        if e['type'] == 'DROP_SHADOW':
            sh.append('BoxShadow(color: %s, offset: Offset(%s, %s), blurRadius: %s, spreadRadius: %s)' % (
                color(e['color']), num(e['offset']['x']), num(e['offset']['y']), num(e['radius']), num(e.get('spread', 0))))
        elif e['type'] == 'LAYER_BLUR':
            lb = e['radius']
        elif e['type'] == 'BACKGROUND_BLUR':
            bb = e['radius']
    a = []
    if sh:
        a.append('shadows: [%s]' % ', '.join(sh))
    if lb:
        a.append('layerBlur: ' + num(lb))
    if bb:
        a.append('backBlur: ' + num(bb))
    return a

def radii(n):
    if 'rectangleCornerRadii' in n:
        r = n['rectangleCornerRadii']
        return '[%s]' % ', '.join(num(x) for x in r)
    r = n.get('cornerRadius', 0)
    return None if not r else '[%s]' % ', '.join([num(r)] * 4)

# ---------- SVG des vecteurs ----------
def vector_svg(n):
    w, h = n['size']['x'], n['size']['y']
    parts = []
    fl = vis(n.get('fills'))
    if fl and fl[-1]['type'] == 'SOLID':
        c = fl[-1]['color']
        op = fl[-1].get('opacity', 1) * c.get('a', 1)
        for g in n.get('fillGeometry', []):
            parts.append('<path d="%s" fill="%s" fill-opacity="%s" fill-rule="%s"/>' % (
                g['path'], hexcol(c), num(op), 'evenodd' if g.get('windingRule') == 'EVENODD' else 'nonzero'))
    st = vis(n.get('strokes'))
    if st and st[-1]['type'].startswith('GRADIENT'):
        st = [{'type': 'SOLID', 'color': st[-1]['gradientStops'][0]['color'], 'opacity': st[-1].get('opacity', 1)}]
    if st and st[-1]['type'] == 'SOLID':
        c = st[-1]['color']
        op = st[-1].get('opacity', 1) * c.get('a', 1)
        for g in n.get('strokeGeometry', []):
            parts.append('<path d="%s" fill="%s" fill-opacity="%s" fill-rule="%s"/>' % (
                g['path'], hexcol(c), num(op), 'evenodd' if g.get('windingRule') == 'EVENODD' else 'nonzero'))
    if not parts:
        return None
    pad = PAD
    return '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="%s %s %s %s">%s</svg>' % (
        num(w + 2 * pad), num(h + 2 * pad), num(-pad), num(-pad), num(w + 2 * pad), num(h + 2 * pad), ''.join(parts))

def save_svg(svg):
    name = hashlib.sha1(svg.encode()).hexdigest()[:14] + '.svg'
    p = os.path.join(ASSET, 'v', name)
    if not os.path.exists(p):
        open(p, 'w', encoding='utf-8').write(svg)
    return 'assets/figma/v/' + name

# ---------- couche dynamique : détection des composants interactifs ----------
ROLE = {}
SKIP = set()

def lum(c):
    return 0.2126 * c['r'] + 0.7152 * c['g'] + 0.0722 * c['b']

def solid_fill(n):
    fl = vis(n.get('fills'))
    return fl[-1] if fl and fl[-1]['type'] == 'SOLID' else None

def rad(n):
    return n.get('cornerRadius', 0) or max(n.get('rectangleCornerRadii', [0]))

def flat(n, PM, out, root=False):
    if not n.get('visible', True) or n.get('isMask'):
        return
    rel = n.get('relativeTransform') or [[1, 0, 0], [0, 1, 0]]
    M = PM if root else mat_mul(PM, rel)
    if not root:
        out.append(dict(n=n, x=M[0][2], y=M[1][2], w=n['size']['x'], h=n['size']['y'], rot=abs(M[1][0]) > 1e-4))
    for c in n.get('children', []):
        flat(c, M, out)

def analyze(doc, nid):
    ROLE.clear()
    SKIP.clear()
    items = []
    flat(doc, [[1, 0, 0], [0, 1, 0]], items, True)
    texts = [i for i in items if i['n']['type'] == 'TEXT']
    rects = [i for i in items if i['n']['type'] == 'RECTANGLE' and not i['rot']]
    ells = [i for i in items if i['n']['type'] == 'ELLIPSE']
    _drop = set(BINDINGS.get(CUR['sid'], {}).get('dropLinks', []))
    _nb = BINDINGS.get(CUR['sid'], {}).get('nodes', {})
    links = [[float(v) for v in box.split(',')] for box, dest in LINKS.get(nid, []) if box not in _drop]
    rects = [r_ for r_ in rects if not _nb.get(r_['n']['id'], {}).get('noRole')]

    def inside(a, b, m=1):
        return a['x'] >= b['x'] - m and a['y'] >= b['y'] - m and a['x'] + a['w'] <= b['x'] + b['w'] + m and a['y'] + a['h'] <= b['y'] + b['h'] + m

    def linked(r):
        cx, cy = r['x'] + r['w'] / 2, r['y'] + r['h'] / 2
        return any(l[0] <= cx <= l[0] + l[2] and l[1] <= cy <= l[1] + l[3] for l in links) or bool(r['n'].get('interactions'))

    # interrupteurs
    for r in rects:
        n = r['n']
        if not (18 <= r['h'] <= 40 and 1.4 <= r['w'] / max(r['h'], 1) <= 2.6 and rad(n) >= r['h'] / 2 - 1):
            continue
        sf = solid_fill(n)
        if not sf:
            continue
        for e in ells:
            if inside(e, r) and abs(e['w'] - e['h']) < 1 and r['h'] - 14 <= e['w'] <= r['h'] - 1:
                on = e['x'] + e['w'] / 2 > r['x'] + r['w'] / 2
                ROLE[n['id']] = ('toggle', dict(on=on, color=sf['color'], knob=e['w']))
                SKIP.add(e['n']['id'])
                break
    # champs de saisie
    for r in rects:
        n = r['n']
        if n['id'] in ROLE or linked(r) or not (34 <= r['h'] <= 72 and r['w'] >= 110):
            continue
        named = re.search('champ|recherche|search|input|saisie', n['name'], re.I)
        if rad(n) < 10 and not named:
            continue
        sf = solid_fill(n)
        if not sf or lum(sf['color']) < 0.5:
            continue
        ts = [t for t in texts if inside(t, r, 2) and t['n']['id'] not in SKIP]
        if not ts or len(ts) > 3:
            continue
        ts.sort(key=lambda t_: t_['x'])
        t = ts[-1]
        tn = t['n']
        if any(o['x'] + o['w'] > t['x'] + 1 for o in ts[:-1]):
            continue
        if '\n' in tn['characters'] or len(tn['characters']) > 60:
            continue
        left = t['x'] - r['x']
        if not (8 <= left <= 120):
            continue
        if t['h'] > 1.7 * tn['style'].get('fontSize', 12):
            continue
        col = solid_fill(tn)
        grey = col and abs(col['color']['r'] - col['color']['g']) < 0.08 and 0.3 < lum(col['color']) < 0.8
        dots = set(tn['characters'].strip()) == {'•'}
        if not (grey or named or dots):
            continue
        if tn['style'].get('textAlignHorizontal') == 'CENTER' and abs((t['x'] + t['w'] / 2) - (r['x'] + r['w'] / 2)) < 6:
            continue
        if left > 48 and len(ts) == 1:
            continue
        ROLE[n['id']] = ('input', dict(t=tn, left=left, multi=False))
        SKIP.add(tn['id'])
    # groupes de pastilles / onglets à choix unique
    cands = []
    for r in rects:
        n = r['n']
        if n['id'] in ROLE or n['id'] in SKIP or linked(r):
            continue
        if not (22 <= r['h'] <= 52 and r['w'] <= 220 and rad(n) >= r['h'] / 2 - 3):
            continue
        sf = solid_fill(n)
        if not sf:
            continue
        ts = [t for t in texts if inside(t, r, 2) and t['n']['id'] not in SKIP]
        if len(ts) != 1:
            continue
        cands.append((r, ts[0], sf))
    cands.sort(key=lambda c: (round(c[0]['y'] / 3), c[0]['x']))
    rows = []
    for c in cands:
        if rows and abs(rows[-1][-1][0]['y'] - c[0]['y']) <= 2 and c[0]['x'] - (rows[-1][-1][0]['x'] + rows[-1][-1][0]['w']) <= 24:
            rows[-1].append(c)
        else:
            rows.append([c])
    for row in rows:
        if len(row) < 2:
            continue
        key = lambda c: (round(c[2]['color']['r'], 2), round(c[2]['color']['g'], 2), round(c[2]['color']['b'], 2), round(c[2].get('opacity', 1), 2))
        counts = {}
        for c in row:
            counts[key(c)] = counts.get(key(c), 0) + 1
        if len(counts) != 2 or min(counts.values()) == max(counts.values()):
            continue
        minority = [c for c in row if counts[key(c)] == min(counts.values())]
        if len(minority) != 1:
            continue
        sel = row.index(minority[0])
        unsel = [c for c in row if c is not minority[0]][0]
        ROLE[row[0][0]['n']['id']] = ('choice', dict(row=row, sel=sel, unsel=unsel, selc=minority[0]))
        for c in row:
            SKIP.add(c[1]['n']['id'])
            if c[0]['n']['id'] != row[0][0]['n']['id']:
                SKIP.add(c[0]['n']['id'])

    # onglets segmentés : une pastille sombre sélectionnée + libellés voisins sans rectangle
    done = {k for v in ROLE.values() if v[0] == 'choice' for c in v[1]['row'] for k in (c[0]['n']['id'],)}
    for r in rects:
        n = r['n']
        if n['id'] in ROLE or n['id'] in SKIP or n['id'] in done or linked(r):
            continue
        sf = solid_fill(n)
        if not sf or lum(sf['color']) > 0.3 or not (24 <= r['h'] <= 50 and 50 <= r['w'] <= 220 and rad(n) >= r['h'] / 2 - 3):
            continue
        own = [t for t in texts if inside(t, r, 2) and t['n']['id'] not in SKIP]
        if len(own) != 1:
            continue
        cy = r['y'] + r['h'] / 2
        near = [t for t in texts if t is not own[0] and t['n']['id'] not in SKIP and abs(t['y'] + t['h'] / 2 - cy) <= 4
                and not inside(t, r, 2) and r['x'] - 260 <= t['x'] <= r['x'] + r['w'] + 260
                and abs(t['n']['style'].get('fontSize', 0) - own[0]['n']['style'].get('fontSize', 0)) <= 1.5]
        if not (1 <= len(near) <= 5):
            continue
        row = [(r, own[0], sf)]
        for t in near:
            tc = solid_fill(t['n'])
            if not tc:
                row = None
                break
            fake = dict(x=t['x'] + t['w'] / 2 - r['w'] / 2, y=r['y'], w=r['w'], h=r['h'], rot=False, n=dict(id='seg-' + t['n']['id'], name='seg', type='RECTANGLE', cornerRadius=rad(n), fills=[]))
            row.append((fake, t, dict(type='SOLID', color=dict(r=1, g=1, b=1, a=0), opacity=1)))
        if not row:
            continue
        row.sort(key=lambda c: c[0]['x'])
        sel = [i for i, c in enumerate(row) if c[0]['n']['id'] == n['id']][0]
        unsel = [c for c in row if c[0]['n']['id'] != n['id']][0]
        ROLE[row[0][0]['n']['id']] = ('choice', dict(row=row, sel=sel, unsel=unsel, selc=(r, own[0], sf)))
        for c in row:
            SKIP.add(c[1]['n']['id'])
            if c[0]['n']['id'] != row[0][0]['n']['id']:
                SKIP.add(c[0]['n']['id'])
        if row[0][0]['n']['id'].startswith('seg-'):
            # le premier élément est un faux rectangle : on ancre le rôle sur la pastille sélectionnée
            del ROLE[row[0][0]['n']['id']]
            ROLE[n['id']] = ('choice', dict(row=row, sel=sel, unsel=unsel, selc=(r, own[0], sf)))
            SKIP.discard(n['id'])
    # boutons : rectangle arrondi + libellé centré, sans lien
    for r in rects:
        n = r['n']
        if n['id'] in ROLE or n['id'] in SKIP or linked(r):
            continue
        if not (36 <= r['h'] <= 66 and r['w'] >= 100 and rad(n) >= min(12, r['h'] / 2 - 4)):
            continue
        ts = [t for t in texts if inside(t, r, 2)]
        if len(ts) != 1:
            continue
        t = ts[0]
        if abs((t['x'] + t['w'] / 2) - (r['x'] + r['w'] / 2)) > 8:
            continue
        ROLE[n['id']] = ('button', t['n']['characters'])

# ---------- émission ----------
def tap_expr(n):
    for it in n.get('interactions', []) or []:
        if it.get('trigger', {}).get('type') not in ('ON_CLICK', 'ON_PRESS'):
            continue
        for a in it.get('actions', []):
            d = a.get('destinationId')
            if a.get('type') == 'NODE' and d in NODE2ID:
                return "() => gOpen(context, %s)" % dq(NODE2ID[d])
            if a.get('type') == 'BACK':
                return "() => gBack(context)"
    tbl = NAV_DEST_CERCLE if CUR['root'] in CERCLE else NAV_DEST
    if n['name'] in tbl and tbl[n['name']] in NODE2ID and tbl[n['name']] != CUR['root']:
        return "() => gOpen(context, %s)" % dq(NODE2ID[tbl[n['name']]])
    if n['name'] in ('Bouton rond', 'icon/back'):
        return "() => gBack(context)"
    return None

def pos(M, w, h, ox, oy):
    rot = math.atan2(M[1][0], M[0][0])
    return M[0][2] - ox, M[1][2] - oy, rot

def _emit_node_inner(ctx, n, PM, ox, oy, out, root=False):
    if not n.get('visible', True) or n.get('isMask') or n['id'] in SKIP:
        return
    t = n['type']
    rel = n.get('relativeTransform') or [[1, 0, 0], [0, 1, 0]]
    M = PM if root else mat_mul(PM, rel)
    w, h = n['size']['x'], n['size']['y']
    x, y, rot = (0, 0, 0) if root else pos(M, w, h, ox, oy)
    op = n.get('opacity', 1.0)
    tap = tap_expr(n)
    extra = ''
    if rot:
        extra += ', rot: ' + num(rot)
    if op < 1 and t != 'TEXT':
        extra += ', op: ' + num(op)
    geo = '%s, %s, %s, %s' % (num(x), num(y), num(w), num(h))
    nm = n['name'].lower()
    if t == 'ELLIPSE' and n['name'] == 'Halo':
        extra += ", fx: 'halo'"
    elif t == 'RECTANGLE' and nm.startswith('onde'):
        extra += ", fx: 'wave'"
    elif t == 'TEXT' and n.get('characters', '').strip().upper() in ('EN DIRECT', 'LIVE'):
        extra += ", fx: 'pulse'"
    role = ROLE.get(n['id'])
    if role and role[0] == 'toggle':
        d = role[1]
        on_c = color(d['color']) if d['on'] else 'Color(0xFF111015)'
        off_c = 'Color(0xFFDAD8DF)' if d['on'] else color(d['color'])
        out.append("gP(%s, GToggle(on: %s, onColor: %s, offColor: %s, knob: %s)%s)" % (geo, 'true' if d['on'] else 'false', on_c, off_c, num(d['knob']), extra))
        return
    if role and role[0] == 'choice':
        d = role[1]
        chips = []
        for (r_, t_, sf_) in d['row']:
            tn = t_['n']
            chips.append("GChip(%s, %s, %s, %s, %s, %s, %d)" % (num(r_['x'] - ox), num(r_['y'] - oy), num(r_['w']), num(r_['h']), dq(tn['characters']), num(tn['style'].get('fontSize', 12)), int(tn['style'].get('fontWeight', 400))))

        def tcol(c_):
            f_ = solid_fill(c_[1]['n'])
            return color(f_['color'], f_.get('opacity', 1)) if f_ else 'Color(0xFF111015)'
        selc, unsel = d['selc'], d['unsel']
        bd = ''
        ust = stroke_args(unsel[0]['n'])
        if ust:
            bd = ', border: ' + ust[0][8:]
        inter = 'inter' in d['row'][0][1]['n']['style'].get('fontFamily', '').lower()
        oc_ = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n['id'], {}).get('onChanged')
        out.append("Positioned.fill(child: GChoiceGroup(chips: [%s], selected: %d, selFill: %s, unselFill: %s, selText: %s, unselText: %s, radius: %s%s%s%s))" % (
            ', '.join(chips), d['sel'], color(selc[2]['color'], selc[2].get('opacity', 1)), color(unsel[2]['color'], unsel[2].get('opacity', 1)),
            tcol(selc), tcol(unsel), num(rad(d['row'][0][0]['n'])), bd, ', inter: true' if inter else '', (', onChanged: (i) { %s }' % oc_) if oc_ else ''))
        return

    # --- rastérisation : icônes à texture (chrome) et formes complexes
    def raster():
        ctx.rasters.append(n['id'])
        out.append("gP(%s, gImg(%s)%s)" % (geo, dq('assets/figma/r/%s.png' % n['id'].replace(':', '_')), extra))

    if not root and (t in ('FRAME', 'GROUP', 'INSTANCE', 'COMPONENT')) and (
            'Carte du Cameroun' in n['name']):
        raster()
        return
    if t == 'BOOLEAN_OPERATION' or (t in VECTORS and (paint_types(n) - {'SOLID'}) and w > 0 and h > 0):
        raster()
        return

    # --- texte
    if t == 'TEXT':
        emit_text(ctx, n, geo, x, y, w, h, extra, tap, out)
        return

    # --- vecteur simple -> SVG local
    if t in VECTORS or (t == 'ELLIPSE' and n.get('arcData') and (abs(n['arcData'].get('endingAngle', 6.283185) - n['arcData'].get('startingAngle', 0) - 2 * math.pi) > 0.01 or n['arcData'].get('innerRadius', 0) > 0)):
        svg = vector_svg(n)
        if svg:
            g2 = '%s, %s, %s, %s' % (num(x - PAD), num(y - PAD), num(w + 2 * PAD), num(h + 2 * PAD))
            out.append("gP(%s, gImg(%s)%s)" % (g2, dq(save_svg(svg)), extra))
        return

    # --- boîtes
    fa = fill_args(ctx, n, w, h, 1.0)
    sa = stroke_args(n)
    ea = effect_args(n)
    shape = t in ('RECTANGLE', 'ELLIPSE', 'FRAME', 'COMPONENT', 'INSTANCE', 'GROUP', 'SECTION')
    drawn = bool(fa or sa or ea)
    if t in ('FRAME', 'GROUP', 'INSTANCE', 'COMPONENT', 'SECTION') and not (fa or sa):
        drawn = False  # ombre portée par les enfants (icônes) : on ne dessine pas de rectangle
    r = radii(n)
    args = list(fa) + sa + ea
    ib_ = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n['id'], {}).get('image')
    if ib_:
        args = [('image: (%s)' % ib_) if a.startswith('image: ') else a for a in args]
    fb_ = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n['id'], {}).get('fill')
    if fb_:
        args = [('color: (%s)' % fb_) if a.startswith('color: ') else a for a in args]
        if not any(a.startswith('color: ') for a in args):
            args.append('color: (%s)' % fb_)
    if r and not (t == 'ELLIPSE'):
        args.append('radii: ' + r)
    if t == 'ELLIPSE':
        args.append('oval: true')
    if root:
        return
    if shape and drawn:
        if role and role[0] == 'button' and not tap:
            tap = "() => gToast(context, %s)" % dq('Démonstration : ' + role[1].strip())
        tp = (', tap: ' + tap) if (tap and t in ('RECTANGLE', 'ELLIPSE') ) else ''
        if n['name'] == 'Micro':
            out.append("gP(%s, GMic(child: gBox(%s))%s)" % (geo, ', '.join(args), extra))
        else:
            out.append("gP(%s, gBox(%s)%s%s)" % (geo, ', '.join(args), extra, tp))
        if role and role[0] == 'input':
            tn = role[1]['t']
            st_ = tn['style']
            f_ = solid_fill(tn)
            hc = color(f_['color'], f_.get('opacity', 1)) if f_ else 'Color(0xFF8C8A93)'
            obs = ', obscure: true' if (re.search('mot de passe|password', tn['characters'], re.I) or set(tn['characters'].strip()) == {'•'}) else ''
            dark = bool(f_) and lum(f_['color']) < 0.35 and set(tn['characters'].strip()) != {'•'}
            txt = ("hint: '', initial: %s" % dq(tn['characters'])) if dark else ("hint: %s" % dq(tn['characters']))
            bi_ = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n['id'], {})
            cb_ = ''
            if bi_.get('onChanged'):
                cb_ += ', onChanged: (v) { %s }' % bi_['onChanged']
            if bi_.get('onSubmitted'):
                cb_ += ', onSubmitted: (v) { %s }' % bi_['onSubmitted']
            if bi_.get('initial'):
                txt = txt.split(', initial')[0] + ', initial: ' + bi_['initial'] if 'initial' in txt else txt + ', initial: ' + bi_['initial']
            out.append("gP(%s, GField(%s, size: %s, hintColor: %s, weight: %d, padL: %s%s%s%s))" % (
                geo, txt, num(st_.get('fontSize', 14)), hc, int(st_.get('fontWeight', 400)), num(role[1]['left']),
                ', inter: true' if 'inter' in st_.get('fontFamily', '').lower() else '', obs, cb_))
    elif tap and t in ('RECTANGLE', 'ELLIPSE', 'FRAME', 'GROUP', 'INSTANCE', 'COMPONENT'):
        out.append("gP(%s, const SizedBox.expand()%s, tap: %s)" % (geo, extra, tap))
    if t in ('FRAME', 'GROUP', 'INSTANCE', 'COMPONENT', 'SECTION'):
        if tap and drawn and t in ('FRAME', 'GROUP', 'INSTANCE', 'COMPONENT'):
            out.append("gP(%s, const SizedBox.expand(), tap: %s)" % (geo, tap))
        kids = [c for c in n.get('children', []) if c.get('visible', True)]
        if t == 'FRAME' and nm.startswith('icon/heart'):
            for c in kids:
                emit_node(ctx, c, M, ox, oy, out)
            fav_ = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n['id'], {}).get('favorite')
            out.append("gP(%s, %s)" % (', '.join([num(x - 8), num(y - 8), num(w + 16), num(h + 16)]), ('GHeartLive(title: %s)' % fav_) if fav_ else 'GHeart()'))
            return
        clip = n.get('clipsContent') and any(
            (c['absoluteBoundingBox']['x'] < n['absoluteBoundingBox']['x'] - 1 or c['absoluteBoundingBox']['y'] < n['absoluteBoundingBox']['y'] - 1 or
             c['absoluteBoundingBox']['x'] + c['absoluteBoundingBox']['width'] > n['absoluteBoundingBox']['x'] + n['absoluteBoundingBox']['width'] + 1 or
             c['absoluteBoundingBox']['y'] + c['absoluteBoundingBox']['height'] > n['absoluteBoundingBox']['y'] + n['absoluteBoundingBox']['height'] + 1)
            for c in kids if c.get('absoluteBoundingBox')) and not rot
        if clip:
            inner = []
            for c in kids:
                emit_node(ctx, c, M, M[0][2], M[1][2], inner)
            out.append("gClip(%s, %s, [\n%s\n])" % (geo, r or 'null', ',\n'.join(inner)))
        else:
            for c in kids:
                emit_node(ctx, c, M, ox, oy, out)


def emit_node(ctx, n, PM, ox, oy, out, root=False):
    b = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n.get('id'), {}) if not root else {}
    if b.get('skip'):
        return
    if b.get('before'):
        out.extend(b['before'])
    start = len(out)
    _emit_node_inner(ctx, n, PM, ox, oy, out, root)
    if b.get('show'):
        for k in range(start, len(out)):
            e = out[k]
            if e.startswith('gP(') and e.endswith(')'):
                out[k] = e[:-1] + ', show: (%s))' % b['show']
    if b.get('after'):
        out.extend(b['after'])

def emit_text(ctx, n, geo, x, y, w, h, extra, tap, out):
    st = n['style']
    fam = st.get('fontFamily', '')
    inter = 'inter' in fam.lower()
    size = st.get('fontSize', 12)
    weight = int(st.get('fontWeight', 400))
    fl = vis(n.get('fills'))
    c = fl[-1]['color'] if fl and fl[-1]['type'] == 'SOLID' else {'r': 0, 'g': 0, 'b': 0, 'a': 1}
    op = n.get('opacity', 1.0) * (fl[-1].get('opacity', 1) if fl else 1)
    col = color(c, op)
    lh = None
    if st.get('lineHeightUnit') != 'INTRINSIC_%' and st.get('lineHeightPx'):
        lh = st['lineHeightPx']
    ls = st.get('letterSpacing') or 0
    al = {'LEFT': 'left', 'CENTER': 'center', 'RIGHT': 'right', 'JUSTIFIED': 'justify'}.get(st.get('textAlignHorizontal', 'LEFT'), 'left')
    wrap = st.get('textAutoResize', 'WIDTH_AND_HEIGHT') != 'WIDTH_AND_HEIGHT'
    rb = False
    chars = n['characters']
    if st.get('textCase') == 'UPPER':
        chars = chars.upper()
    common = []
    if inter:
        common.append('inter: true')
    if lh:
        common.append('lh: ' + num(lh))
    if ls:
        common.append('ls: ' + num(ls))
    if al != 'left':
        common.append('align: TextAlign.' + al)
    if wrap:
        common.append('wrap: true')
    if st.get('textDecoration') == 'UNDERLINE':
        common.append('deco: TextDecoration.underline')
    ov = n.get('characterStyleOverrides') or []
    tbl = n.get('styleOverrideTable') or {}
    if ov and any(ov) and tbl:
        runs = []
        i = 0
        L = len(chars)
        ov = ov + [0] * (L - len(ov))
        while i < L:
            j = i
            while j < L and ov[j] == ov[i]:
                j += 1
            s = dict(st)
            fills = vis(n.get('fills'))
            rc = col
            if ov[i] and str(ov[i]) in tbl:
                o = tbl[str(ov[i])]
                s.update({k: v for k, v in o.items() if k != 'fills'})
                if o.get('fills'):
                    f0 = vis(o['fills'])
                    if f0 and f0[-1]['type'] == 'SOLID':
                        rc = color(f0[-1]['color'], op)
            runs.append("(%s, %s, %d, %s)" % (dq(chars[i:j]), num(s.get('fontSize', size)), int(s.get('fontWeight', weight)), rc))
            i = j
        w_ = 'gRich([%s]%s)' % (', '.join(runs), ''.join(', ' + a for a in common if not a.startswith('deco')))
    else:
        b_ = BINDINGS.get(ctx.sid, {}).get('nodes', {}).get(n['id'], {})
        if b_.get('text'):
            if b_.get('color'):
                col = '(%s)' % b_['color']
            if b_.get('right') and not wrap:
                rb = True
                common = [a for a in common if not a.startswith(('wrap', 'align'))] + ['wrap: true', 'align: TextAlign.right']
            w_ = 'Consumer(builder: (context, ref, _) => gText(%s, %s, %s%s))' % (b_['text'], num(size), col, (', weight: %d' % weight if weight != 400 else '') + ''.join(', ' + a for a in common))
        else:
            w_ = 'gText(%s, %s, %s%s)' % (dq(chars), num(size), col, (', weight: %d' % weight if weight != 400 else '') + ''.join(', ' + a for a in common))
    gx, gy, gw, gh = x, y, w, h
    if rb:
        gx, gw = x + w - (w + 140), w + 140
    elif wrap:
        # tolérance de 3 px pour éviter les retours à la ligne dus aux petites différences de police
        d = {'left': 0, 'center': 1.5, 'right': 3, 'justify': 0}[al]
        gx, gw = x - d, w + 3
    g = '%s, %s, %s, %s' % (num(gx), num(gy), num(gw), num(gh))
    t = (', tap: ' + tap) if tap else ''
    out.append("gP(%s, %s%s%s)" % (g, w_, extra, t))

# ---------- écran complet ----------
def class_name(sid):
    return 'G_' + re.sub(r'[^0-9A-Za-z]', '_', sid)

def convert(sid):
    nid = REG[sid]
    fn = os.path.join(CACHE, 'nodes', nid.replace(':', '_') + '.json')
    if not os.path.exists(fn):
        print('manque', sid, nid)
        return None
    doc = json.load(open(fn, encoding='utf-8'))['document']
    ctx = Ctx(sid)
    CUR['root'] = nid
    CUR['sid'] = sid
    w, h = doc['size']['x'], doc['size']['y']
    SIZES[sid] = (w, h)
    analyze(doc, nid)
    out = []
    ident = [[1, 0, 0], [0, 1, 0]]
    sk = BINDINGS.get(sid, {}).get('skipRegion')
    inserted = False
    for c in doc.get('children', []):
        if sk:
            cy = c['relativeTransform'][1][2]
            if sk[0] <= cy < sk[1]:
                if not inserted:
                    out.append('...' + BINDINGS[sid]['liveCall'])
                    inserted = True
                continue
        emit_node(ctx, c, ident, 0, 0, out)
    bl = BINDINGS.get(sid, {}).get('links', {})
    used = set()
    drop = set(BINDINGS.get(sid, {}).get('dropLinks', []))
    for box, dest in LINKS.get(nid, []):
        bx = [float(v) for v in box.split(',')]
        if box in drop:
            continue
        if box in bl:
            used.add(box)
            out.append("gTap(%s, %s, %s, %s, () { %s })" % (num(bx[0]), num(bx[1]), num(bx[2]), num(bx[3]), bl[box]))
        elif dest in NODE2ID and dest != nid:
            out.append("gTap(%s, %s, %s, %s, () => gOpen(context, %s))" % (num(bx[0]), num(bx[1]), num(bx[2]), num(bx[3]), dq(NODE2ID[dest])))
    for box, stmt in bl.items():
        if box not in used:
            bx = [float(v) for v in box.split(',')]
            out.append("gTap(%s, %s, %s, %s, () { %s })" % (num(bx[0]), num(bx[1]), num(bx[2]), num(bx[3]), stmt))
    root_args = ['w: %s' % num(w), 'h: %s' % num(h)]
    rr = doc.get('cornerRadius', 0)
    if rr:
        root_args.append('radius: ' + num(rr))
    fa = fill_args(ctx, doc, w, h, 1.0)
    for a in fa:
        if a.startswith('gradient: '):
            root_args.append('bg: ' + a[10:])
        elif a.startswith('color: '):
            root_args.append('color: ' + a[7:])
    body = ',\n      '.join(out)
    cls = class_name(sid)
    code = """// GÉNÉRÉ par tool/figma_export/convert.py — écran %s (nœud Figma %s). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class %s extends ConsumerWidget {
  const %s({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(%s, children: [
      %s,
    ]);
  }
}
""" % (sid, nid, cls, cls, ', '.join(root_args), body)
    open(os.path.join(OUT, cls.lower() + '.dart'), 'w', encoding='utf-8').write(code)
    return ctx

# ---------- téléchargements ----------
def http_get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    return urllib.request.urlopen(req, timeout=120).read()

def download_images(refs):
    todo = [r for r in refs if not os.path.exists(os.path.join(ASSET, 'img', r + '.png'))]
    def one(r):
        u = IMAGEREFS.get(r)
        if u:
            try:
                open(os.path.join(ASSET, 'img', r + '.png'), 'wb').write(http_get(u))
            except Exception as e:
                print('image KO', r, e)
    with ThreadPoolExecutor(8) as ex:
        list(ex.map(one, todo))

def export_rasters(ids):
    todo = [i for i in ids if not os.path.exists(os.path.join(ASSET, 'r', i.replace(':', '_') + '.png'))]
    for k in range(0, len(todo), 40):
        chunk = todo[k:k + 40]
        url = 'https://api.figma.com/v1/images/%s?ids=%s&format=png&scale=2&use_absolute_bounds=true' % (FILE, urllib.parse.quote(','.join(chunk)))
        data = json.loads(http_get(url, {'X-Figma-Token': TOKEN}))
        def one(item):
            i, u = item
            if u:
                open(os.path.join(ASSET, 'r', i.replace(':', '_') + '.png'), 'wb').write(http_get(u))
        with ThreadPoolExecutor(8) as ex:
            list(ex.map(one, data.get('images', {}).items()))

if __name__ == '__main__':
    ids = sys.argv[1:] or list(REG.keys())
    ctxs = []
    for sid in ids:
        if sid in REG:
            c = convert(sid)
            if c:
                ctxs.append(c)
    imgs = set().union(*[c.images for c in ctxs]) if ctxs else set()
    ras = sorted({i for c in ctxs for i in c.rasters})
    print(len(ctxs), 'écrans,', len(imgs), 'images,', len(ras), 'rasters')
    download_images(imgs)
    export_rasters(ras)
    # registre des écrans générés
    done = sorted(os.path.basename(f)[:-5] for f in glob.glob(os.path.join(OUT, '*.dart')))
    sid_by_cls = {class_name(s).lower(): s for s in REG}
    lines = ["// GÉNÉRÉ par tool/figma_export/convert.py", "// ignore_for_file: unused_import", "import 'package:flutter/widgets.dart';"]
    lines += ["import 'g/%s.dart';" % d for d in done]
    lines.append('final Map<String, WidgetBuilder> gBuilders = {')
    for d in done:
        s = sid_by_cls.get(d)
        if s:
            lines.append("  %s: (_) => const %s()," % (dq(s), class_name(s)))
    lines.append('};')
    sizes = json.load(open(os.path.join(CACHE, 'sizes.json'))) if os.path.exists(os.path.join(CACHE, 'sizes.json')) else {}
    sizes.update({k: [v[0], v[1]] for k, v in SIZES.items()})
    json.dump(sizes, open(os.path.join(CACHE, 'sizes.json'), 'w'))
    lines.append('/// Largeur des écrans générés (pour choisir le format mobile / web / tablette / borne).')
    lines.append('final Map<String, double> gWidths = {')
    for k in sorted(sizes):
        lines.append('  %s: %s,' % (dq(k), num(sizes[k][0])))
    lines.append('};')
    open(os.path.join(ROOT, 'lib', 'figma', 'registry.dart'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
