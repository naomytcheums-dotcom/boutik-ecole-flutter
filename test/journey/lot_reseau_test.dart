import 'package:boutik_ecole/figma/g/g_129.dart';
import 'package:boutik_ecole/figma/g/g_118.dart';
import 'package:boutik_ecole/figma/g/g_267.dart';
import 'package:boutik_ecole/figma/g/g_133.dart';
import 'package:boutik_ecole/figma/g/g_134.dart';
import 'package:boutik_ecole/figma/g/g_213.dart';
import 'package:boutik_ecole/figma/g/g_214.dart';
import 'package:boutik_ecole/figma/g/g_216.dart';
import 'package:boutik_ecole/figma/g/g_223.dart';
import 'package:boutik_ecole/figma/g/g_246.dart';
import 'package:boutik_ecole/figma/g/g_262.dart';
import 'package:boutik_ecole/figma/g/g_261.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/reseau.dart';
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
    expect(institutionStatus('verified'), 'Vérifié');
    expect(claimReason('damaged'), 'Article endommagé ou non conforme');
    expect(claimStatus('open'), 'Ouverte');
  });

  testWidgets('129 connecté : établissements réels', (t) async {
    await monter(t, const G_129(), connecte: true, large: true, overrides: [
      institutionsProvider.overrideWith(() => _Rows('table:institutions', [
            {'name': 'Institut Test', 'short_name': 'IT', 'kind': 'institut', 'city': 'Douala', 'status': 'verified'}
          ]))
    ]);
    expect(find.text('Institut Test'), findsOneWidget);
    expect(find.text('Vérifié'), findsOneWidget);
  });

  testWidgets('133 connecté : réclamations réelles', (t) async {
    await monter(t, const G_133(), connecte: true, large: true, overrides: [
      claimsListProvider.overrideWith(() => _Rows('table:claims', [
            {'reason': 'damaged', 'details': 'Article cassé à la livraison', 'status': 'open', 'created_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Article endommagé ou non conforme'), findsOneWidget);
  });

  testWidgets('216 connecté : vœux ouverts réels, brouillons exclus', (t) async {
    await monter(t, const G_216(), connecte: true, overrides: [
      wishesListProvider.overrideWith(() => _Rows('table:wishes', [
            {'title': 'Vœu Test', 'price': 5000, 'threshold': 20, 'status': 'approved'},
            {'title': 'Brouillon Test', 'price': 1, 'threshold': 1, 'status': 'draft'},
          ]))
    ]);
    expect(find.text('Vœu Test'), findsOneWidget);
    expect(find.text('Brouillon Test'), findsNothing);
  });

  testWidgets('223 connecté : seuls les lives programmés sont affichés', (t) async {
    await monter(t, const G_223(), connecte: true, overrides: [
      livesListProvider.overrideWith(() => _Rows('table:scheduled_lives', [
            {'title': 'Atelier Test', 'starts_at': 'Samedi 10 h', 'product_title': '', 'status': 'scheduled'},
            {'title': 'Brouillon Live', 'starts_at': '', 'product_title': '', 'status': 'draft'},
          ]))
    ]);
    expect(find.text('Atelier Test'), findsOneWidget);
    expect(find.text('Brouillon Live'), findsNothing);
  });

  for (final c in <(String, Widget, String, bool)>[
    ('129', const G_129(), 'Institution', true),
    ('118', const G_118(), 'Adresse', true),
    ('267', const G_267(), 'IUT de Bandjoun', true),
    ('133', const G_133(), 'LIT-0042', true),
    ('134', const G_134(), 'Référence', true),
    ('213', const G_213(), 'Identifiant', true),
    ('214', const G_214(), 'Technologies du Tertiaire · MTT', false),
    ('216', const G_216(), 'Lampe en bois recyclé', false),
    ('223', const G_223(), 'En direct maintenant · Atelier bois', false),
    ('246', const G_246(), 'EN DIRECT', false),
    ('262', const G_262(), 'Lancer un défi d’innovation', true),
    ('261', const G_261(), 'Suivre ma commande', false),
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
