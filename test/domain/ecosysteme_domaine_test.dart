import 'package:boutik_ecole/core/domain/abonnements_campagnes.dart';
import 'package:boutik_ecole/core/domain/feed_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 3, 12);

FeedItem _item(String id, String author, {String cat = 'tech', String fmt = 'texte', int likes = 0, int comments = 0, int hoursAgo = 1, double quality = 0.5, int reports = 0, bool approved = true, String? community}) =>
    FeedItem(id: id, authorId: author, category: cat, format: fmt, likes: likes, comments: comments, quality: quality, reports: reports, approved: approved, communityId: community, createdAt: _now.subtract(Duration(hours: hoursAgo)));

void main() {
  const ranker = FeedRanker();

  group('classement du fil', () {
    test('la popularité ne suffit pas : un auteur suivi, récent et pertinent passe devant un contenu viral sans lien', () {
      final viral = _item('viral', 'inconnu', cat: 'sport', likes: 50000, comments: 9000, hoursAgo: 200);
      final pertinent = _item('pertinent', 'ami', cat: 'tech', likes: 3, hoursAgo: 2, quality: 0.8);
      const s = FeedSignals(followed: {'ami'}, interests: {'tech': 0.9});
      final r = ranker.rank([viral, pertinent], s, _now);
      expect(r.first.item.id, 'pertinent');
    });

    test('le poids de la popularité est plafonné (échelle logarithmique)', () {
      final a = _item('a', 'x', likes: 500);
      final b = _item('b', 'y', likes: 5000000);
      expect(ranker.engagementScore(a), closeTo(1.0, 0.0001));
      expect(ranker.engagementScore(b), 1.0);
    });

    test('la fraîcheur décroît de moitié à chaque demi-vie', () {
      final recent = ranker.freshnessScore(_item('r', 'x', hoursAgo: 0), _now);
      final vieux = ranker.freshnessScore(_item('v', 'x', hoursAgo: 48), _now);
      expect(recent, closeTo(1.0, 1e-9));
      expect(vieux, closeTo(0.5, 1e-9));
    });

    test('contenus non approuvés, masqués, auteurs bloqués et catégories coupées ne sont jamais classés', () {
      final items = [
        _item('ok', 'a'),
        _item('modere', 'b', approved: false),
        _item('masque', 'c'),
        _item('bloque', 'd'),
        _item('coupe', 'e', cat: 'pub'),
      ];
      const s = FeedSignals(hiddenItems: {'masque'}, blockedAuthors: {'d'}, mutedCategories: {'pub'});
      final ids = ranker.rank(items, s, _now).map((r) => r.item.id).toList();
      expect(ids, ['ok']);
    });

    test('diversité : au plus 2 contenus du même auteur', () {
      final items = [for (var i = 0; i < 6; i++) _item('a$i', 'meme', hoursAgo: i + 1), _item('b', 'autre', hoursAgo: 20)];
      final r = ranker.rank(items, const FeedSignals(), _now);
      expect(r.where((x) => x.item.authorId == 'meme').length, 2);
      expect(r.map((x) => x.item.id), contains('b'));
    });

    test('un contenu déjà vu et un contenu signalé sont pénalisés', () {
      final neuf = _item('neuf', 'a');
      final vu = _item('vu', 'b');
      final signale = _item('sig', 'c', reports: 5);
      final r = ranker.rank([neuf, vu, signale], const FeedSignals(seen: {'vu'}), _now);
      expect(r.first.item.id, 'neuf');
      expect(r.last.item.id, anyOf('vu', 'sig'));
    });

    test('chaque résultat explique pourquoi il est recommandé', () {
      final r = ranker.rank([_item('a', 'ami', cat: 'tech')], const FeedSignals(followed: {'ami'}, interests: {'tech': 0.8}), _now);
      expect(r.single.reasons, containsAll(['Vous suivez cet auteur', 'Correspond à votre intérêt : tech']));
    });

    test('flux chronologique : tri par date seule, sans pondération', () {
      final items = [_item('ancien', 'a', likes: 9999, hoursAgo: 30), _item('nouveau', 'b', hoursAgo: 1)];
      final r = ranker.rank(items, const FeedSignals(), _now, mode: FeedMode.recentes);
      expect(r.map((x) => x.item.id), ['nouveau', 'ancien']);
    });

    test('onglets Abonnements et Communautés filtrent sur les relations réelles', () {
      final items = [_item('suivi', 'ami'), _item('autre', 'x'), _item('comm', 'y', community: 'c1')];
      const s = FeedSignals(followed: {'ami'}, joinedCommunities: {'c1'});
      expect(ranker.rank(items, s, _now, mode: FeedMode.abonnements).map((x) => x.item.id), ['suivi']);
      expect(ranker.rank(items, s, _now, mode: FeedMode.communautes).map((x) => x.item.id), ['comm']);
    });

    test('les poids sont configurables', () {
      final a = _item('fraiche', 'x', hoursAgo: 1, quality: 0.1);
      final b = _item('qualite', 'y', hoursAgo: 40, quality: 1.0);
      final parDefaut = ranker.rank([a, b], const FeedSignals(), _now).first.item.id;
      final qualite = const FeedRanker(weights: RankWeights(freshness: 0.0, quality: 1.0)).rank([a, b], const FeedSignals(), _now).first.item.id;
      expect(qualite, 'qualite');
      expect(parDefaut, isNotEmpty);
    });
  });

  group('abonnements et droits', () {
    const gratuit = Plan(PlanCode.gratuit, {});
    const pro = Plan(PlanCode.createurPro, {Feature.statsAvancees, Feature.badgeVerifie});
    final debut = _now.subtract(const Duration(days: 5));
    final fin = _now.add(const Duration(days: 25));

    test('sans abonnement, aucune fonctionnalité premium', () {
      expect(const Entitlements([], free: gratuit).allows(Feature.statsAvancees, _now), isFalse);
    });

    test('un abonnement non payé ou non validé ne donne aucun droit', () {
      final s = Subscription(plan: pro, status: SubStatus.enAttentePaiement, startsAt: debut, endsAt: fin);
      final nonValide = Subscription(plan: pro, status: SubStatus.active, startsAt: debut, endsAt: fin, paymentValidated: false);
      expect(Entitlements([s, nonValide], free: gratuit).allows(Feature.statsAvancees, _now), isFalse);
    });

    test('un abonnement actif et payé donne ses droits, et seulement les siens', () {
      final s = Subscription(plan: pro, status: SubStatus.active, startsAt: debut, endsAt: fin, paymentValidated: true);
      final e = Entitlements([s], free: gratuit);
      expect(e.allows(Feature.statsAvancees, _now), isTrue);
      expect(e.allows(Feature.boostCampagnes, _now), isFalse);
    });

    test('annulé en fin de période : droits jusqu\'à l\'échéance, puis plus rien', () {
      final s = Subscription(plan: pro, status: SubStatus.annuleFinPeriode, startsAt: debut, endsAt: fin, paymentValidated: true);
      final e = Entitlements([s], free: gratuit);
      expect(e.allows(Feature.badgeVerifie, _now), isTrue);
      expect(e.allows(Feature.badgeVerifie, fin.add(const Duration(seconds: 1))), isFalse);
    });

    test('expirée ou suspendue : aucun droit', () {
      for (final st in [SubStatus.expiree, SubStatus.suspendue]) {
        final s = Subscription(plan: pro, status: st, startsAt: debut, endsAt: fin, paymentValidated: true);
        expect(Entitlements([s], free: gratuit).allows(Feature.statsAvancees, _now), isFalse);
      }
    });
  });

  group('campagnes sponsorisées', () {
    Campaign base() => Campaign(id: 'c1', targetId: 'p1', budgetFcfa: 10000, dailyBudgetFcfa: 2000, startsAt: _now, endsAt: _now.add(const Duration(days: 7)));

    test('un brouillon invalide ne peut pas être soumis', () {
      final c = Campaign(id: 'c', targetId: 'p', budgetFcfa: 1000, dailyBudgetFcfa: 5000, startsAt: _now, endsAt: _now.add(const Duration(days: 1)));
      expect(c.validate(), isNotEmpty);
      expect(() => c.moveTo(CampaignStatus.enAttenteValidation), throwsStateError);
    });

    test('cycle normal : brouillon, validation, approbation, activation', () {
      var c = base().moveTo(CampaignStatus.enAttenteValidation).moveTo(CampaignStatus.approuvee);
      expect(() => c.moveTo(CampaignStatus.active), throwsStateError, reason: 'sans paiement validé ni confirmation');
      c = c.copyWith(paymentValidated: true, confirmedByOwner: true).moveTo(CampaignStatus.active);
      expect(c.status, CampaignStatus.active);
    });

    test('paiement validé mais sans confirmation du propriétaire : pas de diffusion', () {
      final c = base().moveTo(CampaignStatus.enAttenteValidation).moveTo(CampaignStatus.approuvee).copyWith(paymentValidated: true);
      expect(() => c.moveTo(CampaignStatus.active), throwsStateError);
    });

    test('transitions interdites', () {
      expect(() => base().moveTo(CampaignStatus.active), throwsStateError);
      expect(() => base().moveTo(CampaignStatus.terminee), throwsStateError);
    });

    test('la dépense ne dépasse jamais le budget ni la limite du jour, et termine la campagne', () {
      var c = base().copyWith(status: CampaignStatus.active, paymentValidated: true, confirmedByOwner: true);
      expect(() => c.spend(2500, spentToday: 0), throwsStateError, reason: 'au-delà du budget quotidien');
      expect(() => c.spend(500, spentToday: 1800), throwsStateError);
      c = c.spend(2000, spentToday: 0);
      expect(c.spentFcfa, 2000);
      c = c.copyWith(spentFcfa: 8000).spend(2000, spentToday: 0);
      expect(c.status, CampaignStatus.terminee);
      expect(() => c.spend(1, spentToday: 0), throwsStateError);
    });

    test('indicateurs : jamais de statistique inventée', () {
      expect(indicateurs(impressions: 0, clics: 0, depenseFcfa: 500).tauxClic, isNull);
      expect(indicateurs(impressions: 100, clics: 0, depenseFcfa: 500).coutParClic, isNull);
      final i = indicateurs(impressions: 200, clics: 10, depenseFcfa: 500);
      expect(i.tauxClic, 0.05);
      expect(i.coutParClic, 50);
    });

    test('toute campagne est identifiée comme sponsorisée', () => expect(base().isSponsored, isTrue));
  });
}
