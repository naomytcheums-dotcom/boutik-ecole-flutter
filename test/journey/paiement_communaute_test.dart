import 'package:boutik_ecole/figma/g/g_17.dart';
import 'package:boutik_ecole/figma/g/g_43.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/communities.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/decisions.dart';
import 'package:boutik_ecole/figma/live/paiement_messagerie.dart';
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

class _Thread extends PaymentThread {
  _Thread(this.v);
  final Map<String, dynamic> v;
  @override
  Map<String, dynamic>? build() => v;
}

class _Sel extends SelectedPayment {
  @override
  String? build() => 'p1';
}

class _Feed extends CommunityFeed {
  _Feed(this.v);
  final List<Map<String, dynamic>> v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

class _SelC extends SelectedCommunity {
  _SelC(this.c);
  final Community c;
  @override
  Community? build() => c;
}

Map<String, dynamic> _thread(String status) => {
      'id': 'p1', 'reference': 'PAY-10001', 'amount': 25000, 'status': status, 'provider': 'manual', 'subject': 'Commande BE-1', 'provider_ref': null,
      'messages': [
        {'sender': 'system', 'body': 'Demande de paiement PAY-10001 : 25000 FCFA', 'created_at': '2026-11-05T10:00:00Z'},
        {'sender': 'payer', 'body': 'J’ai payé. Référence : MP240101.1234', 'created_at': '2026-11-05T10:05:00Z'},
        {'sender': 'finance', 'body': 'Paiement confirmé. Merci !', 'created_at': '2026-11-05T10:20:00Z'},
      ],
    };

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {bool connecte = true, List<Override> overrides = const [], bool login = true}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte && login) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés des états de paiement', () {
    expect(paymentStatusLabel('pending'), 'En attente de vérification');
    expect(paymentStatusLabel('confirmed'), 'Confirmé');
    expect(paymentStatusLabel('created'), 'À payer');
  });

  testWidgets('289 : le fil montre les messages et le champ de déclaration tant que le paiement n’est pas déclaré', (t) async {
    await monter(t, const PaymentChatScreen(), overrides: [selectedPaymentProvider.overrideWith(_Sel.new), paymentThreadProvider.overrideWith(() => _Thread(_thread('created')))]);
    expect(find.text('Demande de paiement PAY-10001 : 25000 FCFA'), findsOneWidget);
    expect(find.text('J’ai payé'), findsOneWidget);
    expect(find.text('À payer'), findsOneWidget);
  });

  testWidgets('289 : paiement confirmé, plus de champ de saisie', (t) async {
    await monter(t, const PaymentChatScreen(), overrides: [selectedPaymentProvider.overrideWith(_Sel.new), paymentThreadProvider.overrideWith(() => _Thread(_thread('confirmed')))]);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('J’ai payé'), findsNothing);
    expect(find.text('Paiement confirmé.'), findsOneWidget);
  });

  testWidgets('289 sans paiement ouvert : message clair', (t) async {
    await monter(t, const PaymentChatScreen());
    expect(find.textContaining('Aucun paiement ouvert'), findsOneWidget);
  });

  testWidgets('290 : mes paiements réels', (t) async {
    await monter(t, const MyPaymentsScreen(), overrides: [
      myPaymentsProvider.overrideWith(() => _Rows('my_payments', [
            {'id': 'p1', 'reference': 'PAY-10001', 'amount': 25000, 'status': 'pending', 'subject': 'Commande BE-1', 'created_at': '2026-11-05T10:00:00Z'}
          ]))
    ]);
    expect(find.textContaining('PAY-10001'), findsOneWidget);
    expect(find.text('En attente de vérification'), findsOneWidget);
  });

  testWidgets('43 connecté : bouton de paiement par messagerie ; hors connexion : maquette inchangée', (t) async {
    await monter(t, const G_43());
    expect(find.text('Payer par messagerie'), findsOneWidget);
    await monter(t, const G_43(), connecte: false);
    expect(find.text('Payer par messagerie'), findsNothing);
  });

  testWidgets('communauté : fil réel et saisie réservée aux membres', (t) async {
    const c = Community(id: 'c1', name: 'Club Robotique', description: '', category: '', privacy: 'public', members: 4, myStatus: 'active', myRole: 'member');
    await monter(t, const CommunityScreen(), overrides: [
      selectedCommunityProvider.overrideWith(() => _SelC(c)),
      communityFeedProvider.overrideWith(() => _Feed([
            {'id': 'x', 'author': 'Alice Test', 'author_id': 'a', 'body': 'Réunion samedi', 'published_at': '2026-11-01T10:00:00Z', 'mine': false}
          ])),
    ]);
    expect(find.text('Réunion samedi'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('communauté non membre : invitation à rejoindre', (t) async {
    const c = Community(id: 'c1', name: 'Club Robotique', description: '', category: '', privacy: 'public', members: 4, myStatus: null, myRole: null);
    await monter(t, const CommunityScreen(), overrides: [selectedCommunityProvider.overrideWith(() => _SelC(c)), communityFeedProvider.overrideWith(() => _Feed(const []))]);
    expect(find.text('Rejoignez la communauté pour publier.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('17 connecté sans contenu de page : le texte d’origine reste', (t) async {
    await monter(t, const G_17(), overrides: [cmsPagesProvider.overrideWith(() => _Rows('table:cms_items', const []))]);
    expect(find.text('Version Test des conditions'), findsNothing);
    expect(find.text('Conditions et confidentialité'), findsWidgets);
  });

  testWidgets('17 connecté avec un contenu de page : il remplace le texte fixe', (t) async {
    await monter(t, const G_17(), overrides: [
      cmsPagesProvider.overrideWith(() => _Rows('table:cms_items', [
            {'kind': 'page', 'title': 'Conditions et confidentialité', 'body': 'Version Test des conditions', 'active': true, 'updated_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Version Test des conditions'), findsOneWidget);
  });
}
