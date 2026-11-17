import 'package:boutik_ecole/figma/g/g_57.dart';
import 'package:boutik_ecole/figma/g/g_58.dart';
import 'package:boutik_ecole/figma/g/g_59.dart';
import 'package:boutik_ecole/figma/g/g_60.dart';
import 'package:boutik_ecole/figma/g/g_61.dart';
import 'package:boutik_ecole/figma/g/g_62.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/review.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/seller_live.dart';
import 'package:boutik_ecole/figma/live/store.dart' show StrV, fcfa;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot G2 (annonces, boutique, stock, modération) à 390 px, connecté : chiffres réels, états de chargement / vide / erreur,
/// motif de refus visible, zones tactiles d'au moins 48 dp, aucun débordement.

class _Listings extends Listings {
  _Listings(this.v);
  final List<Listing> v;
  @override
  List<Listing> build() => v;
  @override
  Future<void> refresh() async {}
}

class _Load extends StrV {
  _Load(this.v);
  final String v;
  @override
  String build() => v;
}

const _ov = {
  'revenue': 45000,
  'orders': 3,
  'pending_orders': 2,
  'listings': {'approved': 4, 'pending': 1, 'draft': 2},
  'months': <Object>[],
};

const _refused = Listing(id: 'l1', title: 'Lampe refusée', category: 'Maison', price: 25000, stock: 3, published: false, status: 'rejected', note: 'Photo floue : refaites-la');
const _live = Listing(id: 'l2', title: 'Sac publié', category: 'Mode', price: 12000, stock: 8, status: 'approved');

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  List<Override> base({List<Listing> listings = const [_refused, _live], String load = 'ok', bool overviewOk = true}) => [
        listingsProvider.overrideWith(() => _Listings(listings)),
        listingsLoadProvider.overrideWith(() => _Load(load)),
        sellerOverviewProvider.overrideWith((ref) async {
          if (!overviewOk) throw StateError('seller_overview');
          return Map<String, dynamic>.from(_ov);
        }),
        sellerShopProvider.overrideWith((ref) async => <String, dynamic>{}),
      ];

  Future<void> monter(WidgetTester t, Widget ecran, List<Override> overrides, {bool settle = true}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 846);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  group('catalogue (61)', () {
    testWidgets('première lecture : indicateur de chargement, pas de « Aucune annonce »', (t) async {
      await monter(t, const G_61(), base(listings: const [], load: ''), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Aucune annonce pour le moment'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('lecture impossible : message d\'erreur et « Réessayer », jamais « Aucune annonce »', (t) async {
      await monter(t, const G_61(), base(listings: const [], load: 'error'));
      expect(find.textContaining('Impossible de lire vos annonces'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucune annonce pour le moment'), findsNothing);
      expect(t.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('lecture réussie sans annonce : invitation à créer la première', (t) async {
      await monter(t, const G_61(), base(listings: const []));
      expect(find.textContaining('Aucune annonce pour le moment'), findsOneWidget);
    });

    testWidgets('annonce refusée : statut et motif du département visibles ; une liste périmée est signalée', (t) async {
      await monter(t, const G_61(), base(load: 'error'));
      expect(find.text('Refusée'), findsOneWidget);
      expect(find.textContaining('Motif du refus : Photo floue'), findsOneWidget);
      expect(find.textContaining('Actualisation impossible'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('stocks (62)', () {
    testWidgets('lecture impossible : message et « Réessayer »', (t) async {
      await monter(t, const G_62(), base(listings: const [], load: 'error'));
      expect(find.textContaining('Impossible de lire vos annonces'), findsOneWidget);
      expect(find.textContaining('Aucun produit à gérer'), findsNothing);
    });

    testWidgets('stocks réels, sans débordement', (t) async {
      await monter(t, const G_62(), base());
      expect(find.text('Sac publié'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('tableau de bord (57)', () {
    testWidgets('chiffres du serveur, aucun chiffre de maquette', (t) async {
      await monter(t, const G_57(), base());
      expect(find.text(fcfa(45000).replaceAll(' FCFA', '')), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('4'), findsWidgets);
      expect(find.textContaining('1 245 000'), findsNothing);
      expect(find.textContaining('+12 %'), findsNothing);
      expect(find.textContaining('4 paiements'), findsNothing);
      expect(find.textContaining('1 en validation · 2 brouillon(s)'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('lecture impossible : « — » et « Réessayer » sur le graphique', (t) async {
      await monter(t, const G_57(), base(overviewOk: false));
      expect(find.text('—'), findsWidgets);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('modération (département)', () {
    testWidgets('le valideur voit description, stock, département et le motif du refus précédent, sans débordement', (t) async {
      t.view.physicalSize = const Size(390, 846);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Backend.ready = true;
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            return Scaffold(body: TextButton(onPressed: () => reviewDialog(context, ref, const ReviewItem('Lampe', 'Mariam K.', 'Maison', 25000, 'il y a 2 h', seed: false, id: 'x', status: 'rejected', note: 'Photo floue', description: 'Lampe en bois recyclé', stock: 4, department: 'Génie civil')), child: const Text('ouvrir')));
          }),
        ),
      ));
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      expect(find.textContaining('Vendeur : Mariam K.'), findsOneWidget);
      expect(find.textContaining('Stock : 4'), findsOneWidget);
      expect(find.textContaining('Département : Génie civil'), findsOneWidget);
      expect(find.text('Lampe en bois recyclé'), findsOneWidget);
      expect(find.textContaining('Motif du refus précédent : Photo floue'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('zones tactiles >= 48 dp, connecté, 390 px', () {
    final ecrans = <String, Widget>{'57': const G_57(), '58': const G_58(), '59': const G_59(), '60': const G_60(), '61': const G_61(), '62': const G_62()};
    for (final e in ecrans.entries) {
      testWidgets('écran ${e.key}', (t) async {
        final handle = t.ensureSemantics();
        await monter(t, e.value, base());
        final petites = <String>[];
        void walk(SemanticsNode n) {
          final d = n.getSemanticsData();
          final tappable = d.hasAction(SemanticsAction.tap) || d.hasAction(SemanticsAction.longPress);
          final rect = n.rect;
          if (tappable && (rect.width < 47.5 || rect.height < 47.5)) petites.add('${rect.width.toStringAsFixed(0)}x${rect.height.toStringAsFixed(0)} « ${d.label} »');
          n.visitChildren((c) {
            walk(c);
            return true;
          });
        }

        walk(t.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
        handle.dispose();
        expect(petites, isEmpty);
        expect(t.takeException(), isNull);
      });
    }
  });
}
