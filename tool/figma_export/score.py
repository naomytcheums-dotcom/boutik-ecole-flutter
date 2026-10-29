import sys,os,statistics,time
sys.path.insert(0,os.path.dirname(__file__)); sys.argv=['x']
import convert as c
from PIL import Image, ImageChops, ImageStat
ROOT=c.ROOT
res=[];bad=[]
for sid,nid in c.REG.items():
    g=f'{ROOT}/test/golden/goldens/{sid}.png'; r=f'{c.CACHE}/ref/{nid.replace(":","_")}.png'
    try:
        a=Image.open(g).convert('RGB'); b=Image.open(r).convert('RGB')
    except Exception:
        bad.append(sid); continue
    note=''
    if a.size!=b.size: note=f'{a.size} vs {b.size}'; b=b.resize(a.size,Image.LANCZOS)
    s=(a.width//2,a.height//2)
    d=ImageChops.difference(a.resize(s),b.resize(s))
    res.append((sum(ImageStat.Stat(d).mean)/3,sid,note))
res.sort(reverse=True)
ms=[x[0] for x in res]
print('invalides:',bad)
print('médiane',round(statistics.median(ms),2),'moyenne',round(sum(ms)/len(ms),2))
print('>12:',sum(1 for m in ms if m>12),' 6-12:',sum(1 for m in ms if 6<m<=12),' <=6:',sum(1 for m in ms if m<=6))
for m,s,n in res[:int(sys.argv[1]) if len(sys.argv)>1 else 30]: print(round(m,1),s,n)
