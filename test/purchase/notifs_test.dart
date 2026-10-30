import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une ligne serveur devient une notification, lue ou non', () {
    final n = NotificationItem.fromRow({'id': 'n1', 'kind': 'order', 'title': 'Paiement confirmé', 'body': 'Votre commande #BE-1 est payée.', 'created_at': '2026-10-30T07:00:00Z', 'read_at': null});
    expect(n.read, isFalse);
    expect(n.kind, 'order');
    final lue = NotificationItem.fromRow({'id': 'n2', 'kind': 'message', 'title': 'Nouveau message', 'body': 'Bonjour', 'created_at': '2026-10-30T07:00:00Z', 'read_at': '2026-10-30T08:00:00Z'});
    expect(lue.read, isTrue);
  });

  test('hors connexion : aucune notification ni compteur, filtre « toutes » par défaut', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(notifsProvider), isEmpty);
    expect(c.read(notifFilterProvider), 0);
    c.read(notifFilterProvider.notifier).set(2);
    expect(c.read(notifFilterProvider), 2);
    final u = await c.read(unreadProvider.future);
    expect(u.notifications, 0);
    expect(u.messages, 0);
  });
}
