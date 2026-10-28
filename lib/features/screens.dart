import '../core/router/screen_entry.dart';
import 'a_demarrage/screens.dart';
import 'b_auth/screens.dart';
import 'nouveaux/screens.dart';
import 'n_admin_globale/screens.dart';
import 'e_commandes/screens.dart';
import 'f_communication/screens.dart';
import 'g_espace_etudiant/screens.dart';

/// Registre de tous les écrans codés, dans l'ordre du manifeste.
final List<ScreenEntry> allScreens = [
  ...nouveauxScreens,
  ...sectionAScreens,
  ...sectionBScreens,
  ...sectionNScreens,
  ...sectionEScreens,
  ...sectionFScreens,
  ...sectionGScreens,
];
