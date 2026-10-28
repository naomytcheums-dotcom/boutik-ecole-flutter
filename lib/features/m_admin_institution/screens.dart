import '../../core/router/screen_entry.dart';
import 's117_tableau_de_bord/tableau_de_bord_institution_screen.dart';
import 's118_etablissement/etablissement_screen.dart';
import 's119_departements/departements_filieres_screen.dart';
import 's120_utilisateurs/utilisateurs_screen.dart';
import 's121_responsables/responsables_screen.dart';
import 's122_circuits_validation/circuits_validation_screen.dart';
import 's123_ventes_activite/ventes_activite_screen.dart';
import 's124_evenements_campagnes/evenements_campagnes_screen.dart';
import 's125_rapports/rapports_consolides_screen.dart';
import 's126_journal_audit/journal_audit_institution_screen.dart';

const _s = 'M';
const _web = ScreenFormat.web;

/// Section M · Administration institutionnelle (117–126, web).
final sectionMScreens = <ScreenEntry>[
  ScreenEntry('117', 'Tableau de bord institutionnel', (_) => const TableauDeBordInstitutionScreen(), section: _s, node: '148:326', format: _web),
  ScreenEntry('118', 'Établissement et identité visuelle', (_) => const EtablissementScreen(), section: _s, node: '42:187', format: _web),
  ScreenEntry('119', 'Départements et filières', (_) => const DepartementsFilieresScreen(), section: _s, node: '42:317', format: _web),
  ScreenEntry('120', 'Utilisateurs et affectations', (_) => const UtilisateursScreen(), section: _s, node: '42:450', format: _web),
  ScreenEntry('121', 'Responsables et encadreurs', (_) => const ResponsablesScreen(), section: _s, node: '42:593', format: _web),
  ScreenEntry('122', 'Circuits de validation', (_) => const CircuitsValidationScreen(), section: _s, node: '42:729', format: _web),
  ScreenEntry('123', 'Ventes et activité', (_) => const VentesActiviteScreen(), section: _s, node: '42:842', format: _web),
  ScreenEntry('124', 'Événements et campagnes', (_) => const EvenementsCampagnesScreen(), section: _s, node: '42:973', format: _web),
  ScreenEntry('125', 'Rapports consolidés', (_) => const RapportsConsolidesScreen(), section: _s, node: '42:1092', format: _web),
  ScreenEntry('126', 'Journal d’audit', (_) => const JournalAuditInstitutionScreen(), section: _s, node: '42:1212', format: _web),
];
