import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart' show dateCourte;
import 'impact.dart' show RpcMap;
import 'store.dart' show fcfa;

/// Finance (écrans 139, 140, 141, 142, 143), lue sur le serveur (migration 20261105000500) : chiffres calculés sur les commandes payées
/// et lots de reversement saisis par la finance. Lecture réservée à la finance, à l'administration et à la direction.
/// Aucun paiement réel n'est déclenché par ces écrans.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final financeOverviewProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('finance_overview', needsLogin: true));
final financePaymentsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('finance_payments', const {'p_limit': 200}));
final financePayoutsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('finance_payouts', const {'p_limit': 200}));
final financeByDepartmentProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('finance_by_department'));

/// Journal : les lignes (liste) et les totaux lus avec elles.
class JournalRows extends RpcRows {
  JournalRows() : super('finance_journal', const {'p_limit': 300});
  Map<String, dynamic> totals = const {};

  @override
  Future<void> refresh() async {
    final r = await Backend.rpc(fn, args);
    if (!ref.mounted) return;
    error = r.error != null || r.data is! Map;
    if (error) {
      totals = const {};
      state = const [];
      return;
    }
    final m = Map<String, dynamic>.from(r.data as Map);
    totals = m;
    state = [for (final x in (m['rows'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  }
}

final financeJournalProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(JournalRows.new);

String paymentState(Object? s) => switch ('$s') { 'verified' => 'Vérifié', 'rejected' => 'Rejeté', _ => 'À vérifier' };
String payoutStatus(Object? s) => switch ('$s') { 'verse' => 'Versé', 'rejete' => 'Rejeté', _ => 'Prévu' };

/// Ancienneté d'un paiement déclaré : « Il y a 2 h », « Hier », ou la date.
String agoLabel(Object? iso, DateTime now) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '—';
  final diff = now.difference(d);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes.clamp(1, 59)} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'Hier';
  return dateCourte(iso);
}

int _i(Object? v) => ((v as num?) ?? 0).toInt();

Widget _kpi(String label, String value, double w) => Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: _st(11.5, c: _grey)),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(20, w: FontWeight.w800)),
      ]),
    );

Widget _gate(WidgetRef ref, double width, Widget Function() child, {required bool Function() error, required Object? data}) {
  Widget note(String t) => SizedBox(width: width, child: Padding(padding: const EdgeInsets.only(left: 16, top: 4), child: Text(t, style: _st(13, c: _grey))));
  if (ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous avec un compte de finance ou de gestion pour voir ces chiffres.');
  if (data == null) return note('Chargement…');
  if (error()) return note('Accès réservé à la finance et à la gestion, ou chiffres indisponibles pour le moment.');
  return child();
}

/// Tableau de bord financier (139) : encaissé, commandes, paiements à vérifier, montants dus, versé sur 30 jours, et les six derniers mois.
class FinanceOverviewPanel extends ConsumerWidget {
  const FinanceOverviewPanel({super.key, this.width = 940, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(financeOverviewProvider);
    return _gate(ref, width, () {
      final months = [for (final m in (d!['months'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
      final maxA = months.fold<double>(0, (a, m) => (m['amount'] as num).toDouble() > a ? (m['amount'] as num).toDouble() : a);
      final w = (width - 4 * 14) / 5;
      return SizedBox(
        width: width,
        height: height,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _kpi('Encaissé', fcfa(_i(d['collected'])), w),
              const SizedBox(width: 14),
              _kpi('Commandes payées', '${d['orders_paid']}', w),
              const SizedBox(width: 14),
              _kpi('Paiements à vérifier', '${d['to_verify']}', w),
              const SizedBox(width: 14),
              _kpi('Montants dus', fcfa(_i(d['due'])), w),
              const SizedBox(width: 14),
              _kpi('Versé (30 j)', fcfa(_i(d['paid_out_30d'])), w),
            ]),
            const SizedBox(height: 26),
            Text('Encaissements par mois (FCFA)', style: _st(15, w: FontWeight.w700)),
            const SizedBox(height: 12),
            if (months.isEmpty || maxA == 0)
              Text('Aucun encaissement sur les six derniers mois.', style: _st(12.5, c: _grey))
            else
              SizedBox(
                height: 190,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final m in months)
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(fcfa(_i(m['amount'])), style: _st(10, c: _grey)),
                        const SizedBox(height: 4),
                        Container(height: 130 * ((m['amount'] as num).toDouble() / maxA) + 2, margin: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: const Color(0xFF5A3FE0), borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 4),
                        Text('${m['month']}'.substring(5), style: _st(10.5, c: _grey)),
                      ]),
                    ),
                ]),
              ),
          ]),
        ),
      );
    }, error: () => ref.read(financeOverviewProvider.notifier).error, data: d);
  }
}

