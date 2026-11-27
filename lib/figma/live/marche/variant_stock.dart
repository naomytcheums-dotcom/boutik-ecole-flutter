import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../gen.dart' show gToast;
import '../../i18n.dart' show Text;
import '../backend.dart' show Backend;
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Stock par variante (migrations 20261127200000 et 20261127200100) : taille, couleur… chacune avec son stock et son seuil d'alerte.
/// Prix propre OPTIONNEL par variante (migration 20261128030000) : sans prix, la variante se vend au prix de l'annonce ; avec un prix, la commande utilise
/// celui de la variante (le serveur le relit, le client n'envoie jamais de prix). Image facultative par variante (compartiment public `listing-images`).
/// Tout vient du serveur ; un refus ou une panne est affiché tel quel, jamais une confirmation. Une annonce sans variante garde le stock global actuel.

/// Variante telle que la renvoie le serveur : lecture publique (état seulement, `left` quand il en reste peu) ou lecture du vendeur (stock exact).
class StockVariant {
  const StockVariant({required this.id, required this.label, required this.state, required this.active, this.attributes = const {}, this.sku, this.stock, this.threshold, this.left, this.price, this.effectivePrice, this.image, this.reserved});
  final String id, label;

  /// available | low | out
  final String state;
  final bool active;
  final Map<String, String> attributes;
  final String? sku, image;
  final int? stock, threshold, left, price, effectivePrice, reserved;

  bool get out => state == 'out';
  bool get low => state == 'low';

  static StockVariant? fromJson(Object? j) {
    if (j is! Map || j['id'] == null) return null;
    final a = j['attributes'];
    return StockVariant(
      id: '${j['id']}',
      label: '${j['label'] ?? ''}',
      state: '${j['state'] ?? 'available'}',
      active: j['active'] != false,
      attributes: a is Map ? {for (final e in a.entries) '${e.key}': '${e.value}'} : const {},
      sku: j['sku'] == null ? null : '${j['sku']}',
      stock: (j['stock'] as num?)?.toInt(),
      threshold: (j['low_threshold'] as num?)?.toInt(),
      left: (j['left'] as num?)?.toInt(),
      price: (j['price'] as num?)?.toInt(),
      effectivePrice: (j['effective_price'] as num?)?.toInt(),
      image: j['image'] == null || '${j['image']}'.isEmpty ? null : '${j['image']}',
      reserved: (j['reserved'] as num?)?.toInt(),
    );
  }

  String get attributesText => attributes.entries.map((e) => '${e.key} : ${e.value}').join(' · ');

  /// Vrai quand la variante a son propre prix (sinon : prix de l'annonce).
  bool get hasOwnPrice => price != null;
}

/// Message lisible d'un refus du serveur (les codes internes `variant_*` sont retirés).
String variantErrorText(Object? e) => marcheErrorText(e);

/// Variantes actives d'une annonce (lecture publique). Fonction serveur absente : annonce sans variante. Autre échec : erreur (jamais « aucune variante »).
final stockVariantsProvider = FutureProvider.autoDispose.family<List<StockVariant>, String>((ref, listingId) async {
  final r = await marcheCall('listing_variants_public', {'p_listing': listingId});
  if (r.error == 'missing' || r.error == 'offline') return const [];
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) ?StockVariant.fromJson(x)];
}, retry: (_, _) => null);

// ------------------------------------------------------------------ acheteur : sélecteur de variante

