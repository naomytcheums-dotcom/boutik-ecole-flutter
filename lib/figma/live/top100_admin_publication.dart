import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'tp_ui.dart';
import 'top100_admin_common.dart';
import 'top100_admin_form.dart';

/// Publication, correction et archivage des classements mensuels (permission `ranking.publish`, sensible, 2FA exigée des agents qui ont un facteur vérifié).
/// Publier fige le mois (une publication ne change plus) : la confirmation est explicite, le refus du serveur est affiché dans la fenêtre et aucun succès n'est annoncé sans lui.

const _kStatusLabels = {'published': 'Publié', 'archived': 'Archivé'};

const _kExclusions = {
  'eligibles': 'Étudiants éligibles',
  'non_verifies': 'Non vérifiés',
  'suspendus': 'Suspendus',
  'sans_rattachement_verifie': 'Sans rattachement vérifié',
  'non_consentants': 'Sans consentement au classement public',
  'fraude': 'Alerte de fraude',
  'sous_le_seuil': 'Sous le seuil',
};

final top100PeriodsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100List('admin_ranking_periods_list');
}, retry: (_, _) => null);

/// Disponibilité à publier pour un mois (lecture seule, aucune écriture).
final top100ReadinessProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_ranking_readiness', {'p_period': period});
}, retry: (_, _) => null);

final top100CorrectionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100List('admin_ranking_corrections_list');
}, retry: (_, _) => null);

class Top100PublicationSection extends ConsumerStatefulWidget {
  const Top100PublicationSection({super.key});

  @override
  ConsumerState<Top100PublicationSection> createState() => _PublicationState();
}

class _PublicationState extends ConsumerState<Top100PublicationSection> {
  final _period = TextEditingController(text: top100CurrentPeriod());

  @override
  void dispose() {
    _period.dispose();
    super.dispose();
  }

  String get _p => _period.text.trim();

  void _refresh() {
    ref.invalidate(top100PeriodsProvider);
    ref.invalidate(top100ReadinessProvider);
    ref.invalidate(top100CorrectionsProvider);
  }

  Future<void> _publish() async {
    if (!top100ValidPeriod(_p)) {
      await gAlert(context, 'Mois invalide', 'Saisissez le mois au format AAAA-MM, par exemple ${top100CurrentPeriod()}.');
      return;
    }
    Map<String, dynamic>? result;
    final ok = await top100Form(
      context,
      title: 'Publier le classement de $_p ?',
      body: 'La publication fige les rangs, les scores et les empreintes du mois : une fois publié, le classement ne change plus (seule une correction auditée avec motif est possible). '
          'Les étudiants classés sont notifiés. Une seule publication par mois.',
      fields: const [],
      ok: 'Publier',
      submit: (_) async => result = await top100Map('ranking_publish', {'p_period': _p}),
    );
    if (!ok || !mounted) return;
    _refresh();
    final r = result ?? const <String, dynamic>{};
    await gAlert(context, 'Classement publié', '${top100Num(r['entries'])} entrée(s) dans ${top100Num(r['groups'])} groupe(s) ; ${top100Num(r['notified'])} étudiant(s) notifié(s).\nEmpreinte : ${top100Str(r['content_hash'], 'non communiquée')}');
  }

  Future<void> _correct(String period) async {
    Map<String, dynamic>? result;
    final ok = await top100Form(
      context,
      title: 'Corriger le classement de $period',
      body: 'Sans identifiant : retire les entrées des étudiants devenus inéligibles (suspendus, non vérifiés, alerte de fraude). Avec un identifiant : retire les entrées de cet étudiant. '
          'L’entrée est conservée mais invisible ; les rangs sont recalculés, la correction est journalisée (ancienne et nouvelle valeur) et les étudiants touchés sont notifiés.',
      fields: const [
        T100Field('user', 'Identifiant de l’étudiant (facultatif)'),
        T100Field('reason', 'Motif (10 à 500 caractères)', kind: T100Kind.multiline, required: true, maxLength: 500),
      ],
      ok: 'Corriger',
      danger: true,
      validate: (v) => (v['reason'] ?? '').length < 10 ? 'Le motif doit contenir au moins 10 caractères.' : null,
      submit: (v) async => result = await top100Map('ranking_correct', {'p_period': period, 'p_reason': v['reason'], if ((v['user'] ?? '').isNotEmpty) 'p_user': v['user']}),
    );
    if (!ok || !mounted) return;
    _refresh();
    final r = result ?? const <String, dynamic>{};
    gToast(context, '${top100Num(r['voided'])} entrée(s) retirée(s), ${top100Num(r['rank_changes'])} changement(s) de rang.');
  }

  Future<void> _archive(String period) async {
    final ok = await top100Form(
      context,
      title: 'Archiver le classement de $period ?',
      body: 'Un classement archivé reste lisible dans l’historique mais ne peut plus être corrigé.',
      fields: const [T100Field('reason', 'Motif (10 à 500 caractères)', kind: T100Kind.multiline, required: true, maxLength: 500)],
      ok: 'Archiver',
      danger: true,
      validate: (v) => (v['reason'] ?? '').length < 10 ? 'Le motif doit contenir au moins 10 caractères.' : null,
      submit: (v) async => top100Call('ranking_archive', {'p_period': period, 'p_reason': v['reason']}),
    );
    if (!ok || !mounted) return;
    _refresh();
    gToast(context, 'Classement de $period archivé.');
  }

