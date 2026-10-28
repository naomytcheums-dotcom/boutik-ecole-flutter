import '../../core/router/screen_entry.dart';
import 's32_detail_produit/detail_produit_screen.dart';
import 's33_histoire_produit/histoire_produit_screen.dart';
import 's34_galerie/galerie_screen.dart';
import 's35_disponibilite/disponibilite_screen.dart';
import 's36_detail_service/detail_service_screen.dart';
import 's38_reputation/reputation_screen.dart';
import 's39_demande_renseignements/demande_renseignements_screen.dart';
import 's40_demande_devis/demande_devis_screen.dart';

const _s = 'D';

/// Section D · Fiches produits, services, prestataires (32–40).
final sectionDScreens = <ScreenEntry>[
  ScreenEntry('32', 'Détail du produit', (_) => const DetailProduitScreen(), section: _s, node: '36:140'),
  ScreenEntry('33', 'Histoire du produit', (_) => const HistoireProduitScreen(), section: _s, node: '54:2'),
  ScreenEntry('34', 'Galerie', (_) => const GalerieScreen(), section: _s, node: '35:828'),
  ScreenEntry('35', 'Disponibilité', (_) => const DisponibiliteScreen(), section: _s, node: '35:1033'),
  ScreenEntry('36', 'Détail du service', (_) => const DetailServiceScreen(), section: _s, node: '35:870'),
  ScreenEntry('38', 'Réputation', (_) => const ReputationScreen(), section: _s, node: '54:606'),
  ScreenEntry(
    '39',
    'Demande de renseignements',
    (_) => const DemandeRenseignementsScreen(),
    section: _s,
    node: '54:674',
  ),
  ScreenEntry('40', 'Demande de devis', (_) => const DemandeDevisScreen(), section: _s, node: '36:752'),
];
