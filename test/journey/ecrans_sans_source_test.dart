import 'package:boutik_ecole/figma/g/g_105.dart';
import 'package:boutik_ecole/figma/g/g_107.dart';
import 'package:boutik_ecole/figma/g/g_237.dart';
import 'package:boutik_ecole/figma/g/g_238.dart';
import 'package:boutik_ecole/figma/g/g_239.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/impact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Écrans d'impact et de sponsoring : connectés, ils lisent les agrégats calculés par le serveur ; sans donnée, un état vide ;
/// hors connexion, la démonstration reste affichée.
class _Rpc extends RpcMap {
  _Rpc(super.fn, this.v);
  final Map<String, dynamic>? v;
  @override
  Map<String, dynamic>? build() => v;
}

class _Sponsor extends SponsorReportNotifier {
  _Sponsor(this.v);
  final Map<String, dynamic>? v;
  @override
  Map<String, dynamic>? build() => v;
}

class _Autres extends OtherListings {
  _Autres(this.v);
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

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const [], Size size = const Size(393, 852), bool login = false}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (login) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  final impact = <String, dynamic>{'revenue_paid': 980500, 'students_paid': 12, 'missions_delivered': 4, 'orders_paid': 34, 'recycled_kg': 7.5, 'cities': [{'city': 'Douala', 'orders': 13, 'students': 12}]};

  testWidgets('238 connecté : l’impact calculé, aucun chiffre de maquette', (t) async {
    await monter(t, const G_238(), connecte: true, overrides: [platformImpactProvider.overrideWith(() => _Rpc('platform_impact', impact))]);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7,5 kg'), findsOneWidget);
    expect(find.textContaining('Douala'), findsWidgets);
    expect(find.text('Ensemble, nous faisons grandir le Cameroun'), findsNothing);
  });

  testWidgets('237 connecté : même impact en console web, sans valeur de maquette', (t) async {
    await monter(t, const G_237(), connecte: true, size: const Size(1280, 820), overrides: [platformImpactProvider.overrideWith(() => _Rpc('platform_impact', impact))]);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('48,2 M F'), findsNothing);
  });

  testWidgets('107 connecté : mon impact calculé sur mes achats, et le graphique mensuel', (t) async {
    final mine = <String, dynamic>{'purchases': 3, 'amount': 45000, 'students_supported': 2, 'recycled_kg': 4.0, 'months': [{'month': '2026-10', 'recycled_kg': 1.5}, {'month': '2026-11', 'recycled_kg': 2.5}]};
    await monter(t, const G_107(), connecte: true, login: true, overrides: [myImpactProvider.overrideWith(() => _Rpc('my_impact', mine))]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4 kg'), findsOneWidget);
    expect(find.text('48 kg'), findsNothing);
  });

  testWidgets('105 connecté : créations d’un autre établissement, état vide sinon', (t) async {
    await monter(t, const G_105(), connecte: true, overrides: [otherListingsProvider.overrideWith(() => _Autres(const []))]);
    expect(find.text('Tablette solaire'), findsNothing);
    expect(find.textContaining('Aucune création d’un autre établissement'), findsOneWidget);
  });

  testWidgets('105 connecté : la liste réelle avec l’établissement du vendeur', (t) async {
    await monter(t, const G_105(), connecte: true, overrides: [otherListingsProvider.overrideWith(() => _Autres([{'title': 'Séchoir réel', 'institution': 'IUT de Bandjoun', 'price': 12000}]))]);
    expect(find.text('Séchoir réel'), findsOneWidget);
    expect(find.text('IUT de Bandjoun'), findsOneWidget);
  });

  testWidgets('239 connecté : rapport de sponsoring réel', (t) async {
    final rapport = <String, dynamic>{'sponsor': 'Sponsor Test', 'total': 750000, 'students': 6, 'projects': [{'title': 'Projet réel', 'department': 'Informatique', 'amount': 500000, 'students': 4, 'outcome': 'Prototype livré', 'status': 'termine', 'year': 2026}]};
    await monter(t, const G_239(), connecte: true, login: true, size: const Size(1280, 866), overrides: [sponsorReportProvider.overrideWith(() => _Sponsor(rapport))]);
    expect(find.text('Projet réel'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('Serre intelligente'), findsNothing);
  });

  testWidgets('239 connecté sans sponsoring : état vide', (t) async {
    await monter(t, const G_239(), connecte: true, login: true, size: const Size(1280, 866), overrides: [sponsorReportProvider.overrideWith(() => _Sponsor(const {}))]);
    expect(find.textContaining('Aucun sponsoring enregistré'), findsOneWidget);
  });

  for (final c in <(String, Widget, String, Size)>[
    ('105', const G_105(), 'Tablette solaire', Size(393, 852)),
    ('107', const G_107(), '48 kg', Size(393, 852)),
    ('238', const G_238(), 'Ensemble, nous faisons grandir le Cameroun', Size(393, 852)),
    ('237', const G_237(), '48,2 M F', Size(1280, 820)),
    ('239', const G_239(), 'Serre intelligente', Size(1280, 866)),
  ]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false, size: c.$4);
      expect(find.text(c.$3), findsOneWidget);
    });
  }
}
