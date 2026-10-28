import '../../core/router/screen_entry.dart';
import 's175_bienvenue_etudiant/bienvenue_etudiant_screen.dart';
import 's176_bienvenue_client/bienvenue_client_screen.dart';
import 's177_bienvenue_entreprise/bienvenue_entreprise_screen.dart';
import 's178_bienvenue_jury/bienvenue_jury_screen.dart';
import 's179_guide/guide_screen.dart';
import 's180_roles_permissions/roles_permissions_screen.dart';
import 's181_matrice_permissions/matrice_permissions_screen.dart';

const _s = 'V';

final sectionVScreens = <ScreenEntry>[
  ScreenEntry('175', 'Bienvenue, étudiant', (_) => const BienvenueEtudiantScreen(), section: _s, node: '61:306'),
  ScreenEntry('176', 'Bienvenue', (_) => const BienvenueClientScreen(), section: _s, node: '61:360'),
  ScreenEntry('177', 'Bienvenue, entreprise', (_) => const BienvenueEntrepriseScreen(), section: _s, node: '61:413'),
  ScreenEntry('178', 'Bienvenue, jury', (_) => const BienvenueJuryScreen(), section: _s, node: '61:466'),
  ScreenEntry('179', 'Guide d’utilisation', (_) => const GuideScreen(), section: _s, node: '61:516'),
  ScreenEntry(
    '180',
    'Rôles et permissions',
    (_) => const RolesPermissionsScreen(),
    section: _s,
    node: '61:612',
    format: ScreenFormat.web,
  ),
  ScreenEntry(
    '181',
    'Matrice des permissions',
    (_) => const MatricePermissionsScreen(),
    section: _s,
    node: '61:740',
    format: ScreenFormat.web,
  ),
];
