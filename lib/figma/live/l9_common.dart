import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert;
import '../nav.dart';
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'tp_ui.dart';

/// Rôles qui peuvent porter un projet, une campagne ou un journal (le serveur refuse les autres : « Réservé aux étudiants »).
const projectOwnerRoles = {'student', 'dept', 'admin'};

const _alternative = 'Demandez à un étudiant de votre équipe de s’en charger, ou consultez les projets validés.';

bool canOwnProjects(Account? a) => !Backend.ready || projectOwnerRoles.contains(roleKey(a));

/// Avant une action réservée aux étudiants : connexion, puis rôle. Un compte non autorisé reçoit un message clair AVANT toute saisie.
Future<bool> requireProjectOwner(BuildContext context, WidgetRef ref, String action, {String alternative = _alternative}) async {
  if (!Backend.ready) return true;
  if (!await requireLogin(context, ref, action) || !context.mounted) return false;
  if (canOwnProjects(ref.read(authProvider).current)) return true;
  await gAlert(context, 'Réservé aux étudiants', 'Seuls les étudiants peuvent $action. $alternative');
  return false;
}

/// Message affiché à la place d'un écran réservé aux étudiants, avec une alternative.
class ProjectRoleNotice extends StatelessWidget {
  const ProjectRoleNotice({super.key, required this.action, this.alternative = _alternative});
  final String action, alternative;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
        child: Column(children: [
          const Icon(Icons.lock_outline_rounded, size: 40, color: tpViolet),
          const SizedBox(height: 14),
          Text('Réservé aux étudiants', textAlign: TextAlign.center, style: tpSt(16, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Seuls les étudiants peuvent $action. $alternative', textAlign: TextAlign.center, style: tpSt(13, c: tpGrey, h: 1.5)),
          const SizedBox(height: 18),
          TpButton('Voir les projets validés', () => gOpen(context, '78'), icon: Icons.lightbulb_outline_rounded),
        ]),
      );
}

/// Enveloppe d'une page réservée aux étudiants : visiteur → connexion ; autre rôle → message ; sinon la page.
class ProjectRoleGate extends ConsumerWidget {
  const ProjectRoleGate({super.key, required this.title, required this.action, required this.child});
  final String title, action;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready) return child;
    final a = ref.watch(authProvider.select((s) => s.current));
    if (a == null) {
      return TpPage(title: title, children: [
        TpEmpty(title: 'Connexion requise', text: 'Connectez-vous avec votre compte étudiant pour $action.', icon: Icons.lock_outline_rounded, action: 'Se connecter', onAction: () => requireLogin(context, ref, action)),
      ]);
    }
    if (!canOwnProjects(a)) return TpPage(title: title, children: [ProjectRoleNotice(action: action)]);
    return child;
  }
}

/// Projets du compte connecté (la table n'est lisible que par son propriétaire et le département).
Future<List<Map<String, dynamic>>> loadMyProjects({bool approvedOnly = false}) async {
  final uid = Backend.userId;
  if (uid == null) return const [];
  final r = await Backend.rows('projects', 'id,kind,title,status,department,details,links,updated_at',
      eq: {'owner_id': uid, if (approvedOnly) 'status': 'approved'}, order: 'updated_at', limit: 100);
  return r.rows;
}

/// Choix du projet sur lequel on travaille (pastilles) ; la sélection est renvoyée par [onChanged].
class ProjectPicker extends StatelessWidget {
  const ProjectPicker({super.key, required this.projects, required this.value, required this.onChanged, this.label = 'Projet'});
  final List<Map<String, dynamic>> projects;
  final String value, label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TpChoice(label, {for (final p in projects) '${p['id']}': '${p['title']}'}, value, onChanged, required: true);
}

/// Écran d'attente d'une lecture serveur.
Widget l9Loading() => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
