import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'console.dart';

/// Suivi des productions (écran 113) et mentors / encadreurs (écran 114), lus et saisis sur le serveur (migration 20261105000700).
/// Aucune ligne de maquette hors démonstration ; « en retard » est calculé par le serveur (en cours et échéance dépassée).

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final staffMentorsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('staff_mentors'));
final staffProductionsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('staff_productions'));

String productionStatus(Object? s) => switch ('$s') { 'terminee' => 'Terminée', 'en_retard' => 'En retard', 'annulee' => 'Annulée', _ => 'En cours' };

Widget _note(double w, String t, {double h = 130}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

Widget? _guard(WidgetRef ref, List<Map<String, dynamic>>? rows, bool Function() error, double width) {
  if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de gestion pour voir cette liste.');
  if (rows == null) return _note(width, 'Chargement…');
  if (error()) return _note(width, 'Accès réservé à la gestion, ou liste indisponible pour le moment.');
  return null;
}

Widget _cell(String t, int flex, {bool bold = false, bool head = false}) => Expanded(flex: flex, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(head ? 11.5 : 12.5, w: head || bold ? FontWeight.w600 : FontWeight.w500, c: head ? _grey : _ink)));

class ProductionKpis extends ConsumerWidget {
  const ProductionKpis({super.key, this.width = 984});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(staffProductionsProvider);
    final g = _guard(ref, rows, () => ref.read(staffProductionsProvider.notifier).error, width);
    if (g != null) return SizedBox(width: width, child: g);
    int n(String s) => rows!.where((r) => '${r['status']}' == s).length;
    final teams = {for (final r in rows!) if ('${r['status']}' == 'en_cours' || '${r['status']}' == 'en_retard') '${r['team']}'}..remove('');
    final month = DateTime.now();
    final doneMonth = rows.where((r) {
      final d = DateTime.tryParse('${r['finished_at'] ?? ''}')?.toLocal();
      return d != null && d.year == month.year && d.month == month.month;
    }).length;
    final w = (width - 3 * 12) / 4;
    Widget k(String l, String v) => Container(width: w, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEEECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(l, style: _st(11.5, c: _grey)), const SizedBox(height: 6), Text(v, style: _st(22, w: FontWeight.w700))]));
    return Row(children: [k('Équipes actives', '${teams.length}'), const SizedBox(width: 12), k('Productions en cours', '${n('en_cours') + n('en_retard')}'), const SizedBox(width: 12), k('Terminées ce mois', '$doneMonth'), const SizedBox(width: 12), k('En retard', '${n('en_retard')}')]);
  }
}

class ProductionsTable extends ConsumerWidget {
  const ProductionsTable({super.key, this.width = 984, this.height = 520});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(staffProductionsProvider);
    final g = _guard(ref, rows, () => ref.read(staffProductionsProvider.notifier).error, width);
    if (g != null) return SizedBox(width: width, child: g);
    if (rows!.isEmpty) return SizedBox(width: width, child: _note(width, 'Aucune production enregistrée pour le moment.'));
    return SizedBox(
      width: width,
      height: height,
      child: Column(children: [
        Row(children: [_cell('Production', 4, head: true), _cell('Équipe', 3, head: true), _cell('Encadreur', 3, head: true), _cell('Avancement', 2, head: true), _cell('État', 2, head: true)]),
        const Divider(height: 18),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF2EFF6)),
            itemBuilder: (_, i) {
              final r = rows[i];
              return Row(children: [_cell('${r['title']}', 4, bold: true), _cell('${r['team']}'.isEmpty ? '—' : '${r['team']}', 3), _cell('${r['mentor']}'.isEmpty ? '—' : '${r['mentor']}', 3), _cell('${r['progress']} %', 2), _cell(productionStatus(r['status']), 2, bold: true)]);
            },
          ),
        ),
      ]),
    );
  }
}

class MentorsTable extends ConsumerWidget {
  const MentorsTable({super.key, this.width = 984, this.height = 520});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(staffMentorsProvider);
    final g = _guard(ref, rows, () => ref.read(staffMentorsProvider.notifier).error, width);
    if (g != null) return SizedBox(width: width, child: g);
    if (rows!.isEmpty) return SizedBox(width: width, child: _note(width, 'Aucun mentor ni encadreur enregistré pour le moment.\nUtilisez « Ajouter un mentor » pour en créer un.'));
    return SizedBox(
      width: width,
      height: height,
      child: Column(children: [
        Row(children: [_cell('Nom', 4, head: true), _cell('Rôle', 2, head: true), _cell('Spécialité', 3, head: true), _cell('Productions en cours', 3, head: true), _cell('Statut', 2, head: true)]),
        const Divider(height: 18),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF2EFF6)),
            itemBuilder: (_, i) {
              final r = rows[i];
              return Row(children: [_cell('${r['name']}', 4, bold: true), _cell('${r['role']}', 2), _cell('${r['specialty']}'.isEmpty ? '—' : '${r['specialty']}', 3), _cell('${r['productions']}', 3), _cell(r['active'] == true ? 'Actif' : 'Inactif', 2, bold: true)]);
            },
          ),
        ),
      ]),
    );
  }
}

/// Fenêtre d'ajout d'un mentor ou encadreur ; la fonction serveur refuse les comptes sans droit.
Future<void> addMentorDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController(), spec = TextEditingController();
  var role = 'Mentor';
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Ajouter un mentor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: spec, decoration: const InputDecoration(labelText: 'Spécialité')),
          const SizedBox(height: 8),
          DropdownButton<String>(value: role, isExpanded: true, items: const [DropdownMenuItem(value: 'Mentor', child: Text('Mentor')), DropdownMenuItem(value: 'Encadreur', child: Text('Encadreur'))], onChanged: (v) => set(() => role = v ?? 'Mentor')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ajouter'))],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await Backend.rpc('mentor_create', {'p_name': name.text, 'p_role': role, 'p_specialty': spec.text});
  if (!context.mounted) return;
  if (r.error != null) {
    gToast(context, 'Ajout impossible : ${r.error}');
    return;
  }
  gToast(context, 'Mentor ajouté.');
  await ref.read(staffMentorsProvider.notifier).refresh();
}
