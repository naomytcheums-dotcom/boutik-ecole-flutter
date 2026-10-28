import sys, os
from PIL import Image
crops, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
# (nom, écran, boîte en coordonnées "small", échelle small)
spec = [
 ('coder','287',(40,256,256,466),.5), ('solar','287',(272,256,488,466),.5), ('builder','287',(504,256,720,466),.5),
 ('student_hijab','287',(40,606,256,816),.5),
 ('lamp','03',(15,559,158,722),.5), ('bulb','03',(205,559,348,722),.5),
 ('bissap','263',(415,190,600,287),.4), ('phone','263',(214,405,399,503),.4), ('maquette','263',(415,405,600,503),.4),
 ('technician','263',(616,405,801,503),.4), ('office','263',(817,405,1002,503),.4),
 ('map_cameroon','267',(250,125,530,520),.4),
 ('avatar_woman','03',(347,63,381,97),.5),
]
for name, sid, (x0,y0,x1,y1), sc in spec:
    im = Image.open(os.path.join(crops, sid+'.png')).convert('RGB')
    k = 1/sc; ins = 0 if name.startswith(('map','avatar')) else 6
    box = (int((x0+ins)*k), int((y0+ins)*k), int((x1-ins)*k), int((y1-ins)*k))
    c = im.crop(box)
    c.save(os.path.join(out, name+'.jpg'), quality=88)
    print(name, c.size)

