import '../core/router/screen_entry.dart';
import '../figma/registry.dart';
import 'a_demarrage/screens.dart';
import 'b_auth/screens.dart';
import 'c_decouverte/screens.dart';
import 'nouveaux/screens.dart';
import 'n_admin_globale/screens.dart';
import 'o_finance/screens.dart';
import 'p_exploitation/screens.dart';
import 'q_parametres/screens.dart';
import 's_opportunites/screens.dart';
import 't_concours/screens.dart';
import 'u_confiance/screens.dart';
import 'v_onboarding/screens.dart';
import 'w_connexion/screens.dart';
import 'e_commandes/screens.dart';
import 'f_communication/screens.dart';
import 'g_espace_etudiant/screens.dart';
import 'h_talents/screens.dart';
import 'i_projets/screens.dart';
import 'k_evenements/screens.dart';
import 'l_departement/screens.dart';
import 'm_admin_institution/screens.dart';
import 'd_fiches/screens.dart';
import 'j_entreprises/screens.dart';
import 'am_cercle/screens.dart';
import 'ad_innovations/screens.dart';
import 'y_missions/screens.dart';
import 'aa_borne/screens.dart';
import 'x_web_entreprise/screens.dart';
import 'ai_kela/screens.dart';
import 'ref_echantillons/screens.dart';

/// Registre de tous les écrans codés, dans l'ordre du manifeste.
final List<ScreenEntry> _baseScreens = [
  ...nouveauxScreens,
  ...sectionAScreens,
  ...sectionBScreens,
  ...sectionCScreens,
  ...sectionNScreens,
  ...sectionOScreens,
  ...sectionPScreens,
  ...sectionQScreens,
  ...sectionSScreens,
  ...sectionTScreens,
  ...sectionUScreens,
  ...sectionVScreens,
  ...sectionWScreens,
  ...sectionEScreens,
  ...sectionFScreens,
  ...sectionGScreens,
  ...sectionHScreens,
  ...sectionIScreens,
  ...sectionKScreens,
  ...sectionLScreens,
  ...sectionMScreens,
  ...sectionDScreens,
  ...sectionJScreens,
  ...sectionAMScreens,
  ...sectionADScreens,
  ...sectionYScreens,
  ...sectionAAScreens,
  ...sectionXScreens,
  ...sectionAIScreens,
  ...sectionREFScreens,
];

/// Les écrans générés fidèlement depuis Figma (lib/figma/g) remplacent la version écrite à la main.
final List<ScreenEntry> allScreens = [
  for (final e in _baseScreens)
    gBuilders.containsKey(e.id)
        ? ScreenEntry(e.id, e.title, gBuilders[e.id]!, section: e.section, node: e.node, format: _formatOf(gWidths[e.id], e.format))
        : e,
];

ScreenFormat _formatOf(double? w, ScreenFormat fallback) {
  if (w == null) return fallback;
  if (w == 720) return ScreenFormat.kiosk;
  if (w == 768) return ScreenFormat.tablet;
  return w >= 1000 ? ScreenFormat.web : ScreenFormat.mobile;
}
