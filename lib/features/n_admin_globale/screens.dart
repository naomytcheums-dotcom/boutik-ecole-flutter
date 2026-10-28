import '../../core/router/screen_entry.dart';
import 's127_tableau_de_bord/tableau_de_bord_screen.dart';
import 's128_comptes_roles/comptes_roles_screen.dart';
import 's129_institutions/institutions_screen.dart';
import 's130_moderation/moderation_screen.dart';
import 's131_signalements/signalements_screen.dart';
import 's132_commandes_incidents/commandes_incidents_screen.dart';
import 's133_litiges/litiges_screen.dart';
import 's134_transactions/transactions_screen.dart';
import 's135_commissions/commissions_screen.dart';
import 's136_securite/securite_screen.dart';
import 's137_journal_audit/journal_audit_screen.dart';
import 's138_configuration/configuration_screen.dart';

/// Section N · Administration globale (127–138, web 1280).
final sectionNScreens = <ScreenEntry>[
  ScreenEntry('127', 'Tableau de bord de la plateforme', (_) => const TableauDeBordPlateformeScreen(), section: 'N', node: '148:636', format: ScreenFormat.web),
  ScreenEntry('128', 'Comptes, rôles et permissions', (_) => const ComptesRolesScreen(), section: 'N', node: '43:198', format: ScreenFormat.web),
  ScreenEntry('129', 'Institutions', (_) => const InstitutionsScreen(), section: 'N', node: '43:334', format: ScreenFormat.web),
  ScreenEntry('130', 'Modération', (_) => const ModerationScreen(), section: 'N', node: '43:469', format: ScreenFormat.web),
  ScreenEntry('131', 'Signalements', (_) => const SignalementsScreen(), section: 'N', node: '43:590', format: ScreenFormat.web),
  ScreenEntry('132', 'Commandes et incidents', (_) => const CommandesIncidentsScreen(), section: 'N', node: '43:733', format: ScreenFormat.web),
  ScreenEntry('133', 'Litiges et remboursements', (_) => const LitigesScreen(), section: 'N', node: '43:879', format: ScreenFormat.web),
  ScreenEntry('134', 'Transactions et rapprochements', (_) => const TransactionsScreen(), section: 'N', node: '43:999', format: ScreenFormat.web),
  ScreenEntry('135', 'Commissions et règles économiques', (_) => const CommissionsScreen(), section: 'N', node: '43:1139', format: ScreenFormat.web),
  ScreenEntry('136', 'Sécurité et accès', (_) => const SecuriteScreen(), section: 'N', node: '43:1263', format: ScreenFormat.web),
  ScreenEntry('137', 'Journal d’audit global', (_) => const JournalAuditScreen(), section: 'N', node: '43:1380', format: ScreenFormat.web),
  ScreenEntry('138', 'Configuration générale', (_) => const ConfigurationScreen(), section: 'N', node: '43:1531', format: ScreenFormat.web),
];
