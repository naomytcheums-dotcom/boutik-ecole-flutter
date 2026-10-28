import '../../core/router/screen_entry.dart';
import 's01_bienvenue/bienvenue_screen.dart';
import 's03_accueil/accueil_screen.dart';
import 's04_explorer/explorer_screen.dart';
import 's05_fiche_produit/fiche_produit_screen.dart';
import 's06_panier/panier_screen.dart';
import 's07_livraison/livraison_screen.dart';
import 's08_paiement/paiement_screen.dart';
import 's09_ma_commande/ma_commande_screen.dart';
import 's10_profil_etudiant/profil_etudiant_screen.dart';

const _s = 'A';

/// Section A · Démarrage et navigation (01–10).
final sectionAScreens = <ScreenEntry>[
  ScreenEntry('01', 'Bienvenue', (_) => const BienvenueScreen(), section: _s, node: '1:29'),
  ScreenEntry('02', 'Bienvenue (variante)', (_) => const BienvenueScreen(), section: _s, node: '2:100'),
  ScreenEntry('03', 'Accueil', (_) => const AccueilScreen(), section: _s, node: '3:3'),
  ScreenEntry('04', 'Explorer', (_) => const ExplorerScreen(), section: _s, node: '18:167'),
  ScreenEntry('05', 'Fiche produit', (_) => const FicheProduitScreen(), section: _s, node: '18:266'),
  ScreenEntry('06', 'Mon panier', (_) => const PanierScreen(), section: _s, node: '14:2'),
  ScreenEntry('07', 'Livraison', (_) => const LivraisonScreen(), section: _s, node: '14:130'),
  ScreenEntry('08', 'Paiement', (_) => const PaiementScreen(), section: _s, node: '14:205'),
  ScreenEntry('09', 'Ma commande', (_) => const MaCommandeScreen(), section: _s, node: '15:2'),
  ScreenEntry('10', 'Profil étudiant', (_) => const ProfilEtudiantScreen(), section: _s, node: '15:96'),
];
