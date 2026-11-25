import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart' show Text;
import 'access.dart' show roleKey, roleNames;
import 'admin_access.dart';
import 'auth.dart';
import 'tp_ui.dart';
import 'top100_admin_common.dart';
import 'top100_admin_institutions.dart';
import 'top100_admin_moderation.dart';
import 'top100_admin_publication.dart';
import 'top100_admin_rules.dart';
import 'top100_admin_scope.dart';

/// Console « Classement et talents » (route /admin/classement) : administration globale et équipe `ranking` (permissions institutions.manage, ranking.rules,
/// ranking.publish, ranking.moderate), plus la vue de périmètre des responsables d'établissement et de département. Chaque onglet n'apparaît que si le compte
/// a la permission ou le périmètre correspondant ; le serveur reste l'autorité (gardes SQL, 2FA) et son message est affiché tel quel en cas de refus.

const _kTabLabels = {
  'overview': 'Vue d’ensemble',
  'rules': 'Règles de score',
  'publication': 'Publication',
  'institutions': 'Établissements et filières',
  'affiliations': 'Rattachements',
  'flags': 'Fraude',
  'disputes': 'Contestations',
  'perimeter': 'Mon périmètre',
};

final top100AccessProvider = adminAccessProvider;

/// Périmètres du compte : administration, établissements dont il est responsable, département rattaché.
final top100ScopesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('my_ranking_scopes');
}, retry: (_, _) => null);

/// Onglets ouverts à un compte selon ses permissions ([a]) et ses périmètres ([scopes], nul si illisibles).
List<String> top100Tabs(AdminAccess a, Map<String, dynamic>? scopes) {
  final hasInstitutions = scopes != null && top100Rows(scopes['institutions']).isNotEmpty;
  final hasDepartment = scopes != null && scopes['department'] is Map;
  final inScope = hasInstitutions || hasDepartment;
  return [
    if (a.hasAny(kRankingPerms)) 'overview',
    if (a.has('ranking.rules')) 'rules',
    if (a.has('ranking.publish')) 'publication',
    if (a.has('institutions.manage')) 'institutions',
    if (a.has('institutions.manage') || inScope) 'affiliations',
    if (a.has('ranking.moderate')) 'flags',
    if (a.has('ranking.moderate')) 'disputes',
    if (a.isAdmin || inScope || scopes?['admin'] == true) 'perimeter',
  ];
}

class Top100AdminScreen extends ConsumerStatefulWidget {
  const Top100AdminScreen({super.key});

  @override
  ConsumerState<Top100AdminScreen> createState() => _Top100AdminState();
}

class _Top100AdminState extends ConsumerState<Top100AdminScreen> {
  String? _tab;

  @override
  Widget build(BuildContext context) {
    final role = roleKey(ref.watch(authProvider.select((a) => a.current)));
    final access = ref.watch(top100AccessProvider);
    final scopes = ref.watch(top100ScopesProvider);
    final loading = (access.isLoading && !access.hasValue) || (scopes.isLoading && !scopes.hasValue);
    final a = access.asData?.value ?? AdminAccess.none;
    final tabs = top100Tabs(a, scopes.asData?.value);
    final current = tabs.contains(_tab) ? _tab! : (tabs.isEmpty ? '' : tabs.first);
    return TpPage(
      title: 'Classement et talents',
      subtitle: roleNames[role] ?? '',
      actions: [
        TpRound(
          icon: Icons.refresh_rounded,
          label: 'Actualiser',
          onTap: () {
            ref.invalidate(top100AccessProvider);
            ref.invalidate(top100ScopesProvider);
          },
        ),
      ],
      children: [
        if (loading) top100Loading(),
        if (!loading && access.hasError) top100Failed('Vos droits d’équipe n’ont pas pu être lus : ${top100Msg(access.error!)}', () => ref.invalidate(top100AccessProvider)),
        if (!loading && scopes.hasError && tabs.isEmpty) top100Failed('Vos périmètres n’ont pas pu être lus : ${top100Msg(scopes.error!)}', () => ref.invalidate(top100ScopesProvider)),
        if (!loading && tabs.isEmpty && !access.hasError && !scopes.hasError)
          const TpEmpty(
            title: 'Accès réservé',
            text: 'Cette console est réservée à l’administration, à l’équipe « Classement et talents » (permissions attribuées explicitement par l’administrateur global) et aux responsables d’établissement ou de département.',
            icon: Icons.lock_outline_rounded,
          ),
        if (!loading && tabs.isNotEmpty) ...[
          TpChoice('Section', {for (final t in tabs) t: _kTabLabels[t]!}, current, (v) => setState(() => _tab = v)),
          if (scopes.hasError) tpNote('Vos périmètres n’ont pas pu être lus : ${top100Msg(scopes.error!)}', c: tpRed),
          switch (current) {
            'overview' => const _Overview(),
            'rules' => const Top100RulesSection(),
            'publication' => const Top100PublicationSection(),
            'institutions' => const Top100InstitutionsSection(),
            'affiliations' => const Top100AffiliationsSection(),
            'flags' => const Top100FlagsSection(),
            'disputes' => const Top100DisputesSection(),
            'perimeter' => Top100ScopeSection(scopes: scopes.asData?.value ?? const {}),
            _ => const SizedBox.shrink(),
          },
        ],
      ],
    );
  }
}

