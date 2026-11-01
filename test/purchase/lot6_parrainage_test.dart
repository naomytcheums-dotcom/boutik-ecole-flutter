import 'package:boutik_ecole/figma/g/g_243.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/referral.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Parrainage et gains (migration 20261101000400 ; règles § 3).

class _Summary extends ReferralNotifier {
  _Summary(this.s);
  final ReferralSummary? s;
  @override
  ReferralSummary? build() => s;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  test('synthèse serveur : paliers et libellés', () {
    final s = ReferralSummary.fromJson({
      'tier': 'Argent', 'active': 5, 'pending_referrals': 2, 'available': 360, 'waiting': 750, 'this_month': 1110,
      'referees': [{'name': 'Brice N.', 'status': 'active', 'earned': 750}],
    });
    expect(s.total, 1110);
    expect(s.tierLabel, 'Niveau Argent');
    expect(s.nextLabel, 'Plus que 15 filleuls pour passer Or');
    expect(s.referees.single.name, 'Brice N.');
    expect(const ReferralSummary().tierLabel, 'Aucun filleul actif');
    expect(const ReferralSummary(tier: 'Bronze', active: 4).nextLabel, 'Plus que 1 filleul pour passer Argent');
    expect(refereeStatus('pending'), 'En attente');
    expect(invitationText(''), contains('Connectez-vous'));
    expect(invitationText('ABCD2345'), 'Code de parrainage : ABCD2345');
  });

  testWidgets('243 connecté : solde réel, aucun filleul ni montant fictif', (tester) async {
    Backend.ready = true;
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [referralProvider.overrideWith(() => _Summary(const ReferralSummary(tier: 'Bronze', active: 1, available: 0, waiting: 500, month: 500, referees: [(name: 'Carine M.', status: 'active', earned: 500)])))],
      child: const MaterialApp(home: Scaffold(body: G_243())),
    ));
    await tester.pump();
    expect(find.text('12 500 FCFA'), findsNothing);
    expect(find.text('Brice Ndoumbe'), findsNothing);
    expect(find.text('Mme Mbella'), findsNothing);
    expect(find.text('Carine M.'), findsOneWidget);
    expect(find.textContaining('500'), findsWidgets);
  });
}
