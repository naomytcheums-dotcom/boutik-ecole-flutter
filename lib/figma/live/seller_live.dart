import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart';
import 'seller_edit.dart';
import 'store.dart';

/// Espace vendeur alimenté par le serveur : aperçu chiffré (tableau de bord 57, studio D1), catalogue (61), stocks (62).
/// Aucun chiffre n'est inventé : tant que la lecture n'a pas abouti, « … » ; en cas d'échec, « — ».

const _ink = Color(0xFF111015);
const _mute = Color(0xFF57545F);
const _line = Color(0xFFECE8F2);

TextStyle _t(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

// ------------------------------------------------------------------ données

/// Aperçu du vendeur sur 30 jours (RPC seller_overview) : ventes payées, commandes, avis, annonces par statut, 6 derniers mois, produits.
final sellerOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await Backend.rpc('seller_overview', const {'p_days': 30});
  if (r.error != null || r.data is! Map) throw StateError(r.error ?? 'seller_overview');
  return Map<String, dynamic>.from(r.data as Map);
}, retry: (_, _) => null);

/// Boutique du vendeur (statut) : les annonces d'une boutique non active ne sont pas visibles du public.
final sellerShopProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await Backend.rpc('my_shop', const {});
  return r.error == null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}, retry: (_, _) => null);

/// Réglages d'alerte de stock (RPC seller_settings_get / seller_settings_set).
final sellerSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await Backend.rpc('seller_settings_get', const {});
  if (r.error != null || r.data is! Map) throw StateError(r.error ?? 'seller_settings_get');
  final m = Map<String, dynamic>.from(r.data as Map);
  Listing.lowStock = (m['stock_threshold'] as num?)?.toInt() ?? Listing.lowStock;
  return m;
}, retry: (_, _) => null);

/// Texte d'une valeur de l'aperçu : « … » pendant la lecture, « — » si elle a échoué.
class OverviewText extends ConsumerWidget {
  const OverviewText(this.pick, {super.key, this.size = 20, this.color = _ink, this.weight = FontWeight.w800});
  final String Function(Map<String, dynamic> ov, List<Listing> listings) pick;
  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ov = ref.watch(sellerOverviewProvider);
    final text = ov.when(data: (d) => pick(d, ref.watch(listingsProvider)), loading: () => '…', error: (_, _) => '—');
    return Align(alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(size, weight, color)));
  }
}

int _n(Object? v) => (v as num?)?.toInt() ?? 0;

