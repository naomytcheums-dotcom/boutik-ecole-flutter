import 'package:flutter/material.dart' hide Text;
import '../../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../gen.dart' show gAlert, gToast;
import '../auth.dart';
import '../backend.dart';
import '../seller.dart' show serverSellerOrdersProvider;
import 'marche_data.dart';
import 'marche_vendeur.dart' show advancedStatsProvider;
import 'marche_widgets.dart';

/// Multi-boutiques : « Mes boutiques » (liste, création, bascule de la boutique active, vue globale), équipe d'une boutique et espace d'un membre.
/// Tout vient du serveur (my_shops, my_shops_overview, shop_set_active, shop_set_enabled, shop_member_*, seller_orders / seller_overview / shop_listings avec p_shop) ;
/// aucun chiffre n'est calculé ici et aucun succès n'est affiché sans la réponse du serveur.

Future<Map<String, dynamic>> _callMap(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}

Future<List<Map<String, dynamic>>> _callList(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

/// Boutiques du compte (propriétaire ou membre) avec compteurs réels.
final myShopsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callList('my_shops', const {});
}, retry: (_, _) => null);

/// Vue globale du propriétaire : limite, droit de créer (avec le motif d'un refus) et totaux de SES boutiques.
final myShopsOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callMap('my_shops_overview', const {});
}, retry: (_, _) => null);

final shopMembersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, shopId) => _callList('shop_members_list', {'p_shop': shopId}), retry: (_, _) => null);

/// Fiche complète d'une boutique précise (lecture protégée : propriétaire et membres seulement pour une boutique non publiée).
final shopByIdProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await Backend.rows('shops', 'id,slug,name,description,logo_url,banner_url,categories,city,delivery_info,terms,socials,color_primary,color_secondary,status,review_note,owner_id', eq: {'id': id}, limit: 1);
  if (r.error != null) throw MarcheException(r.error);
  if (r.rows.isEmpty) throw MarcheException('Boutique introuvable');
  return r.rows.first;
}, retry: (_, _) => null);

final _memberOrdersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, shopId) => _callList('seller_orders', {'p_shop': shopId}), retry: (_, _) => null);
final _memberStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, shopId) => _callMap('seller_overview', {'p_days': 30, 'p_shop': shopId}), retry: (_, _) => null);
final shopListingsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, shopId) => _callMap('shop_listings', {'p_shop': shopId}), retry: (_, _) => null);

/// Après un changement de boutique active (ou d'identité) : tout ce qui dépend de la boutique est relu auprès du serveur.
void refreshAfterShopChange(WidgetRef ref) {
  ref.invalidate(myShopsProvider);
  ref.invalidate(myShopsOverviewProvider);
  ref.invalidate(marcheMyShopProvider);
  ref.invalidate(marchePromotionsProvider);
  ref.invalidate(marcheDashboardProvider);
  ref.invalidate(advancedStatsProvider);
  ref.invalidate(shopByIdProvider);
  ref.invalidate(serverSellerOrdersProvider);
}

const shopRoleLabels = {'owner': 'Propriétaire', 'manager': 'Gestionnaire', 'staff': 'Préparateur', 'viewer': 'Lecteur'};
const _roleHelp = {
  'viewer': 'Lecteur : consulte commandes, stock et statistiques.',
  'staff': 'Préparateur : lecteur + fait avancer la préparation des commandes de la boutique.',
  'manager': 'Gestionnaire : préparateur + promotions, produits mis en avant et identité de la boutique.',
};

Widget _tile(String l, String v) => Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: mst(17, w: FontWeight.w800)), Text(l, style: mst(11.5, c: kGrey))]),
    );

Future<bool> _confirm(BuildContext context, String title, String body, String ok) async =>
    await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok))])) == true;

// ------------------------------------------------------------------ Mes boutiques

class MyShopsScreen extends ConsumerWidget {
  const MyShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Mes boutiques',
        child: ref.watch(authProvider.select((a) => a.current == null)) && Backend.ready
            ? mNote('Connectez-vous pour gérer vos boutiques.')
            : mAsync<Map<String, dynamic>>(ref.watch(myShopsOverviewProvider), (ov) => mAsync<List<Map<String, dynamic>>>(ref.watch(myShopsProvider), (shops) => _MyShopsBody(ov: ov, shops: shops))),
      );
}

