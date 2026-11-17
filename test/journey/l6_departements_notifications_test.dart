import 'package:boutik_ecole/figma/g/g_214.dart';
import 'package:boutik_ecole/figma/g/g_215.dart';
import 'package:boutik_ecole/figma/g/g_173.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/department_pages.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot L6 : départements réels (214, 215), notifications routées, partage réel (173).
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<ProviderContainer> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byWidget(ecran)));
    if (connecte) {
      c.read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
    return c;
  }

  testWidgets('214 connecté : seuls les départements vérifiés du serveur sont listés, sans ligne de maquette', (t) async {
    await monter(t, const G_214(), connecte: true, overrides: [
      departmentRowsProvider.overrideWith((ref) async => [
            {'id': 'd1', 'name': 'Génie Test', 'institutions': {'name': 'Institut Test'}},
          ]),
    ]);
    expect(find.text('Génie Test'), findsOneWidget);
    expect(find.text('Institut Test'), findsOneWidget);
    expect(find.text('GBM · Génie biomédical'), findsNothing);
    expect(find.text('Tertiaire'), findsNothing);
  });

  testWidgets('215 connecté : fiche réelle du département choisi, jamais le nom du compte en vedette', (t) async {
    final c = await monter(t, const G_215(), connecte: true, overrides: [
      departmentDetailProvider.overrideWith((ref, id) async => id == 'd1'
          ? {
              'id': 'd1',
              'name': 'Génie Test',
              'institution': 'Institut Test',
              'city': 'Douala',
              'students': 12,
              'listings': 3,
              'projects': 2,
              'featured': [
                {'id': 'u9', 'name': 'Awa Réelle', 'skills': 'Flutter', 'avatar_url': null, 'certified': true},
              ],
            }
          : null),
    ]);
    c.read(selectedDepartmentProvider.notifier).set('d1');
    await t.pumpAndSettle();
    expect(find.text('Génie Test'), findsWidgets);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Awa Réelle'), findsOneWidget);
    expect(find.text('Génie Informatique · GI'), findsNothing);
    expect(find.text(demoAccount.name), findsNothing);
    expect(find.text('Mariam Essono'), findsNothing);
  });

  testWidgets('215 connecté sans département choisi : invitation à en choisir un', (t) async {
    await monter(t, const G_215(), connecte: true);
    expect(find.textContaining('Choisissez un département'), findsOneWidget);
  });

  testWidgets('173 connecté : plus de lien vers « Partager mon CV », la photo de maquette n’est plus affichée', (t) async {
    await monter(t, const G_173(), connecte: true);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
  });

  test('notification : le bouton d’action dépend du type, un type sans écran propre n’en a pas', () {
    NotificationItem n(String kind) => NotificationItem(id: '1', kind: kind, title: 't', body: 'b', createdAt: DateTime(2026), read: false);
    expect(notificationActionLabel(n('order')), 'Voir la commande');
    expect(notificationActionLabel(n('message')), 'Ouvrir la conversation');
    expect(notificationActionLabel(n('support')), isNotNull);
    expect(notificationActionLabel(n('support_ticket')), isNotNull);
    expect(notificationActionLabel(n('community_accept')), isNotNull);
    expect(notificationActionLabel(n('referral')), 'Voir mon parrainage');
    expect(notificationActionLabel(n('type_inconnu')), isNull);
  });

  test('notification : les données jointes sont conservées et groupées par catégorie', () {
    final item = NotificationItem.fromRow({'id': 'x', 'kind': 'order', 'title': 'T', 'body': 'B', 'created_at': '2026-11-01T10:00:00Z', 'read_at': null, 'data': {'order_number': 'BE-1'}});
    expect(item.data['order_number'], 'BE-1');
    expect(item.read, isFalse);
    expect(item.asRead().read, isTrue);
    expect(notifGroup('payment'), 1);
    expect(notifGroup('teammate_message'), 2);
    expect(notifGroup('follow'), 3);
  });
}
