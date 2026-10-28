import '../u_widgets.dart';

/// 172 · Confiance du vendeur.
class ConfianceVendeurScreen extends ConsumerWidget {
  const ConfianceVendeurScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionUDataProvider);
    final s = d.seller;
    return CPage(
      title: 'Confiance du vendeur',
      showNav: false,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            children: [
              Avatar(image: s.image, size: 76),
              gap12,
              Text(s.name, style: AppText.h3),
              const SizedBox(height: 2),
              Text(s.detail, style: AppText.small),
              gap12,
              const GBadge('Vendeur vérifié', Tone.success),
            ],
          ),
        ),
        const GSectionTitle('Badges de confiance'),
        QCard(
          children: [
            for (final b in d.trustBadges) QRow(icon: b.$1, title: b.$2, subtitle: b.$3, trailing: GBadge(b.$4, b.$5)),
          ],
        ),
        gap16,
        const GNote(
          'Un badge est retiré automatiquement si le compte est signalé ou si les documents expirent.',
          icon: AppIcons.info,
        ),
      ],
    );
  }
}
