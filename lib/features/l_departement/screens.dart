import '../../core/router/screen_entry.dart';
import 's108_tableau_de_bord/tableau_de_bord_departement_screen.dart';
import 's109_etudiants_vendeurs/etudiants_vendeurs_screen.dart';
import 's110_validation_annonces/validation_annonces_screen.dart';
import 's111_validation_projets/validation_projets_screen.dart';
import 's112_statistiques/statistiques_departement_screen.dart';
import 's113_suivi_productions/suivi_productions_screen.dart';
import 's114_mentors/mentors_screen.dart';
import 's115_evenements/evenements_departement_screen.dart';
import 's116_rapports/rapports_departement_screen.dart';
import 's214_departements/departements_screen.dart';
import 's215_fiche_departement/fiche_departement_screen.dart';

const _s = 'L';
const _web = ScreenFormat.web;

/// Section L · Département (108–116 web, 214–215 mobile).
final sectionLScreens = <ScreenEntry>[
  ScreenEntry('108', 'Tableau de bord du département', (_) => const TableauDeBordDepartementScreen(), section: _s, node: '148:16', format: _web),
  ScreenEntry('109', 'Étudiants et vendeurs', (_) => const EtudiantsVendeursScreen(), section: _s, node: '41:188', format: _web),
  ScreenEntry('110', 'Validation des annonces', (_) => const ValidationAnnoncesScreen(), section: _s, node: '41:341', format: _web),
  ScreenEntry('111', 'Validation des projets', (_) => const ValidationProjetsScreen(), section: _s, node: '41:480', format: _web),
  ScreenEntry('112', 'Statistiques du département', (_) => const StatistiquesDepartementScreen(), section: _s, node: '41:611', format: _web),
  ScreenEntry('113', 'Suivi des productions', (_) => const SuiviProductionsScreen(), section: _s, node: '41:757', format: _web),
  ScreenEntry('114', 'Mentors et encadreurs', (_) => const MentorsScreen(), section: _s, node: '41:891', format: _web),
  ScreenEntry('115', 'Événements et initiatives', (_) => const EvenementsDepartementScreen(), section: _s, node: '41:1014', format: _web),
  ScreenEntry('116', 'Rapports et exports', (_) => const RapportsDepartementScreen(), section: _s, node: '41:1153', format: _web),
  ScreenEntry('214', 'Départements', (_) => const DepartementsScreen(), section: _s, node: '83:961'),
  ScreenEntry('215', 'Fiche département', (_) => const FicheDepartementScreen(), section: _s, node: '83:1094'),
];
