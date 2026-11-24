import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/dept_invite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// Page d'invitation d'un responsable de département (lien privé). Le comportement réel (jeton, expiration, usage unique, rôle) est prouvé
/// par `supabase/tests/marketplace_pglite/invitations_departement.mjs` et sur le serveur réel ; ici, l'affichage et l'appel.
void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());
  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.calls.clear();
  });
  tearDown(() => GScreen.mockupFrame = true);

  // Fin de test : on démonte l'arbre et on avance l'horloge pour libérer les minuteries de connexion HTTP gardées ouvertes.
  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Future<void> ouvrir(WidgetTester t, {Account? compte}) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [if (compte != null) initialAccountProvider.overrideWithValue(compte)],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const DeptInviteScreen(token: 'abc')),
          GoRoute(path: '/departement', builder: (_, _) => const Scaffold(body: Center(child: Text('Espace département')))),
        ]),
      ),
    ));
    await settleReal(t, rounds: 8, ms: 60);
  }

  testWidgets('lien valide : département, fonction, bouton Accepter', (t) async {
    srv.rpc['dept_invite_info'] = (_) => {'valid': true, 'state': 'valid', 'department': 'Génie logiciel', 'institution': 'IUT de Douala', 'title': 'Chef de département', 'email_hint': 'cl***@t.cm'};
    await ouvrir(t);
    expect(find.text('Génie logiciel'), findsOneWidget);
    expect(find.text('IUT de Douala'), findsOneWidget);
    expect(find.text('Fonction : Chef de département'), findsOneWidget);
    expect(find.textContaining('cl***@t.cm'), findsOneWidget);
    expect(find.text('Accepter l’invitation'), findsOneWidget);
    await fin(t);
  });

  for (final e in {'used': 'déjà été utilisée', 'expired': 'a expiré', 'revoked': 'annulée', 'unknown': 'n’existe pas'}.entries) {
    testWidgets('lien ${e.key} : message clair, pas de bouton', (t) async {
      srv.rpc['dept_invite_info'] = (_) => {'valid': false, 'state': e.key};
      await ouvrir(t);
      expect(find.textContaining(e.value), findsOneWidget);
      expect(find.text('Accepter l’invitation'), findsNothing);
      await fin(t);
    });
  }

  testWidgets('Accepter : le jeton du lien est envoyé au serveur', (t) async {
    srv.rpc['dept_invite_info'] = (_) => {'valid': true, 'state': 'valid', 'department': 'Génie logiciel', 'institution': 'X', 'title': 'Responsable'};
    srv.rpc['dept_invite_accept'] = (_) => {'department': 'Génie logiciel', 'institution': 'X', 'title': 'Responsable'};
    await ouvrir(t, compte: Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', serverId: FakeSupabase.userId));
    await t.tap(find.text('Accepter l’invitation'));
    await settleReal(t, rounds: 4, ms: 25);
    expect(srv.calls.any((c) => c.kind == 'rpc' && c.name == 'dept_invite_accept' && c.args['p_token'] == 'abc'), isTrue, reason: '${srv.calls}');
    expect(find.text('Espace département'), findsOneWidget, reason: 'après acceptation, ouverture de l’espace département');
    await fin(t);
  });

  test('le lien commence par le site et finit par le jeton', () {
    expect(deptInviteLink('xyz'), endsWith('/#/invitation/xyz'));
  });
}