class _MyShopsBody extends ConsumerWidget {
  const _MyShopsBody({required this.ov, required this.shops});
  final Map<String, dynamic> ov;
  final List<Map<String, dynamic>> shops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = (ov['totals'] as Map?) ?? const {};
    final owned = [for (final s in shops) if (s['role'] == 'owner') s];
    final member = [for (final s in shops) if (s['role'] != 'owner') s];
    final canCreate = ov['can_create'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
      if (owned.isNotEmpty) ...[
        Text('Vue globale de vos boutiques (30 derniers jours)', style: mst(16, w: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _tile('Boutiques', '${mInt(t['shops'])}'),
          _tile('Ventes brutes', mFcfa(t['revenue_30d'])),
          _tile('Commandes payées', '${mInt(t['orders_30d'])}'),
          _tile('À préparer', '${mInt(t['pending_orders'])}'),
          _tile('Produits publiés', '${mInt(t['listings_approved'])}'),
          _tile('Stock (unités)', '${mInt(t['stock_units'])}'),
          _tile('Abonnés', '${mInt(t['followers'])}'),
        ]),
        const SizedBox(height: 6),
        Text('Chaque boutique garde ses propres commandes, statistiques et stocks : ces totaux ne servent qu’à la vue d’ensemble.', style: mst(11.5, c: kGrey).copyWith(height: 1.4)),
      ],
      const SizedBox(height: 16),
      if (canCreate)
        mButton('Créer une nouvelle boutique', () => context.push('/marche/ma-boutique?nouvelle=1'), icon: Icons.add_business_outlined)
      else
        Text('${ov['create_blocked_reason'] ?? 'Création impossible pour le moment.'}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('${mInt(ov['owned'])} boutique(s) ouverte(s) sur ${mInt(ov['max'])} autorisée(s) par compte (les boutiques fermées ne comptent pas).', style: mst(11.5, c: kGrey))),
      mSectionTitle('Mes boutiques'),
      if (owned.isEmpty) mNote('Vous n’avez pas encore de boutique.') else for (final s in owned) _ShopCard(shop: s),
      if (member.isNotEmpty) ...[mSectionTitle('Boutiques où je fais partie de l’équipe'), for (final s in member) _ShopCard(shop: s)],
    ]);
  }
}

class _ShopCard extends ConsumerStatefulWidget {
  const _ShopCard({required this.shop});
  final Map<String, dynamic> shop;

