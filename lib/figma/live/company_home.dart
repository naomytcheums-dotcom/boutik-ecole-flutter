import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'coequipiers_screens.dart' show MateNavPill;
import 'company_screens.dart' show companyStatusColor, companyStatusLabel;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Accueil et forfaits de l'entreprise. Tout vient du serveur (migration 20261114002600) ; les prix et quotas sont ceux que l'administrateur a définis.

final companyDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('company_dashboard', const {});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});

final companyPlansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('company_plans_list', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

final companyPlanStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('company_plan_status', const {});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});

final companyPendingPlansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('company_subscriptions_pending', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

/// « 25 000 FCFA / 30 jours », « Gratuit ».
String planPriceLabel(Map<String, dynamic> p) {
  final price = (p['price_fcfa'] as num?)?.toInt() ?? 0;
  if (price == 0) return 'Gratuit';
  final digits = price.toString();
  final spaced = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  final days = (p['period_days'] as num?)?.toInt() ?? 30;
  return '$spaced FCFA / ${days == 30 ? 'mois' : '$days jours'}';
}

/// « 3 sur 10 », « 4 (illimité) » : quota utilisé.
String quotaLabel(int used, int max) => max >= 999 ? '$used (illimité)' : '$used sur $max';

class CompanyHomeScreen extends ConsumerWidget {
  const CompanyHomeScreen({super.key});

  Widget _tile(BuildContext context, IconData icon, String value, String label, String route) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(route),
          child: Container(
            margin: const EdgeInsets.all(5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: kViolet, size: 22), const SizedBox(height: 8), Text(value, style: mst(22, w: FontWeight.w800)), Text(label, style: mst(12, c: kGrey))]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(companyDashboardProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      body: SafeArea(
        child: Stack(children: [
          mAsync<Map<String, dynamic>>(d, (x) {
            final status = '${x['status']}' == 'none' ? 'draft' : '${x['status']}';
            int n(String k) => (x[k] as num?)?.toInt() ?? 0;
            return ListView(padding: const EdgeInsets.fromLTRB(11, 12, 11, 130), children: [
              Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, 8), child: Text('${x['company_name'] ?? 'Mon entreprise'}', style: mst(22, w: FontWeight.w800))),
              GestureDetector(
                onTap: () => context.push('/entreprise/profil'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(5, 0, 5, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: companyStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    Icon(status == 'approved' ? Icons.verified : Icons.info_outline, color: companyStatusColor(status)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(status == 'approved' ? 'Entreprise vérifiée' : companyStatusLabel(status), style: mst(13, w: FontWeight.w700, c: companyStatusColor(status)))),
                    if (status != 'approved') Text('Compléter', style: mst(12.5, w: FontWeight.w800, c: kViolet)),
                  ]),
                ),
              ),
              GestureDetector(
                onTap: () => showCompanyPlans(context, ref),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(5, 0, 5, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    const Icon(Icons.workspace_premium_outlined, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Forfait ${x['plan_name'] ?? 'Découverte'}', style: mst(14, w: FontWeight.w800, c: Colors.white)),
                      Text(x['plan_ends_at'] == null ? 'Sans date de fin' : 'Actif jusqu’au ${'${x['plan_ends_at']}'.substring(0, 10)}', style: mst(12, c: const Color(0xFFD9D5E2))),
                    ])),
                    Text('Changer', style: mst(12.5, w: FontWeight.w800, c: Colors.white)),
                  ]),
                ),
              ),
              Row(children: [
                _tile(context, Icons.assignment_outlined, '${n('needs_open')}', 'Besoins ouverts', '/s/99'),
                _tile(context, Icons.mark_email_unread_outlined, '${n('proposals_new')}', 'Propositions à traiter', '/s/93'),
              ]),
              Row(children: [
                _tile(context, Icons.work_outline, '${n('offers_active')}', 'Offres actives', '/opportunites/mes'),
                _tile(context, Icons.how_to_reg_outlined, '${n('applications_new')}', 'Candidatures reçues', '/opportunites/mes'),
              ]),
              Row(children: [
                _tile(context, Icons.emoji_events_outlined, '${n('contests_active')}', 'Concours actifs', '/concours/mes'),
                _tile(context, Icons.celebration_outlined, '${n('recruits')}', 'Recrutés', '/opportunites/mes'),
              ]),
              mSectionTitle('Actions rapides'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: mButton('Publier un besoin', () => context.push('/s/90'), icon: Icons.add)),
              Padding(padding: const EdgeInsets.fromLTRB(5, 8, 5, 0), child: mButton('Publier une offre (stage, emploi, mission)', () => context.push('/opportunites/publier'), dark: false, icon: Icons.work_outline)),
              Padding(padding: const EdgeInsets.fromLTRB(5, 8, 5, 0), child: mButton('Publier un concours ou un hackathon', () => context.push('/concours/publier'), dark: false, icon: Icons.emoji_events_outlined)),
              Padding(padding: const EdgeInsets.fromLTRB(5, 8, 5, 0), child: mButton('Rechercher des talents', () => context.push('/s/91'), dark: false, icon: Icons.search)),
            ]);
          }),
          const Positioned(left: 0, right: 0, bottom: 14, child: Center(child: MateNavPill())),
        ]),
      ),
    );
  }
}

