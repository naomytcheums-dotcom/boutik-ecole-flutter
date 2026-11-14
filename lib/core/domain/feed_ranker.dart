import 'dart:math' as math;

/// Moteur de classement du fil (logique pure, sans interface ni réseau).
///
/// État : **implémenté, testé unitairement et branché** sur le fil du Cercle (`rankReels`, lib/figma/live/reels.dart), voir
/// docs/transformation/ALGORITHME_RECOMMANDATION.md. Les poids sont configurables, le classement est explicable
/// (chaque résultat porte ses raisons) et un flux chronologique simple est toujours disponible.

enum FeedMode { pourToi, abonnements, communautes, tendances, recentes }

/// Contenu candidat. Les compteurs sont ceux que le serveur a validés (dédoublonnage des faux likes côté serveur).
class FeedItem {
  const FeedItem({
    required this.id,
    required this.authorId,
    required this.createdAt,
    this.category = '',
    this.format = 'texte',
    this.communityId,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
    this.reports = 0,
    this.quality = 0.5,
    this.approved = true,
  });
  final String id, authorId, category, format;
  final String? communityId;
  final DateTime createdAt;
  final int likes, comments, saves, shares, reports;

  /// Qualité estimée du contenu entre 0 et 1 (complétude, média, longueur utile) : calculée en amont, jamais par les likes.
  final double quality;

  /// Faux tant que la modération n'a pas approuvé la publication : elle n'est jamais classée.
  final bool approved;
}

/// Ce que l'on sait de l'utilisateur. Aucune donnée sensible (santé, religion, opinion, origine) n'entre ici.
class FeedSignals {
  const FeedSignals({
    this.followed = const {},
    this.joinedCommunities = const {},
    this.interests = const {},
    this.affinity = const {},
    this.hiddenAuthors = const {},
    this.blockedAuthors = const {},
    this.hiddenItems = const {},
    this.seen = const {},
    this.mutedCategories = const {},
  });
  final Set<String> followed, joinedCommunities, hiddenAuthors, blockedAuthors, hiddenItems, seen, mutedCategories;

  /// Centres d'intérêt déclarés ou déduits : catégorie → poids entre 0 et 1.
  final Map<String, double> interests;

  /// Interactions passées avec un auteur : auteur → intensité entre 0 et 1.
  final Map<String, double> affinity;
}

/// Poids du score (leur somme n'a pas à valoir 1 : le score est comparatif). La popularité est volontairement faible.
class RankWeights {
  const RankWeights({
    this.affinity = 0.28,
    this.interest = 0.25,
    this.freshness = 0.18,
    this.quality = 0.12,
    this.engagement = 0.08,
    this.community = 0.09,
    this.reportPenalty = 0.15,
    this.seenPenalty = 0.45,
    this.halfLifeHours = 48,
    this.engagementCap = 500,
    this.maxPerAuthor = 2,
    this.sameAuthorPenalty = 0.22,
    this.sameCategoryPenalty = 0.06,
    this.sameFormatPenalty = 0.04,
  });
  final double affinity, interest, freshness, quality, engagement, community, reportPenalty, seenPenalty, halfLifeHours;
  final double sameAuthorPenalty, sameCategoryPenalty, sameFormatPenalty;
  final int engagementCap, maxPerAuthor;
}

class RankedItem {
  const RankedItem(this.item, this.score, this.reasons);
  final FeedItem item;
  final double score;

  /// « Pourquoi cette publication ? » : raisons lisibles par l'utilisateur.
  final List<String> reasons;
}

class FeedRanker {
  const FeedRanker({this.weights = const RankWeights()});
  final RankWeights weights;

  bool _eligible(FeedItem i, FeedSignals s) =>
      i.approved && !s.blockedAuthors.contains(i.authorId) && !s.hiddenAuthors.contains(i.authorId) && !s.hiddenItems.contains(i.id) && !s.mutedCategories.contains(i.category);

  /// Popularité : échelle logarithmique plafonnée, donc une publication à 10 000 likes ne vaut pas 20 fois une à 500.
  double engagementScore(FeedItem i) {
    final raw = i.likes + 2 * i.comments + 3 * i.saves + 2 * i.shares;
    return math.min(1.0, math.log(1 + raw) / math.log(1 + weights.engagementCap));
  }

  double freshnessScore(FeedItem i, DateTime now) {
    final hours = math.max(0, now.difference(i.createdAt).inMinutes) / 60.0;
    return math.pow(0.5, hours / weights.halfLifeHours).toDouble();
  }