const _months = ['Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];

/// Ventes payées des six derniers mois (histogramme réel).
class SellerMonthsChart extends ConsumerWidget {
  const SellerMonthsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(sellerOverviewProvider).when(
      loading: () => const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Statistiques indisponibles pour le moment.', textAlign: TextAlign.center, style: _t(12.5, FontWeight.w500, _mute)), _retryButton('Réessayer', () => refreshSellerData(ref))]),
      data: (d) {
        final months = [for (final m in (d['months'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
        final mx = months.fold<int>(0, (a, m) => _n(m['revenue']) > a ? _n(m['revenue']) : a);
        if (months.isEmpty || mx == 0) return Center(child: Text('Aucune vente payée sur les 6 derniers mois.', textAlign: TextAlign.center, style: _t(12.5, FontWeight.w500, _mute)));
        return Semantics(
          label: 'Ventes mensuelles, maximum ${fcfa(mx)}',
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final m in months)
              Expanded(
                child: Tooltip(
                  message: '${m['month']} : ${fcfa(_n(m['revenue']))}',
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Expanded(child: Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(heightFactor: _n(m['revenue']) == 0 ? 0.02 : _n(m['revenue']) / mx, widthFactor: 0.6, child: Container(decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(6)))))),
                    const SizedBox(height: 6),
                    Text(_months[(int.tryParse('${m['month']}'.substring(5, 7)) ?? 1).clamp(1, 12) - 1], style: _t(10.5, FontWeight.w500, _mute)),
                  ]),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ 61 « Mon catalogue »

/// Message d'état de la boutique pour les annonces (null si rien à signaler).
String? shopVisibilityNote(Map<String, dynamic> shop, List<Listing> ls) {
  final st = '${shop['status'] ?? ''}';
  if (shop['id'] == null || st == 'active') return null;
  if (!ls.any((l) => l.published)) return null;
  return 'Votre boutique n’est pas active (${const {'draft': 'brouillon', 'pending': 'en validation', 'suspended': 'suspendue', 'closed': 'fermée'}[st] ?? st}) : vos annonces publiées ne sont visibles que de vous tant qu’elle n’est pas validée.';
}

String listingSubtitle(Listing l) {
  final price = l.price == 0 ? 'Sur devis' : fcfa(l.price);
  if (!l.published) return '$price · ${l.label}';
  return l.category == 'Services' ? price : '$price · ${l.stock} en stock';
}

/// Relit l'aperçu, la boutique et les annonces du vendeur (tirer pour actualiser, bouton « Réessayer »).
Future<void> refreshSellerData(WidgetRef ref) async {
  ref.invalidate(sellerOverviewProvider);
  ref.invalidate(sellerShopProvider);
  await ref.read(listingsProvider.notifier).refresh();
}

/// Bouton d'action d'un état vide ou d'erreur (zone tactile d'au moins 48 dp).
Widget _retryButton(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48, minWidth: 48), child: OutlinedButton(onPressed: onTap, child: Text(label, style: _t(13, FontWeight.w600, _ink))))),
    );

/// État de la lecture des annonces : spinner à la première lecture, message + « Réessayer » si elle échoue sans rien à montrer, bandeau sinon ; null si tout va bien.
Widget? listingsStatusView(WidgetRef ref, {required bool hasRows}) {
  final load = ref.watch(listingsLoadProvider);
  if (load == '' && !hasRows) return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
  if (load == 'error' && !hasRows) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Impossible de lire vos annonces pour le moment.\nVérifiez votre connexion.', textAlign: TextAlign.center, style: _t(13.5, FontWeight.w500, _mute).copyWith(height: 1.5)),
      _retryButton('Réessayer', () => refreshSellerData(ref)),
    ]);
  }
  return null;
}

/// Liste défilante des annonces du vendeur (toutes, avec photo, statut lisible et motif de refus complet).
class SellerCatalogList extends ConsumerWidget {
  const SellerCatalogList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(listingsProvider);
    final rows = ref.watch(visibleListingsProvider);
    final note = shopVisibilityNote(ref.watch(sellerShopProvider).value ?? const {}, all);
    final status = listingsStatusView(ref, hasRows: all.isNotEmpty);
    if (status != null) return status;
    if (all.isEmpty) return Center(child: Text('Aucune annonce pour le moment.\nTouchez + pour créer votre premier produit.', textAlign: TextAlign.center, style: _t(13.5, FontWeight.w500, _mute).copyWith(height: 1.5)));
    return RefreshIndicator(
      onRefresh: () => refreshSellerData(ref),
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 120), children: [
      if (ref.watch(listingsLoadProvider) == 'error') Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFDE6E7), borderRadius: BorderRadius.circular(14)), child: Text('Actualisation impossible : la liste affichée peut ne plus être à jour. Tirez vers le bas pour réessayer.', style: _t(12, FontWeight.w500, _ink).copyWith(height: 1.4))),
      if (note != null) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(14)), child: Text(note, style: _t(12, FontWeight.w500, _ink).copyWith(height: 1.4))),
      if (rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 30), child: Center(child: Text('Aucune annonce dans cette liste.', style: _t(13.5, FontWeight.w500, _mute)))),
      for (final l in rows)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openListing(ref, context, l),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 50, height: 50, child: l.images.isEmpty ? Container(color: const Color(0xFFEDE9F6), child: const Icon(Icons.image_outlined, size: 20, color: _mute)) : gNetImage(Backend.listingImageUrl(l.images.first), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEDE9F6)))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(13.5, FontWeight.w600, _ink)),
                  const SizedBox(height: 2),
                  Text(listingSubtitle(l), style: _t(11.5, FontWeight.w400, _mute)),
                  if (l.rejected && l.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Motif du refus : ${l.note}', style: _t(11.5, FontWeight.w600, const Color(0xFFD64545)).copyWith(height: 1.35))),
                ]),
              ),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: listingPillFill(l.label), borderRadius: BorderRadius.circular(11)), child: Text(l.label, style: _t(11, FontWeight.w600, listingPillInk(l.label)))),
            ]),
          ),
        ),
    ]));
  }
}

