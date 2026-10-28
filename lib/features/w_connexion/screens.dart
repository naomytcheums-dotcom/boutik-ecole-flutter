import '../../core/router/screen_entry.dart';
import 's182_explorer_chargement/explorer_chargement_screen.dart';
import 's183_commandes_hors_ligne/commandes_hors_ligne_screen.dart';
import 's184_economie_donnees/economie_donnees_screen.dart';
import 's185_language/language_screen.dart';
import 's186_accessibilite/accessibilite_screen.dart';

const _s = 'W';

final sectionWScreens = <ScreenEntry>[
  ScreenEntry('182', 'Explorer (chargement)', (_) => const ExplorerChargementScreen(), section: _s, node: '61:884'),
  ScreenEntry(
    '183',
    'Mes commandes (hors ligne)',
    (_) => const CommandesHorsLigneScreen(),
    section: _s,
    node: '61:968',
  ),
  ScreenEntry('184', 'Économie de données', (_) => const EconomieDonneesScreen(), section: _s, node: '61:1035'),
  ScreenEntry('185', 'Language', (_) => const LanguageScreen(), section: _s, node: '61:1084'),
  ScreenEntry('186', 'Accessibilité', (_) => const AccessibiliteScreen(), section: _s, node: '61:1153'),
];
