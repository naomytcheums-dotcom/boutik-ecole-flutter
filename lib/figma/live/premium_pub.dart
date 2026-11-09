import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart';
import 'paiement_messagerie.dart';
import 'store.dart' show fcfa;

/// Offres premium (plans, abonnements) et campagnes sponsorisées (migration 20261106000000). Aucun prix n'est inventé : tant que
/// l'administration n'a pas fixé le prix d'un plan, il est « à définir » et ne peut pas être souscrit. Toute publicité porte « Sponsorisé ».

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

Widget _btn(String t, VoidCallback f, {bool dark = true, double? w}) => GestureDetector(onTap: f, child: Container(width: w, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: dark ? _ink : Colors.white, borderRadius: BorderRadius.circular(22), border: dark ? null : Border.all(color: const Color(0xFFE6E1EE))), child: Text(t, style: _st(13, w: FontWeight.w700, c: dark ? Colors.white : _ink))));
Widget _note(String t) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(t, textAlign: TextAlign.center, style: _st(14, c: _grey).copyWith(height: 1.5))));
bool _out(WidgetRef ref) => ref.watch(authProvider.select((a) => a.current == null));
bool _isAdmin(WidgetRef ref) => ref.watch(authProvider.select((a) => a.current?.staff == 'admin'));

Future<bool> _run(BuildContext context, String fn, Map<String, dynamic> args, String ok) async {
  final r = await Backend.rpc(fn, args);
  if (!context.mounted) return false;
  if (r.error != null) {
    gToast(context, Backend.userMessage(r.error!));
    return false;
  }
  gToast(context, ok);
  return true;
}

const featureLabels = {
  'stats_avancees': 'Statistiques avancées',
  'portfolio_enrichi': 'Portfolio enrichi',
  'visiteurs_profil': 'Visiteurs de votre profil',
  'outils_vendeur_pro': 'Outils vendeur professionnel',
  'boost_campagnes': 'Campagnes sponsorisées',
  'gestion_equipe': 'Gestion d’équipe',
  'gestion_communaute': 'Gestion de communauté',
};

final plansProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('plans', 'code,name,audience,price_xaf,period_days,features,active', order: 'code', ascending: true));
final entitlementsProvider = NotifierProvider<EntitlementsNotifier, Map<String, dynamic>?>(EntitlementsNotifier.new);

class EntitlementsNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() {
    if (!Backend.ready || ref.watch(authProvider.select((a) => a.current == null))) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('my_entitlements', const {});
    if (!ref.mounted) return;
    state = r.error != null || r.data is! Map ? const {} : Map<String, dynamic>.from(r.data as Map);
  }
}

