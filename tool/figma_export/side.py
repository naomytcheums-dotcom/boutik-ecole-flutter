import sys,os
sys.path.insert(0,os.path.dirname(__file__)); ids=sys.argv[1:]; sys.argv=['x']
import convert as c
from PIL import Image
tiles=[]
for sid in ids:
    r=Image.open(f'{c.CACHE}/ref/{c.REG[sid].replace(":","_")}.png').convert('RGB'); g=Image.open(f'{c.ROOT}/test/golden/goldens/{sid}.png').convert('RGB')
    H=700; 
    r=r.resize((int(r.width*H/r.height),H)); g=g.resize((int(g.width*H/g.height),H))
    tiles+=[r,g]
W=sum(t.width for t in tiles)+10*len(tiles); im=Image.new('RGB',(W,700),'white'); x=0
for t in tiles: im.paste(t,(x,0)); x+=t.width+10
im.save(f'{c.CACHE}/side.png'); print(im.size)
