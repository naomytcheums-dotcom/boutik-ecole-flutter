import '../../common/common.dart';
import '../d_widgets.dart';

/// 35 · Disponibilité du produit par variante et informations de stock.
class DisponibiliteScreen extends ConsumerStatefulWidget {
  const DisponibiliteScreen({super.key});

  @override
  ConsumerState<DisponibiliteScreen> createState() => _DisponibiliteScreenState();
}

class _DisponibiliteScreenState extends ConsumerState<DisponibiliteScreen> {
  bool _alert = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionDDataProvider);
    return DScaffold(
      title: 'Disponibilité',
      actions: [
        DButton(
          _alert ? 'Alerte activée' : 'Me prévenir',
          kind: DButtonKind.outline,
          onPressed: () {
            setState(() => _alert = !_alert);
            context.toast(_alert ? 'Vous serez prévenu du réassort.' : 'Alerte de réassort désactivée.');
          },
        ),
        DButton(
          'Ajouter au panier',
          onPressed: () {
            final v = d.stockVariants.first;
            ref
                .read(cartProvider.notifier)
                .add(CartLine('${d.productTitle} · ${v.$1}', d.creatorName, d.productPrice, d.productHero));
            context.toast('Ajouté au panier (${v.$1}).');
          },
        ),
      ],
      children: [
        const SizedBox(height: 2),
        DSummaryCard(
          leading: DPhoto(d.productThumb, radius: 10, width: 50, height: 50),
          title: d.productTitle,
          subtitle: '${fcfa(d.productPrice)} · ${d.productTotalUnits} unités au total',
          trailing: DBadge(d.productStock, background: DColors.doneSoft, foreground: DColors.doneText, height: 24),
        ),
        const SizedBox(height: 15),
        const DSectionTitle('Variantes'),
        const SizedBox(height: 17),
        DCard(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            children: [
              for (final (i, v) in d.stockVariants.indexed) ...[
                if (i > 0) const DDivider(),
                _VariantRow(name: v.$1, sku: v.$2, count: v.$3, stock: v.$4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        DKvCard(title: 'Informations de stock', rows: d.stockInfo),
        const SizedBox(height: 16),
        DNote(icon: AppIcons.triangleAlert, text: d.stockAlert),
      ],
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.name, required this.sku, required this.count, required this.stock});

  final String name;
  final String sku;
  final int count;
  final DStock stock;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (stock) {
      DStock.ok => ('$count en stock', DColors.doneSoft, DColors.doneText),
      DStock.low => ('$count en stock', DColors.lowSoft, DColors.lowText),
      DStock.out => ('Rupture', DColors.outSoft, DColors.outText),
    };
    return Semantics(
      label: '$name, $sku, $label',
      excludeSemantics: true,
      child: SizedBox(
        height: 65,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DTxt.item),
                    const SizedBox(height: 5),
                    Text(sku, style: DTxt.meta),
                  ],
                ),
              ),
              DBadge(label, background: bg, foreground: fg),
            ],
          ),
        ),
      ),
    );
  }
}
