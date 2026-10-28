import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'catalog_demo.dart';

/// Indicateur des consoles : libellé, valeur, pictogramme, note et tonalité de la note.
typedef OpsKpiData = ({String label, String value, String icon, String? note, Tone tone});

/// Données de démonstration de la section N (administration globale, 127–138).
class SectionNData {
  const SectionNData();

  // 127 · Tableau de bord de la plateforme
  final volumeTitle = 'Volume des transactions (M FCFA)';
  final volumeTotal = 182500000;
  final volumeDelta = '+ 14 %';
  final volumeGain = 22600000;
  final volumeTooltip = ('182 M', 'Octobre 2026');
  final months = const ['Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.'];
  final volumeBars = const [
    0.47, 0.45, 0.52, 0.46, 0.52, 0.51, 0.48, 0.54, 0.48, 0.53, 0.49, 0.49, 0.53, 0.57, 0.49, 0.49, 0.54, 0.57, 0.52, 0.49, //
    0.55, 0.43, 0.51, 0.44, 0.41, 0.39, 0.4, 0.45, 0.37, 0.4, 0.4, 0.36, 0.37, 0.3, 0.29, 0.3, 0.35, 0.31, 0.84, 0.68, //
    0.84, 0.71, 0.85, 0.83, 0.71, 0.85, 0.68, 0.92, 0.63, 0.84, 0.7, 0.8, 0.69, 0.87, 0.71, 0.78, 0.75, 0.74, 0.9, 0.65, //
    0.93, 0.56, 0.9, 0.67, 0.86, 0.72, 0.86, 0.55, 0.5, 0.53, 0.47, 0.55, 0.55, 0.59, 0.58, 0.51, 0.53, 0.56, 0.48, 0.53,
  ];
  final volumeHighlight = (38, 66);
  final volumeCurve = const [0.59, 0.81, 0.62, 0.42, 0.58, 0.82, 0.66, 0.5];

  /// (vignette, établissement, code, utilisateurs, statut, tonalité, ventes en milliers de FCFA).
  final establishments = const [
    (Photos.builder, 'IUT de Douala', 'DLA', 1240, 'Actif', Tone.success, 48700),
    (Photos.foodSpread, 'IUT de Bandjoun', 'BDJ', 860, 'Actif', Tone.neutral, 31200),
    (Photos.solar, 'IUT de Ngaoundéré', 'NGD', 640, 'Actif', Tone.success, 22800),
    (Photos.technician, 'Université partenaire A', 'UPA', 410, 'En intégration', Tone.neutral, 9600),
    (Photos.coder, 'École partenaire B', 'EPB', 280, 'En intégration', Tone.success, 4100),
  ];
  final deploymentGoal = 60;
  final deploymentProgress = const [(60, 'des établissements'), (80, 'de disponibilité')];
  final kelaAvatar = Photos.portraitWoman;
  final kelaQuestion = 'Quels enseignements cherches-tu ?';
  final kelaAnswer =
      'Le réseau compte 3 établissements actifs. 2 sont en cours d’intégration : veux-tu relancer leurs responsables ?';

  // 128 · Comptes, rôles et permissions
  final accounts = const [
    ('Mariam Essono', 'Étudiant-vendeur', 'IUT Douala', 'Actif', Tone.success),
    ('Dr Mbarga', 'Resp. département', 'IUT Douala', 'Actif', Tone.success),
    ('Orange Cameroun', 'Entreprise', '—', 'Actif', Tone.success),
    ('Support 01', 'Support', 'Plateforme', 'Actif', Tone.success),
    ('Carine Mbarga', 'Étudiant', 'IUT Douala', 'Suspendu', Tone.error),
  ];
  final permissions = const [
    ('Valider les annonces', 'Resp. département', true),
    ('Accéder aux finances', 'Finance uniquement', true),
    ('Modifier les commissions', 'Admin global', true),
    ('Exporter les données', 'Direction, finance', false),
  ];

  // 129 · Institutions : (institution, ville, utilisateurs, chiffre d'affaires en FCFA, statut, tonalité)
  final institutions = const [
    ('IUT de Douala', 'Douala', 1240, 28400000, 'Actif', Tone.success),
    ('IUT de Bandjoun', 'Bandjoun', 860, 14900000, 'Actif', Tone.success),
    ('IUT de Ngaoundéré', 'Ngaoundéré', 540, 8100000, 'Actif', Tone.success),
    ('Nouvelle institution', 'Yaoundé', null, null, 'En configuration', Tone.warning),
  ];

