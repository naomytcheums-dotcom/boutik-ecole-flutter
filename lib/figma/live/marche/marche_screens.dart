import 'package:flutter/material.dart' hide Text;
import '../../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/demo/section_a_demo.dart' show CartLine;
import '../../../data/repositories/repositories.dart' show cartProvider;
import '../../gen.dart' show gToast;
import '../auth.dart';
import '../backend.dart';
import '../messages.dart' show contactSeller;
import '../../nav.dart' show gOpenProfile;
import '../offer_types.dart' show offerTypeLabels;
import '../promo_state.dart';
import 'decouverte.dart';
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Écrans acheteur de la marketplace : accueil (recherche, filtres, tris, tendances), vitrine d'une boutique, ventes flash,
/// fiche produit riche, comparaison, boutiques suivies, panier par boutique.

final marcheCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  if (!Backend.ready) return const [];
  final r = await Backend.rows('marketplace_categories', 'label,position,active', eq: const {'active': true}, order: 'position', ascending: true, limit: 30);
  return [for (final x in r.rows) '${x['label']}'];
});

// ------------------------------------------------------------------ accueil de la marketplace

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _set(MarcheFilters f) => ref.read(marcheFiltersProvider.notifier).set(f);

  Future<void> _filters() async {
    final f = ref.read(marcheFiltersProvider);
    final city = TextEditingController(text: f.city);
    final min = TextEditingController(text: f.min?.toString() ?? '');
    final max = TextEditingController(text: f.max?.toString() ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filtres', style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'Ville ou lieu', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix min (FCFA)', border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix max (FCFA)', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: mButton('Effacer', () => Navigator.pop(c, false), dark: false)),
            const SizedBox(width: 12),
            Expanded(child: mButton('Appliquer', () => Navigator.pop(c, true))),
          ]),
        ]),
      ),
    );
    if (ok == null) return;
    _set(ok ? f.copy(city: city.text.trim(), min: int.tryParse(min.text.trim()), max: int.tryParse(max.text.trim())) : f.copy(city: '', min: null, max: null));
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(marcheFiltersProvider);
    final cats = ref.watch(marcheCategoriesProvider).value ?? const <String>[];
    final browsing = f.q.trim().isEmpty && !f.active && !f.shops;
    return MarchePage(
      title: 'Marketplace',
      actions: [
        Semantics(button: true, label: 'Ventes flash', excludeSemantics: true, child: IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.bolt_rounded), onPressed: () => context.push('/marche/ventes-flash'))),
        if (ref.watch(authProvider.select((a) => a.current?.staff.isNotEmpty ?? false))) Semantics(button: true, label: 'Modération de la marketplace', excludeSemantics: true, child: IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.verified_user_outlined), onPressed: () => context.push('/marche/moderation'))),
        Semantics(button: true, label: 'Mes boutiques suivies', excludeSemantics: true, child: IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.storefront_outlined), onPressed: () => context.push('/marche/suivies'))),
      ],
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(child: mButton('Appel à entreprises', () => context.push('/marche/appels'), dark: false, icon: Icons.campaign_outlined)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Projets de l’IUT', () => context.push('/marche/projets'), dark: false, icon: Icons.verified_outlined)),
          ]),
        ),
        if (ref.watch(marcheCompareProvider).length >= 2) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Comparer ${ref.watch(marcheCompareProvider).length} produits', () => context.push('/marche/comparer'), icon: Icons.compare_arrows_rounded)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _set(f.copy(q: v, need: '')),
                decoration: InputDecoration(hintText: f.shops ? 'Rechercher une boutique' : 'Un produit, ou votre problème : « mon stock se perd »', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(button: true, label: 'Filtres prix, lieu', excludeSemantics: true, child: GestureDetector(onTap: _filters, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: f.active ? kInk : Colors.white, borderRadius: BorderRadius.circular(4)), child: Icon(Icons.tune_rounded, color: f.active ? Colors.white : kInk)))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(children: [
            MDropdown(label: 'Type d’offre', value: f.offerType, items: {'': 'Tous les types d’offres', ...offerTypeLabels}, onChanged: (v) => _set(f.copy(offerType: v, shops: false))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MDropdown(label: 'Filière', value: f.department, items: marcheFilieres, onChanged: (v) => _set(f.copy(department: v, shops: false)))),
              const SizedBox(width: 10),
              Expanded(child: MDropdown(label: 'Besoin', value: f.need, items: marcheBesoins, onChanged: (v) => _set(f.copy(need: v, q: '', shops: false)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MDropdown(label: 'Afficher', value: f.shops ? 'shops' : 'products', items: const {'products': 'Produits', 'shops': 'Boutiques'}, onChanged: (v) => _set(f.copy(shops: v == 'shops')))),
              const SizedBox(width: 10),
              Expanded(child: MDropdown(label: 'Catégorie', value: f.category, items: {'': 'Toutes catégories', for (final c in cats) c: c}, onChanged: (v) => _set(f.copy(category: v)))),
            ]),
            const SizedBox(height: 10),
            MDropdown(label: 'Trier par', value: f.sort, items: marcheSorts, onChanged: (v) => _set(f.copy(sort: v))),
          ]),
        ),
        if (browsing) ...[
          mSectionTitle('Produits tendance'),
          mAsyncList(ref.watch(marcheTrendingProvider), (l) => l.isEmpty ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Les tendances apparaîtront dès les premières ventes.', style: mst(13, c: kGrey))) : MarcheRail(cards: l)),
        ],
        if (browsing && !f.active) ...[
          mSectionTitle('Nouveautés'),
          mAsyncList(ref.watch(marcheNewProvider), (l) => l.isEmpty ? const SizedBox.shrink() : MarcheRail(cards: l)),
          if (ref.watch(authProvider.select((a) => a.current != null))) ...[
            mSectionTitle('Recommandés pour toi'),
            mAsyncList(ref.watch(marcheRecoProvider), (l) => l.isEmpty ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Des offres de votre filière apparaîtront ici dès qu’elles seront publiées.', style: mst(13, c: kGrey))) : MarcheRail(cards: l)),
          ],
        ],
        mSectionTitle(f.shops ? 'Boutiques' : (browsing ? 'Tous les produits' : 'Résultats')),
        if (f.shops)
          mAsyncList(ref.watch(marcheShopsProvider), (l) => l.isEmpty ? mNote('Aucune boutique ne correspond.') : Column(children: [for (final s in l) _ShopRow(shop: s)]))
        else
          mAsyncList(ref.watch(marcheProductsProvider), (l) => l.isEmpty ? mNote('Aucun produit ne correspond à votre recherche.') : MarcheGrid(cards: l)),
      ]),
    );
  }
}

