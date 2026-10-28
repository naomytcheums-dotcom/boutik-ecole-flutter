import '../../common/common.dart';

/// 06 · Mon panier.
class PanierScreen extends ConsumerWidget {
  const PanierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADataProvider);
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final fee = d.deliveryFee;
    return AppScaffold(
      tab: NavTab.home,
      header: TitleHeader(
        'Mon panier',
        trailing: Text('${cart.count} article${cart.count > 1 ? 's' : ''}', style: AppText.secondary),
      ),
      bottomBar: cart.isEmpty
          ? null
          : PrimaryButton(
              label: 'Passer la commande',
              trailingIcon: AppIcons.arrowRight,
              onPressed: () => context.openScreen('07'),
            ),
      children: [
        const Divider(),
        if (cart.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                const ChromeIcon(AppIcons.shoppingCart, size: 64),
                gap16,
                Text('Votre panier est vide', style: AppText.h3),
                gap16,
                PrimaryButton(label: 'Explorer le catalogue', expand: false, onPressed: () => context.goScreen('04')),
              ],
            ),
          ),
        for (final (i, l) in cart.indexed) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 106, child: PhotoTile(image: l.image, aspectRatio: 106 / 128, radius: 16, semanticLabel: l.title)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: AppText.h3),
                      const SizedBox(height: 6),
                      Text('Département : ${l.department}', style: AppText.small),
                      gap8,
                      Text(fcfa(l.price), style: AppText.bodyStrong.copyWith(color: AppColors.accent, fontSize: 15)),
                      gap8,
                      _QtyStepper(
                        qty: l.qty,
                        label: l.title,
                        onMinus: () => notifier.setQty(i, l.qty - 1),
                        onPlus: () => notifier.setQty(i, l.qty + 1),
                      ),
                    ],
                  ),
                ),
                RoundIconButton(
                  icon: AppIcons.trash2,
                  label: 'Retirer ${l.title}',
                  bordered: false,
                  background: Colors.transparent,
                  onTap: () => notifier.remove(i),
                ),
              ],
            ),
          ),
          const Divider(),
        ],
        if (cart.isNotEmpty) ...[
          gap8,
          KeyValueRow(KV('Sous-total', fcfa(cart.subtotal), color: AppColors.accent)),
          gap12,
          KeyValueRow(KV('Livraison', fcfa(fee), color: AppColors.accent)),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(child: Text('Total', style: AppText.h2)),
              Text(fcfa(cart.subtotal + fee), style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.label, required this.onMinus, required this.onPlus});

  final int qty;
  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget btn(String icon, String l, VoidCallback onTap) => RoundIconButton(
      icon: icon,
      label: l,
      size: 30,
      bordered: false,
      background: const Color(0xFFEDEBF1),
      onTap: onTap,
    );
    return Container(
      decoration: ShapeDecoration(color: const Color(0xFFF6F5F8), shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(AppIcons.minus, 'Diminuer la quantité de $label', onMinus),
          SizedBox(
            width: 32,
            child: Text('$qty', textAlign: TextAlign.center, style: AppText.bodyStrong, semanticsLabel: 'Quantité $qty'),
          ),
          btn(AppIcons.plus, 'Augmenter la quantité de $label', onPlus),
        ],
      ),
    );
  }
}
