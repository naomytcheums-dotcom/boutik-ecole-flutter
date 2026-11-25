import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'tp_ui.dart';
import 'top100_admin_common.dart';
import 'top100_admin_form.dart';

/// Règles de score et réglages du classement (permission `ranking.rules`). Aucun poids ni seuil n'est fixé par le code : une règle naît en brouillon (0 point, inactive)
/// et c'est l'administration qui décide. Chaque changement exige un motif, est versionné et audité par le serveur (2FA exigée des agents qui ont un facteur vérifié).

const _kRuleFamilies = {
  'live_hosted': 'Live animé',
  'replay_completed_100': 'Replay suivi en entier',
  'badge_verified': 'Badge vérifié',
  'certificate_verified': 'Certificat vérifié',
  'project_published_with_proof': 'Projet publié avec preuves',
  'challenge_participation': 'Participation à un défi',
  'review_verified': 'Avis vérifié',
  'sale_confirmed': 'Vente confirmée',
  'mission_validated': 'Mission validée',
  'skill_demonstrated': 'Compétence démontrée',
  'collaboration': 'Collaboration',
  'event_attended': 'Événement suivi',
  'assessment_validated': 'Évaluation validée',
};

const _kSettingLabels = {
  'min_cohort': 'Effectif minimal d’un groupe publié',
  'burst_count': 'Rafale : nombre d’activités',
  'burst_minutes': 'Rafale : fenêtre (minutes)',
  'actor_repeat': 'Même auteur répété (30 jours)',
};

const kRankingScopes = {'national': 'National', 'program': 'Filière', 'institution': 'Établissement', 'department': 'Département', 'domain': 'Domaine'};

/// Règles de score (`rules`) et réglages réglés (`settings`).
final top100RulesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_talent_rules_list');
}, retry: (_, _) => null);

/// Réglages de publication du classement (seuil, nombre d'entrées, portées) : « non décidé » tant que l'administration n'a rien fixé.
final top100SettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_ranking_settings_get');
}, retry: (_, _) => null);

class Top100RulesSection extends ConsumerWidget {
  const Top100RulesSection({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(top100RulesProvider);
    ref.invalidate(top100SettingsProvider);
  }

  Future<void> _editRule(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final ok = await top100Form(
      context,
      title: top100Str(r['label'], '${r['code']}'),
      body: 'Une règle active exige au moins 1 point. La version augmente si une valeur change ; l’ancien état reste dans l’historique.',
      fields: [
        T100Field('points', 'Points par activité (0 à 1000)', kind: T100Kind.integer, initial: top100Str(r['points'], '0'), required: true),
        T100Field('cap_day', 'Plafond par jour (vide = aucun)', kind: T100Kind.integer, initial: top100Str(r['cap_per_day'])),
        T100Field('cap_period', 'Plafond par mois (vide = aucun)', kind: T100Kind.integer, initial: top100Str(r['cap_per_period'])),
        T100Field('weight', 'Poids de la qualité (0 à 1)', kind: T100Kind.decimal, initial: top100Str(r['quality_weight'], '0'), required: true),
        T100Field('active', 'Règle active', kind: T100Kind.toggle, initial: '${r['active'] == true}'),
        const T100Field('reason', 'Motif (10 à 500 caractères)', kind: T100Kind.multiline, required: true, maxLength: 500),
      ],
      ok: 'Enregistrer',
      validate: (v) {
        final p = int.tryParse(v['points'] ?? '');
        final w = double.tryParse((v['weight'] ?? '').replaceAll(',', '.'));
        if (p == null || p < 0 || p > 1000) return 'Les points doivent être compris entre 0 et 1000.';
        if (w == null || w < 0 || w > 1) return 'Le poids de la qualité doit être compris entre 0 et 1.';
        if (v['active'] == 'true' && p < 1) return 'Une règle active exige au moins 1 point.';
        if ((v['reason'] ?? '').length < 10) return 'Le motif doit contenir au moins 10 caractères.';
        return null;
      },
      submit: (v) async {
        await top100Call('admin_talent_rule_set', {
          'p_code': r['code'],
          'p_points': int.parse(v['points']!),
          'p_cap_day': (v['cap_day'] ?? '').isEmpty ? null : int.tryParse(v['cap_day']!),
          'p_cap_period': (v['cap_period'] ?? '').isEmpty ? null : int.tryParse(v['cap_period']!),
          'p_quality_weight': double.parse(v['weight']!.replaceAll(',', '.')),
          'p_active': v['active'] == 'true',
          'p_reason': v['reason'],
        });
      },
    );
    if (ok && context.mounted) {
      gToast(context, 'Règle enregistrée.');
      _refresh(ref);
    }
  }

  Future<void> _history(BuildContext context, String code) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (_) => _RuleHistory(code: code),
      );