Widget mAsyncList<T>(AsyncValue<T> v, Widget Function(T) b) => mAsync<T>(v, b);

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.shop});
  final Map<String, dynamic> shop;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Boutique ${shop['name']}',
        excludeSemantics: true,
        onTap: () => context.push('/marche/boutique/${shop['slug']}'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/marche/boutique/${shop['slug']}'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 56, height: 56, child: MImage(mImageUrl(shop['logo_url']), icon: Icons.storefront_outlined))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${shop['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14.5, w: FontWeight.w800)),
                  Text([if ('${shop['city'] ?? ''}'.isNotEmpty) '${shop['city']}', '${mInt(shop['products'])} produit${mInt(shop['products']) > 1 ? 's' : ''}', '${mInt(shop['followers'])} abonné${mInt(shop['followers']) > 1 ? 's' : ''}'].join(' · '), style: mst(12, c: kGrey)),
                  if (shop['rating_avg'] != null) Text('★ ${shop['rating_avg']} (${mInt(shop['rating_count'])} avis)', style: mst(12, c: kGrey)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: kGrey),
            ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------ vitrine d'une boutique (type Alibaba)

class ShopPageScreen extends ConsumerWidget {
  const ShopPageScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(marcheShopProvider(slug));
    return MarchePage(title: v.value?['shop'] is Map ? '${(v.value!['shop'] as Map)['name']}' : 'Boutique', child: mAsync<Map<String, dynamic>>(v, (d) => d['found'] != true ? mNote('Cette boutique n’existe pas ou n’est pas encore ouverte.') : _ShopBody(data: d, slug: slug)));
  }
}

class _ShopBody extends ConsumerStatefulWidget {
  const _ShopBody({required this.data, required this.slug});
  final Map<String, dynamic> data;
  final String slug;

  @override
  ConsumerState<_ShopBody> createState() => _ShopBodyState();
}

class _ShopBodyState extends ConsumerState<_ShopBody> {
  bool? _following;
  bool _recorded = false;

