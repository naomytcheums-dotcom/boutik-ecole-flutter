"""Télécharge depuis l'API REST de Figma : l'arbre JSON de chaque écran + les images (photos) utilisées.
Le jeton est lu dans tool/figma_export/.figma_token (jamais affiché, jamais commité)."""
import json, os, sys, urllib.request, urllib.parse, time
HERE=os.path.dirname(os.path.abspath(__file__)); CACHE=os.path.join(HERE,'cache'); os.makedirs(CACHE+'/nodes',exist_ok=True); os.makedirs(CACHE+'/img',exist_ok=True)
FILE='q3uvJnUobbPfhLbcaj0PzJ'
TOKEN=open(os.path.join(HERE,'.figma_token')).read().strip()
def api(path):
    req=urllib.request.Request('https://api.figma.com'+path,headers={'X-Figma-Token':TOKEN})
    for i in range(5):
        try: return json.load(urllib.request.urlopen(req,timeout=120))
        except urllib.error.HTTPError as e:
            if e.code==429: time.sleep(20); continue
            raise
def ids_from_manifest():
    import re
    ids=[]
    for l in open(os.path.join(HERE,'..','..','docs','SCREENS_MANIFEST.md'),encoding='utf-8'):
        for m in re.finditer(r'=\s*(\d+:\d+)',l): ids.append(m.group(1))
        for m in re.finditer(r'(\d+:\d+)',l.split('=')[-1]) if False else []: pass
    return list(dict.fromkeys(ids))
if __name__=='__main__':
    ids=ids_from_manifest(); print(len(ids),'écrans')
    for i in range(0,len(ids),6):
        chunk=[x for x in ids[i:i+6] if not os.path.exists(f'{CACHE}/nodes/{x.replace(":","_")}.json')]
        if not chunk: continue
        data=api(f'/v1/files/{FILE}/nodes?ids='+urllib.parse.quote(','.join(chunk))+'&geometry=paths')
        for k,v in data['nodes'].items(): json.dump(v,open(f'{CACHE}/nodes/{k.replace(":","_")}.json','w'),ensure_ascii=False)
        print('ok',i)
    imgs=api(f'/v1/files/{FILE}/images')['meta']['images']
    json.dump(imgs,open(CACHE+'/imagerefs.json','w'))
    print(len(imgs),'images')
