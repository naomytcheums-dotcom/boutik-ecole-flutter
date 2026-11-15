import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/staff_portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1200, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('chaque rôle de l’équipe arrive sur son tableau de bord ; les autres rôles n’ont pas d’accès', () {
    expect(staffConsoleFor('Admin global'), '127');
    expect(staffConsoleFor('Resp. département'), '108');
    expect(staffConsoleFor('Direction'), '117');
    expect(staffConsoleFor('Finance'), '139');
    expect(staffConsoleFor('Support'), '145');
    expect(staffConsoleFor(''), isNull);
    expect(staffConsoleFor('Client'), isNull);
  });

  test('lien du portail : clé longue et aléatoire dans le chemin', () {
    expect(staffPortalKey.length, greaterThanOrEqualTo(24));
    expect(staffPortalPath(), '/equipe/$staffPortalKey');
  });

  testWidgets('bonne clé : formulaire de connexion de l’équipe', (t) async {
    await _pump(t, const StaffPortalScreen(portalKey: staffPortalKey));
    expect(find.text('Espace équipe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('mauvaise clé : page vide, aucune trace du portail', (t) async {
    await _pump(t, const StaffPortalScreen(portalKey: 'devine'));
    expect(find.text('Espace équipe'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('compte connecté hors équipe : page neutre, sa session n’est pas touchée', (t) async {
    t.view.physicalSize = const Size(1200, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    const client = Account(name: 'Cli Ent', phone: '690000000', email: 'client@t.cm', password: 'Boutik2026', role: 0);
    c.read(authProvider.notifier).login(client);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: StaffPortalScreen(portalKey: staffPortalKey))));
    await t.pumpAndSettle();
    expect(find.text('Espace équipe'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(c.read(authProvider).current, isNotNull);
  });
}
