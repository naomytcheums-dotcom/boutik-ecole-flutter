// Extraction statique des appels Backend/Supabase du code Dart (aucun reseau).
// Produit : rpc[], tables[], buckets[], functions[], channels[] avec fichier:ligne.
import fs from 'node:fs';
import path from 'node:path';

// Remplace les commentaires par des espaces (offsets conserves) ; les chaines sont conservees.
export function maskComments(src) {
  const out = src.split('');
  let i = 0;
  const n = src.length;
  const blank = (a, b) => { for (let k = a; k < b; k++) if (out[k] !== '\n') out[k] = ' '; };
  while (i < n) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') { let j = i; while (j < n && src[j] !== '\n') j++; blank(i, j); i = j; continue; }
    if (c === '/' && src[i + 1] === '*') { let j = src.indexOf('*/', i + 2); j = j < 0 ? n : j + 2; blank(i, j); i = j; continue; }
    if (c === "'" || c === '"') { i = skipString(src, i); continue; }
    i++;
  }
  return out.join('');
}

// Index juste apres la chaine commencant a i (gere r'', ''' ''', interpolation ${...}).
export function skipString(s, i) {
  const raw = s[i - 1] === 'r' && !/\w/.test(s[i - 2] || ' ');
  const q = s[i];
  const triple = s[i + 1] === q && s[i + 2] === q;
  let j = i + (triple ? 3 : 1);
  while (j < s.length) {
    const c = s[j];
    if (!raw && c === '\\') { j += 2; continue; }
    if (!raw && c === '$' && s[j + 1] === '{') { j = skipInterpolation(s, j + 1); continue; }
    if (triple) { if (c === q && s[j + 1] === q && s[j + 2] === q) return j + 3; }
    else if (c === q) return j + 1;
    else if (c === '\n') return j + 1;
    j++;
  }
  return j;
}

function skipInterpolation(s, i) {
  let depth = 0;
  let j = i;
  while (j < s.length) {
    const c = s[j];
    if (c === "'" || c === '"') { j = skipString(s, j); continue; }
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) return j + 1; }
    j++;
  }
  return j;
}

const OPEN = { '(': ')', '[': ']', '{': '}' };

// s[i] est une ouverture ; retourne l'index du fermant correspondant (ou -1).
export function matchClose(s, i) {
  const stack = [];
  let j = i;
  while (j < s.length) {
    const c = s[j];
    if (c === "'" || c === '"') { j = skipString(s, j); continue; }
    if (OPEN[c]) stack.push(OPEN[c]);
    else if (c === ')' || c === ']' || c === '}') {
      if (stack.pop() !== c) return -1;
      if (stack.length === 0) return j;
    }
    j++;
  }
  return -1;
}

// Decoupe le contenu (sans delimiteurs externes) en elements de premier niveau.
export function splitTop(s) {
  const parts = [];
  let depth = 0;
  let last = 0;
  let j = 0;
  while (j < s.length) {
    const c = s[j];
    if (c === "'" || c === '"') { j = skipString(s, j); continue; }
    if (c === '(' || c === '[' || c === '{') depth++;
    else if (c === ')' || c === ']' || c === '}') depth--;
    else if (c === ',' && depth === 0) { parts.push(s.slice(last, j)); last = j + 1; }
    j++;
  }
  if (s.slice(last).trim() !== '') parts.push(s.slice(last));
  return parts.map((p) => p.trim());
}

export function lineOf(src, idx) {
  let n = 1;
  for (let i = 0; i < idx; i++) if (src.charCodeAt(i) === 10) n++;
  return n;
}

