import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'company_screens.dart' show companyContextProvider;
import 'marche/marche_data.dart';

/// Vivier de talents : les listes d'étudiants d'une ORGANISATION (« Favoris » par défaut), partagées par son équipe selon les rôles, et la fenêtre qui permet
/// de ranger un étudiant dans une ou plusieurs listes avec une note interne. Listes, notes, étiquettes et rappels sont privés (migrations 20261114003900 et 20261126060300).
/// L'organisation visée est celle du contexte courant (`companyContextProvider`) ; null = le compte lui-même.

/// Paramètres d'un RPC de vivier : ajoute `p_org` quand une organisation d'équipe est consultée.
Map<String, dynamic> poolArgs(String? org, [Map<String, dynamic> extra = const {}]) => {...extra, 'p_org': ?org};

/// Message lisible d'une lecture ou d'une écriture du vivier en échec.
String poolErrorText(Object? e) => e == 'offline' || e == 'missing' ? marcheErrorText(e) : Backend.userMessage('$e');

final talentListsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final org = ref.watch(companyContextProvider);
  if (!Backend.ready) return const [];
  final r = await marcheCall('pool_lists_get', poolArgs(org));
  if (r.error != null) throw MarcheException(r.error);
  if (r.data is! List) return const [];
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

/// Identifiants des étudiants d'une liste.
final talentListMembersProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, listId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final org = ref.watch(companyContextProvider);
  if (listId.isEmpty) return const {};
  final r = await marcheCall('pool_list_members_get', poolArgs(org, {'p_list': listId}));
  if (r.error != null) throw MarcheException(r.error);
  if (r.data is! List) return const {};
  return {for (final x in r.data as List) '${(x as Map)['id']}'};
}, retry: (_, _) => null);

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
  final _newName = TextEditingController(), _note = TextEditingController();
  bool _busy = false;
  String? _loadError;

  String? get _org => ref.read(companyContextProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newName.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await marcheCall('pool_lists_get', poolArgs(_org, {'p_student': widget.studentId}));
    if (!mounted) return;
    setState(() {
      _loadError = r.error == null ? null : poolErrorText(r.error);
      _lists = r.error != null || r.data is! List ? null : [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
    });
  }

  Future<void> _toggle(Map<String, dynamic> l, bool on) async {
    setState(() => _busy = true);
    final r = on
        ? await marcheCall('pool_list_add', poolArgs(_org, {'p_list': l['id'], 'p_student': widget.studentId, 'p_note': _note.text.trim()}))
        : await marcheCall('pool_list_remove', poolArgs(_org, {'p_list': l['id'], 'p_student': widget.studentId}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, 'Liste non modifiée', poolErrorText(r.error));
      return;
    }
    await _load();
  }

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.length < 2) return;
    setState(() => _busy = true);
    final r = await marcheCall('pool_list_create', poolArgs(_org, {'p_name': name}));
    if (!mounted) return;
    if (r.error != null) {
      setState(() => _busy = false);
      await gAlert(context, 'Liste non créée', poolErrorText(r.error));
      return;
    }
    final add = await marcheCall('pool_list_add', poolArgs(_org, {'p_list': '${r.data}', 'p_student': widget.studentId, 'p_note': _note.text.trim()}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (add.error != null) await gAlert(context, 'Étudiant non ajouté', poolErrorText(add.error));
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
          Text('Les listes sont privées à votre organisation : l’étudiant n’est pas prévenu.', style: mst(12, c: kGrey)),
          const SizedBox(height: 10),
          TextField(controller: _note, maxLength: 200, decoration: const InputDecoration(labelText: 'Note interne (facultative)', hintText: 'Pourquoi ce talent ?', counterText: '')),
          if (lists == null && _loadError != null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(children: [Text(_loadError!, style: mst(13, c: kGrey)), TextButton(onPressed: _load, child: const Text('Réessayer'))])),
          if (lists == null && _loadError == null) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
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