  @override
  ConsumerState<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends ConsumerState<_ShopCard> {
  bool _busy = false;

  Map<String, dynamic> get s => widget.shop;
  String get id => '${s['id']}';
  String get role => '${s['role']}';
  bool get owner => role == 'owner';

  Future<void> _run(String fn, Map<String, dynamic> p, String okMsg) async {
    setState(() => _busy = true);
    final r = await marcheCall(fn, p);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, 'Action non enregistrée', Backend.userMessage('${r.error}'));
      return;
    }
    gToast(context, okMsg);
    refreshAfterShopChange(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l = (s['listings'] as Map?) ?? const {};
    final active = s['is_active'] == true;
    final status = '${s['status']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? kGreen : kLine, width: active ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 48, height: 48, child: MImage('${s['logo_url'] ?? ''}'))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['name']}', style: mst(15, w: FontWeight.w800)),
            Text('${shopStatusLabels[status] ?? status} · ${shopRoleLabels[role] ?? role}', style: mst(12, c: kGrey)),
          ])),
          if (active) Text('Boutique active', style: mst(12, w: FontWeight.w800, c: kGreen)),
        ]),
        const SizedBox(height: 10),
        Text(
          'Produits publiés ${mInt(l['approved'])} · en validation ${mInt(l['pending'])} · brouillons ${mInt(l['draft'])}\n'
          'Stock ${mInt(s['stock_units'])} unité(s), ${mInt(s['out_of_stock'])} en rupture\n'
          'À préparer ${mInt(s['pending_orders'])} · commandes 30 j ${mInt(s['orders_30d'])} · ventes 30 j ${mFcfa(s['revenue_30d'])}\n'
          'Abonnés ${mInt(s['followers'])} · promotions actives ${mInt(s['active_promos'])}${owner ? ' · membres ${mInt(s['members'])}' : ''}',
          style: mst(12.5, c: kGrey).copyWith(height: 1.5),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (!active) mButton('Utiliser cette boutique', _busy ? null : () => _run('shop_set_active', {'p_shop': id}, 'Boutique active : ${s['name']}.'), busy: _busy, dark: false),
          if (owner) mButton('Espace vendeur', () async {
            if (!active) {
              final r = await marcheCall('shop_set_active', {'p_shop': id});
              if (!context.mounted) return;
              if (r.error != null) return gAlert(context, 'Boutique non activée', Backend.userMessage('${r.error}'));
              refreshAfterShopChange(ref);
            }
            if (context.mounted) context.push('/marche/vendeur');
          }, dark: false)
          else
            mButton('Commandes, stock et statistiques', () => context.push('/marche/mes-boutiques/$id/espace'), dark: false),
          if (owner || role == 'manager') mButton('Identité et réglages', () => context.push('/marche/ma-boutique?id=$id'), dark: false),
          if (owner) mButton('Équipe', () => context.push('/marche/mes-boutiques/$id/equipe'), dark: false),
          if (owner && status == 'active')
            mButton('Désactiver', _busy ? null : () async {
              if (await _confirm(context, 'Désactiver cette boutique ?', 'Elle disparaît de la vitrine et ne reçoit plus de commande ; les commandes en cours se poursuivent. Vos autres boutiques ne changent pas.', 'Désactiver')) {
                await _run('shop_set_enabled', {'p_shop': id, 'p_enabled': false}, 'Boutique désactivée.');
              }
            }, dark: false),
          if (owner && status == 'paused') mButton('Réactiver', _busy ? null : () => _run('shop_set_enabled', {'p_shop': id, 'p_enabled': true}, 'Boutique réactivée.'), dark: false),
          if (!owner)
            mButton('Quitter l’équipe', _busy ? null : () async {
              final me = ref.read(authProvider).current?.serverId ?? '';
              if (await _confirm(context, 'Quitter l’équipe ?', 'Vous n’aurez plus accès aux données de cette boutique.', 'Quitter')) {
                await _run('shop_member_remove', {'p_shop': id, 'p_user': me}, 'Vous avez quitté l’équipe.');
              }
            }, dark: false),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ boutique affichée dans l'espace vendeur

/// Rappelle quelle boutique est affichée dans les onglets de l'espace vendeur et permet d'en changer sans quitter l'écran (le serveur mémorise le choix).
class ActiveShopBar extends ConsumerWidget {
  const ActiveShopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready) return const SizedBox.shrink();
    return ref.watch(myShopsProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('Boutique affichée inconnue : ${e is MarcheException ? e.toString() : marcheErrorText('$e')}', style: mst(12, c: kRed))),
          data: (shops) {
            if (shops.isEmpty) return const SizedBox.shrink();
            final active = shops.firstWhere((s) => s['is_active'] == true, orElse: () => shops.first);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                Expanded(
                  child: shops.length < 2
                      ? Text('Boutique : ${active['name']}', style: mst(13, w: FontWeight.w700))
                      : MDropdown(
                          label: 'Boutique affichée',
                          value: '${active['id']}',
                          items: {for (final s in shops) '${s['id']}': '${s['name']}'},
                          onChanged: (v) async {
                            final r = await marcheCall('shop_set_active', {'p_shop': v});
                            if (!context.mounted) return;
                            if (r.error != null) {
                              gToast(context, Backend.userMessage('${r.error}'));
                              return;
                            }
                            refreshAfterShopChange(ref);
                          },
                        ),
                ),
                TextButton(onPressed: () => context.push('/marche/mes-boutiques'), child: const Text('Mes boutiques')),
              ]),
            );
          },
        );
  }
}