/// Sélecteur de variante de la fiche produit : une pastille par variante, état « épuisée » ou « plus que N ». N'affiche rien pour une annonce sans variante.
class VariantPicker extends ConsumerWidget {
  const VariantPicker({super.key, required this.listingId, required this.selectedId, required this.onSelect});
  final String listingId;
  final String? selectedId;
  final ValueChanged<StockVariant> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stockVariantsProvider(listingId));
    return v.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(child: Text('Les variantes de ce produit n’ont pas pu être chargées. Vous ne pouvez pas l’ajouter au panier pour le moment.', style: mst(12.5, w: FontWeight.w600, c: kRed))),
          TextButton(onPressed: () => ref.invalidate(stockVariantsProvider(listingId)), child: const Text('Réessayer')),
        ]),
      ),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final sel = list.where((x) => x.id == selectedId).firstOrNull;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choisissez une variante', style: mst(13, w: FontWeight.w700)),
            Wrap(spacing: 8, children: [
              for (final x in list)
                MChip(
                  '${x.out ? '${x.label} · épuisée' : (x.low && x.left != null ? '${x.label} · plus que ${x.left}' : x.label)}${x.hasOwnPrice ? ' · ${mFcfa(x.price)}' : ''}',
                  selected: sel?.id == x.id,
                  onTap: () => x.out ? gToast(context, '« ${x.label} » est épuisée : choisissez une autre variante.') : onSelect(x),
                ),
            ]),
            if (sel != null && (sel.image != null || sel.attributes.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  if (sel.image != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 72, height: 72, child: MImage(mImageUrl(sel.image)))),
                  if (sel.image != null) const SizedBox(width: 10),
                  if (sel.attributes.isNotEmpty) Expanded(child: Text(sel.attributesText, style: mst(12.5, c: kGrey))),
                ]),
              ),
            if (sel != null && sel.low && sel.left != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Derniers exemplaires : plus que ${sel.left} en stock.', style: mst(12.5, w: FontWeight.w700, c: const Color(0xFFB45309)))),
          ]),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ vendeur : gestion des variantes

/// Section « Stock par variante » du formulaire produit du vendeur : ajout, modification, ajustement du stock (motif obligatoire) et désactivation.
class VariantStockSection extends StatefulWidget {
  const VariantStockSection({super.key, required this.listingId});
  final String listingId;

  @override
  State<VariantStockSection> createState() => _VariantStockSectionState();
}

class _VariantStockSectionState extends State<VariantStockSection> {
  bool loading = true;
  String? loadError;
  List<StockVariant> items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    final r = await marcheCall('seller_variants_list', {'p_listing': widget.listingId});
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r.error != null) {
        loadError = variantErrorText(r.error);
      } else {
        items = [for (final x in (r.data as List? ?? const [])) ?StockVariant.fromJson(x)];
      }
    });
  }

  Future<void> _edit([StockVariant? v]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _VariantDialog(listingId: widget.listingId, variant: v));
    if (ok == true) {
      if (mounted) gToast(context, v == null ? 'Variante ajoutée.' : 'Variante modifiée.');
      await _load();
    }
  }

  Future<void> _adjust(StockVariant v) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _AdjustDialog(variant: v));
    if (ok == true) {
      if (mounted) gToast(context, 'Stock ajusté.');
      await _load();
    }
  }

  Future<void> _toggle(StockVariant v, bool on) async {
    final r = await marcheCall('variant_set_active', {'p_id': v.id, 'p_active': on});
    if (!mounted) return;
    gToast(context, r.error != null ? variantErrorText(r.error) : (on ? 'Variante réactivée.' : 'Variante désactivée : elle n’est plus proposée aux acheteurs.'));
    await _load();
  }

  String _badge(StockVariant v) => !v.active ? 'Désactivée' : (v.out ? 'Épuisée' : (v.low ? 'Stock bas' : 'Disponible'));

  @override
  Widget build(BuildContext context) {
    final hasActive = items.any((x) => x.active);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Stock par variante', style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Chaque variante (taille, couleur…) a son stock, son seuil d’alerte, une image et un prix propre facultatifs. Sans prix propre, la variante se vend au prix de l’annonce. Dès qu’une variante est active, le stock de l’annonce est la somme des variantes.', style: mst(12, c: kGrey)),
        const SizedBox(height: 10),
        if (loading)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (loadError != null) ...[
          Text(loadError!, style: mst(13, w: FontWeight.w600, c: kRed)),
          const SizedBox(height: 8),
          mButton('Réessayer', _load, dark: false),
        ] else ...[
          if (items.isEmpty) Text('Aucune variante : cette annonce se vend sur son stock global.', style: mst(13, c: kGrey)),
          for (final v in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (v.image != null) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 44, height: 44, child: MImage(mImageUrl(v.image))))),
                  Expanded(child: Text(v.label, style: mst(14, w: FontWeight.w700))),
                  Text(_badge(v), style: mst(12, w: FontWeight.w700, c: !v.active ? kGrey : (v.out ? kRed : (v.low ? const Color(0xFFB45309) : kGreen)))),
                ]),
                Text('Stock : ${v.stock ?? 0}${(v.reserved ?? 0) > 0 ? ' (dont ${v.reserved} réservé(s) par des commandes non payées)' : ''} · alerte à ${v.threshold ?? 0}${v.sku == null ? '' : ' · SKU ${v.sku}'}', style: mst(12, c: kGrey)),
                Text(v.hasOwnPrice ? 'Prix propre : ${mFcfa(v.price)}' : 'Prix : celui de l’annonce (${mFcfa(v.effectivePrice)})', style: mst(12, c: kGrey)),
                if (v.attributes.isNotEmpty) Text(v.attributesText, style: mst(12, c: kGrey)),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => _edit(v), child: const Text('Modifier')),
                  TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => _adjust(v), child: const Text('Ajuster le stock')),
                  Row(mainAxisSize: MainAxisSize.min, children: [Text('Active', style: mst(12.5)), Switch(value: v.active, onChanged: (on) => _toggle(v, on))]),
                ]),
              ]),
            ),
          if (items.isNotEmpty && !hasActive) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Toutes les variantes sont désactivées : l’annonce est épuisée tant qu’aucune n’est réactivée.', style: mst(12, w: FontWeight.w600, c: kRed))),
          mButton('Ajouter une variante', () => _edit(), dark: false, icon: Icons.add),
        ],
      ]),
    );
  }
}

