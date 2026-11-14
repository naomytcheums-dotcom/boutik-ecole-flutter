import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';

/// Vivier de talents : les listes d'étudiants d'une entreprise (« Favoris » par défaut) et la fenêtre qui permet de ranger un étudiant
/// dans une ou plusieurs listes. Les listes et les notes sont privées (migration 20261114003900).

final talentListsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  if (!Backend.ready) return const [];
  final r = await marcheCall('talent_lists_get', const {});
  if (r.error != null || r.data is! List) return const [];
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
});

/// Identifiants des étudiants d'une liste.
final talentListMembersProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, listId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  if (listId.isEmpty) return const {};
  final r = await marcheCall('talent_list_members_get', {'p_list': listId});
  if (r.error != null || r.data is! List) return const {};
  return {for (final x in r.data as List) '${(x as Map)['id']}'};
});

/// Étudiants enregistrés dans au moins une liste (pour allumer l'étoile).
final talentSavedIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final lists = await ref.watch(talentListsProvider.future);
  final out = <String>{};
  for (final l in lists) {
    if (mInt(l['count']) > 0) out.addAll(await ref.watch(talentListMembersProvider('${l['id']}').future));
  }
  return out;
});

void refreshTalentPool(WidgetRef ref) {
  ref.invalidate(talentListsProvider);
  ref.invalidate(talentListMembersProvider);
  ref.invalidate(talentSavedIdsProvider);
}

/// Fenêtre « Enregistrer dans… » : une case par liste, une note privée, et la création d'une nouvelle liste.
Future<void> showTalentListsSheet(BuildContext context, WidgetRef ref, {required String studentId, required String studentName}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => _TalentListsSheet(studentId: studentId, studentName: studentName),
  );
  refreshTalentPool(ref);
}

class _TalentListsSheet extends ConsumerStatefulWidget {
  const _TalentListsSheet({required this.studentId, required this.studentName});
  final String studentId, studentName;

  @override
  ConsumerState<_TalentListsSheet> createState() => _TalentListsSheetState();
}

class _TalentListsSheetState extends ConsumerState<_TalentListsSheet> {
  List<Map<String, dynamic>>? _lists;
  final _newName = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await marcheCall('talent_lists_get', {'p_student': widget.studentId});
    if (!mounted) return;
    setState(() => _lists = r.error != null || r.data is! List ? const [] : [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)]);
  }

  Future<void> _toggle(Map<String, dynamic> l, bool on) async {
    setState(() => _busy = true);
    final r = on
        ? await marcheCall('talent_list_add', {'p_list': l['id'], 'p_student': widget.studentId})
        : await marcheCall('talent_list_remove', {'p_list': l['id'], 'p_student': widget.studentId});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, 'Liste non modifiée', Backend.userMessage('${r.error}'));
      return;
    }
    await _load();
  }

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.length < 2) return;
    setState(() => _busy = true);
    final r = await marcheCall('talent_list_create', {'p_name': name});
    if (!mounted) return;
    if (r.error != null) {
      setState(() => _busy = false);
      await gAlert(context, 'Liste non créée', Backend.userMessage('${r.error}'));
      return;
    }
    final add = await marcheCall('talent_list_add', {'p_list': '${r.data}', 'p_student': widget.studentId});
    if (!mounted) return;
    setState(() => _busy = false);
    if (add.error != null) await gAlert(context, 'Étudiant non ajouté', Backend.userMessage('${add.error}'));
    _newName.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final lists = _lists;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enregistrer ${widget.studentName}', style: mst(17, w: FontWeight.w800)),
          Text('Vos listes sont privées : l’étudiant n’est pas prévenu.', style: mst(12, c: kGrey)),
          const SizedBox(height: 10),
          if (lists == null) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (lists != null)
            for (final l in lists)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: l['has'] == true,
                onChanged: _busy ? null : (v) => _toggle(l, v == true),
                title: Text('${l['name']}', style: mst(14, w: FontWeight.w700)),
                subtitle: Text('${mInt(l['count'])} étudiant${mInt(l['count']) > 1 ? 's' : ''}', style: mst(11.5, c: kGrey)),
              ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _newName, maxLength: 40, decoration: const InputDecoration(labelText: 'Nouvelle liste', hintText: 'Développeurs, Stage été…', counterText: ''), onSubmitted: (_) => _create())),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _busy ? null : _create, style: IconButton.styleFrom(backgroundColor: kInk), tooltip: 'Créer la liste', icon: const Icon(Icons.add, color: Colors.white)),
          ]),
        ]),
      ),
    );
  }
}
