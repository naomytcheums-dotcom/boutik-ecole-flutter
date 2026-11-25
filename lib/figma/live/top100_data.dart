import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'marche/marche_data.dart';

/// TOP 100 national des talents (migrations 20261127010000 à 20261127020400) : données de lecture publique et de l'espace étudiant.
/// Tout vient des fonctions serveur (`top100_*`, `ranking_*`, `talent_public_profile`, `my_talent_*`…). Aucun classement, score ni établissement n'est
/// inventé : serveur muet ou en panne = message d'erreur (jamais « aucun classement » ni zéro), rien de publié = état honnête dédié.

const top100NothingPublished = 'Aucun classement n’est publié pour le moment.';

class Top100Exception implements Exception {
  Top100Exception(this.message);
  final String message;
  @override
  String toString() => message;
}

String top100ErrorText(String e) => switch (e) {
      'offline' => 'Le TOP 100 est disponible une fois l’application connectée au serveur.',
      'missing' => 'Le TOP 100 n’est pas encore installé sur le serveur.',
      _ => Backend.userMessage(e),
    };

/// Appel d'une fonction serveur ; lève [Top100Exception] avec un message lisible. Ne renvoie jamais de valeur de remplacement.
Future<Object?> top100Call(String fn, Map<String, dynamic> params) async {
  final r = await marcheCall(fn, params);
  if (r.error != null) throw Top100Exception(top100ErrorText(r.error!));
  return r.data;
}

Future<Map<String, dynamic>> top100Map(String fn, [Map<String, dynamic> params = const {}]) async {
  final d = await top100Call(fn, params);
  if (d is! Map) throw Top100Exception('Réponse illisible du serveur. Réessayez dans un instant.');
  return Map<String, dynamic>.from(d);
}

Future<List<Map<String, dynamic>>> top100List(String fn, [Map<String, dynamic> params = const {}]) async {
  final d = await top100Call(fn, params);
  if (d is! List) throw Top100Exception('Réponse illisible du serveur. Réessayez dans un instant.');
  return [for (final x in d) if (x is Map) Map<String, dynamic>.from(x)];
}

