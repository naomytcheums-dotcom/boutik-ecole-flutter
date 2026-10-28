import '../../common/common.dart';

/// 07 · Livraison (retrait sur campus ou domicile).
class LivraisonScreen extends ConsumerWidget {
  const LivraisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADataProvider);
    final pickup = ref.watch(pickupProvider);
    final set = ref.read(pickupProvider.notifier).set;
    return AppScaffold(
      tab: NavTab.home,
      header: const TitleHeader('Livraison'),
      bottomBar: PrimaryButton(label: 'Continuer', trailingIcon: AppIcons.arrowRight, onPressed: () => context.openScreen('08')),
      children: [
        Text('Choisissez votre mode de livraison', style: AppText.h3),
        gap16,
        _ModeCard(
          icon: AppIcons.school,
          title: 'Retrait sur campus',
          text: 'Récupérez votre commande à l’IUT de Douala.',
          selected: pickup,
          onTap: () => set(true),
        ),
        gap12,
        _ModeCard(
          icon: AppIcons.truck,
          title: 'Livraison à domicile',
          text: 'Recevez votre commande à l’adresse de votre choix.',
          selected: !pickup,
          onTap: () => set(false),
        ),
        gap24,
        Text('Adresse de livraison', style: AppText.h3),
        gap12,
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          radius: 18,
          child: ListRow(
            title: d.deliveryAddress,
            leading: const AppIcon(AppIcons.mapPin, size: 20),
            onTap: () => context.openScreen('43'),
          ),
        ),
        gap24,
        Text('Détails de livraison', style: AppText.h3),
        gap12,
        AppCard(
          color: const Color(0xFFF6F5F8),
          borderColor: null,
          radius: 18,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              KeyValueRow(KV('Délai estimé', d.deliveryDelay)),
              gap16,
              KeyValueRow(KV('Frais de livraison', fcfa(d.deliveryFee))),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.text, required this.selected, required this.onTap});

  final String icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title. $text',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        color: selected ? const Color(0xFFFFFAEE) : Colors.white,
        borderColor: selected ? const Color(0xFFF2C24B) : AppColors.cardBorder,
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: AppIcon(icon, size: 32)),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.h3),
                  const SizedBox(height: 6),
                  Text(text, style: AppText.secondary),
                ],
              ),
            ),
            if (selected)
              const StatusBadge('Sélectionné', tone: BadgeTone.dark)
            else
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 1.4)),
              ),
          ],
        ),
      ),
    );
  }
}
