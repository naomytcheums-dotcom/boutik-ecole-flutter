import '../../core/router/screen_entry.dart';
import 's187_tableau_de_bord/tableau_de_bord_screen.dart';
import 's188_recherche_talents/recherche_talents_screen.dart';
import 's189_propositions_recues/propositions_recues_screen.dart';
import 's190_devis_negociations/devis_negociations_screen.dart';

const _s = 'X';
const _web = ScreenFormat.web;

/// Section X · Web entreprise (187–190).
final sectionXScreens = <ScreenEntry>[
  ScreenEntry(
    '187',
    'Tableau de bord entreprise',
    (_) => const TableauDeBordEntrepriseScreen(),
    section: _s,
    node: '148:1256',
    format: _web,
  ),
  ScreenEntry(
    '188',
    'Recherche de talents et d’équipes',
    (_) => const RechercheTalentsScreen(),
    section: _s,
    node: '61:1366',
    format: _web,
  ),
  ScreenEntry(
    '189',
    'Propositions reçues',
    (_) => const PropositionsRecuesWebScreen(),
    section: _s,
    node: '61:1493',
    format: _web,
  ),
  ScreenEntry(
    '190',
    'Devis et négociations',
    (_) => const DevisNegociationsWebScreen(),
    section: _s,
    node: '61:1610',
    format: _web,
  ),
];
