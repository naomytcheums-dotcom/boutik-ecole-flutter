import 'package:flutter_test/flutter_test.dart';

import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/qr.dart';
import 'package:boutik_ecole/figma/live/referral.dart';

void main() {
  group('mot de passe oublié', () {
    test('le canal par défaut est l’e-mail et seuls les canaux connus sont acceptés', () {
      expect(forgotChannel(const {}), 'email');
      expect(forgotChannel(const {'fg_channel': 'sms'}), 'sms');
      expect(forgotChannel(const {'fg_channel': 'whatsapp'}), 'whatsapp');
      expect(forgotChannel(const {'fg_channel': 'telegram'}), 'email');
    });

    test('le lien de réinitialisation ne renvoie jamais vers localhost', () {
      expect(Backend.recoveryRedirect(), startsWith('https://'));
      expect(Backend.recoveryRedirect(), isNot(contains('localhost')));
    });
  });

  group('parrainage : barème défini côté serveur', () {
    test('sans barème : récompense non définie, aucun montant inventé', () {
      final s = ReferralSummary.fromJson({'tier': 'Aucun', 'active': 0, 'rules': []});
      expect(s.rewardsDefined, isFalse);
      expect(s.nextLabel, 'Récompense non définie');
      expect(s.progress, 0);
    });

    test('avec barème : palier suivant, avancement et libellé de récompense issus des règles', () {
      final s = ReferralSummary.fromJson({
        'tier': 'A',
        'active': 3,
        'rules': [
          {'tier': 'A', 'min_active': 1, 'bonus': 100, 'share_pct': 0},
          {'tier': 'B', 'min_active': 6, 'bonus': 200, 'share_pct': 0.02},
        ],
      });
      expect(s.rewardsDefined, isTrue);
      expect(s.nextLabel, 'Plus que 3 filleuls pour passer B');
      expect(s.progress, closeTo(0.5, 1e-9));
      expect(ruleReward(s.rules[1]), contains('2 %'));
    });
  });

  group('QR codes', () {
    test('le jeton est lu depuis l’adresse encodée ou seul ; tout autre texte est refusé', () {
      const t = 'AbCdEfGhIjKlMnOpQrStUvWxYz012345';
      expect(qrTokenOf(qrPayload(t)), t);
      expect(qrTokenOf(t), t);
      expect(qrTokenOf('https://exemple.com/?qr=court'), isNull);
      expect(qrTokenOf('BE-1234-ABCD'), isNull);
    });
  });
}
