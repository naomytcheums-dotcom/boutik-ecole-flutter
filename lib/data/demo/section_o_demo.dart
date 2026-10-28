import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Données de démonstration de la section O (finance et paiements, 139–144).
class SectionOData {
  const SectionOData();

  final account = 'Finance';
  final accountMail = 'finance@iut-douala.cm';
  final accountSubtitle = 'Finance et opérations';

  // 139 · Tableau de bord financier
  final flowTitle = 'Flux financiers (M FCFA)';
  final flowTotal = 48200000;
  final flowDelta = '+ 12 %';
  final flowGain = 5100000;
  final flowTooltip = ('48,2 M', 'Octobre 2026');
  final months = const ['Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.'];
  final flowBars = const [
    0.31, 0.29, 0.34, 0.30, 0.35, 0.33, 0.30, 0.36, 0.31, 0.35, 0.33, 0.32, 0.36, 0.38, 0.32, 0.33, 0.36, 0.38, 0.34, 0.33, //
    0.37, 0.30, 0.34, 0.31, 0.29, 0.28, 0.29, 0.31, 0.27, 0.29, 0.29, 0.26, 0.27, 0.24, 0.23, 0.24, 0.26, 0.25, 0.72, 0.56, //
    0.79, 0.63, 0.81, 0.77, 0.63, 0.83, 0.59, 0.91, 0.57, 0.81, 0.63, 0.73, 0.61, 0.83, 0.63, 0.71, 0.67, 0.67, 0.85, 0.57, //
    0.89, 0.49, 0.85, 0.59, 0.81, 0.63, 0.79, 0.47, 0.41, 0.43, 0.39, 0.45, 0.45, 0.47, 0.46, 0.41, 0.43, 0.46, 0.39, 0.43,
  ];
  final flowHighlight = (38, 66);
  final flowCurve = const [0.56, 0.71, 0.53, 0.39, 0.53, 0.77, 0.61, 0.47];

  /// (vignette, référence, détail, type, statut, tonalité, montant).
  final lastFlows = const [
    (Photos.lamp, 'TX-88421', '22 oct. · Orange Money', 'Encaissement', 'Vérifié', Tone.success, 25000),
    (Photos.coder, 'RV-1204', '22 oct. · Mobile Money', 'Reversement', 'Programmé', Tone.neutral, 23750),
    (Photos.bulb, 'TX-88420', '22 oct. · Espèces kiosque', 'Encaissement', 'À vérifier', Tone.success, 17000),
    (Photos.sketch, 'TX-88419', '21 oct. · Orange Money', 'Encaissement', 'Vérifié', Tone.neutral, 45000),
    (Photos.solar, 'RV-1203', '21 oct. · Mobile Money', 'Reversement', 'Programmé', Tone.success, 60000),
  ];
  final cashGoal = 78;
  final cashProgress = const [(78, 'des encaissements'), (80, 'des reversements')];
  final kelaAvatar = Photos.portraitWoman;
  final kelaQuestion = 'Quels enseignements cherches-tu ?';
  final kelaAnswer =
      'Les reversements vendeurs progressent de 6 %. 18 paiements attendent ta vérification : veux-tu les passer en revue ?';

  // 140 · Paiements déclarés
  final paymentTabs = const ['À vérifier (18)', 'Vérifiés', 'Rejetés'];

  /// (référence, commande, moyen, montant, déclaré, statut, tonalité).
  final declared = const [
    ('TX-88420', '#BE-2026-0138', 'MTN MoMo', 17000, 'Il y a 2 h', 'À vérifier', Tone.accent),
    ('TX-88419', '#BE-2026-0135', 'Orange Money', 45000, 'Il y a 3 h', 'À vérifier', Tone.accent),
    ('TX-88417', '#BE-2026-0131', 'Orange Money', 12000, 'Hier', 'Vérifié', Tone.success),
    ('TX-88410', '#BE-2026-0128', 'MTN MoMo', 8000, 'Hier', 'Rejeté', Tone.error),
  ];

  // 141 · Journal financier
  /// (date, libellé, débit, crédit, rapproché).
  final journal = const [
    ('22 oct.', 'Encaissement #0142', 0, 25000, true),
    ('22 oct.', 'Commission plateforme', 0, 1250, true),
    ('22 oct.', 'Reversement vendeur', 23750, 0, true),
    ('21 oct.', 'Encaissement #0138', 0, 17000, false),
  ];

  // 142 · Rapports financiers
  final periods = const ['Mois', 'Trimestre', 'Année'];
  final cashByDepartment = const [('Info', 9.8), ('Civil', 7.9), ('MMI', 6.2), ('Élec.', 4.5), ('Agro', 3.0)];
  final sellers = const [('M. Essono', 1245000, 62250), ('Y. Mouanga', 860000, 43000), ('A. Bello', 540000, 27000), ('B. Ndoumbe', 320000, 16000)];

  // 143 · Versements et montants dus
  final payoutKpis = const [
    ('Versé (30 j)', '44 590 000 FCFA', AppIcons.send, ''),
    ('Montants dus', '3 120 000 FCFA', AppIcons.clock, 'Prochain lot le 26 oct.'),
    ('Vendeurs concernés', '142', AppIcons.users, ''),
    ('Rejets', '3', AppIcons.triangleAlert, ''),
  ];

  /// (lot, vendeur, montant, moyen, date, statut, tonalité).
  final payouts = const [
    ('RV-1204', 'Mariam Essono', 23750, 'Orange Money', '22 oct.', 'Versé', Tone.success),
    ('RV-1203', 'Yannick Mouanga', 41800, 'MTN MoMo', '22 oct.', 'Versé', Tone.success),
    ('RV-1202', 'Aminata Bello', 18900, 'Orange Money', '21 oct.', 'Programmé', Tone.accent),
    ('RV-1201', 'Brice Ndoumbe', 7600, 'MTN MoMo', '21 oct.', 'Rejeté', Tone.error),
  ];

  // 144 · Moyens de paiement et règles
  final methods = const [
    ('Orange Money', 'Paiement marchand', AppIcons.wallet, 'Actif', Tone.success),
    ('MTN MoMo', 'Paiement marchand', AppIcons.wallet, 'Actif', Tone.success),
    ('Espèces au kiosque', 'Pour les retraits sur place', AppIcons.store, 'À confirmer', Tone.accent),
    ('Carte bancaire', 'Non disponible', AppIcons.creditCard, 'Inactif', Tone.neutral),
  ];
  final rules = const [
    ('Délai de vérification', '24 h ouvrées'),
    ('Seuil de versement vendeur', '10 000 FCFA'),
    ('Fréquence des versements', 'Hebdomadaire'),
    ('Devise', 'FCFA (XAF)'),
  ];
}

final sectionODataProvider = Provider<SectionOData>((_) => const SectionOData());
