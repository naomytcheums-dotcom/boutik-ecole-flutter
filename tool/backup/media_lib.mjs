// Bibliothèque des outils médias (H13.2) : inventaire par objet de « post-media » et bascule vérifiée vers « post-media-private ».
// Règles : lecture seule par défaut (--apply explicite pour écrire), COPIE par l'API Storage, vérification de la taille ET de l'empreinte SHA-256 de chaque copie (octets relus des deux
// compartiments), mise à jour des références (post_media.storage_bucket) SEULEMENT après vérification (RPC media_migrate_confirm_checked), reprise sur incident (fichier d'état),
// rapports SANS donnée personnelle, AUCUNE suppression (ce module ne contient aucun appel de suppression : elle reste une action humaine).
import { createHash } from 'node:crypto';
import fs from 'node:fs';

export const SOURCE = 'post-media';
export const TARGET = 'post-media-private';
export const CONFIDENTIALITY = { public: 'publique', pending: 'en_attente_validation', restricted: 'restreinte', unreferenced: 'non_rattachee' };
const ORPHAN_MIN_AGE_MS = 24 * 3600 * 1000;

export const sha256Hex = (s) => createHash('sha256').update(s).digest('hex');
// Identifiant d'objet des rapports : empreinte du chemin (le chemin contient l'identifiant du compte propriétaire : jamais écrit dans un rapport).
export const objectId = (path) => `obj-${sha256Hex(path).slice(0, 12)}`;
export const encodePath = (p) => p.split('/').map(encodeURIComponent).join('/');

export class HttpError extends Error {
  constructor(status, where, body) { super(`${where} : HTTP ${status}${body ? ' ' + String(body).slice(0, 200) : ''}`); this.status = status; this.body = body; }
}

