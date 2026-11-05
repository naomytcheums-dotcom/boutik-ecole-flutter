import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'store.dart' show fcfa;

/// Impact et sponsoring (écrans 105, 107, 237, 238, 239), lus sur le serveur (migration 20261105000100) :
/// impact de la plateforme et de la personne calculés sur les commandes payées et les missions livrées, rapport de sponsoring,
/// créations d'autres établissements. Rien n'est inventé : sans donnée, un état vide ou « — » s'affiche.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Réponse JSON d'une fonction serveur ; `null` : lecture en cours ou serveur absent ; `error` : la lecture a échoué.
class RpcMap extends Notifier<Map<String, dynamic>?> {
  RpcMap(this.fn, {this.needsLogin = false});
  final String fn;
  final bool needsLogin;
  bool error = false;

  @override
  Map<String, dynamic>? build() {
    if (!Backend.ready) return null;
    if (needsLogin && ref.watch(authProvider.select((a) => a.current == null))) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc(fn, const {});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! Map;
    state = error ? const {} : Map<String, dynamic>.from(r.data as Map);
  }
}

final platformImpactProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('platform_impact'));
final deptStatsProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('dept_stats', needsLogin: true));
final myImpactProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('my_impact', needsLogin: true));

/// Première fiche de sponsor visible par la personne (le sien, ou n'importe lequel pour la gestion), puis son rapport.
class SponsorReportNotifier extends Notifier<Map<String, dynamic>?> {
  bool error = false;

  @override
  Map<String, dynamic>? build() {
    if (!Backend.ready) return null;
    if (ref.watch(authProvider.select((a) => a.current == null))) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final s = await Backend.rows('sponsors', 'id,name', order: 'name', ascending: true, limit: 1);
    if (!ref.mounted) return;
    if (s.error != null) {
      error = true;
      state = const {};
      return;
    }
    if (s.rows.isEmpty) {
      error = false;
      state = const {};
      return;
    }
    final r = await Backend.rpc('sponsor_report', {'p_sponsor': s.rows.first['id']});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! Map;
    state = error ? const {} : Map<String, dynamic>.from(r.data as Map);
  }
}

final sponsorReportProvider = NotifierProvider<SponsorReportNotifier, Map<String, dynamic>?>(SponsorReportNotifier.new);

class OtherListings extends Notifier<List<Map<String, dynamic>>?> {
  bool error = false;

  @override
  List<Map<String, dynamic>>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('listings_other_institutions', {'p_limit': 20});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
  }
}

final otherListingsProvider = NotifierProvider<OtherListings, List<Map<String, dynamic>>?>(OtherListings.new);

Widget _note(String t, double width, {double height = 200}) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
      child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
    );

Widget _kpi(String label, String value, double w) => Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(18, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: _st(11, c: _grey)),
      ]),
    );

String _kg(Object? v) {
  final n = (v as num?)?.toDouble() ?? 0;
  return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1).replaceAll('.', ',')} kg';
}

