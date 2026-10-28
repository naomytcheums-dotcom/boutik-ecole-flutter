import '../../common/common.dart';
import '../e_widgets.dart';

/// 46 · Suivi de livraison : trajet, étapes, point et code de retrait.
class SuiviLivraisonScreen extends ConsumerWidget {
  const SuiviLivraisonScreen({super.key});

  void _showCode(BuildContext context, SectionEData d) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text('Code de retrait', style: ETxt.section)),
              gap12,
              Semantics(
                label: 'Code de retrait : ${d.pickupCode.split('').join(' ')}',
                excludeSemantics: true,
                child: Text(d.pickupCode, style: AppText.display.copyWith(letterSpacing: 4)),
              ),
              gap8,
              Text(
                'Présentez ce code au ${d.pickupPoint} pour retirer votre commande.',
                style: ETxt.body,
                textAlign: TextAlign.center,
              ),
              gap16,
              EButton('Fermer', onPressed: () => Navigator.pop(c)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionEDataProvider);
    final small = AppText.small.copyWith(fontSize: 10.5);
    final strong = ETxt.cardTitle;
    return EScaffold(
      title: 'Suivi de livraison',
      actions: [
        EButton('Contacter le vendeur', kind: EButtonKind.outline, onPressed: () => context.openScreen('51')),
        EButton('Voir le code de retrait', onPressed: () => _showCode(context, d)),
      ],
      children: [
        const SizedBox(height: 2),
        ECard(
          child: ERow(
            height: 65.5,
            leading: const ETile(AppIcons.truck),
            title: d.trackingRef,
            titleStyle: ETxt.itemRegular,
            subtitle: d.trackingEta,
            trailing: const EStatusBadge(EOrderStatus.inTransit),
          ),
        ),
        const SizedBox(height: 15),
        ECard(
          color: Colors.white.withValues(alpha: .78),
          child: SizedBox(
            height: 169.5,
            child: Stack(
              children: [
                Positioned(
                  left: 22,
                  top: 7.5,
                  width: 105,
                  height: 154,
                  child: Image.asset(
                    d.trackingMap,
                    fit: BoxFit.fill,
                    semanticLabel: 'Carte du trajet de ${d.departure} à ${d.arrival}',
                  ),
                ),
                Positioned(
                  left: 170,
                  right: 12,
                  top: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Départ', style: small),
                      const SizedBox(height: 2),
                      Text(d.departure, style: strong),
                      const SizedBox(height: 15.5),
                      Text('Arrivée prévue', style: small),
                      const SizedBox(height: 3),
                      Text(d.arrival, style: strong),
                      const SizedBox(height: 15.5),
                      Container(
                        height: 29,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: const ShapeDecoration(color: Color(0xFFEDE8FF), shape: StadiumBorder()),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            d.distanceLeft,
                            maxLines: 1,
                            style: ETxt.badge.copyWith(fontSize: 10.7, color: AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ETimeline(steps: d.trackingSteps, current: d.trackingCurrentStep),
        const SizedBox(height: 35),
        EKvList(rows: [('Point de retrait', d.pickupPoint), ('Code de retrait', d.pickupCode)]),
      ],
    );
  }
}
