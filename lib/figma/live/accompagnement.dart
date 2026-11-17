import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'l9_common.dart' show loadMyProjects;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Accompagnement des projets (écran 204 « Coup de pouce startup ») : le porteur demande un mentor, un financement, du matériel ou des compétences
/// pour l'un de SES projets ; le département répond et il suit l'état. Fonctions serveur : migration 20261117050500.

const _kinds = {'mentor': 'Un mentor', 'funding': 'Un financement', 'equipment': 'Du matériel', 'skills': 'Des compétences'};
const _statuses = {'open': 'En attente', 'in_progress': 'Prise en charge', 'done': 'Réponse reçue', 'declined': 'Non retenue'};

Future<List<Map<String, dynamic>>> _rows(String fn) async {
  final r = await marcheCall(fn, const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final mySupportRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _rows('my_support_requests');
}, retry: (_, _) => null);

final supportQueueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _rows('support_requests_to_handle'), retry: (_, _) => null);

Widget _card(Widget child) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: child,
    );

InputDecoration _deco(String l) => InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

class SupportRequestsScreen extends ConsumerWidget {
  const SupportRequestsScreen({super.key});

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final projects = await loadMyProjects();
    if (!context.mounted) return;
    if (projects.isEmpty) return gAlert(context, 'Aucun projet', 'L’accompagnement se demande pour l’un de vos projets : créez-le d’abord depuis « Soumettre mon projet ».');
    var project = '${projects.first['id']}', kind = 'mentor';
    String? error;
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Demander un accompagnement', style: mst(17, w: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(initialValue: project, isExpanded: true, decoration: _deco('Projet'), items: [for (final p in projects) DropdownMenuItem(value: '${p['id']}', child: Text('${p['title']}', overflow: TextOverflow.ellipsis))], onChanged: (v) => set(() => project = v ?? project)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [for (final k in _kinds.entries) ChoiceChip(label: Text(k.value), selected: kind == k.key, onSelected: (_) => set(() => kind = k.key))]),
              const SizedBox(height: 10),
              TextField(controller: message, maxLines: 4, maxLength: 1000, decoration: _deco('Votre besoin (10 caractères au moins)')),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: mst(12.5, w: FontWeight.w600, c: kRed))),
            ]),
          ),
          actions: [
            TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: mst(14, c: kGrey))),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () {
                if (message.text.trim().length < 10) return set(() => error = 'Expliquez votre besoin en 10 caractères au moins.');
                Navigator.pop(d, true);
              },
              child: Text('Envoyer', style: mst(14, w: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('support_request_create', {'p_project': project, 'p_kind': kind, 'p_message': message.text});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Demande non envoyée', Backend.userMessage('${r.error}'));
    ref.invalidate(mySupportRequestsProvider);
    gToast(context, 'Demande envoyée au département : vous suivez son état ici.');
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, Map<String, dynamic> x, String status) async {
    final response = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(status == 'in_progress' ? 'Prendre en charge' : (status == 'done' ? 'Répondre' : 'Refuser la demande'), style: mst(17, w: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: response, maxLines: 4, maxLength: 1000, decoration: _deco(status == 'in_progress' ? 'Message (facultatif)' : 'Réponse au porteur')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: mst(12.5, w: FontWeight.w600, c: kRed))),
          ]),
          actions: [
            TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: mst(14, c: kGrey))),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () {
                if (status != 'in_progress' && response.text.trim().length < 5) return set(() => error = 'Rédigez une réponse (5 caractères au moins).');
                Navigator.pop(d, true);
              },
              child: Text('Confirmer', style: mst(14, w: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('support_request_handle', {'p_id': x['id'], 'p_status': status, 'p_response': response.text});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Impossible', Backend.userMessage('${r.error}'));
    ref.invalidate(supportQueueProvider);
    gToast(context, 'Décision enregistrée ; le porteur est notifié.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = roleKey(ref.watch(authProvider).current);
    final staff = const {'dept', 'admin'}.contains(role);
    final mine = ref.watch(mySupportRequestsProvider);
    return MarchePage(
      title: 'Accompagnement',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text('Demandez un mentor, un financement, du matériel ou des compétences pour l’un de vos projets : le département de votre projet répond et vous suivez ici l’état de chaque demande. Aucun financement n’est promis : la réponse est rédigée par le département.', style: mst(12.5, c: kGrey).copyWith(height: 1.45))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Nouvelle demande', () => _new(context, ref), icon: Icons.add)),
        mSectionTitle('Mes demandes'),
        mAsync<List<Map<String, dynamic>>>(
          mine,
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune demande pour le moment.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final x in l)
                    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text('${x['project']}', style: mst(14.5, w: FontWeight.w800))), Text(_statuses['${x['status']}'] ?? '${x['status']}', style: mst(11.5, w: FontWeight.w700, c: x['status'] == 'done' ? kGreen : (x['status'] == 'declined' ? kRed : kViolet)))]),
                      Text(_kinds['${x['kind']}'] ?? '${x['kind']}', style: mst(12, w: FontWeight.w600, c: kViolet)),
                      const SizedBox(height: 4),
                      Text('${x['message']}', style: mst(13).copyWith(height: 1.4)),
                      if ('${x['response'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Réponse du département : ${x['response']}', style: mst(12.5, w: FontWeight.w600, c: kGreen).copyWith(height: 1.4))),
                    ])),
                ]),
        ),
        if (staff) ...[
          mSectionTitle('Demandes à traiter'),
          mAsync<List<Map<String, dynamic>>>(
            ref.watch(supportQueueProvider),
            (l) => l.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune demande en attente.', style: mst(13, c: kGrey)))
                : Column(children: [
                    for (final x in l)
                      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${x['project']} · ${x['owner']}', style: mst(14, w: FontWeight.w800)),
                        Text('${_kinds[x['kind']] ?? x['kind']} · ${_statuses[x['status']] ?? x['status']}', style: mst(12, w: FontWeight.w600, c: kViolet)),
                        const SizedBox(height: 4),
                        Text('${x['message']}', style: mst(13).copyWith(height: 1.4)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (x['status'] == 'open') mButton('Prendre en charge', () => _handle(context, ref, x, 'in_progress'), dark: false),
                          mButton('Répondre', () => _handle(context, ref, x, 'done'), dark: false),
                          mButton('Refuser', () => _handle(context, ref, x, 'declined'), dark: false),
                        ]),
                      ])),
                  ]),
          ),
        ],
      ]),
    );
  }
}
