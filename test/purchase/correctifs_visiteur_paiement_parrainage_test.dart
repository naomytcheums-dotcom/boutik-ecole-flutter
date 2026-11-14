import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_home.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/modules.dart';
import 'package:boutik_ecole/figma/live/order_summary.dart';
import 'package:boutik_ecole/figma/live/paiement_messagerie.dart';
import 'package:boutik_ecole/figma/live/referral.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Correctifs du profil Visiteur : parrainage, commande à payer, vérification des paiements par la finance, quotas des forfaits.

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

Order _order(String id, int subtotal, {bool paid = false, bool cancelled = false}) =>
    Order(id: id, date: '1 nov. 2026', lines: const [], subtotal: subtotal, fee: 0, method: 'Mobile Money', reference: 'x', paid: paid, cancelled: cancelled);

Map<String, dynamic> _pending() => {
      'id': 'p1', 'reference': 'PAY-10001', 'amount': 25000, 'status': 'pending', 'provider': 'manual', 'subject': 'Commande #BE-2026-0150', 'provider_ref': 'MP240101.1234',
      'messages': [
        {'sender': 'payer', 'body': 'J’ai payé. Référence : MP240101.1234', 'created_at': '2026-11-05T10:05:00Z'},
      ],
    };

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {Account? compte, List<Override> overrides = const []}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (compte != null) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(compte);
      await t.pumpAndSettle();
    }
  }

  group('parrainage', () {
    test('le code saisi est mis en forme : 8 caractères A-Z2-9, majuscules, espaces retirés', () {
      expect(normalizeReferralCode(' abcd 2345 '), 'ABCD2345');
      expect(normalizeReferralCode('ABCD2345'), 'ABCD2345');
      expect(normalizeReferralCode('BE-ABC123'), isNull);
      expect(normalizeReferralCode('ABCD234'), isNull);
      expect(normalizeReferralCode('ABCD23456'), isNull);
      expect(normalizeReferralCode('ABCD2310'), isNull, reason: '0 et 1 ne font pas partie du code');
    });

    test('le message dit où saisir le code (le formulaire d’inscription n’a pas de champ de parrainage)', () {
      final m = invitationMessage('ABCD2345');
      expect(m, contains('après ton inscription'));
      expect(m, contains('ABCD2345 dans Mon compte › J’ai un code de parrainage.'));
    });

    test('le texte d’invitation distingue chargement, visiteur et code indisponible', () {
      expect(invitationText(null), 'Chargement du code…');
      expect(invitationText(''), contains('Connectez-vous'));
      expect(invitationText('', signedOut: false), 'Code indisponible pour le moment');
    });

    testWidgets('visiteur : le kit invite à se connecter avec un bouton', (t) async {
      await monter(t, const Scaffold(body: SingleChildScrollView(child: ReferralKit())));
      expect(find.text('Connectez-vous pour obtenir votre code.'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });
  });

  group('commande à payer', () {
    test('la commande ciblée est la plus récente impayée et non annulée', () {
      final l = [_order('#BE-2026-0003', 1000, paid: true), _order('#BE-2026-0002', 2000, cancelled: true), _order('#BE-2026-0001', 3000)];
      expect(payableOrder(l)?.id, '#BE-2026-0001');
      expect(orderReferenceLabel(l), 'BE-2026-0001');
      expect(amountToPay(l, const Totals(1, 500, 0)), 3000);
    });

    test('toutes payées : plus de commande ; le panier courant sert de repli', () {
      final l = [_order('#BE-2026-0003', 1000, paid: true)];
      expect(payableOrder(l), isNull);
      expect(orderReferenceLabel(l), 'Attribuée à la validation');
      expect(amountToPay(l, const Totals(1, 500, 0)), 500);
    });
  });

  group('forfaits', () {
    test('quota d’une carte de forfait : « 0 sur 10 » ou « illimité »', () {
      expect(planQuotaLabel(10), '0 sur 10');
      expect(planQuotaLabel(999), 'illimité');
    });
  });

  group('paiement par messagerie : vérification par la finance', () {
    final finance = demoAccount.copyWith(staff: 'Finance');

    testWidgets('finance : boutons Confirmer et Non retrouvé sur un paiement en attente', (t) async {
      await monter(t, const PaymentChatScreen(), compte: finance, overrides: [selectedPaymentProvider.overrideWith(_Sel.new), paymentThreadProvider.overrideWith(() => _Thread(_pending()))]);
      expect(find.text('Confirmer le paiement'), findsOneWidget);
      expect(find.text('Non retrouvé'), findsOneWidget);
    });

    testWidgets('payeur : aucun bouton de décision, seulement l’attente de la finance', (t) async {
      await monter(t, const PaymentChatScreen(), compte: demoAccount, overrides: [selectedPaymentProvider.overrideWith(_Sel.new), paymentThreadProvider.overrideWith(() => _Thread(_pending()))]);
      expect(find.text('Confirmer le paiement'), findsNothing);
      expect(find.text('Votre paiement est en cours de vérification par la finance.'), findsOneWidget);
      expect(find.text('Paiement par messagerie'), findsOneWidget);
      expect(find.text('Compte professionnel'), findsNothing);
    });

    testWidgets('référence SMS trop courte : message clair, aucun appel', (t) async {
      final th = _pending()..['status'] = 'created';
      await monter(t, const PaymentChatScreen(), compte: demoAccount, overrides: [selectedPaymentProvider.overrideWith(_Sel.new), paymentThreadProvider.overrideWith(() => _Thread(th))]);
      await t.enterText(find.byType(TextField), 'ab');
      await t.tap(find.text('J’ai payé'));
      await t.pump();
      expect(find.text('Saisissez la référence reçue par SMS (4 caractères au moins).'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('mes paiements : la finance voit la section « À vérifier »', (t) async {
      await monter(t, const MyPaymentsScreen(), compte: finance, overrides: [
        myPaymentsProvider.overrideWith(() => _Rows('my_payments', const [])),
        paymentsToVerifyProvider.overrideWith(() => _Rows('payments_to_verify', [
              {'id': 'p1', 'reference': 'PAY-10001', 'amount': 25000, 'status': 'pending', 'subject': 'Commande #BE-2026-0150', 'provider_ref': 'MP240101.1234', 'payer': 'Mariam Essono', 'created_at': '2026-11-05T10:00:00Z'}
            ])),
      ]);
      expect(find.text('À vérifier'), findsOneWidget);
      expect(find.textContaining('PAY-10001'), findsOneWidget);
      expect(find.textContaining('Réf. SMS : MP240101.1234'), findsOneWidget);
    });

    testWidgets('mes paiements : un payeur n’a pas la section « À vérifier »', (t) async {
      await monter(t, const MyPaymentsScreen(), compte: demoAccount, overrides: [
        myPaymentsProvider.overrideWith(() => _Rows('my_payments', const [
              {'id': 'p1', 'reference': 'PAY-10001', 'amount': 25000, 'status': 'pending', 'subject': 'Commande #BE-2026-0150'}
            ])),
      ]);
      expect(find.text('À vérifier'), findsNothing);
      expect(find.textContaining('PAY-10001'), findsOneWidget);
    });
  });
}
