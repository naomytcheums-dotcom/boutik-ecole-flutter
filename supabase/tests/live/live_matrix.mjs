// Appelle les fonctions de lecture (STABLE) avec chacun des 10 comptes de test sur le serveur RÉEL : codes HTTP, lignes renvoyées, données de maquette.
// Usage : LIVE_PASSWORD=... node supabase/tests/live/live_matrix.mjs   (sortie : live_matrix.json, ou LIVE_OUT)
const url = process.env.LIVE_URL || 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co', key = process.env.LIVE_KEY || 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01', PW = process.env.LIVE_PASSWORD;
if (!PW) { console.error('Définir LIVE_PASSWORD (mot de passe des comptes test-<rôle>@boutik-ecole.test).'); process.exit(2); }
import fs from 'fs';
const url='https://zxqcnmgwhtbxkdpjqtlr.supabase.co', key='sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01', PW='France2020!@';
const ROLES=['visitor','client','student','company','other','dept','direction','finance','support','admin'];
const names=JSON.parse(fs.readFileSync(new URL('./live_read_functions.json', import.meta.url),'utf8'));
const FAKE=['Mariam Essono','Aminata Bello','Brice Ndoumbe','Kouassi Tagne','Orange Cameroun','Ngono Aminata','Team Innov','Mbarga','Sac à dos design','Drone éducatif','Lampe en bois recyclé'];
async function login(r){const res=await fetch(url+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({email:`test-${r}@boutik-ecole.test`,password:PW})});const j=await res.json();return j.access_token;}
const res={};
for(const r of ROLES){
  const tok=await login(r); res[r]={};
  const q=[...names];
  async function worker(){ while(q.length){ const fn=q.shift(); try{
    const x=await fetch(url+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:key,Authorization:'Bearer '+tok,'Content-Type':'application/json'},body:'{}'});
    const t=await x.text(); let n='-'; try{const j=JSON.parse(t); n=Array.isArray(j)?j.length:(j&&typeof j==='object'?Object.keys(j).length+'k':String(j).slice(0,12));}catch{}
    const fake=FAKE.filter(f=>t.includes(f));
    let m=''; if(x.status>=400){try{m=(JSON.parse(t).message||JSON.parse(t).code||'').slice(0,70)}catch{m=t.slice(0,40)}}
    res[r][fn]={s:x.status,n,m,fake};
  }catch(e){res[r][fn]={s:0,m:e.message.slice(0,40)}} } }
  await Promise.all(Array.from({length:10},worker));
  fs.writeFileSync(process.env.LIVE_OUT || 'live_matrix.json',JSON.stringify(res));
  console.log('fini',r);
}
