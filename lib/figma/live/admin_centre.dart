import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart' show Text;
import '../nav.dart';
import 'access.dart' show NotFoundView, roleKey, roleNames;
import 'admin_access.dart';
import 'auth.dart';
import 'backend.dart';
import 'lots.dart' show confirmPickupDialog, kioskIncidentsDialog;
import 'tp_ui.dart';
import 'top100_admin_common.dart' show kRankingPerms;
import 'verification_equipe.dart' show accountDeletionsDialog, documentReviewDialog, mfaResetDialog, referenceReviewDialog;

/// Centre d'administration (écran 300) : point d'entrée unique de l'administration. L'administrateur global y voit les quatre équipes internes (Finance, Support,
/// Sécurité et modération, Technique) et les outils d'administration globale ; un agent n'y voit que les équipes dont il a des permissions.
/// Tableaux de bord des équipes (301 à 304) : indicateurs réels du serveur (`admin_team_dashboard`) et outils de l'équipe, qui réutilisent les écrans existants.

/// Libellés courts des permissions (catalogue `admin_permissions` du serveur).
const kPermissionLabels = {
  'finance.read': 'Lecture financière',
  'finance.payments': 'Valider les paiements',
  'finance.payouts': 'Retraits et versements',
  'finance.refunds': 'Rembourser',
  'finance.transfers': 'Virements Mobile Money',
  'finance.split': 'Répartition et séquestre',
  'support.tickets': 'Demandes d’aide',
  'support.claims': 'Réclamations',
  'support.disputes': 'Litiges',
  'support.orders': 'Commandes et bornes',
  'support.requests': 'Demandes des utilisateurs',
  'support.refunds': 'Décider un remboursement',
  'security.moderation': 'Modérer les contenus',
  'security.reports': 'Signalements',
  'security.accounts': 'Comptes suspects et 2FA',
  'security.audit': 'Journal d’audit',
  'tech.config': 'Configuration',
  'tech.integrations': 'Intégrations et clés d’API',
  'tech.logs': 'Journaux techniques',
  'tech.maintenance': 'Maintenance et diagnostic',
  'tech.assessments': 'Évaluations de talents',
  'institutions.manage': 'Établissements, filières et responsables',
  'ranking.rules': 'Règles de score et réglages du classement',
  'ranking.publish': 'Publier, corriger et archiver les classements',
  'ranking.moderate': 'Fraude et contestations du classement',
};

/// Un outil d'équipe : écran du registre, route dédiée ou action. Visible seulement si l'agent détient l'une des permissions [perms] (l'administrateur voit tout).
class TeamTool {
  const TeamTool(this.label, this.hint, this.perms, {this.screen, this.route, this.action});
  final String label, hint;
  final Set<String> perms;
  final String? screen, route;
  final Future<void> Function(BuildContext, WidgetRef)? action;

  Future<void> open(BuildContext context, WidgetRef ref) async {
    if (screen != null) {
      gOpen(context, screen!);
    } else if (route != null) {
      GoRouter.of(context).push(route!);
    } else {
      await action?.call(context, ref);
    }
  }
}

Future<void> _suppressions(BuildContext c, WidgetRef r) => accountDeletionsDialog(c, r, canExecute: roleKey(r.read(authProvider).current) == 'admin');

