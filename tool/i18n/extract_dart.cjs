'use strict';
// Extracteur de litteraux de chaines Dart -> formes modeles {0},{1}.. (convention des cles « § » de assets/i18n/en.json).
// Usage : node extract_dart.cjs <fichier.dart|dossier> [...]   (JSON sur la sortie standard)
const fs = require('fs');
const path = require('path');

const IDENT_START = /[A-Za-z_]/;
const IDENT_PART = /[A-Za-z0-9_]/;

function lineOf(lineStarts, idx) {
  let lo = 0, hi = lineStarts.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (lineStarts[mid] <= idx) lo = mid; else hi = mid - 1;
  }
  return lo + 1;
}

/** Extrait tous les litteraux d'un source Dart. */
function extractLiterals(src, file = '') {
  const lineStarts = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === '\n') lineStarts.push(i + 1);
  const all = [];
  let scopeCounter = 0;

  function skipComment(i) {
    if (src[i] === '/' && src[i + 1] === '/') {
      while (i < src.length && src[i] !== '\n') i++;
      return i;
    }
    if (src[i] === '/' && src[i + 1] === '*') {
      let depth = 1;
      i += 2;
      while (i < src.length && depth > 0) {
        if (src[i] === '/' && src[i + 1] === '*') { depth++; i += 2; } else if (src[i] === '*' && src[i + 1] === '/') { depth--; i += 2; } else i++;
      }
      return i;
    }
    return -1;
  }

  // Lit un litteral commencant a `start` (sur le r ou le guillemet). Retourne l'objet et l'index apres la fin.
  function scanString(start, depth, parent) {
    let i = start;
    let raw = false;
    if (src[i] === 'r') { raw = true; i++; }
    const q = src[i];
    const triple = src[i + 1] === q && src[i + 2] === q;
    i += triple ? 3 : 1;
    const bodyStart = i;
    const parts = [];
    let cur = '';
    let nested = false;
    const lit = { file, start, quote: q, triple, raw, parts, depth, parent, nested: false };
    const myIndex = all.length;
    all.push(lit);
    if (triple && !raw) {
      // un saut de ligne juste apres l'ouverture est ignore
      if (src[i] === '\r' && src[i + 1] === '\n') i += 2; else if (src[i] === '\n') i++;
    }
    const flush = () => { if (cur) { parts.push({ t: 'text', v: cur }); cur = ''; } };
    for (;;) {
      if (i >= src.length) { lit.error = 'unterminated'; break; }
      const c = src[i];
      if (triple ? (c === q && src[i + 1] === q && src[i + 2] === q) : c === q) { i += triple ? 3 : 1; break; }
      if (!triple && c === '\n') { lit.error = 'newline'; break; }
      if (raw) { cur += c; i++; continue; }
      if (c === '\\') {
        const n = src[i + 1];
        i += 2;
        if (n === 'n') cur += '\n';
        else if (n === 'r') cur += '\r';
        else if (n === 't') cur += '\t';
        else if (n === 'b') cur += '\b';
        else if (n === 'f') cur += '\f';
        else if (n === 'v') cur += '\v';
        else if (n === 'x') { cur += String.fromCharCode(parseInt(src.substr(i, 2), 16)); i += 2; }
        else if (n === 'u') {
          if (src[i] === '{') {
            const e = src.indexOf('}', i);
            cur += String.fromCodePoint(parseInt(src.slice(i + 1, e), 16));
            i = e + 1;
          } else { cur += String.fromCharCode(parseInt(src.substr(i, 4), 16)); i += 4; }
        } else if (n === '\n') { /* continuation de ligne */ } else if (n === '\r' && src[i] === '\n') i++;
        else cur += n;
        continue;
      }
      if (c === '$') {
        if (src[i + 1] === '{') {
          flush();
          const scope = ++scopeCounter;
          const r = scanCode(i + 2, '}', depth + 1, myIndex, scope);
          const expr = src.slice(i + 2, r.end);
          if (r.hasString) nested = true;
          parts.push({ t: 'interp', v: expr, braces: true });
          i = r.end + 1;
          continue;
        }
        if (IDENT_START.test(src[i + 1] || '')) {
          flush();
          let j = i + 1;
          while (j < src.length && IDENT_PART.test(src[j])) j++;
          parts.push({ t: 'interp', v: src.slice(i + 1, j), braces: false });
          i = j;
          continue;
        }
      }
      cur += c;
      i++;
    }
    flush();
    lit.end = i;
    lit.nested = nested;
    lit.source = src.slice(start, i);
    lit.body = src.slice(bodyStart, Math.max(bodyStart, i - (triple ? 3 : 1)));
    return { lit, end: i };
  }

  // Parcourt du code Dart jusqu'a `closer` (accolade fermante d'une interpolation) ou la fin. Retourne les litteraux du scope.
  function scanCode(i, closer, depth, parent, scope) {
    let braces = 0;
    const own = [];
    let hasString = false;
    while (i < src.length) {
      const c = src[i];
      const cm = skipComment(i);
      if (cm >= 0) { i = cm; continue; }
      if (c === '"' || c === '\'' || (c === 'r' && (src[i + 1] === '"' || src[i + 1] === '\'') && !(i > 0 && IDENT_PART.test(src[i - 1])))) {
        const r = scanString(i, depth, parent);
        r.lit.scope = scope;
        own.push(r.lit);
        hasString = true;
        i = r.end;
        continue;
      }
      if (closer === '}') {
        if (c === '{') braces++;
        else if (c === '}') {
          if (braces === 0) return { end: i, own, hasString };
          braces--;
        }
      }
      i++;
    }
    return { end: i, own, hasString };
  }

  // scope 0 = niveau fichier
  const top = scanCode(0, null, 0, -1, 0);
  void top;

  // Regroupement par scope : litteraux adjacents (ou relies par +) = une seule chaine.
  const byScope = new Map();
  for (const l of all) {
    if (!byScope.has(l.scope)) byScope.set(l.scope, []);
    byScope.get(l.scope).push(l);
  }
  const groups = [];
  for (const list of byScope.values()) {
    list.sort((a, b) => a.start - b.start);
    let g = null;
    for (const l of list) {
      if (g) {
        const gap = stripGap(src.slice(g.lits[g.lits.length - 1].end, l.start));
        if (gap === '' || gap === '+') { g.lits.push(l); if (gap === '+') g.viaPlus = true; else g.adjacent = true; continue; }
      }
      g = { lits: [l], adjacent: false, viaPlus: false };
      groups.push(g);
    }
  }

  function stripGap(s) {
    let out = '';
    for (let i = 0; i < s.length;) {
      const cm = skipCommentIn(s, i);
      if (cm >= 0) { i = cm; continue; }
      if (!/\s/.test(s[i])) out += s[i];
      i++;
    }
    return out;
  }
  function skipCommentIn(s, i) {
    if (s[i] === '/' && s[i + 1] === '/') { while (i < s.length && s[i] !== '\n') i++; return i; }
    if (s[i] === '/' && s[i + 1] === '*') { const e = s.indexOf('*/', i + 2); return e < 0 ? s.length : e + 2; }
    return -1;
  }

  return groups.map((g) => {
    const parts = [];
    for (const l of g.lits) for (const p of l.parts) {
      const last = parts[parts.length - 1];
      if (p.t === 'text' && last && last.t === 'text') last.v += p.v; else parts.push({ ...p });
    }
    const exprs = [];
    let template = '';
    let plain = '';
    for (const p of parts) {
      if (p.t === 'text') { template += p.v; plain += p.v; } else { template += `{${exprs.length}}`; exprs.push(p.v); }
    }
    const first = g.lits[0];
    return {
      file,
      line: lineOf(lineStarts, first.start),
      endLine: lineOf(lineStarts, g.lits[g.lits.length - 1].end),
      source: g.lits.map((l) => l.source).join(g.viaPlus ? ' + ' : ' '),
      template,
      interpolations: exprs,
      isTemplate: exprs.length > 0,
      nestedQuotes: g.lits.some((l) => l.nested),
      nestedDepth: first.depth,
      concatenated: g.lits.length > 1,
      concatKind: g.lits.length > 1 ? (g.viaPlus ? 'plus' : 'adjacent') : null,
      raw: g.lits.some((l) => l.raw),
      error: g.lits.map((l) => l.error).find(Boolean) || null,
      key: exprs.length ? '§' + template : template,
      plain,
    };
  });
}

