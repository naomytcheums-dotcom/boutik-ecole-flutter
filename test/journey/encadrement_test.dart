import 'package:boutik_ecole/figma/g/g_113.dart';
import 'package:boutik_ecole/figma/g/g_114.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/dept_space.dart' show deptCallProvider;
import 'package:boutik_ecole/figma/live/encadrement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés des états', () {
    expect(productionStatus('en_retard'), 'En retard');
    expect(productionStatus('terminee'), 'Terminée');
    expect(productionStatus('en_cours'), 'En cours');
  });

  // K3 : en connecté, les toiles 113 et 114 incrustent la page mobile réelle (mêmes lectures `deptCallProvider`).
  Future<void> monterChef(WidgetTester t, Widget ecran, Map<String, Object? Function()> reads) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final all = {'my_department': () => {'role': 'dept', 'attached': true, 'department': 'Informatique', 'institution': 'IUT'}, ...reads};
    await t.pumpWidget(ProviderScope(
      overrides: [
        initialAccountProvider.overrideWithValue(demoAccount.copyWith(staff: 'Resp. département')),
        deptCallProvider.overrideWith((ref, c) async {
          final f = all[c.fn];
          if (f == null) throw 'Fonction inattendue : ${c.fn}';
          return f();
        }),
      ],
      child: MaterialApp(home: ecran),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('113 connecté : productions réelles (page réelle)', (t) async {
    await monterChef(t, const G_113(), {
      'staff_productions': () => [
            {'id': '1', 'title': 'Lot Test', 'team': 'Équipe A', 'mentor': 'Dr Test', 'progress': 40, 'status': 'en_cours'},
            {'id': '2', 'title': 'Appli Test', 'team': 'Équipe B', 'mentor': '', 'progress': 20, 'status': 'en_retard'},
          ],
    });
    expect(find.text('Lot Test'), findsOneWidget);
    expect(find.text('En retard'), findsWidgets);
    expect(find.text('Lot de 50 lampes recyclées'), findsNothing);
  });

  testWidgets('113 connecté vide : état vide, aucune ligne de maquette', (t) async {
    await monterChef(t, const G_113(), {'staff_productions': () => const []});
    expect(find.text('Aucune production'), findsOneWidget);
    expect(find.text('Lot de 50 lampes recyclées'), findsNothing);
  });

  testWidgets('114 connecté : mentors réels', (t) async {
    await monterChef(t, const G_114(), {
      'staff_mentors': () => [
            {'id': '1', 'name': 'Dr Test', 'role': 'Mentor', 'specialty': 'Réseaux', 'active': true, 'productions': 2}
          ],
    });
    expect(find.text('Dr Test'), findsOneWidget);
    expect(find.text('Dr Paul Tchoupo'), findsNothing);
  });

  testWidgets('114 connecté sans droit : message d’erreur et « Réessayer »', (t) async {
    await monterChef(t, const G_114(), {'staff_mentors': () => throw 'Accès réservé à la gestion'});
    expect(find.text('Lecture impossible'), findsOneWidget);
    expect(find.textContaining('Accès réservé'), findsWidgets);
    expect(find.text('Réessayer'), findsWidgets);
    expect(find.text('Dr Paul Tchoupo'), findsNothing);
  });

  for (final c in <(String, Widget, String)>[('113', const G_113(), 'Lot de 50 lampes recyclées'), ('114', const G_114(), 'Dr Paul Tchoupo')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
