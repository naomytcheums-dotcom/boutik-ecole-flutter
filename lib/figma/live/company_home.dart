import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart' show screenPath;
import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'access.dart' show canOpen, roleKey;
import 'backend.dart';
import 'account_menu.dart' show accountMenu;
import 'coequipiers_screens.dart' show MateNavPill;
import 'company_screens.dart' show companyContextProvider, companyRoleLabels, companyStatusColor, companyStatusLabel;
import 'org_types.dart' show orgTypeOf;
import 'org_partnerships.dart' show orgPartnershipsPendingProvider;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'notifs.dart' show NotifBadge;
import 'tara_payment.dart';

/// Accueil et forfaits de l'organisation. Tout vient du serveur (migrations 20261114002600 et 20261120010000) ; les prix et quotas sont ceux que l'administrateur a définis.

final companyDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final ctx = ref.watch(companyContextProvider);
  final r = await marcheCall('company_dashboard', {'p_owner': ?ctx});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
}, retry: (_, _) => null);

final companyPlansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final ctx = ref.watch(companyContextProvider);
  final r = await marcheCall('company_plans_list', {'p_owner': ?ctx});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

final companyPlanStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final ctx = ref.watch(companyContextProvider);
  final r = await marcheCall('company_plan_status', {'p_owner': ?ctx});
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

/// Quota d'un forfait tel qu'affiché sur sa carte : « 0 sur 10 » ou « illimité ».
String planQuotaLabel(int max) => max >= 999 ? 'illimité' : quotaLabel(0, max);

/// Paiement ou demande de forfait : propriétaire, administrateur ou finance de l'organisation.
bool roleCanPayHome(String role) => role == 'owner' || role == 'admin' || role == 'finance';

