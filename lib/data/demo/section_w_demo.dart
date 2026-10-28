import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Données de démonstration de la section W (faible connexion, langues, accessibilité : 182–186).
class SectionWData {
  const SectionWData();

  // 182 · Explorer en cours de chargement.
  final exploreTabs = const ['Tous', 'Produits', 'Services', 'Talents'];
  final skeletonCount = 5;

  // 183 · Mes commandes hors connexion (dernière synchronisation).
  final lastSync = 'aujourd’hui 10:24';
  final orders = const [
    (ref: '#BE-2026-0142', status: 'Livrée', amount: 32500, tone: Tone.success),
    (ref: '#BE-2026-0138', status: 'En cours', amount: 17000, tone: Tone.accent),
  ];

  // 184 · Économie de données (réglages locaux en plus du mode économie global).
  final dataToggles = const [
    (title: 'Images basse qualité sur réseau mobile', subtitle: 'Réduit la consommation', value: true),
    (title: 'Téléchargement des vidéos en Wi-Fi uniquement', subtitle: 'Évite les frais de données', value: true),
    (title: 'Synchronisation en arrière-plan', subtitle: 'Uniquement en Wi-Fi', value: false),
  ];
  final dataUsed = '182 Mo';
  final dataSaved = '64 Mo';

  // 185 · Aperçu bilingue.
  final previewLampPrice = 25000;
  final previewLampImage = 'assets/images/w_drone.jpg';

  // 186 · Accessibilité.
  final textSizes = const [('Petit', 0.9), ('Normal', 1.0), ('Grand', 1.2), ('Très grand', 1.4)];
  final norms = const [
    ('Zones tactiles minimales', '44 × 44 px'),
    ('Contraste du texte', '≥ 4,5 : 1'),
    ('Taille de police min.', '12 px'),
  ];
}

final sectionWDataProvider = Provider<SectionWData>((_) => const SectionWData());