  List<Map<String, dynamic>> _list(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  Future<void> _follow(String shopId) async {
    if (!await requireLogin(context, ref, 'suivre cette boutique')) return;
    final r = await marcheCall('toggle_follow_shop', {'p_shop': shopId});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    setState(() => _following = r.data == true);
    ref.invalidate(marcheShopProvider(widget.slug));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final s = Map<String, dynamic>.from(d['shop'] as Map);
    final c1 = mHex(s['color_primary'], kInk), c2 = mHex(s['color_secondary'], kViolet);
    final following = _following ?? d['following'] == true;
    final isOwner = d['is_owner'] == true;
    if (!_recorded && s['status'] == 'active') {
      _recorded = true;
      Future.microtask(() => marcheCall('record_view', {'p_kind': 'shop', 'p_id': s['id']}));
    }
    final flash = _list(d['flash']), campaigns = _list(d['campaigns']), packs = _list(d['packs']), products = _list(d['products']), reviews = _list(d['reviews']);
    final socials = Map<String, dynamic>.from((s['socials'] as Map?) ?? const {});
    return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
      if (s['status'] != 'active') Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(14)), child: Text('Boutique ${shopStatusLabels[s['status']]?.toLowerCase()} : seul vous (ou la modération) la voyez.', style: mst(12.5))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AspectRatio(
          aspectRatio: 16 / 7,
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
            '${s['banner_url'] ?? ''}'.isEmpty ? Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [c1, c2]))) : MImage(mImageUrl(s['banner_url'])),
            Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x99000000)]))),
            Positioned(left: 14, bottom: 12, right: 14, child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(20, w: FontWeight.w800, c: Colors.white))),
          ])),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 64, height: 64, child: MImage(mImageUrl(s['logo_url']), icon: Icons.storefront_outlined))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([if ('${s['city'] ?? ''}'.isNotEmpty) '${s['city']}', '${mInt(d['followers'])} abonné${mInt(d['followers']) > 1 ? 's' : ''}', '${mInt(d['sales'])} vente${mInt(d['sales']) > 1 ? 's' : ''}'].join(' · '), style: mst(12.5, c: kGrey)),
              if (d['rating_avg'] != null) Text('★ ${d['rating_avg']} · ${mInt(d['rating_count'])} avis', style: mst(12.5, c: kGrey)),
              if ((s['categories'] as List? ?? const []).isNotEmpty) Text((s['categories'] as List).join(' · '), style: mst(12, c: kViolet)),
            ]),
          ),
        ]),
      ),
      if ('${s['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text('${s['description']}', style: mst(13.5, c: const Color(0xFF4A4854)).copyWith(height: 1.5))),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          if (isOwner) Expanded(child: mButton('Gérer ma boutique', () => context.push('/marche/ma-boutique'), dark: false)) else ...[
            Expanded(child: mButton(following ? 'Abonné' : 'Suivre la boutique', () => _follow('${s['id']}'), dark: !following, icon: following ? Icons.check : Icons.add)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Écrire', () async {
              if (!await requireLogin(context, ref, 'écrire à cette boutique')) return;
              final r = await Backend.startDirectConversation('${s['owner_id']}', 'Bonjour, je vous contacte au sujet de votre boutique ${s['name']}.');
              if (!context.mounted) return;
              if (r.error != null) return gToast(context, r.error!);
              context.push('/s/53');
            }, dark: false)),
          ],
        ]),
      ),
      if (flash.isNotEmpty) ...[
        mSectionTitle('Ventes flash'),
        MarcheRail(cards: [for (final f in flash) Map<String, dynamic>.from(f['listing'] as Map)]),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Row(children: [const Icon(Icons.timer_outlined, size: 16, color: kRed), const SizedBox(width: 6), Countdown(end: DateTime.parse('${flash.first['ends_at']}'), prefix: 'Se termine dans ')])),
      ],
      for (final c in campaigns) ...[
        mSectionTitle('${c['title']}'),
        if ('${c['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('${c['description']}', style: mst(13, c: kGrey))),
        if (_list(c['products']).isNotEmpty) MarcheRail(cards: _list(c['products'])),
      ],
      if (packs.isNotEmpty) ...[
        mSectionTitle('Packs'),
        for (final p in packs)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['title']}', style: mst(14.5, w: FontWeight.w800)),
              if ('${p['description'] ?? ''}'.isNotEmpty) Text('${p['description']}', style: mst(12.5, c: kGrey)),
              const SizedBox(height: 6),
              Row(children: [Text(mFcfa(p['price']), style: mst(15, w: FontWeight.w800)), const SizedBox(width: 8), Text(mFcfa(p['normal_price']), style: mst(12, c: kGrey).copyWith(decoration: TextDecoration.lineThrough))]),
              const SizedBox(height: 8),
              mButton('Ajouter le pack au panier', () => _addPack(p), dark: false),
            ]),
          ),
      ],
      mSectionTitle('Tous les produits (${products.length})'),
      products.isEmpty ? mNote('Cette boutique n’a pas encore de produit publié.') : MarcheGrid(cards: products),
      if ('${s['delivery_info'] ?? ''}'.isNotEmpty || '${s['terms'] ?? ''}'.isNotEmpty) ...[
        mSectionTitle('Livraison et conditions'),
        if ('${s['delivery_info'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Livraison : ${s['delivery_info']}', style: mst(13, c: const Color(0xFF4A4854)).copyWith(height: 1.5))),
        if ('${s['terms'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Conditions : ${s['terms']}', style: mst(13, c: const Color(0xFF4A4854)).copyWith(height: 1.5))),
      ],
      if (socials.values.any((v) => '$v'.trim().isNotEmpty)) ...[
        mSectionTitle('Réseaux'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8, runSpacing: 6, children: [for (final e in socials.entries) if ('${e.value}'.trim().isNotEmpty) Chip(label: Text('${e.key} : ${e.value}', style: mst(12)))])),
      ],
      mSectionTitle('Avis sur la boutique', trailing: isOwner ? null : TextButton(onPressed: () => _review('${s['id']}'), child: Text('Donner mon avis', style: mst(13, w: FontWeight.w700, c: kViolet)))),
      if (reviews.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucun avis pour le moment.', style: mst(13, c: kGrey))),
      for (final r in reviews) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${'★' * mInt(r['rating'])}  ${r['author']}', style: mst(13, w: FontWeight.w700)), if ('${r['comment'] ?? ''}'.isNotEmpty) Text('${r['comment']}', style: mst(13, c: kGrey))])),
      if (!isOwner) Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _report('${s['id']}'), child: Text('Signaler cette boutique', style: mst(12.5, c: kRed))))),
    ]);
  }

  void _addPack(Map<String, dynamic> p) {
    final shop = Map<String, dynamic>.from(widget.data['shop'] as Map);
    final title = 'Pack · ${p['title']}';
    Backend.packLines[title] = '${p['id']}';
    ref.read(cartProvider.notifier).add(CartLine(title, 'Boutique : ${shop['name']}', mInt(p['price']), ''));
    gToast(context, 'Pack ajouté au panier');
  }

  Future<void> _review(String shopId) async {
    if (!await requireLogin(context, ref, 'noter cette boutique')) return;
    if (!mounted) return;
    final comment = TextEditingController();
    var rating = 5;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
            title: const Text('Votre avis sur la boutique'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 1; i <= 5; i++) IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), tooltip: '$i étoile${i > 1 ? 's' : ''}', icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF5A524)), onPressed: () => set(() => rating = i))]),
              TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(hintText: 'Commentaire (facultatif)', border: OutlineInputBorder())),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer'))],
          )),
    );
    if (ok != true) return;
    final r = await marcheCall('submit_shop_review', {'p_shop': shopId, 'p_rating': rating, 'p_comment': comment.text});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Merci pour votre avis.');
    ref.invalidate(marcheShopProvider(widget.slug));
  }

  Future<void> _report(String shopId) async {
    if (!await requireLogin(context, ref, 'signaler cette boutique')) return;
    final r = await marcheCall('report_shop', {'p_shop': shopId, 'p_reason': 'other'});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Signalement transmis à la modération.');
  }
}

