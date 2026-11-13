import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Disponibilités (stage, mission, job…) et langues d'un profil, visibles par les entreprises. Se placent en tête du portfolio (migration 20261114003000).

const availabilityKinds = {'internship': 'Stage', 'vacation': 'Stage de vacances', 'mission': 'Mission', 'job': 'Job étudiant ou emploi', 'volunteer': 'Bénévolat'};
const languageLevels = {'basic': 'Notions', 'intermediate': 'Intermédiaire', 'advanced': 'Avancé', 'native': 'Langue maternelle'};

/// « Stage, Mission · à partir du 15/01/2027 » ; vide quand rien n'est renseigné.
String availabilitySummary(Map<String, dynamic>? a) {
  if (a == null) return '';
  final kinds = [for (final k in (a['kinds'] as List? ?? const [])) availabilityKinds['$k'] ?? '$k'];
  if (kinds.isEmpty) return '';
  final from = DateTime.tryParse('${a['available_from']}');
  return '${kinds.join(', ')}${from == null ? '' : ' · à partir du ${from.day.toString().padLeft(2, '0')}/${from.month.toString().padLeft(2, '0')}/${from.year}'}';
}

final profileExtrasProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, userId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('profile_extras_get', {if (userId.isNotEmpty) 'p_user': userId});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});

class ProfileExtrasCard extends ConsumerWidget {
  const ProfileExtrasCard({super.key, this.userId = ''});
  final String userId;

  Future<void> _editAvailability(BuildContext context, WidgetRef ref, Map<String, dynamic>? cur) async {
    final selected = {for (final k in (cur?['kinds'] as List? ?? const [])) '$k'};
    final note = TextEditingController(text: '${cur?['note'] ?? ''}');
    final from = TextEditingController(text: cur?['available_from'] == null ? '' : '${cur!['available_from']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text('Mes disponibilités'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, children: [for (final e in availabilityKinds.entries) FilterChip(label: Text(e.value), selected: selected.contains(e.key), onSelected: (v) => setS(() => v ? selected.add(e.key) : selected.remove(e.key)))]),
              const SizedBox(height: 10),
              TextField(controller: from, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'Disponible à partir du', hintText: 'AAAA-MM-JJ')),
              TextField(controller: note, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Précisions (facultatif)', hintText: 'Libre le soir et le week-end')),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Enregistrer'))],
        ),
      ),
    );
    final n = note.text, f = from.text.trim();
    note.dispose();
    from.dispose();
    if (ok != true || !context.mounted) return;
    if (f.isNotEmpty && DateTime.tryParse(f) == null) return gToast(context, 'Date invalide : utilisez AAAA-MM-JJ.');
    final r = await marcheCall('availability_save', {'p': {'kinds': selected.toList(), 'note': n, 'available_from': f}});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Disponibilités enregistrées.');
    ref.invalidate(profileExtrasProvider);
  }

  Future<void> _addLanguage(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var level = 'intermediate';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text('Ajouter une langue'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Langue', hintText: 'Anglais')),
            const SizedBox(height: 10),
            MDropdown(label: 'Niveau', value: level, items: languageLevels, onChanged: (v) => setS(() => level = v)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Ajouter'))],
        ),
      ),
    );
    final lang = name.text;
    name.dispose();
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('language_save', {'p_language': lang, 'p_level': level});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Langue enregistrée.');
    ref.invalidate(profileExtrasProvider);
  }

  Future<void> _removeLanguage(BuildContext context, WidgetRef ref, String lang) async {
    final r = await marcheCall('language_delete', {'p_language': lang});
    if (!context.mounted) return;
    if (r.error != null) gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(profileExtrasProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileExtrasProvider(userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (d) {
        final mine = d['mine'] == true;
        final avail = d['availability'] is Map ? Map<String, dynamic>.from(d['availability'] as Map) : null;
        final summary = availabilitySummary(avail);
        final langs = [for (final x in (d['languages'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        if (!mine && summary.isEmpty && langs.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Disponibilités', style: mst(14, w: FontWeight.w800))),
              if (mine) TextButton(onPressed: () => _editAvailability(context, ref, avail), child: Text(summary.isEmpty ? 'Renseigner' : 'Modifier')),
            ]),
            Text(summary.isEmpty ? (mine ? 'Indiquez si vous cherchez un stage, une mission ou un job : les entreprises le voient.' : '') : summary, style: mst(13, c: summary.isEmpty ? kGrey : kInk)),
            if ('${avail?['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${avail!['note']}', style: mst(12.5, c: kGrey))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Langues', style: mst(14, w: FontWeight.w800))),
              if (mine) TextButton(onPressed: () => _addLanguage(context, ref), child: Text('Ajouter')),
            ]),
            if (langs.isEmpty) Text(mine ? 'Aucune langue renseignée.' : '', style: mst(13, c: kGrey)),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final l in langs)
                Chip(
                  label: Text('${l['language']} · ${languageLevels['${l['level']}'] ?? l['level']}', style: mst(12, w: FontWeight.w600)),
                  onDeleted: mine ? () => _removeLanguage(context, ref, '${l['language']}') : null,
                  deleteButtonTooltipMessage: 'Retirer',
                ),
            ]),
          ]),
        );
      },
    );
  }
}
