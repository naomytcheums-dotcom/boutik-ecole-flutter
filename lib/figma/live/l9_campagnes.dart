import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'l9_common.dart';
import 'paiement_messagerie.dart' show selectedPaymentProvider, myPaymentsProvider;
import 'project_pages.dart' show MyProjectsPage;
import 'store.dart' show fcfa;
import 'tp_ui.dart';

const campaignKinds = {'project': 'Financement participatif', 'preorder': 'Précommande', 'sponsoring': 'Parrainage'};
const _campaignStatus = {'draft': 'Brouillon', 'submitted': 'En validation', 'approved': 'Ouverte', 'rejected': 'Refusée', 'closed': 'Clôturée'};

String _err(Object? e) => Backend.userMessage('$e');

Future<List<Map<String, dynamic>>> _campaigns({bool mine = false, String? id}) async {
  final r = await Backend.rpc('campaigns_overview', {'p_mine': mine, 'p_id': ?id});
  if (r.error != null) throw r.error!;
  return r.data is List ? [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)] : const [];
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// « 12 jours restants », « Terminée » ou rien si la date de fin n'est pas encore fixée (campagne non validée).
String _remaining(Map<String, dynamic> c) {
  final end = DateTime.tryParse('${c['ends_at']}');
  if (end == null) return '';
  final left = end.difference(DateTime.now());
  if (left.isNegative) return 'Terminée';
  return left.inDays >= 1 ? '${left.inDays} jour${left.inDays > 1 ? 's' : ''} restant${left.inDays > 1 ? 's' : ''}' : 'Dernières heures';
}

class _Progress extends StatelessWidget {
  const _Progress(this.c);
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) {
    final goal = _int(c['goal']), raised = _int(c['raised']);
    final ratio = goal <= 0 ? 0.0 : (raised / goal).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: const Color(0xFFF2EFF6), color: tpViolet)),
      const SizedBox(height: 6),
      Text('${fcfa(raised)} collectés sur ${fcfa(goal)} · ${_int(c['backers'])} contributeur${_int(c['backers']) > 1 ? 's' : ''}', style: tpSt(12, c: tpGrey)),
    ]);
  }
}

/// Chargement d'une liste de campagnes avec états de chargement, d'erreur et de liste vide.
class _CampaignLoader extends StatefulWidget {
  const _CampaignLoader({required this.mine, required this.builder, required this.empty});
  final bool mine;
  final Widget Function(List<Map<String, dynamic>> rows, Future<void> Function() reload) builder;
  final Widget empty;
  @override
  State<_CampaignLoader> createState() => _CampaignLoaderState();
}

class _CampaignLoaderState extends State<_CampaignLoader> {
  List<Map<String, dynamic>>? rows;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _campaigns(mine: widget.mine);
      if (!mounted) return;
      setState(() {
        rows = r;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        rows = const [];
        error = _err(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = rows;
    if (r == null) return l9Loading();
    if (error != null) return TpEmpty(title: 'Lecture impossible', text: error!, icon: Icons.cloud_off_rounded, action: 'Réessayer', onAction: _load);
    if (r.isEmpty) return widget.empty;
    return widget.builder(r, _load);
  }
}

// ---------------------------------------------------------------- catalogue des campagnes (84b)

/// Campagnes de financement ouvertes (visiteurs compris) : objectif, somme collectée, jours restants ; une fiche par campagne.
class CampaignsPage extends StatelessWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context) => TpPage(title: 'Financement', subtitle: 'Campagnes ouvertes', children: [
        _CampaignLoader(
          mine: false,
          empty: const TpEmpty(title: 'Aucune campagne ouverte', text: 'Les campagnes des porteurs de projet apparaissent ici après validation par le département.', icon: Icons.volunteer_activism_outlined),
          builder: (rows, reload) => Column(children: [
            for (final c in rows)
              TpCard(
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => CampaignDetailPage(campaignId: '${c['id']}', initial: c))).then((_) => reload()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${c['project']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(15, w: FontWeight.w700))),
                    Text(c['open'] == true ? 'Ouverte' : 'Terminée', style: tpSt(12, w: FontWeight.w700, c: c['open'] == true ? tpGreen : tpGrey)),
                  ]),
                  const SizedBox(height: 3),
                  Text([campaignKinds['${c['kind']}'] ?? '', _remaining(c)].where((e) => e.isNotEmpty).join(' · '), style: tpSt(12, c: tpGrey)),
                  const SizedBox(height: 10),
                  _Progress(c),
                ]),
              ),
          ]),
        ),
      ]);
}

