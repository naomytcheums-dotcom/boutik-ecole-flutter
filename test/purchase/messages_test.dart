import 'package:boutik_ecole/figma/live/messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends Conversations {
  @override
  List<ConversationItem> build() => [
        ConversationItem.fromRow({'id': 'c1', 'listing_title': 'Lampe', 'other_name': 'Yannick Mouanga', 'last_body': 'Bonjour', 'last_at': '2026-10-30T07:00:00Z', 'unread': 2}),
        ConversationItem.fromRow({'id': 'c2', 'listing_title': null, 'other_name': null, 'last_body': null, 'last_at': null, 'unread': null}),
      ];
}

void main() {
  test('une ligne serveur devient une conversation avec ses non-lus', () {
    final c = ConversationItem.fromRow({'id': 'c1', 'listing_title': 'Lampe', 'other_name': 'Yannick Mouanga', 'last_body': 'Bonjour', 'last_at': '2026-10-30T07:00:00Z', 'unread': 2});
    expect(c.otherName, 'Yannick Mouanga');
    expect(c.unread, 2);
    expect(c.lastAt, isNotNull);
  });

  test('valeurs absentes : repli neutre, jamais d\'erreur', () {
    final c = ConversationItem.fromRow({'id': 'c2'});
    expect(c.otherName, 'Utilisateur');
    expect(c.unread, 0);
    expect(c.lastBody, '');
    expect(c.lastAt, isNull);
  });

  test('la conversation ouverte est celle qui a été choisie', () {
    final c = ProviderContainer(overrides: [conversationsProvider.overrideWith(_Fake.new)]);
    addTearDown(c.dispose);
    expect(c.read(selectedConversationItemProvider), isNull);
    c.read(selectedConversationProvider.notifier).set('c1');
    expect(c.read(selectedConversationItemProvider)!.otherName, 'Yannick Mouanga');
    c.read(selectedConversationProvider.notifier).set('inconnue');
    expect(c.read(selectedConversationItemProvider), isNull);
  });

  test('hors connexion : aucune conversation', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(conversationsProvider), isEmpty);
  });
}