  // 130 · Modération : onglets et contenus signalés (contenu, auteur, motif, signalé)
  final moderationTabs = const ['Produits (12)', 'Services (6)', 'Projets (4)', 'Commentaires (18)'];
  final moderationQueues = const [
    [
      ('Lampe en bois recyclé', 'Y. Mouanga', 'Photo non conforme', 'Hier'),
      ('Commentaire sur Sac à dos', 'Anonyme', 'Propos inappropriés', 'Hier'),
      ('Service graphisme', 'A. Bello', 'Prix trompeur', 'Il y a 2 j'),
      ('Drone éducatif', 'Team Innov’', 'Description incomplète', 'Il y a 3 j'),
    ],
    [
      ('Service graphisme', 'A. Bello', 'Prix trompeur', 'Il y a 2 j'),
      ('Cours de soutien Java', 'K. Tagne', 'Coordonnées en clair', 'Il y a 4 j'),
    ],
    [
      ('Drone éducatif', 'Team Innov’', 'Description incomplète', 'Il y a 3 j'),
    ],
    [
      ('Commentaire sur Sac à dos', 'Anonyme', 'Propos inappropriés', 'Hier'),
      ('Avis sur Lampe LED', 'Anonyme', 'Spam', 'Il y a 2 j'),
    ],
  ];

  // 131 · Signalements
  final reportKpis = const <OpsKpiData>[
    (label: 'Ouverts', value: '27', icon: 'assets/icons/flag.svg', note: null, tone: Tone.success),
    (label: 'En traitement', value: '11', icon: 'assets/icons/clock.svg', note: null, tone: Tone.success),
    (label: 'Résolus (30 j)', value: '142', icon: 'assets/icons/check.svg', note: null, tone: Tone.success),
    (label: 'Délai moyen', value: '6 h', icon: 'assets/icons/history.svg', note: null, tone: Tone.success),
  ];
  final reports = const [
    ('Annonce frauduleuse', 'Fraude', 'Il y a 1 h', 'Support 01', 'Urgent', Tone.error),
    ('Avis injurieux', 'Contenu', 'Il y a 3 h', 'Support 02', 'En traitement', Tone.accent),
    ('Photo copiée', 'Propriété', 'Hier', 'Support 01', 'En traitement', Tone.accent),
    ('Vendeur injoignable', 'Service', 'Hier', 'Support 03', 'Ouvert', Tone.warning),
  ];

  // 132 · Commandes et incidents : (commande, client, vendeur, montant, statut, tonalité)
  final orderKpis = const <OpsKpiData>[
    (label: 'Commandes du jour', value: '212', icon: 'assets/icons/receipt.svg', note: null, tone: Tone.success),
    (label: 'En préparation', value: '64', icon: 'assets/icons/package.svg', note: null, tone: Tone.success),
    (label: 'En retard', value: '7', icon: 'assets/icons/clock.svg', note: null, tone: Tone.success),
    (label: 'Incidents', value: '9', icon: 'assets/icons/triangle-alert.svg', note: null, tone: Tone.success),
  ];
  final orders = const [
    ('#BE-2026-0142', 'Y. Mouanga', 'M. Essono', 25000, 'Livrée', Tone.success),
    ('#BE-2026-0138', 'A. Bello', 'B. Ndoumbe', 17000, 'En retard', Tone.error),
    ('#BE-2026-0127', 'K. Tagne', 'A. Bello', 45000, 'Incident', Tone.warning),
    ('#BE-2026-0119', 'C. Mbarga', 'Y. Mouanga', 28000, 'Annulée', Tone.neutral),
  ];

  // 133 · Litiges et remboursements : (dossier, commande, motif, montant, statut, tonalité)
  final disputeTabs = const ['Litiges (6)', 'Remboursements (4)', 'Réclamations (9)'];
  final disputeQueues = const [
    [
      ('LIT-0042', '#BE-2026-0138', 'Article non reçu', 17000, 'À arbitrer', Tone.error),
      ('LIT-0041', '#BE-2026-0127', 'Article non conforme', 45000, 'En médiation', Tone.warning),
      ('LIT-0039', '#BE-2026-0119', 'Annulation tardive', 28000, 'Remboursé', Tone.success),
    ],
    [
      ('RMB-0018', '#BE-2026-0119', 'Annulation tardive', 28000, 'Remboursé', Tone.success),
      ('RMB-0017', '#BE-2026-0111', 'Double paiement', 12000, 'En cours', Tone.accent),
    ],
    [
      ('REC-0031', '#BE-2026-0140', 'Retard de livraison', 9000, 'Ouvert', Tone.warning),
    ],
  ];
  final disputeNote = 'Les décisions de remboursement sont tracées dans le journal d’audit.';

