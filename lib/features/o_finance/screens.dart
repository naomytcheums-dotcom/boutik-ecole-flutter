import '../../core/router/screen_entry.dart';
import 's139_tableau_de_bord/tableau_de_bord_financier_screen.dart';
import 's140_paiements_declares/paiements_declares_screen.dart';
import 's141_journal_financier/journal_financier_screen.dart';
import 's142_rapports_financiers/rapports_financiers_screen.dart';
import 's143_versements/versements_screen.dart';
import 's144_moyens_paiement/moyens_paiement_screen.dart';

const _s = 'O';
const _web = ScreenFormat.web;

/// Section O · Finance et paiements (139–144, web).
final sectionOScreens = <ScreenEntry>[
  ScreenEntry('139', 'Tableau de bord financier', (_) => const TableauDeBordFinancierScreen(), section: _s, node: '148:946', format: _web),
  ScreenEntry('140', 'Paiements déclarés', (_) => const PaiementsDeclaresScreen(), section: _s, node: '43:1820', format: _web),
  ScreenEntry('141', 'Journal financier', (_) => const JournalFinancierScreen(), section: _s, node: '43:1935', format: _web),
  ScreenEntry('142', 'Rapports financiers', (_) => const RapportsFinanciersScreen(), section: _s, node: '43:2046', format: _web),
  ScreenEntry('143', 'Versements et montants dus', (_) => const VersementsScreen(), section: _s, node: '54:1445', format: _web),
  ScreenEntry('144', 'Moyens de paiement et règles', (_) => const MoyensPaiementScreen(), section: _s, node: '54:1580', format: _web),
];
