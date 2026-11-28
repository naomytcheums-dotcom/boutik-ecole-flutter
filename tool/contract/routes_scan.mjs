// Routes GoRouter : table des routes declarees, ecrans du manifeste et cibles de navigation litterales du Dart.
import fs from 'node:fs';
import path from 'node:path';
import { maskComments, lineOf } from './dart_scan.mjs';

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.dart') || e.name.endsWith('.dart.fixture')) out.push(p);
  }
  return out;
}

// '/a/:id' -> RegExp ; les segments d'interpolation (`$x`, `${...}`) sont remplaces par `\u0001` avant comparaison.
export function routeRegex(pattern) {
  const body = pattern.split('/').map((seg) => (seg.startsWith(':') ? '[^/]+' : seg.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))).join('/');
  return new RegExp(`^${body}/?$`);
}

export function normalizeTarget(raw) {
  let t = raw.split('#')[0].split('?')[0];
  t = t.replace(/\$\{[^}]*\}|\$\w+/g, '\u0001');
  return t;
}

export function matchRoute(routes, target) {
  const t = normalizeTarget(target);
  // un segment d'interpolation se comporte comme une valeur de parametre ; sinon il doit pouvoir completer un segment statique
  const probe = t.replace(/\u0001/g, 'x');
  return routes.findIndex((r) => routeRegex(r.path).test(probe));
}

export function screenKnown(ids, id) {
  return [id, id.toUpperCase(), id.toLowerCase(), id.replace(/_/g, '-')].some((k) => ids.has(k));
}

export function scanRoutes(root) {
  const routerFile = path.join(root, 'lib', 'core', 'router', 'app_router.dart');
  const rsrc = maskComments(fs.readFileSync(routerFile, 'utf8'));
  const routes = [];
  for (const m of rsrc.matchAll(/GoRoute\(\s*path:\s*'([^']+)'/g)) {
    const tail = rsrc.slice(m.index, m.index + 400);
    routes.push({ path: m[1], at: `lib/core/router/app_router.dart:${lineOf(rsrc, m.index)}`, redirectOnly: /^GoRoute\(\s*path:\s*'[^']+',\s*redirect:/.test(tail) });
  }

  const files = walk(path.join(root, 'lib'));
  const screenIds = new Set();
  const targets = [];
  const screenRefs = [];
  const rel = (f) => path.relative(root, f).split(path.sep).join('/');
  const callRe = /(?<![\w$])(?:(go|push|pushReplacement|replace|goTo|GRedirect|pushAndRemoveUntil)|(screenPath))\(\s*(?:const\s+)?(?:'([^'\n]*)'|"([^"\n]*)")/g;
  for (const f of files) {
    const raw = fs.readFileSync(f, 'utf8');
    const masked = maskComments(raw);
    for (const m of masked.matchAll(/ScreenEntry\(\s*'([^']+)'/g)) screenIds.add(m[1]);
    for (const m of masked.matchAll(callRe)) {
      const value = m[3] ?? m[4];
      const at = `${rel(f)}:${lineOf(masked, m.index)}`;
      if (m[2]) { if (!value.includes('$')) screenRefs.push({ id: value, at }); continue; }
      if (!value.startsWith('/')) continue;
      targets.push({ path: value, at, via: m[1] });
    }
    for (const m of masked.matchAll(/'\/s\/([A-Za-z0-9_-]+)(?:\?[^']*)?'/g)) screenRefs.push({ id: m[1], at: `${rel(f)}:${lineOf(masked, m.index)}` });
  }
  return { routes, screenIds, targets, screenRefs };
}

// Ecarts : cible sans route, ecran de manifeste inexistant, route masquee par une route precedente ou doublon.
export function checkRoutes({ routes, screenIds, targets, screenRefs }) {
  const out = [];
  for (const t of targets) {
    const target = normalizeTarget(t.path);
    if (matchRoute(routes, t.path) < 0) out.push({ kind: 'route_missing', key: `route_missing|${target.replace(/\u0001/g, ':x')}`, at: t.at, detail: `${t.via}('${t.path}') n'a pas de route` });
    const s = /^\/s\/([^/]+)$/.exec(target);
    if (s && !s[1].includes('\u0001') && !screenKnown(screenIds, s[1])) out.push({ kind: 'screen_missing', key: `screen_missing|${s[1]}`, at: t.at, detail: `ecran ${s[1]} absent du manifeste` });
  }
  for (const r of screenRefs) if (!screenKnown(screenIds, r.id)) out.push({ kind: 'screen_missing', key: `screen_missing|${r.id}`, at: r.at, detail: `ecran ${r.id} absent du manifeste` });
  routes.forEach((r, i) => {
    if (r.path.includes(':')) return;
    const j = routes.slice(0, i).findIndex((q) => routeRegex(q.path).test(r.path));
    if (j >= 0) out.push({ kind: 'route_shadowed', key: `route_shadowed|${r.path}`, at: r.at, detail: `${r.path} est deja declaree ou masquee par ${routes[j].path} (${routes[j].at})` });
  });
  const seen = new Set();
  return out.filter((f) => { const k = `${f.key}@${f.at}`; if (seen.has(k)) return false; seen.add(k); return true; });
}