// ------------------------------------------------------------------ ventes flash

class FlashSalesScreen extends ConsumerWidget {
  const FlashSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Ventes flash',
        child: mAsync<List<Map<String, dynamic>>>(ref.watch(marcheFlashProvider), (l) {
          if (l.isEmpty) return mNote('Aucune vente flash en cours. Revenez bientôt.');
          return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            for (final f in l)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 130, child: MarcheProductTile(card: Map<String, dynamic>.from(f['listing'] as Map))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f['live'] == true ? 'En cours' : 'Bientôt', style: mst(12, w: FontWeight.w700, c: f['live'] == true ? kRed : kGrey)),
                      const SizedBox(height: 4),
                      Countdown(end: DateTime.parse('${f[f['live'] == true ? 'ends_at' : 'starts_at']}'), prefix: f['live'] == true ? 'Fin dans ' : 'Début dans '),
                      const SizedBox(height: 10),
                      Text('${mInt(f['stock']) - mInt(f['sold'])} restant${mInt(f['stock']) - mInt(f['sold']) > 1 ? 's' : ''} sur ${mInt(f['stock'])}', style: mst(12.5, c: kGrey)),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 7, value: mInt(f['stock']) == 0 ? 0 : mInt(f['sold']) / mInt(f['stock']), backgroundColor: const Color(0xFFF2EFF6), color: kRed)),
                    ]),
                  ),
                ]),
              ),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ fiche produit

