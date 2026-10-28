import '../../core/router/screen_entry.dart';
import 's57_tableau_de_bord/tableau_de_bord_screen.dart';
import 's58_nouveau_produit/nouveau_produit_screen.dart';
import 's59_nouveau_service/nouveau_service_screen.dart';
import 's60_modifier_annonce/modifier_annonce_screen.dart';
import 's61_mon_catalogue/mon_catalogue_screen.dart';
import 's62_stocks/stocks_screen.dart';
import 's63_commandes_recues/commandes_recues_screen.dart';
import 's64_preparer_commande/preparer_commande_screen.dart';
import 's65_detail_vente/detail_vente_screen.dart';
import 's66_revenus/revenus_screen.dart';
import 's67_statistiques/statistiques_screen.dart';
import 's69_validations/validations_screen.dart';

const _s = 'G';

/// Section G · Espace étudiant et vendeur (57–69).
final sectionGScreens = <ScreenEntry>[
  ScreenEntry('57', 'Tableau de bord vendeur', (_) => const TableauDeBordVendeurScreen(), section: _s, node: '37:114'),
  ScreenEntry('58', 'Nouveau produit', (_) => const NouveauProduitScreen(), section: _s, node: '37:226'),
  ScreenEntry('59', 'Nouveau service', (_) => const NouveauServiceScreen(), section: _s, node: '37:300'),
  ScreenEntry('60', 'Modifier l’annonce', (_) => const ModifierAnnonceScreen(), section: _s, node: '37:373'),
  ScreenEntry('61', 'Mon catalogue', (_) => const MonCatalogueScreen(), section: _s, node: '37:426'),
  ScreenEntry('62', 'Stocks', (_) => const StocksScreen(), section: _s, node: '37:520'),
  ScreenEntry('63', 'Commandes reçues', (_) => const CommandesRecuesScreen(), section: _s, node: '37:631'),
  ScreenEntry('64', 'Préparer une commande', (_) => const PreparerCommandeScreen(), section: _s, node: '54:1142'),
  ScreenEntry('65', 'Détail d’une vente', (_) => const DetailVenteScreen(), section: _s, node: '37:707'),
  ScreenEntry('66', 'Revenus', (_) => const RevenusScreen(), section: _s, node: '37:772'),
  ScreenEntry('67', 'Statistiques', (_) => const StatistiquesScreen(), section: _s, node: '37:860'),
  ScreenEntry('69', 'Validations', (_) => const ValidationsScreen(), section: _s, node: '37:1031'),
];
