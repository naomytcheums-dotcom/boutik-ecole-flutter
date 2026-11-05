import 'package:boutik_ecole/figma/g/g_148_1.dart';
import 'package:boutik_ecole/figma/g/g_173.dart';
import 'package:boutik_ecole/figma/g/g_248.dart';
import 'package:boutik_ecole/figma/g/g_278.dart';
import 'package:boutik_ecole/figma/g/g_285.dart';
import 'package:boutik_ecole/figma/g/g_158.dart';
import 'package:boutik_ecole/figma/g/g_251.dart';
import 'package:boutik_ecole/figma/g/g_244b.dart';
import 'package:boutik_ecole/figma/g/g_25b.dart';
import 'package:boutik_ecole/figma/g/g_127.dart';
import 'package:boutik_ecole/figma/g/g_263.dart';
import 'package:boutik_ecole/figma/g/g_74.dart';
import 'package:boutik_ecole/figma/g/g_88.dart';
import 'package:boutik_ecole/figma/g/g_93b.dart';
import 'package:boutik_ecole/figma/g/g_94.dart';
import 'package:boutik_ecole/figma/g/g_97.dart';
import 'package:boutik_ecole/figma/g/g_101.dart';
import 'package:boutik_ecole/figma/g/g_104.dart';
import 'package:boutik_ecole/figma/g/g_33.dart';
import 'package:boutik_ecole/figma/g/g_51.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/lot20b.dart';
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

  testWidgets('148_1 connecté : nom et e-mail du compte', (t) async {
    await monter(t, const G_148_1(), connecte: true);
    expect(find.text(demoAccount.name), findsWidgets);
    expect(find.text(demoAccount.email), findsWidgets);
  });

  testWidgets('248 connecté sans annonce : message honnête', (t) async {
    await monter(t, const G_248(), connecte: true, overrides: [myListingsProvider.overrideWith(() => _Rows('table:listings', const []))]);
    expect(find.textContaining('aucune annonce'), findsOneWidget);
    expect(find.text('0 annonce'), findsOneWidget);
  });

  testWidgets('158 connecté : propositions réelles', (t) async {
    await monter(t, const G_158(), connecte: true, overrides: [
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', [
            {'author': 'Alice Test', 'mission': 'Logo', 'amount': 90000, 'delay_days': 7, 'status': 'submitted'}
          ]))
    ]);
    expect(find.text('Alice Test'), findsOneWidget);
  });

  testWidgets('285 connecté : besoins réels', (t) async {
    await monter(t, const G_285(), connecte: true, overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'title': 'Besoin Test', 'proposals': 1, 'status': 'assigned', 'created_at': '2026-11-01T10:00:00Z', 'team': 'Équipe A'}
          ]))
    ]);
    expect(find.text('Besoin Test'), findsOneWidget);
  });

  testWidgets('278 connecté : projets réels', (t) async {
    await monter(t, const G_278(), connecte: true, overrides: [
      projectsCatalogProvider.overrideWith(() => _Rows('table:projects', [
            {'title': 'Projet Test', 'summary': 'Résumé', 'department': 'GI', 'status': 'approved'}
          ]))
    ]);
    expect(find.text('Projet Test'), findsOneWidget);
  });

  testWidgets('25b connecté : aucun favori de maquette', (t) async {
    await monter(t, const G_25b(), connecte: true);
    expect(find.textContaining('Aucun favori'), findsOneWidget);
    expect(find.text('Maison et décoration'), findsNothing);
  });

  for (final c in <(String, Widget, String, bool)>[
    ('248', const G_248(), '8 articles · 4,9 ★', false),
    ('278', const G_278(), 'Liens du projet', false),
    ('285', const G_285(), 'Contrat de mission', false),
    ('158', const G_158(), 'Mariam Essono', false),
    ('251', const G_251(), 'Tendances', false),
    ('244b', const G_244b(), 'Yannick', false),
    ('25b', const G_25b(), 'Mes listes', false),
    ('127', const G_127(), 'Analytique · données en direct', true),
    ('263', const G_263(), 'Téléverser un média', true),
    ('74', const G_74(), 'Niveau Confirmé', false),
    ('88', const G_88(), 'Besoins publiés', false),
    ('93b', const G_93b(), 'Mariam Essono', false),
    ('94', const G_94(), 'Critère', false),
    ('97', const G_97(), 'Stage développeur web', false),
    ('101', const G_101(), 'Exposition des innovations', false),
    ('104', const G_104(), 'Atelier Génie civil', false),
    ('33', const G_33(), 'De la chute de bois à la lumière', false),
    ('51', const G_51(), 'Commande expédiée', false),
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
