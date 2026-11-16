import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart' show requireLogin;
import 'backend.dart';
import 'communities.dart' show communityFeedProvider;
import 'talents.dart' show askText;

/// Modération d'une communauté : signalement d'un contenu par un membre, retrait d'un message, d'une question ou d'une réponse (par son auteur ou un responsable),
/// file des signalements et publications masquées (rétablissement) pour les responsables. Les décisions passent par des fonctions serveur qui prévenent les personnes concernées.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _line = Color(0xFFECE8F2);
const _red = Color(0xFFB42318);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Petit lien d'action (Signaler, Retirer…) sous un contenu.
Widget communityActionLink(String label, VoidCallback onTap, {Color color = _grey}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.fromLTRB(0, 6, 14, 2), child: Text(label, style: _st(11.5, w: FontWeight.w600, c: color))),
    );

/// Signale un contenu de la communauté (kind : chat, question, answer, post).
Future<void> communityReportContent(BuildContext context, WidgetRef ref, {required String communityId, required String kind, required String id}) async {
  if (!await requireLogin(context, ref, 'signaler un contenu') || !context.mounted) return;
  final why = await askText(context, title: 'Signaler ce contenu', body: 'Les responsables de la communauté examineront votre signalement.', hint: 'Insulte, spam, hors sujet…', ok: 'Signaler', min: 3);
  if (why == null || !context.mounted) return;
  final r = await Backend.rpc('community_report', {'p_community': communityId, 'p_kind': kind, 'p_ref': id, 'p_reason': why});
  if (context.mounted) gToast(context, r.error != null ? Backend.userMessage(r.error!) : 'Signalement transmis aux responsables de la communauté');
}

/// Retire un contenu : son auteur le supprime directement ; un responsable donne un motif, envoyé à l'auteur. Renvoie vrai si le serveur l'a retiré.
Future<bool> communityRemoveContent(BuildContext context, {required String fn, required Map<String, dynamic> params, required bool mine}) async {
  String? note;
  if (!mine) {
    note = await askText(context, title: 'Retirer ce contenu', body: 'Le motif est envoyé à son auteur.', hint: 'Motif (3 caractères au moins)', ok: 'Retirer', min: 3);
    if (note == null || !context.mounted) return false;
  }
  final r = await Backend.rpc(fn, {...params, 'p_note': ?note});
  if (!context.mounted) return false;
  if (r.error != null) {
    await gAlert(context, 'Action impossible', Backend.userMessage(r.error!));
    return false;
  }
  gToast(context, mine ? 'Supprimé' : 'Contenu retiré : l’auteur est prévenu.');
  return true;
}

/// Onglet « Modération » (propriétaire, administrateurs, modérateurs).
class CommunityModerationTab extends ConsumerStatefulWidget {
  const CommunityModerationTab({super.key, required this.communityId});
  final String communityId;

  @override
  ConsumerState<CommunityModerationTab> createState() => _ModerationState();
}

class _ModerationState extends ConsumerState<CommunityModerationTab> {
  List<Map<String, dynamic>>? _reports, _hidden;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Backend.rpc('community_reports_list', {'p_community': widget.communityId});
    final b = await Backend.rpc('community_hidden_posts', {'p_community': widget.communityId});
    if (!mounted) return;
    List<Map<String, dynamic>> rows(Object? d) => [for (final x in (d is List ? d : const [])) Map<String, dynamic>.from(x as Map)];
    setState(() {
      _failed = a.error != null && b.error != null;
      _reports = rows(a.data);
      _hidden = rows(b.data);
    });
  }

  Future<void> _close(Map<String, dynamic> r, bool remove) async {
    String? note;
    if (remove) {
      note = await askText(context, title: 'Retirer le contenu signalé', body: 'Le motif est envoyé à son auteur.', hint: 'Motif (3 caractères au moins)', ok: 'Retirer', min: 3);
      if (note == null || !mounted) return;
    }
    final res = await Backend.rpc('community_report_close', {'p_report': r['id'], 'p_remove': remove, 'p_note': note});
    if (!mounted) return;
    if (res.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(res.error!));
    gToast(context, remove ? 'Contenu retiré : l’auteur est prévenu.' : 'Signalement classé.');
    await _load();
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  Future<void> _restore(Map<String, dynamic> p) async {
    final res = await Backend.rpc('moderate_community_post', {'p_post': p['id'], 'p_hide': false});
    if (!mounted) return;
    if (res.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(res.error!));
    gToast(context, 'Publication rétablie : l’auteur est prévenu.');
    await _load();
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  static const _kinds = {'chat': 'Message du chat', 'question': 'Question', 'answer': 'Réponse', 'post': 'Publication'};

  Widget _card(Widget child) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)), child: child);

  Widget _btn(String label, VoidCallback onTap, {bool dark = true}) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(constraints: const BoxConstraints(minHeight: 44), alignment: Alignment.center, decoration: BoxDecoration(color: dark ? _ink : Colors.white, borderRadius: BorderRadius.circular(6), border: dark ? null : Border.all(color: _line)), child: Text(label, style: _st(13, w: FontWeight.w700, c: dark ? Colors.white : _ink))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_failed) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('La modération est indisponible pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))));
    if (_reports == null || _hidden == null) return const Center(child: CircularProgressIndicator());
    final reports = _reports!, hidden = _hidden!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Signalements (${reports.length})', style: _st(15, w: FontWeight.w800)),
        const SizedBox(height: 8),
        if (reports.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text('Aucun contenu signalé.', style: _st(13, c: _grey))),
        for (final r in reports)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_kinds['${r['kind']}'] ?? 'Contenu'} · ${r['author'] ?? ''}', style: _st(12.5, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${r['preview'] ?? 'Contenu déjà retiré'}', style: _st(13.5).copyWith(height: 1.4)),
            const SizedBox(height: 6),
            Text('Signalé par ${r['reporter']} : ${r['reason']}', style: _st(12, c: _red)),
            const SizedBox(height: 10),
            Row(children: [_btn('Retirer', () => _close(r, true)), const SizedBox(width: 10), _btn('Garder', () => _close(r, false), dark: false)]),
          ])),
        const SizedBox(height: 10),
        Text('Publications masquées (${hidden.length})', style: _st(15, w: FontWeight.w800)),
        const SizedBox(height: 8),
        if (hidden.isEmpty) Text('Aucune publication masquée.', style: _st(13, c: _grey)),
        for (final p in hidden)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['author']}', style: _st(12.5, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${p['body']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: _st(13.5).copyWith(height: 1.4)),
            if ('${p['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motif : ${p['note']}', style: _st(12, c: _red))),
            const SizedBox(height: 10),
            Row(children: [_btn('Rétablir', () => _restore(p), dark: false)]),
          ])),
      ]),
    );
  }
}