  // 134 · Transactions et rapprochements : (référence, moyen, montant, date, rapprochement, tonalité)
  final transactionKpis = const <OpsKpiData>[
    (label: 'Transactions (30 j)', value: '4 820', icon: 'assets/icons/wallet.svg', note: '+12 %', tone: Tone.success),
    (label: 'Rapprochées', value: '4 764', icon: 'assets/icons/check.svg', note: '98,8 %', tone: Tone.success),
    (label: 'Écarts', value: '56', icon: 'assets/icons/triangle-alert.svg', note: 'À analyser', tone: Tone.error),
    (label: 'En attente', value: '18', icon: 'assets/icons/clock.svg', note: 'Mobile Money', tone: Tone.warning),
  ];
  final transactions = const [
    ('TX-88421', 'Orange Money', 25000, '22 oct.', 'Rapproché', Tone.success),
    ('TX-88420', 'MTN MoMo', 17000, '22 oct.', 'Écart', Tone.error),
    ('TX-88419', 'Orange Money', 45000, '21 oct.', 'En attente', Tone.warning),
  ];

  // 135 · Commissions et règles économiques
  final commissionRules = const [
    ('Commission sur les produits', '5 %'),
    ('Commission sur les services', '7 %'),
    ('Commission financement participatif', '4 %'),
    ('Frais de retrait kiosque', 'Gratuit'),
  ];
  final sellerPayoutThreshold = 10000;
  final lastCommissionChange = '01 sept. 2026';
  final commissionNote =
      'Ces règles financières ne sont pas figées : elles restent configurables et doivent être confirmées avec l’IUT avant toute mise en production.';

  // 136 · Sécurité et accès
  final securityRules = const [
    ('Double authentification obligatoire', 'Pour les rôles sensibles', true),
    ('Expiration des sessions', 'Après 30 min d’inactivité', true),
    ('Blocage après 5 échecs', 'Connexion temporairement bloquée', true),
    ('Restriction par adresse IP', 'Espaces administrateurs', false),
  ];
  final sessions = const [
    ('Super admin', 'Chrome · Windows', 'Maintenant'),
    ('Direction', 'Safari · macOS', 'Il y a 12 min'),
    ('Finance', 'Chrome · Windows', 'Il y a 1 h'),
  ];

  // 137 · Journal d'audit global : (date, acteur, action, cible, institution, niveau, tonalité, catégorie)
  final auditFilters = const ['Tout', 'Comptes', 'Finances', 'Modération', 'Configuration'];
  final auditEntries = const [
    ('22 oct. 10:31', 'Super admin', 'Commission modifiée', 'Produits 5 %', 'Plateforme', 'Critique', Tone.error, 'Finances'),
    ('22 oct. 10:12', 'Support 01', 'Contenu retiré', 'Annonce #4412', 'IUT Douala', 'Sensible', Tone.warning, 'Modération'),
    ('22 oct. 09:40', 'Finance', 'Rapprochement validé', 'Lot du 21 oct.', 'IUT Douala', 'Normal', Tone.neutral, 'Finances'),
    ('21 oct. 17:05', 'Super admin', 'Rôle attribué', 'Finance', 'Plateforme', 'Sensible', Tone.warning, 'Comptes'),
  ];

  // 138 · Configuration générale
  final modules = const [
    ('Financement participatif', 'Module de campagnes', true),
    ('Messagerie interne', 'Entre acheteurs et vendeurs', true),
    ('Marketplace inter-IUT', 'Catalogue multi-établissements', true),
    ('Défis entreprises', 'Espace B2B', false),
  ];
  final integrations = const [
    ('assets/icons/wallet.svg', 'Paiement Mobile Money', 'Orange Money, MTN MoMo', 'À configurer', Tone.warning),
    ('assets/icons/mail.svg', 'E-mail transactionnel', 'Notifications et reçus', 'Actif', Tone.success),
    ('assets/icons/smartphone.svg', 'SMS et OTP', 'Vérification des comptes', 'Actif', Tone.success),
    ('assets/icons/map.svg', 'Cartographie', 'Carte de l’innovation', 'Actif', Tone.success),
  ];
  final configNote = 'Les intégrations de paiement restent à confirmer avec l’IUT et ses partenaires.';
}

final sectionNDataProvider = Provider<SectionNData>((_) => const SectionNData());
