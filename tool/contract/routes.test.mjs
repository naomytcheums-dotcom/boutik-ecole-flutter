// Routes GoRouter (aucun reseau) :
//   node --test tool/contract/routes.test.mjs
// Echoue si une navigation litterale (context.go/push, GRedirect, screenPath, '/s/<id>') vise une route ou un ecran
// inexistant, ou si une route est declaree deux fois / masquee par une route precedente.
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scanRoutes, checkRoutes, matchRoute, screenKnown } from './routes_scan.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('correspondance des routes : parametres, requetes, interpolation, doublons', () => {
  const routes = [{ path: '/a' }, { path: '/a/:id' }, { path: '/b/publier' }, { path: '/b/:id' }, { path: '/s/:id' }];
  assert.ok(matchRoute(routes, '/a?x=1') >= 0);
  assert.ok(matchRoute(routes, '/a/${item.id}') >= 0);
  assert.ok(matchRoute(routes, '/s/$id?user=1') >= 0);
  assert.equal(matchRoute(routes, '/c'), -1);
  assert.equal(matchRoute(routes, '/a/1/2'), -1);
  assert.ok(screenKnown(new Set(['146-1']), '146_1'));
  assert.ok(screenKnown(new Set(['P3']), 'p3'));
});

test('le controle signale route absente, ecran inconnu et route masquee', () => {
  const routes = [{ path: '/x', at: 'r:1' }, { path: '/y/:id', at: 'r:2' }, { path: '/y/new', at: 'r:3' }, { path: '/x', at: 'r:4' }];
  const f = checkRoutes({
    routes,
    screenIds: new Set(['01']),
    targets: [{ path: '/nope', at: 'a:1', via: 'push' }, { path: '/x', at: 'a:2', via: 'go' }, { path: '/s/99', at: 'a:3', via: 'go' }],
    screenRefs: [{ id: '77', at: 'a:4' }, { id: '01', at: 'a:5' }],
  }).map((x) => x.key).sort();
  assert.deepEqual(f, ['route_missing|/nope', 'route_missing|/s/99', 'route_shadowed|/x', 'route_shadowed|/y/new', 'screen_missing|77', 'screen_missing|99'].sort());
});

test('toutes les navigations litterales du code mene a une route ou un ecran existant', () => {
  const scan = scanRoutes(root);
  assert.ok(scan.routes.length > 100 && scan.screenIds.size > 300 && scan.targets.length > 200, 'extraction incomplete');
  assert.deepEqual(checkRoutes(scan).map((f) => `${f.key} @ ${f.at} - ${f.detail}`), []);
});
