import 'form_options.dart' show pickDate;
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'backend.dart';
import 'company_screens.dart' show companyContextProvider, companyProvider;
import 'entreprise.dart' show dateCourte, daysLabel, invalidateCompanyData, openedProposalProvider, parseDate, proposalStatus;
import 'store.dart' show fcfa;
import 'talent_pages.dart' show SkillCatalog;
import 'tp_ui.dart';

/// Besoins et missions (écran 90) : publication d'un besoin SANS valeur d'exemple, liste « Mes besoins » (consulter, modifier un brouillon
/// ou un besoin publié, suivre l'état). Les propositions des talents et les jalons suivent les écrans 192 à 201.

const needStatusLabels = {
  'draft': 'Brouillon',
  'published': 'Publié',
  'assigned': 'Attribué',
  'in_progress': 'En cours',
  'delivered': 'Livré',
  'closed': 'Clôturé',
  'completed': 'Terminé',
  'cancelled': 'Annulé',
};

/// Bouton rond d'au moins 48 dp de toucher (le rond de la maquette fait 44).
Widget _bigRound(IconData icon, String label, VoidCallback onTap) => SizedBox(width: 48, height: 48, child: Center(child: TpRound(icon: icon, label: label, onTap: onTap)));

/// Ce que le compte peut publier MAINTENANT (vérification de la fiche, forfait, quotas) : lu AVANT la saisie ; à défaut de réponse du serveur,
/// contrôle local de l'état de la fiche entreprise.
class _PublishInfo {
  const _PublishInfo({this.canPublish = true, this.canDraft = true, this.message = '', this.quota = ''});
  final bool canPublish, canDraft;
  final String message, quota;
}