/// Fiche d'une campagne : présentation, contreparties, jalons, et contribution par le flux de paiement.
class CampaignDetailPage extends ConsumerStatefulWidget {
  const CampaignDetailPage({super.key, required this.campaignId, this.initial});
  final String campaignId;
  final Map<String, dynamic>? initial;
  @override
  ConsumerState<CampaignDetailPage> createState() => _CampaignDetailState();
}

class _CampaignDetailState extends ConsumerState<CampaignDetailPage> {
  Map<String, dynamic>? c;
  bool loading = true, gone = false, busy = false;

  @override
  void initState() {
    super.initState();
    c = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _campaigns(id: widget.campaignId);
      if (!mounted) return;
      setState(() {
        loading = false;
        gone = r.isEmpty;
        if (r.isNotEmpty) c = r.first;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _contribute() async {
    final cur = c;
    if (cur == null) return;
    if (!await requireLogin(context, ref, 'contribuer à une campagne') || !mounted) return;
    final amount = await showDialog<int>(context: context, builder: (_) => const _AmountDialog());
    if (amount == null || !mounted) return;
    setState(() => busy = true);
    final r = await Backend.rpc('campaign_contribute', {'p_campaign': cur['id'], 'p_amount': amount});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null || r.data == null) return gToast(context, _err(r.error ?? 'Paiement impossible'));
    ref.read(selectedPaymentProvider.notifier).select('${r.data}');
    ref.invalidate(myPaymentsProvider);
    GoRouter.of(context).push('/paiement');
  }

  @override
  Widget build(BuildContext context) {
    final cur = c;
    if (cur == null || gone) {
      return TpPage(title: 'Campagne', children: [
        if (loading) l9Loading() else const TpEmpty(title: 'Campagne indisponible', text: 'Cette campagne n’est pas ouverte ou n’existe pas.', icon: Icons.volunteer_activism_outlined),
      ]);
    }
    final open = cur['open'] == true;
    final mine = cur['mine'] == true;
    final milestones = cur['milestones'] is List ? [for (final m in cur['milestones'] as List) if (m is Map) Map<String, dynamic>.from(m)] : <Map<String, dynamic>>[];
    Widget block(String title, Object? text) => '${text ?? ''}'.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tpSt(13, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('$text'.trim(), style: tpSt(13, c: const Color(0xFF3B3944), h: 1.5)),
            ]),
          );
    return TpPage(
      title: 'Campagne',
      subtitle: campaignKinds['${cur['kind']}'],
      bottom: mine
          ? Text('C’est votre campagne : vous ne pouvez pas y contribuer.', textAlign: TextAlign.center, style: tpSt(12.5, c: tpGrey))
          : open
              ? TpButton('Contribuer', busy ? null : _contribute, busy: busy, icon: Icons.volunteer_activism_outlined)
              : Text('Cette campagne n’accepte plus de contributions.', textAlign: TextAlign.center, style: tpSt(12.5, c: tpGrey)),
      children: [
        Text('${cur['project']}', style: tpSt(20, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([_campaignStatus['${cur['status']}'] ?? '', _remaining(cur)].where((e) => e.isNotEmpty).join(' · '), style: tpSt(12.5, c: tpGrey)),
        const SizedBox(height: 12),
        _Progress(cur),
        block('Présentation', cur['presentation']),
        block('Contreparties', cur['rewards']),
        if (milestones.isNotEmpty) ...[
          tpSection('Jalons'),
          for (final m in milestones)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(m['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: m['done'] == true ? tpGreen : tpGrey),
                const SizedBox(width: 10),
                Expanded(child: Text('${m['title']}${m['target_xaf'] == null ? '' : ' · ${fcfa(_int(m['target_xaf']))}'}${m['due_on'] == null ? '' : ' · avant le ${tpDate(m['due_on'])}'}', style: tpSt(13, h: 1.4))),
              ]),
            ),
        ],
        tpNote('Votre contribution ouvre une demande de paiement par messagerie (Mobile Money). Elle n’est comptée dans la somme collectée qu’une fois le paiement confirmé par la finance.'),
      ],
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog();
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final amount = TextEditingController();

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Votre contribution', style: tpSt(17, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            for (final v in const [1000, 5000, 10000, 25000]) ActionChip(label: Text(fcfa(v)), onPressed: () => setState(() => amount.text = '$v')),
          ]),
          TpField('Montant (FCFA, 500 au minimum)', amount, keyboard: TextInputType.number, maxLength: 9, formatters: [FilteringTextInputFormatter.digitsOnly]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: tpSt(14, c: tpGrey))),
          TextButton(
            onPressed: () {
              final v = int.tryParse(amount.text.trim()) ?? 0;
              if (v < 500) return gToast(context, 'La contribution minimale est de 500 FCFA.');
              Navigator.pop(context, v);
            },
            child: Text('Continuer vers le paiement', style: tpSt(14, w: FontWeight.w700)),
          ),
        ],
      );
}

