import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'auth.dart' show authProvider;
import 'company_billing.dart';
import 'company_screens.dart' show companyContextProvider;
import 'docs.dart' show downloadCompanyOrderInvoice;
import 'f4_api.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// « Achats de l'entreprise » : commandes passées au nom de l'entreprise (propriétaire et équipe finance / administrateurs), avec statut, total et facture.
/// Fonctions serveur : company_orders_list, company_billing_context_get / _set (migration 20261118040100) ; aucun flux de paiement n'est touché.

const _pageSize = 50;

/// Entreprise au nom de laquelle j'achète (null : moi) ; `forced` : compte Entreprise, toujours facturé à l'entreprise.
final companyBuyingProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final r = await ref.read(f4RpcProvider)('company_billing_context_get', const {});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

/// Libellé d'un état de commande.
String companyOrderStateLabel(String s) => switch (s) {
      'paid' => 'Payée',
      'cancelled' => 'Annulée',
      'cod' => 'Paiement à la livraison',
      _ => 'En attente de paiement',
    };

class CompanyPurchasesScreen extends ConsumerStatefulWidget {
  const CompanyPurchasesScreen({super.key});

  @override
  ConsumerState<CompanyPurchasesScreen> createState() => _PurchasesState();
}

class _PurchasesState extends ConsumerState<CompanyPurchasesScreen> {
  final _orders = <Map<String, dynamic>>[];
  bool _loading = true, _more = false, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final owner = ref.read(companyContextProvider);
    final r = await ref.read(f4RpcProvider)('company_orders_list', {'p_owner': ?owner, 'p_limit': _pageSize, 'p_offset': reset ? 0 : _orders.length});
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _loading = false;
        _error = r.error == 'offline' || r.error == 'missing' ? marcheErrorText(r.error) : Backend.userMessage('${r.error}');
      });
      return;
    }
    final rows = [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    setState(() {
      if (reset) _orders.clear();
      _orders.addAll(rows);
      _more = rows.length >= _pageSize;
      _loading = false;
    });
  }

  Future<void> _toggleBuying(bool on, String? owner) async {
    final target = on ? (owner ?? ref.read(authProvider).current?.serverId) : null;
    setState(() => _busy = true);
    final r = await ref.read(f4RpcProvider)('company_billing_context_set', {'p_owner': target});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(companyBuyingProvider);
    gToast(context, on ? 'Vos prochains achats seront facturés à l’entreprise.' : 'Vos prochains achats redeviennent personnels.');
  }

  String _fcfa(num v) => '${v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} FCFA';

  String _date(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(companyContextProvider);
    final buying = ref.watch(companyBuyingProvider);
    return MarchePage(
      title: 'Achats de l’entreprise',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(companyBuyingProvider);
          await _load(reset: true);
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
          buying.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (b) {
              final forced = b?['forced'] == true;
              final on = b != null;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
                child: forced
                    ? Text('Les achats de ce compte sont facturés à ${b?['company_name'] ?? 'l’entreprise'} (raison sociale, NIU et adresse de la fiche).', style: mst(13, w: FontWeight.w600).copyWith(height: 1.4))
                    : Row(children: [
                        Expanded(child: Text(on ? 'Vos achats sont facturés à ${b['company_name']}.' : 'Acheter au nom de l’entreprise : vos achats personnels restent séparés.', style: mst(13, w: FontWeight.w600).copyWith(height: 1.4))),
                        SizedBox(height: 48, child: Switch(value: on, onChanged: _busy ? null : (v) => _toggleBuying(v, ctx))),
                      ]),
              );
            },
          ),
          const CompanyBillingCard(),
          mSectionTitle('Commandes de l’entreprise'),
          if (_loading)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Column(children: [
              Text(_error!, textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 12),
              mButton('Réessayer', () => _load(reset: true), dark: false, icon: Icons.refresh_rounded),
            ])
          else if (_orders.isEmpty)
            Column(children: [
              Text('Aucune commande au nom de l’entreprise pour le moment.\nActivez « acheter au nom de l’entreprise » ou commandez avec le compte Entreprise : la commande apparaît ici avec sa facture.', textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 12),
              mButton('Parcourir la marketplace', () => context.push('/marche'), dark: false, icon: Icons.storefront_outlined),
            ])
          else ...[
            for (final o in _orders) _OrderCard(order: o, fcfa: _fcfa, date: _date),
            if (_more) mButton('Voir plus', () => _load(), dark: false),
          ],
        ]),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.fcfa, required this.date});
  final Map<String, dynamic> order;
  final String Function(num) fcfa;
  final String Function(String) date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = '${order['state']}';
    final items = [for (final i in (order['items'] as List? ?? const [])) '${(i as Map)['qty']} × ${i['title']}'];
    final color = switch (state) { 'paid' => kGreen, 'cancelled' => kRed, _ => const Color(0xFF9A5B00) };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Commande ${'${order['number']}'.replaceAll('#', '')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w800))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(companyOrderStateLabel(state), style: mst(11.5, w: FontWeight.w700, c: color))),
        ]),
        const SizedBox(height: 4),
        Text('${date('${order['created_at']}')} · ${order['by_me'] == true ? 'Passée par vous' : 'Passée par ${order['buyer_name'] ?? 'un membre de l’équipe'}'}', style: mst(12, c: kGrey)),
        if (items.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(items.join('\n'), maxLines: 4, overflow: TextOverflow.ellipsis, style: mst(13))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(fcfa((order['total'] as num?) ?? 0), style: mst(16, w: FontWeight.w800))),
          Text('Facture ${order['invoice_number']}', style: mst(11.5, c: kGrey)),
        ]),
        if (state != 'cancelled') ...[const SizedBox(height: 8), mButton('Facture (PDF)', () => downloadCompanyOrderInvoice(context, ref, order), dark: false, icon: Icons.picture_as_pdf_outlined)],
      ]),
    );
  }
}
