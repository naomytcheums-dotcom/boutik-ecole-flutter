import { expect, test } from '@playwright/test';
async function ouvrir(page, hash: string) {
  const err: string[] = [];
  page.on('pageerror', (e) => err.push(e.message));
  await page.goto('/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(2500);
  await page.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; e?.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
  await page.waitForTimeout(2000);
  return err;
}
const texte = async (page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');
test('page /design : nouvelle direction visuelle, sans erreur', async ({ page }) => {
  const err = await ouvrir(page, '#/design');
  await expect.poll(() => texte(page), { timeout: 20_000 }).toContain('Nouvelle direction visuelle');
  expect(err).toEqual([]);
  await page.screenshot({ path: 'results/design-en-ligne.png' });
});
test('reels (245) en ligne : aucun reel inventé', async ({ page }) => {
  const err = await ouvrir(page, '#/s/245');
  await expect.poll(() => texte(page), { timeout: 20_000 }).toContain('Aucun reel publié');
  expect(await texte(page)).not.toContain('Brice N.');
  expect(err).toEqual([]);
});