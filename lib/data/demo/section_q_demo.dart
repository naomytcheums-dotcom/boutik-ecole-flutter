import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';

/// Données de démonstration de la section Q (paramètres et états système, 148–150).
class SectionQData {
  const SectionQData();

  // 148-1 · Paramètres
  final userName = 'Mariam Essono';
  final userMail = 'mariam@iut-douala.cm';
  final userAvatar = 'assets/images/q_av_mariam.jpg';

  /// (icône, libellé, valeur à droite, écran cible).
  final settings = const [
    (AppIcons.user, 'Informations personnelles', '', '18b'),
    (AppIcons.mapPin, 'Adresses', '', '27'),
    (AppIcons.wallet, 'Moyens de paiement', '', '08'),
    (AppIcons.bell, 'Notifications', '', '50'),
    (AppIcons.globe, 'Langue et affichage', 'Français', '149'),
    (AppIcons.circleHelp, 'Aide et support', '', '48'),
  ];

  // 148-2 · Centre de sécurité
  final securityLevel = 'Élevé';
  final securityScore = 80;
  final passwordAge = 'Modifié il y a 3 mois';
  final verifiedPhone = '+237 6•• •• •• 42';

  /// (icône, appareil, détail, appareil courant).
  final sessions = const [
    (AppIcons.smartphone, 'iPhone 14 • Cet appareil', 'Douala, Cameroun • Active maintenant', true),
    (AppIcons.monitor, 'Chrome • Windows', 'Yaoundé, Cameroun • Il y a 2 jours', false),
  ];

  // 150-1 · Synchronisation
  final syncPercent = 72;
  final syncDetail = '3 éléments sur 4 envoyés';

  /// (icône, élément, détail, statut, tonalité).
  final syncItems = const [
    (AppIcons.shoppingCart, 'Panier', 'Synchronisé', 'OK', Tone.success),
    (AppIcons.heart, 'Favoris', 'Synchronisé', 'OK', Tone.success),
    (AppIcons.messageCircle, 'Messages', 'En attente d’envoi', 'En attente', Tone.warning),
  ];
  final lastSync = 'Aujourd’hui 10:24';
  final serviceStatus = 'Opérationnel';

  // 150-4 · Mes commandes (vide)
  final orderTabs = const ['Toutes', 'En cours', 'Livrées', 'Annulées'];
}

final sectionQDataProvider = Provider<SectionQData>((_) => const SectionQData());