// ---- Variantes : `${cond ? 'a' : ''}` etc. ----
// Une interpolation vide ne peut pas etre reconnue par un modele (« .+? » exige au moins un caractere) : on genere donc une forme par branche.
function skipStr(s, i) {
  let raw = false;
  if (s[i] === 'r') { raw = true; i++; }
  const q = s[i];
  const triple = s[i + 1] === q && s[i + 2] === q;
  i += triple ? 3 : 1;
  while (i < s.length) {
    if (triple ? (s[i] === q && s[i + 1] === q && s[i + 2] === q) : s[i] === q) return i + (triple ? 3 : 1);
    if (!raw && s[i] === '\\') { i += 2; continue; }
    if (!raw && s[i] === '$' && s[i + 1] === '{') {
      let d = 1;
      i += 2;
      while (i < s.length && d > 0) {
        if (s[i] === '"' || s[i] === '\'') { i = skipStr(s, i); continue; }
        if (s[i] === '{') d++; else if (s[i] === '}') d--;
        i++;
      }
      continue;
    }
    i++;
  }
  return i;
}

function splitTernary(expr) {
  let depth = 0;
  let q = -1;
  for (let i = 0; i < expr.length;) {
    const c = expr[i];
    if (c === '"' || c === '\'' || (c === 'r' && (expr[i + 1] === '"' || expr[i + 1] === '\'') && !(i > 0 && /[A-Za-z0-9_]/.test(expr[i - 1])))) { i = skipStr(expr, i); continue; }
    if ('([{'.includes(c)) depth++;
    else if (')]}'.includes(c)) depth--;
    else if (c === '?' && depth === 0) {
      const n = expr[i + 1];
      const prevSpace = i === 0 || /\s/.test(expr[i - 1]);
      if (n === '?') { i += 2; continue; }
      if ((n === '.' || n === '[') && !prevSpace) { i += 1; continue; }
      q = i;
      break;
    }
    i++;
  }
  if (q < 0) return null;
  let d2 = 0;
  let nested = 0;
  for (let i = q + 1; i < expr.length;) {
    const c = expr[i];
    if (c === '"' || c === '\'' || (c === 'r' && (expr[i + 1] === '"' || expr[i + 1] === '\'') && !(i > 0 && /[A-Za-z0-9_]/.test(expr[i - 1])))) { i = skipStr(expr, i); continue; }
    if ('([{'.includes(c)) d2++;
    else if (')]}'.includes(c)) d2--;
    else if (d2 === 0 && c === '?' && expr[i + 1] !== '?' && expr[i + 1] !== '.' && !(expr[i - 1] === '?')) nested++;
    else if (d2 === 0 && c === ':') {
      if (nested === 0) return { cond: expr.slice(0, q), a: expr.slice(q + 1, i), b: expr.slice(i + 1) };
      nested--;
    }
    i++;
  }
  return null;
}