Future<_PublishInfo> _loadPublishInfo(WidgetRef ref) async {
  final ctx = ref.read(companyContextProvider);
  final r = await Backend.rpc('company_publish_status', {'p_owner': ?ctx});
  if (r.error == null && r.data is Map) {
    final d = Map<String, dynamic>.from(r.data as Map);
    final can = d['can'] is Map ? Map<String, dynamic>.from(d['can'] as Map) : const <String, dynamic>{};
    final reasons = d['reasons'] is Map ? Map<String, dynamic>.from(d['reasons'] as Map) : const <String, dynamic>{};
    final needs = d['needs'] is Map ? Map<String, dynamic>.from(d['needs'] as Map) : const <String, dynamic>{};
    final canNeed = can['need'] != false, canDraft = can['draft'] != false;
    final max = needs['max'];
    return _PublishInfo(
      canPublish: canNeed,
      canDraft: canDraft,
      message: canNeed ? '' : '${reasons['need'] ?? 'Vous ne pouvez pas publier de besoin pour le moment.'}',
      quota: max == null ? '' : 'Besoins publiés : ${needs['used'] ?? 0} sur $max.',
    );
  }
  // Contrôle local : une organisation dont la fiche n'est pas approuvée ne publie pas.
  final role = ref.read(authProvider).current?.role;
  if (role == 2) {
    try {
      final c = await ref.read(companyProvider.future);
      if (c == null) return const _PublishInfo(canPublish: false, message: 'Renseignez et faites vérifier la fiche de votre organisation avant de publier un besoin (menu Espace organisation › Fiche de l’organisation).');
      if ('${c['status']}' != 'approved') return const _PublishInfo(canPublish: false, message: 'La fiche de votre organisation n’est pas encore vérifiée : vous pouvez enregistrer des brouillons, la publication s’ouvre après la vérification.');
    } catch (_) {}
  }
  return const _PublishInfo();
}

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
  bool busy = false, dirty = false, done = false;
  _PublishInfo info = const _PublishInfo();
  String _initial = '';

  bool get editable => widget.existing == null || const ['draft', 'published'].contains('${widget.existing!['status']}');
  bool get wasPublished => '${widget.existing?['status']}' == 'published';
  String _snapshot() => [title.text, desc.text, bmin.text, bmax.text, category, deadline].join('\u0001');

  void _touch() {
    final d = _snapshot() != _initial;
    if (d != dirty && mounted) setState(() => dirty = d);
  }

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
      deadlineDate = parseDate(deadline);
      if (deadlineDate != null) deadline = _fmt(deadlineDate!);
    }
    _initial = _snapshot();
    for (final c in [title, desc, bmin, bmax]) {
      c.addListener(_touch);
    }
    SkillCatalog.load().then((c) {
      if (mounted) setState(() => domains = c.domains);
    });
    Future.microtask(() async {
      final i = await _loadPublishInfo(ref);
      if (mounted) setState(() => info = i);
    });
  }

  @override
  void dispose() {
    for (final c in [title, desc, bmin, bmax]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var initial = deadlineDate ?? now.add(const Duration(days: 14));
    if (initial.isBefore(today)) initial = today;
    final d = await pickDate(context: context, initialDate: initial, firstDate: today, lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    setState(() {
      deadlineDate = d;
      deadline = _fmt(d);
    });
    _touch();
  }

  Future<bool> _confirm(String titleText, String text, String yes) async {
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(titleText, style: tpSt(16, w: FontWeight.w700)),
        content: Text(text, style: tpSt(13, c: tpGrey, h: 1.5)),
        actions: [
          TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
        ],
      ),
    );
    return v == true;
  }

  Future<void> _save({required bool publish}) async {
    if (title.text.trim().length < 3) return gToast(context, 'Donnez un titre à votre besoin (3 caractères minimum).');
    if (publish && desc.text.trim().length < 20) return gToast(context, 'Pour publier, décrivez le besoin en 20 caractères minimum.');
    final lo = int.tryParse(bmin.text.trim()), hi = int.tryParse(bmax.text.trim());
    if (lo != null && hi != null && hi < lo) return gToast(context, 'Le budget maximum doit être supérieur au minimum.');
    if (deadline.isNotEmpty) {
      final d = deadlineDate ?? parseDate(deadline);
      final now = DateTime.now();
      if (d == null) return gToast(context, 'Date limite invalide : choisissez-la dans le calendrier.');
      if (d.isBefore(DateTime(now.year, now.month, now.day))) return gToast(context, 'La date limite est déjà passée : choisissez une date à venir.');
    }
    if (publish && !info.canPublish) return gToast(context, info.message.isEmpty ? 'Vous ne pouvez pas publier de besoin pour le moment.' : info.message);
    if (!publish && !info.canDraft) return gToast(context, 'Vous avez atteint le nombre maximum de brouillons : supprimez-en un avant d’en enregistrer un autre.');
    if (!publish && wasPublished) {
      final ok = await _confirm('Repasser ce besoin en brouillon ?', 'Il n’est plus visible des talents. Les propositions déjà reçues restent enregistrées, mais leurs auteurs sont prévenus que le besoin est retiré. Vous pourrez le republier plus tard.', 'Repasser en brouillon');
      if (!ok || !mounted) return;
    }
    if (!await requireLogin(context, ref, 'publier un besoin') || !mounted) return;
    // La catégorie est ajoutée à la description seulement si le total reste dans la limite du serveur (4 000 caractères).
    final withCategory = [desc.text.trim(), if (category.isNotEmpty) 'Catégorie : $category'].where((x) => x.isNotEmpty).join('\n');
    final categoryDropped = withCategory.length > 4000;
    final ctx = ref.read(companyContextProvider);
    setState(() => busy = true);
    final r = await Backend.rpc('save_mission', {
      'p_id': widget.existing?['id'], 'p_title': title.text.trim(),
      'p_description': categoryDropped ? desc.text.trim() : withCategory,
      'p_budget_min': lo, 'p_budget_max': hi, 'p_deadline': deadline, 'p_publish': publish, 'p_kind': 'besoin',
      if (!publish && wasPublished) 'p_unpublish': true,
      'p_owner': ?ctx,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    invalidateCompanyData(context);
    gToast(context, [
      publish ? 'Besoin publié : les talents peuvent vous faire des propositions.' : (wasPublished ? 'Besoin repassé en brouillon : il n’est plus visible des talents.' : 'Brouillon enregistré.'),
      if (categoryDropped) 'La catégorie n’a pas été ajoutée : la description est trop longue.',
    ].join(' '));
    done = true;
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmLeave() async {
    final leave = await _confirm('Quitter sans enregistrer ?', 'Ce que vous avez saisi pour ce besoin sera perdu.', 'Quitter');
    if (leave && mounted) {
      done = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty || done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: TpPage(
        title: widget.existing == null ? 'Publier un besoin' : 'Modifier le besoin',
        actions: [_bigRound(Icons.list_alt_rounded, 'Mes besoins', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyNeedsPage())))],
        bottom: editable
            ? Row(children: [
                Expanded(child: TpButton(wasPublished ? 'Repasser en brouillon' : 'Brouillon', busy ? null : () => _save(publish: false), dark: false)),
                const SizedBox(width: 10),
                Expanded(child: TpButton(wasPublished ? 'Enregistrer' : 'Publier', busy || !info.canPublish ? null : () => _save(publish: true), busy: busy)),
              ])
            : Text('Ce besoin est ${needStatusLabels['${widget.existing!['status']}']?.toLowerCase() ?? 'en cours'} : il ne peut plus être modifié ici.', textAlign: TextAlign.center, style: tpSt(13, c: tpGrey)),
        children: [
          if (!info.canPublish && info.message.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3C77B))),
              child: Text(info.message, style: tpSt(12.5, c: const Color(0xFF8F5400), h: 1.45)),
            )
          else if (info.quota.isNotEmpty)
            tpNote(info.quota),
          TpField('Titre du besoin', title, required: true, maxLength: 120),
          TpSelect('Catégorie', category, domains, (v) {
            setState(() => category = v);
            _touch();
          }, customLabel: 'Autre catégorie (saisir)'),
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
            Expanded(child: TpButton(deadline.isEmpty ? 'Choisir une date' : deadline, _pickDate, dark: false, icon: Icons.event_rounded)),
            if (deadline.isNotEmpty) ...[
              const SizedBox(width: 8),
              _bigRound(Icons.close_rounded, 'Retirer la date', () {
                setState(() {
                  deadline = '';
                  deadlineDate = null;
                });
                _touch();
              }),
            ],
          ]),
          tpNote('Le cahier des charges peut être transmis dans la messagerie du besoin une fois publié.'),
        ],
      ),
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
  Map<String, List<Map<String, dynamic>>> proposals = const {};
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Backend.userId;
    if (uid == null) return setState(() => items = const []);
    final ctx = ref.read(companyContextProvider);
    final r = await Backend.rows('missions', 'id,number,kind,title,description,status,budget_min,budget_max,deadline,created_at', eq: {'client_id': ctx ?? uid, 'kind': 'besoin'}, order: 'created_at', limit: 100);
    // Propositions reçues par besoin : lecture d'accompagnement, sans effet sur la liste si elle échoue.
    final byNeed = <String, List<Map<String, dynamic>>>{};
    final needs = await Backend.rpc('my_needs', const {});
    if (needs.error == null && needs.data is List) {
      for (final n in needs.data as List) {
        if (n is! Map) continue;
        byNeed['${n['id']}'] = [for (final p in (n['proposals'] as List? ?? const [])) if (p is Map) Map<String, dynamic>.from(p)];
      }
    }
    if (!mounted) return;
    setState(() {
      items = r.rows;
      proposals = byNeed;
      error = r.error;
    });
  }

  Future<void> _open([Map<String, dynamic>? m]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => NeedFormPage(existing: m)));
    if (ok == true) _load();
  }

  Future<void> _cancel(Map<String, dynamic> m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Annuler ce besoin ?', style: tpSt(16, w: FontWeight.w700)),
        content: Text('Il n’est plus visible des talents et les propositions en attente sont déclinées : leurs auteurs sont prévenus.', style: tpSt(13, c: tpGrey, h: 1.5)),
        actions: [
          TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(ctx, false), child: const Text('Garder')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: tpRed), onPressed: () => Navigator.pop(ctx, true), child: const Text('Annuler le besoin')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final r = await Backend.rpc('mission_cancel', {'p_id': m['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    invalidateCompanyData(context);
    gToast(context, 'Besoin annulé.');
    _load();
  }

  String _budget(Map<String, dynamic> m) {
    final lo = m['budget_min'], hi = m['budget_max'];
    if (lo == null && hi == null) return '';
    if (lo != null && hi != null) return 'Budget ${fcfa(lo as num)} – ${fcfa(hi as num)}';
    return lo != null ? 'Budget à partir de ${fcfa(lo as num)}' : 'Budget jusqu’à ${fcfa(hi as num)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = items;
    return TpPage(
      title: 'Mes besoins',
      bottom: TpButton('Publier un besoin', () => _open(), icon: Icons.add_rounded),
      children: [
        if (l == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (error != null) TpEmpty(title: 'Lecture impossible', text: Backend.userMessage(error!), icon: Icons.cloud_off_rounded, action: 'Réessayer', onAction: _load)
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
                    _budget(m),
                    if ('${m['deadline'] ?? ''}'.isNotEmpty) 'Avant le ${dateCourte(m['deadline']) == '—' ? m['deadline'] : dateCourte(m['deadline'])}',
                  ].where((e) => e.isNotEmpty).join(' · '), style: tpSt(12, c: tpGrey)),
                ),
                if ('${m['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${m['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
                ..._proposalRows(m),
                if (const ['draft', 'published'].contains('${m['status']}'))
                  Padding(padding: const EdgeInsets.only(top: 10), child: TpButton('Annuler ce besoin', () => _cancel(m), dark: false, danger: true)),
              ]),
            ),
      ],
    );
  }

  List<Widget> _proposalRows(Map<String, dynamic> m) {
    final list = proposals['${m['id']}'] ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) return const [];
    final waiting = list.where((p) => '${p['status']}' == 'submitted').length;
    return [
      Padding(padding: const EdgeInsets.only(top: 10), child: Text('${list.length} proposition${list.length > 1 ? 's' : ''}${waiting > 0 ? ' · $waiting en attente' : ''}', style: tpSt(12.5, w: FontWeight.w700))),
      for (final p in list)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ref.read(openedProposalProvider.notifier).set('${p['id']}');
            gOpen(context, '93b');
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Expanded(child: Text('${p['author_name']} · ${fcfa((p['amount'] as num?) ?? 0)} · ${daysLabel(p['delay_days'])}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12.5, c: tpGrey))),
              Text(proposalStatus(p['status']), style: tpSt(11.5, w: FontWeight.w700, c: tpViolet)),
              const Icon(Icons.chevron_right, size: 18, color: tpGrey),
            ]),
          ),
        ),
    ];
  }
}