// ---------------------------------------------------------------- nouvelle campagne (84)

/// Création et envoi d'une campagne pour l'un de MES projets validés. Aucune valeur n'est préremplie ; un brouillon se met à jour.
class CampaignFormPage extends StatelessWidget {
  const CampaignFormPage({super.key});
  @override
  Widget build(BuildContext context) => const ProjectRoleGate(title: 'Nouvelle campagne', action: 'lancer une campagne de financement', child: _CampaignForm());
}

class _CampaignForm extends ConsumerStatefulWidget {
  const _CampaignForm();
  @override
  ConsumerState<_CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends ConsumerState<_CampaignForm> {
  List<Map<String, dynamic>>? projects;
  List<Map<String, dynamic>> drafts = const [];
  String projectId = '', kind = 'project', status = 'draft';
  String? id, rejection;
  final goal = TextEditingController(), days = TextEditingController(), presentation = TextEditingController(), rewards = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [goal, days, presentation, rewards]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final p = await loadMyProjects(approvedOnly: true);
    List<Map<String, dynamic>> mine = const [];
    try {
      mine = [for (final c in await _campaigns(mine: true)) if (const ['draft', 'rejected'].contains('${c['status']}')) c];
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      projects = p;
      drafts = mine;
      if (projectId.isEmpty && p.isNotEmpty) projectId = '${p.first['id']}';
    });
  }

  void _resume(Map<String, dynamic> c) => setState(() {
        id = '${c['id']}';
        kind = '${c['kind']}';
        status = '${c['status']}';
        rejection = c['status'] == 'rejected' ? '${c['review_note'] ?? ''}' : null;
        goal.text = '${c['goal'] ?? ''}';
        days.text = '${c['duration_days'] ?? ''}';
        presentation.text = '${c['presentation'] ?? ''}';
        rewards.text = '${c['rewards'] ?? ''}';
        if ('${c['project_id']}' != 'null' && (projects ?? const []).any((p) => '${p['id']}' == '${c['project_id']}')) projectId = '${c['project_id']}';
      });

  Future<void> _save(bool submit) async {
    final p = (projects ?? const <Map<String, dynamic>>[]).where((x) => '${x['id']}' == projectId).firstOrNull;
    if (p == null) return gToast(context, 'Choisissez l’un de vos projets validés.');
    final g = int.tryParse(goal.text.trim()), d = int.tryParse(days.text.trim());
    if (submit) {
      final missing = [
        if (g == null || g < 1000) 'objectif (1 000 FCFA minimum)',
        if (d == null || d < 7 || d > 90) 'durée (7 à 90 jours)',
        if (presentation.text.trim().length < 30) 'présentation (30 caractères minimum)',
      ];
      if (missing.isNotEmpty) return gToast(context, 'Complétez : ${missing.join(', ')}.');
      if (!await tpConfirm(context, 'Envoyer la campagne ?', 'Elle sera examinée par le département. Une fois envoyée, vous ne pourrez plus la modifier.', yes: 'Envoyer')) return;
    }
    setState(() => busy = true);
    final r = await Backend.rpc('save_campaign', {
      'p_id': id, 'p_kind': kind, 'p_project': '${p['title']}', 'p_goal': g, 'p_duration_days': d, 'p_presentation': presentation.text.trim(),
      'p_rewards': rewards.text.trim(), 'p_submit': submit, 'p_project_id': projectId,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, _err(r.error));
    id = '${r.data}';
    if (submit) {
      gToast(context, 'Campagne envoyée au département pour validation.');
      Navigator.of(context).maybePop();
    } else {
      gToast(context, 'Brouillon enregistré.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = projects;
    return TpPage(
      title: 'Nouvelle campagne',
      subtitle: id == null ? null : 'Brouillon en cours',
      bottom: p == null || p.isEmpty
          ? null
          : Row(children: [
              Expanded(child: TpButton('Brouillon', busy ? null : () => _save(false), dark: false, busy: busy)),
              const SizedBox(width: 10),
              Expanded(child: TpButton('Envoyer', busy ? null : () => _save(true))),
            ]),
      children: [
        if (p == null)
          l9Loading()
        else if (p.isEmpty)
          Column(children: [
            const TpEmpty(title: 'Aucun projet validé', text: 'Une campagne finance l’un de vos projets validés par le département. Publiez d’abord un projet et attendez sa validation.', icon: Icons.lightbulb_outline_rounded),
            TpButton('Mes projets', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MyProjectsPage())), icon: Icons.folder_open_rounded),
          ])
        else ...[
          if (drafts.isNotEmpty) ...[
            tpSection('Reprendre un brouillon'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in drafts) TpButton('${d['project']}${d['status'] == 'rejected' ? ' (refusée)' : ''}', () => _resume(d), dark: false, compact: true, icon: Icons.edit_outlined),
            ]),
            const SizedBox(height: 10),
          ],
          if (rejection != null && rejection!.isNotEmpty) tpNote('Motif du refus : $rejection', c: tpRed),
          ProjectPicker(projects: p, value: projectId, label: 'Projet financé', onChanged: (v) => setState(() => projectId = v)),
          TpChoice('Type de campagne', campaignKinds, kind, (v) => setState(() => kind = v), required: true),
          TpField('Objectif (FCFA)', goal, keyboard: TextInputType.number, maxLength: 10, required: true, formatters: [FilteringTextInputFormatter.digitsOnly]),
          TpField('Durée de la collecte (7 à 90 jours)', days, keyboard: TextInputType.number, maxLength: 2, required: true, formatters: [FilteringTextInputFormatter.digitsOnly]),
          TpField('Présentation', presentation, lines: 5, maxLength: 4000, required: true),
          TpField('Contreparties offertes aux contributeurs', rewards, lines: 3, maxLength: 2000),
          tpNote('La durée court à partir de la validation de la campagne par le département. Les contributions passent par le paiement par messagerie.'),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- jalons (85) et résultats (86) de MES campagnes

/// MES campagnes : jalons à définir et à cocher (écran 85) ou somme collectée et contributeurs (écran 86).
class CampaignOwnerPage extends StatelessWidget {
  const CampaignOwnerPage({super.key, required this.results});
  final bool results;

  @override
  Widget build(BuildContext context) => ProjectRoleGate(
        title: results ? 'Résultats de campagne' : 'Objectifs et jalons',
        action: results ? 'suivre les résultats d’une campagne' : 'définir les jalons d’une campagne',
        child: TpPage(title: results ? 'Résultats de campagne' : 'Objectifs et jalons', subtitle: 'Mes campagnes', children: [
          _CampaignLoader(
            mine: true,
            empty: TpEmpty(
              title: 'Aucune campagne',
              text: results ? 'Vos campagnes et leurs résultats apparaîtront ici dès que vous en aurez créé une.' : 'Créez une campagne pour y définir des jalons.',
              icon: Icons.volunteer_activism_outlined,
              action: 'Nouvelle campagne',
              onAction: () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const CampaignFormPage())),
            ),
            builder: (rows, reload) => Column(children: [for (final c in rows) results ? _ResultCard(c) : _MilestoneCard(c, reload)]),
          ),
        ]),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.c);
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) => TpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${c['project']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(15, w: FontWeight.w700))),
            Text(_campaignStatus['${c['status']}'] ?? '', style: tpSt(12, w: FontWeight.w700, c: c['status'] == 'rejected' ? tpRed : tpViolet)),
          ]),
          const SizedBox(height: 3),
          Text(_remaining(c), style: tpSt(12, c: tpGrey)),
          const SizedBox(height: 10),
          _Progress(c),
          if (c['status'] == 'rejected' && '${c['review_note'] ?? ''}'.isNotEmpty) tpNote('Motif du refus : ${c['review_note']}', c: tpRed),
          tpNote('Seules les contributions dont le paiement est confirmé sont comptées.'),
        ]),
      );
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard(this.c, this.reload);
  final Map<String, dynamic> c;
  final Future<void> Function() reload;

  Future<void> _edit(BuildContext context, [Map<String, dynamic>? m]) async {
    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _MilestoneDialog(m: m));
    if (res == null || !context.mounted) return;
    final r = await Backend.rpc('campaign_milestone_save', {'p_campaign': c['id'], 'p_id': m?['id'], 'p_title': res['title'], 'p_target': res['target'], 'p_due': res['due']});
    if (!context.mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    reload();
  }

  Future<void> _toggle(BuildContext context, Map<String, dynamic> m) async {
    final r = await Backend.rpc('campaign_milestone_done', {'p_id': m['id'], 'p_done': m['done'] != true});
    if (!context.mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    reload();
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> m) async {
    if (!await tpConfirm(context, 'Supprimer ce jalon ?', '« ${m['title']} » sera retiré de la campagne.')) return;
    final r = await Backend.rpc('campaign_milestone_delete', {'p_id': m['id']});
    if (!context.mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final ms = c['milestones'] is List ? [for (final m in c['milestones'] as List) if (m is Map) Map<String, dynamic>.from(m)] : <Map<String, dynamic>>[];
    return TpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['project']}', style: tpSt(15, w: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('Objectif : ${fcfa(_int(c['goal']))} · ${_campaignStatus['${c['status']}'] ?? ''}', style: tpSt(12, c: tpGrey)),
        const SizedBox(height: 8),
        if (ms.isEmpty) Text('Aucun jalon défini.', style: tpSt(12.5, c: tpGrey)),
        for (final m in ms)
          Row(children: [
            IconButton(
              tooltip: m['done'] == true ? 'Marquer comme à faire' : 'Marquer comme atteint',
              icon: Icon(m['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: m['done'] == true ? tpGreen : tpGrey),
              onPressed: () => _toggle(context, m),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _edit(context, m),
                child: Text('${m['title']}${m['target_xaf'] == null ? '' : ' · ${fcfa(_int(m['target_xaf']))}'}${m['due_on'] == null ? '' : ' · avant le ${tpDate(m['due_on'])}'}', style: tpSt(13, h: 1.4)),
              ),
            ),
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline_rounded, color: tpGrey, size: 20), onPressed: () => _delete(context, m)),
          ]),
        const SizedBox(height: 6),
        TpButton('Ajouter un jalon', () => _edit(context), dark: false, compact: true, icon: Icons.add_rounded),
      ]),
    );
  }
}

