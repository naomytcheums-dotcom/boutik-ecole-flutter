import '../../common/common.dart';

/// 09 · Ma commande (suivi).
class MaCommandeScreen extends ConsumerWidget {
  const MaCommandeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADataProvider);
    final cart = ref.watch(cartProvider);
    const stepIcons = [AppIcons.check, AppIcons.package, AppIcons.truck, AppIcons.fileCheck];
    return AppScaffold(
      tab: NavTab.home,
      header: const TitleHeader('Ma commande'),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.orderId, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(d.orderDate, style: AppText.secondary),
                ],
              ),
            ),
            const StatusBadge('En cours', tone: BadgeTone.dark),
          ],
        ),
        gap24,
        Semantics(
          label: 'Étape ${d.orderCurrentStep + 1} sur ${d.orderSteps.length} : ${d.orderSteps[d.orderCurrentStep]}',
          excludeSemantics: true,
          child: Row(
            children: [
              for (final (i, s) in d.orderSteps.indexed)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : (i <= d.orderCurrentStep ? AppColors.ink : AppColors.cardBorder))),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: i == d.orderSteps.length - 1 ? Colors.transparent : (i < d.orderCurrentStep ? AppColors.ink : AppColors.cardBorder),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: i == d.orderCurrentStep ? 46 : 34,
                              height: i == d.orderCurrentStep ? 46 : 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= d.orderCurrentStep ? AppColors.ink : Colors.white,
                                boxShadow: i == d.orderCurrentStep
                                    ? const [BoxShadow(color: Color(0x55F2B33D), blurRadius: 10, spreadRadius: 2)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: AppIcon(stepIcons[i], size: 18, color: i <= d.orderCurrentStep ? Colors.white : AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      gap8,
                      Text(
                        s,
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(
                          color: i < d.orderCurrentStep
                              ? AppColors.accent
                              : (i == d.orderCurrentStep ? AppColors.ink : AppColors.textSecondary),
                          fontWeight: i == d.orderCurrentStep ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap24,
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Détails de la commande', style: AppText.h3),
              gap12,
              for (final (i, l) in cart.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: i == 0 ? PhotoTile(image: Photos.sketch, radius: 12, semanticLabel: l.title) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.title, style: AppText.bodyStrong),
                            const SizedBox(height: 4),
                            Text(fcfa(l.price), style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Text('×${l.qty}', style: AppText.small),
                    ],
                  ),
                ),
              const Divider(height: 28),
              Text('Adresse de livraison', style: AppText.body),
              gap12,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(AppIcons.mapPin, size: 20),
                  const SizedBox(width: 16),
                  Expanded(child: Text(d.pickupAddress, style: AppText.secondary)),
                ],
              ),
            ],
          ),
        ),
        gap24,
        PrimaryButton(
          label: 'Contacter le vendeur',
          icon: AppIcons.messageCircle,
          variant: ButtonVariant.secondary,
          onPressed: () => context.openScreen('51'),
        ),
      ],
    );
  }
}
