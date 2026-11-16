import 'package:boutik_ecole/figma/g/g_156.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/l8_opportunites.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:boutik_ecole/figma/live/opportunites_screens.dart' show oppMyApplicationsProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

NotificationItem _n(String kind) => NotificationItem(id: 'n', kind: kind, title: 't', body: 'b', createdAt: DateTime(2026, 11, 1), read: false);

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {List<Override> overrides = const []}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
    await t.pumpAndSettle();
  }

  test('S8-16 : les notifications mentor, profil mentor et dossier ont une destination', () {
    expect(notificationActionLabel(_n('mentor_request')), 'Voir mes demandes de mentor');
    expect(notificationActionLabel(_n('mentor_profile')), 'Voir mon profil mentor');
    expect(notificationActionLabel(_n('document')), 'Voir mon dossier');
  });

  testWidgets('S8-5 : l\'écran 156 propose le réglage « Pièces du dossier » (il est lu par le serveur)', (t) async {
    await monter(t, const G_156());
    expect(find.text('Pièces du dossier'), findsOneWidget);
    expect(find.text('Offres compatibles'), findsOneWidget);
    expect(find.text('Résultats de candidature'), findsOneWidget);
  });

  testWidgets('S8-12 : 159 relit la dernière candidature sur le serveur après un rechargement', (t) async {
    await monter(t, const ApplicationSentHost(), overrides: [
      oppMyApplicationsProvider.overrideWith((ref) async => [
            {'id': 'a1', 'status': 'sent', 'created_at': '2026-11-01T10:00:00Z', 'opportunity_id': 'o1', 'title': 'Stage relu', 'org': 'Acme'},
          ]),
    ]);
    expect(find.text('Stage relu'), findsOneWidget);
    expect(find.textContaining('depuis cet appareil'), findsNothing);
  });
}

class ApplicationSentHost extends StatelessWidget {
  const ApplicationSentHost({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: SingleChildScrollView(child: ApplicationSentCard()));
}