class _MilestoneDialog extends StatefulWidget {
  const _MilestoneDialog({this.m});
  final Map<String, dynamic>? m;
  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  late final title = TextEditingController(text: '${widget.m?['title'] ?? ''}');
  late final target = TextEditingController(text: widget.m?['target_xaf'] == null ? '' : '${widget.m!['target_xaf']}');
  late DateTime? due = DateTime.tryParse('${widget.m?['due_on']}');

  @override
  void dispose() {
    title.dispose();
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(widget.m == null ? 'Nouveau jalon' : 'Modifier le jalon', style: tpSt(17, w: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TpField('Jalon', title, maxLength: 120),
            TpField('Montant visé (FCFA, facultatif)', target, keyboard: TextInputType.number, maxLength: 10, formatters: [FilteringTextInputFormatter.digitsOnly]),
            TpButton(due == null ? 'Choisir une échéance (facultatif)' : 'Échéance : ${tpDate(due!.toIso8601String())}', () async {
              final d = await showDatePicker(context: context, initialDate: due ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 900)));
              if (d != null) setState(() => due = d);
            }, dark: false, compact: true, icon: Icons.event_outlined),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: tpSt(14, c: tpGrey))),
          TextButton(
            onPressed: () {
              if (title.text.trim().length < 3) return gToast(context, 'Décrivez le jalon en 3 caractères au moins.');
              final d = due;
              Navigator.pop(context, {
                'title': title.text.trim(),
                'target': int.tryParse(target.text.trim()),
                'due': d == null ? null : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
              });
            },
            child: Text('Enregistrer', style: tpSt(14, w: FontWeight.w700)),
          ),
        ],
      );
}
