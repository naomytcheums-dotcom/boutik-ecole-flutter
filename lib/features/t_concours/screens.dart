import '../../core/router/screen_entry.dart';
import 's160_hackathons/hackathons_screen.dart';
import 's161_hackathon/hackathon_screen.dart';
import 's162_inscription/inscription_concours_screen.dart';
import 's163_coequipiers/coequipiers_screen.dart';
import 's164_espace_equipe/espace_equipe_screen.dart';
import 's165_depot_projet/depot_projet_screen.dart';
import 's166_resultats/resultats_concours_screen.dart';
import 's167_noter_projet/noter_projet_screen.dart';
import 's168_publier_concours/publier_concours_screen.dart';
import 's169_moderation_concours/moderation_concours_screen.dart';

const _s = 'T';
const _web = ScreenFormat.web;

/// Section T · Hackathons et concours (160–169).
final sectionTScreens = <ScreenEntry>[
  ScreenEntry('160', 'Hackathons et concours', (_) => const HackathonsScreen(), section: _s, node: '60:752'),
  ScreenEntry('161', 'Hackathon', (_) => const HackathonScreen(), section: _s, node: '60:847'),
  ScreenEntry('162', 'Inscription', (_) => const InscriptionConcoursScreen(), section: _s, node: '60:906'),
  ScreenEntry('163', 'Trouver des coéquipiers', (_) => const CoequipiersScreen(), section: _s, node: '60:983'),
  ScreenEntry('164', 'Espace d’équipe', (_) => const EspaceEquipeScreen(), section: _s, node: '60:1053'),
  ScreenEntry('165', 'Dépôt du projet', (_) => const DepotProjetScreen(), section: _s, node: '60:1122'),
  ScreenEntry('166', 'Résultats', (_) => const ResultatsConcoursScreen(), section: _s, node: '60:1187'),
  ScreenEntry('167', 'Noter un projet', (_) => const NoterProjetScreen(), section: _s, node: '60:1254'),
  ScreenEntry(
    '168',
    'Publier un concours',
    (_) => const PublierConcoursScreen(),
    section: _s,
    node: '60:1306',
    format: _web,
  ),
  ScreenEntry(
    '169',
    'Modération des concours',
    (_) => const ModerationConcoursScreen(),
    section: _s,
    node: '60:1415',
    format: _web,
  ),
];