/// Vrai si le compte a un abonnement en vigueur qui donne ce droit (jamais vrai hors connexion).
bool hasFeature(WidgetRef ref, String feature) => ((ref.watch(entitlementsProvider)?['features'] as List?) ?? const []).contains(feature);

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final ent = ref.watch(entitlementsProvider);
    final admin = _isAdmin(ref);
    final mine = [for (final s in (ent?['subscriptions'] as List? ?? const [])) Map<String, dynamic>.from(s as Map)];
    Widget body;
    if (_out(ref)) {
      body = _note('Connectez-vous pour voir les offres.');
    } else if (plans == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(padding: const EdgeInsets.all(18), children: [
        Text('Offres premium', style: _st(22, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Le badge vérifié reste attribué par le département : il ne s’achète pas.', style: _st(12, c: _grey)),
        const SizedBox(height: 16),
        for (final p in plans)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${p['name']}', style: _st(16, w: FontWeight.w800))), Text(p['price_xaf'] == null ? 'Prix à définir' : (p['price_xaf'] == 0 ? 'Gratuit' : '${fcfa((p['price_xaf'] as num).toInt())} / ${p['period_days']} j'), style: _st(13, w: FontWeight.w700, c: const Color(0xFF5A3FE0)))]),
              if ('${p['audience']}'.isNotEmpty) Text('${p['audience']}', style: _st(12, c: _grey)),
              const SizedBox(height: 10),
              for (final f in (p['features'] as List? ?? const [])) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [const Icon(Icons.check, size: 16, color: Color(0xFF1F9D6B)), const SizedBox(width: 8), Text(featureLabels['$f'] ?? '$f', style: _st(12.5))])),
              if ((p['features'] as List? ?? const []).isEmpty) Text('Fonctions de base.', style: _st(12.5, c: _grey)),
              const SizedBox(height: 12),
              Row(children: [
                if (p['code'] != 'gratuit')
                  _btn(mine.any((s) => s['plan'] == p['code'] && '${s['status']}' != 'expired') ? 'Déjà souscrit ou en attente' : 'Souscrire', () async {
                    final r = await Backend.rpc('subscription_start', {'p_plan': '${p['code']}'});
                    if (!context.mounted) return;
                    if (r.error != null) {
                      gToast(context, Backend.userMessage(r.error!));
                      return;
                    }
                    ref.read(selectedPaymentProvider.notifier).select('${r.data}');
                    ref.invalidate(entitlementsProvider);
                    GoRouter.of(context).push('/paiement');
                  }),
                if (admin) ...[const SizedBox(width: 8), _btn('Fixer le prix', () => _priceDialog(context, ref, p), dark: false)],
              ]),
            ]),
          ),
        if (mine.isNotEmpty) ...[
          Text('Mes abonnements', style: _st(15, w: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final s in mine) Text('${s['name']} · ${_status('${s['status']}')}${s['period_end'] == null ? '' : ' · jusqu’au ${dateCourte(s['period_end'])}'}', style: _st(13)),
          const SizedBox(height: 10),
          if (mine.any((s) => '${s['status']}' == 'active')) _btn('Annuler à la fin de la période', () async { if (await _run(context, 'subscription_cancel', const {}, 'Annulation programmée.')) ref.invalidate(entitlementsProvider); }, dark: false),
        ],
      ]);
    }
    return Scaffold(backgroundColor: const Color(0xFFF7F6F4), appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: _ink, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => gBack(context)), title: Text('Offres', style: _st(16, w: FontWeight.w700))), body: SafeArea(child: body));
  }

  static String _status(String s) => switch (s) { 'pending' => 'paiement en attente', 'active' => 'actif', 'cancel_at_period_end' => 'se termine à l’échéance', _ => 'expiré' };

  Future<void> _priceDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final c = TextEditingController(text: p['price_xaf'] == null ? '' : '${p['price_xaf']}');
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text('Prix de ${p['name']}'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix en FCFA (vide = à définir)')), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enregistrer'))]));
    if (ok != true || !context.mounted) return;
    if (await _run(context, 'plan_set', {'p_code': '${p['code']}', 'p_name': '${p['name']}', 'p_price': int.tryParse(c.text.trim()), 'p_active': true}, 'Prix enregistré.')) await ref.read(plansProvider.notifier).refresh();
  }
}

// ------------------------------------------------------------------ campagnes sponsorisées

final myAdsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('my_ad_campaigns'));
final pendingAdsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('ad_campaigns', 'id,title,body,budget_xaf,status,created_at', order: 'created_at'));

String adStatus(Object? s) => switch ('$s') {
      'awaiting_payment' => 'Paiement du budget en attente',
      'pending_review' => 'En attente de validation',
      'approved' => 'Validée, début à venir',
      'active' => 'Active',
      'paused' => 'En pause',
      'finished' => 'Terminée',
      'rejected' => 'Refusée',
      _ => 'Brouillon',
    };