  Future<void> _editSetting(BuildContext context, WidgetRef ref, String key, Object? current) async {
    final ok = await top100Form(
      context,
      title: _kSettingLabels[key] ?? key,
      fields: [
        T100Field('value', 'Valeur (supérieure à 0)', kind: T100Kind.decimal, initial: top100Str(current), required: true),
        const T100Field('reason', 'Motif (10 à 500 caractères)', kind: T100Kind.multiline, required: true, maxLength: 500),
      ],
      ok: 'Enregistrer',
      validate: (v) {
        final n = double.tryParse((v['value'] ?? '').replaceAll(',', '.'));
        if (n == null || n <= 0 || n > 100000) return 'La valeur doit être supérieure à 0 et au plus 100 000.';
        if ((v['reason'] ?? '').length < 10) return 'Le motif doit contenir au moins 10 caractères.';
        return null;
      },
      submit: (v) async {
        await top100Call('admin_talent_setting_set', {'p_key': key, 'p_value': double.parse(v['value']!.replaceAll(',', '.')), 'p_reason': v['reason']});
      },
    );
    if (ok && context.mounted) {
      gToast(context, 'Réglage enregistré.');
      _refresh(ref);
    }
  }

  Future<void> _editPublication(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final current = <String>{for (final x in (s['scopes'] is List ? s['scopes'] as List : const [])) '$x'};
    final ok = await top100Form(
      context,
      title: 'Réglages de publication',
      body: 'Ces décisions appartiennent à l’administration : aucune valeur n’est imposée. Tant qu’elles ne sont pas toutes prises et qu’aucune règle de score n’est active, la publication est refusée.',
      fields: [
        T100Field('min_score', 'Score minimal pour être classé', kind: T100Kind.integer, initial: top100Str(s['min_score']), required: true),
        T100Field('min_activities', 'Nombre d’activités minimal (vide = aucun seuil)', kind: T100Kind.integer, initial: top100Str(s['min_activities'])),
        T100Field('entries_limit', 'Nombre d’entrées par classement (1 à 1000)', kind: T100Kind.integer, initial: top100Str(s['entries_limit']), required: true),
        for (final e in kRankingScopes.entries) T100Field('scope_${e.key}', 'Portée : ${e.value}', kind: T100Kind.toggle, initial: '${current.contains(e.key)}'),
        const T100Field('reason', 'Motif (10 à 500 caractères)', kind: T100Kind.multiline, required: true, maxLength: 500),
      ],
      ok: 'Enregistrer',
      validate: (v) {
        final m = int.tryParse(v['min_score'] ?? '');
        final l = int.tryParse(v['entries_limit'] ?? '');
        if (m == null || m < 0) return 'Le score minimal doit être un entier positif ou nul.';
        if (l == null || l < 1 || l > 1000) return 'Le nombre d’entrées doit être compris entre 1 et 1000.';
        if (!kRankingScopes.keys.any((k) => v['scope_$k'] == 'true')) return 'Choisissez au moins une portée.';
        if ((v['reason'] ?? '').length < 10) return 'Le motif doit contenir au moins 10 caractères.';
        return null;
      },
      submit: (v) async {
        await top100Call('admin_ranking_settings_set', {
          'p_min_score': int.parse(v['min_score']!),
          'p_min_activities': (v['min_activities'] ?? '').isEmpty ? null : int.tryParse(v['min_activities']!),
          'p_entries_limit': int.parse(v['entries_limit']!),
          'p_scopes': [for (final k in kRankingScopes.keys) if (v['scope_$k'] == 'true') k],
          'p_reason': v['reason'],
        });
      },
    );
    if (ok && context.mounted) {
      gToast(context, 'Réglages de publication enregistrés.');
      _refresh(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(top100RulesProvider);
    final settings = ref.watch(top100SettingsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote('Les 13 familles d’activité naissent en brouillon : 0 point, inactives. Les vues et les mentions « j’aime » n’ont aucune règle. Formule appliquée par le serveur : points × ((1 − poids) + poids × qualité), puis plafonds par jour et par mois.'),
      tpSection('Réglages de publication', hint: 'Seuil, nombre d’entrées et portées du classement.'),
      settings.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100SettingsProvider)),
        data: (s) {
          final undecided = [for (final x in (s['undecided'] is List ? s['undecided'] as List : const [])) '$x'];
          return TpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              top100Line('Score minimal', s['min_score'] ?? 'Non décidé'),
              top100Line('Activités minimales', s['min_activities'] ?? 'Aucun seuil'),
              top100Line('Entrées par classement', s['entries_limit'] ?? 'Non décidé'),
              top100Line('Portées', (s['scopes'] is List && (s['scopes'] as List).isNotEmpty) ? [for (final x in s['scopes'] as List) kRankingScopes['$x'] ?? '$x'].join(', ') : 'Non décidé'),
              top100Line('Effectif minimal d’un groupe', s['min_cohort']),
              const SizedBox(height: 8),
              if (s['decided'] == true) top100Chip('Réglages décidés', c: tpGreen) else top100Chip(undecided.isEmpty ? 'Non décidés' : 'À décider : ${undecided.join(', ')}', c: tpRed),
              const SizedBox(height: 10),
              TpButton('Modifier les réglages', () => _editPublication(context, ref, s), compact: true, icon: Icons.tune_rounded),
            ]),
          );
        },
      ),
      tpSection('Règles de score', hint: 'Une règle par famille d’activité.'),
      rules.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100RulesProvider)),
        data: (d) {
          final list = top100Rows(d['rules']);
          final st = top100Obj(d['settings']);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (list.isEmpty) const TpEmpty(title: 'Aucune règle', text: 'Le serveur ne renvoie aucune règle de score.', icon: Icons.rule_rounded),
            for (final r in list)
              TpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(top100Str(r['label'], _kRuleFamilies['${r['code']}'] ?? '${r['code']}'), style: tpSt(14, w: FontWeight.w700))),
                    top100Chip(r['active'] == true ? 'Active' : 'Brouillon', c: r['active'] == true ? tpGreen : tpGrey),
                  ]),
                  if (top100Str(r['description']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('${r['description']}', style: tpSt(12, c: tpGrey, h: 1.4))),
                  const SizedBox(height: 6),
                  top100Line('Points par activité', r['points']),
                  top100Line('Plafond par jour', r['cap_per_day'] ?? 'Aucun'),
                  top100Line('Plafond par mois', r['cap_per_period'] ?? 'Aucun'),
                  top100Line('Poids de la qualité', r['quality_weight']),
                  top100Line('Version', r['version']),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TpButton('Modifier', () => _editRule(context, ref, r), compact: true)),
                    const SizedBox(width: 8),
                    Expanded(child: TpButton('Historique', () => _history(context, '${r['code']}'), compact: true, dark: false)),
                  ]),
                ]),
              ),
            tpSection('Seuils de détection', hint: 'Effectif minimal et détection de fraude.'),
            for (final e in _kSettingLabels.entries)
              TpCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value, style: tpSt(13, w: FontWeight.w600)),
                      Text(st.containsKey(e.key) ? 'Valeur réglée : ${top100Num(st[e.key])}' : 'Non réglé : valeur de repli du serveur', style: tpSt(11.5, c: tpGrey)),
                    ]),
                  ),
                  TpButton('Régler', () => _editSetting(context, ref, e.key, st[e.key]), compact: true, dark: false),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }
}