/// Outils rangés par équipe (écrans existants réutilisés ; aucun n'est dupliqué).
final kTeamTools = <String, List<TeamTool>>{
  'finance': const [
    TeamTool('Tableau de bord financier', 'Encaissements, commandes payées, montants dus.', {'finance.read'}, screen: '139'),
    TeamTool('Paiements déclarés', 'Vérifier et valider les paiements.', {'finance.payments'}, screen: '140'),
    TeamTool('Transactions et rapprochements', 'Suivi des transactions et rapprochements.', {'finance.read', 'finance.payments'}, screen: '134'),
    TeamTool('Versements et retraits', 'Retraits des vendeurs et versements.', {'finance.payouts', 'finance.read'}, screen: '143'),
    TeamTool('Journal financier', 'Mouvements financiers enregistrés.', {'finance.read'}, screen: '141'),
    TeamTool('Rapports financiers', 'Rapports par département et par période.', {'finance.read'}, screen: '142'),
    TeamTool('Commissions et règles économiques', 'Seuil de paiement appliqué ; taux enregistrés, non appliqués aux calculs.', {'finance.read'}, screen: '135'),
    TeamTool('Moyens de paiement et règles', 'Moyens de paiement acceptés.', {'finance.read'}, screen: '144'),
    TeamTool('Séquestre et répartition', 'Montants en séquestre, blocage et déblocage.', {'finance.read', 'finance.split'}, route: '/admin/sequestre'),
    TeamTool('Registre financier', 'Registre des mouvements.', {'finance.read'}, screen: '284'),
  ],
  'support': [
    const TeamTool('Boîte du support', 'Demandes d’aide et conversations signalées.', {'support.tickets'}, route: '/support/boite'),
    const TeamTool('Commandes et incidents', 'Commandes problématiques et incidents.', {'support.orders', 'support.claims'}, screen: '132'),
    const TeamTool('Litiges et remboursements', 'Réclamations et litiges à trancher.', {'support.disputes', 'support.claims', 'support.refunds'}, screen: '133'),
    const TeamTool('Points de retrait et kiosques', 'Kiosques et retraits de commandes.', {'support.orders'}, screen: '145'),
    const TeamTool('Supervision des bornes', 'État des bornes.', {'support.orders'}, screen: '277'),
    const TeamTool('Tickets de support', 'Historique des interventions.', {'support.tickets'}, screen: '147-1'),
    const TeamTool('Interventions et résolutions', 'Résolutions et interventions.', {'support.tickets', 'support.orders'}, screen: '147-3'),
    TeamTool('Remettre une commande', 'Code de retrait.', const {'support.orders'}, action: confirmPickupDialog),
    TeamTool('Pièces justificatives à examiner', 'Pièces d’étudiants à valider.', const {'support.requests'}, action: documentReviewDialog),
    TeamTool('Établissements et départements proposés', 'Propositions à relire.', const {'support.requests'}, action: referenceReviewDialog),
    TeamTool('Suppressions de compte', 'Demandes programmées.', const {'support.requests'}, action: _suppressions),
  ],
  'security': [
    const TeamTool('Modération du réseau social', 'Publications, histoires et commentaires.', {'security.moderation', 'security.reports'}, route: '/moderation/reseau'),
    const TeamTool('Modération de la marketplace', 'Boutiques, annonces et signalements.', {'security.moderation', 'security.reports'}, route: '/marche/moderation'),
    const TeamTool('Modération (vue d’ensemble)', 'File de modération.', {'security.moderation'}, screen: '130'),
    const TeamTool('Signalements', 'Signalements des utilisateurs.', {'security.reports'}, screen: '131'),
    const TeamTool('Comptes suspects', 'Signaler un compte, suivre les signalements.', {'security.accounts'}, screen: '306'),
    TeamTool('Réinitialiser une double authentification', 'Après vérification d’identité.', const {'security.accounts'}, action: mfaResetDialog),
    const TeamTool('Sécurité et accès', 'Accès et sécurité de la plateforme.', {'security.audit'}, screen: '136'),
    const TeamTool('Journal d’audit global', 'Actions sensibles tracées.', {'security.audit'}, screen: '137'),
  ],
  'tech': [
    const TeamTool('Configuration générale', 'Réglages de la plateforme.', {'tech.config'}, screen: '138'),
    const TeamTool('Intégrations', 'Hub d’intégrations et clés d’API.', {'tech.integrations'}, screen: '280'),
    const TeamTool('État technique', 'État des services.', {'tech.maintenance'}, screen: '266'),
    const TeamTool('Boutik-École Network', 'Réseau des bornes et services.', {'tech.maintenance'}, screen: '267'),
    const TeamTool('Supervision des bornes', 'État et incidents des bornes.', {'tech.maintenance'}, screen: '277'),
    const TeamTool('Analytics de la borne', 'Usage des bornes.', {'tech.maintenance'}, screen: '268'),
    const TeamTool('Modèles de notifications', 'Messages envoyés par la plateforme.', {'tech.config'}, screen: '265'),
    const TeamTool('Pages éditoriales', 'Contenus éditoriaux.', {'tech.config'}, screen: '264'),
    const TeamTool('Journal d’audit global', 'Journaux techniques.', {'tech.logs'}, screen: '137'),
    TeamTool('Journal des incidents des bornes', 'Incidents signalés.', const {'tech.maintenance'}, action: kioskIncidentsDialog),
  ],
};

/// Administration globale (administrateur seul) : utilisateurs, rôles, institutions, supervision, paramètres.
const kGlobalTools = <TeamTool>[
  TeamTool('Tableau de bord de la plateforme', 'Chiffres globaux.', {}, screen: '127'),
  TeamTool('Comptes, rôles et permissions', 'Utilisateurs, rôles, suspension.', {}, screen: '128'),
  TeamTool('Équipes et permissions', 'Attribuer ou retirer les droits des équipes.', {}, screen: '305'),
  TeamTool('Institutions', 'Établissements, départements et organisations.', {}, screen: '129'),
  TeamTool('Rôles et périmètres', 'Périmètre de chaque rôle.', {}, screen: '281'),
  TeamTool('Organisations à vérifier', 'Dossiers des organisations.', {}, route: '/admin/entreprises'),
  TeamTool('Forfaits des organisations', 'Plans et abonnements.', {}, route: '/admin/forfaits'),
  TeamTool('Promotions de la plateforme', 'Codes promotionnels.', {}, route: '/marche/promotions'),
  TeamTool('Innovation Radar', 'Veille sur les innovations.', {}, screen: '269'),
];

