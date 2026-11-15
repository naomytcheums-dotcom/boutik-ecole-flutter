import 'package:boutik_ecole/figma/g/g_100.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/evenements.dart';
import 'package:boutik_ecole/figma/live/store.dart' show fcfa, nowProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Events extends EventsNotifier {
  _Events(this.v);
  final List<AppEvent>? v;
  @override
  List<AppEvent>? build() => v;
}

AppEvent _event({int price = 5000, int? capacity = 10, int registered = 0, int held = 0, bool mine = false, String? myStatus, String? paymentStatus}) => AppEvent(
      id: 'e1',
      title: 'Atelier payant',
      kind: 'atelier',
      startsAt: DateTime(2026, 11, 6, 15),
      place: 'Salle B2',
      price: price,
      capacity: capacity,
      registered: registered,
      held: held,
      mine: mine,
      myStatus: myStatus,
      paymentStatus: paymentStatus,
    );

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  final now = DateTime(2026, 11, 5, 10);

  Future<void> monter(WidgetTester t, AppEvent e) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [nowProvider.overrideWithValue(now), eventsProvider.overrideWith(() => _Events([e]))],
      child: const MaterialApp(home: G_100()),
    ));
    await t.pumpAndSettle();
  }

  test('lecture du serveur : état de paiement et places retenues', () {
    final e = AppEvent.fromRow({
      'id': 'x',
      'title': 'Salon',
      'kind': 'salon',
      'starts_at': '2026-11-06T14:00:00Z',
      'place': '',
      'price': 3000,
      'capacity': 5,
      'registered': 2,
      'held': 1,
      'mine': false,
      'my_status': 'pending_payment',
      'payment_status': 'pending',
    });
    expect(e.paid, isTrue);
    expect(e.pending, isTrue);
    expect(e.mine, isFalse);
    expect(e.left, 2);
    expect(_event(capacity: 2, registered: 1, held: 1).full, isTrue);
    expect(_event(price: 0).paid, isFalse);
    expect(AppEvent.fromRow({'id': 'y', 'title': 'Ancien', 'kind': 'autre', 'starts_at': '2026-11-06T14:00:00Z'}).myStatus, isNull);
  });

  testWidgets('payant non inscrit : « Payer et s’inscrire », places moins les places retenues', (t) async {
    await monter(t, _event(registered: 2, held: 3));
    expect(find.text('Payer et s’inscrire'), findsOneWidget);
    expect(find.text('${fcfa(5000)} · 5 places'), findsOneWidget);
    expect(find.text('Inscription'), findsNothing);
  });

  testWidgets('payant : en attente de confirmation', (t) async {
    await monter(t, _event(myStatus: 'pending_payment', paymentStatus: 'pending', held: 1));
    expect(find.text('Paiement en attente'), findsOneWidget);
    expect(find.text('Inscrit(e)'), findsNothing);
  });

  testWidgets('payant : paiement échoué, à refaire', (t) async {
    await monter(t, _event(myStatus: 'pending_payment', paymentStatus: 'failed', held: 1));
    expect(find.text('Paiement à refaire'), findsOneWidget);
  });

  testWidgets('payant : inscrit(e) seulement après confirmation du serveur', (t) async {
    await monter(t, _event(mine: true, myStatus: 'confirmed', registered: 1));
    expect(find.text('Inscrit(e)'), findsOneWidget);
    expect(find.text('Payer et s’inscrire'), findsNothing);
  });

  testWidgets('payant complet : « Complet », pas de paiement possible', (t) async {
    await monter(t, _event(capacity: 2, registered: 1, held: 1));
    expect(find.text('Complet'), findsOneWidget);
    expect(find.text('Payer et s’inscrire'), findsNothing);
  });

  testWidgets('gratuit : le libellé « Inscription » est inchangé', (t) async {
    await monter(t, _event(price: 0));
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.text('Payer et s’inscrire'), findsNothing);
  });

  testWidgets('détail d’un événement payant : bouton avec le prix, paiement par messagerie, plus de promesse d’inscription sans paiement', (t) async {
    await monter(t, _event());
    await t.tap(find.text('Atelier payant').last);
    await t.pumpAndSettle();
    expect(find.text('Payer et s’inscrire (${fcfa(5000)})'), findsOneWidget);
    expect(find.text('Payer par messagerie'), findsOneWidget);
    expect(find.textContaining('pas encore pris en charge'), findsNothing);
    expect(find.textContaining('réservée 30 minutes'), findsOneWidget);
  });

  testWidgets('détail : paiement en attente de confirmation, reprise sans second paiement par messagerie', (t) async {
    await monter(t, _event(myStatus: 'pending_payment', paymentStatus: 'pending', held: 1));
    await t.tap(find.text('Atelier payant').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Paiement en attente de confirmation'), findsOneWidget);
    expect(find.text('Reprendre le paiement (${fcfa(5000)})'), findsOneWidget);
    expect(find.text('Payer par messagerie'), findsNothing);
  });

  testWidgets('détail : inscription payée, pas d’annulation directe', (t) async {
    await monter(t, _event(mine: true, myStatus: 'confirmed', registered: 1));
    await t.tap(find.text('Atelier payant').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Inscription payée'), findsOneWidget);
    expect(find.text('Annuler mon inscription'), findsNothing);
  });
}

