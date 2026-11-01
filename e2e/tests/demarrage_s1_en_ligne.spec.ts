import { expect, test } from '@playwright/test';
test('racine du site : S1 « Chargement… » puis accueil 01, sans erreur JavaScript', async ({ page }) => {
  const err: string[] = [];
  page.on('pageerror', (e) => err.push(e.message));
  await page.goto('/');
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45_000 });
  await page.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; e?.dispatchEvent(new MouseEvent('click', { bubbles: true })); });
  await expect.poll(async () => page.url(), { timeout: 30_000 }).toContain('/s/01');
  const t = await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '');
  expect(t).not.toContain('Chargement…');
  expect(err).toEqual([]);
});
