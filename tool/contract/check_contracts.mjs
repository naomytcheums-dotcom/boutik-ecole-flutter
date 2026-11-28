// Contrats frontend <-> backend : compare les appels du code Dart (rpc, from, storage, functions.invoke,
// Realtime) aux objets definis par supabase/schema.sql + migrations rejoues dans PGlite.
// Usage : node tool/contract/check_contracts.mjs [--out rapport.json] [--catalog cache.json] [--strict]
// Sortie 1 si un ecart n'est pas liste dans tool/contract/exceptions.json (ou avec --strict si exception obsolete).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scanDart } from './dart_scan.mjs';
import { buildCatalog } from './catalog.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

// Controle pur (testable) : scan + catalogue -> liste d'ecarts.
export function compare(scan, cat) {
  const out = [];
  const add = (kind, name, at, detail) => out.push({ kind, name, at, detail, key: `${kind}|${name}` });

  for (const c of scan.rpc) {
    const overloads = cat.functions[c.name];
    if (!overloads) { add('rpc_missing', c.name, c.at, 'fonction absente des migrations'); continue; }
    if (!overloads.some((o) => o.auth)) add('rpc_no_execute', c.name, c.at, 'EXECUTE refuse a authenticated');
    if (c.keys == null) continue;
    const keys = new Set(c.keys);
    // appel ternaire : les cles conditionnelles ne visent pas forcement les deux fonctions
    const checked = c.ternary ? new Set(c.keys.filter((k) => !(c.optional || []).includes(k))) : keys;
    const accepting = overloads.filter((o) => [...checked].every((k) => o.names.includes(k)));
    if (accepting.length === 0) {
      const best = overloads.map((o) => [...checked].filter((k) => !o.names.includes(k))).sort((a, b) => a.length - b.length)[0];
      add('rpc_unknown_param', `${c.name}(${best.join(',')})`, c.at, `parametre(s) inconnu(s) ${best.join(', ')} ; signatures : ${overloads.map((o) => `(${o.names.join(', ')})`).join(' | ')}`);
      continue;
    }
    if (!c.dynamic && !accepting.some((o) => o.required.every((r) => keys.has(r)))) {
      const best = accepting.map((o) => o.required.filter((r) => !keys.has(r))).sort((a, b) => a.length - b.length)[0];
      add('rpc_missing_required', `${c.name}(${best.join(',')})`, c.at, `parametre(s) obligatoire(s) manquant(s) ${best.join(', ')}`);
    }
  }

  const fkByTable = new Map();
  for (const fk of cat.fks) (fkByTable.get(fk.src) ?? fkByTable.set(fk.src, []).get(fk.src)).push(fk);
  const resolveEmbed = (parent, rel) => {
    if (cat.tables[rel]) return rel;
    const hit = (fkByTable.get(parent) || []).find((fk) => fk.name === rel || (fk.cols || []).includes(rel));
    return hit ? hit.dst : null;
  };
  const checkCols = (table, cols, at, kind) => {
    const t = cat.tables[table];
    for (const col of new Set(cols)) if (!t.cols.includes(col)) add(kind, `${table}.${col}`, at, `colonne absente de ${table}`);
  };
  const checkEmbeds = (parent, embeds, at) => {
    for (const e of embeds) {
      const target = resolveEmbed(parent, e.rel);
      if (!target) { add('embed_missing', `${parent}->${e.rel}`, at, `relation ${e.rel} introuvable depuis ${parent}`); continue; }
      checkCols(target, e.cols, at, 'column_missing');
      checkEmbeds(target, e.embeds, at);
    }
  };
  for (const t of scan.tables) {
    if (!cat.tables[t.table]) { add('table_missing', t.table, t.at, 'table/vue absente des migrations'); continue; }
    checkCols(t.table, t.cols, t.at, 'column_missing');
    checkCols(t.table, t.written, t.at, 'column_missing');
    checkEmbeds(t.table, t.embeds, t.at);
  }
  const buckets = new Set(cat.buckets.map((b) => b.id));
  for (const b of scan.buckets) if (!buckets.has(b.name)) add('bucket_missing', b.name, b.at, 'bucket absent des migrations');
  const edge = new Set(cat.edge);
  for (const f of scan.functions) if (f.name && !edge.has(f.name)) add('edge_missing', f.name, f.at, 'Edge Function absente de supabase/functions');
  for (const ch of scan.channels) if (!cat.tables[ch.table]) add('realtime_table_missing', ch.table, ch.at, 'table ecoutee en Realtime inexistante');

  const seen = new Set();
  return out.filter((f) => { const k = `${f.key}@${f.at}`; if (seen.has(k)) return false; seen.add(k); return true; });
}

export function applyExceptions(findings, exceptions) {
  const map = new Map(exceptions.map((e) => [e.key, e]));
  const used = new Set();
  const open = [];
  for (const f of findings) { if (map.has(f.key)) used.add(f.key); else open.push(f); }
  return { open, stale: exceptions.filter((e) => !used.has(e.key)) };
}

export async function run({ catalogFile, scanOnlyCatalog } = {}) {
  const scan = scanDart(root);
  let cat;
  if (catalogFile && fs.existsSync(catalogFile)) cat = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
  else { cat = await buildCatalog(path.join(root, 'supabase')); if (catalogFile) fs.writeFileSync(catalogFile, JSON.stringify(cat)); }
  const findings = compare(scan, cat);
  const exFile = path.join(root, 'tool', 'contract', 'exceptions.json');
  const exceptions = fs.existsSync(exFile) ? JSON.parse(fs.readFileSync(exFile, 'utf8')) : [];
  const { open, stale } = applyExceptions(findings, exceptions);
  return { scan, cat, findings, open, stale, exceptions };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const arg = (n) => { const i = process.argv.indexOf(n); return i >= 0 ? process.argv[i + 1] : null; };
  const { scan, cat, findings, open, stale } = await run({ catalogFile: arg('--catalog') });
  const byKind = {};
  for (const f of findings) byKind[f.kind] = (byKind[f.kind] || 0) + 1;
  const report = {
    generated: new Date().toISOString(),
    stats: { dartFiles: scan.files, rpcCalls: scan.rpc.length, tableCalls: scan.tables.length, buckets: scan.buckets.length, edgeCalls: scan.functions.length, channels: scan.channels.length, migrationsReplayed: cat.replayed, migrationsFailed: cat.failed.length },
    dynamic: { rpcNotResolved: scan.dynamicRpc.length, bucketsNotResolved: scan.dynamicBuckets.length },
    findingsByKind: byKind,
    open,
    covered: findings.length - open.length,
    staleExceptions: stale,
    replayFailures: cat.failed,
  };
  const outFile = arg('--out');
  if (outFile) fs.writeFileSync(outFile, JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ stats: report.stats, findingsByKind: byKind, open: open.length, stale: stale.length }));
  for (const f of open.slice(0, 60)) console.log(`${f.kind} ${f.name} @ ${f.at} - ${f.detail}`);
  process.exit(open.length || (process.argv.includes('--strict') && stale.length) ? 1 : 0);
}
