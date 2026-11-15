import 'package:boutik_ecole/figma/live/inert_actions.dart';
import 'package:boutik_ecole/figma/live/profile_links.dart';
import 'package:boutik_ecole/figma/live/share.dart';
import 'package:boutik_ecole/figma/live/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le lien de partage d’un profil désigne la personne partagée', () {
    expect(profileLink('abc-123'), '$siteUrl/#/etudiant/abc-123');
    expect(profileLink('  '), siteUrl);
  });

  test('un lien de profil exige une adresse https valide', () {
    expect(profileLinkError('Portfolio', 'https://exemple.cm/moi'), isNull);
    expect(profileLinkError('Portfolio', 'http://exemple.cm/moi'), isNotNull);
    expect(profileLinkError('Portfolio', 'https://a b.cm/moi'), isNotNull);
    expect(profileLinkError('x' * 61, 'https://exemple.cm/moi'), isNotNull);
  });

  test('la synchronisation ne se dit complète que si les trois lectures ont abouti', () {
    expect(const SyncReport(favorites: true, messages: true, orders: false).allOk, isFalse);
    expect(const SyncReport(favorites: true, messages: true, orders: true).allOk, isTrue);
    expect(const SyncReport(favorites: true, messages: true, orders: true).percent, 100);
    expect(const SyncReport(favorites: true, messages: true, orders: false).upToDate, 2);
  });

  test('l’heure de synchronisation est honnête', () {
    final now = DateTime(2026, 11, 15, 12);
    expect(syncTime(null, now), 'Jamais');
    expect(syncTime(DateTime(2026, 11, 15, 9, 5), now), 'Aujourd’hui 09:05');
    expect(syncTime(DateTime(2026, 11, 14, 18, 30), now), '14/11 18:30');
  });
}