  Future<void> _verify(String period) async {
    try {
      final r = await top100Map('ranking_verify_hash', {'p_period': period});
      if (!mounted) return;
      if (r['found'] != true) {
        await gAlert(context, 'Empreinte', 'Aucun classement publié pour $period.');
      } else {
        await gAlert(context, r['intact'] == true ? 'Classement intact' : 'Empreinte différente', r['intact'] == true
            ? 'Les empreintes recalculées correspondent à celles enregistrées (${top100Num(r['corrections'])} correction(s) au journal).'
            : 'Les empreintes recalculées ne correspondent pas à celles enregistrées : à signaler à l’équipe technique.');
      }
    } catch (e) {
      if (mounted) await gAlert(context, 'Vérification impossible', top100Msg(e));
    }
  }

  Future<void> _journal() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (_) => const _CorrectionsSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final valid = top100ValidPeriod(_p);
    final ready = valid ? ref.watch(top100ReadinessProvider(_p)) : null;
    final periods = ref.watch(top100PeriodsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote('Aucun classement n’est publié tant que l’administration n’a pas décidé les réglages et activé au moins une règle de score. Le serveur refuse sinon, et ce refus est affiché tel quel.'),
      tpSection('Publier un mois'),
      TpField('Mois (AAAA-MM)', _period, maxLength: 7, onChanged: (_) => setState(() {})),
      if (!valid) tpNote('Saisissez le mois au format AAAA-MM.', c: tpRed),
      if (ready != null)
        ready.when(
          loading: top100Loading,
          error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100ReadinessProvider(_p))),
          data: (r) {
            final blockers = [for (final b in (r['blockers'] is List ? r['blockers'] as List : const [])) '$b'];
            final st = top100Obj(r['students']);
            return TpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                top100Chip(r['ready'] == true ? 'Prêt à publier' : 'Pas prêt à publier', c: r['ready'] == true ? tpGreen : tpRed),
                for (final b in blockers) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $b', style: tpSt(12.5, c: tpRed, h: 1.4))),
                const SizedBox(height: 6),
                for (final e in _kExclusions.entries) top100Line(e.value, st[e.key]),
                top100Line('Effectif minimal d’un groupe', r['min_cohort']),
              ]),
            );
          },
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TpButton('Publier', valid ? _publish : null, icon: Icons.publish_rounded)),
        const SizedBox(width: 8),
        Expanded(child: TpButton('Actualiser', _refresh, dark: false, icon: Icons.refresh_rounded)),
      ]),
      tpSection('Classements publiés', hint: 'Du plus récent au plus ancien.'),
      periods.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100PeriodsProvider)),
        data: (list) => list.isEmpty
            ? const TpEmpty(title: 'Aucun classement publié', text: 'Aucune période n’a encore été publiée.', icon: Icons.leaderboard_outlined)
            : Column(children: [
                for (final p in list)
                  TpCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${p['period']}', style: tpSt(15, w: FontWeight.w700))),
                        top100Chip(_kStatusLabels['${p['status']}'] ?? '${p['status']}', c: p['status'] == 'archived' ? tpGrey : tpGreen),
                      ]),
                      top100Line('Publié le', tpDate(p['published_at'])),
                      top100Line('Entrées', p['entries_count']),
                      top100Line('Entrées retirées', p['voided']),
                      top100Line('Corrections', p['corrections']),
                      if (top100Str(p['last_corrected_at']).isNotEmpty) top100Line('Dernière correction', tpDate(p['last_corrected_at'])),
                      if (top100Str(p['archived_at']).isNotEmpty) top100Line('Archivé le', tpDate(p['archived_at'])),
                      top100Line('Empreinte', top100Str(p['content_hash']).length > 16 ? '${top100Str(p['content_hash']).substring(0, 16)}…' : p['content_hash']),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        TpButton('Vérifier l’empreinte', () => _verify('${p['period']}'), compact: true, dark: false),
                        if (p['status'] == 'published') TpButton('Corriger', () => _correct('${p['period']}'), compact: true, danger: true),
                        if (p['status'] == 'published') TpButton('Archiver', () => _archive('${p['period']}'), compact: true, danger: true),
                      ]),
                    ]),
                  ),
              ]),
      ),
      const SizedBox(height: 4),
      TpButton('Journal des corrections', _journal, dark: false, icon: Icons.history_rounded),
    ]);
  }
}

class _CorrectionsSheet extends ConsumerWidget {
  const _CorrectionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(top100CorrectionsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Journal des corrections', style: tpSt(17, w: FontWeight.w700)),
            const SizedBox(height: 8),
            list.when(
              loading: top100Loading,
              error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100CorrectionsProvider)),
              data: (rows) => rows.isEmpty
                  ? Text('Aucune correction enregistrée.', style: tpSt(13, c: tpGrey))
                  : Flexible(
                      child: ListView(shrinkWrap: true, children: [
                        for (final c in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${c['period']} · ${top100Str(c['student'], 'étudiant')} · ${tpDate(c['corrected_at'])}', style: tpSt(12.5, w: FontWeight.w700)),
                              Text('${top100Str(c['field'])} : ${top100Str(c['old_value'], '—')} → ${top100Str(c['new_value'], '—')}', style: tpSt(12, c: tpGrey, h: 1.4)),
                              Text('Motif : ${top100Str(c['reason'], '—')} (par ${top100Str(c['corrected_by'], 'inconnu')})', style: tpSt(12, h: 1.4)),
                            ]),
                          ),
                      ]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
