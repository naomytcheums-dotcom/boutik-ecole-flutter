// Tests des outils médias contre un FAUX serveur Supabase local (PostgREST + Storage en mémoire) : aucun accès réseau externe, aucune clé réelle.
//   node --test tool/backup/media_tools.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { buildReport, fetchInventory, makeClient, migrate, objectId, rollback } from './media_lib.mjs';

const KEY = 'cle-de-service-FACTICE-0123456789';
const UID = '11111111-2222-3333-4444-555555555555';
const sha = (b) => createHash('sha256').update(b).digest('hex');
const noSleep = async () => {};

// ---------------------------------------------------------------- faux serveur
function fakeServer() {
  const buckets = { 'post-media': new Map(), 'post-media-private': new Map() };
  const meta = new Map(); // chemin -> { state, kind, reason, reversible, created_at, migration_status, storage_bucket }
  const calls = []; // { method, url }
  const faults = { copyFail: new Map(), corruptCopy: new Set(), readFail: new Map() }; // chemin -> nombre d'échecs restants
  const rpcs = {
    media_inventory_objects: ({ p_after, p_limit }) => [...buckets['post-media'].keys()].sort().filter((p) => !p_after || p > p_after).slice(0, p_limit).map((p) => {
      const m = meta.get(p), b = buckets['post-media'].get(p);
      return { path: p, size_bytes: b.data.length, mimetype: b.mime, created_at: m.created_at, state: m.state, reference_kind: m.kind, reason: m.reason ?? null, reversible: m.reversible ?? null, in_private: buckets['post-media-private'].has(p), migration_status: m.migration_status ?? null };
    }),
    media_inventory_buckets: () => Object.entries(buckets).map(([bucket, o]) => ({ bucket, public: bucket === 'post-media', objects: o.size, bytes: [...o.values()].reduce((s, x) => s + x.data.length, 0) })),
    media_migrate_private_batch: ({ p_limit, p_include_orphans }) => {
      for (const [p, m] of meta) {
        const eligible = m.state === 'restricted' || (p_include_orphans && m.state === 'unreferenced' && Date.now() - Date.parse(m.created_at) > 86400000);
        if (eligible && !m.migration_status) m.migration_status = 'queued';
      }
      return [...meta].filter(([, m]) => ['queued', 'failed'].includes(m.migration_status)).slice(0, p_limit).map(([p, m]) => ({ path: p, reason: m.reason ?? 'orphan', status: m.migration_status, size_bytes: buckets['post-media'].get(p).data.length }));
    },
    media_migrate_confirm_checked: ({ p_path, p_sha256, p_size }) => {
      rpcs.__confirmCalls.push({ p_path, p_sha256, p_size });
      const d = buckets['post-media-private'].get(p_path), m = meta.get(p_path);
      if (!d) return 'missing_destination';
      if (d.data.length !== p_size) { m.migration_status = 'failed'; return 'failed'; }
      m.migration_status = 'verified'; m.storage_bucket = 'post-media-private'; m.sha256 = p_sha256;
      return 'verified';
    },
    media_migration_report: () => ({ verified: [...meta.values()].filter((m) => m.migration_status === 'verified').length }),
    media_migrate_rollback: ({ p_path }) => { let n = 0; for (const [p, m] of meta) if ((!p_path || p === p_path) && m.migration_status === 'verified') { m.migration_status = 'rolled_back'; m.storage_bucket = 'post-media'; n++; } return { rolled_back: n, skipped: 0 }; },
    __confirmCalls: [],
  };
  const readBody = (req) => new Promise((res) => { let s = ''; req.on('data', (c) => (s += c)); req.on('end', () => res(s)); });
  const server = http.createServer(async (req, res) => {
    calls.push({ method: req.method, url: req.url });
    if (req.headers.authorization !== `Bearer ${KEY}` || req.headers.apikey !== KEY) { res.writeHead(401).end('{"message":"Invalid API key"}'); return; }
    const url = new URL(req.url, 'http://x');
    if (req.method === 'POST' && url.pathname.startsWith('/rest/v1/rpc/')) {
      const fn = url.pathname.split('/').pop();
      if (!rpcs[fn] || fn.startsWith('__')) { res.writeHead(404).end('{}'); return; }
      const out = rpcs[fn](JSON.parse((await readBody(req)) || '{}'));
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(out));
    } else if (req.method === 'POST' && url.pathname === '/storage/v1/object/copy') {
      const b = JSON.parse(await readBody(req));
      const left = faults.copyFail.get(b.sourceKey) ?? 0;
      if (left > 0) { faults.copyFail.set(b.sourceKey, left - 1); res.writeHead(503).end('{"error":"indisponible"}'); return; }
      const src = buckets[b.bucketId]?.get(b.sourceKey);
      if (!src) { res.writeHead(404).end('{"error":"not_found"}'); return; }
      if (buckets[b.destinationBucket].has(b.destinationKey)) { res.writeHead(400).end('{"error":"Duplicate","message":"The resource already exists"}'); return; }
      const data = faults.corruptCopy.has(b.sourceKey) ? Buffer.from(src.data.map((x, i) => (i === 0 ? x ^ 1 : x))) : Buffer.from(src.data);
      buckets[b.destinationBucket].set(b.destinationKey, { data, mime: src.mime });
      res.writeHead(200).end('{"Key":"ok"}');
    } else if (req.method === 'GET' && url.pathname.startsWith('/storage/v1/object/')) {
      const [bucket, ...rest] = url.pathname.replace('/storage/v1/object/', '').split('/');
      const p = decodeURIComponent(rest.join('/'));
      const left = faults.readFail.get(p) ?? 0;
      if (left > 0) { faults.readFail.set(p, left - 1); res.writeHead(500).end('x'); return; }
      const o = buckets[bucket]?.get(p);
      if (!o) { res.writeHead(404).end('{}'); return; }
      res.writeHead(200, { 'content-type': o.mime });
      res.write(o.data.subarray(0, Math.ceil(o.data.length / 2)));
      setTimeout(() => res.end(o.data.subarray(Math.ceil(o.data.length / 2))), 2);
    } else { res.writeHead(404).end('{}'); }
  });
  const add = (p, data, state, kind, extra = {}) => { buckets['post-media'].set(p, { data: Buffer.from(data), mime: extra.mime ?? 'image/jpeg' }); meta.set(p, { state, kind, created_at: extra.created_at ?? '2026-11-01T10:00:00Z', reason: extra.reason, reversible: extra.reversible, storage_bucket: 'post-media' }); };
  return { server, buckets, meta, calls, faults, rpcs, add, listen: () => new Promise((r) => server.listen(0, '127.0.0.1', () => r(`http://127.0.0.1:${server.address().port}`))) };
}

