import 'package:boutik_ecole/figma/g/g_154.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/dossier.dart';
import 'package:boutik_ecole/figma/live/profile_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Docs extends DocsNotifier {
  _Docs(this.v);
  final List<UserDoc>? v;
  @override
  List<UserDoc>? build() => v;
}

UserDoc _d(String kind, String name) => UserDoc(id: kind, kind: kind, name: name, path: 'p/$kind', size: 10, status: 'pending', note: '', createdAt: DateTime(2026, 11, 1));

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const e = G_154();
    await t.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: e)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(e))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('pourcentage calculé sur les pièces', () {
    final items = dossierItems([_d('cv', 'cv.pdf'), _d('student_card', 'carte.jpg')], demoAccount);
    expect(items.length, 6);
    expect(dossierPercent(items), greaterThanOrEqualTo(33));
    expect(dossierPercent(const []), 0);
  });

  testWidgets('connecté : checklist réelle, aucun fichier de maquette', (t) async {
    await monter(t, connecte: true, overrides: [myDocsProvider.overrideWith(() => _Docs([_d('cv', 'MonCV.pdf')]))]);
    expect(find.text('MonCV.pdf'), findsOneWidget);
    expect(find.text('CV_Mariam_Essono.pdf'), findsNothing);
    expect(find.text('Dossier complet à 78 %'), findsNothing);
  });

  testWidgets('connecté sans document : tout est à fournir', (t) async {
    await monter(t, connecte: true, overrides: [myDocsProvider.overrideWith(() => _Docs(const []))]);
    expect(find.text('Document manquant'), findsWidgets);
    expect(find.text('CV_Mariam_Essono.pdf'), findsNothing);
  });

  testWidgets('hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, connecte: false);
    expect(find.text('CV_Mariam_Essono.pdf'), findsWidgets);
  });
}
