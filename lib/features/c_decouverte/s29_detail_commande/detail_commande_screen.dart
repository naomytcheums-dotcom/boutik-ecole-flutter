import '../c_widgets.dart';

/// 29 · Détail de la commande (livrée).
class DetailCommandeScreen extends ConsumerWidget {
  const DetailCommandeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionCDataProvider);
    final item = d.detailItem;
    final total = item.price * d.detailQty + d.detailShipping;
    final small = AppText.small.copyWith(fontSize: 11);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      header: const Padding(padding: EdgeInsets.only(top: 14), child: TitleHeader('Détail de la commande')),
      bottomBar: Row(
        children: [
          Expanded(child: GOutlineButton('Contacter le vendeur', onPressed: () => context.openScreen('51'))),
          const SizedBox(width: 12),
          Expanded(child: PrimaryButton(label: 'Voir le reçu', height: 54, onPressed: () => context.openScreen('259'))),
        ],
      ),
      children: [
        gap16,
        Row(
          children: [
            Expanded(child: Text(d.detailRef, style: AppText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w600))),
            const GBadge('Livrée', Tone.success),
          ],
        ),
        gap8,
        Text('${d.detailDate}  •  ${fcfa(total)}', style: AppText.small.copyWith(fontSize: 11.5, color: AppColors.accent)),
        gap24,
        Semantics(
          label: 'Commande livrée : toutes les étapes sont terminées',
          excludeSemantics: true,
          child: Row(
            children: [
              for (final (i, s) in d.detailSteps.indexed)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 20,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Container(height: 1.5, color: i == 0 ? null : const Color(0xFFA9D8C3))),
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: i == d.detailSteps.length - 1 ? null : const Color(0xFFA9D8C3),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const AppIcon(AppIcons.check, size: 11, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      gap12,
                      Text(s, style: small),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap24,
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Articles', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
              gap16,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(item.image, width: 68, height: 68, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AppText.body.copyWith(fontSize: 13)),
                        gap8,
                        Text(fcfa(item.price), style: AppText.bodyStrong),
                        gap8,
                        Text('Qté : ${d.detailQty}', style: small),
                      ],
                    ),
                  ),
                  Text('x${d.detailQty}', style: small.copyWith(fontSize: 10)),
                ],
              ),
              const Divider(height: 32),
              KeyValueRow(KV('Frais de livraison', fcfa(d.detailShipping))),
              const Divider(height: 32),
              KeyValueRow(KV('Total', fcfa(total), strong: true)),
            ],
          ),
        ),
        gap24,
        Text('Adresse de livraison', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
        gap12,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon(AppIcons.mapPin, size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(d.detailAddress.$1, style: small), gap12, Text(d.detailAddress.$2, style: small)],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