// Forme de la production lue par le chef : 17 objets = 13 publics, 1 en attente, 1 histoire expirée, 2 orphelins.
async function setup() {
  const f = fakeServer();
  for (let i = 0; i < 13; i++) f.add(`${UID}/pub${i}.jpg`, `public-${i}`.repeat(3), 'public', 'post_media');
  f.add(`${UID}/attente.mp4`, 'attente'.repeat(50), 'pending', 'post_media', { mime: 'video/mp4' });
  f.add(`${UID}/story.jpg`, 'histoire-expiree', 'restricted', 'story', { reason: 'story_expired', reversible: false });
  f.add(`${UID}/orphan1.png`, 'orphelin-un', 'unreferenced', 'none', { mime: 'image/png', reason: 'orphan', reversible: true });
  f.add(`${UID}/orphan2.png`, 'orphelin-deux', 'unreferenced', 'none', { mime: 'image/png', reason: 'orphan', reversible: true });
  const url = await f.listen();
  const client = makeClient({ url, key: KEY, sleep: noSleep });
  const dir = fs.mkdtempSync(path.join(process.cwd(), '.media_test_'));
  return { f, client, dir, state: path.join(dir, 'etat.json'), done: () => { f.server.close(); fs.rmSync(dir, { recursive: true, force: true }); } };
}

