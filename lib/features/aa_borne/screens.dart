import '../../core/router/screen_entry.dart';
import 's206_accueil_borne/accueil_borne_screen.dart';
import 's207_explorer_borne/explorer_borne_screen.dart';
import 's208_fiche_borne/fiche_borne_screen.dart';
import 's209_qr_borne/qr_borne_screen.dart';
import 's210_envoye_borne/envoye_borne_screen.dart';

const _s = 'AA';
const _k = ScreenFormat.kiosk;

final sectionAAScreens = <ScreenEntry>[
  ScreenEntry('206', 'Borne · Accueil', (_) => const AccueilBorneScreen(), section: _s, node: '83:1733', format: _k),
  ScreenEntry('207', 'Borne · Explorer', (_) => const ExplorerBorneScreen(), section: _s, node: '83:1783', format: _k),
  ScreenEntry(
    '208',
    'Borne · Fiche article',
    (_) => const FicheBorneScreen(),
    section: _s,
    node: '83:1833',
    format: _k,
  ),
  ScreenEntry('209', 'Borne · QR téléphone', (_) => const QrBorneScreen(), section: _s, node: '83:1870', format: _k),
  ScreenEntry(
    '210',
    'Borne · C’est envoyé',
    (_) => const EnvoyeBorneScreen(),
    section: _s,
    node: '83:2241',
    format: _k,
  ),
];
