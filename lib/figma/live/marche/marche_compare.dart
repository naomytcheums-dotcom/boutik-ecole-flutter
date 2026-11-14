import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/demo/section_a_demo.dart' show CartLine;
import '../../../data/repositories/repositories.dart' show cartProvider;
import '../../gen.dart' show gToast;
import '../../i18n.dart' show Text;
import '../messages.dart' show contactSeller;
import 'compare_logic.dart';
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Comparaison de deux offres choisies par l'acheteur : critères modifiables, pourcentage de compatibilité recalculé en direct,
/// meilleure valeur mise en évidence sur chaque ligne, prix total livré, et bouton « Choisir celle-ci » vers la commande ou le contact.

class CompareCriteriaNotifier extends Notifier<CompareCriteria> {
  @override
  CompareCriteria build() => const CompareCriteria();
  void set(CompareCriteria c) => state = c;
}

final compareCriteriaProvider = NotifierProvider<CompareCriteriaNotifier, CompareCriteria>(CompareCriteriaNotifier.new);

/// Frais de livraison d'une offre vers une ville (tarifs du vendeur, de la plateforme ou de l'IUT) ; nul si la ville n'est pas desservie.
final compareFeeProvider = FutureProvider.autoDispose.family<int?, ({String id, String city})>((ref, k) async {
  final r = await marcheCall('delivery_quote', {'p_city': k.city, 'p_items': [{'id': k.id, 'qty': 1}]});
  if (r.error != null || r.data is! Map) return null;
  final fee = (r.data as Map)['fee'];
  return fee is num ? fee.toInt() : null;
});

