// Précharge (node --import) : faux « Deno » (env + serve) et crochets de résolution. Voir contract.test.mjs pour la commande.
import { register } from 'node:module';

const world = {
  env: {}, handler: null, tokens: new Map(),
  dbCalls: [], rpcCalls: [], authCalls: [], fetchCalls: [], logs: [],
  tableResult: () => ({ data: null, error: null, count: 0 }),
  rpcResult: () => ({ data: null, error: null }),
};
globalThis.__CONTRACT__ = world;
globalThis.Deno = {
  env: { get: (k) => world.env[k] },
  serve: (h) => { world.handler = h; return {}; },
};
// Aucun appel réseau réel : tout fetch est consigné puis refusé.
globalThis.fetch = async (url, init) => { world.fetchCalls.push({ url: String(url), method: init?.method ?? 'GET' }); if (world.fetchImpl) return world.fetchImpl(String(url), init); throw new Error('réseau interdit dans les tests de contrat'); };
for (const m of ['log', 'error', 'warn', 'info']) { const orig = console[m].bind(console); console[m] = (...a) => { world.logs.push(a.map((x) => (typeof x === 'string' ? x : JSON.stringify(x))).join(' ')); if (process.env.CONTRACT_VERBOSE) orig(...a); }; }
register('./loader.mjs', import.meta.url);