class ProductPageScreen extends ConsumerWidget {
  const ProductPageScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Produit',
        child: mAsync<Map<String, dynamic>>(ref.watch(marcheProductProvider(id)), (d) => d['found'] != true ? mNote('Ce produit n’est plus disponible.') : _ProductBody(d: d, id: id)),
      );
}

class _ProductBody extends ConsumerStatefulWidget {
  const _ProductBody({required this.d, required this.id});
  final Map<String, dynamic> d;
  final String id;

  @override
  ConsumerState<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends ConsumerState<_ProductBody> {
  final _chosen = <String, String>{};
  final _question = TextEditingController();
  bool _recorded = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  void _reload() => ref.invalidate(marcheProductProvider(widget.id));

  Future<void> _alert(String kind, bool on) async {
    if (!await requireLogin(context, ref, 'créer une alerte')) return;
    final r = await marcheCall('set_price_alert', {'p_listing': widget.id, 'p_kind': kind, 'p_on': on});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (on ? 'Alerte activée : vous serez prévenu.' : 'Alerte retirée.'));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final card = Map<String, dynamic>.from(d['card'] as Map);
    if (!_recorded) {
      _recorded = true;
      Future.microtask(() => marcheCall('record_view', {'p_kind': 'listing', 'p_id': widget.id}));
    }
    final images = [for (final x in (d['images'] as List? ?? const [])) mImageUrl(x)].where((e) => e.isNotEmpty).toList();
    if (images.isEmpty && '${card['image'] ?? ''}'.isNotEmpty) images.add(mImageUrl(card['image']));
    final price = mInt(card['price']);
    final before = card['price_before'] == null ? null : mInt(card['price_before']);
    final flash = card['flash_price'] == null ? null : mInt(card['flash_price']);
    final shown = flash ?? price;
    final old = flash != null ? price : before;
    final stock = mInt(card['stock']);
    final variants = _list(d['variants']);
    final specs = Map<String, dynamic>.from((d['specs'] as Map?) ?? const {});
    final alerts = [for (final a in (d['alerts'] as List? ?? const [])) '$a'];
    final isOwner = d['is_owner'] == true;
    final qs = _list(d['questions']), rs = _list(d['reviews']);
    final video = '${d['video_url'] ?? ''}';
    return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AutoCarousel(urls: images, aspect: 1)),
      if (video.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: MarcheVideo(url: mImageUrlVideo(video))),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${card['title']}', style: mst(22, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(mFcfa(shown), style: mst(22, w: FontWeight.w800, c: flash != null ? kRed : kInk)),
            if (old != null && old > shown) ...[const SizedBox(width: 10), Text(mFcfa(old), style: mst(14, c: kGrey).copyWith(decoration: TextDecoration.lineThrough))],
          ]),
          if (flash != null) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.bolt_rounded, color: kRed, size: 18), Countdown(end: DateTime.parse('${card['flash_ends']}'), prefix: 'Vente flash : fin dans '), Text(' · ${mInt(card['flash_left'])} restant(s)', style: mst(12.5, c: kGrey))])),
          const SizedBox(height: 4),
          Text(stock <= 0 ? 'Épuisé' : (stock <= 5 ? 'Plus que $stock en stock' : 'En stock'), style: mst(13, w: FontWeight.w700, c: stock <= 0 ? kRed : (stock <= 5 ? const Color(0xFFB45309) : kGreen))),
          if (card['rating_avg'] != null) Text('★ ${card['rating_avg']} · ${mInt(card['rating_count'])} avis · ${mInt(card['sales'])} vendu(s)', style: mst(12.5, c: kGrey)),
          if (d['seller'] is Map)
            SellerCard(
              seller: Map<String, dynamic>.from(d['seller'] as Map),
              supervisor: '${d['supervisor'] ?? ''}',
              validated: d['validated'] == true,
              onTap: '${d['seller_id'] ?? ''}'.isEmpty ? null : () => gOpenProfile(context, '${d['seller_id']}'),
            ),
        ]),
      ),
      if (variants.isNotEmpty) ...[
        for (final v in variants)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${v['name']}', style: mst(13, w: FontWeight.w700)),
              Wrap(spacing: 8, children: [for (final o in (v['options'] as List? ?? const [])) MChip('$o', selected: _chosen['${v['name']}'] == '$o', onTap: () => setState(() => _chosen['${v['name']}'] = '$o'))]),
            ]),
          ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(children: [
          Row(children: [
            Expanded(flex: 3, child: mButton(stock <= 0 ? 'Épuisé' : 'Ajouter au panier', stock <= 0 || isOwner ? null : () => _addToCart(card, shown, variants))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: mButton('Contacter', isOwner ? null : () => contactSeller(ref, context, '${card['title']}'), dark: false)),
          ]),
          if (offerTypeOf(card) != 'product') ...[
            const SizedBox(height: 10),
            mButton('Demander un devis', isOwner ? null : () => _askQuote(card), dark: false, icon: Icons.request_quote_outlined, width: double.infinity),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (stock <= 0) MChip(alerts.contains('stock') ? 'Alerte retour en stock activée' : 'M’alerter au retour en stock', selected: alerts.contains('stock'), onTap: () => _alert('stock', !alerts.contains('stock'))),
            MChip(alerts.contains('price') ? 'Alerte de prix activée' : 'M’alerter si le prix baisse', selected: alerts.contains('price'), onTap: () => _alert('price', !alerts.contains('price'))),
            MChip(ref.watch(marcheCompareProvider).contains(widget.id) ? 'Dans la comparaison' : 'Comparer', selected: ref.watch(marcheCompareProvider).contains(widget.id), onTap: () {
              if (!ref.read(marcheCompareProvider.notifier).toggle(widget.id)) gToast(context, 'Comparaison limitée à 4 produits.');
            }),
          ]),
        ]),
      ),
      if ('${card['shop_slug'] ?? ''}'.isNotEmpty)
        Semantics(
          button: true,
          label: 'Voir la boutique ${card['shop_name']}',
          excludeSemantics: true,
          onTap: () => context.push('/marche/boutique/${card['shop_slug']}'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/marche/boutique/${card['shop_slug']}'),
            child: Container(margin: const EdgeInsets.fromLTRB(16, 18, 16, 0), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)), child: Row(children: [const Icon(Icons.storefront_outlined), const SizedBox(width: 12), Expanded(child: Text('${card['shop_name']}', style: mst(14.5, w: FontWeight.w700))), Text('Voir la boutique', style: mst(12.5, w: FontWeight.w700, c: kViolet))])),
          ),
        ),
      if ('${d['description'] ?? ''}'.isNotEmpty) ...[mSectionTitle('Description'), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${d['description']}', style: mst(13.5, c: const Color(0xFF4A4854)).copyWith(height: 1.55)))],
      if (specs.isNotEmpty) ...[
        mSectionTitle('Caractéristiques'),
        for (final e in specs.entries) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(e.key, style: mst(13, c: kGrey))), Expanded(child: Text('${e.value}', style: mst(13, w: FontWeight.w600)))])),
      ],
      mSectionTitle('Questions et réponses (${qs.length})'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: TextField(controller: _question, decoration: const InputDecoration(hintText: 'Poser une question au vendeur', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          mButton('Envoyer', isOwner ? null : () async {
            if (!await requireLogin(context, ref, 'poser une question')) return;
            final r = await marcheCall('ask_question', {'p_listing': widget.id, 'p_question': _question.text});
            if (!mounted) return;
            if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
            _question.clear();
            gToast(context, 'Question envoyée au vendeur.');
            _reload();
          }),
        ]),
      ),
      for (final q in qs)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Q : ${q['question']}', style: mst(13, w: FontWeight.w700)),
            if ('${q['answer'] ?? ''}'.isNotEmpty) Text('R : ${q['answer']}', style: mst(13, c: kGrey)) else if (isOwner) TextButton(onPressed: () => _answer('${q['id']}'), child: const Text('Répondre')) else Text('En attente de réponse', style: mst(12, c: kGrey)),
          ]),
        ),
      mSectionTitle('Avis (${rs.length})'),
      if (rs.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucun avis pour le moment. Seuls les acheteurs peuvent noter.', style: mst(13, c: kGrey))),
      for (final r in rs) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${'★' * mInt(r['rating'])}  ${r['author']}', style: mst(13, w: FontWeight.w700)), if ('${r['comment'] ?? ''}'.isNotEmpty) Text('${r['comment']}', style: mst(13, c: kGrey))])),
    ]);
  }

  String offerTypeOf(Map<String, dynamic> card) => '${card['offer_type'] ?? 'product'}';

  /// Demande de devis adressée au vendeur d'une solution, d'un service ou d'un projet : besoin, budget facultatif, échéance facultative.
  Future<void> _askQuote(Map<String, dynamic> card) async {
    if (!await requireLogin(context, ref, 'demander un devis') || !mounted) return;
    final brief = TextEditingController(), budget = TextEditingController(), deadline = TextEditingController();
    InputDecoration deco(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Demander un devis', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${card['title']}', style: mst(13, c: kGrey)),
            const SizedBox(height: 14),
            TextField(controller: brief, maxLines: 4, decoration: deco('Votre besoin', hint: 'Décrivez ce que vous voulez, en quelques lignes')),
            const SizedBox(height: 12),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: deco('Budget (FCFA, facultatif)')),
            const SizedBox(height: 12),
            TextField(controller: deadline, decoration: deco('Échéance souhaitée (facultatif)', hint: 'Ex. fin du mois')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
              const SizedBox(width: 12),
              Expanded(child: mButton('Envoyer', () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final b = int.tryParse(budget.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final r = await marcheCall('request_quote_offer', {'p_listing': widget.id, 'p_brief': brief.text, 'p_budget': b, 'p_deadline': deadline.text});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Demande envoyée. Le vendeur vous répondra avec un devis : retrouvez-le dans « Mes devis ».');
  }

  String mImageUrlVideo(String v) => v.startsWith('http') ? v : Backend.publicUrl('listing-videos', v);

  Future<void> _answer(String qid) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: const Text('Votre réponse'), content: TextField(controller: c, maxLines: 3), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Publier'))]));
    if (ok != true) return;
    final r = await marcheCall('answer_question', {'p_id': qid, 'p_answer': c.text});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Réponse publiée.');
    _reload();
  }

  void _addToCart(Map<String, dynamic> card, int price, List<Map<String, dynamic>> variants) {
    final missing = [for (final v in variants) if (!_chosen.containsKey('${v['name']}')) '${v['name']}'];
    if (missing.isNotEmpty) return gToast(context, 'Choisissez : ${missing.join(', ')}');
    ref.read(cartProvider.notifier).add(CartLine('${card['title']}', 'Boutique : ${card['shop_name'] ?? 'Boutik-École'}', price, mImageUrl(card['image'])));
    gToast(context, 'Ajouté au panier');
  }
}

// ------------------------------------------------------------------ comparaison

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(marcheCompareProvider);
    return MarchePage(
      title: 'Comparer',
      actions: [if (ids.isNotEmpty) TextButton(onPressed: () => ref.read(marcheCompareProvider.notifier).clear(), child: const Text('Vider'))],
      child: ids.length < 2
          ? mNote('Choisissez au moins deux produits à comparer avec le bouton de comparaison de leur photo.')
          : ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(16), children: [for (final id in ids) _CompareColumn(id: id)]),
    );
  }
}

