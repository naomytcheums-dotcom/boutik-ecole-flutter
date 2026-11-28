// Contrats frontend <-> backend (aucun reseau) :
//   node --test tool/contract/contracts.test.mjs
// Le test echoue des qu'un appel rpc/table/colonne/bucket/Edge Function du Dart ne correspond plus aux
// migrations, sauf exception justifiee dans tool/contract/exceptions.json.
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scanDart } from './dart_scan.mjs';
import { compare, applyExceptions, run } from './check_contracts.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

const catalog = {
  functions: { known_fn: [{ names: ['p_id', 'p_note'], required: ['p_id'], anon: false, auth: true }] },
  tables: {
    orders: { kind: 'r', cols: ['id', 'status', 'buyer_id', 'created_at', 'item_id'] },
    items: { kind: 'r', cols: ['id', 'sku'] },
    events: { kind: 'r', cols: ['id'] },
  },
  fks: [{ name: 'orders_item_id_fkey', src: 'orders', dst: 'items', cols: ['item_id'] }],
  buckets: [{ id: 'real-bucket' }],
  edge: ['known-edge'],
  replayed: 1, total: 1, failed: [],
};

test('le controle detecte chaque famille d\'ecart (fixture volontairement fausse)', () => {
  const scan = scanDart(path.join(here, 'fixtures'));
  const keys = new Set(compare(scan, catalog).map((f) => f.key));
  assert.deepEqual([...keys].sort(), [
    'bucket_missing|ghost-bucket',
    'column_missing|orders.ghost_col',
    'column_missing|orders.ghost_written',
    'column_missing|items.ghost_item_col',
    'edge_missing|ghost-edge',
    'embed_missing|orders->nowhere',
    'rpc_missing|ghost_fn',
    'rpc_missing_required|known_fn(p_id)',
    'rpc_unknown_param|known_fn(p_typo)',
    'table_missing|ghost_table',
  ].sort());
});

test('les exceptions sont appliquees et les exceptions obsoletes signalees', () => {
  const f = [{ key: 'rpc_missing|a' }, { key: 'rpc_missing|b' }];
  const r = applyExceptions(f, [{ key: 'rpc_missing|a', reason: 'x' }, { key: 'rpc_missing|zzz', reason: 'y' }]);
  assert.deepEqual(r.open.map((x) => x.key), ['rpc_missing|b']);
  assert.deepEqual(r.stale.map((x) => x.key), ['rpc_missing|zzz']);
});

test('le code Dart reel respecte les contrats Supabase (migrations rejouees)', { timeout: 900000 }, async () => {
  const { open, cat, exceptions } = await run();
  assert.equal(cat.failed.length, 0, `migrations en echec au rejeu : ${JSON.stringify(cat.failed)}`);
  for (const e of exceptions) assert.ok(e.reason && e.reason.length > 10, `exception sans justification : ${e.key}`);
  assert.deepEqual(open.map((f) => `${f.key} @ ${f.at} - ${f.detail}`), [], 'ecarts frontend/backend non justifies');
});
