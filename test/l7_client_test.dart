import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/lives.dart';
import 'package:boutik_ecole/figma/live/lot20.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:boutik_ecole/figma/live/referral.dart';
import 'package:flutter_test/flutter_test.dart';

Account _acc({int role = 0, String certification = 'none', String staff = ''}) => Account(name: 'Test', phone: '', email: 't@t.cm', password: 'x', role: role, certification: certification, staff: staff);

NotificationItem _n(String kind) => NotificationItem(id: kind, kind: kind, title: kind, body: '', createdAt: DateTime(2026, 11, 1), read: false);

void main() {
  group('Lives : qui peut diffuser', () {
    test('un client non certifié regarde mais ne diffuse pas', () => expect(canBroadcastLive(_acc()), false));
    test('un client certifié diffuse', () => expect(canBroadcastLive(_acc(certification: 'approved')), true));
    test('un étudiant diffuse', () => expect(canBroadcastLive(_acc(role: 1)), true));
    test('le département diffuse', () => expect(canBroadcastLive(_acc(staff: 'Resp. département')), true));
    test('un visiteur ne diffuse pas', () => expect(canBroadcastLive(null), false));
  });

  group('Défis : lecture de my_challenges', () {
    test('pastilles, états et badges viennent du serveur', () {
      final c = Challenges.fromJson({
        'streak': 6,
        'next_reward_in': 0,
        'streak_reward_claimable': true,
        'checked_today': true,
        'week_marks': [true, true, false, false, false, false, false],
        'today_index': 1,
        'posts_week': 2,
        'posts_claimable': false,
        'points': 40,
        'badges': {'first_sale': true, 'top10': false},
      });
      expect(c.streak, 6);
      expect(c.streakClaimable, true);
      expect(c.checkedToday, true);
      expect(c.weekMarks.where((m) => m).length, 2);
      expect(c.postsWeek, 2);
      expect(c.postsClaimed, false);
      expect(c.points, 40);
      expect(c.badges['first_sale'], true);
      expect(c.badges['top10'], false);
    });
  });

  group('Activité : segments', () {
    test('Abonnés ne garde que les nouveaux abonnés', () {
      expect(activityMatches(_n('follow'), 1), true);
      expect(activityMatches(_n('live'), 1), false);
    });
    test('Commandes regroupe commandes et paiements', () {
      expect(activityMatches(_n('order'), 2), true);
      expect(activityMatches(_n('payment'), 2), true);
      expect(activityMatches(_n('comment'), 2), false);
    });
    test('Lives ne garde que les lives et Tout garde tout', () {
      expect(activityMatches(_n('live'), 3), true);
      expect(activityMatches(_n('follow'), 3), false);
      expect(activityMatches(_n('comment'), 0), true);
    });
  });

  group('Parrainage : lien d’invitation', () {
    test('le code est normalisé avant d’être appliqué', () {
      expect(normalizeReferralCode(' abcd 2345 '), 'ABCD2345');
      expect(normalizeReferralCode('ABCD'), isNull);
      expect(normalizeReferralCode('ABCDEFG1'), isNull);
    });
    test('le lien d’invitation porte le code', () => expect(invitationLink('ABCD2345'), contains('?ref=ABCD2345')));
  });
}