class AdminCounter {
  const AdminCounter(this.key, this.label, this.value, this.unit, this.permission);
  final String key, label, unit, permission;
  final num value;

  factory AdminCounter.fromJson(Map<dynamic, dynamic> j) => AdminCounter('${j['key']}', '${j['label']}', (j['value'] as num?) ?? 0, '${j['unit'] ?? ''}', '${j['permission'] ?? ''}');

  String get shown {
    final s = value.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
    return unit.isEmpty ? s : '$s $unit';
  }
}

/// Indicateurs de l'équipe (aucun chiffre hors connexion : la liste est vide et l'écran le dit).
final adminTeamDashboardProvider = FutureProvider.autoDispose.family<List<AdminCounter>, String>((ref, team) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  final r = await Backend.rpc('admin_team_dashboard', {'p_team': team});
  if (r.error != null || r.data is! Map) throw Exception(Backend.userMessage(r.error ?? 'Indicateurs indisponibles'));
  final c = (r.data as Map)['counters'];
  return [for (final x in (c is List ? c : const [])) if (x is Map) AdminCounter.fromJson(x)];
}, retry: (_, _) => null);

Widget _tile({required IconData icon, required String title, required String body, VoidCallback? onTap, Widget? trailing}) => TpCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: tpInk, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tpSt(14.5, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: tpSt(12, c: tpGrey, h: 1.4)),
            ]),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: tpGrey),
        ]),
      ),
    );

Widget _chips(Iterable<String> perms) => Wrap(spacing: 6, runSpacing: 6, children: [
      for (final p in perms)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFEFEAFB), borderRadius: BorderRadius.circular(100)),
          child: Text(kPermissionLabels[p] ?? p, style: tpSt(11.5, w: FontWeight.w600, c: tpViolet)),
        ),
    ]);

Widget _failed(String message, VoidCallback retry) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        const Icon(Icons.error_outline_rounded, size: 38, color: tpRed),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: tpSt(13, c: tpGrey, h: 1.5)),
        const SizedBox(height: 14),
        TpButton('Réessayer', retry, dark: false, icon: Icons.refresh_rounded),
      ]),
    );

/// Hub du centre d'administration.
class AdminCentreScreen extends ConsumerWidget {
  const AdminCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).current;
    final access = ref.watch(adminAccessProvider);
    final role = roleKey(account);
    return TpPage(
      title: 'Centre d’administration',
      subtitle: roleNames[role] ?? '',
      children: access.when(
        loading: () => [const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))],
        error: (e, _) => [_failed('Vos droits d’équipe n’ont pas pu être chargés.', () => ref.invalidate(adminAccessProvider))],
        data: (a) {
          final teams = a.myTeams;
          return [
            tpNote(a.isAdmin
                ? 'Vous êtes administrateur global : vous gardez tous les droits. Chaque équipe a son tableau de bord et des permissions que vous attribuez ou retirez.'
                : 'Vous voyez les équipes dont vous faites partie ; seules les permissions attribuées explicitement par l’administrateur global ouvrent des outils. Les outils des autres équipes ne vous sont pas proposés.'),
            if (teams.isEmpty && !a.hasAny(kRankingPerms))
              const TpEmpty(
                title: 'Aucune équipe',
                text: 'L’administrateur global ne vous a encore attribué aucune permission. Demandez-lui de vous ajouter à l’équipe qui correspond à votre mission.',
                icon: Icons.lock_outline_rounded,
              ),
            if (a.isMinimal)
              tpNote('Droits minimaux : vous pouvez consulter le tableau de bord de votre équipe, mais aucune opération (paiement, retrait, remboursement, modération, configuration…) n’est ouverte '
                  'tant que l’administrateur global ne vous a pas attribué de permission.'),
            if (teams.isNotEmpty) tpSection('Équipes', hint: a.isAdmin ? 'Quatre équipes internes, chacune avec son tableau de bord.' : 'Vos équipes.'),
            for (final t in teams)
              _tile(
                icon: kTeamIcons[t]!,
                title: kTeamNames[t]!,
                body: kTeamBlurbs[t]!,
                onTap: () => gOpen(context, const {'finance': '301', 'support': '302', 'security': '303', 'tech': '304'}[t]!),
              ),
            if (a.hasAny(kRankingPerms)) ...[
              tpSection('Classement et talents', hint: 'Équipe « ranking » : règles, publication, établissements, fraude et contestations.'),
              _tile(icon: Icons.leaderboard_outlined, title: 'Classement et talents', body: 'Règles de score, publication des classements, établissements et filières, rattachements, fraude et contestations.', onTap: () => GoRouter.of(context).push('/admin/classement')),
              if (!a.isAdmin) _chips([for (final p in kRankingPerms) if (a.permissions.contains(p)) p]..sort()),
            ],
            if (!a.isAdmin && teams.isNotEmpty) ...[
              tpSection('Vos permissions'),
              for (final t in teams) ...[
                Padding(padding: const EdgeInsets.only(top: 6, bottom: 6), child: Text(kTeamNames[t]!, style: tpSt(12.5, w: FontWeight.w700))),
                _chips((a.teams[t]?.toList() ?? <String>[])..sort()),
              ],
            ],
            if (a.isAdmin) ...[
              tpSection('Administration globale', hint: 'Utilisateurs, rôles, institutions, supervision, paramètres, sécurité et journaux.'),
              for (final t in kGlobalTools) _tile(icon: Icons.admin_panel_settings_outlined, title: t.label, body: t.hint, onTap: () => t.open(context, ref)),
            ],
          ];
        },
      ),
    );
  }
}