class AdsScreen extends ConsumerWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(myAdsProvider);
    final admin = ref.watch(authProvider.select((a) => const {'admin', 'direction'}.contains(a.current?.staff)));
    Widget body;
    if (_out(ref)) {
      body = _note('Connectez-vous pour gérer vos campagnes.');
    } else if (rows == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(padding: const EdgeInsets.all(18), children: [
        Row(children: [Expanded(child: Text('Mes campagnes', style: _st(22, w: FontWeight.w800))), _btn('Nouvelle', () => adDialog(context, ref))]),
        const SizedBox(height: 4),
        Text('Toute publicité est marquée « Sponsorisé ». Le budget se règle par le fil de paiement avant la validation.', style: _st(12, c: _grey)),
        const SizedBox(height: 14),
        if (rows.isEmpty) _note('Aucune campagne pour le moment.'),
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE8F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${r['title']}', style: _st(14.5, w: FontWeight.w800))), Text(adStatus(r['status']), style: _st(11.5, w: FontWeight.w700, c: const Color(0xFF5A3FE0)))]),
              const SizedBox(height: 6),
              Text('Budget ${fcfa((r['budget'] as num).toInt())} · dépensé ${fcfa((r['spent'] as num).toInt())}', style: _st(12, c: _grey)),
              Text('${r['impressions']} impressions · ${r['clicks']} clics${r['ctr'] == null ? '' : ' · ${r['ctr']} % de clics'}', style: _st(12, c: _grey)),
              if ('${r['review_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Motif : ${r['review_note']}', style: _st(12, c: const Color(0xFFC0392B)))),
              const SizedBox(height: 10),
              Row(children: [
                if ('${r['status']}' == 'draft' || '${r['status']}' == 'rejected')
                  _btn('Payer le budget', () async {
                    final x = await Backend.rpc('ad_campaign_submit', {'p_id': '${r['id']}'});
                    if (!context.mounted) return;
                    if (x.error != null) {
                      gToast(context, Backend.userMessage(x.error!));
                      return;
                    }
                    ref.read(selectedPaymentProvider.notifier).select('${x.data}');
                    ref.invalidate(myAdsProvider);
                    GoRouter.of(context).push('/paiement');
                  }),
                if ('${r['status']}' == 'awaiting_payment' && r['payment_id'] != null)
                  _btn('Ouvrir le paiement', () {
                    ref.read(selectedPaymentProvider.notifier).select('${r['payment_id']}');
                    GoRouter.of(context).push('/paiement');
                  }, dark: false),
                if ('${r['status']}' == 'active' || '${r['status']}' == 'paused') _btn('${r['status']}' == 'active' ? 'Mettre en pause' : 'Reprendre', () async { if (await _run(context, 'ad_campaign_toggle', {'p_id': '${r['id']}'}, 'Campagne mise à jour.')) await ref.read(myAdsProvider.notifier).refresh(); }, dark: false),
              ]),
            ]),
          ),
        if (admin) ...[const SizedBox(height: 12), _btn('Campagnes à valider', () => GoRouter.of(context).push('/campagnes/validation'), dark: false)],
      ]);
    }
    return Scaffold(backgroundColor: const Color(0xFFF7F6F4), appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: _ink, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => gBack(context)), title: Text('Campagnes sponsorisées', style: _st(16, w: FontWeight.w700))), body: SafeArea(child: body));
  }
}

final myPostsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('posts', 'id,caption,author_id,status', order: 'created_at'));
final myListingsForAdsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('listings', 'id,title,seller_id,status', order: 'created_at'));

Future<void> adDialog(BuildContext context, WidgetRef ref) async {
  if (!hasFeature(ref, 'boost_campagnes')) {
    final go = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Offre requise'), content: const Text('Les campagnes sponsorisées font partie des offres Vendeur professionnel et Entreprise.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Fermer')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Voir les offres'))]));
    if (go == true && context.mounted) GoRouter.of(context).push('/offres');
    return;
  }
  final uid = Backend.userId;
  final posts = [for (final r in (ref.read(myPostsProvider) ?? const <Map<String, dynamic>>[])) if ('${r['author_id']}' == uid && '${r['status']}' == 'published') r];
  final listings = [for (final r in (ref.read(myListingsForAdsProvider) ?? const <Map<String, dynamic>>[])) if ('${r['seller_id']}' == uid && '${r['status']}' == 'approved') r];
  final title = TextEditingController(), body = TextEditingController(), budget = TextEditingController();
  String? target;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: const Text('Nouvelle campagne'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
            TextField(controller: body, decoration: const InputDecoration(labelText: 'Texte (facultatif)')),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget en FCFA (1 000 minimum)')),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Contenu à promouvoir'),
              value: target,
              items: [for (final p in posts) DropdownMenuItem(value: 'post:${p['id']}', child: Text('Publication : ${'${p['caption']}'.isEmpty ? 'sans légende' : p['caption']}', overflow: TextOverflow.ellipsis)), for (final l in listings) DropdownMenuItem(value: 'listing:${l['id']}', child: Text('Annonce : ${l['title']}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => set(() => target = v),
            ),
            if (posts.isEmpty && listings.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Vous n’avez encore aucune publication ni annonce publiée à promouvoir.', style: TextStyle(fontSize: 12))),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Créer'))],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final isPost = (target ?? '').startsWith('post:');
  final id = target == null ? null : target!.substring(target!.indexOf(':') + 1);
  if (await _run(context, 'ad_campaign_save', {'p_id': null, 'p_title': title.text, 'p_body': body.text, 'p_post': isPost ? id : null, 'p_listing': !isPost ? id : null, 'p_budget': int.tryParse(budget.text.replaceAll(RegExp(r'\D'), '')) ?? 0, 'p_daily': null, 'p_starts': null, 'p_ends': null}, 'Brouillon créé.')) {
    await ref.read(myAdsProvider.notifier).refresh();
  }
}

