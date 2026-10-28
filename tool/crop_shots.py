import json, sys, os
from PIL import Image
man, shots, crops = sys.argv[1:4]
os.makedirs(crops, exist_ok=True)
bad=[]; n=0
for it in json.load(open(man, encoding='utf-8')):
    f = os.path.join(shots, it['node'].replace(':','-')+'.png')
    o = os.path.join(crops, it['id']+'.png')
    if not os.path.exists(f) or (os.path.exists(o) and os.path.getmtime(o) > os.path.getmtime(f)): continue
    im = Image.open(f).convert('RGB')
    g = im.convert('L').point(lambda p: 255 if p > 12 else 0)
    bb = g.getbbox()
    if not bb or (bb[2]-bb[0]) < 300 or (bb[3]-bb[1]) < 300:
        bad.append(it['id']); os.makedirs(shots+'_bad',exist_ok=True); os.replace(f, os.path.join(shots+'_bad', os.path.basename(f))); continue
    im.crop(bb).save(o, optimize=True); n+=1
print('cropped', n, 'bad', bad)

