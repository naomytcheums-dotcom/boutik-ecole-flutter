import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart' show dateCourte, missionStatus;
import 'store.dart' show fcfa;

/// Console des missions (écrans 198 Briefs reçus, 199 Attribution, 200 Missions) : besoins publiés par les clients, propositions reçues,
/// attribution à une équipe et montants de jalons (migration 20261105000600). Aucun séquestre réel n'est géré : les montants affichés
/// sont ceux des jalons saisis sur les missions.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final staffMissionsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('staff_missions'));

/// Besoin choisi dans la boîte de réception, repris par l'écran d'attribution.
class SelectedMission extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedMissionProvider = NotifierProvider<SelectedMission, String?>(SelectedMission.new);

class MissionProposals extends RpcRows {
  MissionProposals() : super('staff_mission_proposals');

  @override
  List<Map<String, dynamic>>? build() {
    ref.watch(selectedMissionProvider);
    return super.build();
  }

  @override
  Future<void> refresh() async {
    final id = ref.read(selectedMissionProvider);
    if (id == null) {
      state = const [];
      return;
    }
    final r = await Backend.rpc(fn, {'p_mission': id});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
  }
}

final missionProposalsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(MissionProposals.new);

int _i(Object? v) => ((v as num?) ?? 0).toInt();

String budgetLabel(Map<String, dynamic> r) {
  final a = r['budget_min'], b = r['budget_max'];
  if (a == null && b == null) return 'Budget non précisé';
  if (a == null || a == b) return 'Budget ${fcfa(_i(b ?? a))}';
  return 'Budget ${fcfa(_i(a))} – ${fcfa(_i(b))}';
}

Widget _note(double w, String t, {double h = 130}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

Widget _kpi(String label, String value, double w) => Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEEECE8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: _st(12, c: _grey)), const SizedBox(height: 6), Text(value, style: _st(26, w: FontWeight.w700))]),
    );

/// Garde commune : connexion, chargement, accès refusé.
Widget? _guard(WidgetRef ref, List<Map<String, dynamic>>? rows, bool Function() error, double width) {
  if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de gestion pour voir les missions.');
  if (rows == null) return _note(width, 'Chargement…');
  if (error()) return _note(width, 'Accès réservé à la gestion, ou missions indisponibles pour le moment.');
  return null;
}

/// Quatre compteurs calculés sur les besoins reçus.
class MissionKpis extends ConsumerWidget {
  const MissionKpis({super.key, this.width = 984, this.kind = 'inbox'});
  final double width;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(staffMissionsProvider);
    final g = _guard(ref, rows, () => ref.read(staffMissionsProvider.notifier).error, width);
    if (g != null) return SizedBox(width: width, child: g);
    int n(String s) => rows!.where((r) => '${r['status']}' == s).length;
    final w = (width - 3 * 12) / 4;
    final items = kind == 'inbox'
        ? [('Publiés', '${n('published')}'), ('Attribués', '${n('assigned')}'), ('En cours', '${n('in_progress')}'), ('Livrés', '${n('delivered')}')]
        : [('Attribuées', '${n('assigned')}'), ('En cours', '${n('in_progress')}'), ('Livrées', '${n('delivered')}'), ('Clôturées', '${n('closed')}')];
    return Row(children: [
      for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 12), _kpi(items[i].$1, items[i].$2, w)]
    ]);
  }
}

