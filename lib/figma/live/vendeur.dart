import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'impact.dart' show RpcMap;
import 'profile_data.dart';
import 'store.dart' show fcfa, selectedProductProvider;

/// Espace vendeur (écrans 66 Revenus, 67 Statistiques, 69 Validations) : chiffres calculés sur les commandes payées de ses annonces
/// (migration 20261105000800) et état réel de ses justificatifs. Les vues d'annonces et le taux de conversion ne sont pas mesurés.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final sellerRevenueProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('seller_revenue', needsLogin: true));

int _i(Object? v) => ((v as num?) ?? 0).toInt();

Widget _note(double w, String t) => Container(width: w, height: 140, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

Widget _tile(String l, String v, String? sub) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: _st(11.5, c: _grey)), const SizedBox(height: 6), Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(16, w: FontWeight.w800)), if (sub != null) Text(sub, style: _st(11, c: _grey))]),
      ),
    );

Widget _bars(List<Map<String, dynamic>> rows, String key, String Function(String) label, double width) {
  final maxA = rows.fold<double>(0, (a, r) => _i(r['amount']) > a ? _i(r['amount']).toDouble() : a);
  if (rows.isEmpty || maxA == 0) return SizedBox(width: width, height: 80, child: Center(child: Text('Aucune vente payée sur cette période.', style: _st(12.5, c: _grey))));
  return SizedBox(
    width: width,
    height: 170,
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final r in rows)
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(fcfa(_i(r['amount'])), maxLines: 1, style: _st(9, c: _grey)),
            const SizedBox(height: 3),
            Container(height: 110 * (_i(r['amount']) / maxA) + 2, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: const Color(0xFF5A3FE0), borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 4),
            Text(label('${r[key]}'), style: _st(10.5, c: _grey)),
          ]),
        ),
    ]),
  );
}

List<Map<String, dynamic>> _list(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

Widget? _gate(WidgetRef ref, Map<String, dynamic>? d, double width) {
  if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous pour voir vos chiffres.');
  if (d == null) return _note(width, 'Chargement…');
  return null;
}

/// 66 : disponible, en attente, reversé, et ventes des six derniers mois.
class SellerRevenuePanel extends ConsumerWidget {
  const SellerRevenuePanel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sellerRevenueProvider);
    final g = _gate(ref, d, width);
    if (g != null) return SizedBox(width: width, child: g);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_tile('Disponible', fcfa(_i(d!['available'])), null), const SizedBox(width: 12), _tile('En attente', fcfa(_i(d['pending_amount'])), '${_i(d['pending_count'])} paiement${_i(d['pending_count']) > 1 ? 's' : ''}')]),
        const SizedBox(height: 12),
        Row(children: [_tile('Déjà reversé', fcfa(_i(d['paid_out'])), null), const SizedBox(width: 12), _tile('Reversement prévu', fcfa(_i(d['scheduled'])), null)]),
        const SizedBox(height: 22),
        Text('Ventes payées · 6 mois', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Total : ${fcfa(_i(d['total']))} sur ${_i(d['orders'])} commande${_i(d['orders']) > 1 ? 's' : ''}', style: _st(12, c: _grey)),
        const SizedBox(height: 12),
        _bars(_list(d['months']), 'month', (m) => m.length >= 7 ? m.substring(5) : m, width),
      ]),
    );
  }
}

/// 67 : ventes par semaine (huit dernières semaines).
class SellerStatsPanel extends ConsumerWidget {
  const SellerStatsPanel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sellerRevenueProvider);
    final g = _gate(ref, d, width);
    if (g != null) return SizedBox(width: width, child: g);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_tile('Ventes payées', '${_i(d!['orders'])}', null), const SizedBox(width: 12), _tile('Chiffre d’affaires', fcfa(_i(d['total'])), null)]),
        const SizedBox(height: 22),
        Text('Ventes par semaine', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 12),
        _bars(_list(d['weeks']), 'week', (w) => w.length >= 10 ? '${w.substring(8)}/${w.substring(5, 7)}' : w, width),
        const SizedBox(height: 18),
        Text('Les vues d’annonces et le taux de conversion ne sont pas encore mesurés.', style: _st(12, c: _grey).copyWith(height: 1.5)),
      ]),
    );
  }
}

