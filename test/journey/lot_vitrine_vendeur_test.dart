import 'package:boutik_ecole/figma/g/g_04.dart';
import 'package:boutik_ecole/figma/g/g_115.dart';
import 'package:boutik_ecole/figma/g/g_172.dart';
import 'package:boutik_ecole/figma/g/g_187.dart';
import 'package:boutik_ecole/figma/g/g_20.dart';
import 'package:boutik_ecole/figma/g/g_212.dart';
import 'package:boutik_ecole/figma/g/g_22c.dart';
import 'package:boutik_ecole/figma/g/g_22d.dart';
import 'package:boutik_ecole/figma/g/g_24.dart';
import 'package:boutik_ecole/figma/g/g_38.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/vendeur_public.dart';
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

class _Seller extends SellerPublic {
  _Seller(this.v);
  final Map<String, dynamic>? v;
  @override
  Map<String, dynamic>? build() => v;
}

const _seller = {
  'found': true, 'name': 'Alice Test', 'department': 'GI', 'institution': 'IUT Test', 'verified': true, 'since': '2025-03-01T10:00:00Z',
  'products': 3, 'services': 1, 'sales': 7, 'rating_count': 4, 'rating_avg': 4.5, 'stars': {'5': 2, '4': 2},
};

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

  final sellerOv = [sellerPublicProvider.overrideWith(() => _Seller(_seller))];

  testWidgets('24 connecté : profil du vendeur calculé', (t) async {
    await monter(t, const G_24(), connecte: true, overrides: sellerOv);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Produits'), findsWidgets);
    expect(find.text('Atelier Krea’Tech'), findsNothing);
  });

  testWidgets('38 connecté : réputation réelle', (t) async {
    await monter(t, const G_38(), connecte: true, overrides: sellerOv);
    expect(find.text('4.5 / 5'), findsOneWidget);
    expect(find.text('Produit de très bonne qualité !'), findsNothing);
  });

  testWidgets('172 connecté : confiance établie sur l’activité', (t) async {
    await monter(t, const G_172(), connecte: true, overrides: sellerOv);
    expect(find.textContaining('7 commandes payées'), findsOneWidget);
    expect(find.text('98 % de commandes livrées à temps'), findsNothing);
  });

  testWidgets('172 connecté, vendeur introuvable : message honnête', (t) async {
    await monter(t, const G_172(), connecte: true, overrides: [sellerPublicProvider.overrideWith(() => _Seller({'found': false}))]);
    expect(find.textContaining('Aucun profil public trouvé'), findsOneWidget);
  });

  testWidgets('212 connecté : champ de vérification, aucun résultat de maquette', (t) async {
    await monter(t, const G_212(), connecte: true);
    expect(find.text('Entrez le code du certificat'), findsOneWidget);
    expect(find.text('BE-CERT-0021'), findsNothing);
  });

  testWidgets('04, 20, 22c, 22d connectés : plus de lignes de maquette', (t) async {
    await monter(t, const G_04(), connecte: true);
    expect(find.text('Département : Agronomie'), findsNothing);
    await monter(t, const G_20(), connecte: true);
    expect(find.text('128 résultats'), findsNothing);
  });

  testWidgets('22c connecté', (t) async {
    await monter(t, const G_22c(), connecte: true);
    expect(find.text('Coups de cœur de la semaine'), findsNothing);
  });

  testWidgets('22d connecté', (t) async {
    await monter(t, const G_22d(), connecte: true);
    expect(find.text('Brice Ndoumbe'), findsNothing);
  });

  testWidgets('115 connecté : plus d’événement de maquette', (t) async {
    await monter(t, const G_115(), connecte: true, large: true);
    expect(find.text('Exposition des innovations'), findsNothing);
  });

  testWidgets('187 connecté : besoins réels de l’entreprise', (t) async {
    await monter(t, const G_187(), connecte: true, large: true, overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'title': 'Besoin Test', 'proposals': 2, 'status': 'published', 'created_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Besoin Test'), findsOneWidget);
    expect(find.text('Borne solaire'), findsNothing);
  });

  for (final c in <(String, Widget, String, bool)>[
    ('24', const G_24(), 'Atelier Krea’Tech', false),
    ('38', const G_38(), 'Produit de très bonne qualité !', false),
    ('172', const G_172(), '98 % de commandes livrées à temps', false),
    ('212', const G_212(), 'Lampe en bois recyclé', false),
    ('115', const G_115(), 'Exposition des innovations', true),
    ('187', const G_187(), 'Borne solaire', true),
  ]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false, large: c.$4);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
