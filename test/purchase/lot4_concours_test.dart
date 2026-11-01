import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/contests.dart';
import 'package:boutik_ecole/figma/live/hackathons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lot 4 : concours réels (migration 20261101000200 ; règles : REGLES_METIER_PROPOSEES.md § 1).

final _row = {
  'id': 'c-1',
  'title': 'Orange Digital Challenge 2026',
  'description': 'Inclusion financière.',
  'city': 'Douala',
  'reg_close_at': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
  'starts_on': '2026-11-14',
  'ends_on': '2026-11-16',
  'prize': 5000000,
  'places': 2,
  'status': 'published',
};

class _Server extends ServerContests {
  _Server(this.rows);
  final List<Hackathon>? rows;
  @override
  List<Hackathon>? build() => rows;
}

class _Ranking extends ServerRanking {
  @override
  List<Ranked> build() => const [Ranked('Équipe Alpha', 'Paiement hors ligne', 78)];
}

void main() {
  tearDown(() => Backend.ready = false);

  test('ligne serveur → fiche : dates, places prises, statut ouvert', () {
    final h = contestFromRow(_row, 1);
    expect(h.id, 'c-1');
    expect(h.dates, '14–16 nov.');
    expect(h.hours, 72);
    expect(h.status, 'Ouvert');
    expect(h.taken, 1);
    expect(contestFromRow({..._row, 'status': 'results'}, 0).status, 'Résultats');
    expect(contestFromRow({..._row, 'reg_close_at': '2020-01-01T00:00:00Z'}, 0).status, 'Clos');
  });

  test('hors serveur : les concours et le classement de la maquette (golden images)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(contestsProvider), same(hackathons));
    expect(c.read(rankingProvider), isNotEmpty);
  });

  test('connecté : seuls les concours du serveur ; aucun concours d’exemple', () {
    Backend.ready = true;
    final c = ProviderContainer(overrides: [serverContestsProvider.overrideWith(() => _Server([contestFromRow(_row, 1)]))]);
    addTearDown(c.dispose);
    expect([for (final h in c.read(visibleHackathonsProvider)) h.title], ['Orange Digital Challenge 2026']);
    expect(c.read(currentEventProvider).id, 'c-1');
    expect(placesLeft(c.read(currentEventProvider), const {}), 1, reason: '2 places, 1 équipe inscrite');
  });

  test('connecté sans concours publié : état vide honnête', () {
    Backend.ready = true;
    final c = ProviderContainer(overrides: [serverContestsProvider.overrideWith(() => _Server(null))]);
    addTearDown(c.dispose);
    expect(c.read(visibleHackathonsProvider), isEmpty);
    expect(c.read(currentEventProvider).title, 'Aucun concours publié pour le moment');
    expect(c.read(currentEventProvider).id, isEmpty);
  });

  test('connecté : le classement est celui du serveur, jamais les équipes d’exemple', () {
    Backend.ready = true;
    final c = ProviderContainer(overrides: [
      serverContestsProvider.overrideWith(() => _Server([contestFromRow(_row, 1)])),
      serverRankingProvider.overrideWith(_Ranking.new),
    ]);
    addTearDown(c.dispose);
    expect([for (final r in c.read(rankingProvider)) r.team], ['Équipe Alpha']);
  });
}
