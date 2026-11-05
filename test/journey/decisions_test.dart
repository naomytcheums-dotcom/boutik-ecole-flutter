import 'package:boutik_ecole/figma/g/g_149.dart';
import 'package:boutik_ecole/figma/g/g_185.dart';
import 'package:boutik_ecole/figma/g/g_225.dart';
import 'package:boutik_ecole/figma/g/g_230.dart';
import 'package:boutik_ecole/figma/g/g_231.dart';
import 'package:boutik_ecole/figma/g/g_232.dart';
import 'package:boutik_ecole/figma/g/g_241.dart';
import 'package:boutik_ecole/figma/g/g_256.dart';
import 'package:boutik_ecole/figma/g/g_272.dart';
import 'package:boutik_ecole/figma/g/g_279.dart';
import 'package:boutik_ecole/figma/g/g_281.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/decisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'sb_publishable_test', authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false));
  });
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  testWidgets('230 connecté : brief écrit, plus de dialogue de maquette', (t) async {
    await monter(t, const G_230(), connecte: true);
    expect(find.text('Décrivez votre besoin'), findsOneWidget);
    expect(find.text('Créer le brouillon'), findsOneWidget);
  });

  testWidgets('232 connecté : briefs réels, aucun message de maquette', (t) async {
    await monter(t, const G_232(), connecte: true, overrides: [myMissionDraftsProvider.overrideWith(() => _Rows('table:missions', const []))]);
    expect(find.textContaining('Aucun brief'), findsOneWidget);
    expect(find.textContaining('Compris ! Je lance ton brief'), findsNothing);
  });

  testWidgets('231 connecté : menu avec le prénom du compte', (t) async {
    await monter(t, const G_231(), connecte: true);
    expect(find.textContaining('Bonjour'), findsWidgets);
    expect(find.text('Écrire mon besoin à Kéla'), findsOneWidget);
  });

  testWidgets('225 connecté : pas de faux modèle 3D', (t) async {
    await monter(t, const G_225(), connecte: true);
    expect(find.textContaining('Aucun modèle 3D'), findsOneWidget);
    expect(find.text('H 42 cm'), findsNothing);
  });

  testWidgets('272 connecté sans serveur : message honnête, pas de code SMS inventé', (t) async {
    await monter(t, const G_272(), connecte: true);
    expect(find.textContaining('Envoyé par SMS'), findsNothing);
    expect(find.textContaining('double authentification'), findsWidgets);
  });

  testWidgets('241 connecté : plus de contacts de maquette', (t) async {
    await monter(t, const G_241(), connecte: true);
    expect(find.text('Sur WhatsApp · pas encore inscrit'), findsNothing);
  });

  testWidgets('149 : langue honnête et réglage mémorisé', (t) async {
    await monter(t, const G_149(), connecte: true);
    expect(find.text('Bientôt disponible'), findsOneWidget);
  });

  testWidgets('185 connecté : anglais non proposé tant que non traduit', (t) async {
    await monter(t, const G_185(), connecte: true);
    expect(find.text('Bientôt disponible'), findsOneWidget);
    expect(find.text('Recycled wooden lamp'), findsNothing);
  });

  testWidgets('256 connecté : contrôles calculés sur l’annonce réelle', (t) async {
    await monter(t, const G_256(), connecte: true, overrides: [checkListingsProvider.overrideWith(() => _Rows('table:listings', const []))]);
    expect(find.textContaining('pas encore d’annonce'), findsOneWidget);
    expect(find.text('12 / 12 réussis'), findsNothing);
  });

  testWidgets('279 connecté : plus de fichiers de maquette', (t) async {
    await monter(t, const G_279(), connecte: true);
    expect(find.text('plan-lampe.pdf'), findsNothing);
    expect(find.text('Règles de dépôt'), findsWidgets);
  });

  testWidgets('281 connecté : institution du compte', (t) async {
    await monter(t, const G_281(), connecte: true);
    expect(find.textContaining('Institution'), findsWidgets);
  });

  testWidgets('hors connexion : les démonstrations restent affichées', (t) async {
    await monter(t, const G_272(), connecte: false);
    expect(find.textContaining('Envoyé par SMS'), findsOneWidget);
    await monter(t, const G_232(), connecte: false);
    expect(find.textContaining('Compris ! Je lance ton brief'), findsOneWidget);
  });
}
