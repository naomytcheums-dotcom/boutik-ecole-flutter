import '../core/router/screen_entry.dart';
import 'a_demarrage/screens.dart';
import 'b_auth/screens.dart';
import 'c_decouverte/screens.dart';
import 'nouveaux/screens.dart';
import 'n_admin_globale/screens.dart';
import 'e_commandes/screens.dart';
import 'f_communication/screens.dart';
import 'g_espace_etudiant/screens.dart';
import 'i_projets/screens.dart';
import 'k_evenements/screens.dart';
import 'l_departement/screens.dart';
import 'd_fiches/screens.dart';

/// Registre de tous les écrans codés, dans l'ordre du manifeste.
final List<ScreenEntry> allScreens = [
  ...nouveauxScreens,
  ...sectionAScreens,
  ...sectionBScreens,
  ...sectionCScreens,
  ...sectionNScreens,
  ...sectionEScreens,
  ...sectionFScreens,
  ...sectionGScreens,
  ...sectionIScreens,
  ...sectionKScreens,
  ...sectionLScreens,
  ...sectionDScreens,
];
