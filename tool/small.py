import os,sys
from PIL import Image
c,o=sys.argv[1],sys.argv[2]; os.makedirs(o,exist_ok=True)
for f in os.listdir(c):
    im=Image.open(os.path.join(c,f)); w,h=im.size
    s = 0.5 if w<1700 else 0.4
    im.resize((int(w*s),int(h*s)),Image.LANCZOS).save(os.path.join(o,f.replace('.png','.jpg')),quality=85)
print(len(os.listdir(o)))
