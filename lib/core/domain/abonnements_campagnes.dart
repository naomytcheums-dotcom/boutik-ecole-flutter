/// Droits d'abonnement et cycle de vie des campagnes sponsorisées (logique pure).
///
/// État : **implémenté et testé unitairement ; non branché** (aucune table de plans, d'abonnements ni de campagnes
/// n'existe encore ; les tarifs ne sont pas fixés : ils sont des données, jamais du code). Voir
/// docs/transformation/COMMUNAUTES_ET_PREMIUM.md et CAMPAGNES_SPONSORISEES.md.

/// Fonctionnalités soumises à un droit. Un bouton affiché ne donne jamais le droit : seul `Entitlements.allows` le fait.
enum Feature { statsAvancees, badgeVerifie, portfolioEnrichi, visiteursProfil, outilsVendeurPro, boostCampagnes, gestionCommunaute, prospection }

enum PlanCode { gratuit, createurPro, vendeurPro, entreprise, adminCommunaute }

/// Plan : droits et tarif sont des données (le prix est en FCFA entiers, `null` tant qu'il n'est pas décidé).
class Plan {
  const Plan(this.code, this.features, {this.priceFcfa, this.periodDays = 30});
  final PlanCode code;
  final Set<Feature> features;
  final int? priceFcfa;
  final int periodDays;
}

enum SubStatus { enAttentePaiement, active, annuleFinPeriode, expiree, suspendue }

class Subscription {
  const Subscription({required this.plan, required this.status, required this.startsAt, required this.endsAt, this.paymentValidated = false});
  final Plan plan;
  final SubStatus status;
  final DateTime startsAt, endsAt;

  /// Vrai uniquement après confirmation fiable du prestataire côté serveur (jamais après une simple redirection).
  final bool paymentValidated;

  bool isInForce(DateTime now) =>
      paymentValidated && (status == SubStatus.active || status == SubStatus.annuleFinPeriode) && !now.isBefore(startsAt) && now.isBefore(endsAt);
}

class Entitlements {
  const Entitlements(this.subscriptions, {required this.free});
  final List<Subscription> subscriptions;
  final Plan free;

  /// Droit accordé par le plan gratuit ou par un abonnement en vigueur dont le paiement est validé.
  bool allows(Feature f, DateTime now) => free.features.contains(f) || subscriptions.any((s) => s.isInForce(now) && s.plan.features.contains(f));
}

enum CampaignStatus { brouillon, enAttenteValidation, approuvee, active, suspendue, terminee, refusee }

/// Transitions autorisées ; toute autre est refusée.
const campaignTransitions = <CampaignStatus, Set<CampaignStatus>>{
  CampaignStatus.brouillon: {CampaignStatus.enAttenteValidation},
  CampaignStatus.enAttenteValidation: {CampaignStatus.approuvee, CampaignStatus.refusee, CampaignStatus.brouillon},
  CampaignStatus.approuvee: {CampaignStatus.active, CampaignStatus.terminee},
  CampaignStatus.active: {CampaignStatus.suspendue, CampaignStatus.terminee},
  CampaignStatus.suspendue: {CampaignStatus.active, CampaignStatus.terminee},
  CampaignStatus.terminee: {},
  CampaignStatus.refusee: {CampaignStatus.brouillon},
};

class Campaign {
  const Campaign({
    required this.id,
    required this.targetId,
    required this.budgetFcfa,
    required this.dailyBudgetFcfa,
    required this.startsAt,
    required this.endsAt,
    this.status = CampaignStatus.brouillon,
    this.spentFcfa = 0,
    this.paymentValidated = false,
    this.confirmedByOwner = false,
  });
  final String id, targetId;
  final int budgetFcfa, dailyBudgetFcfa, spentFcfa;
  final DateTime startsAt, endsAt;
  final CampaignStatus status;
  final bool paymentValidated, confirmedByOwner;

  /// Les contenus d'une campagne sont toujours identifiés comme sponsorisés.
  bool get isSponsored => true;

  /// Erreurs de validité du brouillon (liste vide = valide).
  List<String> validate() => [
        if (budgetFcfa <= 0) 'Le budget total doit être positif.',
        if (dailyBudgetFcfa <= 0) 'Le budget quotidien doit être positif.',
        if (dailyBudgetFcfa > budgetFcfa) 'Le budget quotidien ne peut pas dépasser le budget total.',
        if (!endsAt.isAfter(startsAt)) 'La date de fin doit suivre la date de début.',
      ];

  /// Passe à `to` si la transition est permise et ses conditions sont remplies ; sinon lève une erreur explicite.
  Campaign moveTo(CampaignStatus to) {
    if (!(campaignTransitions[status] ?? const {}).contains(to)) throw StateError('Transition refusée : $status vers $to');
    if (to == CampaignStatus.enAttenteValidation) {
      final e = validate();
      if (e.isNotEmpty) throw StateError(e.first);
    }
    // Jamais de débit ni de diffusion sans confirmation du propriétaire et paiement validé par le serveur.
    if (to == CampaignStatus.active && !(paymentValidated && confirmedByOwner)) throw StateError('Paiement validé et confirmation du propriétaire requis.');
    return copyWith(status: to);
  }

  /// Enregistre une dépense ; elle ne dépasse jamais le budget ni la limite du jour.
  Campaign spend(int amountFcfa, {required int spentToday}) {
    if (status != CampaignStatus.active) throw StateError('Campagne non active.');
    if (amountFcfa <= 0) throw ArgumentError('Montant invalide.');
    if (spentFcfa + amountFcfa > budgetFcfa) throw StateError('Budget total dépassé.');
    if (spentToday + amountFcfa > dailyBudgetFcfa) throw StateError('Budget quotidien dépassé.');
    final next = copyWith(spentFcfa: spentFcfa + amountFcfa);
    return next.spentFcfa == budgetFcfa ? next.copyWith(status: CampaignStatus.terminee) : next;
  }

  Campaign copyWith({CampaignStatus? status, int? spentFcfa, bool? paymentValidated, bool? confirmedByOwner}) => Campaign(
        id: id, targetId: targetId, budgetFcfa: budgetFcfa, dailyBudgetFcfa: dailyBudgetFcfa, startsAt: startsAt, endsAt: endsAt,
        status: status ?? this.status, spentFcfa: spentFcfa ?? this.spentFcfa,
        paymentValidated: paymentValidated ?? this.paymentValidated, confirmedByOwner: confirmedByOwner ?? this.confirmedByOwner,
      );
}

/// Indicateurs d'une campagne : calculés uniquement à partir de compteurs réels ; `null` quand le dénominateur est nul
/// (aucune statistique n'est inventée).
({double? tauxClic, double? coutParClic}) indicateurs({required int impressions, required int clics, required int depenseFcfa}) =>
    (tauxClic: impressions == 0 ? null : clics / impressions, coutParClic: clics == 0 ? null : depenseFcfa / clics);
