import 'package:flutter_test/flutter_test.dart';

import 'package:boutik_ecole/figma/live/money_lot.dart';

void main() {
  test('chaque blocage d’argent a une explication lisible pour le vendeur', () {
    expect(holdReasonLabel({'reason': 'frozen', 'frozen_reason': 'Vérification d’identité'}), contains('Vérification d’identité'));
    expect(holdReasonLabel({'reason': 'claim'}), contains('Réclamation en cours'));
    expect(holdReasonLabel({'reason': 'dispute'}), contains('Litige'));
    expect(holdReasonLabel({'reason': 'refund'}), contains('annulation'));
    expect(holdReasonLabel({'reason': 'delivery'}), contains('livraison'));
    expect(holdReasonLabel({'reason': 'confirmation', 'releases_at': '2026-11-20T10:00:00Z'}), contains('2026-11-20'));
    expect(holdReasonLabel({'reason': 'confirmation', 'releases_at': null}), contains('confirmation de l’acheteur'));
  });

  test('états d’une réclamation : une réponse ne la clôt pas', () {
    expect(claimStatusLabel('open', null), contains('attente'));
    expect(claimStatusLabel('answered', null), contains('décision'));
    expect(claimStatusLabel('closed', 'refund'), contains('remboursé'));
    expect(claimStatusLabel('closed', 'release'), contains('non retenue'));
  });

  test('états d’un retrait', () {
    expect(payoutStatusLabel('demande'), contains('attente'));
    expect(payoutStatusLabel('verse'), 'Versé');
    expect(payoutStatusLabel('rejete'), 'Rejeté');
  });
}