function stripParens(e) {
  e = e.trim();
  while (e.startsWith('(') && e.endsWith(')')) {
    let d = 0, ok = true;
    for (let i = 0; i < e.length; i++) {
      if (e[i] === '"' || e[i] === '\'') { i = skipStr(e, i) - 1; continue; }
      if (e[i] === '(') d++; else if (e[i] === ')') { d--; if (d === 0 && i < e.length - 1) { ok = false; break; } }
    }
    if (!ok) break;
    e = e.slice(1, -1).trim();
  }
  return e;
}

function isLoneInterp(v) { return v.parts.length === 1 && v.parts[0].t === 'interp'; }

const normCond = (c) => c.replace(/\s+/g, ' ').trim();
// Fusionne deux jeux de decisions (condition -> vrai/faux) ; null si contradictoires (meme condition, branches opposees).
function mergeDec(a, b) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) {
    if (k in out && out[k] !== v) return null;
    out[k] = v;
  }
  return out;
}

// Variantes d'une expression : liste de { parts: [{t:'text'|'interp'}], dec: {condition: bool} }.
function exprVariants(expr, file, cap) {
  const e = stripParens(expr);
  const tern = splitTernary(e);
  if (tern) {
    const c = normCond(tern.cond);
    const tag = (vs, val) => vs.map((v) => { const d = mergeDec(v.dec, { [c]: val }); return d ? { parts: v.parts, dec: d } : null; }).filter(Boolean);
    return [...tag(exprVariants(tern.a, file, cap), true), ...tag(exprVariants(tern.b, file, cap), false)];
  }
  if (/^r?(["'])/.test(e)) {
    const g = extractLiterals(e, file).filter((x) => x.nestedDepth === 0);
    if (g.length === 1 && g[0].source.replace(/\s+/g, '') === e.replace(/\s+/g, '')) return partsVariants(partsOf(g[0]), file, cap);
  }
  return [{ parts: [{ t: 'interp', v: e }], dec: {} }];
}

function partsVariants(parts, file, cap) {
  let forms = [{ parts: [], dec: {} }];
  for (const p of parts) {
    if (p.t === 'text') { forms = forms.map((f) => ({ parts: [...f.parts, p], dec: f.dec })); continue; }
    const vs = exprVariants(p.v, file, cap);
    const allDynamic = vs.every(isLoneInterp);
    const next = [];
    if (!allDynamic) for (const f of forms) for (const v of vs) { const d = mergeDec(f.dec, v.dec); if (d) next.push({ parts: [...f.parts, ...v.parts], dec: d }); }
    if (allDynamic || next.length > cap || next.length === 0) { forms = forms.map((f) => ({ parts: [...f.parts, p], dec: f.dec })); continue; }
    forms = next;
  }
  return forms;
}
function partsOf(entry) {
  const out = [];
  const re = /\{(\d+)\}/g;
  let last = 0, m;
  const t = entry.template;
  while ((m = re.exec(t))) {
    if (m.index > last) out.push({ t: 'text', v: t.slice(last, m.index) });
    out.push({ t: 'interp', v: entry.interpolations[Number(m[1])] });
    last = m.index + m[0].length;
  }
  if (last < t.length) out.push({ t: 'text', v: t.slice(last) });
  return out;
}

/** Formes d'un litteral apres developpement des conditionnelles (au plus `cap` formes). Chaque forme : { key, template, exprs }. */
function expandVariants(entry, cap = 16) {
  const forms = partsVariants(partsOf(entry), entry.file, cap).map((f) => f.parts);
  const seen = new Set();
  const out = [];
  for (const f of forms) {
    const merged = [];
    for (const p of f) {
      const last = merged[merged.length - 1];
      if (p.t === 'text' && last && last.t === 'text') merged[merged.length - 1] = { t: 'text', v: last.v + p.v }; else merged.push(p);
    }
    let template = '';
    const exprs = [];
    for (const p of merged) {
      if (p.t === 'text') template += p.v; else { template += `{${exprs.length}}`; exprs.push(p.v); }
    }
    const key = exprs.length ? '§' + template : template;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ key, template, exprs });
  }
  return out;
}