class AdReviewScreen extends ConsumerWidget {
  const AdReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(pendingAdsProvider);
    final rows = [for (final r in (all ?? const <Map<String, dynamic>>[])) if ('${r['status']}' == 'pending_review') r];
    Widget body;
    if (_out(ref)) {
      body = _note('Connectez-vous avec un compte de gestion.');
    } else if (all == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (rows.isEmpty) {
      body = _note('Aucune campagne à valider.');
    } else {
      body = ListView(padding: const EdgeInsets.all(18), children: [
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE8F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['title']}', style: _st(14.5, w: FontWeight.w800)),
              Text('${r['body']}', style: _st(12.5, c: _grey)),
              Text('Budget ${fcfa((r['budget_xaf'] as num).toInt())}', style: _st(12)),
              const SizedBox(height: 10),
              Row(children: [
                _btn('Valider', () async { if (await _run(context, 'ad_campaign_review', {'p_id': '${r['id']}', 'p_approve': true, 'p_note': null}, 'Campagne validée.')) await ref.read(pendingAdsProvider.notifier).refresh(); }),
                const SizedBox(width: 8),
                _btn('Refuser', () async {
                  final c = TextEditingController();
                  final go = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Motif du refus'), content: TextField(controller: c), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Refuser'))]));
                  if (go != true || !context.mounted) return;
                  if (await _run(context, 'ad_campaign_review', {'p_id': '${r['id']}', 'p_approve': false, 'p_note': c.text}, 'Campagne refusée.')) await ref.read(pendingAdsProvider.notifier).refresh();
                }, dark: false),
              ]),
            ]),
          ),
      ]);
    }
    return Scaffold(backgroundColor: const Color(0xFFF7F6F4), appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: _ink, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => gBack(context)), title: Text('Campagnes à valider', style: _st(16, w: FontWeight.w700))), body: SafeArea(child: body));
  }
}

// ------------------------------------------------------------------ publicités dans le fil

final adFeedProvider = NotifierProvider<AdFeedNotifier, List<Map<String, dynamic>>>(AdFeedNotifier.new);

class AdFeedNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    if (!Backend.ready || ref.watch(authProvider.select((a) => a.current == null))) return const [];
    Future.microtask(() async {
      final r = await Backend.rpc('ad_feed', {'p_limit': 2});
      if (ref.mounted && r.error == null && r.data is List) state = [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
    });
    return const [];
  }
}

/// Carte publicitaire du fil : toujours « Sponsorisé » ; l'impression est comptée une fois par personne et par jour, le clic aussi.
class SponsoredCard extends ConsumerStatefulWidget {
  const SponsoredCard({super.key, required this.ad});
  final Map<String, dynamic> ad;
  @override
  ConsumerState<SponsoredCard> createState() => _SponsoredCardState();
}

class _SponsoredCardState extends ConsumerState<SponsoredCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Backend.rpc('ad_event_record', {'p_campaign': '${widget.ad['id']}', 'p_kind': 'impression'}));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ad;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Backend.rpc('ad_event_record', {'p_campaign': '${a['id']}', 'p_kind': 'click'});
        if (a['listing_id'] != null) gOpen(context, '22');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFFBF0), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFF1E3B8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF5E6B0), borderRadius: BorderRadius.circular(8)), child: Text('Sponsorisé', style: _st(10.5, w: FontWeight.w800, c: const Color(0xFF7A5A00)))), const SizedBox(width: 8), Expanded(child: Text('${a['owner']}', style: _st(12, c: _grey)))]),
          const SizedBox(height: 8),
          Text('${a['title']}', style: _st(14.5, w: FontWeight.w800)),
          if ('${a['body']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${a['body']}', style: _st(13).copyWith(height: 1.45))),
        ]),
      ),
    );
  }
}

/// Raccourcis du compte : paiements, offres premium et campagnes sponsorisées.
class ShortcutsPanel extends StatelessWidget {
  const ShortcutsPanel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: SingleChildScrollView(child: Column(children: [
          _btn('Mes paiements', () => GoRouter.of(context).push('/paiements'), w: width),
          const SizedBox(height: 8),
          _btn('Offres premium', () => GoRouter.of(context).push('/offres'), dark: false, w: width),
          const SizedBox(height: 8),
          _btn('Mes campagnes sponsorisées', () => GoRouter.of(context).push('/campagnes'), dark: false, w: width),
        ])),
      );
}