/// Produits et stock d'une boutique en lecture (équipe sans droit de gestion des annonces).
class ShopListingsReadOnly extends ConsumerWidget {
  const ShopListingsReadOnly({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => mAsync<Map<String, dynamic>>(ref.watch(shopListingsProvider(shopId)), (d) {
        final l = [for (final x in (d['listings'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        if (l.isEmpty) return mNote('Cette boutique n’a pas encore de produit.');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          Text('Lecture seule : seul le propriétaire modifie les annonces.', style: mst(12, c: kGrey)),
          const SizedBox(height: 8),
          for (final p in l)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 56, height: 56, child: MImage(mImageUrl(p['image'])))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w700)),
                  Text('${mFcfa(p['price'])} · stock ${mInt(p['stock'])} · ${p['status']}${mInt(p['variants']) > 0 ? ' · ${mInt(p['variants'])} variante(s)' : ''}', style: mst(12, c: kGrey)),
                ])),
              ]),
            ),
        ]);
      });
}

// ------------------------------------------------------------------ équipe de la boutique (propriétaire)

class ShopMembersScreen extends ConsumerStatefulWidget {
  const ShopMembersScreen({super.key, required this.shopId});
  final String shopId;

  @override
  ConsumerState<ShopMembersScreen> createState() => _ShopMembersScreenState();
}

class _ShopMembersScreenState extends ConsumerState<ShopMembersScreen> {
  final email = TextEditingController();
  String role = 'viewer';
  bool _busy = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!email.text.contains('@')) return gToast(context, 'Saisissez l’adresse e-mail du compte à ajouter.');
    setState(() => _busy = true);
    final r = await marcheCall('shop_member_set', {'p_shop': widget.shopId, 'p_role': role, 'p_email': email.text.trim()});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Membre non ajouté', Backend.userMessage('${r.error}'));
    email.clear();
    gToast(context, 'Membre ajouté : il est prévenu par notification.');
    ref.invalidate(shopMembersProvider(widget.shopId));
    ref.invalidate(myShopsProvider);
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    if (!await _confirm(context, 'Retirer ce membre ?', '${m['name']} n’aura plus accès à cette boutique.', 'Retirer')) return;
    final r = await marcheCall('shop_member_remove', {'p_shop': widget.shopId, 'p_user': m['user_id']});
    if (!mounted) return;
    if (r.error != null) return gAlert(context, 'Membre non retiré', Backend.userMessage('${r.error}'));
    gToast(context, 'Membre retiré.');
    ref.invalidate(shopMembersProvider(widget.shopId));
    ref.invalidate(myShopsProvider);
  }

  Future<void> _changeRole(Map<String, dynamic> m, String v) async {
    final r = await marcheCall('shop_member_set', {'p_shop': widget.shopId, 'p_user': m['user_id'], 'p_role': v});
    if (!mounted) return;
    if (r.error != null) return gAlert(context, 'Rôle non modifié', Backend.userMessage('${r.error}'));
    gToast(context, 'Rôle mis à jour.');
    ref.invalidate(shopMembersProvider(widget.shopId));
  }

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Équipe de la boutique',
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
          Text('Seul le propriétaire gère l’équipe. Un membre ne dépasse jamais son rôle ; il ne voit que les données de cette boutique.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 12),
          for (final e in _roleHelp.values) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e', style: mst(12, c: kGrey))),
          mSectionTitle('Ajouter un membre'),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Adresse e-mail du compte', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          MDropdown(label: 'Rôle', value: role, items: {for (final e in shopRoleLabels.entries) if (e.key != 'owner') e.key: e.value}, onChanged: (v) => setState(() => role = v)),
          const SizedBox(height: 10),
          mButton('Ajouter à l’équipe', _busy ? null : _add, busy: _busy),
          mSectionTitle('Membres'),
          mAsyncList(ref.watch(shopMembersProvider(widget.shopId))),
        ]),
      );

  Widget mAsyncList(AsyncValue<List<Map<String, dynamic>>> v) => v.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => mNote(e is MarcheException ? e.toString() : marcheErrorText('$e')),
        data: (l) => l.isEmpty
            ? mNote('Aucun membre pour le moment.')
            : Column(children: [
                for (final m in l)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                    child: Row(children: [
                      Expanded(child: Text('${m['name']}', style: mst(13.5, w: FontWeight.w700))),
                      SizedBox(width: 150, child: MDropdown(label: 'Rôle de ${m['name']}', value: '${m['role']}', items: {for (final e in shopRoleLabels.entries) if (e.key != 'owner') e.key: e.value}, onChanged: (v) => _changeRole(m, v))),
                      IconButton(tooltip: 'Retirer', onPressed: () => _remove(m), icon: const Icon(Icons.person_remove_outlined)),
                    ]),
                  ),
              ]),
      );
}

