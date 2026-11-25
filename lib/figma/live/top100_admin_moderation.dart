import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'tp_ui.dart';
import 'top100_admin_common.dart';
import 'top100_admin_form.dart';

/// Anti-fraude et contestations (permission `ranking.moderate`, 2FA exigée des agents qui ont un facteur vérifié). La neutralisation automatique est toujours réversible
/// par un humain : chaque décision exige un motif, est notifiée à l'étudiant et auditée par le serveur. Aucun détail n'est inventé : tout vient des fonctions serveur.

const _kSignals = {
  'self_dealing': 'Auto-interaction',
  'linked_accounts': 'Comptes liés',
  'repeat_actor': 'Même auteur répété',
  'burst': 'Rafale d’activités',
  'moderation': 'Modération',
  'other': 'Autre',
};

const _kFlagStatus = {'open': 'Ouverte', 'confirmed': 'Confirmée', 'dismissed': 'Classée sans suite'};
const _kDisputeStatus = {'open': 'Ouverte', 'accepted': 'Acceptée', 'rejected': 'Rejetée'};
const _kEventStatus = {'confirmed': 'Comptée', 'cancelled': 'Annulée', 'neutralized': 'Neutralisée'};

final top100FlagsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100List('admin_talent_flags_list', {'p_status': status.isEmpty ? null : status});
}, retry: (_, _) => null);

final top100DisputesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100List('admin_talent_disputes_list', {'p_status': status.isEmpty ? null : status});
}, retry: (_, _) => null);

/// Activités d'un étudiant (clé = identifiant du compte) : `{ total, events: [...] }`.
final top100EventsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, user) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_talent_events_list', {'p_user': user});
}, retry: (_, _) => null);

class Top100FlagsSection extends ConsumerStatefulWidget {
  const Top100FlagsSection({super.key});

  @override
  ConsumerState<Top100FlagsSection> createState() => _FlagsState();
}

class _FlagsState extends ConsumerState<Top100FlagsSection> {
  String _status = 'open';

  Future<void> _events(Map<String, dynamic> f) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (_) => _EventsSheet(user: '${f['user_id']}', student: top100Str(f['student'], 'Étudiant')),
      );

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(top100FlagsProvider(_status));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote('Une activité suspecte est neutralisée automatiquement (0 point, tracée, alerte ouverte) ; un humain peut la rétablir. Aucun classement ne repose sur une alerte non traitée.'),
      TpChoice('Statut', {'open': 'Ouvertes', 'confirmed': 'Confirmées', 'dismissed': 'Sans suite', '': 'Toutes'}, _status, (v) => setState(() => _status = v)),
      flags.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100FlagsProvider(_status))),
        data: (rows) => rows.isEmpty
            ? const TpEmpty(title: 'Aucune alerte', text: 'Aucune alerte de fraude ne correspond à ce filtre.', icon: Icons.shield_outlined)
            : Column(children: [
                for (final f in rows)
                  TpCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(top100Str(f['student'], 'Étudiant'), style: tpSt(14, w: FontWeight.w700))),
                        top100Chip(_kFlagStatus['${f['status']}'] ?? '${f['status']}', c: f['status'] == 'open' ? tpRed : tpGrey),
                      ]),
                      top100Line('Signal', _kSignals['${f['signal']}'] ?? f['signal']),
                      top100Line('Détecté par', f['detected_by'] == 'auto' ? 'Détection automatique' : 'Modérateur'),
                      top100Line('Activité', f['rule']),
                      top100Line('Le', tpDate(f['created_at'])),
                      if (top100Str(f['detail']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${f['detail']}', style: tpSt(12, c: tpGrey, h: 1.4))),
                      if (top100Str(f['decision_note']).isNotEmpty) Text('Décision : ${f['decision_note']}', style: tpSt(12, h: 1.4)),
                      const SizedBox(height: 10),
                      TpButton('Voir les activités de l’étudiant', () => _events(f), compact: true, dark: false),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

class _EventsSheet extends ConsumerWidget {
  const _EventsSheet({required this.user, required this.student});
  final String user, student;

  Future<void> _act(BuildContext context, WidgetRef ref, Map<String, dynamic> e, {required bool neutralize}) async {
    final ok = await top100Form(
      context,
      title: neutralize ? 'Neutraliser cette activité ?' : 'Rétablir cette activité ?',
      body: neutralize
          ? 'Les points sont retirés, une alerte de modération est créée, l’étudiant est notifié (il peut contester) et l’action est auditée.'
          : 'Les alertes sans suite sont classées, les points sont attribués selon les règles en vigueur, l’étudiant est notifié et l’action est auditée.',
      fields: const [T100Field('reason', 'Motif (10 à 500 caractères)', kind: T100Kind.multiline, required: true, maxLength: 500)],
      ok: neutralize ? 'Neutraliser' : 'Rétablir',
      danger: neutralize,
      validate: (v) => (v['reason'] ?? '').length < 10 ? 'Le motif doit contenir au moins 10 caractères.' : null,
      submit: (v) async => top100Call(neutralize ? 'admin_talent_event_neutralize' : 'admin_talent_event_restore', {'p_event': e['id'], 'p_reason': v['reason']}),
    );
    if (ok && context.mounted) {
      gToast(context, neutralize ? 'Activité neutralisée.' : 'Activité rétablie.');
      ref.invalidate(top100EventsProvider(user));
      ref.invalidate(top100FlagsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(top100EventsProvider(user));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Activités de $student', style: tpSt(17, w: FontWeight.w700)),
            const SizedBox(height: 8),
            events.when(
              loading: top100Loading,
              error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100EventsProvider(user))),
              data: (d) {
                final rows = top100Rows(d['events']);
                if (rows.isEmpty) return Text('Aucune activité enregistrée pour cet étudiant.', style: tpSt(13, c: tpGrey));
                return Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Total de points : ${top100Num(d['total'])}', style: tpSt(13, w: FontWeight.w600))),
                    for (final e in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${top100Str(e['rule'])} · ${tpDate(e['occurred_at'])}', style: tpSt(12.5, w: FontWeight.w700))),
                            top100Chip(_kEventStatus['${e['status']}'] ?? '${e['status']}', c: e['status'] == 'confirmed' ? tpGreen : tpRed),
                          ]),
                          Text('${top100Num(e['points'])} point(s)${top100Str(e['status_reason']).isEmpty ? '' : ' · ${e['status_reason']}'}', style: tpSt(12, c: tpGrey, h: 1.4)),
                          if (e['status'] == 'confirmed' || e['status'] == 'neutralized')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TpButton(e['status'] == 'confirmed' ? 'Neutraliser' : 'Rétablir', () => _act(context, ref, e, neutralize: e['status'] == 'confirmed'), compact: true, dark: false, danger: e['status'] == 'confirmed'),
                            ),
                        ]),
                      ),
                  ]),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class Top100DisputesSection extends ConsumerStatefulWidget {
  const Top100DisputesSection({super.key});

  @override
  ConsumerState<Top100DisputesSection> createState() => _DisputesState();
}