/// Synthèse du journal (141) : total des crédits, des débits, solde et lignes à rapprocher.
class JournalSummary extends ConsumerWidget {
  const JournalSummary({super.key, this.width = 280});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(financeJournalProvider);
    return _gate(ref, width, () {
      final t = (ref.read(financeJournalProvider.notifier) as JournalRows).totals;
      final credit = _i(t['total_credit']), debit = _i(t['total_debit']);
      Widget line(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: _st(13, c: _grey)), Text(v, style: _st(14, w: FontWeight.w700))]));
      return SizedBox(
        width: width,
        child: Column(children: [
          line('Total crédits', fcfa(credit)),
          line('Total débits', fcfa(debit)),
          line('Solde', fcfa(credit - debit)),
          line('Lignes à rapprocher', '${_i(t['to_reconcile'])}'),
        ]),
      );
    }, error: () => ref.read(financeJournalProvider.notifier).error, data: rows);
  }
}

/// Indicateurs des versements (143) : versé sur 30 jours, montants dus, vendeurs concernés et lots rejetés.
class PayoutKpis extends ConsumerWidget {
  const PayoutKpis({super.key, this.width = 940});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(financeOverviewProvider);
    final rows = ref.watch(financePayoutsProvider);
    return _gate(ref, width, () {
      final list = rows ?? const <Map<String, dynamic>>[];
      final w = (width - 3 * 14) / 4;
      return Row(children: [
        _kpi('Versé (30 j)', fcfa(_i(o!['paid_out_30d'])), w),
        const SizedBox(width: 14),
        _kpi('Montants dus', fcfa(_i(o['due'])), w),
        const SizedBox(width: 14),
        _kpi('Vendeurs concernés', '${{for (final r in list) r['seller']}.length}', w),
        const SizedBox(width: 14),
        _kpi('Rejets', '${list.where((r) => r['status'] == 'rejete').length}', w),
      ]);
    }, error: () => ref.read(financeOverviewProvider.notifier).error, data: o);
  }
}

/// Compteurs des onglets de la vérification des paiements (140).
class PaymentCounts extends ConsumerWidget {
  const PaymentCounts({super.key, this.width = 700});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(financePaymentsProvider);
    return _gate(ref, width, () {
      int n(String s) => rows!.where((r) => r['state'] == s).length;
      return Row(children: [
        Text('À vérifier (${n('to_verify')})', style: _st(14, w: FontWeight.w700)),
        const SizedBox(width: 28),
        Text('Vérifiés (${n('verified')})', style: _st(14, c: _grey)),
        const SizedBox(width: 28),
        Text('Rejetés (${n('rejected')})', style: _st(14, c: _grey)),
      ]);
    }, error: () => ref.read(financePaymentsProvider.notifier).error, data: rows);
  }
}

/// Encaissements et nombre de ventes par département (142).
class FinanceByDepartmentPanel extends ConsumerWidget {
  const FinanceByDepartmentPanel({super.key, this.width = 940, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(financeByDepartmentProvider);
    return _gate(ref, width, () {
      if (rows!.isEmpty) return SizedBox(width: width, child: Padding(padding: const EdgeInsets.only(left: 16), child: Text('Aucune vente payée pour le moment.', style: _st(13, c: _grey))));
      Widget cell(String t, double w, {bool bold = false}) => SizedBox(width: w, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, w: bold ? FontWeight.w600 : FontWeight.w500, c: bold ? _ink : const Color(0xFF3D3B37))));
      return SizedBox(
        width: width,
        height: height,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [cell('Département', 300, bold: true), cell('Ventes (FCFA)', 220, bold: true), cell('Commandes', 160, bold: true), cell('Vendeurs', 140, bold: true)]),
            const Divider(height: 18),
            for (final r in rows)
              Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [cell('${r['department']}', 300, bold: true), cell(fcfa(_i(r['sales'])), 220), cell('${r['orders']}', 160), cell('${r['sellers']}', 140)])),
          ]),
        ),
      );
    }, error: () => ref.read(financeByDepartmentProvider.notifier).error, data: rows);
  }
}
