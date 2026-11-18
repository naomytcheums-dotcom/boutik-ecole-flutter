import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';

/// Équipes internes de l'administrateur global (Finance, Support, Sécurité et modération, Technique) et leurs permissions.
/// Les droits d'un agent viennent de permissions explicites attribuées par l'administrateur global (migration 20261120040000) :
/// le serveur est l'autorité (gardes SQL), cette couche évite seulement d'afficher à un agent les outils des autres équipes.

const kTeamOrder = ['finance', 'support', 'security', 'tech'];

const kTeamNames = {'finance': 'Finance', 'support': 'Support', 'security': 'Sécurité et modération', 'tech': 'Technique'};

const kTeamBlurbs = {
  'finance': 'Paiements, transactions, commissions, répartitions, remboursements, retraits et rapports financiers.',
  'support': 'Tickets, assistance, réclamations, litiges, commandes problématiques et demandes des utilisateurs.',
  'security': 'Surveillance, signalements, comptes suspects, protection des utilisateurs et modération des contenus.',
  'tech': 'Supervision technique, configuration, intégrations, services, journaux et maintenance.',
};

const kTeamIcons = {
  'finance': Icons.account_balance_wallet_outlined,
  'support': Icons.support_agent_outlined,
  'security': Icons.shield_outlined,
  'tech': Icons.settings_suggest_outlined,
};

/// Droits de base d'un nouvel agent (identiques à `_admin_team_defaults` côté serveur).
const kTeamDefaults = <String, List<String>>{
  'finance': ['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers'],
  'support': ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests'],
  'security': ['security.moderation', 'security.reports'],
  'tech': ['tech.logs', 'tech.maintenance'],
};

/// Écrans réservés par permission : un agent finance ou support ne les ouvre que s'il détient l'une de ces permissions (l'administrateur global garde tout).
const kScreenPermissions = <String, Set<String>>{
  '130': {'security.moderation'},
  '131': {'security.reports'},
  '132': {'support.orders', 'support.claims'},
  '133': {'support.disputes', 'support.claims', 'support.refunds'},
  '134': {'finance.read', 'finance.payments'},
  '135': {'finance.read'},
  '136': {'security.audit', 'tech.logs'},
  '137': {'security.audit', 'tech.logs'},
  '138': {'tech.config'},
  '139': {'finance.read'},
  '140': {'finance.payments'},
  '141': {'finance.read'},
  '142': {'finance.read'},
  '143': {'finance.payouts', 'finance.read'},
  '144': {'finance.read'},
  '145': {'support.orders', 'tech.maintenance'},
  '146-1': {'support.orders'},
  '146-2': {'support.orders'},
  '147-1': {'support.tickets'},
  '147-2': {'support.orders', 'tech.maintenance'},
  '147-3': {'support.tickets', 'support.orders'},
  '264': {'tech.config'},
  '265': {'tech.config'},
  '266': {'tech.maintenance'},
  '267': {'tech.maintenance'},
  '268': {'support.orders', 'tech.maintenance'},
  '277': {'support.orders', 'tech.maintenance'},
  '280': {'tech.integrations'},
  '282': {'support.orders'},
  '284': {'finance.read'},
  '301': {'finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers', 'finance.split'},
  '302': {'support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'},
  '303': {'security.moderation', 'security.reports', 'security.accounts', 'security.audit'},
  '304': {'tech.config', 'tech.integrations', 'tech.logs', 'tech.maintenance'},
  '306': {'security.accounts'},
};

/// Équipes, permissions et statut de la personne connectée.
class AdminAccess {
  const AdminAccess({this.role = '', this.isAdmin = false, this.teams = const {}});

  final String role;
  final bool isAdmin;
  final Map<String, Set<String>> teams;

  static const none = AdminAccess();

  factory AdminAccess.fromJson(Map<dynamic, dynamic> j) {
    final t = j['teams'];
    return AdminAccess(
      role: '${j['role'] ?? ''}',
      isAdmin: j['is_admin'] == true,
      teams: {
        if (t is Map)
          for (final e in t.entries)
            '${e.key}': {for (final p in (e.value is List ? e.value as List : const [])) '$p'},
      },
    );
  }

  /// Hors connexion au serveur (aperçu, tests) : droits de base de l'équipe du compte, comme après la migration.
  factory AdminAccess.fromAccount(Account? a) {
    switch (a?.staff) {
      case 'Admin global':
        return AdminAccess(role: 'admin', isAdmin: true, teams: {for (final t in kTeamOrder) t: {...kTeamDefaults[t]!}});
      case 'Finance':
        return AdminAccess(role: 'finance', teams: {'finance': {...kTeamDefaults['finance']!}});
      case 'Support':
        return AdminAccess(role: 'support', teams: {
          'support': {...kTeamDefaults['support']!, 'support.refunds'},
          'security': {'security.moderation', 'security.reports', 'security.accounts', 'security.audit'},
        });
    }
    return none;
  }

  Set<String> get permissions => {for (final s in teams.values) ...s};

  bool has(String perm) => isAdmin || permissions.contains(perm);

  bool hasAny(Iterable<String> perms) => isAdmin || perms.any(permissions.contains);

  bool inTeam(String team) => isAdmin || (teams[team]?.isNotEmpty ?? false);

  List<String> get myTeams => [for (final t in kTeamOrder) if (inTeam(t)) t];
}

/// Rôle d'équipe interne (finance ou support) : seuls ces comptes sont soumis aux permissions ; l'administrateur et les autres rôles ne le sont pas.
bool isTeamAgent(Account? a) => a != null && (a.staff == 'Finance' || a.staff == 'Support');

/// Écran permis à ce compte compte tenu de ses permissions ; vrai pour tout compte hors équipes internes ou quand l'accès est encore en lecture ([access] nul).
bool screenAllowedByAccess(Account? a, String id, AdminAccess? access) {
  final need = kScreenPermissions[id.replaceAll('_', '-')];
  if (need == null || !isTeamAgent(a) || access == null) return true;
  return access.hasAny(need);
}

/// Accès de la personne connectée : lu sur le serveur (`my_admin_access`), ou déduit du compte hors connexion.
final adminAccessProvider = FutureProvider.autoDispose<AdminAccess>((ref) async {
  final account = ref.watch(authProvider.select((a) => a.current));
  if (!Backend.ready) return AdminAccess.fromAccount(account);
  if (account == null) return AdminAccess.none;
  final r = await Backend.rpc('my_admin_access', const {});
  if (r.error != null || r.data is! Map) throw Exception(Backend.userMessage(r.error ?? 'Droits d’équipe indisponibles'));
  return AdminAccess.fromJson(r.data as Map);
}, retry: (_, _) => null);