  RankedItem score(FeedItem i, FeedSignals s, DateTime now) {
    final w = weights;
    final reasons = <String>[];
    final aff = s.followed.contains(i.authorId) ? 1.0 : (s.affinity[i.authorId] ?? 0.0);
    final interest = s.interests[i.category] ?? 0.0;
    final fresh = freshnessScore(i, now);
    final inCommunity = i.communityId != null && s.joinedCommunities.contains(i.communityId);
    var v = w.affinity * aff + w.interest * interest + w.freshness * fresh + w.quality * i.quality + w.engagement * engagementScore(i) + (inCommunity ? w.community : 0);
    if (s.followed.contains(i.authorId)) reasons.add('Vous suivez cet auteur');
    if (!s.followed.contains(i.authorId) && aff > 0.4) reasons.add('Vous interagissez souvent avec cet auteur');
    if (interest > 0.4) reasons.add('Correspond à votre intérêt : ${i.category}');
    if (inCommunity) reasons.add('Publié dans une communauté que vous avez rejointe');
    if (fresh > 0.7) reasons.add('Publication récente');
    if (reasons.isEmpty && engagementScore(i) > 0.6) reasons.add('Très appréciée par les membres');
    if (reasons.isEmpty) reasons.add('Découverte : contenu de qualité en dehors de vos habitudes');
    if (i.reports > 0) v -= w.reportPenalty * math.min(1.0, i.reports / 5.0);
    if (s.seen.contains(i.id)) v -= w.seenPenalty;
    return RankedItem(i, v, reasons);
  }

  /// Classe les contenus pour un mode donné. `limit` borne la longueur de la liste.
  List<RankedItem> rank(List<FeedItem> items, FeedSignals s, DateTime now, {FeedMode mode = FeedMode.pourToi, int limit = 20}) {
    var pool = [for (final i in items) if (_eligible(i, s)) i];
    switch (mode) {
      case FeedMode.recentes:
        pool.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return [for (final i in pool.take(limit)) RankedItem(i, 0, const ['Ordre chronologique'])];
      case FeedMode.abonnements:
        pool = [for (final i in pool) if (s.followed.contains(i.authorId)) i];
      case FeedMode.communautes:
        pool = [for (final i in pool) if (i.communityId != null && s.joinedCommunities.contains(i.communityId)) i];
      case FeedMode.tendances:
        // tendances = engagement récent, mais sans effacer la fraîcheur ni les contenus signalés
        final scored = [for (final i in pool) RankedItem(i, engagementScore(i) * freshnessScore(i, now) - (i.reports > 0 ? 0.1 : 0), const ['Tendance récente'])];
        scored.sort((a, b) => b.score.compareTo(a.score));
        return _diversify(scored, limit);
      case FeedMode.pourToi:
        break;
    }
    final scored = [for (final i in pool) score(i, s, now)]..sort((a, b) => b.score.compareTo(a.score));
    return _diversify(scored, limit);
  }

  /// Sélection gloutonne : chaque choix pénalise les contenus du même auteur, de la même catégorie et du même format.
  /// Au-delà de `maxPerAuthor` publications d'un même auteur, les suivantes passent après toutes les autres : le classement
  /// limite la place d'un auteur mais n'écarte jamais une publication.
  List<RankedItem> _diversify(List<RankedItem> sorted, int limit) {
    final left = [...sorted];
    final out = <RankedItem>[];
    final byAuthor = <String, int>{};
    final byCategory = <String, int>{};
    final byFormat = <String, int>{};
    while (out.length < limit && left.isNotEmpty) {
      RankedItem? best;
      var bestV = double.negativeInfinity;
      for (final c in left) {
        if ((byAuthor[c.item.authorId] ?? 0) >= weights.maxPerAuthor) continue;
        final v = c.score -
            weights.sameAuthorPenalty * (byAuthor[c.item.authorId] ?? 0) -
            weights.sameCategoryPenalty * (byCategory[c.item.category] ?? 0) -
            weights.sameFormatPenalty * (byFormat[c.item.format] ?? 0);
        if (v > bestV) {
          bestV = v;
          best = c;
        }
      }
      if (best == null) {
        out.addAll(left.take(limit - out.length));
        break;
      }
      left.remove(best);
      out.add(best);
      byAuthor[best.item.authorId] = (byAuthor[best.item.authorId] ?? 0) + 1;
      byCategory[best.item.category] = (byCategory[best.item.category] ?? 0) + 1;
      byFormat[best.item.format] = (byFormat[best.item.format] ?? 0) + 1;
    }
    return out;
  }
}
