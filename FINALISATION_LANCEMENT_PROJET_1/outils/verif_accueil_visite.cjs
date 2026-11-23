const { chromium } = require('@playwright/test');
const base = process.env.BASE, out = process.env.OUT;
const vps = [[360,800],[390,844],[430,932],[768,1024],[1024,768],[1280,720],[1440,900],[1920,1080]];
const size = { '02':[390,876], '03':[390,939], '175':[390,844], '176':[390,844], '177':[390,844] };
function geo(W,H,id){ const [w,h]=size[id]; if(h<=860){ const s=Math.min(1,W/w,H/h); return {s,x:(W-w*s)/2,y:(H-h*s)/2,h}; }
  const ws=Math.min(1,W/w), fit=Math.min(W/w,H/h);
  if(h*ws>H+1 && fit>=(W>=600?0.7:0.85*ws)) return {s:fit,x:(W-w*fit)/2,y:(H-h*fit)/2,h};
  if(h*ws<=H+1) return {s:ws,x:(W-w*ws)/2,y:(H-h*ws)/2,h};
  return {s:ws,x:(W-w*ws)/2,y:0,h}; }
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'] });
  const rows=[];
  for (const [W,H] of vps) {
    const p = await b.newPage({ viewport: { width: W, height: H } });
    const errs=[]; p.on('pageerror', e=>errs.push(e.message));
    const r={vp:`${W}x${H}`};
    await p.goto(base + '/#/s/02'); await p.waitForSelector('flt-glass-pane',{state:'attached',timeout:60000}); await p.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder'); e && e.dispatchEvent(new MouseEvent('click', { bubbles: true })); }); await p.waitForTimeout(3000);
    let g=geo(W,H,'02'); r.entier02 = (g.y>=-1 && g.y+g.h*g.s<=H+1); r.echelle02=g.s.toFixed(2);
    await p.screenshot({path:`${out}/l_02_${W}x${H}.png`});
    const txt=async()=> p.evaluate(()=>{ const h=document.querySelector('flt-semantics-host'); return h? h.innerText:''; }); const tap=async(id,x,y)=>{ const q=geo(W,H,id); await p.mouse.click(q.x+x*q.s, q.y+y*q.s); await p.waitForTimeout(1800); }; const ecran=async()=>{ const s=await txt(); return s.includes('Achetez local')?'176':s.includes('Vendez vos créations')?'175':s.includes('Recrutez les talents')?'177':s.includes('Produits en vedette')?'03':s.includes('Commencer')?'02':'?'; };
    await tap('02',198,739); r.apres_commencer=await ecran();
    await tap('176',284,787); r.apres_176=await ecran();
    await tap('175',284,787); r.apres_175=await ecran();
    await tap('177',284,787); r.apres_177=await ecran();
    await p.waitForTimeout(1500);
    g=geo(W,H,'03'); r.entier03=(g.y>=-1 && g.y+g.h*g.s<=H+1); r.echelle03=g.s.toFixed(2);
    const clip={x:Math.max(0,g.x+20*g.s),y:Math.max(0,g.y+330*g.s),width:300*g.s,height:150*g.s};
    const a=await p.screenshot({clip}); await p.screenshot({path:`${out}/l_03a_${W}x${H}.png`});
    await tap('03',53,478); const b2=await p.screenshot({clip}); await p.screenshot({path:`${out}/l_03b_${W}x${H}.png`});
    r.fleche_change = !a.equals(b2);
    await tap('03',53,478); await tap('03',53,478); const c=await p.screenshot({clip}); r.retour_1er = a.equals(c);
    r.erreursJS=errs.length; await p.mouse.move(W/2,H/2); const y0=await p.screenshot(); await p.mouse.wheel(0,1200); await p.waitForTimeout(800); r.molette03_inutile = y0.equals(await p.screenshot()); rows.push(r); await p.close();
  }
  console.table(rows); await b.close();
})();