/// Liste des besoins : titre, client, budget, état ; un appui ouvre l'attribution (199) sur ce besoin.
class MissionsInbox extends ConsumerWidget {
  const MissionsInbox({super.key, this.width = 984, this.height = 520, this.statuses = const ['published'], this.onOpen, this.empty = 'Aucun besoin à traiter pour le moment.', this.showMilestones = false});
  final double width, height;
  final List<String> statuses;
  final void Function(BuildContext, Map<String, dynamic>)? onOpen;
  final String empty;
  final bool showMilestones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(staffMissionsProvider);
    final g = _guard(ref, all, () => ref.read(staffMissionsProvider.notifier).error, width);
    if (g != null) return SizedBox(width: width, child: g);
    final rows = [for (final r in all!) if (statuses.contains('${r['status']}')) r];
    if (rows.isEmpty) return SizedBox(width: width, child: _note(width, empty));
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final r = rows[i];
          final detail = showMilestones
              ? '${r['milestones_count']} jalon${_i(r['milestones_count']) > 1 ? 's' : ''} · ${fcfa(_i(r['milestones_validated']))} validés sur ${fcfa(_i(r['milestones_total']))}'
              : '${budgetLabel(r)} · ${r['proposals']} proposition${_i(r['proposals']) > 1 ? 's' : ''}';
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen == null ? null : () => onOpen!(context, r),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEEECE8))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(15, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${r['client']} · publié le ${dateCourte(r['created_at'])}${'${r['team']}'.isEmpty ? '' : ' · équipe : ${r['team']}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, c: const Color(0xFF44546A))),
                    const SizedBox(height: 4),
                    Text(detail, style: _st(12, c: _grey)),
                  ]),
                ),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(12)), child: Text(missionStatus(r['status']), style: _st(11, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Attribution : le besoin choisi, ses propositions, et l'attribution à l'équipe de l'auteur retenu.
class MissionAssignPanel extends ConsumerWidget {
  const MissionAssignPanel({super.key, this.width = 984, this.height = 640});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(staffMissionsProvider);
    final g = _guard(ref, all, () => ref.read(staffMissionsProvider.notifier).error, width);
    if (g != null) return SizedBox(width: width, child: g);
    final id = ref.watch(selectedMissionProvider);
    final m = id == null ? null : all!.where((r) => '${r['id']}' == id).firstOrNull;
    if (m == null) return SizedBox(width: width, child: _note(width, 'Choisissez d’abord un besoin dans les briefs reçus.'));
    final props = ref.watch(missionProposalsProvider);
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['title']}', style: _st(18, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${m['client']} · ${missionStatus(m['status'])}', style: _st(13, c: const Color(0xFF44546A))),
          const SizedBox(height: 14),
          Text(budgetLabel(m), style: _st(13)),
          if (m['deadline'] != null && '${m['deadline']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Échéance : ${m['deadline']}', style: _st(13))),
          if ('${m['team']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Équipe attribuée : ${m['team']}', style: _st(13, w: FontWeight.w700, c: const Color(0xFF0F7A52)))),
          const SizedBox(height: 22),
          Text('Propositions reçues', style: _st(16, w: FontWeight.w700)),
          const SizedBox(height: 10),
          if (props == null)
            Text('Chargement…', style: _st(13, c: _grey))
          else if (props.isEmpty)
            Text('Aucune proposition pour ce besoin.', style: _st(13, c: _grey))
          else
            for (final p in props)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p['author']}', style: _st(14, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${fcfa(_i(p['amount']))} · ${p['delay_days']} jours${'${p['department']}'.isEmpty ? '' : ' · ${p['department']}'}', style: _st(12, c: _grey)),
                    ]),
                  ),
                  if ('${m['status']}' == 'published')
                    GestureDetector(
                      onTap: () async {
                        final r = await Backend.rpc('assign_mission', {'p_mission': '${m['id']}', 'p_team': '${p['author']}'});
                        if (!context.mounted) return;
                        if (r.error != null) {
                          gToast(context, 'Attribution impossible : ${r.error}');
                          return;
                        }
                        gToast(context, 'Besoin attribué à ${p['author']}.');
                        await ref.read(staffMissionsProvider.notifier).refresh();
                      },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(16)), child: Text('Attribuer', style: _st(12, w: FontWeight.w700, c: Colors.white))),
                    ),
                ]),
              ),
        ]),
      ),
    );
  }
}