/// « 2026-11-17T10:00:00+00:00 » -> « 17/11/2026 » (vide si la date est illisible).
String frDate(Object? iso) {
  final d = DateTime.tryParse('$iso');
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

/// Message de l'accueil de l'organisation quand le chargement échoue (jamais le texte de la marketplace).
String companyLoadErrorText(Object e) {
  final code = e is MarcheException ? e.code : e;
  if (code == 'offline' || code == 'missing') return 'L’espace de l’organisation n’est pas joignable pour le moment. Vérifiez votre connexion, puis réessayez.';
  return Backend.userMessage('$code');
}

/// Instructions de paiement d'une demande de forfait manuelle : le numéro vient du réglage de l'administrateur (payments.manual_number) ;
/// s'il n'est pas renseigné, on le dit franchement au lieu d'inventer une consigne.
String manualPlanPaymentMessage({required String planName, required String reference, required num amount, String number = '', String operator = ''}) {
  final amountText = planPriceLabel({'price_fcfa': amount, 'period_days': 30}).split(' /').first;
  if (number.trim().isEmpty) {
    return 'Votre demande du forfait « $planName » est enregistrée (référence $reference, $amountText). L’administration n’a pas encore communiqué de numéro pour le paiement manuel : elle vous contactera avec les instructions. Vous pouvez aussi payer tout de suite par Mobile Money avec le bouton « Payer par Mobile Money ».';
  }
  return 'Envoyez $amountText par ${operator.trim().isEmpty ? 'Mobile Money' : operator.trim()} au $number en indiquant la référence $reference. Puis déclarez votre paiement dans « Mes paiements » (bouton « J’ai payé ») : le forfait « $planName » s’active dès que la finance a confirmé la réception.';
}

class CompanyHomeScreen extends ConsumerWidget {
  const CompanyHomeScreen({super.key, this.shared = false});

  /// Espace partagé : on consulte l'organisation dont on est membre (pas de publication au nom de l'organisation pour l'instant).
  final bool shared;

  Widget _tile(BuildContext context, IconData icon, String value, String label, String? route) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: route == null ? null : () => context.push(route),
          child: Container(
            margin: const EdgeInsets.all(5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: kViolet, size: 22), const SizedBox(height: 8), Text(value, style: mst(22, w: FontWeight.w800)), Text(label, style: mst(12, c: kGrey))]),
          ),
        ),
      );

  /// En-tête (titre, notifications, menu du compte) : toujours affiché, même quand le chargement échoue.
  Widget _header(BuildContext context, WidgetRef ref, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 4),
        child: Row(children: [
          if (shared) IconButton(tooltip: 'Retour', onPressed: () => context.canPop() ? context.pop() : context.go('/mes-entreprises'), icon: const Icon(Icons.arrow_back_rounded, color: kInk)),
          Expanded(child: Text(title, style: mst(22, w: FontWeight.w800))),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(screenPath('50')),
            icon: SizedBox(width: 28, height: 28, child: Stack(clipBehavior: Clip.none, children: [const Center(child: Icon(Icons.notifications_none_rounded, color: kInk)), const Positioned(left: 14, top: 0, child: NotifBadge())])),
          ),
          IconButton(tooltip: 'Menu du compte', onPressed: () => accountMenu(context, ref), icon: const Icon(Icons.menu_rounded, color: kInk)),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(companyDashboardProvider);
    final account = ref.watch(authProvider.select((a) => a.current));
    final org = const {'company', 'admin'}.contains(roleKey(account)) && !shared;
    // Un membre d'équipe (vue partagée) consulte les offres de l'organisation depuis son espace : lecture ouverte par le serveur (20261118000100).
    final viaTeam = shared;
    final open99 = canOpen(account, '99') && !shared;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      body: SafeArea(
        child: Stack(children: [
          d.when(
            loading: () => ListView(padding: const EdgeInsets.fromLTRB(11, 12, 11, 130), children: [_header(context, ref, 'Mon organisation'), const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))]),
            error: (e, _) => ListView(padding: const EdgeInsets.fromLTRB(11, 12, 11, 130), children: [
              _header(context, ref, 'Mon organisation'),
              mNote(companyLoadErrorText(e)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: mButton('Réessayer', () => ref.invalidate(companyDashboardProvider), icon: Icons.refresh)),
            ]),
            data: (x) {
            final status = '${x['status']}' == 'none' ? 'draft' : '${x['status']}';
            int n(String k) => (x[k] as num?)?.toInt() ?? 0;
            final myRole = '${x['my_role'] ?? 'owner'}';
            return ListView(padding: const EdgeInsets.fromLTRB(11, 12, 11, 130), children: [
              _header(context, ref, '${x['company_name'] ?? 'Mon organisation'}'),
              if (shared) Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, 8), child: Text('Vous êtes ${companyRoleLabels['${x['my_role']}'] ?? x['my_role']} de cette organisation.', style: mst(12.5, w: FontWeight.w600, c: kViolet)))
              else const SizedBox(height: 4),
              if (x['org_type'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 8),
                  child: Wrap(spacing: 8, runSpacing: 4, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(12)),
                      child: Text('${x['org_type_label'] ?? orgTypeOf('${x['org_type']}').label}', style: mst(12, w: FontWeight.w700, c: kViolet)),
                    ),
                  ]),
                ),
              GestureDetector(
                onTap: () => context.push('/entreprise/profil'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(5, 0, 5, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: companyStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    Icon(status == 'approved' ? Icons.verified : Icons.info_outline, color: companyStatusColor(status)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(status == 'approved' ? 'Organisation vérifiée' : companyStatusLabel(status), style: mst(13, w: FontWeight.w700, c: companyStatusColor(status)))),
                    if (status == 'draft' || status == 'rejected') Text('Compléter', style: mst(12.5, w: FontWeight.w800, c: kViolet)),
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
                      Text(x['plan_ends_at'] == null ? 'Sans date de fin' : 'Actif jusqu’au ${frDate(x['plan_ends_at'])}', style: mst(12, c: const Color(0xFFD9D5E2))),
                    ])),
                    Text(roleCanPayHome(myRole) ? 'Changer' : 'Voir', style: mst(12.5, w: FontWeight.w800, c: Colors.white)),
                  ]),
                ),
              ),
              if (!roleCanPayHome(myRole)) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: Text('Seuls le propriétaire, les administrateurs et la finance de l’organisation peuvent changer de forfait.', style: mst(12, c: kGrey))),
              if (shared) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: Text('Les candidatures et statistiques des offres se consultent depuis les cases Offres actives, Candidatures et Recrutés (décisions réservées aux administrateurs). Les besoins, la publication et les concours se gèrent depuis le compte du propriétaire.', style: mst(12, c: kGrey))),
              Row(children: [
                _tile(context, Icons.assignment_outlined, '${n('needs_open')}', 'Besoins ouverts', open99 ? '/s/99' : null),
                _tile(context, Icons.mark_email_unread_outlined, '${n('proposals_new')}', 'Propositions à traiter', open99 ? '/s/93' : null),
              ]),
              Row(children: [
                _tile(context, Icons.work_outline, '${n('offers_active')}', 'Offres actives', (org || viaTeam) ? '/opportunites/mes' : null),
                _tile(context, Icons.how_to_reg_outlined, '${n('applications_new')}', 'Candidatures reçues', (org || viaTeam) ? '/opportunites/mes' : null),
              ]),
              Row(children: [
                _tile(context, Icons.emoji_events_outlined, '${n('contests_active')}', 'Concours actifs', org ? '/concours/mes' : null),
                _tile(context, Icons.celebration_outlined, '${n('recruits')}', 'Recrutés', (org || viaTeam) ? '/opportunites/mes' : null),
              ]),
              Padding(padding: const EdgeInsets.fromLTRB(5, 6, 5, 0), child: mButton('Équipe de l’organisation · ${n('members')} personne${n('members') > 1 ? 's' : ''}', () => context.push('/entreprise/equipe'), dark: false, icon: Icons.groups_2_outlined)),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
                child: mButton('Partenariats avec l’établissement${ref.watch(orgPartnershipsPendingProvider) > 0 ? ' · ${ref.watch(orgPartnershipsPendingProvider)} à confirmer' : ''}', () => context.push('/entreprise/partenariats'), dark: false, icon: Icons.handshake_outlined),
              ),
              if (!shared) ...[
              mSectionTitle('Actions rapides'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: mButton('Publier un besoin', () => context.push('/s/90'), icon: Icons.add)),
              Padding(padding: const EdgeInsets.fromLTRB(5, 8, 5, 0), child: mButton('Publier une offre (stage, emploi, mission)', () => context.push('/opportunites/publier'), dark: false, icon: Icons.work_outline)),
              Padding(padding: const EdgeInsets.fromLTRB(5, 8, 5, 0), child: mButton('Publier un concours ou un hackathon', () => context.push('/concours/publier'), dark: false, icon: Icons.emoji_events_outlined)),
              Padding(padding: const EdgeInsets.fromLTRB(5, 8, 5, 0), child: mButton('Rechercher des talents', () => context.push('/s/91'), dark: false, icon: Icons.search)),
              ],
              mSectionTitle('Explorer Boutik-École'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in const [
                    (Icons.storefront_outlined, 'Marketplace', '/marche'),
                    (Icons.home_outlined, 'Accueil Boutik-École', '/s/03?vue=standard'),
                    (Icons.lightbulb_outline, 'Projets innovants', '/innovations'),
                    (Icons.emoji_events_outlined, 'Concours', '/concours'),
                    (Icons.work_outline, 'Opportunités', '/opportunites'),
                    (Icons.school_outlined, 'Mentors', '/mentors'),
                    (Icons.groups_outlined, 'Communautés', '/communautes'),
                  ])
                    GestureDetector(
                      onTap: () => context.push(e.$3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: kLine)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(e.$1, size: 18, color: kViolet), const SizedBox(width: 6), Text(e.$2, style: mst(12.5, w: FontWeight.w700))]),
                      ),
                    ),
                ]),
              ),
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
    final myRole = '${status?['my_role'] ?? 'owner'}';
    final canPay = myRole == 'owner' || myRole == 'admin' || myRole == 'finance';
    Future<void> pay(Map<String, dynamic> p) async {
      if (!Backend.ready) return gAlert(context, 'Paiement indisponible', 'Le paiement nécessite la connexion au serveur. Reconnectez-vous puis réessayez.');
      final ctx = ref.read(companyContextProvider);
      final r = await marcheCall('company_plan_checkout', {'p_plan': p['code'], 'p_owner': ?ctx});
      if (!context.mounted) return;
      if (r.error != null) return gAlert(context, 'Paiement impossible', Backend.userMessage('${r.error}'));
      if (r.data is! Map) return gAlert(context, 'Paiement impossible', 'Le serveur n’a pas renvoyé la transaction. Réessayez dans un instant.');
      final tx = Map<String, dynamic>.from(r.data as Map);
      final ok = await payWithTara(context, ref, reference: '${tx['reference']}', amount: (tx['amount'] as num).toInt(), label: 'le forfait ${p['name']}');
      ref.invalidate(companyPlanStatusProvider);
      ref.invalidate(companyDashboardProvider);
      if (ok && context.mounted) Navigator.of(context).maybePop();
    }

    Future<void> request(String code) async {
      if (!Backend.ready) return gAlert(context, 'Demande impossible', 'La demande nécessite la connexion au serveur. Reconnectez-vous puis réessayez.');
      final owner = ref.read(companyContextProvider);
      final r = await marcheCall('company_subscription_request', {'p_plan': code, 'p_owner': ?owner});
      if (!context.mounted) return;
      if (r.error != null) {
        await gAlert(context, 'Demande impossible', Backend.userMessage('${r.error}'));
        return;
      }
      ref.invalidate(companyPlanStatusProvider);
      Map<String, dynamic>? st;
      try {
        st = await ref.read(companyPlanStatusProvider.future);
      } catch (_) {}
      final pay = st?['requested_payment'] is Map ? Map<String, dynamic>.from(st!['requested_payment'] as Map) : null;
      final ins = await Backend.rpc('payment_instructions', const {});
      final m = ins.data is Map ? Map<String, dynamic>.from(ins.data as Map) : <String, dynamic>{};
      if (!context.mounted) return;
      final planName = '${((plans.asData?.value ?? const []).firstWhere((p) => '${p['code']}' == code, orElse: () => {'name': code}))['name']}';
      final text = pay == null
          ? 'Votre demande du forfait « $planName » est enregistrée. L’administration vous communiquera les instructions de paiement.'
          : manualPlanPaymentMessage(planName: planName, reference: '${pay['reference']}', amount: (pay['amount'] as num?) ?? 0, number: '${m['merchant_number'] ?? ''}', operator: '${m['operator'] ?? ''}');
      final toPayments = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Demande envoyée'),
          content: Text(text),
          actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Fermer')), if (pay != null) TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Mes paiements'))],
        ),
      );
      if (toPayments == true && context.mounted) {
        Navigator.of(context).maybePop();
        context.push('/paiements');
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
        Text('Forfaits de l’organisation', style: mst(18, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Le forfait fixe le nombre de besoins, d’offres et de concours actifs en même temps.', style: mst(12.5, c: kGrey)),
        if (status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Utilisé : ${quotaLabel((status['used_needs'] as num?)?.toInt() ?? 0, (((status['plan'] as Map?)?['max_needs']) as num?)?.toInt() ?? 1)} besoin(s) · ${quotaLabel((status['used_offers'] as num?)?.toInt() ?? 0, (((status['plan'] as Map?)?['max_offers']) as num?)?.toInt() ?? 1)} offre(s) · ${quotaLabel((status['used_contests'] as num?)?.toInt() ?? 0, (((status['plan'] as Map?)?['max_contests']) as num?)?.toInt() ?? 0)} concours', style: mst(12.5, w: FontWeight.w600))),
        if (status != null && !canPay) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Seuls le propriétaire, les administrateurs et la finance de l’organisation peuvent payer ou demander un forfait.', style: mst(12, c: kGrey))),
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
                  if (((p['audience_types'] as List?) ?? const []).isNotEmpty) Text('Pour : ${[for (final t in (p['audience_types'] as List)) orgTypeOf('$t').label].join(', ')}', style: mst(12, w: FontWeight.w600, c: kViolet)),
                  Text('Besoins : ${planQuotaLabel((p['max_needs'] as num).toInt())} · Offres : ${planQuotaLabel((p['max_offers'] as num).toInt())} · Concours : ${planQuotaLabel((p['max_contests'] as num).toInt())}', style: mst(12, c: kGrey)),
                  const SizedBox(height: 8),
                  if ('${p['code']}' == current) Text('Votre forfait actuel', style: mst(12.5, w: FontWeight.w800, c: kGreen))
                  else if (canPay && ((p['price_fcfa'] as num?) ?? 0) > 0) ...[
                    if ('${p['code']}' == requested) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Demande envoyée : en attente de l’administrateur', style: mst(12.5, w: FontWeight.w800, c: const Color(0xFFB45309)))),
                    mButton('Payer par Mobile Money', () => pay(p), icon: Icons.phone_android),
                    if ('${p['code']}' != requested) TextButton(onPressed: () => request('${p['code']}'), child: Text('Payer autrement : demander l’activation à l’administrateur', style: mst(12, w: FontWeight.w600, c: kGrey))),
                  ],
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
    var x = await marcheCall('company_subscription_activate', {'p_owner': r['owner_id'], 'p_plan': r['plan_code']});
    if (x.error != null && '${x.error}'.contains('inférieur') && context.mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Remplacer un forfait supérieur ?'),
          content: Text('${x.error}'),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Remplacer quand même'))],
        ),
      );
      if (replace != true || !context.mounted) return;
      x = await marcheCall('company_subscription_activate', {'p_owner': r['owner_id'], 'p_plan': r['plan_code'], 'p_confirm_replace': true});
    }
    if (!context.mounted) return;
    gToast(context, x.error != null ? Backend.userMessage('${x.error}') : 'Forfait activé. L’organisation est prévenue.');
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
              Row(children: [Expanded(child: Text('Proposé aux organisations', style: mst(13))), Switch(value: active, onChanged: (v) => setS(() => active = v))]),
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
      title: 'Forfaits des organisations',
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
                        if ('${r['payment_reference'] ?? ''}'.isNotEmpty) Text('Paiement ${r['payment_reference']} : ${switch ('${r['payment_status']}') { 'pending' => 'déclaré par l’organisation${'${r['provider_ref'] ?? ''}'.isEmpty ? '' : ' (réf. ${r['provider_ref']})'}', 'created' => 'pas encore déclaré', 'confirmed' => 'confirmé', _ => '${r['payment_status']}' }}', style: mst(12, w: FontWeight.w600, c: kGrey)),
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