/// Ajout ou modification d'une variante : le dialogue reste ouvert et affiche le refus du serveur ; il ne se ferme que sur un enregistrement confirmé.
class _VariantDialog extends StatefulWidget {
  const _VariantDialog({required this.listingId, this.variant});
  final String listingId;
  final StockVariant? variant;

  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  late final label = TextEditingController(text: widget.variant?.label ?? '');
  late final attrs = TextEditingController(text: widget.variant?.attributes.entries.map((e) => '${e.key}: ${e.value}').join('\n') ?? '');
  late final sku = TextEditingController(text: widget.variant?.sku ?? '');
  late final stock = TextEditingController(text: widget.variant == null ? '' : '${widget.variant!.stock ?? 0}');
  late final threshold = TextEditingController(text: '${widget.variant?.threshold ?? 3}');
  late final price = TextEditingController(text: widget.variant?.price?.toString() ?? '');
  late String? image = widget.variant?.image;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    label.dispose();
    attrs.dispose();
    sku.dispose();
    stock.dispose();
    threshold.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null) return;
    final n = x.name.toLowerCase();
    final mime = x.mimeType ?? (n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
    final bytes = await x.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) return setState(() => error = 'Image trop lourde (5 Mo maximum).');
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.uploadPublic('listing-images', 'variantes', bytes, x.name, mime);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r.error != null) {
        error = r.error;
      } else if (r.url != null && r.url!.contains('/listing-images/')) {
        image = Uri.decodeFull(r.url!.split('/listing-images/').last);
      }
    });
  }

  Future<void> _save() async {
    final a = <String, String>{};
    for (final line in attrs.text.split('\n')) {
      final i = line.indexOf(':');
      if (i > 0 && line.substring(i + 1).trim().isNotEmpty) a[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
    if (label.text.trim().isEmpty) return setState(() => error = 'Indiquez le libellé de la variante (par exemple « M — Rouge »).');
    final th = int.tryParse(threshold.text.trim());
    if (th == null || th < 0) return setState(() => error = 'Seuil d’alerte : un nombre entier, 0 ou plus.');
    int? st;
    if (widget.variant == null && stock.text.trim().isNotEmpty) {
      st = int.tryParse(stock.text.trim());
      if (st == null || st < 0) return setState(() => error = 'Stock : un nombre entier, 0 ou plus.');
    }
    int? pr;
    if (price.text.trim().isNotEmpty) {
      pr = int.tryParse(price.text.trim().replaceAll(RegExp(r'[\s.]'), ''));
      if (pr == null || pr < 500 || pr > 100000000) return setState(() => error = 'Prix de la variante : de 500 à 100 000 000 FCFA (laissez vide pour garder le prix de l’annonce).');
    }
    final clearPrice = pr == null && widget.variant?.price != null;
    final newImage = image != null && image != widget.variant?.image ? image : null;
    final clearImage = image == null && widget.variant?.image != null;
    final extra = pr != null || clearPrice || newImage != null || clearImage;
    setState(() {
      busy = true;
      error = null;
    });
    // sans prix ni image : appel historique ; sinon variant_upsert enregistre tout en une seule transaction
    final r = await marcheCall(extra ? 'variant_upsert' : 'variant_save', {
      'p_listing': widget.listingId,
      'p_label': label.text.trim(),
      'p_attributes': a,
      'p_sku': sku.text.trim().isEmpty ? null : sku.text.trim(),
      'p_threshold': th,
      if (widget.variant == null && st != null) 'p_stock': st,
      if (widget.variant != null) 'p_id': widget.variant!.id,
      if (extra && pr != null) 'p_price': pr,
      if (extra && clearPrice) 'p_clear_price': true,
      if (extra && newImage != null) 'p_image': newImage,
      if (extra && clearImage) 'p_clear_image': true,
    });
    if (!mounted) return;
    if (r.error != null) {
      return setState(() {
        busy = false;
        error = variantErrorText(r.error);
      });
    }
    Navigator.of(context).pop(true);
  }

  InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.variant == null ? 'Ajouter une variante' : 'Modifier la variante'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: label, maxLength: 80, decoration: _deco('Libellé', hint: 'M — Rouge').copyWith(counterText: '')),
            const SizedBox(height: 10),
            TextField(controller: attrs, minLines: 2, maxLines: 3, decoration: _deco('Critères (un par ligne)', hint: 'Taille: M\nCouleur: Rouge')),
            const SizedBox(height: 10),
            TextField(controller: sku, maxLength: 40, decoration: _deco('SKU (facultatif)').copyWith(counterText: '')),
            if (widget.variant == null) ...[
              const SizedBox(height: 10),
              TextField(controller: stock, keyboardType: TextInputType.number, decoration: _deco('Stock initial', hint: 'Vide : reprend le stock de l’annonce pour la première variante')),
            ],
            const SizedBox(height: 10),
            TextField(controller: threshold, keyboardType: TextInputType.number, decoration: _deco('Seuil d’alerte de stock bas')),
            const SizedBox(height: 10),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: _deco('Prix propre en FCFA (facultatif)', hint: 'Vide : prix de l’annonce')),
            const SizedBox(height: 10),
            Row(children: [
              if (image != null) Padding(padding: const EdgeInsets.only(right: 10), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 56, height: 56, child: MImage(mImageUrl(image))))),
              Expanded(child: Wrap(spacing: 6, children: [
                TextButton(onPressed: busy ? null : _pick, child: Text(image == null ? 'Ajouter une image' : 'Changer l’image')),
                if (image != null) TextButton(onPressed: busy ? null : () => setState(() => image = null), child: const Text('Retirer')),
              ])),
            ]),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: mst(13, w: FontWeight.w600, c: kRed))),
          ]),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: busy ? null : _save, child: Text(busy ? 'Un instant…' : 'Enregistrer')),
        ],
      );
}

