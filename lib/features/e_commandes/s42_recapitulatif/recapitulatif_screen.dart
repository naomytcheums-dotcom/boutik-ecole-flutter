import '../../common/common.dart';
import '../e_widgets.dart';

/// 42 · Récapitulatif de commande (étape « Confirmation »).
class RecapitulatifScreen extends ConsumerStatefulWidget {
  const RecapitulatifScreen({super.key});

  @override
  ConsumerState<RecapitulatifScreen> createState() => _RecapitulatifScreenState();
}

class _RecapitulatifScreenState extends ConsumerState<RecapitulatifScreen> {
  bool _accepted = true;
  bool _showError = false;

  void _confirm() {
    if (!_accepted) {
      setState(() => _showError = true);
      return;
    }
    context.openScreen('43');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionEDataProvider);
    final subtotal = d.summaryLines.fold(0, (s, l) => s + l.price * l.qty);
    return EScaffold(
      title: 'Récapitulatif',
      actions: [EButton('Confirmer la commande', onPressed: _confirm)],
      children: [
        ECheckoutStepper(labels: d.checkoutSteps, current: 3),
        const SizedBox(height: 14),
        ECard(
          child: Column(
            children: [
              for (final (i, l) in d.summaryLines.indexed) ...[
                if (i > 0) const EDivider(indent: 98.5, endIndent: 12),
                Semantics(
                  label: '${l.title}, quantité ${l.qty}, ${fcfa(l.price)}',
                  excludeSemantics: true,
                  child: ERow(
                    height: i == 0 ? 66 : 65,
                    leading: EThumb(l.image),
                    title: l.title,
                    titleStyle: ETxt.itemRegular,
                    subtitle: 'Qté : ${l.qty}',
                    rightPadding: 16,
                    trailing: Text(
                      fcfa(l.price, withUnit: false),
                      style: ETxt.item.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 15),
        ECard(
          child: Column(
            children: [
              ERow(
                leading: const ETile(AppIcons.mapPin),
                title: d.pickupTitle,
                subtitle: d.pickupDetail,
                chevron: true,
                onTap: () => context.openScreen('07'),
              ),
              const EDivider(indent: 64, endIndent: 12),
              ERow(
                height: 65,
                leading: const ETile(AppIcons.wallet),
                title: d.paymentTitle,
                subtitle: d.paymentDetail,
                chevron: true,
                onTap: () => context.openScreen('08'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.5),
        EKvList(
          rows: [
            ('Sous-total', fcfa(subtotal)),
            ('Livraison', fcfa(d.deliveryFee)),
            ('Total', fcfa(subtotal + d.deliveryFee)),
          ],
        ),
        const SizedBox(height: 14.5),
        ECheckRow(
          height: 40,
          crossAxisAlignment: CrossAxisAlignment.start,
          label: 'J’accepte les conditions de vente et la politique de retour.',
          value: _accepted,
          onChanged: (v) => setState(() {
            _accepted = v;
            if (v) _showError = false;
          }),
        ),
        if (_showError)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Text(
              'Vous devez accepter les conditions de vente pour confirmer.',
              style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
