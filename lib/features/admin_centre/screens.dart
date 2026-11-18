import '../../core/router/screen_entry.dart';
import '../../figma/live/admin_centre.dart';
import '../../figma/live/admin_equipes.dart';

/// Centre d'administration et équipes internes (lot H4) : hub 300, tableaux de bord des équipes 301 à 304, gestion des équipes et permissions 305,
/// comptes suspects 306. Écrans mobiles ajoutés après la maquette ; ils réutilisent les écrans existants (127 à 147, 264 à 284) rangés par équipe.
const _s = 'CENTRE';
const _n = 'H4';

final sectionCentreScreens = <ScreenEntry>[
  ScreenEntry('300', 'Centre d’administration', (_) => const AdminCentreScreen(), section: _s, node: _n),
  ScreenEntry('301', 'Équipe Finance', (_) => const AdminTeamScreen(team: 'finance'), section: _s, node: _n),
  ScreenEntry('302', 'Équipe Support', (_) => const AdminTeamScreen(team: 'support'), section: _s, node: _n),
  ScreenEntry('303', 'Équipe Sécurité et modération', (_) => const AdminTeamScreen(team: 'security'), section: _s, node: _n),
  ScreenEntry('304', 'Équipe Technique', (_) => const AdminTeamScreen(team: 'tech'), section: _s, node: _n),
  ScreenEntry('305', 'Équipes et permissions', (_) => const AdminTeamsScreen(), section: _s, node: _n),
  ScreenEntry('306', 'Comptes suspects', (_) => const SecurityFlagsScreen(), section: _s, node: _n),
];