/// Ajustement manuel du stock : nouvelle valeur et motif obligatoire (journalisé côté serveur) ; un refus reste affiché dans le dialogue.
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.variant});
  final StockVariant variant;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late final value = TextEditingController(text: '${widget.variant.stock ?? 0}');
  final reason = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    value.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = int.tryParse(value.text.trim());
    if (n == null || n < 0) return setState(() => error = 'Stock : un nombre entier, 0 ou plus.');
    if (reason.text.trim().length < 3) return setState(() => error = 'Indiquez le motif de l’ajustement (3 caractères au moins).');
    setState(() {
      busy = true;
      error = null;
    });
    final r = await marcheCall('variant_adjust', {'p_id': widget.variant.id, 'p_set': n, 'p_reason': reason.text.trim()});
    if (!mounted) return;
    if (r.error != null) {
      return setState(() {
        busy = false;
        error = variantErrorText(r.error);
      });
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Ajuster le stock : ${widget.variant.label}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nouveau stock', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: reason, maxLength: 200, decoration: const InputDecoration(labelText: 'Motif (obligatoire)', hintText: 'Réassort, casse, inventaire…', border: OutlineInputBorder(), counterText: '')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: mst(13, w: FontWeight.w600, c: kRed))),
          ]),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: busy ? null : _save, child: Text(busy ? 'Un instant…' : 'Enregistrer')),
        ],
      );
}