class _DisputesState extends ConsumerState<Top100DisputesSection> {
  String _status = 'open';

  Future<void> _decide(Map<String, dynamic> d, String decision) async {
    final accepted = decision == 'accepted';
    final ok = await top100Form(
      context,
      title: accepted ? 'Accepter la contestation ?' : 'Rejeter la contestation ?',
      body: accepted
          ? 'L’activité neutralisée est rétablie et ses points sont attribués. La décision est définitive ; l’étudiant est notifié et l’action est auditée.'
          : 'L’activité reste neutralisée. La décision est définitive ; l’étudiant est notifié avec votre réponse et l’action est auditée.',
      fields: const [T100Field('note', 'Réponse à l’étudiant (10 à 1000 caractères)', kind: T100Kind.multiline, required: true, maxLength: 1000)],
      ok: accepted ? 'Accepter' : 'Rejeter',
      danger: !accepted,
      validate: (v) => (v['note'] ?? '').length < 10 ? 'La réponse doit contenir au moins 10 caractères.' : null,
      submit: (v) async => top100Call('admin_talent_dispute_decide', {'p_id': d['id'], 'p_decision': decision, 'p_note': v['note']}),
    );
    if (ok && mounted) {
      gToast(context, accepted ? 'Contestation acceptée.' : 'Contestation rejetée.');
      ref.invalidate(top100DisputesProvider);
      ref.invalidate(top100FlagsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(top100DisputesProvider(_status));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote('L’étudiant peut contester une activité neutralisée. Vous ne pouvez pas décider de votre propre contestation ; une décision est définitive.'),
      TpChoice('Statut', {'open': 'Ouvertes', 'accepted': 'Acceptées', 'rejected': 'Rejetées', '': 'Toutes'}, _status, (v) => setState(() => _status = v)),
      list.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100DisputesProvider(_status))),
        data: (rows) => rows.isEmpty
            ? const TpEmpty(title: 'Aucune contestation', text: 'Aucune contestation ne correspond à ce filtre.', icon: Icons.gavel_outlined)
            : Column(children: [
                for (final d in rows)
                  TpCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(top100Str(d['student'], 'Étudiant'), style: tpSt(14, w: FontWeight.w700))),
                        top100Chip(_kDisputeStatus['${d['status']}'] ?? '${d['status']}', c: d['status'] == 'open' ? tpRed : tpGrey),
                      ]),
                      top100Line('Activité', d['rule']),
                      top100Line('État de l’activité', _kEventStatus['${d['event_status']}'] ?? d['event_status']),
                      top100Line('Le', tpDate(d['created_at'])),
                      if (top100Str(d['event_reason']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Cause : ${d['event_reason']}', style: tpSt(12, c: tpGrey, h: 1.4))),
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text('« ${top100Str(d['message'])} »', style: tpSt(12.5, h: 1.45))),
                      if (top100Str(d['resolution']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Décision : ${d['resolution']}', style: tpSt(12, c: tpGrey, h: 1.4))),
                      if (d['status'] == 'open') ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: TpButton('Accepter', () => _decide(d, 'accepted'), compact: true)),
                          const SizedBox(width: 8),
                          Expanded(child: TpButton('Rejeter', () => _decide(d, 'rejected'), compact: true, danger: true)),
                        ]),
                      ],
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}
