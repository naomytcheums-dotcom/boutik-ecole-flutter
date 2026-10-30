import { expect, Page, test } from '@playwright/test';

// Flutter Web dessine dans un canvas : on active l'arbre d'accessibilité pour lire les textes affichés.
async function ouvrir(page: Page, hash: string) {
  const erreurs: string[] = [];
  page.on('pageerror', (e) => erreurs.push(e.message));
  page.on('console', (m) => {
    if (m.type() === 'error' && !/favicon|DevTools|Failed to load resource.*(404|401)/i.test(m.text())) erreurs.push(m.text());
  });
  await page.goto('/' + hash);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 45_000 });
  await page.waitForTimeout(3000);
  await page.evaluate(() => { const e = document.querySelector('flt-semantics-placeholder') as HTMLElement | null; e?.dispatchEvent(new MouseEvent('click', { bubbles: true })); e?.focus(); });
  await page.waitForTimeout(2500);
  return erreurs;
}

const texte = async (page: Page) => (await page.evaluate(() => (document.querySelector('flt-semantics-host') as HTMLElement | null)?.innerText ?? '')).replace(/\s+/g, ' ');

test.describe('Visiteur : explorer sans compte', () => {
  test('le site se charge sans erreur JavaScript et dessine l\'application', async ({ page }) => {
    const erreurs = await ouvrir(page, '#/s/03');
    await expect(page.locator('flt-glass-pane')).toBeAttached();
    expect(erreurs, erreurs.join('\n')).toEqual([]);
    await page.screenshot({ path: 'results/visiteur-accueil.png' });
  });

  test('« Commencer » ouvre l\'accueil : aucune inscription ni connexion imposée', async ({ page }) => {
    await ouvrir(page, '#/s/02');
    // bouton « Commencer » : zone (59,716)-(337,763) du cadre 390×844
    await page.mouse.click(198, 739);
    await expect.poll(async () => await texte(page), { timeout: 20_000 }).toContain('Bienvenue');
    const t = await texte(page);
    expect(t).not.toContain('Se connecter');   // aucun écran de connexion imposé
    expect(t).not.toContain('Créer un compte');
    await page.screenshot({ path: 'results/visiteur-commencer.png' });
  });

  test('« Mes rubriques » est accessible au visiteur et ne liste pas les espaces réservés', async ({ page }) => {
    await ouvrir(page, '#/espace');
    const t = await texte(page);
    expect(t).toContain('Mes rubriques');
    expect(t).toContain('Visiteur');
    expect(t).not.toContain('Administration globale');
    expect(t).not.toContain('Espace étudiant-vendeur');
    await page.screenshot({ path: 'results/visiteur-rubriques.png' });
  });

  test('un écran réservé aux vendeurs affiche une page 404 neutre au visiteur', async ({ page }) => {
    await ouvrir(page, '#/s/57');
    const t = await texte(page);
    expect(t).toContain('404');
    expect(t).not.toContain('Tableau de bord vendeur');
  });

  test('un écran inexistant est signalé proprement', async ({ page }) => {
    await ouvrir(page, '#/s/99999');
    const t = await texte(page);
    expect(t).toMatch(/introuvable|404/i);
  });
});

test.describe('Responsive : aucun débordement horizontal', () => {
  for (const [nom, w, h] of [['petit téléphone', 375, 667], ['téléphone', 390, 844], ['tablette', 768, 1024], ['portable', 1280, 800], ['grand écran', 1440, 900]] as const) {
    test(`${nom} (${w}×${h})`, async ({ page }) => {
      await page.setViewportSize({ width: w, height: h });
      await ouvrir(page, '#/s/03');
      const debord = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      expect(debord).toBeLessThanOrEqual(1);
      await page.screenshot({ path: `results/responsive-${w}x${h}.png` });
    });
  }
});

test.describe('Rechargement, retour arrière et liens directs', () => {
  test('un lien direct vers un écran public se recharge sur le même écran', async ({ page }) => {
    await ouvrir(page, '#/s/04');
    await page.reload();
    await page.waitForSelector('flt-glass-pane', { state: 'attached' });
    expect(page.url()).toContain('#/s/04');
  });

  test('retour arrière du navigateur : revient à l\'écran précédent', async ({ page }) => {
    await ouvrir(page, '#/s/03');
    await page.evaluate(() => (location.hash = '#/s/04'));
    await page.waitForFunction(() => location.hash.includes('/s/04'));
    await page.goBack();
    await page.waitForFunction(() => location.hash.includes('/s/03'));
    expect(page.url()).toContain('#/s/03');
  });
});
