import 'package:boutik_ecole/figma/g/g_150_1.dart';
import 'package:boutik_ecole/figma/g/g_275.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:boutik_ecole/figma/live/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot 1 (phase 3) : écrans d'état 150-4, 275 et 150-1 affichés quand l'état se produit réellement.

class _Sync extends SyncNotifier {
  _Sync(this.report);
  final SyncReport report;
  @override
  SyncReport build() => report;
}

Future<void> _pump(WidgetTester tester, Widget screen, ProviderContainer c) async {
  GAnim.enabled = false;
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: Scaffold(body: screen))));
  await tester.pump();
}

const _order = Order(id: '#BE-2026-0161', date: '30 oct. 2026', lines: [], subtotal: 1000, fee: 0, method: '', reference: '');

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  group('150-4 « Mes commandes (vide) »', () {
    test('affiché seulement si le serveur a répondu et qu\'il n\'y a réellement aucune commande', () {
      expect(showEmptyOrders(ready: true, loaded: true, orders: const []), isTrue);
      expect(showEmptyOrders(ready: true, loaded: false, orders: const []), isFalse, reason: 'lecture pas encore aboutie ou échouée');
      expect(showEmptyOrders(ready: true, loaded: true, orders: const [_order]), isFalse);
      expect(showEmptyOrders(ready: false, loaded: true, orders: const []), isFalse, reason: 'hors serveur : maquette 45');
    });

    test('une lecture impossible n\'est jamais confondue avec « aucune commande »', () async {
      expect(await Backend.myOrders(), isNull);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(ordersProvider.notifier).refresh();
      expect(c.read(ordersLoadedProvider), isFalse);
    });
  });

  group('275 « Déposer un produit (erreurs) »', () {
    testWidgets('erreurs réelles de 58 : valeurs saisies, messages réels, aucun faux « brouillon enregistré »', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(formProvider.notifier).put('np_title', 'Ta');
      c.read(formProvider.notifier).put('np_price', '200');
      c.read(errorsProvider.notifier).setAll({'np_title': 'Le titre est obligatoire (3 à 80 caractères).', 'np_price': 'Prix : minimum 500.'});
      await _pump(tester, const G_275(), c);
      expect(find.text('Nouveau produit · corrections'), findsOneWidget);
      expect(find.text('Ta'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('Prix : minimum 500.'), findsOneWidget);
      expect(find.text('2 champs à corriger avant de continuer. Rien n’a été enregistré.'), findsOneWidget);
      expect(find.textContaining('brouillon est enregistré'), findsNothing);
      expect(find.textContaining('image-trop-lourde'), findsNothing);
      expect(find.text('Mobilier · Bois recyclé'), findsNothing);
    });

    testWidgets('sans erreur réelle : la maquette (catalogue des écrans, golden image)', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await _pump(tester, const G_275(), c);
      expect(find.text('Étape 2 sur 4 · Informations'), findsOneWidget);
      expect(find.text('3 champs à corriger avant de continuer. Votre brouillon est enregistré.'), findsOneWidget);
    });

    test('récapitulatif : nombre réel de champs en erreur', () {
      expect(newProductErrorsSummary({'np_stock': 'x'}), '1 champ à corriger avant de continuer. Rien n’a été enregistré.');
      expect(newProductErrorsSummary({'np_title': 'x', 'np_cat': 'y', 'np_stock': 'z', 'autre': 'w'}), startsWith('3 champs'));
    });
  });

  group('150-1 « Synchronisation »', () {
    testWidgets('connecté : résultat réel de la resynchronisation, jamais « 72 % » ni « 10:24 »', (tester) async {
      Backend.ready = true;
      final c = ProviderContainer(overrides: [syncProvider.overrideWith(() => _Sync(SyncReport(at: DateTime.now(), favorites: true, messages: false, orders: true)))]);
      addTearDown(c.dispose);
      await _pump(tester, const G_150_1(), c);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('2 éléments sur 3 à jour'), findsOneWidget);
      expect(find.text('Synchronisation incomplète'), findsOneWidget);
      expect(find.text('Échec de la lecture'), findsOneWidget);
      expect(find.text('Perturbé'), findsOneWidget);
      expect(find.text('Jamais'), findsOneWidget, reason: 'aucune resynchronisation complète réussie');
      expect(find.text('72%'), findsNothing);
      expect(find.text('Aujourd’hui 10:24'), findsNothing);
    });

    testWidgets('hors serveur : la maquette', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await _pump(tester, const G_150_1(), c);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('Aujourd’hui 10:24'), findsOneWidget);
    });

    test('sans serveur, la resynchronisation n\'annonce aucun succès', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final r = await c.read(syncProvider.notifier).run();
      expect(r.allOk, isFalse);
      expect(r.favorites, isFalse);
      expect(r.messages, isFalse);
      expect(c.read(lastSyncProvider), isNull);
    });

    test('heure de dernière synchronisation', () {
      final now = DateTime(2026, 11, 1, 9, 30);
      expect(syncTime(null, now), 'Jamais');
      expect(syncTime(DateTime(2026, 11, 1, 8, 5), now), 'Aujourd’hui 08:05');
      expect(syncTime(DateTime(2026, 10, 31, 18, 5), now), '31/10 18:05');
      expect(const SyncReport(favorites: true, messages: true, orders: true).percent, 100);
      expect(const SyncReport().upToDate, 1);
    });
  });
}
