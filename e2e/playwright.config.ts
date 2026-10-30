import { defineConfig } from '@playwright/test';

// Tests de navigateur réels sur l'application déployée (Flutter Web, rendu CanvasKit).
// Usage : BASE_URL=https://boutik-ecole.vercel.app npx playwright test
export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  retries: 1,
  workers: 2,
  reporter: [['list'], ['json', { outputFile: 'results/report.json' }]],
  outputDir: 'results/artefacts',
  use: {
    baseURL: process.env.BASE_URL ?? 'https://boutik-ecole.vercel.app',
    viewport: { width: 390, height: 844 },
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    launchOptions: { args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] },
  },
});