class _CompareColumn extends ConsumerWidget {
  const _CompareColumn({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        width: 190,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: mAsync<Map<String, dynamic>>(ref.watch(marcheProductProvider(id)), (d) {
            if (d['found'] != true) return mNote('Indisponible');
            final card = Map<String, dynamic>.from(d['card'] as Map);
            final specs = Map<String, dynamic>.from((d['specs'] as Map?) ?? const {});
            return SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MarcheProductTile(card: card),
                const SizedBox(height: 10),
                Text('Boutique : ${card['shop_name'] ?? 'Boutik-École'}', style: mst(12, c: kGrey)),
                Text('Stock : ${mInt(card['stock'])}', style: mst(12, c: kGrey)),
                Text(card['rating_avg'] == null ? 'Pas encore noté' : 'Note : ★ ${card['rating_avg']}', style: mst(12, c: kGrey)),
                for (final e in specs.entries) Text('${e.key} : ${e.value}', style: mst(12)),
              ]),
            );
          }),
        ),
      );
}

// ------------------------------------------------------------------ boutiques suivies

class FollowedShopsScreen extends ConsumerWidget {
  const FollowedShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Boutiques suivies',
        child: mAsync<List<Map<String, dynamic>>>(ref.watch(marcheFollowedProvider), (l) => l.isEmpty ? mNote('Vous ne suivez encore aucune boutique. Touchez « Suivre la boutique » sur une vitrine.') : ListView(padding: const EdgeInsets.only(top: 8, bottom: 90), children: [for (final s in l) _ShopRow(shop: {...s, 'products': 0, 'followers': 0})])),
      );
}

