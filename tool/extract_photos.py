"""Extrait des photos des captures Figma (coordonnées en px de maquette, 1x).
Usage : python tool/extract_photos.py <dossier_crops> assets/images"""
import sys, os
from PIL import Image
crops, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
S = 2  # les captures recadrées sont en 2x
spec = [
 # (nom, écran, x0, y0, x1, y1)
 ('coder','287',46,262,250,460), ('solar','287',278,262,482,460), ('builder','287',510,262,714,460),
 ('student_hijab','287',46,612,250,810),
 ('lamp','03',20,565,158,716), ('bulb','03',211,565,348,716),
 ('bissap','263',421,196,594,281), ('phone','263',220,411,393,497), ('maquette','263',421,411,594,497),
 ('technician','263',622,411,795,497), ('office','263',823,411,996,497),
 ('avatar_woman','03',347,63,381,97),
 ('portrait_woman','01',24,72,220,290), ('food_spread','01',232,207,366,334),
 ('hero_student','03',232,322,388,478),
 ('laptop_meeting','04',20,187,160,322), ('plants','04',212,190,348,310), ('plant_pot','04',22,498,160,596),
 ('phone_stand','04',208,490,345,600), ('enterprise','04',250,756,372,902),
 ('team','05',0,112,390,338), ('avatar_creator','05',24,664,90,730),
 ('paint','06',26,142,131,270), ('paint_red','06',26,310,131,436), ('branding','06',26,474,131,600),
 ('sketch','09',46,357,114,425),
 ('scrabble','19',0,100,390,180),
 ('bag_design','20',26,252,184,364), ('drone_logo','20',212,252,370,364),
 ('drone','20',26,512,184,624), ('backpacks','20',212,512,370,624),
]
only = set(sys.argv[3:])
for name, sid, x0, y0, x1, y1 in spec:
    if only and name not in only: continue
    im = Image.open(os.path.join(crops, sid + '.png')).convert('RGB')
    c = im.crop((x0*S, y0*S, x1*S, y1*S))
    c.save(os.path.join(out, name + '.jpg'), quality=88)
    print(name, c.size)





