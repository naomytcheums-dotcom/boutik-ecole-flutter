import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';

/// Administration des comptes (écran 128) : liste, rôles, suspension.
const staffRoles = ['Client', 'Étudiant-vendeur', 'Entreprise', 'Autre rôle', 'Resp. département', 'Direction', 'Finance', 'Support', 'Admin global'];

/// Rôle serveur (app_role) correspondant à chaque libellé de [staffRoles], dans le même ordre.
const staffRoleKeys = ['client', 'student', 'company', 'other', 'dept', 'direction', 'finance', 'support', 'admin'];

/// Comptes du serveur, lus par l'administrateur (RLS) ; rechargés après chaque modification confirmée.
class ServerAccounts extends Notifier<List<Account>> {
  @override
  List<Account> build() {
    if (Backend.ready) Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final l = await Backend.adminAccounts();
    if (l != null) state = l;
  }
}

final serverAccountsProvider = NotifierProvider<ServerAccounts, List<Account>>(ServerAccounts.new);

/// Comptes affichés : avec le serveur, les comptes réels ; hors connexion (tests, aperçu), les inscriptions récentes puis les comptes de démonstration.
final adminUsersProvider = Provider<List<Account>>((ref) {
  if (Backend.ready) return ref.watch(serverAccountsProvider);
  final all = ref.watch(authProvider).accounts;
  final seeds = seedAccounts.map((s) => s.email).toSet();
  return [
    for (final a in all)
      if (!seeds.contains(a.email)) a,
    for (final a in all)
      if (seeds.contains(a.email)) a,
  ];
});

Future<void> userDialog(BuildContext context, WidgetRef ref, Account a) {
  const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic);
  var role = staffRoles.contains(a.roleLabel) ? a.roleLabel : staffRoles.first;
  var suspended = a.suspended;
  return gDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(a.name, style: st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.email}\n${a.phone} · ${a.institution}', style: st.copyWith(height: 1.6, color: const Color(0xFF66636E))),
            const SizedBox(height: 14),
            Text('Rôle', style: st.copyWith(fontWeight: FontWeight.w600)),
            DropdownButton<String>(
              value: role,
              isExpanded: true,
              style: st,
              items: [for (final r in staffRoles) DropdownMenuItem(value: r, child: Text(r, style: st))],
              onChanged: (v) => set(() => role = v ?? role),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Compte suspendu', style: st),
              value: suspended,
              onChanged: (v) => set(() => suspended = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: st)),
          TextButton(
            onPressed: () async {
              final idx = staffRoles.indexOf(role);
              if (Backend.ready) {
                // Rien n'est annoncé comme enregistré sans confirmation du serveur.
                final err = await Backend.adminSetAccount(a.serverId, staffRoleKeys[idx < 0 ? 0 : idx], suspended);
                if (!ctx.mounted) return;
                if (err != null) {
                  await gAlert(ctx, 'Compte non modifié', err);
                  return;
                }
                Navigator.of(ctx).pop();
                await ref.read(serverAccountsProvider.notifier).refresh();
                if (context.mounted) gToast(context, 'Compte mis à jour par le serveur');
                return;
              }
              final updated = a.copyWith(role: idx < 4 ? idx : a.role, staff: idx < 4 ? '' : role, suspended: suspended);
              ref.read(authProvider.notifier).update(updated);
              if (suspended != a.suspended) {
                ref.read(auditProvider.notifier).log('Super admin', suspended ? 'Compte suspendu' : 'Compte réactivé', a.name, 'Comptes', level: 'Sensible');
              }
              if (role != a.roleLabel) {
                ref.read(auditProvider.notifier).log('Super admin', 'Rôle attribué', '${a.name} → $role', 'Comptes', level: 'Sensible');
              }
              Navigator.of(ctx).pop();
              gToast(context, 'Compte mis à jour');
            },
            child: Text('Enregistrer', style: st.copyWith(color: const Color(0xFF5A3FE0), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

Color statusFill(bool suspended) => suspended ? const Color(0xFFFDE6E7) : const Color(0xFFDDF5EC);
Color statusInk(bool suspended) => suspended ? const Color(0xFFE5484D) : const Color(0xFF0F7A52);
