import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';

/// Données de démonstration de la section P (kiosques, support, exploitation : 145–147).
class SectionPData {
  const SectionPData();

  // 145 · Points de retrait et kiosques
  /// (point de retrait, lieu, retraits du jour, état, tonalité).
  final pickupPoints = const [
    ('Kiosque Bloc A', 'IUT Douala', 24, 'En ligne', Tone.success),
    ('Kiosque Bloc B', 'IUT Douala', 11, 'En ligne', Tone.success),
    ('Kiosque Bibliothèque', 'IUT Douala', 7, 'Hors ligne', Tone.error),
    ('Kiosque Cafétéria', 'IUT Douala', 15, 'En ligne', Tone.success),
  ];
  final networkMap = 'assets/images/p_carte_kiosques.png';
  final networkName = 'Douala · Littoral';
  final networkDetail = '4 kiosques · IUT de Douala';

  // 146-1 · Kiosque (gestionnaire, mobile)
  final kioskName = 'Kiosque Bloc A';
  final kioskRole = 'Gestionnaire · Service retraits';
  final kioskKpis = const [
    ('Retraits du jour', '24', AppIcons.package, '', Tone.neutral),
    ('À remettre', '9', AppIcons.clock, 'Avant 17 h', Tone.warning),
    ('Colis en attente', '31', AppIcons.inbox, '', Tone.neutral),
    ('Incidents', '1', AppIcons.triangleAlert, 'Casier 12 bloqué', Tone.error),
  ];

  /// (commande, client · casier, statut, tonalité, vignette).
  final toHandOver = const [
    ('#BE-2026-0142', 'Y. Mouanga · Casier 04', 'Prêt', Tone.success, 'assets/images/p_cmd_0142.jpg'),
    ('#BE-2026-0141', 'A. Bello · Casier 07', 'Prêt', Tone.success, 'assets/images/p_cmd_0141.jpg'),
    ('#BE-2026-0139', 'B. Ndoumbe · Casier 09', 'En attente', Tone.warning, 'assets/images/p_cmd_0139.jpg'),
  ];

  // 146-2 · Remise d'une commande
  final handoverClient = 'Yannick Mouanga';
  final handoverOrder = '#BE-2026-0142';
  final handoverAvatar = 'assets/images/p_av_yannick.jpg';
  final handoverQr = 'assets/images/p_qr_retrait.png';
  final handoverLocker = '04';
  final handoverItems = 'Lampe en bois recyclé';
  final handoverAmount = 25000;
  final pickupCode = '482915';

  // 147-1 · Incidents et maintenance
  final incidentKpis = const [
    ('Incidents ouverts', '4', AppIcons.triangleAlert),
    ('En maintenance', '1', AppIcons.settings),
    ('Résolus (30 j)', '22', AppIcons.check),
    ('Disponibilité', '98,6 %', AppIcons.server),
  ];

  /// (incident, kiosque, ouvert, priorité, tonalité priorité, statut, tonalité statut).
  final incidents = const [
    ('Casier 12 bloqué', 'Bloc A', 'Il y a 2 h', 'Haute', Tone.error, 'En cours', Tone.accent),
    ('Écran tactile figé', 'Bibliothèque', 'Hier', 'Moyenne', Tone.accent, 'Assigné', Tone.accent),
    ('Imprimante de reçus', 'Cafétéria', 'Il y a 3 j', 'Faible', Tone.neutral, 'Ouvert', Tone.warning),
  ];

  // 147-2 · Tickets de support
  final ticketTabs = const ['Ouverts (14)', 'En cours (6)', 'Résolus', 'Escaladés'];

  /// (ticket, sujet, demandeur, reçu, statut, tonalité).
  final tickets = const [
    ('#T-2041', 'Paiement non reconnu', 'M. Essono', 'Il y a 1 h', 'Urgent', Tone.error),
    ('#T-2040', 'Retrait impossible', 'Y. Mouanga', 'Il y a 3 h', 'En cours', Tone.accent),
    ('#T-2038', 'Modifier une annonce', 'A. Bello', 'Hier', 'Ouvert', Tone.warning),
    ('#T-2035', 'Compte bloqué', 'C. Mbarga', 'Hier', 'Escaladé', Tone.neutral),
  ];

  // 147-3 · Interventions et résolutions
  final interventionSteps = const [
    ('Casier 12 : diagnostic', '22 oct. · Technicien A. Kamga', 0),
    ('Pièce commandée', '22 oct. · Livraison 24 oct.', 1),
    ('Remplacement du verrou', 'Prévu le 24 oct.', 2),
  ];

  /// (intervention, kiosque, technicien, durée, résultat, tonalité).
  final interventions = const [
    ('Remplacement écran', 'Bibliothèque', 'A. Kamga', '2 h', 'Résolu', Tone.success),
    ('Mise à jour logiciel', 'Bloc B', 'A. Kamga', '45 min', 'Résolu', Tone.success),
    ('Casier 12', 'Bloc A', 'A. Kamga', 'En cours', 'En cours', Tone.accent),
  ];
}

final sectionPDataProvider = Provider<SectionPData>((_) => const SectionPData());
