import 'package:boutik_ecole/figma/live/hackathons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agenda : filtres par ville et gratuité, places restantes', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(visibleHackathonsProvider).length, hackathons.length);
    c.read(hackTabProvider.notifier).set(2); // Douala
    expect(c.read(visibleHackathonsProvider).every((h) => h.city == 'Douala'), isTrue);
    c.read(hackTabProvider.notifier).set(4); // gratuits
    expect(c.read(visibleHackathonsProvider).every((h) => h.free), isTrue);

    final orange = hackathons.first;
    expect(placesLeft(orange, c.read(registrationsProvider)), 120);
    c.read(registrationsProvider.notifier).add(const Registration('orange', 'Team Innov’', 'Inclusion financière'));
    expect(placesLeft(orange, c.read(registrationsProvider)), 119);
  });

  test('équipe : invitations, acceptation et limite de taille', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(teamMembersProvider.notifier);
    expect(c.read(teamMembersProvider).length, 1);
    n.invite(mates.first);
    expect(n.has(mates.first.name), isTrue);
    expect(c.read(teamMembersProvider).last.confirmed, isFalse);
    n.confirm(mates.first.name);
    expect(c.read(teamMembersProvider).last.confirmed, isTrue);
    n.remove(mates.first.name);
    expect(n.has(mates.first.name), isFalse);

    c.read(mateTabProvider.notifier).set(2); // Business
    expect(c.read(visibleMatesProvider).every((m) => m.cat == 'Business'), isTrue);
    c.read(mateQueryProvider.notifier).set('marketing');
    expect(c.read(visibleMatesProvider).single.name, 'Nadège Fotso');
  });

  test('jury et classement : la note d\'un projet déposé change le classement', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(rankingProvider).first.team, 'Team Innov’');
    expect(c.read(rankingProvider).length, 3);

    expect(provisionalRank(c.read(scoresProvider)), 4); // 30/40 = 75 pts : derrière 94, 89 et 86
    for (var i = 0; i < 4; i++) {
      for (var k = 0; k < 4; k++) {
        if (c.read(scoresProvider)[k] != 10) c.read(scoresProvider.notifier).bump(k);
      }
    }
    for (var k = 0; k < 4; k++) {
      while (c.read(scoresProvider)[k] != 10) {
        c.read(scoresProvider.notifier).bump(k);
      }
    }
    expect(provisionalRank(c.read(scoresProvider)), 1);

    c.read(submissionProvider.notifier).submit(const Submission('Équipe Test', 'Cartes agricoles', 'https://demo.example.cm', 'Une description assez longue du projet.'));
    c.read(submissionProvider.notifier).score(97);
    final r = c.read(rankingProvider);
    expect(r.first.team, 'Équipe Test');
    expect(r.first.pts, 97);
    expect(r.length, 4);
    expect(ordinal(1), '1er');
    expect(ordinal(3), '3e');
  });
}
