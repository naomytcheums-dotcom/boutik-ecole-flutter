import '../../common/common.dart';

/// 05 · Fiche produit « Lampe en bois recyclé ».
class FicheProduitScreen extends ConsumerStatefulWidget {
  const FicheProduitScreen({super.key});

  @override
  ConsumerState<FicheProduitScreen> createState() => _FicheProduitScreenState();
}

class _FicheProduitScreenState extends ConsumerState<FicheProduitScreen> {
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADataProvider);
    final p = d.product;
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: 360, child: Image.asset(Photos.team, fit: BoxFit.cover, alignment: Alignment.topCenter, semanticLabel: 'Équipe du projet')),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.backgroundGradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StatusBadge('Produit', tone: BadgeTone.neutral, icon: AppIcons.package),
                      gap12,
                      Semantics(header: true, child: Text(p.title, style: AppText.h1.copyWith(fontWeight: FontWeight.w700))),
                      gap8,
                      Text(fcfa(p.price), style: AppText.h2.copyWith(fontWeight: FontWeight.w800)),
                      gap8,
                      Row(
                        children: [
                          const AppIcon(AppIcons.star, size: 16, color: Color(0xFFF2B33D)),
                          const SizedBox(width: 6),
                          Text(p.rating, style: AppText.bodyStrong),
                          Text(' (${p.reviews} avis)', style: AppText.secondary),
                        ],
                      ),
                      gap12,
                      Text(p.description, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.5)),
                      gap16,
                      Row(
                        children: [
                          for (final (i, f) in d.productFeatures.indexed) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: AppCard(
                                color: const Color(0xFFF7F6F9),
                                borderColor: null,
                                radius: 16,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                                child: Column(
                                  children: [
                                    AppIcon(f.$2, size: 22),
                                    gap8,
                                    Text(f.$1, style: AppText.small.copyWith(color: AppColors.ink), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      gap24,
                      InkWell(
                        onTap: () => context.openScreen('33'),
                        child: Row(
                          children: [
                            const Avatar(image: Photos.avatarCreator, size: 66),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Créée par', style: AppText.small.copyWith(color: AppColors.accent)),
                                Text(p.creator, style: AppText.h3),
                                Text('Département : ${p.department}', style: AppText.small),
                              ],
                            ),
                          ],
                        ),
                      ),
                      gap24,
                      PrimaryButton(
                        label: 'Ajouter au panier',
                        onPressed: () {
                          ref.read(cartProvider.notifier).add(CartLine(p.title, p.department, p.price, Photos.paintRed));
                          context.toast('Ajouté au panier.');
                        },
                      ),
                      gap16,
                      for (final r in ['Caractéristiques', 'Livraison et retrait', 'Avis des clients'])
                        DecoratedBox(
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
                          child: ListRow(
                            title: r,
                            onTap: () => context.openScreen(switch (r) {
                              'Livraison et retrait' => '07',
                              'Avis des clients' => '47',
                              _ => '32',
                            }),
                          ),
                        ),
                      PrimaryButton(
                        label: 'Voir mon panier',
                        variant: ButtonVariant.secondary,
                        onPressed: () => context.openScreen('06'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: AppIcons.arrowLeft,
                    label: 'Retour',
                    bordered: false,
                    background: Colors.transparent,
                    foreground: Colors.white,
                    onTap: () => ScreenHeader.back(context),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: AppIcons.heart,
                    label: _favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    bordered: false,
                    background: Colors.transparent,
                    foreground: _favorite ? const Color(0xFFFF6B6B) : Colors.white,
                    onTap: () => setState(() => _favorite = !_favorite),
                  ),
                  RoundIconButton(
                    icon: AppIcons.share2,
                    label: 'Partager',
                    bordered: false,
                    background: Colors.transparent,
                    foreground: Colors.white,
                    onTap: () => context.openScreen('212'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
