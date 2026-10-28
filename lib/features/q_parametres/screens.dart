import '../../core/router/screen_entry.dart';
import 's148_centre_securite/centre_securite_screen.dart';
import 's148_parametres/parametres_screen.dart';
import 's149_langue_affichage/langue_affichage_screen.dart';
import 's150_commandes_vide/commandes_vide_screen.dart';
import 's150_connexion_impossible/connexion_impossible_screen.dart';
import 's150_session_expiree/session_expiree_screen.dart';
import 's150_synchronisation/synchronisation_screen.dart';

const _s = 'Q';

/// Section Q · Paramètres et états système (148–150).
final sectionQScreens = <ScreenEntry>[
  ScreenEntry('148-1', 'Paramètres', (_) => const ParametresScreen(), section: _s, node: '40:706'),
  ScreenEntry('148-2', 'Centre de sécurité', (_) => const CentreSecuriteScreen(), section: _s, node: '22:339'),
  ScreenEntry('149', 'Langue et affichage', (_) => const LangueAffichageScreen(), section: _s, node: '40:862'),
  ScreenEntry('150-1', 'Synchronisation', (_) => const SynchronisationScreen(), section: _s, node: '40:1056'),
  ScreenEntry('150-2', 'Session expirée', (_) => const SessionExpireeScreen(), section: _s, node: '40:1018'),
  ScreenEntry('150-3', 'Connexion impossible', (_) => const ConnexionImpossibleScreen(), section: _s, node: '40:969'),
  ScreenEntry('150-4', 'Mes commandes (vide)', (_) => const CommandesVideScreen(), section: _s, node: '40:918'),
];