/// 69 : justificatifs réellement envoyés et décision de vérification de chacun.
class ValidationsPanel extends ConsumerWidget {
  const ValidationsPanel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return SizedBox(width: width, child: _note(width, 'Connectez-vous pour voir vos validations.'));
    final docs = ref.watch(myDocsProvider);
    final a = ref.watch(profileAccountProvider);
    if (docs == null) return SizedBox(width: width, child: _note(width, 'Chargement…'));
    const kinds = [('student_card', 'Carte d’étudiant'), ('enrollment_certificate', 'Certificat de scolarité'), ('diploma', 'Diplôme')];
    final rows = <(String, String, String)>[
      for (final k in kinds)
        () {
          final d = latestDoc(docs, k.$1);
          return (k.$2, d == null ? 'Non envoyé' : d.name, d == null ? 'À fournir' : d.statusLabel);
        }(),
      ('Matricule', a.matricule.isEmpty ? 'Non renseigné' : a.matricule, a.matricule.isEmpty ? 'À fournir' : 'Renseigné'),
    ];
    final ok = rows.where((r) => r.$3 == 'Vérifié').length;
    Color tone(String s) => s == 'Vérifié' ? const Color(0xFF0F7A52) : s == 'Refusé' ? const Color(0xFFC0392B) : const Color(0xFF8F5400);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Conformité du compte', style: _st(16, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('$ok justificatif${ok > 1 ? 's' : ''} vérifié${ok > 1 ? 's' : ''} sur ${rows.length}', style: _st(12.5, c: _grey)),
        const SizedBox(height: 14),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.$1, style: _st(13.5, w: FontWeight.w600)), const SizedBox(height: 2), Text(r.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey))])),
              Text(r.$3, style: _st(11.5, w: FontWeight.w700, c: tone(r.$3))),
            ]),
          ),
      ]),
    );
  }
}

/// Fiche produit (écran 32, variante de l'écran 05) : le produit réellement choisi, sans caractéristiques inventées.
class SelectedProductInfo extends ConsumerWidget {
  const SelectedProductInfo({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(selectedProductProvider);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.title, style: _st(22, w: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(fcfa(p.price), style: _st(18, w: FontWeight.w700)),
        const SizedBox(height: 14),
        Text(p.description, style: _st(13.5, c: const Color(0xFF4A4854)).copyWith(height: 1.55)),
        const SizedBox(height: 22),
        Text('Vendeur : ${p.seller}', style: _st(14, w: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Département : ${p.department}', style: _st(12, c: _grey)),
      ]),
    );
  }
}

/// Écrans 227 et 229 : carte de présentation construite sur le profil réel (nom, établissement, compétences, présentation, dernier CV envoyé).
class MyProfileCard extends ConsumerWidget {
  const MyProfileCard({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous pour voir votre profil.');
    final a = ref.watch(profileAccountProvider);
    final docs = ref.watch(myDocsProvider);
    final cv = latestDoc(docs, 'cv');
    final skills = [for (final s in a.skills.split(RegExp(r'[,;\n]'))) if (s.trim().isNotEmpty) s.trim()];
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.name, style: _st(22, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([if (a.department.isNotEmpty) a.department, if (a.institution.isNotEmpty) a.institution].join(' · '), style: _st(12.5, c: _grey)),
        const SizedBox(height: 16),
        Text(a.bio.isEmpty ? 'Aucune présentation renseignée. Ajoutez-la depuis votre profil.' : a.bio, style: _st(13.5, c: a.bio.isEmpty ? _grey : _ink).copyWith(height: 1.55)),
        const SizedBox(height: 18),
        Text('Compétences', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 8),
        if (skills.isEmpty) Text('Aucune compétence renseignée.', style: _st(13, c: _grey)) else Wrap(spacing: 8, runSpacing: 8, children: [for (final s in skills) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(14)), child: Text(s, style: _st(12, w: FontWeight.w600, c: const Color(0xFF5A3FE0))))]),
        const SizedBox(height: 18),
        Text('CV envoyé', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(docs == null ? 'Chargement…' : (cv == null ? 'Aucun CV envoyé pour le moment.' : cv.name), style: _st(13, c: _grey)),
      ]),
    );
  }
}
