import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/feedback.dart';
import 'package:boutik_ecole/figma/live/opportunites_screens.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H8 · panne serveur (HTTP 500) sur les cinq formulaires d'écriture principaux, en connecté : message honnête, aucune confirmation de succès,
/// saisie et données conservées.
Account _compte() => Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', bio: 'avant', serverId: FakeSupabase.userId);

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failWrites = true;
    srv.failRpc.clear();
    srv.tables['profiles'] = [
      {'id': FakeSupabase.userId, 'name': 'Nina Test', 'role': 'client', 'email': 'nina@example.com', 'suspended': false, 'created_at': '2026-01-01T00:00:00Z'},
    ];
  });
  tearDown(() {
    srv.failWrites = false;
    srv.failRpc.clear();
    GScreen.mockupFrame = true;
  });

  late ProviderContainer container;
  Future<void> host(WidgetTester t, Map<String, void Function(BuildContext, WidgetRef)> actions, {Widget? body}) async {
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(_compte())],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return Scaffold(body: body ?? Column(children: [for (final e in actions.entries) TextButton(onPressed: () => e.value(context, ref), child: Text(e.key))]));
        }),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> settle(WidgetTester t) => settleReal(t, rounds: 6, ms: 40);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  testWidgets('profil : 500 → « Profil non enregistré », aucune confirmation, compte inchangé', (t) async {
    await host(t, {'modifier': (c, r) => editProfileDialog(c, r)});
    await t.tap(find.text('modifier'));
    await settle(t);
    await t.enterText(find.byType(TextField).at(0), 'Nouvelle description');
    await t.tap(find.text('Enregistrer'));
    await settle(t);
    expect(find.text('Profil non enregistré'), findsOneWidget);
    expect(find.text('Profil enregistré'), findsNothing);
    expect(container.read(authProvider).current!.bio, 'avant');
    expect(srv.calls.any((c) => c.kind == 'write' && c.name == 'profiles'), isTrue);
    await fin(t);
  });

  testWidgets('produit : 500 → erreur renvoyée, aucune annonce ajoutée, formulaire conservé', (t) async {
    await host(t, {'x': (c, r) {}});
    container.read(formProvider.notifier).put('np_title', 'Lampe test');
    final err = await t.runAsync(() => container.read(listingsProvider.notifier).create(const Listing(title: 'Lampe test', category: 'Maison', price: 5000, stock: 3), submit: false));
    expect(err, isNotNull);
    expect(err, isNotEmpty);
    expect(container.read(listingsProvider).where((l) => l.title == 'Lampe test'), isEmpty);
    expect(container.read(listingsProvider.notifier).lastCreated, isNull);
    expect(container.read(formProvider)['np_title'], 'Lampe test');
    await fin(t);
  });

  testWidgets('avis : 500 → message dans la boîte, commentaire conservé, aucun « Merci »', (t) async {
    srv.failRpc.add('submit_review');
    srv.tables['orders'] = [
      {'number': 'BE-H8-1', 'status': 3, 'paid': true, 'cancelled': false, 'method': 'orange_money', 'subtotal': 5000, 'fee': 0, 'reference': 'R', 'created_at': '2026-11-01T10:00:00Z', 'order_lines': [{'title': 'Lampe', 'qty': 1, 'unit_price': 5000, 'fulfillment': 3}]},
    ];
    await host(t, {'avis': (c, r) => reviewOrderDialog(c, r)});
    container.read(selectedOrderIdProvider.notifier).set('BE-H8-1');
    await t.tap(find.text('avis'));
    await settle(t);
    expect(find.text('Évaluer votre commande'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'Très bien');
    await t.tap(find.text('Publier mon avis'));
    await settle(t);
    expect(srv.callsOf('submit_review'), isNotEmpty);
    expect(find.textContaining('Avis non enregistré'), findsOneWidget);
    expect(find.text('Très bien'), findsOneWidget);
    expect(find.text('Merci ! Votre avis a été publié.'), findsNothing);
    await fin(t);
  });

  testWidgets('réclamation : 500 → « Réclamation non envoyée », texte conservé, aucune confirmation', (t) async {
    srv.failRpc.add('submit_claim');
    srv.tables['orders'] = [
      {'number': 'BE-H8-1', 'status': 3, 'paid': true, 'cancelled': false, 'method': 'orange_money', 'subtotal': 5000, 'fee': 0, 'reference': 'R', 'created_at': '2026-11-01T10:00:00Z', 'order_lines': [{'title': 'Lampe', 'qty': 1, 'unit_price': 5000, 'fulfillment': 3}]},
    ];
    await host(t, {'reclamer': (c, r) => submitClaimForm(c, r)});
    container.read(selectedOrderIdProvider.notifier).set('BE-H8-1');
    container.read(formProvider.notifier).put('claim_details', 'Article cassé à la livraison');
    await t.tap(find.text('reclamer'));
    await settle(t);
    expect(srv.callsOf('submit_claim'), isNotEmpty);
    expect(find.text('Réclamation non envoyée'), findsOneWidget);
    expect(find.textContaining('Réclamation envoyée'), findsNothing);
    expect(container.read(formProvider)['claim_details'], 'Article cassé à la livraison');
    await fin(t);
  });

  testWidgets('candidature : 500 → message, lettre conservée dans la feuille, aucune confirmation ni écran de succès', (t) async {
    srv.failRpc.add('opp_apply');
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        initialAccountProvider.overrideWithValue(_compte()),
        oppDetailProvider('1').overrideWith((ref) async => {
              'id': '1',
              'org': 'Orange Cameroun',
              'verified': true,
              'kind': 'stage',
              'contract': 'académique',
              'title': 'Stagiaire Flutter',
              'location': 'Douala',
              'mode': 'hybrid',
              'duration': '3 mois',
              'pay_kind': 'paid',
              'pay_amount': 50000,
              'pay_note': '',
              'deadline': '2099-01-01',
              'skills': ['Flutter'],
              'iut_only': false,
              'saved': false,
              'applied': false,
              'status': 'published',
              'description': 'Description',
              'missions': [],
              'gains': [],
              'apply_whatsapp': '',
              'apply_in_app': true,
              'mine': false,
              'my_application': null,
              'other_offers': [],
            }),
      ],
      child: const MaterialApp(home: OpportunityDetailScreen(id: '1')),
    ));
    await settle(t);
    await t.tap(find.text('Postuler dans l’application'));
    await settle(t);
    const lettre = 'Je suis très motivée par ce stage.';
    await t.enterText(find.byType(TextField).first, lettre);
    await t.tap(find.text('Envoyer'));
    await settle(t);
    expect(srv.callsOf('opp_apply'), isNotEmpty);
    expect(find.text(lettre), findsOneWidget, reason: 'la lettre saisie reste à l’écran');
    expect(find.text('Lettre de motivation'), findsOneWidget);
    expect(find.textContaining('Candidature envoyée'), findsNothing);
    expect(srv.callsOf('opp_my_match'), isEmpty, reason: 'aucun écran de succès : rien n’a été enregistré');
    await fin(t);
  });
}