const _defaultCity = 'Douala';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  final _budget = TextEditingController(), _cap = TextEditingController(), _mat = TextEditingController(), _col = TextEditingController(), _war = TextEditingController(), _liv = TextEditingController(), _city = TextEditingController();

  @override
  void dispose() {
    for (final c in [_budget, _cap, _mat, _col, _war, _liv, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));

  /// Recalcule tout à chaque frappe : les critères sont lus par le fournisseur, les pourcentages et les gagnants suivent.
  void _changed() {
    ref.read(compareCriteriaProvider.notifier).set(CompareCriteria(
          budget: _int(_budget.text),
          minCapacity: firstNumber(_cap.text),
          material: _mat.text,
          color: _col.text,
          minWarrantyMonths: _int(_war.text),
          maxDeliveryDays: _int(_liv.text),
          city: _city.text.trim(),
        ));
  }

  InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

  Widget _field(TextEditingController c, String label, {String? hint, bool number = false}) =>
      TextField(controller: c, keyboardType: number ? TextInputType.number : null, onChanged: (_) => _changed(), decoration: _deco(label, hint: hint));

  void _choose(Map<String, dynamic> card, int price) {
    if ('${card['offer_type'] ?? 'product'}' == 'product') {
      if (mInt(card['stock']) <= 0) return gToast(context, 'Cette offre est épuisée.');
      ref.read(cartProvider.notifier).add(CartLine('${card['title']}', 'Boutique : ${card['shop_name'] ?? 'Boutik-École'}', price, mImageUrl(card['image'])));
      gToast(context, 'Ajouté au panier');
      context.push('/marche/panier');
    } else {
      contactSeller(ref, context, '${card['title']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(marcheCompareProvider);
    final crit = ref.watch(compareCriteriaProvider);
    final city = crit.city.isEmpty ? _defaultCity : crit.city;
    return MarchePage(
      title: 'Comparer',
      actions: [if (ids.isNotEmpty) TextButton(onPressed: () => ref.read(marcheCompareProvider.notifier).clear(), child: const Text('Vider'))],
      child: ids.length < 2
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              mNote('Choisissez deux offres à comparer avec le bouton de comparaison sur leur photo (2 au maximum).${ids.length == 1 ? '\nUne offre est déjà choisie : il en faut une seconde.' : ''}'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: mButton('Parcourir la marketplace', () => context.push('/marche'))),
            ])
          : _body(context, ids, crit, city),
    );
  }

  Widget _body(BuildContext context, List<String> ids, CompareCriteria crit, String city) {
    final detailA = ref.watch(marcheProductProvider(ids[0]));
    final detailB = ref.watch(marcheProductProvider(ids[1]));
    final feeA = ref.watch(compareFeeProvider((id: ids[0], city: city)));
    final feeB = ref.watch(compareFeeProvider((id: ids[1], city: city)));
    if (detailA.isLoading || detailB.isLoading) return const Center(child: CircularProgressIndicator());
    final a = detailA.value, b = detailB.value;
    if (a == null || b == null || a['found'] != true || b['found'] != true) return mNote('L’une des offres n’est plus disponible. Videz la comparaison et choisissez-en une autre.');
    final cards = [Map<String, dynamic>.from(a['card'] as Map), Map<String, dynamic>.from(b['card'] as Map)];
    final specs = [Map<String, dynamic>.from((a['specs'] as Map?) ?? const {}), Map<String, dynamic>.from((b['specs'] as Map?) ?? const {})];
    final fees = [feeA.value, feeB.value];
    final facts = [
      for (var i = 0; i < 2; i++)
        factsFrom(
          title: '${cards[i]['title']}',
          price: mInt(cards[i]['flash_price'] ?? cards[i]['price']),
          specs: specs[i],
          deliveryFee: fees[i],
          rating: (cards[i]['rating_avg'] as num?)?.toDouble(),
          stock: mInt(cards[i]['stock']),
        ),
    ];
    final compat = [for (final f in facts) compatibility(f, crit)];
    final bestCompat = bestOf(compat[0], compat[1]);

    // Tant que delivery_quote n'a pas répondu, la livraison est en cours de calcul : elle n'est pas « non livrable ».
    final calculating = [feeA.isLoading && !feeA.hasValue, feeB.isLoading && !feeB.hasValue];
    final anyCalculating = calculating.contains(true);
    String money(int? v, int i) => calculating[i] ? 'Calcul…' : (v == null ? 'Non livrable' : (v == 0 ? 'Gratuit' : mFcfa(v)));
    String total(int i) => calculating[i] ? 'Calcul…' : (facts[i].totalDelivered == null ? 'Non livrable' : mFcfa(facts[i].totalDelivered));

    // (libellé, valeurs affichées, gagnant)
    final rows = <(String, List<String>, int?)>[
      ('Prix', [mFcfa(facts[0].price), mFcfa(facts[1].price)], bestOf(facts[0].price, facts[1].price, lowerIsBetter: true)),
      ('Livraison vers $city', [money(fees[0], 0), money(fees[1], 1)], anyCalculating ? null : bestOf(fees[0], fees[1], lowerIsBetter: true)),
      ('Prix total livré', [total(0), total(1)], anyCalculating ? null : bestOf(facts[0].totalDelivered, facts[1].totalDelivered, lowerIsBetter: true)),
      ('Matériau', [for (final s in specs) specText(s, ['mat']) ?? 'Non précisé'], null),
      ('Capacité', [for (final s in specs) specText(s, ['capac']) ?? 'Non précisé'], bestOf(facts[0].capacity, facts[1].capacity)),
      ('Couleurs', [for (final s in specs) specText(s, ['coul']) ?? 'Non précisé'], null),
      ('Garantie', [for (final s in specs) specText(s, ['garant']) ?? 'Non précisé'], bestOf(facts[0].warrantyMonths, facts[1].warrantyMonths)),
      ('Délai de livraison', [for (final s in specs) specText(s, ['livr', 'delai']) ?? 'Non précisé'], bestOf(facts[0].deliveryDays, facts[1].deliveryDays, lowerIsBetter: true)),
      ('Note', [for (final f in facts) f.rating == null ? 'Pas encore noté' : '★ ${f.rating}'], bestOf(facts[0].rating, facts[1].rating)),
      ('Stock', [for (final f in facts) f.stock <= 0 ? 'Épuisé' : '${f.stock}'], null),
    ];

    Widget cell(String text, {bool best = false, bool bold = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          color: best ? const Color(0xFFDDF5EC) : null,
          child: Row(children: [
            Expanded(child: Text(text, style: mst(12.5, w: bold || best ? FontWeight.w800 : FontWeight.w500, c: best ? kGreen : kInk))),
            if (best) const Icon(Icons.check_circle, size: 15, color: kGreen),
          ]),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 100), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: 78),
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(aspectRatio: 1, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: MImage(mImageUrl(cards[i]['image'])))),
                const SizedBox(height: 6),
                Text('${cards[i]['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13, w: FontWeight.w800)),
                if ('${cards[i]['shop_name'] ?? ''}'.isNotEmpty) Text('${cards[i]['shop_name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(11, c: kViolet)),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mes critères', style: mst(14.5, w: FontWeight.w800)),
          Text('Renseignez ce qui compte pour vous : la compatibilité de chaque offre se recalcule à chaque modification.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _field(_budget, 'Budget max (FCFA)', number: true)), const SizedBox(width: 8), Expanded(child: _field(_cap, 'Capacité min.', hint: 'Ex. 20', number: true))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _field(_mat, 'Matériau', hint: 'Ex. tissu')), const SizedBox(width: 8), Expanded(child: _field(_col, 'Couleur', hint: 'Ex. noir'))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _field(_war, 'Garantie min. (mois)', number: true)), const SizedBox(width: 8), Expanded(child: _field(_liv, 'Livraison max (jours)', number: true))]),
          const SizedBox(height: 8),
          _field(_city, 'Ville de livraison', hint: _defaultCity),
        ]),
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.0), 1: FlexColumnWidth(1.35), 2: FlexColumnWidth(1.35)},
          border: const TableBorder(horizontalInside: BorderSide(color: kLine)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              cell('Compatibilité', bold: true),
              for (var i = 0; i < 2; i++) cell(compat[i] == null ? 'Indiquez vos critères' : '${compat[i]} %', best: bestCompat == i, bold: true),
            ]),
            for (final r in rows) TableRow(children: [cell(r.$1, bold: true), cell(r.$2[0], best: r.$3 == 0), cell(r.$2[1], best: r.$3 == 1)]),
          ],
        ),
      ),
      if (crit.count > 0 && bestCompat != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Meilleure correspondance : ${facts[bestCompat].title} (${compat[bestCompat]} %).', style: mst(13, w: FontWeight.w800, c: kGreen))),
      const SizedBox(height: 14),
      Row(children: [
        for (var i = 0; i < 2; i++) ...[
          if (i == 1) const SizedBox(width: 8),
          Expanded(child: mButton('Choisir celle-ci', () => _choose(cards[i], facts[i].price))),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 2; i++) ...[
          if (i == 1) const SizedBox(width: 8),
          Expanded(child: Text('${cards[i]['offer_type'] ?? 'product'}' == 'product' ? 'Ajoute au panier et ouvre la commande' : 'Ouvre la discussion avec le vendeur', textAlign: TextAlign.center, style: mst(11, c: kGrey))),
        ],
      ]),
    ]);
  }
}
