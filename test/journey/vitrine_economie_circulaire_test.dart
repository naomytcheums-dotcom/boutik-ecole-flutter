import 'package:boutik_ecole/figma/g/g_102.dart';
import 'package:boutik_ecole/figma/g/g_103.dart';
import 'package:boutik_ecole/figma/g/g_106.dart';
import 'package:boutik_ecole/figma/live/home_live.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/produits_liste.dart';
import 'package:boutik_ecole/figma/live/seller.dart' show allProductsProvider, Listing, PlatformListings, platformListingsProvider;
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

const _lampe = LiveProduct('Lampe en bois recyclé', 'Génie civil', 25000, 'Alice', 'Lampe fabriquée à partir de bois de récupération.', 'placeholder', id: 'a');
const _sac = LiveProduct('Sac à dos', 'Design', 18000, 'Bruno', 'Sac neuf en toile.', 'placeholder', id: 'b');
const _bocal = LiveProduct('Bocal en verre', 'Design', 5000, 'Carla', 'Bocal simple.', 'placeholder', id: 'c');

class _Membres extends TalentsNotifier {
  _Membres(this.v);
  final List<LiveTalent>? v;
  @override
  List<LiveTalent>? build() => v;
}

/// Première lecture des produits de la plateforme réussie (liste vide) ou jamais aboutie (null).
class _Lecture extends PlatformListings {
  _Lecture(this.v);
  final List<Listing>? v;
  @override
  List<Listing>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<LiveProduct> produits = const [], List<String> alHonneur = const [], Set<String> recycles = const {}, bool lecture = true}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        allProductsProvider.overrideWithValue(produits),
        platformListingsProvider.overrideWith(() => _Lecture(lecture ? const <Listing>[] : null)),
        showcaseIdsProvider.overrideWith((ref) async => alHonneur),
        recycledIdsProvider.overrideWith((ref) async => recycles),
      ],
      child: MaterialApp(home: ecran),
    ));
    await t.pumpAndSettle();
  }

  test('reconnaissance des produits de récupération', () {
    expect(isRecycled(_lampe), isTrue);
    expect(isRecycled(_sac), isFalse);
  });

  testWidgets('106 connecté sans produit : aucun produit ni message de maquette, état vide clair', (t) async {
    await monter(t, const G_106(), connecte: true);
    expect(find.text('Sac en bâche recyclée'), findsNothing);
    expect(find.textContaining('Aucune création en matériaux récupérés'), findsOneWidget);
  });

  testWidgets('106 connecté : seuls les produits déclarés récupérés par leur vendeur sont affichés', (t) async {
    await monter(t, const G_106(), connecte: true, produits: [_lampe, _sac], recycles: {'a'});
    expect(find.text('Lampe en bois recyclé'), findsOneWidget);
    expect(find.text('Sac à dos'), findsNothing);
  });

  testWidgets('106 connecté : une annonce dont le texte évoque la récupération mais non déclarée n’est pas affichée (S5-66)', (t) async {
    await monter(t, const G_106(), connecte: true, produits: [_lampe, _sac, _bocal], recycles: {'c'});
    expect(find.text('Bocal en verre'), findsOneWidget);
    expect(find.text('Lampe en bois recyclé'), findsNothing);
    expect(find.text('Sac à dos'), findsNothing);
  });

  testWidgets('102 connecté : compteurs réels, aucun lancement ni collection inventés, seules les pièces à l’honneur du serveur sont mises en avant', (t) async {
    await monter(t, const G_102(), connecte: true, produits: [_lampe, _sac], alHonneur: ['b']);
    expect(find.text('Lancement officiel le 24 octobre'), findsNothing);
    expect(find.text('Collection « Recyclé & Design »'), findsNothing);
    expect(find.text('2'), findsNWidgets(3), reason: '2 pièces, 2 créateurs, 2 départements');
    expect(find.text('Sac à dos'), findsOneWidget);
    expect(find.text('Lampe en bois recyclé'), findsNothing);
  });

  testWidgets('102 connecté sans produit : état vide', (t) async {
    await monter(t, const G_102(), connecte: true);
    expect(find.textContaining('Aucune pièce à l’honneur'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('102 connecté, lecture des produits non aboutie : « — » et jamais 0', (t) async {
    await monter(t, const G_102(), connecte: true, lecture: false);
    expect(find.text('0'), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('102 et 106 hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_102(), connecte: false);
    expect(find.text('Lancement officiel le 24 octobre'), findsOneWidget);
    await monter(t, const G_106(), connecte: false);
    expect(find.text('Sac en bâche recyclée'), findsOneWidget);
  });

  Future<void> monter103(WidgetTester t, List<LiveTalent> membres) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [liveTalentsProvider.overrideWith(() => _Membres(membres))], child: const MaterialApp(home: G_103())));
    await t.pumpAndSettle();
  }

  testWidgets('103 connecté sans membre : aucun ancien inventé, état vide', (t) async {
    await monter103(t, const []);
    expect(find.text('Rodrigue Fotso'), findsNothing);
    expect(find.textContaining('Aucun membre à présenter'), findsOneWidget);
  });

  testWidgets('103 connecté : les membres réels s’affichent avec l’accès à leur profil', (t) async {
    await monter103(t, const [LiveTalent(id: 'u1', name: 'Alice Test', department: 'Informatique', skills: 'Flutter', avatarUrl: '', certified: true)]);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Voir le profil'), findsOneWidget);
    expect(find.text('Rodrigue Fotso'), findsNothing);
  });

  testWidgets('103 hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_103(), connecte: false);
    expect(find.text('Rodrigue Fotso'), findsOneWidget);
  });
}