/// Tableau de bord d'une équipe (301 Finance, 302 Support, 303 Sécurité et modération, 304 Technique).
class AdminTeamScreen extends ConsumerWidget {
  const AdminTeamScreen({super.key, required this.team});
  final String team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kTeamOrder.contains(team)) return const NotFoundView();
    final access = ref.watch(adminAccessProvider);
    final dash = ref.watch(adminTeamDashboardProvider(team));
    return TpPage(
      title: kTeamNames[team]!,
      subtitle: 'Équipe interne',
      actions: [TpRound(icon: Icons.refresh_rounded, label: 'Actualiser', onTap: () => ref.invalidate(adminTeamDashboardProvider(team)))],
      children: access.when(
        loading: () => [const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))],
        error: (e, _) => [_failed('Vos droits d’équipe n’ont pas pu être chargés.', () => ref.invalidate(adminAccessProvider))],
        data: (a) {
          if (!a.inTeam(team)) {
            return const [TpEmpty(title: 'Accès réservé', text: 'Cette équipe n’est pas la vôtre : l’administrateur global ne vous a attribué aucune permission ici.', icon: Icons.lock_outline_rounded)];
          }
          final tools = [for (final t in kTeamTools[team]!) if (a.isAdmin || a.hasAny(t.perms)) t];
          return [
            tpNote(kTeamBlurbs[team]!),
            tpSection('Indicateurs', hint: 'Chiffres réels du serveur, limités à vos permissions.'),
            dash.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => _failed(Backend.userMessage('$e'.replaceFirst('Exception: ', '')), () => ref.invalidate(adminTeamDashboardProvider(team))),
              data: (counters) => counters.isEmpty
                  ? tpNote(Backend.ready ? 'Aucun indicateur : aucune permission de cette équipe ne vous est attribuée.' : 'Les indicateurs s’affichent une fois connecté au serveur.')
                  : Wrap(spacing: 12, runSpacing: 12, children: [for (final c in counters) _CounterCard(c)]),
            ),
            if (a.isAdmin) ...[
              tpSection('Gestion'),
              _tile(icon: Icons.groups_2_outlined, title: 'Agents et permissions de l’équipe', body: 'Ajouter, modifier ou retirer des agents.', onTap: () => gOpen(context, '305')),
            ],
            tpSection('Outils de l’équipe', hint: 'Les outils sont ceux des écrans existants, rangés par équipe.'),
            if (tools.isEmpty) tpNote('Aucun outil : aucune permission de cette équipe ne vous est attribuée.'),
            for (final t in tools) _tile(icon: Icons.build_outlined, title: t.label, body: t.hint, onTap: () => t.open(context, ref)),
            if (!a.isAdmin) ...[
              tpSection('Vos permissions'),
              if ((a.teams[team] ?? <String>{}).isEmpty)
                tpNote('Aucune permission attribuée dans cette équipe (droits minimaux) : demandez à l’administrateur global les permissions nécessaires à votre mission.')
              else
                _chips((a.teams[team] ?? <String>{}).toList()..sort()),
            ],
          ];
        },
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard(this.c);
  final AdminCounter c;

  @override
  Widget build(BuildContext context) => Container(
        width: 168,
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(22, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(c.label, style: tpSt(12, c: tpGrey, h: 1.35)),
        ]),
      );
}
