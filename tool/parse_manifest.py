import re, json, sys
src = open(sys.argv[1], encoding='utf-8').read()
sections = re.split(r'^## ', src, flags=re.M)[1:]
out = []
for sec in sections:
    title = sec.split('\n',1)[0].strip()
    if title.startswith('ORDRE'): continue
    body = sec.split('\n',1)[1]
    if title.startswith('1. NOUVEAUX'): code='NEW'
    elif title.startswith('Échantillons'): code='REF'
    else: code = title.split(' ')[0]
    for m in re.finditer(r'(?<![\w:])([0-9]{2,3}[a-z]?|[A-Z][0-9])(?: \((?:mobile|web)\))?=((?:\d+:\d+)(?:(?:, | et )\d+:\d+)*)', body):
        num, nodes = m.group(1), re.split(r', | et ', m.group(2))
        rest = body[m.end():m.end()+40]
        size = re.match(r' \((\d+)×(\d+)\)', rest)
        for i,n in enumerate(nodes):
            sid = num if len(nodes)==1 else f'{num}-{i+1}'
            out.append({'id': sid.zfill(2) if sid[0].isdigit() and len(sid.split('-')[0].rstrip('abc'))<2 else sid, 'node': n, 'section': code,
                        'w': int(size.group(1)) if size and len(nodes)==1 else None, 'h': int(size.group(2)) if size and len(nodes)==1 else None})
json.dump(out, open(sys.argv[2],'w',encoding='utf-8'), ensure_ascii=False, indent=0)
print(len(out)); from collections import Counter; print(Counter(o['section'] for o in out))