/// Ouvre l'annonce choisie (identifiant, jamais le titre) sur l'écran 60.
void openListing(WidgetRef ref, BuildContext context, Listing l) {
  ref.read(selectedListingProvider.notifier).set(l.key);
  gOpen(context, '60');
}

// ------------------------------------------------------------------ 62 « Stocks »

/// Boîte de réglage du stock : valeur exacte ou ajout rapide ; le résultat n'est annoncé qu'après la réponse du serveur.
Future<void> adjustStockDialog(BuildContext context, WidgetRef ref, Listing l) async {
  final c = TextEditingController(text: '${l.stock}');
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      void add(int n) => set(() => c.text = '${((int.tryParse(c.text.trim()) ?? l.stock) + n).clamp(0, 100000)}');
      Future<void> save() async {
        final v = int.tryParse(c.text.trim());
        if (v == null || v < 0 || v > 100000) return set(() => error = 'Entrez un nombre entier de 0 à 100 000.');
        set(() {
          busy = true;
          error = null;
        });
        final err = await Backend.updateListingStock(l.id, v);
        if (err != null) return set(() {
              busy = false;
              error = Backend.userMessage(err);
            });
        await ref.read(listingsProvider.notifier).refresh();
        if (ctx.mounted) Navigator.of(ctx).pop();
        if (context.mounted) gToast(context, 'Stock de « ${l.title} » : $v');
      }

      const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: _ink, textBaseline: TextBaseline.alphabetic);
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Stock : ${l.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stock actuel : ${l.stock}. Saisissez le nouveau stock total, ou ajoutez des unités.', style: st.copyWith(color: _mute, fontSize: 12.5)),
          const SizedBox(height: 10),
          TextField(controller: c, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: st, decoration: InputDecoration(labelText: 'Stock total', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final n in const [1, 5, 10, 50]) ActionChip(label: Text('+$n'), onPressed: busy ? null : () => add(n))]),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: st.copyWith(color: const Color(0xFFD64545), fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
        actions: [TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(), child: Text('Annuler', style: st)), TextButton(onPressed: busy ? null : save, child: Text(busy ? 'Enregistrement…' : 'Enregistrer', style: st.copyWith(fontWeight: FontWeight.w700)))],
      );
    }),
  );
}

/// Articles dont le stock se gère (produits ; un service n'a pas de stock), les plus bas d'abord.
List<Listing> stockListings(List<Listing> all) => [
      for (final l in all)
        if (l.category != 'Services' && l.status != 'removed') l,
    ]..sort((a, b) {
        if (a.published != b.published) return a.published ? -1 : 1;
        return a.stock.compareTo(b.stock);
      });

Color _levelInk(Listing l) => !l.published ? _mute : (l.stock == 0 ? const Color(0xFFE5484D) : (l.stock <= Listing.lowStock ? const Color(0xFF8F5400) : const Color(0xFF0F7A52)));
Color _levelFill(Listing l) => !l.published ? const Color(0xFFF2EFF6) : (l.stock == 0 ? const Color(0xFFFDE6E7) : (l.stock <= Listing.lowStock ? const Color(0xFFEEE9FF) : const Color(0xFFDDF5EC)));

class SellerStockList extends ConsumerWidget {
  const SellerStockList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = stockListings(ref.watch(listingsProvider));
    final status = listingsStatusView(ref, hasRows: rows.isNotEmpty);
    if (status != null) return status;
    if (rows.isEmpty) return Center(child: Text('Aucun produit à gérer pour le moment.', style: _t(13.5, FontWeight.w500, _mute)));
    return ListView(padding: EdgeInsets.zero, children: [
      for (final l in rows)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => l.id.isEmpty ? gToast(context, 'Le stock se gère une fois connecté au serveur.') : adjustStockDialog(context, ref, l),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 44, height: 44, child: l.images.isEmpty ? Container(color: const Color(0xFFEDE9F6)) : gNetImage(Backend.listingImageUrl(l.images.first), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEDE9F6))))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(13.5, FontWeight.w600, _ink)),
                  Text(l.published ? 'Seuil : ${Listing.lowStock} · Restant : ${l.stock}' : '${l.label} · Stock : ${l.stock}', style: _t(11.5, FontWeight.w400, _mute)),
                ]),
              ),
              Container(constraints: const BoxConstraints(minWidth: 30), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), alignment: Alignment.center, decoration: BoxDecoration(color: _levelFill(l), borderRadius: BorderRadius.circular(11)), child: Text('${l.stock}', style: _t(11, FontWeight.w700, _levelInk(l)))),
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 16, color: _mute),
            ]),
          ),
        ),
    ]);
  }
}

