import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => Backend.ready = false);

  test("les motifs de réclamation correspondent aux valeurs acceptées par le serveur", () {
    expect(claimReasons, ['not_received', 'damaged', 'cancel_before_prep', 'refund']);
    expect(claimReasonLabels.length, claimReasons.length);
  });

  test("les motifs de signalement correspondent aux valeurs acceptées par le serveur", () {
    expect(reportReasonCodes, ['fraud', 'copied', 'price', 'other']);
  });

  test("le motif choisi est mémorisé", () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(claimReasonProvider), 0);
    c.read(claimReasonProvider.notifier).set(2);
    expect(c.read(claimReasonProvider), 2);
  });

  test("hors connexion : aucun envoi, message clair", () async {
    expect(await Backend.submitReview('BE-1', 'T', 5, ''), 'Connexion requise.');
    expect(await Backend.submitClaim('BE-1', 'damaged', 'Article cassé'), 'Connexion requise.');
    expect(await Backend.reportListing('T', 'fraud', ''), 'Connexion requise.');
    expect(await Backend.answerClaim('x', 'ok'), 'Connexion requise.');
    expect(await Backend.claims(), isEmpty);
    expect(await Backend.listingRating('T'), isNull);
  });

  test("engagements hors connexion : aucun enregistrement fictif", () async {
    expect(await Backend.engage('vote', 'duel:220', {'choice': 'lampe'}), 'Connexion requise.');
    expect(await Backend.cancelEngagement('vote', 'duel:220'), 'Connexion requise.');
  });
}
