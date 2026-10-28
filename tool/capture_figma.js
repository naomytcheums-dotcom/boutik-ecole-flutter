const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [manifest, out, workers, waitMs] = process.argv.slice(2);
  const items = JSON.parse(fs.readFileSync(manifest,'utf8')).filter(x => !fs.existsSync(`${out}/${x.node.replace(':','-')}.png`));
  console.log('todo', items.length);
  const browser = await chromium.launch({ headless: false });
  const ctx = await browser.newContext({ viewport: { width: 1520, height: 1820 }, deviceScaleFactor: 2 });
  const base='https://www.figma.com/proto/q3uvJnUobbPfhLbcaj0PzJ/x?scaling=scale-down&hide-ui=1&content-scaling=fixed&page-id=0:1&node-id=';
  let idx = 0;
  async function worker(w){
    const page = await ctx.newPage();
    while (idx < items.length){
      const it = items[idx++];
      const f = `${out}/${it.node.replace(':','-')}.png`;
      try {
        await page.goto(base+it.node.replace(':','-'), { waitUntil: 'domcontentloaded', timeout: 120000 }).catch(()=>{});
        await page.waitForTimeout(+waitMs);
        await page.screenshot({ path: f, timeout: 60000 });
        console.log(w, it.id, it.node, 'ok');
      } catch(e){ console.log(w, it.id, 'ERR', e.message.slice(0,80)); }
    }
  }
  await Promise.all([...Array(+workers).keys()].map(worker));
  await browser.close();
})();