/// Réglages réels : alerte de stock bas, alerte de rupture, seuil. Enregistrés sur le serveur, qui notifie le vendeur.
class SellerStockSettings extends ConsumerStatefulWidget {
  const SellerStockSettings({super.key});
  @override
  ConsumerState<SellerStockSettings> createState() => _SellerStockSettingsState();
}

class _SellerStockSettingsState extends ConsumerState<SellerStockSettings> {
  final threshold = TextEditingController();
  bool low = true, out = true, loaded = false, busy = false;
  String? error;

  @override
  void dispose() {
    threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = int.tryParse(threshold.text.trim());
    if (v == null || v < 0 || v > 100000) return setState(() => error = 'Seuil : un nombre entier de 0 à 100 000.');
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.rpc('seller_settings_set', {'p_threshold': v, 'p_low': low, 'p_out': out});
    if (!mounted) return;
    if (r.error != null) return setState(() {
          busy = false;
          error = Backend.userMessage(r.error!);
        });
    Listing.lowStock = v;
    ref.invalidate(sellerSettingsProvider);
    await ref.read(listingsProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => busy = false);
    gToast(context, 'Alertes de stock enregistrées.');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sellerSettingsProvider);
    if (s.hasError) return Center(child: Text('Réglages indisponibles pour le moment.', style: _t(12.5, FontWeight.w500, _mute)));
    final d = s.value;
    if (d == null) return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    if (!loaded) {
      loaded = true;
      low = d['notify_low'] != false;
      out = d['notify_out'] != false;
      threshold.text = '${_n(d['stock_threshold'])}';
    }
    Widget row(String title, String sub, bool v, ValueChanged<bool> on) => Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _t(13.5, FontWeight.w600, _ink)), Text(sub, style: _t(11.5, FontWeight.w400, _mute))])),
          Switch(value: v, onChanged: busy ? null : on),
        ]);
    return ListView(padding: EdgeInsets.zero, children: [
      row('Alerte stock bas', 'Notification quand le stock passe sous le seuil', low, (v) => setState(() => low = v)),
      row('Alerte de rupture', 'Notification quand un article tombe à 0', out, (v) => setState(() => out = v)),
      const SizedBox(height: 8),
      TextField(controller: threshold, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: _t(13.5, FontWeight.w500, _ink), decoration: InputDecoration(labelText: 'Seuil de stock bas (unités)', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: _t(12, FontWeight.w600, const Color(0xFFD64545)))),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: busy ? null : _save, style: FilledButton.styleFrom(backgroundColor: _ink, minimumSize: const Size(48, 48)), child: Text(busy ? 'Enregistrement…' : 'Enregistrer les alertes', style: _t(13, FontWeight.w600, Colors.white)))),
    ]);
  }
}

// ------------------------------------------------------------------ 60 : aperçu de la fiche telle que le client la voit

/// Ouvre la fiche publique de l'annonce courante (le propriétaire la voit même brouillon, en validation ou refusée).
void previewCurrentListing(WidgetRef ref, BuildContext context) {
  final l = ref.read(currentListingProvider);
  if (l == null) return gToast(context, 'Aucune annonce sélectionnée.');
  if (!Backend.ready || l.id.isEmpty) return gToast(context, 'L’aperçu nécessite la connexion au serveur.');
  GoRouter.of(context).push('/marche/produit/${l.id}');
}

// ------------------------------------------------------------------ fiche produit vue par son propriétaire

