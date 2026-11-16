import 'package:boutik_ecole/figma/live/account_menu.dart';
import 'package:boutik_ecole/figma/live/community_moderation.dart';
import 'package:boutik_ecole/figma/live/moderation_reseau.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationItem _n(String kind) => NotificationItem(id: '1', kind: kind, title: 't', body: 'b', createdAt: DateTime(2026), read: false);

void main() {
  group('Défis : comptes non certifiés (S7-43)', () {
    test('les publications en attente sont expliquées', () {
      final c = Challenges.fromJson({'posts_week': 1, 'posts_week_pending': 2, 'pending_posts': 2, 'certified': false, 'boost_ready': false});
      expect(c.pendingNote, contains('2 publications de la semaine attendent la validation du département'));
      expect(c.boostNote, contains('attend encore la validation'));
      expect(c.certified, false);
    });

    test('aucune explication quand tout est validé', () {
      final c = Challenges.fromJson({'posts_week': 3, 'posts_week_pending': 0, 'pending_posts': 0, 'certified': true, 'boost_ready': true});
      expect(c.pendingNote, isNull);
      expect(c.boostNote, isNull);
    });

    test('le prochain boost est annoncé (un boost tous les 6 jours)', () {
      final c = Challenges.fromJson({'streak': 8, 'next_reward_in': 0, 'streak_reward_claimable': false, 'streak_claimed_today': false, 'boost_next_in': 3});
      expect(c.nextLabel, 'Prochain boost possible dans 3 jours');
      expect(const Challenges(streak: 1, nextIn: 5).nextLabel, 'Encore 5 jours pour gagner un boost de 24 h');
    });
  });

  group('Modération du réseau social', () {
    test('le menu propose la modération au département, à l’administration et au support seulement', () {
      for (final r in ['dept', 'admin', 'support']) {
        expect(accountMenuEntries(r).map((x) => x.$1), contains('Modération du réseau social'), reason: r);
      }
      for (final r in ['student', 'client', 'company']) {
        expect(accountMenuEntries(r).map((x) => x.$1), isNot(contains('Modération du réseau social')), reason: r);
      }
    });

    test('les notifications de modération ont un libellé d’action', () {
      expect(notificationActionLabel(_n('post_review')), 'Valider les publications');
      expect(notificationActionLabel(_n('report')), 'Voir les signalements');
      expect(notificationActionLabel(_n('shop')), 'Voir la boutique');
    });

    testWidgets('l’écran affiche ses cinq onglets et signale un serveur indisponible', (t) async {
      await t.pumpWidget(const ProviderScope(child: MaterialApp(home: SocialModerationScreen())));
      await t.pumpAndSettle();
      for (final label in ['À valider', 'Signalées', 'Masquées', 'Histoires', 'Commentaires']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('onglet de modération d’une communauté : serveur indisponible = message clair', (t) async {
      await t.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: CommunityModerationTab(communityId: 'c1')))));
      await t.pumpAndSettle();
      expect(find.textContaining('indisponible'), findsOneWidget);
    });
  });
}
