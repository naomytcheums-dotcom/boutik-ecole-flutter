import '../../core/router/screen_entry.dart';
import 's21_recherche_avancee/recherche_avancee_screen.dart';
import 's22_catalogue_produits/catalogue_produits_screen.dart';
import 's22b_services_prestations/services_prestations_screen.dart';
import 's22c_tendances_nouveautes/tendances_nouveautes_screen.dart';
import 's22d_pour_vous/pour_vous_screen.dart';
import 's23_filtres/filtres_screen.dart';
import 's24_profil_vendeur/profil_vendeur_screen.dart';
import 's25_mes_favoris/mes_favoris_screen.dart';
import 's25b_mes_collections/mes_collections_screen.dart';
import 's26_comparer_offres/comparer_offres_screen.dart';
import 's27_mes_adresses/mes_adresses_screen.dart';
import 's28_mes_commandes/mes_commandes_screen.dart';
import 's29_detail_commande/detail_commande_screen.dart';
import 's30_commande_recue/commande_recue_screen.dart';
import 's31_avis_evaluations/avis_evaluations_screen.dart';

const _s = 'C';

/// Section C · Découverte et achats (21–31).
final sectionCScreens = <ScreenEntry>[
  ScreenEntry('21', 'Recherche avancée', (_) => const RechercheAvanceeScreen(), section: _s, node: '54:502'),
  ScreenEntry('22', 'Catalogue de produits', (_) => const CatalogueProduitsScreen(), section: _s, node: '35:307'),
  ScreenEntry('22b', 'Services et prestations', (_) => const ServicesPrestationsScreen(), section: _s, node: '34:52'),
  ScreenEntry('22c', 'Tendances et nouveautés', (_) => const TendancesNouveautesScreen(), section: _s, node: '35:508'),
  ScreenEntry('22d', 'Pour vous', (_) => const PourVousScreen(), section: _s, node: '35:612'),
  ScreenEntry('23', 'Filtres', (_) => const FiltresScreen(), section: _s, node: '29:185'),
  ScreenEntry('24', 'Profil vendeur', (_) => const ProfilVendeurScreen(), section: _s, node: '29:246'),
  ScreenEntry('25', 'Mes favoris', (_) => const MesFavorisScreen(), section: _s, node: '29:347'),
  ScreenEntry('25b', 'Mes collections', (_) => const MesCollectionsScreen(), section: _s, node: '36:385'),
  ScreenEntry('26', 'Comparer des offres', (_) => const ComparerOffresScreen(), section: _s, node: '29:432'),
  ScreenEntry('27', 'Mes adresses', (_) => const MesAdressesScreen(), section: _s, node: '30:2'),
  ScreenEntry('28', 'Mes commandes', (_) => const MesCommandesClientScreen(), section: _s, node: '30:79'),
  ScreenEntry('29', 'Détail de la commande', (_) => const DetailCommandeScreen(), section: _s, node: '30:147'),
  ScreenEntry('30', 'Commande reçue', (_) => const CommandeRecueScreen(), section: _s, node: '30:209'),
  ScreenEntry('31', 'Avis et évaluations', (_) => const AvisEvaluationsScreen(), section: _s, node: '30:236'),
];