final _indicatorsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_ranking_national_indicators');
}, retry: (_, _) => null);

final _qualityProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_data_quality');
}, retry: (_, _) => null);

final _anomaliesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100Map('admin_ranking_anomalies');
}, retry: (_, _) => null);

/// Indicateurs nationaux, qualité des données et anomalies : lecture agrégée, aucun nom ni score individuel.
class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ind = ref.watch(_indicatorsProvider);
    final quality = ref.watch(_qualityProvider);
    final anomalies = ref.watch(_anomaliesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpSection('Indicateurs nationaux', hint: 'Chiffres agrégés du serveur : aucun nom ni score individuel.'),
      ind.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(_indicatorsProvider)),
        data: (d) {
          final s = top100Obj(d['students']), i = top100Obj(d['institutions']), q = top100Obj(d['queue']), r = top100Obj(d['rankings']);
          final latest = r['latest'] is Map ? top100Obj(r['latest']) : null;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 10, children: [
              top100Stat('Étudiants', s['total']),
              top100Stat('Étudiants vérifiés', s['verified']),
              top100Stat('Rattachés (vérifiés)', s['affiliated_verified']),
              top100Stat('Au classement public', s['consenting']),
              top100Stat('Actifs ce mois', s['active_this_month']),
              top100Stat('Score moyen par étudiant rattaché', s['avg_score_per_affiliated_student']),
              top100Stat('Établissements vérifiés', i['verified']),
              top100Stat('Établissements proposés', i['proposed']),
              top100Stat('Établissements avec étudiants', i['with_students']),
              top100Stat('Filières actives', i['programs_active']),
              top100Stat('Rattachements en attente', q['pending_affiliations']),
              top100Stat('Alertes de fraude ouvertes', q['open_fraud_flags']),
              top100Stat('Contestations ouvertes', q['open_disputes']),
              top100Stat('Périodes publiées', r['published_periods']),
              top100Stat('Périodes archivées', r['archived_periods']),
              top100Stat('Règles actives', r['rules_active']),
            ]),
            const SizedBox(height: 8),
            top100Line('Réglages décidés', r['settings_decided'] == true ? 'Oui' : 'Non'),
            top100Line('Dernier classement', latest == null ? 'Aucun classement publié' : '${latest['period']} · ${top100Num(latest['entries'])} entrée(s)'),
            if (top100Rows(d['by_institution']).isNotEmpty) ...[
              tpSection('Score moyen par établissement', hint: 'Par étudiant vérifié, jamais selon l’effectif seul.'),
              for (final b in top100Rows(d['by_institution'])) TpCard(child: Column(children: [top100Line('${b['name']}', 'Score moyen ${top100Num(b['avg_score'])}'), top100Line('Étudiants vérifiés', b['verified_students'])])),
            ],
          ]);
        },
      ),
      tpSection('Qualité des données'),
      quality.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(_qualityProvider)),
        data: (d) {
          final p = top100Obj(d['pending_affiliations']), s = top100Obj(d['students_without_program']), g = top100Obj(d['programs']), n = top100Obj(d['institutions']);
          return TpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              top100Line('Rattachements en attente', p['total']),
              top100Line('Plus ancienne demande (jours)', p['oldest_days']),
              top100Line('Étudiants vérifiés sans rattachement', s['verified_without_affiliation']),
              top100Line('… dont demande en attente', s['with_pending_request']),
              top100Line('Filières inactives avec étudiants', g['inactive_with_students']),
              top100Line('Filières actives sans étudiants', g['active_without_students']),
              top100Line('Établissements vérifiés sans filière', n['verified_without_programs']),
              top100Line('Établissements à examiner', n['awaiting_review']),
              top100Line('Matricules en double', d['matricule_duplicates']),
              top100Line('Profils discordants avec leur rattachement', d['profile_affiliation_mismatch']),
            ]),
          );
        },
      ),
      tpSection('Anomalies'),
      anomalies.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(_anomaliesProvider)),
        data: (d) {
          final bySignal = top100Obj(d['flags_open_by_signal']);
          final repeat = top100Rows(d['repeat_students']);
          final needing = top100Rows(d['published_needing_correction']);
          final integrity = top100Rows(d['integrity']);
          return TpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              top100Line('Alertes de fraude ouvertes', d['flags_open']),
              for (final e in bySignal.entries) top100Line('· ${e.key}', e.value),
              top100Line('Contestations ouvertes', d['disputes_open']),
              if (repeat.isNotEmpty) ...[const SizedBox(height: 6), Text('Étudiants récurrents', style: tpSt(12.5, w: FontWeight.w700)), for (final r in repeat) top100Line(top100Str(r['student'], 'Étudiant'), '${top100Num(r['flags'])} alerte(s)')],
              if (needing.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Classements publiés à corriger', style: tpSt(12.5, w: FontWeight.w700, c: tpRed)),
                for (final r in needing) top100Line('${r['period']}', '${top100Num(r['entries'])} entrée(s)'),
              ],
              if (integrity.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Intégrité des empreintes', style: tpSt(12.5, w: FontWeight.w700)),
                for (final r in integrity) top100Line('${r['period']}', r['intact'] == true ? 'Intact' : 'Empreinte différente'),
              ],
            ]),
          );
        },
      ),
    ]);
  }
}