Map<String, dynamic> tMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
List<Map<String, dynamic>> tList(Object? v) => [for (final x in (v as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
String tStr(Object? v) => v == null ? '' : '$v';

/// Nombre affiché ; « — » quand le serveur ne fournit pas la valeur (rubrique non partagée, non mesurée) : jamais 0 à la place.
String tNum(Object? v) {
  if (v == null) return '—';
  if (v is num) return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1).replaceAll('.', ',');
  return '$v';
}

const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// « 2026-10 » → « octobre 2026 ».
String top100PeriodLabel(Object? p) {
  final s = tStr(p);
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (m == null) return s;
  final i = int.parse(m.group(2)!);
  return i >= 1 && i <= 12 ? '${_months[i - 1]} ${m.group(1)}' : s;
}

String top100DateText(Object? v) {
  final s = tStr(v);
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// Requête de classement : type de page + filtres. Seuls les filtres renseignés sont envoyés au serveur.
class Top100Query {
  const Top100Query(this.kind, {this.period = '', this.institution = '', this.program = '', this.department = '', this.domain = '', this.level = ''});

  /// national | institution | program | rising | new
  final String kind;
  final String period, institution, program, department, domain, level;

  Top100Query copy({String? period, String? institution, String? program, String? department, String? domain, String? level}) => Top100Query(
        kind,
        period: period ?? this.period,
        institution: institution ?? this.institution,
        program: program ?? this.program,
        department: department ?? this.department,
        domain: domain ?? this.domain,
        level: level ?? this.level,
      );

  /// Page qui exige un choix (établissement ou filière) avant de pouvoir interroger le serveur.
  bool get needsSelection => (kind == 'institution' && institution.isEmpty) || (kind == 'program' && program.isEmpty);

  String get fn => switch (kind) {
        'institution' => 'top100_by_institution',
        'program' => 'top100_by_program',
        'rising' => 'talents_rising',
        'new' => 'talents_new',
        _ => 'top100_national',
      };

  Map<String, dynamic> get params {
    final p = <String, dynamic>{};
    void put(String k, String v) {
      if (v.isNotEmpty) p[k] = v;
    }

    switch (kind) {
      case 'institution':
        put('p_institution', institution);
        put('p_period', period);
        put('p_program', program);
        put('p_department', department);
        put('p_domain', domain);
        put('p_level', level);
        p['p_limit'] = 100;
      case 'program':
        put('p_program', program);
        put('p_period', period);
        put('p_level', level);
        p['p_limit'] = 100;
      case 'rising' || 'new':
        put('p_period', period);
        put('p_institution', institution);
        put('p_program', program);
        put('p_domain', domain);
        p['p_limit'] = 50;
      default:
        put('p_period', period);
        put('p_institution', institution);
        put('p_program', program);
        put('p_department', department);
        put('p_domain', domain);
        put('p_level', level);
        p['p_limit'] = 100;
        p['p_offset'] = 0;
    }
    return p;
  }

  @override
  bool operator ==(Object other) => other is Top100Query && other.kind == kind && other.period == period && other.institution == institution && other.program == program && other.department == department && other.domain == domain && other.level == level;

  @override
  int get hashCode => Object.hash(kind, period, institution, program, department, domain, level);
}

final top100ListProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Top100Query>((ref, q) => top100Map(q.fn, q.params), retry: (_, _) => null);

/// Mois publiés (filtre mois/année) : tirés de l'historique public, jamais d'une liste de mois inventée.
final top100PeriodsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final h = await top100List('ranking_history', {'p_limit': 24});
  return [for (final x in h) if (tStr(x['period']).isNotEmpty) tStr(x['period'])];
}, retry: (_, _) => null);

typedef Top100Option = ({String id, String name});

Future<List<Top100Option>> _options(String table, String select, {Map<String, Object> eq = const {}}) async {
  final r = await Backend.rows(table, select, eq: eq, order: 'name', ascending: true, limit: 500);
  if (r.error != null) return const [];
  return [for (final x in r.rows) (id: tStr(x['id']), name: tStr(x['name']))].where((o) => o.id.isNotEmpty && o.name.isNotEmpty).toList();
}

/// Établissements vérifiés (référentiel public). Liste vide si le référentiel est vide ou illisible : le filtre n'est alors pas proposé.
final top100InstitutionsProvider = FutureProvider.autoDispose<List<Top100Option>>((ref) => _options('institutions', 'id,name', eq: {'status': 'verified'}), retry: (_, _) => null);

final top100DepartmentsProvider = FutureProvider.autoDispose<List<Top100Option>>((ref) => _options('departments', 'id,name', eq: {'status': 'verified'}), retry: (_, _) => null);

/// Filières d'un établissement : `programs_list` pour un compte connecté ; pour un visiteur, filières publiées au classement des établissements.
final top100ProgramsProvider = FutureProvider.autoDispose.family<List<Top100Option>, String>((ref, institution) async {
  if (institution.isEmpty) return const [];
  final r = await marcheCall('programs_list', {'p_institution': institution});
  if (r.error == null && r.data is List && (r.data as List).isNotEmpty) {
    return [for (final x in tList(r.data)) (id: tStr(x['id']), name: tStr(x['name']))];
  }
  final g = await marcheCall('ranking_institutions_public', {'p_institution': institution});
  if (g.error != null || g.data is! Map) return const [];
  final items = tList(tMap(g.data)['items']);
  if (items.isEmpty) return const [];
  return [for (final x in tList(items.first['programs'])) (id: tStr(x['program_id']), name: tStr(x['name']))];
}, retry: (_, _) => null);

final top100InstitutionsRankingProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, period) => top100Map('ranking_institutions_public', {if (period.isNotEmpty) 'p_period': period}),
  retry: (_, _) => null,
);

final top100InstitutionHistoryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, institution) => top100List('ranking_institution_history', {'p_institution': institution}),
  retry: (_, _) => null,
);

final top100MostViewedProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, period) => top100Map('talents_most_viewed_by_companies', {if (period.isNotEmpty) 'p_period': period, 'p_limit': 20}),
  retry: (_, _) => null,
);

final top100HistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => top100List('ranking_history', {'p_limit': 24}), retry: (_, _) => null);

final top100RulesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => top100List('talent_rules_public'), retry: (_, _) => null);

final talentProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) => top100Map('talent_public_profile', {'p_user': id}), retry: (_, _) => null);

// ------------------------------------------------------------------ espace étudiant

final myTalentDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => top100Map('my_talent_dashboard'), retry: (_, _) => null);
final myTalentExplainProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => top100Map('my_talent_score_explain', {'p_limit': 50}), retry: (_, _) => null);
final myRankingPositionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => top100Map('my_ranking_positions'), retry: (_, _) => null);
final myTop100VisibilityProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => top100Map('my_top100_visibility_get'), retry: (_, _) => null);
final myAffiliationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => top100Map('my_student_affiliation'), retry: (_, _) => null);
final myTalentEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, status) => top100List('my_talent_events', {if (status.isNotEmpty) 'p_status': status, 'p_limit': 50}),
  retry: (_, _) => null,
);
final myTalentDisputesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => top100List('my_talent_disputes'), retry: (_, _) => null);
final myTalentContactsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => top100List('my_talent_contact_requests', {'p_limit': 50}), retry: (_, _) => null);

/// Écriture : renvoie null si le serveur a confirmé, sinon le message à afficher (aucune confirmation en cas d'échec).
Future<({Object? data, String? error})> top100Write(String fn, Map<String, dynamic> params) async {
  final r = await marcheCall(fn, params);
  if (r.error != null) return (data: null, error: top100ErrorText(r.error!));
  return (data: r.data, error: null);
}