export function makeClient({ url, key, fetchImpl = fetch, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), retries = 3 }) {
  if (!url || !key) throw new Error('SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY requis dans l\'environnement.');
  const base = url.replace(/\/+$/, '');
  const H = { apikey: key, Authorization: `Bearer ${key}` };
  async function call(where, input, init) {
    let last;
    for (let i = 0; i <= retries; i++) {
      try {
        const r = await fetchImpl(input, init);
        if (r.status >= 500 || r.status === 429) { last = new HttpError(r.status, where, await r.text().catch(() => '')); } else return r;
      } catch (e) { last = new Error(`${where} : réseau (${e.code || e.name})`); }
      if (i < retries) await sleep(200 * 2 ** i);
    }
    throw last;
  }
  return {
    async rpc(fn, body = {}) {
      const r = await call(`rpc ${fn}`, `${base}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { ...H, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const t = await r.text();
      if (!r.ok) throw new HttpError(r.status, `rpc ${fn}`, t);
      return t ? JSON.parse(t) : null;
    },
    // Copie serveur à serveur ; renvoie 'copied' ou 'exists' (la reprise après incident retrouve des copies déjà faites).
    async copy(path) {
      const r = await call('copie', `${base}/storage/v1/object/copy`, { method: 'POST', headers: { ...H, 'Content-Type': 'application/json' }, body: JSON.stringify({ bucketId: SOURCE, sourceKey: path, destinationBucket: TARGET, destinationKey: path }) });
      if (r.ok) { await r.text().catch(() => ''); return 'copied'; }
      const t = await r.text().catch(() => '');
      if (/already exists|duplicate/i.test(t)) return 'exists';
      throw new HttpError(r.status, 'copie', t);
    },
    // Relit les octets (flux) et renvoie taille + SHA-256.
    async digest(bucket, path) {
      const r = await call('lecture', `${base}/storage/v1/object/${bucket}/${encodePath(path)}`, { method: 'GET', headers: H });
      if (!r.ok) throw new HttpError(r.status, `lecture ${bucket}`, await r.text().catch(() => ''));
      const h = createHash('sha256'); let size = 0;
      for await (const chunk of r.body) { h.update(chunk); size += chunk.length; }
      return { size, sha256: h.digest('hex') };
    },
  };
}

// ---------------------------------------------------------------- inventaire
export async function fetchInventory(client, pageSize = 500) {
  const rows = []; let after = null;
  for (;;) {
    const page = await client.rpc('media_inventory_objects', { p_after: after, p_limit: pageSize });
    rows.push(...page);
    if (page.length < pageSize) break;
    after = page[page.length - 1].path;
  }
  return rows;
}

export function isEligible(o, { orphans = false, now = Date.now() } = {}) {
  if (o.migration_status === 'verified' || o.migration_status === 'rolled_back') return false;
  if (o.state === 'restricted') return true;
  if (o.state === 'unreferenced') return orphans && now - Date.parse(o.created_at) > ORPHAN_MIN_AGE_MS;
  return false; // public et en attente de validation : jamais touchés
}

export function buildReport(objects, buckets, { orphans = false, now = Date.now() } = {}) {
  const count = (key) => objects.reduce((a, o) => { const k = key(o) ?? 'inconnu'; a[k] = (a[k] || 0) + 1; return a; }, {});
  const bytes = objects.reduce((s, o) => s + Number(o.size_bytes || 0), 0);
  return {
    version: 1,
    generated_at: new Date(now).toISOString(),
    contient_des_donnees_personnelles: false,
    note: 'Identifiants d\'objet = empreinte SHA-256 du chemin (12 premiers caractères hexadécimaux) ; aucun chemin, nom de fichier, identifiant de compte ni URL.',
    summary: {
      objects: objects.length,
      bytes,
      par_confidentialite: count((o) => CONFIDENTIALITY[o.state] ?? o.state),
      par_type_mime: count((o) => o.mimetype),
      par_reference: count((o) => o.reference_kind),
      par_motif_restriction: count((o) => o.reason ?? 'aucun'),
      restreints_exposes_par_url_publique: objects.filter((o) => o.state === 'restricted' && !o.in_private).length,
      eligibles_a_la_bascule: objects.filter((o) => isEligible(o, { orphans, now })).length,
      deja_verifies: objects.filter((o) => o.migration_status === 'verified').length,
    },
    buckets: (buckets ?? []).map((b) => ({ bucket: b.bucket, public: b.public, objects: b.objects, bytes: Number(b.bytes) })),
    objects: objects.map((o) => ({
      id: objectId(o.path),
      reference: o.reference_kind,
      confidentialite: CONFIDENTIALITY[o.state] ?? o.state,
      motif: o.reason ?? null,
      reversible: o.reversible ?? null,
      taille_octets: o.size_bytes === null || o.size_bytes === undefined ? null : Number(o.size_bytes),
      type: o.mimetype ?? null,
      cree_le: o.created_at ? String(o.created_at).slice(0, 10) : null,
      copie_privee_presente: !!o.in_private,
      bascule: o.migration_status ?? null,
      eligible: isEligible(o, { orphans, now }),
    })),
  };
}

// ---------------------------------------------------------------- fichier d'état (reprise)
export function loadState(file) {
  if (!file || !fs.existsSync(file)) return { version: 1, items: {} };
  const s = JSON.parse(fs.readFileSync(file, 'utf8'));
  return { version: 1, items: s.items ?? {} };
}
export function saveState(file, state) {
  if (!file) return;
  fs.writeFileSync(`${file}.part`, JSON.stringify(state, null, 1));
  fs.renameSync(`${file}.part`, file);
}

// ---------------------------------------------------------------- bascule
// Étapes par fichier : copie -> relecture des deux compartiments (taille + SHA-256) -> confirmation serveur. L'état n'enregistre que des identifiants d'objet (jamais de chemin).
export async function migrate(client, { apply = false, limit = 50, orphans = false, statePath = null, log = () => {} } = {}) {
  const inv = await fetchInventory(client);
  const plan = inv.filter((o) => isEligible(o, { orphans }));
  const out = { mode: apply ? 'apply' : 'dry-run', eligible: plan.length, verified: 0, failed: 0, skipped_resume: 0, copied: 0, already_copied: 0, errors: [] };
  if (!apply) { log(`--dry-run (défaut) : ${plan.length} fichier(s) éligible(s), aucune écriture. Ajouter --apply pour copier et vérifier.`); return out; }

  const state = loadState(statePath);
  const queue = await client.rpc('media_migrate_private_batch', { p_limit: limit, p_include_orphans: orphans });
  log(`file d'attente : ${queue.length} fichier(s)`);
  for (const x of queue) {
    const id = objectId(x.path);
    const it = state.items[id] ?? (state.items[id] = { stage: 'queued', reason: x.reason });
    if (it.stage === 'confirmed') { out.skipped_resume++; continue; }
    try {
      const c = await client.copy(x.path);
      c === 'copied' ? out.copied++ : out.already_copied++;
      it.stage = 'copied'; saveState(statePath, state);
      const [src, dst] = [await client.digest(SOURCE, x.path), await client.digest(TARGET, x.path)];
      if (src.size !== dst.size || src.sha256 !== dst.sha256) {
        it.stage = 'mismatch'; it.note = src.size !== dst.size ? 'taille différente' : 'empreinte différente';
        out.failed++; log(`ECART ${id} : ${it.note} (aucune référence modifiée)`); saveState(statePath, state); continue;
      }
      it.stage = 'hash_verified'; it.sha256 = dst.sha256; it.size = dst.size; saveState(statePath, state);
      const res = await client.rpc('media_migrate_confirm_checked', { p_path: x.path, p_sha256: dst.sha256, p_size: dst.size });
      if (res === 'verified') { it.stage = 'confirmed'; out.verified++; log(`VERIFIE ${id}`); } else { it.stage = 'server_' + res; out.failed++; log(`A REVOIR ${id} (${res})`); }
    } catch (e) {
      it.stage = it.stage === 'queued' ? 'error' : it.stage; it.note = String(e.message).slice(0, 160);
      out.failed++; out.errors.push({ id, message: it.note }); log(`INCIDENT ${id} : ${it.note} (reprise possible : relancer la commande)`);
    }
    saveState(statePath, state);
  }
  out.report = await client.rpc('media_migration_report', {});
  return out;
}

export async function rollback(client, { apply = false, path = null, all = false, log = () => {} } = {}) {
  if (!path && !all) throw new Error('--rollback exige --path <chemin> ou --all');
  if (!apply) { log('--dry-run (défaut) : retour arrière non exécuté. Ajouter --apply.'); return { mode: 'dry-run' }; }
  const r = await client.rpc('media_migrate_rollback', path ? { p_path: path } : {});
  log(`retour arrière : ${JSON.stringify(r)} (les copies privées sont conservées, rien n'est supprimé)`);
  return { mode: 'apply', result: r };
}