/// Encadré de gestion affiché au propriétaire sur la fiche publique : statut, motif de refus, accès à la modification et au stock.
class OwnerListingPanel extends ConsumerWidget {
  const OwnerListingPanel({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(listingsProvider).where((x) => x.id == listingId).firstOrNull;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l == null ? 'C’est votre annonce' : 'C’est votre annonce · ${l.label}', style: _t(14, FontWeight.w800, _ink)),
        const SizedBox(height: 4),
        Text('Voici la fiche telle que les acheteurs la voient. « Ajouter au panier » et « Contacter » sont désactivés pour vous.', style: _t(12, FontWeight.w400, _mute).copyWith(height: 1.4)),
        if (l != null && l.rejected && l.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motif du refus : ${l.note}', style: _t(12, FontWeight.w600, const Color(0xFFD64545)).copyWith(height: 1.4))),
        if (l != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton(onPressed: () => openListing(ref, context, l), style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)), child: Text('Modifier cette annonce', style: _t(12.5, FontWeight.w600, _ink))),
              if (l.category != 'Services') OutlinedButton(onPressed: () => gOpen(context, '62'), style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)), child: Text('Gérer le stock', style: _t(12.5, FontWeight.w600, _ink))),
            ]),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ D1 « Tableau de bord du studio »

/// Cartes réelles du studio : ventes, commandes, avis, annonces et produits (sur 30 jours).
class StudioOverview extends ConsumerWidget {
  const StudioOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget card(String label, String value, {String? sub}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: _t(13, FontWeight.w500, _mute)),
              const SizedBox(height: 8),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(26, FontWeight.w800, _ink)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: _t(12, FontWeight.w500, _mute))),
            ]),
          ),
        );
    return ref.watch(sellerOverviewProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('Les statistiques de votre studio sont indisponibles pour le moment.', style: _t(14, FontWeight.w500, _mute))),
      data: (d) {
        final products = [for (final p in (d['products'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
        final ls = Map<String, dynamic>.from(d['listings'] as Map? ?? const {});
        final avg = d['rating_avg'];
        return ListView(padding: EdgeInsets.zero, children: [
          Row(children: [
            card('Ventes (30 jours)', fcfa(_n(d['revenue'])), sub: '${_n(d['orders'])} commande${_n(d['orders']) > 1 ? 's' : ''} payée${_n(d['orders']) > 1 ? 's' : ''}'),
            const SizedBox(width: 14),
            card('Avis clients', avg == null ? 'Aucun avis' : '$avg / 5', sub: '${_n(d['rating_count'])} avis reçu${_n(d['rating_count']) > 1 ? 's' : ''}'),
            const SizedBox(width: 14),
            card('Annonces publiées', '${_n(ls['approved'])}', sub: '${_n(ls['pending'])} en validation · ${_n(ls['draft'])} brouillon${_n(ls['draft']) > 1 ? 's' : ''}'),
          ]),
          const SizedBox(height: 22),
          Text('Ventes mensuelles', style: _t(16, FontWeight.w700, _ink)),
          const SizedBox(height: 10),
          Container(height: 200, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)), child: const SellerMonthsChart()),
          const SizedBox(height: 22),
          Text('Performance des produits', style: _t(16, FontWeight.w700, _ink)),
          const SizedBox(height: 10),
          if (products.isEmpty) Text('Vous n’avez pas encore de produit. Créez-en un depuis « Nouveau produit ».', style: _t(13.5, FontWeight.w500, _mute)),
          for (final p in products)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
              child: Row(children: [
                Expanded(child: Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(13.5, FontWeight.w600, _ink))),
                Text('${_n(p['units'])} vendu${_n(p['units']) > 1 ? 's' : ''}', style: _t(12.5, FontWeight.w500, _mute)),
                const SizedBox(width: 14),
                Text('${const {'approved': 'Publiée', 'pending': 'En validation', 'draft': 'Brouillon', 'rejected': 'Refusée'}['${p['status']}'] ?? p['status']}', style: _t(12.5, FontWeight.w600, _ink)),
                const SizedBox(width: 14),
                Text(p['category'] == 'Services' && _n(p['price']) == 0 ? 'Sur devis' : fcfa(_n(p['price'])), style: _t(12.5, FontWeight.w700, _ink)),
              ]),
            ),
        ]);
      },
    );
  }
}