export function strLiteral(arg) {
  if (arg == null) return null;
  const m = /^(?:r)?(['"])((?:(?!\1).)*)\1$/s.exec(arg.trim());
  if (!m || m[2].includes('$')) return null;
  return m[2];
}

// Cles d'un litteral de map ({...}, precede ou non de const / <K,V>). null si ce n'est pas un litteral.
export function mapKeys(arg) {
  if (arg == null) return null;
  const a = arg.trim().replace(/^const\s+/, '').replace(/^<[^>{]*>\s*/, '');
  if (!a.startsWith('{') || matchClose(a, 0) !== a.length - 1) return null;
  const keys = [];
  const optional = new Set();
  let dynamic = false;
  for (let entry of splitTop(a.slice(1, -1))) {
    let cond = false;
    for (;;) {
      const m = /^(?:if|for)\s*\(/.exec(entry);
      if (!m) break;
      const close = matchClose(entry, m[0].length - 1);
      if (close < 0) break;
      entry = entry.slice(close + 1).trim();
      cond = true;
    }
    if (entry.startsWith('...')) { dynamic = true; continue; }
    entry = entry.replace(/^\?\s*/, '');
    const km = /^(?:r)?(['"])((?:(?!\1).)*)\1\s*:/s.exec(entry);
    if (km && !km[2].includes('$')) { keys.push(km[2]); if (cond) optional.add(km[2]); }
    else dynamic = true;
  }
  return { keys, dynamic, optional };
}

function findDartFiles(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...findDartFiles(p));
    else if (e.name.endsWith('.dart') || e.name.endsWith('.dart.fixture')) out.push(p);
  }
  return out;
}

// Colonnes d'une chaine select PostgREST : 'a, b, rel(c, d), x:rel!fk(e)'.
export function parseSelect(str) {
  const cols = [];
  const embeds = [];
  for (let p of splitTop(str.replace(/\s+/g, ' '))) {
    p = p.trim();
    if (!p || p === '*') continue;
    if (/^count$/.test(p)) continue; // agregat PostgREST : rel(count)
    const em = /^(?:(\w+)\s*:\s*)?(\w+)(?:![\w]+)*\s*\((.*)\)$/s.exec(p);
    if (em) {
      const sub = parseSelect(em[3]);
      embeds.push({ alias: em[1] || null, rel: em[2], cols: sub.cols, embeds: sub.embeds });
      continue;
    }
    let name = p.replace(/::\w+$/, '');
    const al = /^\w+\s*:\s*(.+)$/.exec(name);
    if (al) name = al[1];
    name = name.split('->')[0].trim();
    if (/^\w+$/.test(name)) cols.push(name);
  }
  return { cols, embeds };
}

const FILTER_METHODS = new Set(['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'like', 'ilike', 'isFilter', 'inFilter', 'contains', 'containedBy', 'overlaps', 'textSearch', 'order', 'filter', 'not', 'match', 'or', 'likeAllOf', 'likeAnyOf', 'ilikeAllOf', 'ilikeAnyOf']);
const WRITE_METHODS = new Set(['insert', 'update', 'upsert', 'delete']);

function colOf(s) {
  const lit = strLiteral(s);
  return lit == null ? null : lit.split('->')[0].trim();
}

// Analyse la chaine d'appels apres .from('t') : operations + colonnes referencees.
function parseChain(src, idx) {
  const ops = new Set();
  const cols = [];
  const written = [];
  const embeds = [];
  let dynamic = false;
  let j = idx;
  for (;;) {
    while (/\s/.test(src[j] || '')) j++;
    if (src[j] === '?' && src[j + 1] === '.') j++;
    if (src[j] !== '.') break;
    const m = /^\.\s*(\w+)\s*(?:<[^()]*>)?\s*\(/.exec(src.slice(j, j + 80));
    if (!m) break;
    const method = m[1];
    const open = j + m[0].length - 1;
    const close = matchClose(src, open);
    if (close < 0) break;
    const args = splitTop(src.slice(open + 1, close));
    if (method === 'select') {
      ops.add('select');
      const lit = strLiteral(args[0]);
      if (lit != null) { const p = parseSelect(lit); cols.push(...p.cols); embeds.push(...p.embeds); }
      else if (args[0] && !/^(count|head)\b/.test(args[0])) dynamic = true;
    } else if (WRITE_METHODS.has(method)) {
      ops.add(method);
      if (method !== 'delete') {
        const target = args[0];
        const mk = mapKeys(target);
        if (mk) { written.push(...mk.keys); if (mk.dynamic) dynamic = true; }
        else if (target && /^\[/.test(target.trim())) {
          for (const e of splitTop(target.trim().slice(1, -1))) { const k = mapKeys(e); if (k) written.push(...k.keys); else dynamic = true; }
        } else dynamic = true;
        const oc = args.find((a) => a.startsWith('onConflict:'));
        if (oc) { const l = strLiteral(oc.replace(/^onConflict:\s*/, '')); if (l) cols.push(...l.split(',').map((x) => x.trim())); }
      }
    } else if (FILTER_METHODS.has(method)) {
      if (method === 'match') { const mk = mapKeys(args[0]); if (mk) cols.push(...mk.keys); }
      else if (method === 'or') {
        const l = strLiteral(args[0]);
        if (l) for (const part of splitTop(l)) { const cm = /^(?:(?:and|or)\()?([\w>-]+)\./.exec(part); if (cm) cols.push(cm[1].split('->')[0]); }
      } else { const c = colOf(args[0]); if (c && /^\w+$/.test(c)) cols.push(c); }
    }
    j = close + 1;
  }
  return { ops: [...ops], cols, written, embeds, dynamic };
}

const NOT_TABLE_RECEIVER = /\b(?:Map|List|Set|Path|Iterable|B2bStats|Uri|Color|DateTime|Duration|Uint8List|Rect|Offset)(?:<[^>]*>)?\s*$/;

export function scanDart(root) {
  const files = findDartFiles(path.join(root, 'lib'));
  const sources = new Map();
  for (const f of files) {
    const raw = fs.readFileSync(f, 'utf8');
    sources.set(f, { raw, masked: maskComments(raw) });
  }
  const rel = (f) => path.relative(root, f).split(path.sep).join('/');

  // 1) enveloppes RPC : fonction dont un parametre est transmis (transitivement) en nom de .rpc(...)
  const wrappers = new Map(); // cle (nom public ou `fichier::_nom` prive) -> index du parametre "nom"
  const wrapperKey = (name, f) => (name.startsWith('_') ? `${f}::${name}` : name);
  const wrapperIdx = (name, f) => wrappers.get(`${f}::${name}`) ?? wrappers.get(name);
  const sigRe = /(\w+)\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*(?:async\s*)?(?:\{|=>)/g;
  const positionalIndex = (params, id) => {
    const positional = splitTop(params.replace(/[{[][\s\S]*$/, ''));
    return positional.findIndex((p) => new RegExp(`(?:^|\\s)${id}$`).test(p.replace(/\s*=.*$/, '').trim()));
  };
  const enclosing = (masked, index, id) => {
    const head = masked.slice(Math.max(0, index - 8000), index);
    let best = null;
    let s;
    const sig = new RegExp(sigRe.source, 'g');
    while ((s = sig.exec(head))) {
      if (/^(if|for|while|switch|catch)$/.test(s[1])) continue;
      const idx = positionalIndex(s[2], id);
      if (idx >= 0 && new RegExp(`\\bString\\s+${id}\\b`).test(s[2])) best = { name: s[1], idx };
    }
    return best;
  };
  // appels d'enveloppes connues (hors declarations)
  const wrapperCalls = (f, masked) => {
    const out = [];
    const callRe = /(?<![\w$])([A-Za-z_]\w*)\s*\(/g;
    let m;
    while ((m = callRe.exec(masked))) {
      const name = m[1];
      const idx = wrapperIdx(name, f);
      if (idx === undefined) continue;
      const po = m.index + m[0].length - 1;
      const close = matchClose(masked, po);
      if (close < 0) continue;
      const before = masked.slice(Math.max(0, m.index - 40), m.index).trimEnd();
      const after = masked.slice(close + 1, close + 16).trimStart();
      const prevWord = /(\w+)$/.exec(before)?.[1];
      const prevChar = before.slice(-1);
      const isDecl = /^(?:async\b|\{|=>)/.test(after) && !before.endsWith('=>') && prevChar !== '.'
        && (prevChar === '>' || prevChar === '?' || (prevWord && !['await', 'return', 'else', 'in'].includes(prevWord)));
      if (isDecl) continue;
      const args = splitTop(masked.slice(po + 1, close));
      out.push({ name, idx, index: m.index, args, positional: args.filter((a) => !/^\w+\s*:(?!:)/.test(a)) });
    }
    return out;
  };
  wrappers.set('rpc', 0);
  const edges = []; // enveloppe -> enveloppe appelee, avec les cles ajoutees autour de `...params`
  const NOT_WRAPPERS = new Set(['chip', 'toggle', 'call']); // noms de callbacks UI sans rapport avec le backend
  for (let changed = true; changed;) {
    changed = false;
    edges.length = 0;
    for (const [f, { masked }] of sources) {
      for (const c of wrapperCalls(f, masked)) {
        const a = (c.positional[c.idx] || '').trim();
        if (!/^[A-Za-z_]\w*$/.test(a)) continue;
        const enc = enclosing(masked, c.index, a);
        if (!enc || NOT_WRAPPERS.has(enc.name)) continue;
        const k = wrapperKey(enc.name, f);
        const pa = c.args.find((x) => /^params\s*:/.test(x))?.replace(/^params\s*:\s*/, '') ?? c.positional[c.idx + 1];
        const mk = pa ? mapKeys(pa) : null;
        edges.push({ from: k, to: wrappers.has(`${f}::${c.name}`) ? `${f}::${c.name}` : c.name, keys: mk && mk.dynamic ? mk.keys : [] });
        if (!wrappers.has(k)) { wrappers.set(k, enc.idx); changed = true; }
      }
    }
  }
  const extraKeys = (k, seen = new Set()) => {
    if (seen.has(k)) return [];
    seen.add(k);
    return edges.filter((e) => e.from === k).flatMap((e) => [...e.keys, ...extraKeys(e.to, seen)]);
  };
  const bucketWrappers = new Map(); // nom -> index du parametre bucket
  for (const [, { masked }] of sources) {
    const sig2 = new RegExp(sigRe.source, 'g');
    let s2;
    while ((s2 = sig2.exec(masked))) {
      const idx = positionalIndex(s2[2], 'bucket');
      if (idx >= 0 && !/^(if|for|while|switch|catch)$/.test(s2[1])) bucketWrappers.set(s2[1], idx);
    }
  }
  const edgeWrappers = ['callFunction'];

  // utilitaires de lecture de table : fonctions/constructeurs dont un parametre est `String table` (ou this.table)
  const tableFns = new Map(); // nom -> { t, s, c } index des parametres table / select / columns
  const paramNames = (params) => splitTop(params.replace(/[{[][\s\S]*$/, '')).map((p) => /(\w+)$/.exec(p.replace(/\s*=.*$/, '').trim())?.[1]);
  for (const [f3, { masked }] of sources) {
    const re = /(?<![\w$.])([A-Za-z_]\w*)\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*(?:async\s*)?(?:\{|=>|:|;)/g;
    let s3;
    while ((s3 = re.exec(masked))) {
      if (!/(?:String|this\.)\s*table\b/.test(s3[2]) || /^(if|for|while|switch|catch)$/.test(s3[1])) continue;
      const names = paramNames(s3[2]);
      const t = names.indexOf('table');
      if (t >= 0) tableFns.set(s3[1].startsWith('_') ? `${f3}::${s3[1]}` : s3[1], { t, s: names.indexOf('select'), c: names.indexOf('columns') });
    }
  }

  const result = { rpc: [], tables: [], buckets: [], functions: [], channels: [], dynamicRpc: [], dynamicBuckets: [], wrappers: [...wrappers].map(([k, i]) => `${k.replace(/^.*[\\/]/, '')}[${i}]`), files: files.length };

  for (const [f, { masked }] of sources) {
    const where = (idx) => `${rel(f)}:${lineOf(masked, idx)}`;
    let m;
    for (const c of wrapperCalls(f, masked)) {
      const { name, args, positional } = c;
      const nameArg = positional[c.idx];
      const named = (k) => { const a = args.find((x) => new RegExp(`^${k}\\s*:`).test(x)); return a ? a.replace(new RegExp(`^${k}\\s*:\\s*`), '') : null; };
      const paramArg = named('params') ?? positional[c.idx + 1] ?? null;
      let names = [];
      const lit = strLiteral(nameArg);
      if (lit != null) names = [lit];
      else {
        const tern = /^[^?]+\?\s*('[^']*'|"[^"]*")\s*:\s*('[^']*'|"[^"]*")$/s.exec((nameArg || '').trim());
        if (tern) names = [strLiteral(tern[1]), strLiteral(tern[2])];
      }
      if (names.length === 0) {
        result.dynamicRpc.push({ at: where(c.index), via: name, expr: (nameArg || '').slice(0, 70) });
        continue;
      }
      const mk0 = paramArg ? mapKeys(paramArg) : { keys: [], dynamic: false, optional: new Set() };
      const extra = extraKeys(wrappers.has(`${f}::${name}`) ? `${f}::${name}` : name);
      const mk = mk0 && extra.length ? { ...mk0, keys: [...mk0.keys, ...extra] } : mk0;
      for (const n of names) {
        if (!/^[a-z][a-z0-9_]*$/.test(n)) continue;
        result.rpc.push({ name: n, at: where(c.index), via: name, keys: mk ? mk.keys : null, dynamic: mk ? mk.dynamic : true, optional: mk ? [...mk.optional] : [], ternary: names.length > 1 });
      }
    }

    // buckets passes a des utilitaires (uploadFile(bucket, ...)) et constantes *Bucket
    for (const [bw, idx] of bucketWrappers) {
      const re = new RegExp(`(?<![\\w$])${bw}\\(`, 'g');
      let bm;
      while ((bm = re.exec(masked))) {
        const po = bm.index + bm[0].length - 1;
        const close = matchClose(masked, po);
        if (close < 0) continue;
        const before = masked.slice(Math.max(0, bm.index - 40), bm.index).trimEnd();
        const after = masked.slice(close + 1, close + 16).trimStart();
        if (/^(?:async\b|\{|=>)/.test(after) && !before.endsWith('=>') && !before.endsWith('.') && !/(?:await|return)$/.test(before)) continue;
        const a = splitTop(masked.slice(po + 1, close))[idx];
        const lit = strLiteral(a);
        if (lit != null) result.buckets.push({ name: lit, at: where(bm.index), via: bw });
      }
    }
    const constRe = /\b(?:static\s+)?const\s+(?:String\s+)?(\w*[bB]ucket\w*)\s*=\s*('[^'$]*'|"[^"$]*")/g;
    while ((m = constRe.exec(masked))) result.buckets.push({ name: strLiteral(m[2]), at: where(m.index), via: `const ${m[1]}` });

    const stRe = /\.storage\s*\.from\(\s*([^()]*?)\s*\)/g;
    while ((m = stRe.exec(masked))) {
      const lit = strLiteral(m[1]);
      if (lit != null) result.buckets.push({ name: lit, at: where(m.index) });
      else result.dynamicBuckets.push({ at: where(m.index), expr: m[1] });
    }

    for (const [key, ix] of tableFns) {
      const priv = key.includes('::');
      if (priv && key.split('::')[0] !== f) continue;
      const fnName = priv ? key.split('::')[1] : key;
      const re = new RegExp(`(?<![\\w$])${fnName}\\(`, 'g');
      let tm;
      while ((tm = re.exec(masked))) {
        const po = tm.index + tm[0].length - 1;
        const close = matchClose(masked, po);
        if (close < 0) continue;
        const before = masked.slice(Math.max(0, tm.index - 40), tm.index).trimEnd();
        const after = masked.slice(close + 1, close + 16).trimStart();
        if (/^(?:async\b|\{|=>|:|;)/.test(after) && !before.endsWith('=>') && !before.endsWith('.') && !/(?:await|return|const|new)$/.test(before) && !/[=(,?]$/.test(before)) continue;
        const args = splitTop(masked.slice(po + 1, close));
        const positional = args.filter((a) => !/^\w+\s*:(?!:)/.test(a));
        const named = (k) => { const a = args.find((x) => new RegExp(`^${k}\\s*:`).test(x)); return a ? a.replace(new RegExp(`^${k}\\s*:\\s*`), '') : null; };
        const table = strLiteral(positional[ix.t]);
        if (!table || !/^[a-z][a-z0-9_]*$/.test(table)) continue;
        const cols = [];
        const embeds = [];
        let dynamic = false;
        const sel = ix.s >= 0 ? strLiteral(positional[ix.s]) : null;
        if (sel != null) { const p = parseSelect(sel); cols.push(...p.cols); embeds.push(...p.embeds); }
        if (ix.c >= 0 && positional[ix.c]) {
          const items = splitTop(positional[ix.c].trim().replace(/^const\s+/, '').replace(/^\[|\]$/g, ''));
          for (const it of items) { const l = strLiteral(it); if (l) cols.push(l); else dynamic = true; }
        }
        for (const k of ['eq', 'neq']) { const mk = mapKeys(named(k)); if (mk) cols.push(...mk.keys); }
        for (const k of ['order', 'ownerColumn']) { const l = strLiteral(named(k)); if (l) cols.push(l); }
        const any = /^\(\s*('[^']*'|"[^"]*")/.exec((named('anyOf') || '').trim());
        if (any) cols.push(strLiteral(any[1]));
        result.tables.push({ table, at: where(tm.index), ops: ['select'], cols, written: [], embeds, dynamic, via: fnName });
      }
    }

    const fnRe = /\bfunctions\s*\.\s*invoke\(\s*([^,)]+)/g;
    while ((m = fnRe.exec(masked))) result.functions.push({ name: strLiteral(m[1]), expr: m[1].trim(), at: where(m.index) });
    for (const w of edgeWrappers) {
      const re = new RegExp(`(?<![\\w.])${w}\\(\\s*('[^']*')`, 'g');
      while ((m = re.exec(masked))) result.functions.push({ name: strLiteral(m[1]), expr: m[1], at: where(m.index), via: w });
    }

    const frRe = /\.from\(\s*('[^']*'|"[^"]*")\s*\)/g;
    while ((m = frRe.exec(masked))) {
      const before = masked.slice(Math.max(0, m.index - 120), m.index);
      if (/\.storage\s*$/.test(before) || NOT_TABLE_RECEIVER.test(before)) continue;
      const table = strLiteral(m[1]);
      if (!table || !/^[a-z][a-z0-9_]*$/.test(table)) continue;
      result.tables.push({ table, at: where(m.index), ...parseChain(masked, m.index + m[0].length) });
    }

    const rtRe = /\bonPostgresChanges\(([\s\S]*?)\)\s*[,;.]/g;
    while ((m = rtRe.exec(masked))) {
      const t = /table:\s*('[^']*'|"[^"]*")/.exec(m[1]);
      if (t) result.channels.push({ table: strLiteral(t[1]), at: where(m.index) });
    }
  }
  return result;
}
