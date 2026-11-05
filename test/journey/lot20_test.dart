import 'package:boutik_ecole/figma/g/g_145.dart';
import 'package:boutik_ecole/figma/g/g_268.dart';
import 'package:boutik_ecole/figma/g/g_147_1.dart';
import 'package:boutik_ecole/figma/g/g_147_2.dart';
import 'package:boutik_ecole/figma/g/g_147_3.dart';
import 'package:boutik_ecole/figma/g/g_169.dart';
import 'package:boutik_ecole/figma/g/g_117.dart';
import 'package:boutik_ecole/figma/g/g_180.dart';
import 'package:boutik_ecole/figma/g/g_288.dart';
import 'package:boutik_ecole/figma/g/g_287.dart';
import 'package:boutik_ecole/figma/g/g_146_1.dart';
import 'package:boutik_ecole/figma/g/g_155.dart';
import 'package:boutik_ecole/figma/g/g_183.dart';
import 'package:boutik_ecole/figma/g/g_283.dart';
import 'package:boutik_ecole/figma/g/g_284.dart';
import 'package:boutik_ecole/figma/g/g_270.dart';
import 'package:boutik_ecole/figma/g/g_217.dart';
import 'package:boutik_ecole/figma/g/g_277.dart';
import 'package:boutik_ecole/figma/g/g_276.dart';
import 'package:boutik_ecole/figma/g/g_286.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/lot20.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, bool large = false, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = large ? const Size(1280, 890) : const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés', () {
    expect(kioskStatus('maintenance'), 'Maintenance');
    expect(incidentKind('hardware'), 'Matériel');
    expect(listingStatus('approved'), 'Publiée');
  });

  testWidgets('145 connecté : bornes réelles', (t) async {
    await monter(t, const G_145(), connecte: true, large: true, overrides: [
      kiosksProvider.overrideWith(() => _Rows('table:kiosks', [
            {'id': 'borne-1', 'name': 'Borne Test', 'location': 'Hall', 'status': 'online', 'updated_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Borne Test'), findsOneWidget);
    expect(find.text('En ligne'), findsOneWidget);
  });

  testWidgets('147_2 connecté : compteurs et incidents ouverts réels', (t) async {
    await monter(t, const G_147_2(), connecte: true, large: true, overrides: [
      kiosksProvider.overrideWith(() => _Rows('table:kiosks', [
            {'id': 'borne-1', 'name': 'B1', 'location': 'Hall', 'status': 'online', 'updated_at': null},
            {'id': 'borne-2', 'name': 'B2', 'location': 'Bloc', 'status': 'maintenance', 'updated_at': null},
          ])),
      kioskIncidentsProvider.overrideWith(() => _Rows('table:kiosk_incidents', [
            {'id': 1, 'kiosk_id': 'borne-1', 'kind': 'hardware', 'message': 'Écran noir', 'created_at': '2026-11-01T10:00:00Z', 'resolved_at': null},
            {'id': 2, 'kiosk_id': 'borne-2', 'kind': 'payment', 'message': 'Paiement refusé', 'created_at': '2026-10-30T10:00:00Z', 'resolved_at': '2026-10-31T10:00:00Z'},
          ])),
    ]);
    expect(find.text('Écran noir'), findsOneWidget);
    expect(find.text('Paiement refusé'), findsNothing);
    expect(find.text('Incidents ouverts'), findsOneWidget);
  });

  testWidgets('155 connecté : notifications réelles', (t) async {
    await monter(t, const G_155(), connecte: true, overrides: [
      notificationsListProvider.overrideWith(() => _Rows('notifications', [
            {'title': 'Alerte Test', 'body': 'Texte', 'created_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Alerte Test'), findsOneWidget);
  });

  testWidgets('183 connecté : aucune commande de maquette, état vide', (t) async {
    await monter(t, const G_183(), connecte: true);
    expect(find.textContaining('Aucune commande'), findsOneWidget);
    expect(find.text('#BE-2026-0142'), findsNothing);
  });

  testWidgets('288 connecté : annonces réelles', (t) async {
    await monter(t, const G_288(), connecte: true, large: true, overrides: [
      listingsAdminProvider.overrideWith(() => _Rows('table:listings', [
            {'title': 'Annonce Test', 'status': 'draft', 'category': 'Maison', 'price': 5000, 'created_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Annonce Test'), findsOneWidget);
    expect(find.text('Brouillon'), findsOneWidget);
  });

  testWidgets('286 connecté : seules les annonces non publiées', (t) async {
    await monter(t, const G_286(), connecte: true, overrides: [
      listingsAdminProvider.overrideWith(() => _Rows('table:listings', [
            {'title': 'En attente Test', 'status': 'draft', 'category': 'Mode', 'price': 1000, 'created_at': '2026-11-01T10:00:00Z'},
            {'title': 'Publiée Test', 'status': 'approved', 'category': 'Mode', 'price': 1000, 'created_at': '2026-11-01T10:00:00Z'},
          ]))
    ]);
    expect(find.text('En attente Test'), findsOneWidget);
    expect(find.text('Publiée Test'), findsNothing);
  });

  testWidgets('180 connecté : nombre de comptes par rôle', (t) async {
    await monter(t, const G_180(), connecte: true, large: true, overrides: [
      consoleUsersProvider.overrideWith(() => _Rows('admin_users', [
            {'role': 'student'}, {'role': 'student'}, {'role': 'admin'}
          ]))
    ]);
    expect(find.text('2 comptes'), findsOneWidget);
    expect(find.text('1 compte'), findsOneWidget);
  });

  for (final c in <(String, Widget, String, bool)>[
    ('145', const G_145(), 'Kiosque Bloc B', true),
    ('268', const G_268(), 'Sessions par jour', true),
    ('147_1', const G_147_1(), '#T-2041', true),
    ('147_2', const G_147_2(), 'Incident', true),
    ('147_3', const G_147_3(), '22 oct. · Livraison 24 oct.', true),
    ('169', const G_169(), 'Orange Digital Challenge 2026', true),
    ('117', const G_117(), '+ 4 800 000 vs mois précédent', true),
    ('180', const G_180(), '4 comptes', true),
    ('288', const G_288(), 'Statut', true),
    ('287', const G_287(), 'Projets', true),
    ('146_1', const G_146_1(), 'Avant 17 h', false),
    ('155', const G_155(), 'Aujourd’hui', false),
    ('183', const G_183(), '#BE-2026-0142', false),
    ('283', const G_283(), 'BE-C-0412 · Lampe en bois recyclé', false),
    ('284', const G_284(), 'Montant brut', false),
    ('270', const G_270(), 'Lampe en bois recyclé', false),
    ('217', const G_217(), 'Vœu de Mouanga Yannick · Génie civil', false),
    ('277', const G_277(), 'Borne 1 · Hall principal', false),
    ('276', const G_276(), 'Connexion momentanément indisponible', false),
    ('286', const G_286(), 'Lampe en bois recyclé', false),
  ]) {
    testWidgets('${c.$1} connecté : plus de ligne de maquette', (t) async {
      await monter(t, c.$2, connecte: true, large: c.$4);
      expect(find.text(c.$3), findsNothing);
    });
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false, large: c.$4);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