// ------------------------------------------------------------------ espace d'un membre (commandes, stock, statistiques de SA boutique)

class ShopMemberSpaceScreen extends ConsumerWidget {
  const ShopMemberSpaceScreen({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = [for (final s in (ref.watch(myShopsProvider).value ?? const <Map<String, dynamic>>[])) if ('${s['id']}' == shopId) '${s['role']}'].firstOrNull ?? '';
    final canPrepare = role == 'owner' || role == 'manager' || role == 'staff';
    return DefaultTabController(
      length: 3,
      child: MarchePage(
        title: 'Boutique · ${shopRoleLabels[role] ?? 'membre'}',
        child: Column(children: [
          const TabBar(isScrollable: true, labelColor: kInk, indicatorColor: kInk, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Commandes'), Tab(text: 'Produits et stock'), Tab(text: 'Statistiques')]),
          Expanded(
            child: TabBarView(children: [
              _MemberOrders(shopId: shopId, canPrepare: canPrepare),
              ShopListingsReadOnly(shopId: shopId),
              mAsync<Map<String, dynamic>>(ref.watch(_memberStatsProvider(shopId)), (d) => ListView(padding: const EdgeInsets.all(16), children: [
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _tile('Ventes brutes (30 j)', mFcfa(d['revenue'])),
                      _tile('Commandes payées', '${mInt(d['orders'])}'),
                      _tile('Unités vendues', '${mInt(d['units'])}'),
                      _tile('À préparer', '${mInt(d['pending_orders'])}'),
                      _tile('Vues produits', '${mInt(d['views'])}'),
                    ]),
                    const SizedBox(height: 10),
                    Text('Statistiques de cette boutique uniquement.', style: mst(12, c: kGrey)),
                  ])),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MemberOrders extends ConsumerWidget {
  const _MemberOrders({required this.shopId, required this.canPrepare});
  final String shopId;
  final bool canPrepare;

  static const _labels = kSellerOrderSteps;

  @override
  Widget build(BuildContext context, WidgetRef ref) => mAsync<List<Map<String, dynamic>>>(ref.watch(_memberOrdersProvider(shopId)), (orders) {
        if (orders.isEmpty) return mNote('Aucune commande payée à préparer pour cette boutique.');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          for (final o in orders)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('${o['number']}', style: mst(14, w: FontWeight.w800))), Text(mFcfa(o['total']), style: mst(14, w: FontWeight.w800))]),
                Text('${o['title']} · ${o['buyer_name']}', style: mst(12.5, c: kGrey)),
                Text('État : ${_labels[mInt(o['status']).clamp(0, 4)]}', style: mst(12.5, w: FontWeight.w700)),
                if (canPrepare && mInt(o['status']) < 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: mButton('Marquer : ${_labels[mInt(o['status']) + 1]}', () async {
                      final r = await marcheCall('set_seller_order_status', {'p_order': o['number'], 'p_status': mInt(o['status']) + 1, 'p_shop': shopId});
                      if (!context.mounted) return;
                      if (r.error != null) {
                        await gAlert(context, 'Statut non enregistré', Backend.userMessage('${r.error}'));
                      } else {
                        gToast(context, 'Commande mise à jour, l’acheteur est prévenu.');
                      }
                      ref.invalidate(_memberOrdersProvider(shopId));
                    }, dark: false),
                  ),
              ]),
            ),
        ]);
      });
}
