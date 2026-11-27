import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'tp_ui.dart';

/// Santé des services et des intégrations (console technique) : lecture de `admin_service_health`, qui ne s'appuie que sur des données réellement enregistrées (files d'envoi, événements de paiement
/// reçus, rapports des fonctions Edge, journaux de synchronisation). Règle d'affichage : un état inattendu ou une mesure absente est « inconnu » (jamais « en service », jamais 0) ;
/// une panne de lecture est une erreur avec « Réessayer », pas un tableau vide.
class ServiceHealth {
  const ServiceHealth({required this.code, required this.label, required this.status, required this.detail, this.lastEventAt, this.metrics = const {}});
  final String code, label, status, detail;
  final String? lastEventAt;
  final Map<String, Object?> metrics;
}

const kHealthStatusLabels = {
  'ok': 'En service',
  'degrade': 'Dégradé',
  'erreur': 'En erreur',
  'non_configure': 'Non configuré',
  'inconnu': 'Inconnu',
};

/// Libellé d'un statut serveur ; tout statut hors vocabulaire est « Inconnu » (jamais « En service » par défaut).
String healthStatusLabel(Object? status) => kHealthStatusLabels['$status'] ?? 'Inconnu';

Color healthStatusColor(Object? status) => switch ('$status') {
      'ok' => tpGreen,
      'degrade' => const Color(0xFFB26A00),
      'erreur' => tpRed,
      _ => tpGrey,
    };

const kHealthMetricLabels = {
  'queued': 'En attente',
  'failed_24h': 'Échecs (24 h)',
  'sent_24h': 'Envoyés (24 h)',
  'oldest_queued_minutes': 'Plus ancien en attente (min)',
  'events_total': 'Événements reçus',
  'events_24h': 'Événements (24 h)',
  'active_providers': 'Fournisseurs actifs',
  'ready_7d': 'Réussis (7 jours)',
  'ok_24h': 'Réussies (24 h)',
  'active_rules': 'Limites actives',
  'calls_last_hour': 'Appels (1 h)',
};

/// Lignes « libellé : valeur » des mesures connues ; une mesure null est « inconnue » (jamais 0).
List<(String, String)> healthMetricLines(ServiceHealth s) => [
      for (final e in s.metrics.entries)
        if (kHealthMetricLabels.containsKey(e.key)) (kHealthMetricLabels[e.key]!, e.value is num ? '${e.value}' : 'inconnu'),
    ];

/// Réponse du serveur → services ; null si la forme est inattendue (aucun état n'est alors affirmé).
List<ServiceHealth>? parseServiceHealth(Object? data) {
  if (data is! Map || data['services'] is! List) return null;
  final out = <ServiceHealth>[];
  for (final x in data['services'] as List) {
    if (x is! Map || x['code'] is! String) return null;
    final m = x['metrics'];
    out.add(ServiceHealth(
      code: x['code'] as String,
      label: '${x['label'] ?? x['code']}',
      status: '${x['status'] ?? 'inconnu'}',
      detail: '${x['detail'] ?? ''}',
      lastEventAt: x['last_event_at'] is String ? x['last_event_at'] as String : null,
      metrics: m is Map ? {for (final e in m.entries) '${e.key}': e.value as Object?} : const {},
    ));
  }
  return out;
}

final adminServiceHealthProvider = FutureProvider.autoDispose<List<ServiceHealth>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  final r = await Backend.rpc('admin_service_health', {});
  final list = r.error == null ? parseServiceHealth(r.data) : null;
  if (list == null) throw Exception(Backend.userMessage(r.error ?? 'Santé des services indisponible pour le moment.'));
  return list;
}, retry: (_, _) => null);

/// Tuile « Santé des services » de la console technique (permissions techniques ou administrateur : contrôlé par le serveur).
class ServiceHealthSection extends ConsumerWidget {
  const ServiceHealthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(adminServiceHealthProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpSection('Santé des services', hint: 'Calculée à partir des données réellement enregistrées. « Inconnu » = non mesurable ou aucune activité récente, ce n’est pas un état de marche.'),
      health.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            const Icon(Icons.error_outline_rounded, size: 34, color: tpRed),
            const SizedBox(height: 8),
            Text(Backend.userMessage('$e'.replaceFirst('Exception: ', '')), textAlign: TextAlign.center, style: tpSt(13, c: tpGrey, h: 1.5)),
            const SizedBox(height: 12),
            TpButton('Réessayer', () => ref.invalidate(adminServiceHealthProvider), dark: false, icon: Icons.refresh_rounded),
          ]),
        ),
        data: (services) => services.isEmpty
            ? tpNote(Backend.ready ? 'Aucun service à afficher.' : 'La santé des services s’affiche une fois connecté au serveur.')
            : Column(children: [for (final s in services) _ServiceCard(s)]),
      ),
    ]);
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard(this.s);
  final ServiceHealth s;

  @override
  Widget build(BuildContext context) {
    final lines = healthMetricLines(s);
    return TpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.label, style: tpSt(14, w: FontWeight.w700))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: healthStatusColor(s.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
            child: Text(healthStatusLabel(s.status), style: tpSt(11.5, w: FontWeight.w700, c: healthStatusColor(s.status))),
          ),
        ]),
        if (s.detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.detail, style: tpSt(12, c: tpGrey, h: 1.4))),
        for (final (label, value) in lines) Padding(padding: const EdgeInsets.only(top: 2), child: Text('$label : $value', style: tpSt(12, h: 1.4))),
        if (s.lastEventAt != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Dernier événement : ${tpDate(s.lastEventAt)}', style: tpSt(11.5, c: tpGrey, h: 1.4))),
      ]),
    );
  }
}