class _RuleHistory extends StatefulWidget {
  const _RuleHistory({required this.code});
  final String code;

  @override
  State<_RuleHistory> createState() => _RuleHistoryState();
}

class _RuleHistoryState extends State<_RuleHistory> {
  late final Future<List<Map<String, dynamic>>> _future = top100List('admin_talent_rule_history', {'p_code': widget.code});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Historique de la règle', style: tpSt(17, w: FontWeight.w700)),
                const SizedBox(height: 8),
                if (snap.connectionState != ConnectionState.done) top100Loading(),
                if (snap.hasError) Text(top100Msg(snap.error!), style: tpSt(13, c: tpRed, h: 1.5)),
                if (snap.hasData && snap.data!.isEmpty) Text('Aucune modification enregistrée pour cette règle.', style: tpSt(13, c: tpGrey)),
                if (snap.hasData && snap.data!.isNotEmpty)
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final h in snap.data!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Version ${h['version']} · ${tpDate(h['changed_at'])} · ${top100Str(h['changed_by'], 'système')}', style: tpSt(12.5, w: FontWeight.w700)),
                            Text('${top100Num(h['points'])} point(s) · plafond jour ${h['cap_per_day'] ?? 'aucun'} · plafond mois ${h['cap_per_period'] ?? 'aucun'} · qualité ${top100Num(h['quality_weight'])} · ${h['active'] == true ? 'active' : 'inactive'}', style: tpSt(12, c: tpGrey, h: 1.4)),
                            if (top100Str(h['reason']).isNotEmpty) Text('Motif : ${h['reason']}', style: tpSt(12, h: 1.4)),
                          ]),
                        ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      );
}
