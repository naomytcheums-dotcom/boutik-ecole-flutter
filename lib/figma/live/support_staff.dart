import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'tp_ui.dart';

/// Boîte du support (comptes support et administrateur) : demandes d'aide des utilisateurs et conversations signalées.

String _date(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

final staffTicketsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || Backend.userId == null) return null;
  final r = await Backend.rows('support_tickets', 'id,subject,message,status,reply,created_at,user_id', order: 'created_at', limit: 100);
  return r.error != null ? null : [for (final x in r.rows) if (x['status'] != 'closed') x];
}, retry: (_, _) => null);

final staffReportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || Backend.userId == null) return null;
  final r = await Backend.rpc('message_reports_list', {'p_status': 'open', 'p_limit': 50});
  if (r.error != null || r.data is! List) return null;
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

class SupportInboxScreen extends ConsumerStatefulWidget {
  const SupportInboxScreen({super.key});
  @override
  ConsumerState<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends ConsumerState<SupportInboxScreen> {
  int tab = 0;

  Future<void> _reply(Map<String, dynamic> t) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Répondre : ${t['subject']}'),
        content: TextField(controller: c, maxLines: 5, maxLength: 2000, autofocus: true, decoration: const InputDecoration(hintText: 'Votre réponse')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Envoyer')),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final r = await Backend.rpc('support_ticket_reply', {'p_id': t['id'], 'p_reply': text});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    gToast(context, 'Réponse envoyée.');
    ref.invalidate(staffTicketsProvider);
  }

  Future<void> _closeTicket(Map<String, dynamic> t) async {
    final r = await Backend.rpc('support_ticket_close', {'p_id': t['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    ref.invalidate(staffTicketsProvider);
  }

  Future<void> _closeReport(Map<String, dynamic> x) async {
    final r = await Backend.rpc('message_report_set_status', {'p_id': x['id'], 'p_status': 'closed'});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    ref.invalidate(staffReportsProvider);
  }

  Widget _tickets(List<Map<String, dynamic>>? rows) {
    if (rows == null) return tpNote('Les demandes ne peuvent pas être chargées pour le moment.');
    if (rows.isEmpty) return const TpEmpty(title: 'Aucune demande ouverte', text: 'Les nouvelles demandes d’aide apparaîtront ici.', icon: Icons.support_agent_rounded);
    return Column(children: [
      for (final t in rows)
        TpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['subject']}', style: tpSt(14, w: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${_date(t['created_at'])} · ${ticketLabel(t['status'])}', style: tpSt(11.5, c: tpGrey)),
            const SizedBox(height: 8),
            Text('${t['message']}', style: tpSt(13, c: tpGrey, h: 1.5)),
            if ('${t['reply'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Votre réponse : ${t['reply']}', style: tpSt(12.5, c: tpViolet, h: 1.5)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TpButton(t['reply'] == null ? 'Répondre' : 'Répondre à nouveau', () => _reply(t), compact: true)),
              const SizedBox(width: 8),
              Expanded(child: TpButton('Clôturer', () => _closeTicket(t), dark: false, compact: true)),
            ]),
          ]),
        ),
    ]);
  }

  static String ticketLabel(Object? s) => switch ('$s') { 'answered' => 'Répondue', _ => 'Ouverte' };

  Widget _reports(List<Map<String, dynamic>>? rows) {
    if (rows == null) return tpNote('Les signalements ne peuvent pas être chargés pour le moment.');
    if (rows.isEmpty) return const TpEmpty(title: 'Aucun signalement ouvert', text: 'Les conversations signalées par les utilisateurs apparaîtront ici.', icon: Icons.flag_outlined);
    return Column(children: [
      for (final x in rows)
        TpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Signalé par ${x['reporter'] ?? 'un utilisateur'}', style: tpSt(14, w: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_date(x['created_at']), style: tpSt(11.5, c: tpGrey)),
            const SizedBox(height: 8),
            Text('Motif : ${x['reason']}', style: tpSt(13, h: 1.5)),
            const SizedBox(height: 8),
            Text('Derniers messages', style: tpSt(12, w: FontWeight.w700, c: tpViolet)),
            for (final m in (x['messages'] as List? ?? const []))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${(m as Map)['sender'] ?? '—'} : ${m['kind'] == 'text' ? m['body'] : '[${m['kind']}]'}', style: tpSt(12.5, c: tpGrey, h: 1.4)),
              ),
            const SizedBox(height: 10),
            TpButton('Marquer comme traité', () => _closeReport(x), dark: false, compact: true),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(staffTicketsProvider);
    final reports = ref.watch(staffReportsProvider);
    Widget body(AsyncValue<List<Map<String, dynamic>>?> v, Widget Function(List<Map<String, dynamic>>?) build) =>
        v.when(loading: () => tpNote('Chargement…'), error: (_, _) => build(null), data: build);
    return TpPage(
      title: 'Boîte du support',
      children: [
        TpChoice('Affichage', const {'tickets': 'Demandes d’aide', 'reports': 'Conversations signalées'}, tab == 0 ? 'tickets' : 'reports', (v) => setState(() => tab = v == 'tickets' ? 0 : 1)),
        const SizedBox(height: 8),
        if (tab == 0) body(tickets, _tickets) else body(reports, _reports),
      ],
    );
  }
}