// ------------------------------------------------------------------ panier par boutique

class CartByShopScreen extends ConsumerStatefulWidget {
  const CartByShopScreen({super.key});

  @override
  ConsumerState<CartByShopScreen> createState() => _CartByShopScreenState();
}

class _CartByShopScreenState extends ConsumerState<CartByShopScreen> {
  final _code = TextEditingController();
  Map<String, dynamic>? _preview;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final lines = ref.read(cartProvider);
    final r = await marcheCall('promo_preview', {'p_code': _code.text, 'p_items': [for (final l in lines) {'title': l.title, 'qty': l.qty}]});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    final m = Map<String, dynamic>.from(r.data as Map);
    setState(() => _preview = m);
    ref.read(promoCodeProvider.notifier).set(m['valid'] == true ? _code.text : '');
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final groups = <String, List<CartLine>>{};
    for (final l in lines) {
      final shop = l.department.startsWith('Boutique : ') ? l.department.substring(11) : 'Boutik-École';
      (groups[shop] ??= []).add(l);
    }
    final sub = lines.fold<int>(0, (a, l) => a + l.price * l.qty);
    final auto = ref.watch(marcheAutoPromoProvider).value;
    final autoDisc = ref.watch(promoDiscountProvider).value ?? 0;
    final disc = auto != null ? autoDisc : (_preview?['valid'] == true ? mInt(_preview!['discount']) : 0);
    return MarchePage(
      title: 'Panier par boutique',
      child: lines.isEmpty
          ? mNote('Votre panier est vide.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
              Text('Chaque boutique prépare sa propre commande : vous suivez et pouvez noter chaque vendeur séparément. Un seul paiement couvre le tout.', style: mst(12.5, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 12),
              for (final e in groups.entries)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Commande ${e.key}', style: mst(14.5, w: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (final l in e.value) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text('${l.qty} × ${l.title}', style: mst(13))), Text(mFcfa(l.price * l.qty), style: mst(13, w: FontWeight.w600))])),
                    const Divider(),
                    Row(children: [Expanded(child: Text('Sous-total', style: mst(12.5, c: kGrey))), Text(mFcfa(e.value.fold<int>(0, (a, l) => a + l.price * l.qty)), style: mst(13, w: FontWeight.w800))]),
                  ]),
                ),
              if (auto != null) ...[
                // promotion créée par l'administrateur : le code est appliqué d'office, le champ est verrouillé
                TextFormField(
                  key: ValueKey('auto-${auto['code']}'),
                  initialValue: '${auto['code']}',
                  readOnly: true,
                  decoration: InputDecoration(labelText: 'Code promo', suffixIcon: const Icon(Icons.lock_outline, size: 18), border: const OutlineInputBorder(), filled: true, fillColor: const Color(0xFFF2EFF6)),
                ),
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('Promotion « ${auto['label'] ?? auto['code']} » appliquée automatiquement : ${promoValueLabel(auto)}${autoDisc > 0 ? ' (−${mFcfa(autoDisc)})' : ''}', style: mst(12.5, w: FontWeight.w600, c: kGreen))),
              ] else ...[
                Row(children: [
                  Expanded(child: TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Code promo', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  mButton('Appliquer', _check, dark: false),
                ]),
              ],
              if (auto == null && _preview != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_preview!['valid'] == true ? 'Code accepté : −${mFcfa(disc)}' : '${_preview!['message']}', style: mst(12.5, w: FontWeight.w600, c: _preview!['valid'] == true ? kGreen : kRed))),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: Text('Total articles', style: mst(14, w: FontWeight.w700))), Text(mFcfa(sub - disc), style: mst(16, w: FontWeight.w800))]),
              const SizedBox(height: 14),
              mButton('Passer la commande', () => context.push('/s/07')),
            ]),
    );
  }
}
