import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'talent_pages.dart' show SkillCatalog;
import 'tp_ui.dart';

/// Besoins et missions (écran 90) : publication d'un besoin SANS valeur d'exemple, liste « Mes besoins » (consulter, modifier un brouillon
/// ou un besoin publié, suivre l'état). Les propositions des talents et les jalons suivent les écrans 192 à 201.

const needStatusLabels = {'draft': 'Brouillon', 'published': 'Publié', 'assigned': 'Attribué', 'in_progress': 'En cours', 'completed': 'Terminé', 'cancelled': 'Annulé'};

class NeedFormPage extends ConsumerStatefulWidget {
  const NeedFormPage({super.key, this.existing});
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<NeedFormPage> createState() => _NeedFormPageState();
}

class _NeedFormPageState extends ConsumerState<NeedFormPage> {
  final title = TextEditingController(), desc = TextEditingController(), bmin = TextEditingController(), bmax = TextEditingController();
  String category = '', deadline = '';
  DateTime? deadlineDate;
  List<String> domains = const [];
  bool busy = false;

  bool get editable => widget.existing == null || const ['draft', 'published'].contains('${widget.existing!['status']}');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      title.text = '${e['title']}';
      final d = '${e['description'] ?? ''}';
      final m = RegExp(r'\n?Catégorie : (.*)$').firstMatch(d);
      if (m != null) category = m.group(1)!.trim();
      desc.text = d.replaceAll(RegExp(r'\n?Catégorie : .*$'), '').trim();
      if (e['budget_min'] != null) bmin.text = '${e['budget_min']}';
      if (e['budget_max'] != null) bmax.text = '${e['budget_max']}';
      deadline = '${e['deadline'] ?? ''}';
    }
    SkillCatalog.load().then((c) {
      if (mounted) setState(() => domains = c.domains);
    });
  }

  @override
  void dispose() {
    for (final c in [title, desc, bmin, bmax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: deadlineDate ?? now.add(const Duration(days: 14)), firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    setState(() {
      deadlineDate = d;
      deadline = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    });
  }

  Future<void> _save({required bool publish}) async {
    if (title.text.trim().length < 3) return gToast(context, 'Donnez un titre à votre besoin (3 caractères minimum).');
    if (publish && desc.text.trim().length < 20) return gToast(context, 'Pour publier, décrivez le besoin en 20 caractères minimum.');
    final lo = int.tryParse(bmin.text.trim()), hi = int.tryParse(bmax.text.trim());
    if (lo != null && hi != null && hi < lo) return gToast(context, 'Le budget maximum doit être supérieur au minimum.');
    if (!await requireLogin(context, ref, 'publier un besoin') || !mounted) return;
    setState(() => busy = true);
    final r = await Backend.rpc('save_mission', {
      'p_id': widget.existing?['id'], 'p_title': title.text.trim(),
      'p_description': [desc.text.trim(), if (category.isNotEmpty) 'Catégorie : $category'].where((x) => x.isNotEmpty).join('\n'),
      'p_budget_min': lo, 'p_budget_max': hi, 'p_deadline': deadline, 'p_publish': publish, 'p_kind': 'besoin',
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    gToast(context, publish ? 'Besoin publié : les talents peuvent vous faire des propositions.' : 'Brouillon enregistré.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return TpPage(
      title: widget.existing == null ? 'Publier un besoin' : 'Modifier le besoin',
      actions: [TpRound(icon: Icons.list_alt_rounded, label: 'Mes besoins', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyNeedsPage())))],
      bottom: editable
          ? Row(children: [
              Expanded(child: TpButton('Brouillon', busy ? null : () => _save(publish: false), dark: false)),
              const SizedBox(width: 10),
              Expanded(child: TpButton('Publier', busy ? null : () => _save(publish: true), busy: busy)),
            ])
          : Text('Ce besoin est ${needStatusLabels['${widget.existing!['status']}']?.toLowerCase() ?? 'en cours'} : il ne peut plus être modifié ici.', textAlign: TextAlign.center, style: tpSt(13, c: tpGrey)),
      children: [
        TpField('Titre du besoin', title, required: true, maxLength: 120),
        TpSelect('Catégorie', category, domains, (v) => setState(() => category = v), customLabel: 'Autre catégorie (saisir)'),
        TpField('Description (contexte, objectifs, contraintes)', desc, lines: 5, maxLength: 4000),
        tpSection('Budget estimé (FCFA)'),
        Row(children: [
          Expanded(child: TpField('Minimum', bmin, keyboard: TextInputType.number, maxLength: 10, formatters: [FilteringTextInputFormatter.digitsOnly])),
          const SizedBox(width: 10),
          Expanded(child: TpField('Maximum', bmax, keyboard: TextInputType.number, maxLength: 10, formatters: [FilteringTextInputFormatter.digitsOnly])),
        ]),
        const Text(''),
        Text('Date limite', style: tpSt(12.5, w: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TpButton(deadline.isEmpty ? 'Choisir une date' : deadline, _pickDate, dark: false, compact: true, icon: Icons.event_rounded)),
          if (deadline.isNotEmpty) ...[const SizedBox(width: 8), TpRound(icon: Icons.close_rounded, label: 'Retirer la date', onTap: () => setState(() {
                deadline = '';
                deadlineDate = null;
              }))],
        ]),
        tpNote('Le cahier des charges peut être transmis dans la messagerie du besoin une fois publié.'),
      ],
    );
  }
}

class MyNeedsPage extends ConsumerStatefulWidget {
  const MyNeedsPage({super.key});
  @override
  ConsumerState<MyNeedsPage> createState() => _MyNeedsPageState();
}

class _MyNeedsPageState extends ConsumerState<MyNeedsPage> {
  List<Map<String, dynamic>>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Backend.userId;
    if (uid == null) return setState(() => items = const []);
    final r = await Backend.rows('missions', 'id,number,kind,title,description,status,budget_min,budget_max,deadline,created_at', eq: {'client_id': uid, 'kind': 'besoin'}, order: 'created_at', limit: 100);
    if (!mounted) return;
    setState(() {
      items = r.rows;
      error = r.error;
    });
  }

  Future<void> _open([Map<String, dynamic>? m]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => NeedFormPage(existing: m)));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = items;
    return TpPage(
      title: 'Mes besoins',
      bottom: TpButton('Publier un besoin', () => _open(), icon: Icons.add_rounded),
      children: [
        if (l == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (error != null) TpEmpty(title: 'Lecture impossible', text: error!, icon: Icons.cloud_off_rounded)
        else if (l.isEmpty)
          TpEmpty(title: 'Aucun besoin publié', text: 'Décrivez ce que vous cherchez : les talents qualifiés vous font des propositions que vous comparez ici.', icon: Icons.assignment_outlined)
        else
          for (final m in l)
            TpCard(
              onTap: () => _open(m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${m['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(15, w: FontWeight.w700))),
                  Text(needStatusLabels['${m['status']}'] ?? '${m['status']}', style: tpSt(12, w: FontWeight.w700, c: '${m['status']}' == 'published' ? tpGreen : tpViolet)),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text([
                    '${m['number'] ?? ''}',
                    if (m['budget_min'] != null || m['budget_max'] != null) 'Budget ${m['budget_min'] ?? '…'} – ${m['budget_max'] ?? '…'} FCFA',
                    if ('${m['deadline'] ?? ''}'.isNotEmpty) 'Avant le ${m['deadline']}',
                  ].where((e) => e.isNotEmpty).join(' · '), style: tpSt(12, c: tpGrey)),
                ),
                if ('${m['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${m['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
              ]),
            ),
      ],
    );
  }
}