/// Impact de la plateforme : FCFA versés aux vendeurs, étudiants payés, missions livrées, commandes payées, et villes actives.
class PlatformImpactPanel extends ConsumerWidget {
  const PlatformImpactPanel({super.key, this.width = 342, this.height = 440});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(platformImpactProvider);
    if (d == null) return _note('Chargement de l’impact…', width);
    if (ref.read(platformImpactProvider.notifier).error) return _note('L’impact ne peut pas être chargé pour le moment.', width);
    final cities = [for (final c in (d['cities'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    final w = (width - 12) / 2;
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            _kpi('FCFA versés aux vendeurs', fcfa(((d['revenue_paid'] as num?) ?? 0).toInt()), w),
            _kpi('Étudiants payés', '${d['students_paid'] ?? 0}', w),
            _kpi('Missions livrées', '${d['missions_delivered'] ?? 0}', w),
            _kpi('Commandes payées', '${d['orders_paid'] ?? 0}', w),
            _kpi('Déchets valorisés (déclarés)', _kg(d['recycled_kg']), width),
          ]),
          const SizedBox(height: 18),
          Text('Par ville', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
          if (cities.isEmpty) Text('Aucune commande payée pour le moment.', style: _st(12.5, c: _grey)),
          for (final c in cities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Text('${c['city']}', style: _st(13, w: FontWeight.w600))),
                Text('${c['orders']} commande${(c['orders'] as num?) == 1 ? '' : 's'} · ${c['students']} étudiant${(c['students'] as num?) == 1 ? '' : 's'}', style: _st(11.5, c: _grey)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Impact de la personne connectée (écran 107).
class MyImpactPanel extends ConsumerWidget {
  const MyImpactPanel({super.key, this.width = 342, this.height = 540});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note('Connectez-vous pour voir votre impact.', width);
    final d = ref.watch(myImpactProvider);
    if (d == null) return _note('Chargement de votre impact…', width);
    if (ref.read(myImpactProvider.notifier).error) return _note('Votre impact ne peut pas être chargé pour le moment.', width);
    final months = [for (final m in (d['months'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    final maxKg = months.fold<double>(0, (a, m) => ((m['recycled_kg'] as num?)?.toDouble() ?? 0) > a ? (m['recycled_kg'] as num).toDouble() : a);
    final w = (width - 12) / 2;
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            _kpi('Achats payés', '${d['purchases'] ?? 0}', w),
            _kpi('Montant', fcfa(((d['amount'] as num?) ?? 0).toInt()), w),
            _kpi('Étudiants soutenus', '${d['students_supported'] ?? 0}', w),
            _kpi('Déchets valorisés', _kg(d['recycled_kg']), w),
          ]),
          const SizedBox(height: 20),
          Text('Déchets valorisés par mois', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Poids déclaré par les vendeurs sur les produits que vous avez achetés.', style: _st(11.5, c: _grey)),
          const SizedBox(height: 12),
          if (months.isEmpty || maxKg == 0)
            Text('Aucun produit issu de matériaux récupérés dans vos achats pour le moment.', style: _st(12.5, c: _grey))
          else
            SizedBox(
              height: 120,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final m in months)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(height: 80 * (((m['recycled_kg'] as num?)?.toDouble() ?? 0) / maxKg) + 2, margin: const EdgeInsets.symmetric(horizontal: 6), decoration: BoxDecoration(color: const Color(0xFF5A3FE0), borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 4),
                      Text('${m['month']}'.substring(5), style: _st(10.5, c: _grey)),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Rapport de sponsoring (écran 239) : total, étudiants et contributions du sponsor de la personne connectée.
class SponsorReportPanel extends ConsumerWidget {
  const SponsorReportPanel({super.key, this.width = 1180, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note('Connectez-vous avec le compte du sponsor pour voir son rapport.', width, height: 160);
    final d = ref.watch(sponsorReportProvider);
    if (d == null) return _note('Chargement du rapport…', width, height: 160);
    if (ref.read(sponsorReportProvider.notifier).error) return _note('Le rapport ne peut pas être chargé pour le moment.', width, height: 160);
    if (d.isEmpty) return _note('Aucun sponsoring enregistré pour votre compte.\nLa gestion de la plateforme saisit les contributions des sponsors.', width, height: 160);
    final projects = [for (final p in (d['projects'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
    Widget cell(String t, double w, {bool bold = false}) => SizedBox(width: w, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, w: bold ? FontWeight.w600 : FontWeight.w500, c: bold ? _ink : const Color(0xFF3D3B37))));
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d['sponsor']} a contribué à ${fcfa(((d['total'] as num?) ?? 0).toInt())} · ${d['students'] ?? 0} étudiants soutenus', style: _st(17, w: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [cell('Projet sponsorisé', 300, bold: true), cell('Département', 180, bold: true), cell('Montant (FCFA)', 160, bold: true), cell('Étudiants', 100, bold: true), cell('Résultat', 260, bold: true), cell('Statut', 120, bold: true)]),
          const Divider(height: 18),
          if (projects.isEmpty) Text('Aucune contribution enregistrée.', style: _st(12.5, c: _grey)),
          for (final p in projects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                cell('${p['title']}', 300, bold: true),
                cell('${p['department']}'.isEmpty ? '—' : '${p['department']}', 180),
                cell(fcfa(((p['amount'] as num?) ?? 0).toInt()), 160),
                cell('${p['students']}', 100),
                cell('${p['outcome']}'.isEmpty ? '—' : '${p['outcome']}', 260),
                cell(p['status'] == 'termine' ? 'Terminé' : 'En cours', 120),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Créations des autres établissements (écran 105) : annonces publiées dont le vendeur appartient à un autre établissement.
class OtherInstitutionsGrid extends ConsumerWidget {
  const OtherInstitutionsGrid({super.key, this.width = 342, this.height = 520});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(otherListingsProvider);
    if (list == null) return _note('Chargement des créations…', width);
    if (ref.read(otherListingsProvider.notifier).error) return _note('Les créations ne peuvent pas être chargées pour le moment.', width);
    if (list.isEmpty) return _note('Aucune création d’un autre établissement pour le moment.\nLes annonces des étudiants des autres établissements apparaîtront ici.', width);
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 18, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final x = list[i];
          return Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${x['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${x['institution']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: const Color(0xFF5A3FE0))),
              ]),
            ),
            Text(fcfa(((x['price'] as num?) ?? 0).toInt()), style: _st(12.5, w: FontWeight.w700)),
          ]);
        },
      ),
    );
  }
}

/// Statistiques du département (écran 112) : chiffre d'affaires, commandes, panier moyen, part des services et ventes par semaine.
class DeptStatsPanel extends ConsumerWidget {
  const DeptStatsPanel({super.key, this.width = 960, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note('Connectez-vous avec un compte de gestion pour voir ces statistiques.', width, height: 140);
    final d = ref.watch(deptStatsProvider);
    if (d == null) return _note('Chargement des statistiques…', width, height: 140);
    if (ref.read(deptStatsProvider.notifier).error) return _note('Accès réservé à la gestion, ou statistiques indisponibles pour le moment.', width, height: 140);
    final weeks = [for (final w in (d['weeks'] as List? ?? const [])) Map<String, dynamic>.from(w as Map)];
    final maxRev = weeks.fold<double>(0, (a, w) => ((w['revenue'] as num?)?.toDouble() ?? 0) > a ? (w['revenue'] as num).toDouble() : a);
    final revenue = ((d['revenue'] as num?) ?? 0).toInt();
    final services = ((d['services_revenue'] as num?) ?? 0).toInt();
    final servicesPct = revenue == 0 ? 0 : (services * 100 / revenue).round();
    final w4 = (width - 3 * 14) / 4;
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _kpi('Chiffre d’affaires', fcfa(revenue), w4),
            const SizedBox(width: 14),
            _kpi('Commandes', '${d['orders'] ?? 0}', w4),
            const SizedBox(width: 14),
            _kpi('Panier moyen', fcfa(((d['avg_basket'] as num?) ?? 0).toInt()), w4),
            const SizedBox(width: 14),
            _kpi('Part des services', '$servicesPct %', w4),
          ]),
          const SizedBox(height: 24),
          Text('Ventes par semaine (FCFA)', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 12),
          if (weeks.isEmpty || maxRev == 0)
            Text('Aucune vente payée sur les huit dernières semaines.', style: _st(12.5, c: _grey))
          else
            SizedBox(
              height: 170,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final w in weeks)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(fcfa(((w['revenue'] as num?) ?? 0).toInt()), style: _st(10, c: _grey)),
                      const SizedBox(height: 4),
                      Container(height: 110 * (((w['revenue'] as num?)?.toDouble() ?? 0) / maxRev) + 2, margin: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0xFF5A3FE0), borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 4),
                      Text('${w['week']}'.substring(5), style: _st(10.5, c: _grey)),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