const FR_WORDS = /(?:^|[\s'’(«])(le|la|les|de|du|des|un|une|et|ou|à|au|aux|pour|sur|par|avec|sans|vous|votre|vos|mon|ma|mes|ce|cette|ces|est|sont|pas|plus|en|dans|aucun|aucune|ajouter|annuler|voir|erreur|impossible|choisir|envoyer|enregistr\w*|demande\w*|rang|promotion|classement|talent\w*|étudiant\w*|établissement\w*|filière\w*|publi\w*|terminée?s?|ouvrir)(?=$|[\s'’.,:;!?)»])/i;

/** Heuristique : le litteral ressemble-t-il a un texte francais affiche ? */
function looksUserFacing(entry) {
  const text = entry.template.replace(/\{\d+\}/g, '').trim();
  if (!/\p{L}{2}/u.test(text)) return false;
  if (/^[/#]|:\/\/|^https?:|^assets\/|^\.|\.(png|jpg|jpeg|svg|json|dart|webp|mp4|pdf)$/i.test(entry.template.trim())) return false;
  if (!/\s/.test(text) && !/[^\x00-\x7f]/.test(text)) {
    return /^[A-ZÀ-Ý][a-zà-ÿ]{2,}$/.test(text) && !/[_\d]/.test(text);
  }
  if (/^[a-z0-9_.\-:/ ,|]+$/.test(text) && !FR_WORDS.test(text)) return false;
  if (/^(select|insert|update|delete)\s/i.test(text)) return false;
  return /[^\x00-\x7f]/.test(text) || FR_WORDS.test(text) || /^[A-ZÀ-Ý]/.test(text);
}

function listDart(p) {
  const st = fs.statSync(p);
  if (st.isFile()) return [p];
  const out = [];
  for (const e of fs.readdirSync(p, { withFileTypes: true })) {
    const f = path.join(p, e.name);
    if (e.isDirectory()) out.push(...listDart(f)); else if (e.name.endsWith('.dart')) out.push(f);
  }
  return out;
}

module.exports = { extractLiterals, looksUserFacing, listDart, expandVariants, splitTernary };

if (require.main === module) {
  const files = process.argv.slice(2).flatMap(listDart);
  const res = [];
  for (const f of files) res.push(...extractLiterals(fs.readFileSync(f, 'utf8'), f.replace(/\\/g, '/')));
  process.stdout.write(JSON.stringify(res, null, 1));
}