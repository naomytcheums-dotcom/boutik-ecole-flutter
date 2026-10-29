import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'audit.dart';
import 'auth.dart';

/// Contrôle d'accès par rôle : chaque écran réservé n'est visible que pour les rôles autorisés.
///
/// Rôles : visitor (non connecté), client, student, company, other, dept, direction, finance, support, admin.
String roleKey(Account? a) {
  if (a == null) return 'visitor';
  switch (a.staff) {
    case 'Resp. département':
      return 'dept';
    case 'Direction':
      return 'direction';
    case 'Finance':
      return 'finance';
    case 'Support':
      return 'support';
    case 'Admin global':
      return 'admin';
  }
  return const ['client', 'student', 'company', 'other'][a.role.clamp(0, 3)];
}

const roleNames = {
  'visitor': 'Visiteur',
  'client': 'Client',
  'student': 'Étudiant-vendeur',
  'company': 'Entreprise',
  'other': 'Autre rôle',
  'dept': 'Responsable de département',
  'direction': 'Direction',
  'finance': 'Finance',
  'support': 'Support',
  'admin': 'Administrateur global',
};

/// Rôles autorisés pour un écran ; null = ouvert à tous.
Set<String>? allowedRoles(String id) {
  final n = int.tryParse(RegExp(r'^\d+').firstMatch(id)?.group(0) ?? '');
  if (n == null) return null;
  const admin = 'admin';
  if (n >= 57 && n <= 69) return {'student', 'dept', admin};
  if ((n >= 88 && n <= 99) || (n >= 187 && n <= 190)) return {'company', admin};
  if (n >= 108 && n <= 116) return {'dept', 'direction', admin};
  if (n >= 117 && n <= 126) return {'direction', admin};
  if (n >= 127 && n <= 138) {
    if (n >= 131 && n <= 133) return {'support', admin};
    if (n == 134 || n == 135) return {'finance', admin};
    return {admin};
  }
  if (n >= 139 && n <= 144) return {'finance', 'direction', admin};
  if (n >= 145 && n <= 147) return {'support', admin};
  if (n == 167 || n == 168 || n == 169) return {'dept', admin};
  if (n >= 198 && n <= 200) return {'dept', admin};
  if (n == 213) return {'dept', admin};
  if (n == 239) return {'direction', 'dept', admin};
  switch (n) {
    case 262:
    case 285:
      return {'company', admin};
    case 263:
    case 286:
    case 287:
    case 288:
    case 283:
      return {'dept', admin};
    case 264:
    case 265:
    case 266:
    case 267:
    case 269:
    case 280:
    case 281:
      return {admin};
    case 268:
    case 277:
      return {'support', admin};
    case 284:
      return {'finance', 'direction', admin};
  }
  return null;
}

bool canOpen(Account? a, String id) {
  final r = allowedRoles(id);
  return r == null || r.contains(roleKey(a));
}

/// Enveloppe d'un écran : affiche l'écran si le rôle l'autorise, sinon « Accès réservé ».
class AccessGuard extends ConsumerWidget {
  const AccessGuard({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).current;
    if (canOpen(account, id)) return child;
    return AccessDenied(id: id);
  }
}

class AccessDenied extends ConsumerStatefulWidget {
  const AccessDenied({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AccessDenied> createState() => _AccessDeniedState();
}

class _AccessDeniedState extends ConsumerState<AccessDenied> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final a = ref.read(authProvider).current;
      ref.read(auditProvider.notifier).log(a?.name ?? 'Visiteur', 'Accès refusé', 'Écran ${widget.id}', 'Connexions', level: 'Sensible');
    });
  }

  @override
  Widget build(BuildContext context) {
    const f = 'PlusJakartaSans';
    TextStyle st(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: f, fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);
    final a = ref.watch(authProvider).current;
    final need = allowedRoles(widget.id)!.map((r) => roleNames[r]!).join(' · ');
    final quick = <(String, Account)>[
      for (final s in seedAccounts)
        if (s.staff.isNotEmpty || s.email == demoAccount.email) (s.staff.isNotEmpty ? s.staff : 'Étudiant', s),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111015)),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 22),
                Text('Accès réservé', style: st(24, FontWeight.w700, const Color(0xFF111015))),
                const SizedBox(height: 10),
                Text(
                  'L’écran ${widget.id} est réservé aux rôles : $need.\nVous êtes connecté en tant que ${roleNames[roleKey(a)]}${a == null ? '' : ' (${a.name})'}.',
                  textAlign: TextAlign.center,
                  style: st(13.5, FontWeight.w400, const Color(0xFF66636E)).copyWith(height: 1.55),
                ),
                const SizedBox(height: 22),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  for (final (label, acc) in quick)
                    ActionChip(
                      label: Text(label, style: st(12, FontWeight.w600, const Color(0xFF111015))),
                      backgroundColor: Colors.white,
                      onPressed: () {
                        ref.read(authProvider.notifier).login(acc);
                        ref.read(auditProvider.notifier).log(acc.name, 'Changement de compte (démonstration)', roleNames[roleKey(acc)]!, 'Connexions', level: 'Sensible');
                      },
                    ),
                ]),
                const SizedBox(height: 6),
                Text('Comptes de démonstration : mot de passe Boutik2026', style: st(11, FontWeight.w400, const Color(0xFF66636E))),
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: () => context.go(screenPath('03')), child: Text('Retour à l’accueil', style: st(13, FontWeight.w600, const Color(0xFF5A3FE0)))),
                  TextButton(onPressed: () => context.go(screenPath('11')), child: Text('Se connecter', style: st(13, FontWeight.w600, const Color(0xFF5A3FE0)))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