test('inventaire : un objet par ligne, confidentialité, taille, type ; rapport sans donnée personnelle', async () => {
  const t = await setup();
  try {
    const objects = await fetchInventory(t.client, 5); // pagination
    assert.equal(objects.length, 17);
    const report = buildReport(objects, await t.client.rpc('media_inventory_buckets'), { now: Date.parse('2026-11-28T00:00:00Z') });
    assert.equal(report.summary.objects, 17);
    assert.deepEqual(report.summary.par_confidentialite, { publique: 13, en_attente_validation: 1, restreinte: 1, non_rattachee: 2 });
    assert.equal(report.summary.restreints_exposes_par_url_publique, 1);
    assert.equal(report.summary.eligibles_a_la_bascule, 1, 'sans --orphans : seule l\'histoire expirée');
    assert.equal(buildReport(objects, [], { orphans: true, now: Date.parse('2026-11-28T00:00:00Z') }).summary.eligibles_a_la_bascule, 3);
    const story = report.objects.find((o) => o.id === objectId(`${UID}/story.jpg`));
    assert.deepEqual([story.reference, story.confidentialite, story.motif, story.type, story.taille_octets], ['story', 'restreinte', 'story_expired', 'image/jpeg', 16]);
    const txt = JSON.stringify(report);
    assert.ok(!txt.includes(UID) && !txt.includes('story.jpg') && !txt.includes(KEY) && !/https?:\/\//.test(txt), 'aucun chemin, compte, URL ni clé dans le rapport');
    assert.equal(report.contient_des_donnees_personnelles, false);
  } finally { t.done(); }
});

test('dry-run par défaut : aucune écriture (ni copie, ni file, ni référence, ni fichier d\'état)', async () => {
  const t = await setup();
  try {
    const r = await migrate(t.client, { statePath: t.state });
    assert.equal(r.mode, 'dry-run');
    assert.equal(r.eligible, 1);
    assert.ok(!t.f.calls.some((c) => c.url.includes('/object/copy') || c.url.includes('media_migrate_private_batch') || c.url.includes('confirm')), 'aucun appel d\'écriture');
    assert.equal(t.f.buckets['post-media-private'].size, 0);
    assert.ok([...t.f.meta.values()].every((m) => !m.migration_status && m.storage_bucket === 'post-media'));
    assert.ok(!fs.existsSync(t.state));
  } finally { t.done(); }
});

test('apply : copie, taille ET SHA-256 vérifiés, référence mise à jour après vérification, public/attente jamais touchés, rien supprimé', async () => {
  const t = await setup();
  try {
    const r = await migrate(t.client, { apply: true, orphans: true, statePath: t.state });
    assert.equal(r.verified, 3); assert.equal(r.failed, 0);
    for (const p of [`${UID}/story.jpg`, `${UID}/orphan1.png`, `${UID}/orphan2.png`]) {
      assert.equal(sha(t.f.buckets['post-media-private'].get(p).data), sha(t.f.buckets['post-media'].get(p).data));
      assert.equal(t.f.meta.get(p).storage_bucket, 'post-media-private');
      assert.equal(t.f.meta.get(p).sha256, sha(t.f.buckets['post-media'].get(p).data), 'empreinte enregistrée côté base');
    }
    assert.equal(t.f.buckets['post-media-private'].size, 3, 'ni public ni en attente copiés');
    assert.equal(t.f.meta.get(`${UID}/attente.mp4`).storage_bucket, 'post-media');
    assert.equal(t.f.buckets['post-media'].size, 17, 'anciens fichiers conservés');
    assert.ok(!t.f.calls.some((c) => c.method === 'DELETE' || /remove|delete/i.test(c.url)), 'aucune suppression');
    const order = t.f.calls.map((c) => c.url);
    assert.ok(order.findIndex((u) => u.includes('/object/post-media-private/')) < order.findIndex((u) => u.includes('media_migrate_confirm_checked')), 'relecture de la copie avant la confirmation');
  } finally { t.done(); }
});

test('copie corrompue (même taille, octet différent) : écart d\'empreinte, référence NON modifiée, les autres continuent', async () => {
  const t = await setup();
  try {
    t.f.faults.corruptCopy.add(`${UID}/orphan1.png`);
    const r = await migrate(t.client, { apply: true, orphans: true, statePath: t.state });
    assert.equal(r.verified, 2); assert.equal(r.failed, 1);
    assert.equal(t.f.meta.get(`${UID}/orphan1.png`).storage_bucket, 'post-media');
    assert.ok(!t.f.rpcs.__confirmCalls.some((c) => c.p_path === `${UID}/orphan1.png`), 'aucune confirmation envoyée');
    assert.equal(JSON.parse(fs.readFileSync(t.state, 'utf8')).items[objectId(`${UID}/orphan1.png`)].stage, 'mismatch');
  } finally { t.done(); }
});

test('reprise sur incident : un fichier en panne n\'arrête pas les autres ; la relance termine sans refaire les confirmés ; état sans chemin ni clé', async () => {
  const t = await setup();
  try {
    t.f.faults.copyFail.set(`${UID}/orphan2.png`, 99); // panne persistante (retries épuisés)
    const lines = [];
    const r1 = await migrate(t.client, { apply: true, orphans: true, statePath: t.state, log: (m) => lines.push(m) });
    assert.equal(r1.verified, 2); assert.equal(r1.failed, 1); assert.equal(r1.errors.length, 1);
    assert.ok(lines.some((l) => /INCIDENT .*reprise possible/.test(l)));
    t.f.faults.copyFail.clear();
    t.f.calls.length = 0; t.f.rpcs.__confirmCalls.length = 0;
    const r2 = await migrate(t.client, { apply: true, orphans: true, statePath: t.state });
    assert.equal(r2.verified, 1); assert.equal(r2.failed, 0);
    assert.equal(t.f.rpcs.__confirmCalls.length, 1, 'seul le fichier en incident est confirmé à la reprise');
    assert.equal(t.f.calls.filter((c) => c.url.includes('/object/copy')).length, 1, 'aucune copie refaite pour les fichiers déjà confirmés');
    const stateTxt = fs.readFileSync(t.state, 'utf8');
    assert.ok(!stateTxt.includes(UID) && !stateTxt.includes(KEY) && !stateTxt.includes('.png'));
    // copie déjà présente (reprise après coupure entre copie et confirmation) : relue et vérifiée, pas recopiée
    const t2 = await setup();
    try {
      t2.f.buckets['post-media-private'].set(`${UID}/story.jpg`, { data: Buffer.from(t2.f.buckets['post-media'].get(`${UID}/story.jpg`).data), mime: 'image/jpeg' });
      const r3 = await migrate(t2.client, { apply: true, statePath: t2.state });
      assert.equal(r3.verified, 1); assert.equal(r3.already_copied, 1);
    } finally { t2.done(); }
  } finally { t.done(); }
});

test('erreurs transitoires (503 puis succès) : nouvelles tentatives ; mauvaise clé : refus sans écriture', async () => {
  const t = await setup();
  try {
    t.f.faults.copyFail.set(`${UID}/story.jpg`, 2);
    t.f.faults.readFail.set(`${UID}/story.jpg`, 1);
    const r = await migrate(t.client, { apply: true, statePath: t.state });
    assert.equal(r.verified, 1); assert.equal(r.failed, 0);
    const bad = makeClient({ url: t.client ? `http://127.0.0.1:${t.f.server.address().port}` : '', key: 'mauvaise-cle', sleep: noSleep });
    await assert.rejects(() => migrate(bad, { apply: true, statePath: t.state + '.x' }), /401/);
    assert.ok(!fs.existsSync(t.state + '.x'));
  } finally { t.done(); }
});

test('retour arrière : dry-run par défaut ; --apply ne supprime rien et rétablit la référence', async () => {
  const t = await setup();
  try {
    await migrate(t.client, { apply: true, statePath: t.state });
    assert.equal((await rollback(t.client, { all: true })).mode, 'dry-run');
    assert.equal(t.f.meta.get(`${UID}/story.jpg`).storage_bucket, 'post-media-private');
    await assert.rejects(() => rollback(t.client, { apply: true }), /--path|--all/);
    const r = await rollback(t.client, { apply: true, path: `${UID}/story.jpg` });
    assert.equal(r.result.rolled_back, 1);
    assert.equal(t.f.meta.get(`${UID}/story.jpg`).storage_bucket, 'post-media');
    assert.equal(t.f.buckets['post-media-private'].size, 1, 'la copie privée est conservée');
    assert.ok(!t.f.calls.some((c) => c.method === 'DELETE'));
  } finally { t.done(); }
});

test('la clé de service n\'apparaît jamais dans les sorties de la bibliothèque', async () => {
  const t = await setup();
  try {
    const lines = [];
    const r = await migrate(t.client, { apply: true, orphans: true, statePath: t.state, log: (m) => lines.push(m) });
    assert.ok(!JSON.stringify([r, lines]).includes(KEY));
    assert.ok(!fs.readFileSync(t.state, 'utf8').includes(KEY));
  } finally { t.done(); }
});
