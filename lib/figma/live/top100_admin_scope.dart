import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'tp_ui.dart';
import 'top100_admin_common.dart';
import 'top100_admin_institutions.dart' show top100InstitutionsProvider;

/// Vue d'un périmètre pour un responsable d'établissement ou de département (`my_ranking_scopes`, `scope_dashboard`) : données agrégées de son seul périmètre,
/// aucun nom ni score individuel. Un responsable de département ne lit pas l'établissement entier ; l'administration choisit l'établissement à consulter.

/// Tableau de bord d'un périmètre ; clé « institution:identifiant » ou « department:identifiant ».
final top100ScopeDashboardProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  final i = key.indexOf(':');
  final kind = key.substring(0, i), id = key.substring(i + 1);
  return top100Map('scope_dashboard', {kind == 'institution' ? 'p_institution' : 'p_department': id});
}, retry: (_, _) => null);

class Top100ScopeSection extends ConsumerStatefulWidget {
  const Top100ScopeSection({super.key, required this.scopes});

  /// Réponse de `my_ranking_scopes` : `{ admin, institutions: [ {id, name} ], department: {id, name, institution_id} | null }`.
  final Map<String, dynamic> scopes;

  @override
  ConsumerState<Top100ScopeSection> createState() => _ScopeState();
}

class _ScopeState extends ConsumerState<Top100ScopeSection> {
  String? _key;

  @override
  Widget build(BuildContext context) {
    final s = widget.scopes;
    final institutions = top100Rows(s['institutions']);
    final department = s['department'] is Map ? top100Obj(s['department']) : null;
    final isAdmin = s['admin'] == true;
    final choices = <String, String>{
      for (final i in institutions) 'institution:${i['id']}': 'Établissement · ${i['name']}',
      if (department != null) 'department:${department['id']}': 'Département · ${department['name']}',
    };
    final adminInstitutions = isAdmin ? ref.watch(top100InstitutionsProvider('')) : null;
    if (adminInstitutions != null) {
      for (final i in adminInstitutions.asData?.value ?? const []) {
        choices.putIfAbsent('institution:${i.id}', () => 'Établissement · ${i.name}');
      }
    }
    final key = choices.containsKey(_key) ? _key : (choices.isEmpty ? null : choices.keys.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote(isAdmin
          ? 'Administration : choisissez l’établissement à consulter. Les chiffres sont agrégés (aucun nom ni score individuel).'
          : 'Vous ne voyez que votre périmètre. Les chiffres sont agrégés : aucun nom ni score individuel.'),
      if (adminInstitutions != null && adminInstitutions.hasError) top100Failed(top100Msg(adminInstitutions.error!), () => ref.invalidate(top100InstitutionsProvider(''))),
      if (choices.isEmpty && !(adminInstitutions?.isLoading ?? false) && !(adminInstitutions?.hasError ?? false))
        const TpEmpty(title: 'Aucun périmètre', text: 'Aucun établissement ni département ne vous est rattaché comme responsable, ou le référentiel est encore vide.', icon: Icons.account_tree_outlined),
      if (choices.length > 1) TpChoice('Périmètre', choices, key ?? '', (v) => setState(() => _key = v)),
      if (key != null) _Dashboard(scopeKey: key),
    ]);
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.scopeKey});
  final String scopeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(top100ScopeDashboardProvider(scopeKey));
    return d.when(
      loading: top100Loading,
      error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100ScopeDashboardProvider(scopeKey))),
      data: (r) {
        final scope = top100Obj(r['scope']);
        final programs = top100Rows(r['programs']);
        final rank = r['institution_ranking'] is Map ? top100Obj(r['institution_ranking']) : null;
        final hidden = r['avg_hidden_reason'];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tpSection(top100Str(scope['name'], 'Périmètre'), hint: 'Période ${top100Str(r['period'], 'non précisée')}'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            top100Stat('Étudiants vérifiés', r['verified_students']),
            top100Stat('Actifs ce mois', r['active_this_month']),
            top100Stat('Talents classés', r['ranked_talents']),
            top100Stat('Rattachements en attente', r['pending_affiliations']),
            top100Stat('Score moyen par étudiant vérifié', hidden != null ? '—' : r['avg_score_per_verified_student']),
          ]),
          if (hidden != null) tpNote('Moyenne masquée : l’effectif vérifié est inférieur à l’effectif minimal (${top100Num(r['min_cohort'])}) pour protéger les étudiants.'),
          if (rank != null) ...[
            tpSection('Classement de l’établissement'),
            TpCard(child: Column(children: [top100Line('Rang', rank['rank']), top100Line('Évolution du rang', rank['delta_rank']), top100Line('Score moyen', rank['avg_score']), top100Line('Étudiants vérifiés', rank['verified_students'])])),
          ],
          tpSection('Filières', hint: 'Seules les filières d’un effectif suffisant sont détaillées.'),
          if (programs.isEmpty) tpNote('Aucune filière détaillée pour ce périmètre.'),
          for (final p in programs) TpCard(child: top100Line('${p['name']}', '${top100Num(p['verified_students'])} étudiant(s)')),
          if (r['other_programs_students'] != null) top100Line('Autres filières (regroupées)', r['other_programs_students']),
          if (top100Str(r['note']).isNotEmpty) tpNote('${r['note']}'),
        ]);
      },
    );
  }
}