/// Forfaits proposés (prix et quotas fixés par l'administrateur) et demande de forfait.
Future<void> showCompanyPlans(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (_) => const CompanyPlansSheet(),
    );

class CompanyPlansSheet extends ConsumerWidget {
  const CompanyPlansSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(companyPlansProvider);
    final status = ref.watch(companyPlanStatusProvider).asData?.value;
    final current = '${(status?['plan'] as Map?)?['code'] ?? 'free'}';
    final requested = '${status?['requested'] ?? ''}';
    Future<void> request(String code) async {
      final r = await marcheCall('company_subscription_request', {'p_plan': code});
      if (!context.mounted) return;
      gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Demande envoyée. Réglez le forfait comme indiqué par l’administrateur : il l’active dès réception du paiement.');
      ref.invalidate(companyPlanStatusProvider);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
        Text('Forfaits entreprise', style: mst(18, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Le forfait fixe le nombre de besoins, d’offres et de concours actifs en même temps.', style: mst(12.5, c: kGrey)),
        if (status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Utilisé : ${quotaLabel((status['used_needs'] as num?)?.toInt() ?? 0, (((status['plan'] as Map?)?['max_needs']) as num?)?.toInt() ?? 1)} besoin(s) · ${quotaLabel((status['used_offers'] as num?)?.toInt() ?? 0, (((status['plan'] as Map?)?['max_offers']) as num?)?.toInt() ?? 1)} offre(s)', style: mst(12.5, w: FontWeight.w600))),
        const SizedBox(height: 10),
        mAsync<List<Map<String, dynamic>>>(
          plans,
          (l) => Column(children: [
            for (final p in l)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: '${p['code']}' == current ? kViolet : kLine, width: '${p['code']}' == current ? 2 : 1)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('${p['name']}', style: mst(15, w: FontWeight.w800))), Text(planPriceLabel(p), style: mst(13.5, w: FontWeight.w800, c: kViolet))]),
                  Text('${p['perks'] ?? ''}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                  Text('Besoins : ${quotaLabel(0, (p['max_needs'] as num).toInt()).replaceFirst('0 ', '')} · Offres : ${quotaLabel(0, (p['max_offers'] as num).toInt()).replaceFirst('0 ', '')} · Concours : ${quotaLabel(0, (p['max_contests'] as num).toInt()).replaceFirst('0 ', '')}', style: mst(12, c: kGrey)),
                  const SizedBox(height: 8),
                  if ('${p['code']}' == current) Text('Votre forfait actuel', style: mst(12.5, w: FontWeight.w800, c: kGreen))
                  else if ('${p['code']}' == requested) Text('Demande envoyée : en attente de l’administrateur', style: mst(12.5, w: FontWeight.w800, c: const Color(0xFFB45309)))
                  else if (((p['price_fcfa'] as num?) ?? 0) > 0) mButton('Demander ce forfait', () => request('${p['code']}'), dark: false),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Écran de l'administrateur : demandes de forfait à activer (paiement confirmé à la main) et prix des forfaits modifiables.
class CompanyPlansAdminScreen extends ConsumerWidget {
  const CompanyPlansAdminScreen({super.key});

  Future<void> _activate(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Activer le forfait ?'),
        content: Text('Confirmez que vous avez reçu le paiement de ${planPriceLabel({'price_fcfa': r['price_fcfa'], 'period_days': r['period_days']})} de ${r['company_name']}. Le forfait « ${r['plan_name']} » sera actif pour ${r['period_days']} jours.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Paiement reçu : activer'))],
      ),
    );
    if (yes != true || !context.mounted) return;
    final x = await marcheCall('company_subscription_activate', {'p_owner': r['owner_id'], 'p_plan': r['plan_code']});
    if (!context.mounted) return;
    gToast(context, x.error != null ? Backend.userMessage('${x.error}') : 'Forfait activé. L’entreprise est prévenue.');
    ref.invalidate(companyPendingPlansProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final name = TextEditingController(text: '${p['name']}'), price = TextEditingController(text: '${p['price_fcfa']}'), days = TextEditingController(text: '${p['period_days']}');
    final needs = TextEditingController(text: '${p['max_needs']}'), offers = TextEditingController(text: '${p['max_offers']}'), contests = TextEditingController(text: '${p['max_contests']}');
    final perks = TextEditingController(text: '${p['perks'] ?? ''}');
    var active = p['active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text('Forfait « ${p['code']} »'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix (FCFA)')),
              TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (jours)')),
              TextField(controller: needs, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Besoins actifs (999 = illimité)')),
              TextField(controller: offers, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Offres actives (999 = illimité)')),
              TextField(controller: contests, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Concours actifs')),
              TextField(controller: perks, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
              Row(children: [Expanded(child: Text('Proposé aux entreprises', style: mst(13))), Switch(value: active, onChanged: (v) => setS(() => active = v))]),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Enregistrer'))],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    int i(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final r = await marcheCall('company_plan_save', {
      'p': {'code': p['code'], 'name': name.text, 'price_fcfa': i(price), 'period_days': i(days), 'max_needs': i(needs), 'max_offers': i(offers), 'max_contests': i(contests), 'perks': perks.text, 'position': p['position'], 'active': active}
    });
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Forfait enregistré.');
    ref.invalidate(companyPlansProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Forfaits des entreprises',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mSectionTitle('Demandes à activer'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(companyPendingPlansProvider),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Aucune demande en attente.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final r in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['company_name']}', style: mst(15, w: FontWeight.w800)),
                        Text('Forfait « ${r['plan_name']} » · ${planPriceLabel({'price_fcfa': r['price_fcfa'], 'period_days': r['period_days']})}', style: mst(12.5, c: kGrey)),
                        Text('${r['phone'] ?? ''} · ${r['email'] ?? ''}', style: mst(12, c: kGrey)),
                        const SizedBox(height: 8),
                        mButton('Paiement reçu : activer', () => _activate(context, ref, r)),
                      ]),
                    ),
                ]),
        ),
        mSectionTitle('Forfaits (prix et quotas)'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(companyPlansProvider),
          (l) => Column(children: [
            for (final p in l)
              ListTile(
                title: Text('${p['name']}${p['active'] == false ? ' (masqué)' : ''}', style: mst(14, w: FontWeight.w700)),
                subtitle: Text('${planPriceLabel(p)} · ${quotaLabel(0, (p['max_needs'] as num).toInt()).replaceFirst('0 ', '')} besoins · ${quotaLabel(0, (p['max_offers'] as num).toInt()).replaceFirst('0 ', '')} offres', style: mst(12, c: kGrey)),
                trailing: IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, p)),
              ),
          ]),
        ),
      ]),
    );
  }
}
