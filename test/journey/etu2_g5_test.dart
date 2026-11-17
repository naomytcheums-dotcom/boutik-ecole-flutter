import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

NotificationItem notif(String kind, [Map<String, dynamic> data = const {}]) =>
    NotificationItem(id: '1', kind: kind, title: 'T', body: 'B', createdAt: DateTime(2026, 11, 19), read: false, data: data);

void main() {
  const wishId = '123e4567-e89b-12d3-a456-426614174000';

  Future<String?> ouvrir(WidgetTester t, Account? compte, NotificationItem n) async {
    final vus = <String>[];
    Widget page(GoRouterState s) {
      vus.add(s.uri.toString());
      return const SizedBox();
    }

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/s/:id', builder: (_, s) => page(s)),
      GoRoute(path: '/offres', builder: (_, s) => page(s)),
      GoRoute(path: '/marche/vendeur', builder: (_, s) => page(s)),
      GoRoute(path: '/marche/moderation', builder: (_, s) => page(s)),
      GoRoute(path: '/admin/sequestre', builder: (_, s) => page(s)),
    ]);
    late BuildContext ctx;
    late ProviderContainer container;
    await t.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [initialAccountProvider.overrideWithValue(compte)],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (c, child) {
          ctx = c;
          container = ProviderScope.containerOf(c);
          return child!;
        },
      ),
    ));
    await t.pumpAndSettle();
    final opened = openNotification(ctx, null, n, router: router, reader: container.read);
    await t.pumpAndSettle();
    return opened && vus.isNotEmpty ? vus.last : null;
  }

  final etudiant = demoAccount.copyWith(role: 1, staff: '');
  final finance = demoAccount.copyWith(staff: 'Finance');
  final admin = demoAccount.copyWith(staff: 'Admin global');
  final dept = demoAccount.copyWith(staff: 'Resp. département');

  group('destinations des notifications de l’étudiant', () {
    testWidgets('retrait / remboursement : l’étudiant va aux retraits ou à la commande, la finance au séquestre', (t) async {
      expect(await ouvrir(t, finance, notif('payout')), '/admin/sequestre');
      expect(await ouvrir(t, finance, notif('refund')), '/admin/sequestre');
      expect(await ouvrir(t, etudiant, notif('refund', {'order_number': 'BE-1'})), isNot('/admin/sequestre'));
    });

    testWidgets('sécurité, vérification et suppression de compte ouvrent les réglages du compte', (t) async {
      expect(await ouvrir(t, etudiant, notif('security')), '/s/148-2');
      expect(await ouvrir(t, etudiant, notif('account_deletion')), '/s/148-1');
      expect(await ouvrir(t, etudiant, notif('verification', {'document': 'student_card'})), '/s/154');
    });

    testWidgets('certification : étudiant → espace vendeur ; dept/admin → pas de redirection trompeuse', (t) async {
      expect(await ouvrir(t, etudiant, notif('certification', {'status': 'approved'})), '/marche/vendeur');
      expect(await ouvrir(t, dept, notif('certification')), isNull);
      expect(await ouvrir(t, admin, notif('certification')), isNull);
    });

    testWidgets('vœu, duel, coéquipiers, parrainage, offres, lives, modération ont un écran réel', (t) async {
      expect(await ouvrir(t, etudiant, notif('wish', {'wish_id': wishId})), '/s/217?wish=$wishId');
      expect(await ouvrir(t, etudiant, notif('wish')), '/s/216');
      expect(await ouvrir(t, etudiant, notif('duel')), '/s/220');
      expect(await ouvrir(t, etudiant, notif('teammate_invite')), '/s/163');
      expect(await ouvrir(t, etudiant, notif('subscription')), '/offres');
      expect(await ouvrir(t, etudiant, notif('live_reminder')), '/s/L1');
      expect(await ouvrir(t, etudiant, notif('moderation')), '/s/244');
    });

    testWidgets('file de validation des annonces : réservée au département, à l’admin et au support', (t) async {
      expect(await ouvrir(t, etudiant, notif('listing_review')), isNull);
      expect(await ouvrir(t, dept, notif('listing_review')), '/marche/moderation');
    });
  });

  test('retraits et remboursements sont classés avec les commandes et paiements ; chaque type a un libellé d’action', () {
    expect(notifGroup('payout'), 1);
    expect(notifGroup('refund'), 1);
    for (final k in ['payout', 'refund', 'certification', 'verification', 'security', 'moderation', 'teammate_invite', 'wish', 'duel', 'referral', 'subscription', 'certificate', 'listing_review', 'live_reminder', 'account_deletion']) {
      expect(notificationActionLabel(notif(k)), isNotNull, reason: k);
    }
  });
}

